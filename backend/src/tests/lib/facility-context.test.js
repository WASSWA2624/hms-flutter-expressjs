/**
 * Facility context resolution tests
 */

const authRepository = require('@repositories/auth/auth.repository');
const { resolveOperationalFacilityId } = require('@lib/facility-context');

jest.mock('@repositories/auth/auth.repository');

describe('facility-context', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns explicit facility id when provided', async () => {
    await expect(
      resolveOperationalFacilityId({
        facilityId: 'facility-1',
        userId: 'user-1',
        tenantId: 'tenant-1'})
    ).resolves.toBe('facility-1');
    expect(authRepository.getUserFacilities).not.toHaveBeenCalled();
  });

  it('falls back to the only accessible facility for the user', async () => {
    authRepository.getUserFacilities.mockResolvedValue([{ id: 'facility-2' }]);

    await expect(
      resolveOperationalFacilityId({
        userId: 'user-1',
        tenantId: 'tenant-1'})
    ).resolves.toBe('facility-2');
  });

  it('returns null when the user has multiple facilities and none is selected', async () => {
    authRepository.getUserFacilities.mockResolvedValue([
      { id: 'facility-2' },
      { id: 'facility-3' }]);

    await expect(
      resolveOperationalFacilityId({
        userId: 'user-1',
        tenantId: 'tenant-1'})
    ).resolves.toBeNull();
  });
});
