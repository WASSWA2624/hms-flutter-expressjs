/**
 * Shared staff availability slot helpers.
 */

const normalizeTimeString = (value) => {
  const raw = String(value || '').trim();
  const match = raw.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
  if (!match) {
    return null;
  }

  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  const seconds = match[3] != null ? Number(match[3]) : null;
  if (!Number.isFinite(hours) || !Number.isFinite(minutes) || hours > 23 || minutes > 59) {
    return null;
  }

  const base = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
  if (seconds != null) {
    if (!Number.isFinite(seconds) || seconds > 59) {
      return null;
    }
    return `${base}:${String(seconds).padStart(2, '0')}`;
  }

  return base;
};

const toMinutes = (value) => {
  const normalized = normalizeTimeString(value);
  if (!normalized) {
    return null;
  }

  const [hours, minutes] = normalized.split(':').map(Number);
  return hours * 60 + minutes;
};

const normalizeSlotList = (slots = []) => {
  if (!Array.isArray(slots)) {
    return [];
  }

  return slots
    .map((slot) => ({
      start_time: normalizeTimeString(slot?.start_time),
      end_time: normalizeTimeString(slot?.end_time),
    }))
    .filter((slot) => slot.start_time && slot.end_time);
};

const slotsOverlap = (slots = []) => {
  const ranges = normalizeSlotList(slots)
    .map((slot) => ({
      start: toMinutes(slot.start_time),
      end: toMinutes(slot.end_time),
    }))
    .filter((range) => range.start != null && range.end != null && range.end > range.start)
    .sort((left, right) => left.start - right.start);

  for (let index = 1; index < ranges.length; index += 1) {
    if (ranges[index].start < ranges[index - 1].end) {
      return true;
    }
  }

  return false;
};

const parseRecordSlots = (record = {}) => {
  const jsonSlots = Array.isArray(record.time_slots_json) ? record.time_slots_json : [];
  const normalizedJsonSlots = normalizeSlotList(jsonSlots).filter(
    (slot) => toMinutes(slot.end_time) > toMinutes(slot.start_time)
  );

  if (normalizedJsonSlots.length) {
    return normalizedJsonSlots;
  }

  const startTime = normalizeTimeString(record.start_time);
  const endTime = normalizeTimeString(record.end_time);
  if (
    startTime &&
    endTime &&
    toMinutes(endTime) > toMinutes(startTime)
  ) {
    return [{ start_time: startTime, end_time: endTime }];
  }

  return [];
};

module.exports = {
  normalizeTimeString,
  toMinutes,
  normalizeSlotList,
  slotsOverlap,
  parseRecordSlots,
};
