/**
 * Staff availability service tests
 */
const staffAvailabilityService = require('@services/staff-availability/staff-availability.service');
const staffAvailabilityRepository = require('@repositories/staff-availability/staff-availability.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/staff-availability/staff-availability.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || null),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolveEntityId: jest.fn(async ({ identifier }) => identifier)}));

describe('Staff Availability Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';
  const staffProfileId = '550e8400-e29b-41d4-a716-446655440000';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('creates availability with normalized multi-slot payload', async () => {
    const created = {
      id: 'avail-1',
      staff_profile_id: staffProfileId,
      day_of_week: 1,
      start_time: '08:00',
      end_time: '10:00',
      time_slots_json: [
        { start_time: '08:00', end_time: '10:00' },
        { start_time: '14:00', end_time: '16:00' }]};
    staffAvailabilityRepository.create.mockResolvedValue(created);

    const result = await staffAvailabilityService.create({
      staff_profile_id: staffProfileId,
      day_of_week: 1,
      time_slots: [
        { start_time: '08:00', end_time: '10:00' },
        { start_time: '14:00', end_time: '16:00' }],
      effective_from: '2026-06-30T00:00:00.000Z'}, mockUserId, mockIpAddress);

    expect(staffAvailabilityRepository.create).toHaveBeenCalledWith(expect.objectContaining({
      staff_profile_id: staffProfileId,
      start_time: '08:00',
      end_time: '10:00',
      time_slots_json: [
        { start_time: '08:00', end_time: '10:00' },
        { start_time: '14:00', end_time: '16:00' }]}));
    expect(result.time_slots).toEqual([
      { start_time: '08:00', end_time: '10:00' },
      { start_time: '14:00', end_time: '16:00' }]);
  });

  it('creates a weekly schedule in batch', async () => {
    staffAvailabilityRepository.create
      .mockResolvedValueOnce({
        id: 'avail-1',
        day_of_week: 1,
        start_time: '08:00',
        end_time: '10:00',
        time_slots_json: [{ start_time: '08:00', end_time: '10:00' }]})
      .mockResolvedValueOnce({
        id: 'avail-2',
        day_of_week: 2,
        start_time: '14:00',
        end_time: '16:00',
        time_slots_json: [{ start_time: '14:00', end_time: '16:00' }]});

    const result = await staffAvailabilityService.createBatch({
      staff_profile_id: staffProfileId,
      preference: 'AVAILABLE',
      effective_from: '2026-06-30T00:00:00.000Z',
      days: [
        {
          day_of_week: 1,
          time_slots: [{ start_time: '08:00', end_time: '10:00' }]},
        {
          day_of_week: 2,
          time_slots: [{ start_time: '14:00', end_time: '16:00' }]}]}, mockUserId, mockIpAddress);

    expect(staffAvailabilityRepository.create).toHaveBeenCalledTimes(2);
    expect(result).toHaveLength(2);
    expect(createAuditLog).toHaveBeenCalledTimes(2);
  });

  it('rejects overlapping slots during create', async () => {
    await expect(staffAvailabilityService.create({
      staff_profile_id: staffProfileId,
      day_of_week: 1,
      time_slots: [
        { start_time: '08:00', end_time: '12:00' },
        { start_time: '11:00', end_time: '13:00' }],
      effective_from: '2026-06-30T00:00:00.000Z'}, mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
  });
});
