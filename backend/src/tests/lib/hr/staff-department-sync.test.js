/**
 * Staff department sync tests
 *
 * @module tests/lib/hr/staff-department-sync
 */

const prisma = require('@prisma/client');
const {
  resolvePrimaryDepartmentId,
  endActiveStaffAssignments,
  syncStaffProfilePrimaryDepartment} = require('@lib/hr/staff-department-sync');

jest.mock('@prisma/client', () => ({
  staff_assignment: {
    findFirst: jest.fn(),
    updateMany: jest.fn()},
  staff_profile: {
    findFirst: jest.fn(),
    update: jest.fn()}}));

describe('staff-department-sync', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('resolvePrimaryDepartmentId returns latest active assignment department', async () => {
    prisma.staff_assignment.findFirst.mockResolvedValue({
      department_id: 'dept-1'});

    await expect(resolvePrimaryDepartmentId('profile-1')).resolves.toBe('dept-1');
  });

  it('endActiveStaffAssignments closes open assignments at the given end date', async () => {
    const endDate = new Date('2026-08-10T00:00:00.000Z');
    prisma.staff_assignment.updateMany.mockResolvedValue({ count: 2 });

    await expect(
      endActiveStaffAssignments('profile-1', endDate)
    ).resolves.toEqual({ count: 2 });

    expect(prisma.staff_assignment.updateMany).toHaveBeenCalledWith({
      where: {
        staff_profile_id: 'profile-1',
        deleted_at: null,
        department_id: { not: null },
        OR: [{ end_date: null }, { end_date: { gt: endDate } }]},
      data: { end_date: endDate }});
  });

  it('endActiveStaffAssignments skips invalid dates', async () => {
    await expect(
      endActiveStaffAssignments('profile-1', 'not-a-date')
    ).resolves.toEqual({ count: 0 });
    expect(prisma.staff_assignment.updateMany).not.toHaveBeenCalled();
  });

  it('syncStaffProfilePrimaryDepartment updates profile when assignment exists', async () => {
    prisma.staff_profile.findFirst.mockResolvedValue({
      id: 'profile-1',
      department_id: null,
      tenant_id: 'tenant-1',
      human_friendly_id: 'STF-1',
      staff_number: 'STF-1'});
    prisma.staff_assignment.findFirst.mockResolvedValue({
      department_id: 'dept-1'});
    prisma.staff_profile.update.mockResolvedValue({
      id: 'profile-1',
      department_id: 'dept-1',
      tenant_id: 'tenant-1',
      human_friendly_id: 'STF-1',
      staff_number: 'STF-1'});

    const result = await syncStaffProfilePrimaryDepartment('profile-1');

    expect(prisma.staff_profile.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'profile-1' },
        data: { department_id: 'dept-1' }})
    );
    expect(result.department_id).toBe('dept-1');
  });

  it('syncStaffProfilePrimaryDepartment preserves onboarding department without assignments', async () => {
    const profile = {
      id: 'profile-1',
      department_id: 'dept-onboard',
      tenant_id: 'tenant-1',
      human_friendly_id: 'STF-1',
      staff_number: 'STF-1'};
    prisma.staff_profile.findFirst.mockResolvedValue(profile);
    prisma.staff_assignment.findFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null);

    const result = await syncStaffProfilePrimaryDepartment('profile-1');

    expect(prisma.staff_profile.update).not.toHaveBeenCalled();
    expect(result).toEqual(profile);
  });
});
