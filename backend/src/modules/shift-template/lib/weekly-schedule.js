/**
 * Shift template weekly schedule helpers.
 */
const {
  normalizeSlotList,
  slotsOverlap,
  normalizeTimeString} = require('@modules/staff-availability/lib/availability-slots');

const WEEKDAY_ORDER = Object.freeze([1, 2, 3, 4, 5, 6, 0]);
const DEFAULT_WEEKDAYS = Object.freeze([1, 2, 3, 4, 5]);

const normalizeWeeklySchedule = (days = []) => {
  if (!Array.isArray(days)) {
    return [];
  }

  const normalized = [];
  const seenDays = new Set();

  for (const entry of days) {
    const dayOfWeek = Number(entry?.day_of_week);
    if (!Number.isInteger(dayOfWeek) || dayOfWeek < 0 || dayOfWeek > 6) {
      continue;
    }
    if (seenDays.has(dayOfWeek)) {
      continue;
    }

    const timeSlots = normalizeSlotList(entry?.time_slots).filter(
      (slot) => slot.start_time && slot.end_time && slot.end_time > slot.start_time
    );
    if (!timeSlots.length) {
      continue;
    }

    seenDays.add(dayOfWeek);
    normalized.push({
      day_of_week: dayOfWeek,
      time_slots: timeSlots});
  }

  return normalized.sort(
    (left, right) => WEEKDAY_ORDER.indexOf(left.day_of_week) - WEEKDAY_ORDER.indexOf(right.day_of_week)
  );
};

const buildDefaultWeekdaySchedule = (startTime, endTime) => {
  const start = normalizeTimeString(startTime);
  const end = normalizeTimeString(endTime);
  if (!start || !end) {
    return [];
  }

  return DEFAULT_WEEKDAYS.map((dayOfWeek) => ({
    day_of_week: dayOfWeek,
    time_slots: [{ start_time: start, end_time: end }]}));
};

const parseWeeklySchedule = (record = {}) => {
  const fromJson = normalizeWeeklySchedule(record.weekly_schedule_json);
  if (fromJson.length) {
    return fromJson;
  }

  return buildDefaultWeekdaySchedule(record.default_start_time, record.default_end_time);
};

const firstSlotFromSchedule = (schedule = []) => {
  for (const day of schedule) {
    const slot = day?.time_slots?.[0];
    if (slot?.start_time && slot?.end_time) {
      return slot;
    }
  }
  return null;
};

const applyWeeklyScheduleToPayload = (payload = {}) => {
  const next = { ...payload };

  if (Array.isArray(next.weekly_schedule_json)) {
    const schedule = normalizeWeeklySchedule(next.weekly_schedule_json);
    if (!schedule.length) {
      throw new Error('weekly_schedule_invalid');
    }

    for (const day of schedule) {
      if (slotsOverlap(day.time_slots)) {
        throw new Error('weekly_schedule_overlap');
      }
    }

    next.weekly_schedule_json = schedule;
    const firstSlot = firstSlotFromSchedule(schedule);
    if (firstSlot) {
      next.default_start_time = firstSlot.start_time;
      next.default_end_time = firstSlot.end_time;
    }
    return next;
  }

  if (next.default_start_time && next.default_end_time) {
    next.weekly_schedule_json = buildDefaultWeekdaySchedule(
      next.default_start_time,
      next.default_end_time
    );
  }

  return next;
};

module.exports = {
  WEEKDAY_ORDER,
  DEFAULT_WEEKDAYS,
  normalizeWeeklySchedule,
  buildDefaultWeekdaySchedule,
  parseWeeklySchedule,
  firstSlotFromSchedule,
  applyWeeklyScheduleToPayload};
