const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelRecordByIdentifier,
  normalizeIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');

const DEFAULT_CONSTRAINTS = Object.freeze({
  max_shifts_per_nurse: null,
  max_shifts_per_week: 5,
  max_hours_per_week: 48,
  min_rest_hours: 10,
  max_consecutive_working_days: 6,
  skill_matching: false,
});

const normalizeNumber = (value) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return parsed;
};

const normalizeInt = (value) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  return Math.trunc(parsed);
};

const normalizeDate = (value) => {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date;
};

const startOfDayKey = (value) => {
  const date = normalizeDate(value);
  if (!date) return null;
  return date.toISOString().slice(0, 10);
};

const toMinutes = (timeText) => {
  const text = String(timeText || '').trim();
  if (!text) return null;
  const parts = text.split(':').map((part) => Number(part));
  if (parts.length < 2 || parts.some((part) => !Number.isFinite(part))) return null;
  return parts[0] * 60 + parts[1];
};

const getDayOfWeekUtc = (value) => {
  const date = normalizeDate(value);
  if (!date) return null;
  return date.getUTCDay();
};

const getMinutesFromDateUtc = (value) => {
  const date = normalizeDate(value);
  if (!date) return null;
  return date.getUTCHours() * 60 + date.getUTCMinutes();
};

const hoursBetween = (from, to) => {
  const fromDate = normalizeDate(from);
  const toDate = normalizeDate(to);
  if (!fromDate || !toDate) return 0;
  return (toDate.getTime() - fromDate.getTime()) / (1000 * 60 * 60);
};

const overlaps = (leftStart, leftEnd, rightStart, rightEnd) => {
  const leftStartDate = normalizeDate(leftStart);
  const leftEndDate = normalizeDate(leftEnd);
  const rightStartDate = normalizeDate(rightStart);
  const rightEndDate = normalizeDate(rightEnd);

  if (!leftStartDate || !leftEndDate || !rightStartDate || !rightEndDate) return false;
  return leftStartDate.getTime() < rightEndDate.getTime() && rightStartDate.getTime() < leftEndDate.getTime();
};

const weekKeyUtc = (value) => {
  const date = normalizeDate(value);
  if (!date) return null;

  const utc = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = utc.getUTCDay() || 7;
  utc.setUTCDate(utc.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(utc.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil((((utc - yearStart) / 86400000) + 1) / 7);
  return `${utc.getUTCFullYear()}-W${String(weekNo).padStart(2, '0')}`;
};

const normalizeConstraints = (rosterConstraints = {}, overrideConstraints = {}) => {
  const merged = {
    ...DEFAULT_CONSTRAINTS,
    ...(rosterConstraints && typeof rosterConstraints === 'object' ? rosterConstraints : {}),
    ...(overrideConstraints && typeof overrideConstraints === 'object' ? overrideConstraints : {}),
  };

  return {
    max_shifts_per_nurse: normalizeInt(merged.max_shifts_per_nurse),
    max_shifts_per_week: normalizeInt(merged.max_shifts_per_week),
    max_hours_per_week: normalizeNumber(merged.max_hours_per_week),
    min_rest_hours: normalizeNumber(merged.min_rest_hours),
    max_consecutive_working_days: normalizeInt(merged.max_consecutive_working_days),
    skill_matching: Boolean(merged.skill_matching),
  };
};

const resolveDisplayId = (record = {}) =>
  resolvePublicIdentifier(record.display_id, record.human_friendly_id, record.id) || null;

const resolveRecordOrThrow = async ({ model, identifier, where = {}, errorKey }) => {
  const record = await resolveModelRecordByIdentifier({
    model,
    identifier,
    where,
    includeDeleted: false,
    select: { id: true, human_friendly_id: true },
  });

  if (!record?.id) {
    throw new HttpError(errorKey, 404);
  }

  return record;
};

const resolveRosterOrThrow = async (rosterIdentifier) => {
  const rosterRecord = await resolveModelRecordByIdentifier({
    model: 'nurse_roster',
    identifier: rosterIdentifier,
    where: { deleted_at: null },
    include: {
      facility: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
        },
      },
      department: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
        },
      },
      tenant: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
        },
      },
    },
  });

  if (!rosterRecord?.id) {
    throw new HttpError('errors.nurse_roster.not_found', 404);
  }

  return rosterRecord;
};

const listRosterShifts = async (rosterId, periodStart, periodEnd) =>
  prisma.shift.findMany({
    where: {
      deleted_at: null,
      nurse_roster_id: rosterId,
      status: {
        not: 'CANCELLED',
      },
      start_time: {
        gte: periodStart,
        lte: periodEnd,
      },
    },
    include: {
      assignments: {
        where: {
          deleted_at: null,
        },
        include: {
          staff_profile: {
            select: {
              id: true,
              human_friendly_id: true,
              department_id: true,
              staff_number: true,
              position: true,
            },
          },
        },
        orderBy: {
          assigned_at: 'asc',
        },
      },
    },
    orderBy: {
      start_time: 'asc',
    },
  });

const listCandidateProfiles = async (roster) => {
  const where = {
    deleted_at: null,
    tenant_id: roster.tenant_id,
  };

  return prisma.staff_profile.findMany({
    where,
    include: {
      user: {
        select: {
          id: true,
          human_friendly_id: true,
          first_name: true,
          last_name: true,
          email: true,
        },
      },
      department: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
        },
      },
    },
  });
};

const listAvailability = async (profileIds, periodStart, periodEnd) => {
  if (!Array.isArray(profileIds) || !profileIds.length) return [];

  return prisma.staff_availability.findMany({
    where: {
      deleted_at: null,
      staff_profile_id: {
        in: profileIds,
      },
      effective_from: {
        lte: periodEnd,
      },
      OR: [
        { effective_to: null },
        {
          effective_to: {
            gte: periodStart,
          },
        },
      ],
    },
  });
};

const listApprovedLeaves = async (profileIds, periodStart, periodEnd) => {
  if (!Array.isArray(profileIds) || !profileIds.length) return [];

  return prisma.staff_leave.findMany({
    where: {
      deleted_at: null,
      status: 'APPROVED',
      staff_profile_id: {
        in: profileIds,
      },
      start_date: {
        lte: periodEnd,
      },
      end_date: {
        gte: periodStart,
      },
    },
  });
};

const listDayOffs = async (profileIds, rosterId) => {
  if (!Array.isArray(profileIds) || !profileIds.length) return [];

  return prisma.roster_day_off.findMany({
    where: {
      deleted_at: null,
      nurse_roster_id: rosterId,
      staff_profile_id: {
        in: profileIds,
      },
    },
  });
};

const listExistingAssignments = async (profileIds, periodStart, periodEnd) => {
  if (!Array.isArray(profileIds) || !profileIds.length) return [];

  return prisma.shift_assignment.findMany({
    where: {
      deleted_at: null,
      staff_profile_id: {
        in: profileIds,
      },
      shift: {
        deleted_at: null,
        start_time: {
          lte: periodEnd,
        },
        end_time: {
          gte: periodStart,
        },
      },
    },
    include: {
      shift: {
        select: {
          id: true,
          human_friendly_id: true,
          start_time: true,
          end_time: true,
          nurse_roster_id: true,
        },
      },
    },
  });
};

const mapRosterShift = (shift) => ({
  id: shift.id,
  display_id: resolveDisplayId(shift),
  shift_type: shift.shift_type,
  status: shift.status,
  start_time: shift.start_time,
  end_time: shift.end_time,
  assignments: (shift.assignments || []).map((assignment) => ({
    id: assignment.id,
    display_id: resolveDisplayId(assignment),
    staff_profile_id: assignment.staff_profile_id,
    staff_profile_display_id: resolveDisplayId(assignment.staff_profile || {}),
    staff_number: assignment.staff_profile?.staff_number || null,
    staff_position: assignment.staff_profile?.position || null,
    assigned_at: assignment.assigned_at,
  })),
});

const buildRosterCoverage = (shifts = []) => {
  const totalShifts = shifts.length;
  const assignedShifts = shifts.filter((shift) => Array.isArray(shift.assignments) && shift.assignments.length > 0).length;
  const unassignedShifts = Math.max(0, totalShifts - assignedShifts);

  return {
    total_shifts: totalShifts,
    assigned_shifts: assignedShifts,
    unassigned_shifts: unassignedShifts,
    assignment_ratio: totalShifts > 0 ? Number((assignedShifts / totalShifts).toFixed(4)) : 0,
  };
};

const buildWeeklyMetrics = (intervals, targetWeekKey) => {
  const scoped = intervals.filter((entry) => weekKeyUtc(entry.start_time) === targetWeekKey);
  const shifts = scoped.length;
  const hours = scoped.reduce((sum, entry) => sum + Math.max(0, hoursBetween(entry.start_time, entry.end_time)), 0);
  return {
    shifts,
    hours,
  };
};

const calculateConsecutiveSpan = (dayKeys = [], candidateDayKey) => {
  const set = new Set(dayKeys.filter(Boolean));
  if (candidateDayKey) set.add(candidateDayKey);
  const values = Array.from(set).sort();
  if (!values.length || !candidateDayKey) return 0;

  const index = values.indexOf(candidateDayKey);
  if (index === -1) return 0;

  let span = 1;

  for (let left = index - 1; left >= 0; left -= 1) {
    const previous = new Date(`${values[left]}T00:00:00.000Z`);
    const current = new Date(`${values[left + 1]}T00:00:00.000Z`);
    const diff = (current.getTime() - previous.getTime()) / 86400000;
    if (diff !== 1) break;
    span += 1;
  }

  for (let right = index + 1; right < values.length; right += 1) {
    const previous = new Date(`${values[right - 1]}T00:00:00.000Z`);
    const current = new Date(`${values[right]}T00:00:00.000Z`);
    const diff = (current.getTime() - previous.getTime()) / 86400000;
    if (diff !== 1) break;
    span += 1;
  }

  return span;
};

const canPassAvailability = (records, shift) => {
  if (!Array.isArray(records) || !records.length) {
    return { allowed: true, preferred: false };
  }

  const shiftStart = normalizeDate(shift.start_time);
  const shiftEnd = normalizeDate(shift.end_time);
  if (!shiftStart || !shiftEnd) {
    return { allowed: true, preferred: false };
  }

  const dayOfWeek = getDayOfWeekUtc(shiftStart);
  const shiftStartMinutes = getMinutesFromDateUtc(shiftStart);
  const shiftEndMinutes = getMinutesFromDateUtc(shiftEnd);
  const shiftDayKey = startOfDayKey(shiftStart);

  let preferred = false;
  let seenRelevant = false;

  for (const record of records) {
    if (normalizeInt(record.day_of_week) !== dayOfWeek) continue;

    const effectiveFrom = normalizeDate(record.effective_from);
    const effectiveTo = normalizeDate(record.effective_to);
    if (effectiveFrom && shiftEnd.getTime() < effectiveFrom.getTime()) continue;
    if (effectiveTo && shiftStart.getTime() > effectiveTo.getTime()) continue;

    const recordStartMinutes = toMinutes(record.start_time);
    const recordEndMinutes = toMinutes(record.end_time);
    if (recordStartMinutes == null || recordEndMinutes == null) continue;

    const isOverlap = shiftStartMinutes < recordEndMinutes && recordStartMinutes < shiftEndMinutes;
    if (!isOverlap) continue;

    seenRelevant = true;
    const preference = String(record.preference || '').trim().toUpperCase();

    if (preference === 'UNAVAILABLE') {
      return {
        allowed: false,
        preferred: false,
        reason: `availability_unavailable_${shiftDayKey || 'day'}`,
      };
    }

    if (preference === 'PREFERRED') {
      preferred = true;
    }
  }

  if (!seenRelevant) {
    return { allowed: true, preferred: false };
  }

  return { allowed: true, preferred };
};

const hasLeaveConflict = (records, shift) =>
  (records || []).some((entry) => overlaps(entry.start_date, entry.end_date, shift.start_time, shift.end_time));

const hasDayOffConflict = (records, shift) => {
  const shiftDay = startOfDayKey(shift.start_time);
  if (!shiftDay) return false;

  return (records || []).some((entry) => startOfDayKey(entry.off_date) === shiftDay);
};

const hasOverlapConflict = (intervals, shift) =>
  (intervals || []).some((entry) => overlaps(entry.start_time, entry.end_time, shift.start_time, shift.end_time));

const hasRestConflict = (intervals, shift, minRestHours) => {
  if (!Number.isFinite(minRestHours) || minRestHours <= 0) return false;

  const shiftStart = normalizeDate(shift.start_time);
  const shiftEnd = normalizeDate(shift.end_time);
  if (!shiftStart || !shiftEnd) return false;

  return (intervals || []).some((entry) => {
    const entryStart = normalizeDate(entry.start_time);
    const entryEnd = normalizeDate(entry.end_time);
    if (!entryStart || !entryEnd) return false;

    const hoursAfter = hoursBetween(entryEnd, shiftStart);
    if (hoursAfter >= 0 && hoursAfter < minRestHours) {
      return true;
    }

    const hoursBefore = hoursBetween(shiftEnd, entryStart);
    if (hoursBefore >= 0 && hoursBefore < minRestHours) {
      return true;
    }

    return false;
  });
};

const buildProfileState = ({ profiles, availability, leaves, dayOffs, existingAssignments }) => {
  const availabilityMap = new Map();
  const leaveMap = new Map();
  const dayOffMap = new Map();
  const assignmentMap = new Map();

  for (const profile of profiles) {
    availabilityMap.set(profile.id, []);
    leaveMap.set(profile.id, []);
    dayOffMap.set(profile.id, []);
    assignmentMap.set(profile.id, []);
  }

  for (const entry of availability) {
    if (!availabilityMap.has(entry.staff_profile_id)) continue;
    availabilityMap.get(entry.staff_profile_id).push(entry);
  }

  for (const entry of leaves) {
    if (!leaveMap.has(entry.staff_profile_id)) continue;
    leaveMap.get(entry.staff_profile_id).push(entry);
  }

  for (const entry of dayOffs) {
    if (!dayOffMap.has(entry.staff_profile_id)) continue;
    dayOffMap.get(entry.staff_profile_id).push(entry);
  }

  for (const entry of existingAssignments) {
    const profileId = entry.staff_profile_id;
    if (!assignmentMap.has(profileId) || !entry.shift) continue;
    assignmentMap.get(profileId).push({
      assignment_id: entry.id,
      shift_id: entry.shift_id,
      start_time: entry.shift.start_time,
      end_time: entry.shift.end_time,
      roster_id: entry.shift.nurse_roster_id,
      source: 'existing',
    });
  }

  for (const intervals of assignmentMap.values()) {
    intervals.sort((a, b) => new Date(a.start_time).getTime() - new Date(b.start_time).getTime());
  }

  return {
    availabilityMap,
    leaveMap,
    dayOffMap,
    assignmentMap,
  };
};

const pickBestCandidate = ({
  shift,
  roster,
  profiles,
  state,
  constraints,
}) => {
  const candidateScores = [];

  const shiftWeekKey = weekKeyUtc(shift.start_time);
  const shiftDayKey = startOfDayKey(shift.start_time);

  for (const profile of profiles) {
    const profileIntervals = state.assignmentMap.get(profile.id) || [];

    if (hasLeaveConflict(state.leaveMap.get(profile.id), shift)) {
      continue;
    }

    if (hasDayOffConflict(state.dayOffMap.get(profile.id), shift)) {
      continue;
    }

    const availabilityResult = canPassAvailability(state.availabilityMap.get(profile.id), shift);
    if (!availabilityResult.allowed) {
      continue;
    }

    if (hasOverlapConflict(profileIntervals, shift)) {
      continue;
    }

    if (hasRestConflict(profileIntervals, shift, constraints.min_rest_hours)) {
      continue;
    }

    if (constraints.max_shifts_per_nurse && profileIntervals.length >= constraints.max_shifts_per_nurse) {
      continue;
    }

    if (constraints.max_shifts_per_week && shiftWeekKey) {
      const weekly = buildWeeklyMetrics(profileIntervals, shiftWeekKey);
      if (weekly.shifts >= constraints.max_shifts_per_week) {
        continue;
      }
    }

    if (constraints.max_hours_per_week && shiftWeekKey) {
      const weekly = buildWeeklyMetrics(profileIntervals, shiftWeekKey);
      const nextHours = weekly.hours + Math.max(0, hoursBetween(shift.start_time, shift.end_time));
      if (nextHours > constraints.max_hours_per_week) {
        continue;
      }
    }

    if (constraints.max_consecutive_working_days && shiftDayKey) {
      const dayKeys = profileIntervals.map((entry) => startOfDayKey(entry.start_time)).filter(Boolean);
      const consecutiveLength = calculateConsecutiveSpan(dayKeys, shiftDayKey);
      if (consecutiveLength > constraints.max_consecutive_working_days) {
        continue;
      }
    }

    let score = 0;

    if (roster.department_id && profile.department_id && roster.department_id === profile.department_id) {
      score += 60;
    }

    if (availabilityResult.preferred) {
      score += 25;
    }

    const weekly = shiftWeekKey ? buildWeeklyMetrics(profileIntervals, shiftWeekKey) : { shifts: 0 };
    score -= weekly.shifts * 8;

    if (shiftDayKey) {
      const dayKeys = profileIntervals.map((entry) => startOfDayKey(entry.start_time)).filter(Boolean);
      const streak = calculateConsecutiveSpan(dayKeys, shiftDayKey);
      score -= Math.max(0, streak - 1) * 4;
    }

    const lastAssignedAt = profileIntervals.length
      ? profileIntervals[profileIntervals.length - 1].end_time
      : null;

    candidateScores.push({
      profile,
      score,
      last_assigned_at: lastAssignedAt,
      weekly_shift_count: weekly.shifts,
    });
  }

  if (!candidateScores.length) return null;

  candidateScores.sort((left, right) => {
    if (right.score !== left.score) return right.score - left.score;

    const leftTime = left.last_assigned_at ? new Date(left.last_assigned_at).getTime() : Number.NEGATIVE_INFINITY;
    const rightTime = right.last_assigned_at ? new Date(right.last_assigned_at).getTime() : Number.NEGATIVE_INFINITY;

    if (leftTime !== rightTime) return leftTime - rightTime;
    return String(left.profile.id).localeCompare(String(right.profile.id));
  });

  return candidateScores[0];
};

const buildWorkflow = async (rosterIdentifier) => {
  const roster = await resolveRosterOrThrow(rosterIdentifier);

  const shifts = await listRosterShifts(roster.id, roster.period_start, roster.period_end);
  const mappedShifts = shifts.map(mapRosterShift);
  const coverage = buildRosterCoverage(shifts);

  const gaps = shifts
    .filter((shift) => !Array.isArray(shift.assignments) || shift.assignments.length === 0)
    .map((shift) => ({
      shift_id: shift.id,
      shift_display_id: resolveDisplayId(shift),
      shift_type: shift.shift_type,
      start_time: shift.start_time,
      end_time: shift.end_time,
      reason: 'UNASSIGNED',
    }));

  return {
    roster: {
      id: roster.id,
      display_id: resolveDisplayId(roster),
      tenant_id: roster.tenant_id,
      tenant_display_id: resolveDisplayId(roster.tenant || {}),
      facility_id: roster.facility_id,
      facility_display_id: resolveDisplayId(roster.facility || {}),
      department_id: roster.department_id,
      department_display_id: resolveDisplayId(roster.department || {}),
      period_start: roster.period_start,
      period_end: roster.period_end,
      status: roster.status,
      published_at: roster.published_at,
      constraints: roster.constraints || null,
    },
    shifts: mappedShifts,
    assignments: mappedShifts.flatMap((shift) => shift.assignments.map((assignment) => ({ ...assignment, shift_id: shift.id }))),
    gaps,
    coverage,
  };
};

const generateRosterAssignments = async ({
  rosterIdentifier,
  constraints: constraintsOverride = {},
  replaceExistingAssignments = true,
  dryRun = false,
  userId = null,
  ipAddress = null,
}) => {
  const normalizedRosterIdentifier = normalizeIdentifier(rosterIdentifier);
  const roster = await resolveRosterOrThrow(normalizedRosterIdentifier);

  if (roster.status === 'PUBLISHED') {
    throw new HttpError('errors.nurse_roster.cannot_generate_published', 400);
  }

  const periodStart = normalizeDate(roster.period_start);
  const periodEnd = normalizeDate(roster.period_end);

  const constraints = normalizeConstraints(roster.constraints, constraintsOverride);

  const [shifts, profiles] = await Promise.all([
    listRosterShifts(roster.id, periodStart, periodEnd),
    listCandidateProfiles(roster),
  ]);

  const profileIds = profiles.map((profile) => profile.id);

  const [availability, approvedLeaves, dayOffs, existingAssignments] = await Promise.all([
    listAvailability(profileIds, periodStart, periodEnd),
    listApprovedLeaves(profileIds, periodStart, periodEnd),
    listDayOffs(profileIds, roster.id),
    listExistingAssignments(profileIds, periodStart, periodEnd),
  ]);

  const state = buildProfileState({
    profiles,
    availability,
    leaves: approvedLeaves,
    dayOffs,
    existingAssignments,
  });

  const shiftsToGenerate = shifts.filter((shift) => {
    const hasAssignment = Array.isArray(shift.assignments) && shift.assignments.length > 0;
    return replaceExistingAssignments || !hasAssignment;
  });

  const baselineAssignedShifts = shifts.length - shiftsToGenerate.length;

  const plannedAssignments = [];
  const unassignedShifts = [];

  for (const shift of shiftsToGenerate) {
    const picked = pickBestCandidate({
      shift,
      roster,
      profiles,
      state,
      constraints,
    });

    if (!picked?.profile) {
      unassignedShifts.push({
        shift_id: shift.id,
        shift_display_id: resolveDisplayId(shift),
        shift_type: shift.shift_type,
        start_time: shift.start_time,
        end_time: shift.end_time,
        reason: 'NO_ELIGIBLE_CANDIDATE',
      });
      continue;
    }

    const entry = {
      shift_id: shift.id,
      shift_display_id: resolveDisplayId(shift),
      staff_profile_id: picked.profile.id,
      staff_profile_display_id: resolveDisplayId(picked.profile),
      staff_number: picked.profile.staff_number || null,
      score: picked.score,
      assigned_at: new Date(),
    };

    plannedAssignments.push(entry);

    state.assignmentMap.get(picked.profile.id).push({
      assignment_id: null,
      shift_id: shift.id,
      start_time: shift.start_time,
      end_time: shift.end_time,
      roster_id: roster.id,
      source: 'planned',
    });

    state.assignmentMap.get(picked.profile.id).sort((left, right) =>
      new Date(left.start_time).getTime() - new Date(right.start_time).getTime()
    );
  }

  if (!dryRun) {
    await prisma.$transaction(async (tx) => {
      if (replaceExistingAssignments && shifts.length > 0) {
        await tx.shift_assignment.updateMany({
          where: {
            deleted_at: null,
            shift_id: {
              in: shifts.map((shift) => shift.id),
            },
          },
          data: {
            deleted_at: new Date(),
          },
        });
      }

      if (plannedAssignments.length > 0) {
        await tx.shift_assignment.createMany({
          data: plannedAssignments.map((entry) => ({
            shift_id: entry.shift_id,
            staff_profile_id: entry.staff_profile_id,
            assigned_at: entry.assigned_at,
          })),
        });
      }

      await tx.nurse_roster.update({
        where: { id: roster.id },
        data: {
          status: 'DRAFT',
          published_at: null,
          constraints,
        },
      });
    });
  }

  const totalShifts = shifts.length;
  const newlyAssignedShifts = plannedAssignments.length;
  const assignedShifts = baselineAssignedShifts + newlyAssignedShifts;
  const coverage = {
    total_shifts: totalShifts,
    assigned_shifts: assignedShifts,
    unassigned_shifts: Math.max(0, totalShifts - assignedShifts),
    assignment_ratio: totalShifts > 0 ? Number((assignedShifts / totalShifts).toFixed(4)) : 0,
  };

  createAuditLog({
    user_id: userId,
    action: 'UPDATE',
    entity: 'nurse_roster',
    entity_id: roster.id,
    tenant_id: roster.tenant_id,
    diff: {
      metadata: {
        operation: 'AUTO_GENERATE_ROSTER',
        dry_run: Boolean(dryRun),
        replace_existing_assignments: Boolean(replaceExistingAssignments),
        constraints,
        generation_summary: {
          total_shifts: totalShifts,
          assigned_shifts: assignedShifts,
          planned_assignments: newlyAssignedShifts,
          unassigned_shifts: coverage.unassigned_shifts,
        },
      },
    },
    ip_address: ipAddress,
  }).catch(() => {});

  return {
    roster: {
      id: roster.id,
      display_id: resolveDisplayId(roster),
      tenant_id: roster.tenant_id,
      facility_id: roster.facility_id,
      department_id: roster.department_id,
      status: 'DRAFT',
      period_start: roster.period_start,
      period_end: roster.period_end,
      constraints,
    },
    generation_summary: {
      dry_run: Boolean(dryRun),
      replace_existing_assignments: Boolean(replaceExistingAssignments),
      total_shifts: totalShifts,
      existing_assigned_kept: baselineAssignedShifts,
      newly_assigned: newlyAssignedShifts,
      unassigned: coverage.unassigned_shifts,
    },
    coverage,
    assignments: plannedAssignments,
    unassigned_shifts: unassignedShifts,
  };
};

module.exports = {
  buildWorkflow,
  generateRosterAssignments,
  resolveRecordOrThrow,
  resolveDisplayId,
};
