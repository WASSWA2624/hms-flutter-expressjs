const {
  createStaffAvailabilitySchema,
  batchCreateStaffAvailabilitySchema} = require('../../../../modules/staff-availability/schemas/staff-availability.schema');
const { slotsOverlap, normalizeSlotList, parseRecordSlots } = require('../../../../modules/staff-availability/lib/availability-slots');
const { serializeStaffAvailability } = require('../../../../modules/staff-availability/lib/staff-availability.serializer');

const STAFF_PROFILE_ID = '550e8400-e29b-41d4-a716-446655440000';

describe('staff-availability.schema contract', () => {
  it('accepts multi-slot availability payloads without overlap', () => {
    const parsed = createStaffAvailabilitySchema.parse({
      staff_profile_id: STAFF_PROFILE_ID,
      day_of_week: 1,
      time_slots: [
        { start_time: '08:00', end_time: '10:00' },
        { start_time: '14:00', end_time: '16:00' }],
      preference: 'AVAILABLE',
      effective_from: '2026-06-30T00:00:00.000Z'});

    expect(parsed.time_slots).toHaveLength(2);
  });

  it('rejects overlapping slots on the same day', () => {
    expect(() => createStaffAvailabilitySchema.parse({
      staff_profile_id: STAFF_PROFILE_ID,
      day_of_week: 1,
      time_slots: [
        { start_time: '08:00', end_time: '12:00' },
        { start_time: '11:00', end_time: '13:00' }],
      effective_from: '2026-06-30T00:00:00.000Z'})).toThrow(/overlap/i);
  });

  it('accepts weekly batch payloads with unique days', () => {
    const parsed = batchCreateStaffAvailabilitySchema.parse({
      staff_profile_id: STAFF_PROFILE_ID,
      preference: 'PREFERRED',
      effective_from: '2026-06-30T00:00:00.000Z',
      days: [
        {
          day_of_week: 1,
          time_slots: [{ start_time: '08:00', end_time: '10:00' }]},
        {
          day_of_week: 2,
          time_slots: [{ start_time: '22:00', end_time: '23:00' }]}]});

    expect(parsed.days).toHaveLength(2);
  });

  it('rejects duplicate day_of_week values in batch payloads', () => {
    expect(() => batchCreateStaffAvailabilitySchema.parse({
      staff_profile_id: STAFF_PROFILE_ID,
      effective_from: '2026-06-30T00:00:00.000Z',
      days: [
        {
          day_of_week: 1,
          time_slots: [{ start_time: '08:00', end_time: '10:00' }]},
        {
          day_of_week: 1,
          time_slots: [{ start_time: '14:00', end_time: '16:00' }]}]})).toThrow(/once/i);
  });
});

describe('availability-slots helpers', () => {
  it('normalizes and parses stored slot json', () => {
    expect(normalizeSlotList([
      { start_time: '8:00', end_time: '10:00' }])).toEqual([{ start_time: '08:00', end_time: '10:00' }]);

    expect(parseRecordSlots({
      start_time: '08:00',
      end_time: '10:00',
      time_slots_json: [
        { start_time: '08:00', end_time: '10:00' },
        { start_time: '14:00', end_time: '16:00' }]})).toEqual([
      { start_time: '08:00', end_time: '10:00' },
      { start_time: '14:00', end_time: '16:00' }]);
  });

  it('detects overlapping slot ranges', () => {
    expect(slotsOverlap([
      { start_time: '08:00', end_time: '12:00' },
      { start_time: '11:00', end_time: '13:00' }])).toBe(true);
  });
});

describe('staff-availability.serializer contract', () => {
  it('exposes time_slots on API records', () => {
    const serialized = serializeStaffAvailability({
      id: 'avail-1',
      human_friendly_id: 'AVL0001',
      day_of_week: 1,
      start_time: '08:00',
      end_time: '10:00',
      time_slots_json: [
        { start_time: '08:00', end_time: '10:00' },
        { start_time: '14:00', end_time: '16:00' }]});

    expect(serialized.display_id).toBe('AVL0001');
    expect(serialized.time_slots).toEqual([
      { start_time: '08:00', end_time: '10:00' },
      { start_time: '14:00', end_time: '16:00' }]);
  });
});
