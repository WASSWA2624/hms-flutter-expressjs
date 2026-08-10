/**
 * Roster template duplicate / similarity helpers.
 *
 * Tenant-scoped weighted similarity across name, facility, department,
 * recurring flag, period overlap, month-day coverage, and weekly schedule.
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  textSimilarityScore,
} = require('@lib/tenant/tenant-similarity');
const {
  normalizeWeeklySchedule,
} = require('@modules/shift-template/lib/weekly-schedule');

const NAME_WEIGHT = 40;
const FACILITY_WEIGHT = 10;
const DEPARTMENT_WEIGHT = 15;
const RECURRING_WEIGHT = 10;
const PERIOD_WEIGHT = 10;
const MONTH_DAYS_WEIGHT = 10;
const SCHEDULE_WEIGHT = 15;

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const toDateKey = (value) => {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString().slice(0, 10);
};

const normalizeMonthDays = (value) => {
  if (!Array.isArray(value)) return [];
  return [
    ...new Set(
      value
        .map((day) => Number(day))
        .filter((day) => Number.isInteger(day) && day >= 1 && day <= 31)
    ),
  ].sort((a, b) => a - b);
};

const scheduleFingerprint = (constraints = {}) => {
  const weekly = normalizeWeeklySchedule(constraints.weekly_schedule_json);
  if (weekly.length) {
    return JSON.stringify(weekly);
  }
  const workingDays = Array.isArray(constraints.working_days)
    ? [...constraints.working_days].map(String).sort()
    : [];
  return JSON.stringify({
    working_days: workingDays,
    start: constraints.default_start_time || null,
    end: constraints.default_end_time || null,
    respect_weekends: constraints.respect_weekends !== false,
    respect_public_holidays: constraints.respect_public_holidays !== false,
  });
};

const periodOverlapRatio = (leftStart, leftEnd, rightStart, rightEnd) => {
  const aStart = new Date(leftStart).getTime();
  const aEnd = new Date(leftEnd).getTime();
  const bStart = new Date(rightStart).getTime();
  const bEnd = new Date(rightEnd).getTime();
  if ([aStart, aEnd, bStart, bEnd].some((value) => Number.isNaN(value))) {
    return null;
  }
  if (aEnd <= aStart || bEnd <= bStart) return 0;
  const overlapStart = Math.max(aStart, bStart);
  const overlapEnd = Math.min(aEnd, bEnd);
  if (overlapEnd <= overlapStart) return 0;
  const overlap = overlapEnd - overlapStart;
  const shorter = Math.min(aEnd - aStart, bEnd - bStart);
  if (shorter <= 0) return 0;
  return Math.round((overlap / shorter) * 100);
};

const monthDaysScore = (leftDays, rightDays) => {
  if (!leftDays.length && !rightDays.length) return 100;
  if (!leftDays.length || !rightDays.length) return 0;
  const left = new Set(leftDays);
  const right = new Set(rightDays);
  let intersection = 0;
  for (const day of left) {
    if (right.has(day)) intersection += 1;
  }
  const union = new Set([...left, ...right]).size;
  if (!union) return 0;
  return Math.round((intersection / union) * 100);
};

const buildCandidateSnapshot = (roster) => {
  const constraints =
    roster?.constraints && typeof roster.constraints === 'object'
      ? roster.constraints
      : {};
  return {
    id: roster?.id || null,
    human_friendly_id: roster?.human_friendly_id || null,
    display_id:
      roster?.display_id || roster?.human_friendly_id || roster?.id || null,
    tenant_id: roster?.tenant_id || null,
    facility_id: roster?.facility_id || null,
    department_id: roster?.department_id || null,
    name: roster?.name || null,
    is_recurring: Boolean(roster?.is_recurring),
    status: roster?.status || null,
    period_start: toDateKey(roster?.period_start),
    period_end: toDateKey(roster?.period_end),
    month_days: normalizeMonthDays(constraints.month_days),
    respect_weekends: constraints.respect_weekends !== false,
    respect_public_holidays: constraints.respect_public_holidays !== false,
    schedule_fingerprint: scheduleFingerprint(constraints),
  };
};

const compositeSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.nameScore, NAME_WEIGHT],
    [scores.facilityScore, FACILITY_WEIGHT],
    [scores.departmentScore, DEPARTMENT_WEIGHT],
    [scores.recurringScore, RECURRING_WEIGHT],
    [scores.periodScore, PERIOD_WEIGHT],
    [scores.monthDaysScore, MONTH_DAYS_WEIGHT],
    [scores.scheduleScore, SCHEDULE_WEIGHT],
  ];

  let weightedTotal = 0;
  let weightSum = 0;
  for (const [score, weight] of weighted) {
    if (score == null) continue;
    weightedTotal += score * weight;
    weightSum += weight;
  }
  if (!weightSum) return 0;
  return Math.round(weightedTotal / weightSum);
};

const buildFieldComparison = ({
  field,
  inputValue,
  candidateValue,
  score,
  exact = false,
}) => ({
  field,
  input_value:
    inputValue == null || inputValue === '' ? null : String(inputValue),
  candidate_value:
    candidateValue == null || candidateValue === ''
      ? null
      : String(candidateValue),
  score: score == null ? null : score,
  status: comparisonStatus(score, { exact }),
});

/** True when every compared parameter scores 100 (identical template). */
const isRosterFullExactDuplicate = (match = {}) => {
  const scores = [
    match.nameScore,
    match.facilityScore,
    match.departmentScore,
    match.recurringScore,
    match.periodScore,
    match.monthDaysScore,
    match.scheduleScore,
  ].filter((score) => score != null);
  if (scores.length < 2) {
    return false;
  }
  return scores.every((score) => score === 100);
};

/**
 * @param {Object} params
 * @param {string} params.name
 * @param {string|null|undefined} params.facilityId
 * @param {string|null|undefined} params.departmentId
 * @param {boolean} params.isRecurring
 * @param {string|Date} params.periodStart
 * @param {string|Date} params.periodEnd
 * @param {Object} [params.constraints]
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeRosterId]
 */
const checkRosterDuplicates = ({
  name,
  facilityId = null,
  departmentId = null,
  isRecurring = false,
  periodStart,
  periodEnd,
  constraints = {},
  existing = [],
  excludeRosterId = null,
}) => {
  const normalizedName = normalizeText(name);
  const normalizedFacility = String(facilityId || '').trim();
  const normalizedDepartment = String(departmentId || '').trim();
  const inputMonthDays = normalizeMonthDays(constraints.month_days);
  const inputFingerprint = scheduleFingerprint(constraints);
  const excludeId = String(excludeRosterId || '').trim();

  let exactNameConflict = false;
  const matches = [];

  for (const roster of existing) {
    const snapshot = buildCandidateSnapshot(roster);
    const rosterId = String(snapshot.id || '').trim();
    const rosterFriendly = String(snapshot.human_friendly_id || '').trim();
    const rosterDisplay = String(snapshot.display_id || '').trim();
    if (
      excludeId &&
      (rosterId === excludeId ||
        rosterFriendly === excludeId ||
        rosterDisplay === excludeId)
    ) {
      continue;
    }

    const rosterName = normalizeText(snapshot.name);
    const nameExact =
      Boolean(normalizedName) && Boolean(rosterName) && rosterName === normalizedName;

    let nameScore = null;
    let facilityScore = null;
    let departmentScore = null;
    let recurringScore = null;
    let periodScore = null;
    let daysScore = null;
    let scheduleScore = null;
    const reasons = [];

    if (normalizedName && rosterName) {
      nameScore = nameExact
        ? 100
        : textSimilarityScore(normalizedName, rosterName);
      if (nameExact || nameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('name');
      }
    }

    if (normalizedFacility || snapshot.facility_id) {
      const sameFacility =
        Boolean(normalizedFacility) &&
        normalizedFacility === String(snapshot.facility_id || '').trim();
      facilityScore = sameFacility ? 100 : 0;
      if (sameFacility) reasons.push('facility');
    }

    if (normalizedDepartment || snapshot.department_id) {
      const sameDepartment =
        Boolean(normalizedDepartment) &&
        normalizedDepartment === String(snapshot.department_id || '').trim();
      // Both null/empty ("all departments") counts as a match.
      const bothOpen =
        !normalizedDepartment && !String(snapshot.department_id || '').trim();
      departmentScore = sameDepartment || bothOpen ? 100 : 0;
      if (sameDepartment || bothOpen) reasons.push('department');
    }

    recurringScore = Boolean(isRecurring) === Boolean(snapshot.is_recurring) ? 100 : 0;
    if (recurringScore === 100) reasons.push('is_recurring');

    if (!isRecurring && !snapshot.is_recurring) {
      periodScore = periodOverlapRatio(
        periodStart,
        periodEnd,
        snapshot.period_start,
        snapshot.period_end
      );
      if (periodScore != null && periodScore >= SIMILARITY_THRESHOLD) {
        reasons.push('period');
      }
    } else if (isRecurring && snapshot.is_recurring) {
      periodScore = 100;
      reasons.push('period');
    }

    daysScore = monthDaysScore(inputMonthDays, snapshot.month_days);
    if (daysScore >= SIMILARITY_THRESHOLD) reasons.push('month_days');

    scheduleScore =
      inputFingerprint && snapshot.schedule_fingerprint
        ? inputFingerprint === snapshot.schedule_fingerprint
          ? 100
          : textSimilarityScore(inputFingerprint, snapshot.schedule_fingerprint)
        : null;
    if (scheduleScore != null && scheduleScore >= SIMILARITY_THRESHOLD) {
      reasons.push('weekly_schedule');
    }

    const score = compositeSimilarityScore({
      nameScore,
      facilityScore,
      departmentScore,
      recurringScore,
      periodScore,
      monthDaysScore: daysScore,
      scheduleScore,
    });

    const fieldComparisons = [
      buildFieldComparison({
        field: 'name',
        inputValue: name,
        candidateValue: snapshot.name,
        score: nameScore,
        exact: nameExact,
      }),
      buildFieldComparison({
        field: 'facility_id',
        inputValue: facilityId,
        candidateValue: snapshot.facility_id,
        score: facilityScore,
        exact: facilityScore === 100,
      }),
      buildFieldComparison({
        field: 'department_id',
        inputValue: departmentId || 'ALL',
        candidateValue: snapshot.department_id || 'ALL',
        score: departmentScore,
        exact: departmentScore === 100,
      }),
      buildFieldComparison({
        field: 'is_recurring',
        inputValue: isRecurring ? 'true' : 'false',
        candidateValue: snapshot.is_recurring ? 'true' : 'false',
        score: recurringScore,
        exact: recurringScore === 100,
      }),
      buildFieldComparison({
        field: 'period',
        inputValue: `${toDateKey(periodStart) || ''}–${toDateKey(periodEnd) || ''}`,
        candidateValue: `${snapshot.period_start || ''}–${snapshot.period_end || ''}`,
        score: periodScore,
        exact: periodScore === 100,
      }),
      buildFieldComparison({
        field: 'month_days',
        inputValue: inputMonthDays.join(','),
        candidateValue: snapshot.month_days.join(','),
        score: daysScore,
        exact: daysScore === 100,
      }),
      buildFieldComparison({
        field: 'weekly_schedule',
        inputValue: inputFingerprint,
        candidateValue: snapshot.schedule_fingerprint,
        score: scheduleScore,
        exact: scheduleScore === 100,
      }),
      buildFieldComparison({
        field: 'display_id',
        inputValue: null,
        candidateValue: snapshot.display_id,
        score: null,
        exact: false,
      }),
    ].filter((entry) => entry.input_value != null || entry.candidate_value != null);

    // Exact name in same tenant is always a hard conflict when facility aligns
    // (or either facility is open / same).
    const facilityAligned =
      !normalizedFacility ||
      !snapshot.facility_id ||
      normalizedFacility === String(snapshot.facility_id || '').trim();
    if (nameExact && facilityAligned) {
      exactNameConflict = true;
    }

    const isExact = nameExact && facilityAligned;
    const strongIdentitySignal =
      (nameScore != null && nameScore >= SIMILARITY_THRESHOLD) ||
      (scheduleScore === 100 &&
        departmentScore === 100 &&
        recurringScore === 100);
    const compositeSignal = score >= SIMILARITY_THRESHOLD;

    if (!isExact && !strongIdentitySignal && !compositeSignal) {
      continue;
    }

    const match = {
      ...snapshot,
      score,
      reasons: reasons.length ? reasons : ['name'],
      isExact,
      exactNameConflict: nameExact && facilityAligned,
      nameScore,
      facilityScore,
      departmentScore,
      recurringScore,
      periodScore,
      monthDaysScore: daysScore,
      scheduleScore,
      field_comparisons: fieldComparisons,
    };
    match.isFullExactDuplicate = isRosterFullExactDuplicate(match);
    matches.push(match);
  }

  matches.sort((left, right) => right.score - left.score);

  const blockingMatches = matches.filter((match) => match.isFullExactDuplicate);
  return {
    exactNameConflict,
    hasExactConflict: exactNameConflict,
    hasFullExactDuplicate: blockingMatches.length > 0,
    similarMatches: matches,
    nonExactSimilarMatches: matches.filter((match) => !match.isExact),
    // Name-only exact matches remain overridable when other parameters differ.
    overridableMatches: matches.filter((match) => !match.isFullExactDuplicate),
    blockingMatches,
  };
};

module.exports = {
  SIMILARITY_THRESHOLD,
  NAME_WEIGHT,
  FACILITY_WEIGHT,
  DEPARTMENT_WEIGHT,
  RECURRING_WEIGHT,
  PERIOD_WEIGHT,
  MONTH_DAYS_WEIGHT,
  SCHEDULE_WEIGHT,
  scheduleFingerprint,
  normalizeMonthDays,
  compositeSimilarityScore,
  checkRosterDuplicates,
  buildCandidateSnapshot,
  isRosterFullExactDuplicate,
};
