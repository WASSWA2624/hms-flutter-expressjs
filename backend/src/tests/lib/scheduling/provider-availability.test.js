/**
 * Provider availability tests
 *
 * @module tests/lib/scheduling
 * @description Whether a staff member can be booked for a window, from their
 * recurring schedule, dated overrides, and approved leave.
 */

jest.mock('@prisma/client', () => ({
  provider_schedule: { findMany: jest.fn() },
  staff_leave: { findMany: jest.fn() }}));

const prisma = require('@prisma/client');
const {
  resolveProviderAvailability,
  UNAVAILABLE_REASONS} = require('@lib/scheduling/provider-availability');

// Monday 2026-07-20. Schedule times carry a time of day, read in UTC.
const timeOfDay = (hour, minute = 0) =>
  new Date(Date.UTC(1970, 0, 1, hour, minute));

const weekdaySchedule = (overrides = {}) => ({
  id: 'schedule-1',
  human_friendly_id: 'PSC000001',
  timezone: 'UTC',
  day_of_week: 1,
  start_time: timeOfDay(8),
  end_time: timeOfDay(17),
  effective_from: null,
  effective_to: null,
  slots: [],
  ...overrides});

const booking = (startIso, endIso) => ({
  providerUserId: 'provider-1',
  tenantId: 'tenant-1',
  scheduledStart: startIso,
  scheduledEnd: endIso});

describe('resolveProviderAvailability', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    prisma.provider_schedule.findMany.mockResolvedValue([]);
    prisma.staff_leave.findMany.mockResolvedValue([]);
  });

  it('treats a provider with no schedule on file as available', async () => {
    const result = await resolveProviderAvailability(
      booking('2026-07-20T09:00:00.000Z', '2026-07-20T09:30:00.000Z')
    );

    expect(result).toEqual({ available: true });
    expect(prisma.staff_leave.findMany).not.toHaveBeenCalled();
  });

  it('accepts a window inside the rostered hours', async () => {
    prisma.provider_schedule.findMany.mockResolvedValue([weekdaySchedule()]);

    await expect(
      resolveProviderAvailability(
        booking('2026-07-20T09:00:00.000Z', '2026-07-20T09:30:00.000Z')
      )
    ).resolves.toEqual({ available: true });
  });

  it('rejects a window that runs past the end of the shift', async () => {
    prisma.provider_schedule.findMany.mockResolvedValue([weekdaySchedule()]);

    const result = await resolveProviderAvailability(
      booking('2026-07-20T16:45:00.000Z', '2026-07-20T17:30:00.000Z')
    );

    expect(result.available).toBe(false);
    expect(result.reason).toBe(UNAVAILABLE_REASONS.OFF_SCHEDULE);
  });

  it('rejects a day the provider does not work', async () => {
    prisma.provider_schedule.findMany.mockResolvedValue([weekdaySchedule()]);

    // 2026-07-21 is the Tuesday after; the roster only covers Monday.
    const result = await resolveProviderAvailability(
      booking('2026-07-21T09:00:00.000Z', '2026-07-21T09:30:00.000Z')
    );

    expect(result.reason).toBe(UNAVAILABLE_REASONS.OFF_SCHEDULE);
  });

  it('reads the roster on the timezone it declares', async () => {
    // 08:30 UTC is 11:30 in Kampala, inside the shift; the same instant read
    // as UTC would fall before the 09:00 start.
    prisma.provider_schedule.findMany.mockResolvedValue([
      weekdaySchedule({
        timezone: 'Africa/Kampala',
        start_time: timeOfDay(9),
        end_time: timeOfDay(17)})]);

    await expect(
      resolveProviderAvailability(
        booking('2026-07-20T08:30:00.000Z', '2026-07-20T09:00:00.000Z')
      )
    ).resolves.toEqual({ available: true });
  });

  it('falls back to UTC for an unusable timezone instead of failing', async () => {
    prisma.provider_schedule.findMany.mockResolvedValue([
      weekdaySchedule({ timezone: 'Not/AZone' })]);

    await expect(
      resolveProviderAvailability(
        booking('2026-07-20T09:00:00.000Z', '2026-07-20T09:30:00.000Z')
      )
    ).resolves.toEqual({ available: true });
  });

  it('honours the effective window a schedule is valid for', async () => {
    prisma.provider_schedule.findMany.mockResolvedValue([
      weekdaySchedule({ effective_from: new Date('2026-08-01T00:00:00.000Z') })]);

    const result = await resolveProviderAvailability(
      booking('2026-07-20T09:00:00.000Z', '2026-07-20T09:30:00.000Z')
    );

    expect(result.reason).toBe(UNAVAILABLE_REASONS.OFF_SCHEDULE);
  });

  describe('dated overrides', () => {
    it('blocks a window the roster was edited to close', async () => {
      prisma.provider_schedule.findMany.mockResolvedValue([
        weekdaySchedule({
          slots: [
            {
              id: 'slot-1',
              human_friendly_id: 'AVS000001',
              override_date: new Date('2026-07-20T00:00:00.000Z'),
              start_time: timeOfDay(9),
              end_time: timeOfDay(12),
              is_available: false}]})]);

      const result = await resolveProviderAvailability(
        booking('2026-07-20T09:00:00.000Z', '2026-07-20T09:30:00.000Z')
      );

      expect(result.available).toBe(false);
      expect(result.reason).toBe(UNAVAILABLE_REASONS.BLOCKED_SLOT);
      expect(result.detail).toMatchObject({ slot_id: 'AVS000001' });
    });

    it('leaves the rest of a partly blocked day bookable', async () => {
      prisma.provider_schedule.findMany.mockResolvedValue([
        weekdaySchedule({
          slots: [
            {
              id: 'slot-1',
              override_date: new Date('2026-07-20T00:00:00.000Z'),
              start_time: timeOfDay(9),
              end_time: timeOfDay(12),
              is_available: false}]})]);

      await expect(
        resolveProviderAvailability(
          booking('2026-07-20T14:00:00.000Z', '2026-07-20T14:30:00.000Z')
        )
      ).resolves.toEqual({ available: true });
    });

    it('opens a window the recurring roster does not cover', async () => {
      prisma.provider_schedule.findMany.mockResolvedValue([
        weekdaySchedule({
          slots: [
            {
              id: 'slot-1',
              // The Tuesday the weekly roster leaves out.
              override_date: new Date('2026-07-21T00:00:00.000Z'),
              start_time: timeOfDay(9),
              end_time: timeOfDay(12),
              is_available: true}]})]);

      await expect(
        resolveProviderAvailability(
          booking('2026-07-21T09:00:00.000Z', '2026-07-21T09:30:00.000Z')
        )
      ).resolves.toEqual({ available: true });
    });
  });

  describe('leave', () => {
    beforeEach(() => {
      prisma.provider_schedule.findMany.mockResolvedValue([weekdaySchedule()]);
    });

    it('blocks an approved full day of leave', async () => {
      prisma.staff_leave.findMany.mockResolvedValue([
        {
          id: 'leave-1',
          human_friendly_id: 'LEV000001',
          leave_type: 'ANNUAL',
          is_half_day: false,
          half_day_period: null}]);

      const result = await resolveProviderAvailability(
        booking('2026-07-20T09:00:00.000Z', '2026-07-20T09:30:00.000Z')
      );

      expect(result.available).toBe(false);
      expect(result.reason).toBe(UNAVAILABLE_REASONS.ON_LEAVE);
      expect(result.detail).toMatchObject({ leave_id: 'LEV000001' });
    });

    it('only asks about leave that was actually approved', async () => {
      await resolveProviderAvailability(
        booking('2026-07-20T09:00:00.000Z', '2026-07-20T09:30:00.000Z')
      );

      expect(prisma.staff_leave.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            status: 'APPROVED',
            staff_profile: { deleted_at: null, user_id: 'provider-1' }})})
      );
    });

    it('lets an afternoon clinic survive a morning off', async () => {
      prisma.staff_leave.findMany.mockResolvedValue([
        {
          id: 'leave-1',
          leave_type: 'ANNUAL',
          is_half_day: true,
          half_day_period: 'MORNING'}]);

      await expect(
        resolveProviderAvailability(
          booking('2026-07-20T14:00:00.000Z', '2026-07-20T14:30:00.000Z')
        )
      ).resolves.toEqual({ available: true });

      const morning = await resolveProviderAvailability(
        booking('2026-07-20T09:00:00.000Z', '2026-07-20T09:30:00.000Z')
      );
      expect(morning.reason).toBe(UNAVAILABLE_REASONS.ON_LEAVE);
    });
  });

  it('stands aside for a booking that crosses local midnight', async () => {
    prisma.provider_schedule.findMany.mockResolvedValue([weekdaySchedule()]);

    // No single weekday window can describe this, so the weekday rule does
    // not get to reject it; the clash checks still apply elsewhere.
    await expect(
      resolveProviderAvailability(
        booking('2026-07-20T23:30:00.000Z', '2026-07-21T00:30:00.000Z')
      )
    ).resolves.toEqual({ available: true });
  });

  it('returns available for an incomplete or inverted request', async () => {
    await expect(
      resolveProviderAvailability({ providerUserId: null })
    ).resolves.toEqual({ available: true });
    await expect(
      resolveProviderAvailability(
        booking('2026-07-20T10:00:00.000Z', '2026-07-20T09:00:00.000Z')
      )
    ).resolves.toEqual({ available: true });
    expect(prisma.provider_schedule.findMany).not.toHaveBeenCalled();
  });
});
