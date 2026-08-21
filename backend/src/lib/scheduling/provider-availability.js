/**
 * Provider availability
 *
 * @module lib/scheduling/provider-availability
 * @description Answers whether a member of staff can be booked for a given
 * window, from the roster the facility already maintains: their recurring
 * provider_schedule, dated availability_slot overrides, and approved leave.
 *
 * Read-only and side-effect free, so any module that books someone's time
 * (appointments today, visit queues or theatre lists later) can ask the same
 * question and get the same answer.
 */

const prisma = require('@prisma/client');

/** Reasons a provider cannot take the requested window. */
const UNAVAILABLE_REASONS = {
  ON_LEAVE: 'ON_LEAVE',
  BLOCKED_SLOT: 'BLOCKED_SLOT',
  OFF_SCHEDULE: 'OFF_SCHEDULE',
};

const MINUTES_PER_DAY = 24 * 60;
const MIDDAY_MINUTES = 12 * 60;

const AVAILABLE = Object.freeze({ available: true });

/**
 * Wall-clock parts of an instant in a named zone.
 *
 * provider_schedule.timezone states which clock its start/end times are on,
 * so the booking has to be read on that same clock before the two can be
 * compared. An unknown zone falls back to UTC rather than failing the
 * booking — a bad timezone string is a configuration problem, and refusing
 * to schedule anybody until it is fixed helps no one.
 */
const zonedParts = (instant, timeZone) => {
  const format = (zone) =>
    new Intl.DateTimeFormat('en-US', {
      timeZone: zone,
      hour12: false,
      weekday: 'short',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    }).formatToParts(instant);

  let parts;
  try {
    parts = format(timeZone || 'UTC');
  } catch (_error) {
    parts = format('UTC');
  }

  const lookup = {};
  for (const part of parts) {
    lookup[part.type] = part.value;
  }

  const weekdayIndex = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(
    lookup.weekday
  );
  // `hour: '2-digit'` with hour12:false renders midnight as 24 in some ICU
  // versions; normalise so minute maths cannot land a day ahead.
  const hour = Number(lookup.hour) % 24;

  return {
    dayOfWeek: weekdayIndex,
    dateKey: `${lookup.year}-${lookup.month}-${lookup.day}`,
    minutes: hour * 60 + Number(lookup.minute),
  };
};

/** Time of day a schedule row carries, in minutes since midnight. */
const scheduleMinutes = (value) => {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.getUTCHours() * 60 + date.getUTCMinutes();
};

/** Whether [start, end) sits wholly inside [windowStart, windowEnd). */
const windowContains = (windowStart, windowEnd, start, end) =>
  windowStart !== null &&
  windowEnd !== null &&
  windowStart <= start &&
  end <= windowEnd;

const overlaps = (aStart, aEnd, bStart, bEnd) => aStart < bEnd && bStart < aEnd;

const isEffectiveOn = (schedule, instant) => {
  const from = schedule.effective_from ? new Date(schedule.effective_from) : null;
  const to = schedule.effective_to ? new Date(schedule.effective_to) : null;
  if (from && instant < from) return false;
  if (to && instant > to) return false;
  return true;
};

/**
 * Leave that covers the booked window.
 *
 * Only APPROVED leave counts: a request still awaiting a decision is not yet
 * time off, and blocking on it would let anyone freeze their own diary. A
 * half day blocks only the half it names, so an afternoon clinic survives a
 * morning off.
 */
const findBlockingLeave = async ({ providerUserId, localDate, startMinutes, endMinutes }) => {
  const dayStart = new Date(`${localDate}T00:00:00.000Z`);
  const dayEnd = new Date(`${localDate}T23:59:59.999Z`);

  const leaves = await prisma.staff_leave.findMany({
    where: {
      deleted_at: null,
      status: 'APPROVED',
      start_date: { lte: dayEnd },
      end_date: { gte: dayStart },
      staff_profile: {
        deleted_at: null,
        user_id: providerUserId,
      },
    },
    select: {
      id: true,
      human_friendly_id: true,
      leave_type: true,
      is_half_day: true,
      half_day_period: true,
    },
    take: 10,
  });

  return (
    leaves.find((leave) => {
      if (!leave.is_half_day) return true;
      const period = String(leave.half_day_period || '').toUpperCase();
      if (period === 'MORNING') return startMinutes < MIDDAY_MINUTES;
      if (period === 'AFTERNOON') return endMinutes > MIDDAY_MINUTES;
      // Half day with no period recorded says nothing about which half, so it
      // is treated as the whole day rather than guessed at.
      return true;
    }) || null
  );
};

/**
 * Whether [scheduledStart, scheduledEnd) is bookable for a provider.
 *
 * Sources, in order of authority: approved leave, then a dated override for
 * that day, then the recurring weekly schedule.
 *
 * A provider with no schedule on file is available. Facilities book long
 * before anyone fills in a roster, so treating a missing schedule as "never
 * available" would refuse every booking until the roster exists; silence in
 * the data is not a statement that someone is busy.
 *
 * @returns {Promise<{available: boolean, reason?: string, detail?: Object}>}
 */
const resolveProviderAvailability = async ({
  providerUserId,
  tenantId,
  facilityId,
  scheduledStart,
  scheduledEnd,
}) => {
  if (!providerUserId || !scheduledStart || !scheduledEnd) {
    return AVAILABLE;
  }
  const start = new Date(scheduledStart);
  const end = new Date(scheduledEnd);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
    return AVAILABLE;
  }

  const schedules = await prisma.provider_schedule.findMany({
    where: {
      deleted_at: null,
      provider_user_id: providerUserId,
      ...(tenantId ? { tenant_id: tenantId } : {}),
      // A schedule kept at facility level applies to that facility; one with
      // no facility is the provider's tenant-wide roster and applies anywhere.
      ...(facilityId ? { OR: [{ facility_id: facilityId }, { facility_id: null }] } : {}),
    },
    select: {
      id: true,
      human_friendly_id: true,
      timezone: true,
      day_of_week: true,
      start_time: true,
      end_time: true,
      effective_from: true,
      effective_to: true,
      slots: {
        where: { deleted_at: null, override_date: { not: null } },
        select: {
          id: true,
          human_friendly_id: true,
          override_date: true,
          start_time: true,
          end_time: true,
          is_available: true,
        },
      },
    },
    take: 50,
  });

  if (schedules.length === 0) {
    return AVAILABLE;
  }

  const timezone = schedules[0].timezone || 'UTC';
  const startParts = zonedParts(start, timezone);
  const endParts = zonedParts(end, timezone);

  const leave = await findBlockingLeave({
    providerUserId,
    localDate: startParts.dateKey,
    startMinutes: startParts.minutes,
    endMinutes: endParts.minutes,
  });
  if (leave) {
    return {
      available: false,
      reason: UNAVAILABLE_REASONS.ON_LEAVE,
      detail: {
        leave_id: leave.human_friendly_id || leave.id,
        leave_type: leave.leave_type || null,
      },
    };
  }

  // A booking running past local midnight cannot be expressed as one window
  // on one weekday, so the weekday rules below do not describe it. Overlap
  // checks against other bookings still apply; this one steps aside rather
  // than rejecting on a rule it cannot evaluate.
  if (startParts.dateKey !== endParts.dateKey) {
    return AVAILABLE;
  }

  const startMinutes = startParts.minutes;
  const endMinutes = endParts.minutes === 0 ? MINUTES_PER_DAY : endParts.minutes;

  const dayOverrides = [];
  for (const schedule of schedules) {
    for (const slot of schedule.slots || []) {
      const overrideParts = zonedParts(
        new Date(slot.override_date),
        schedule.timezone || 'UTC'
      );
      if (overrideParts.dateKey === startParts.dateKey) {
        dayOverrides.push({ slot, schedule });
      }
    }
  }

  // A day the roster was edited by hand is the last word on that day: the
  // person who blocked out Tuesday afternoon knew about the recurring clinic.
  if (dayOverrides.length > 0) {
    const blocking = dayOverrides.find(
      ({ slot }) =>
        slot.is_available === false &&
        overlaps(
          startMinutes,
          endMinutes,
          scheduleMinutes(slot.start_time) ?? 0,
          scheduleMinutes(slot.end_time) ?? MINUTES_PER_DAY
        )
    );
    if (blocking) {
      return {
        available: false,
        reason: UNAVAILABLE_REASONS.BLOCKED_SLOT,
        detail: {
          schedule_id:
            blocking.schedule.human_friendly_id || blocking.schedule.id,
          slot_id: blocking.slot.human_friendly_id || blocking.slot.id,
        },
      };
    }

    const opened = dayOverrides.some(
      ({ slot }) =>
        slot.is_available !== false &&
        windowContains(
          scheduleMinutes(slot.start_time),
          scheduleMinutes(slot.end_time),
          startMinutes,
          endMinutes
        )
    );
    if (opened) {
      return AVAILABLE;
    }
  }

  const workingWindow = schedules.find(
    (schedule) =>
      schedule.day_of_week === startParts.dayOfWeek &&
      isEffectiveOn(schedule, start) &&
      windowContains(
        scheduleMinutes(schedule.start_time),
        scheduleMinutes(schedule.end_time),
        startMinutes,
        endMinutes
      )
  );
  if (workingWindow) {
    return AVAILABLE;
  }

  return {
    available: false,
    reason: UNAVAILABLE_REASONS.OFF_SCHEDULE,
    detail: { timezone },
  };
};

module.exports = {
  resolveProviderAvailability,
  UNAVAILABLE_REASONS,
};
