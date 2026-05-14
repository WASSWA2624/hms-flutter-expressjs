/**
 * Staff profile service tests
 *
 * @module tests/modules/staff-profile/services
 * @description Tests for staff profile service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const staffProfileService = require('@services/staff-profile/staff-profile.service');
const staffProfileRepository = require('@repositories/staff-profile/staff-profile.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const prisma = require('@prisma/client');

// Mock dependencies
jest.mock('@repositories/staff-profile/staff-profile.repository');
jest.mock('@lib/audit');
jest.mock('@prisma/client', () => ({
  user: {
    findFirst: jest.fn(),
  },
}));

describe('Staff Profile Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.user.findFirst.mockResolvedValue({
      id: '550e8400-e29b-41d4-a716-446655440001',
    });
  });

  describe('listStaffProfiles', () => {
    it('should list staff profiles with pagination', async () => {
      const mockProfiles = [{ id: '1', staff_number: 'STF001' }];
      staffProfileRepository.findMany.mockResolvedValue(mockProfiles);
      staffProfileRepository.count.mockResolvedValue(1);

      const result = await staffProfileService.listStaffProfiles({}, 1, 20, 'created_at', 'desc', mockUserId, mockIpAddress);

      expect(result.staffProfiles).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            id: '1',
            staff_number: 'STF001',
            display_id: 'STF001',
          }),
        ])
      );
      expect(result.pagination.total).toBe(1);
      expect(result.pagination.totalPages).toBe(1);
    });

    it('should handle search filters', async () => {
      staffProfileRepository.findMany.mockResolvedValue([]);
      staffProfileRepository.count.mockResolvedValue(0);

      await staffProfileService.listStaffProfiles({ search: 'STF001' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(staffProfileRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ OR: expect.any(Array) }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      staffProfileRepository.findMany.mockResolvedValue([]);
      staffProfileRepository.count.mockResolvedValue(50);

      const result = await staffProfileService.listStaffProfiles({}, 2, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(result.pagination.totalPages).toBe(3);
      expect(result.pagination.hasNextPage).toBe(true);
      expect(result.pagination.hasPreviousPage).toBe(true);
    });
  });

  describe('getStaffProfileById', () => {
    it('should get staff profile by id', async () => {
      const mockProfile = { id: '123', staff_number: 'STF001' };
      staffProfileRepository.findById.mockResolvedValue(mockProfile);

      const result = await staffProfileService.getStaffProfileById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining({
        id: '123',
        staff_number: 'STF001',
        display_id: 'STF001',
      }));
    });

    it('should throw HttpError if staff profile not found', async () => {
      staffProfileRepository.findById.mockResolvedValue(null);

      await expect(
        staffProfileService.getStaffProfileById('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createStaffProfile', () => {
    it('should create staff profile and log audit', async () => {
      const mockData = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        user_id: '550e8400-e29b-41d4-a716-446655440001',
        staff_number: 'STF001'
      };
      const mockProfile = { id: '456', ...mockData };
      staffProfileRepository.create.mockResolvedValue(mockProfile);
      staffProfileRepository.findById.mockResolvedValue(mockProfile);

      const result = await staffProfileService.createStaffProfile(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining({
        id: '456',
        staff_number: 'STF001',
        display_id: 'STF001',
      }));
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: mockData.tenant_id,
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'staff_profile',
        entity_id: mockProfile.id,
        diff: { after: mockProfile },
        ip_address: mockIpAddress
      });
    });

    it('should not fail if audit log fails', async () => {
      const mockData = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        user_id: '550e8400-e29b-41d4-a716-446655440001'
      };
      const mockProfile = { id: '456', ...mockData };
      staffProfileRepository.create.mockResolvedValue(mockProfile);
      staffProfileRepository.findById.mockResolvedValue(mockProfile);
      createAuditLog.mockImplementation(() => Promise.reject(new Error('Audit failed')));

      const result = await staffProfileService.createStaffProfile(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining({
        id: '456',
        user_id: '550e8400-e29b-41d4-a716-446655440001',
      }));
    });
  });

  describe('updateStaffProfile', () => {
    it('should update staff profile and log audit', async () => {
      const mockBefore = { id: '123', tenant_id: 'tenant-1', position: 'Nurse' };
      const mockData = { position: 'Senior Nurse' };
      const mockAfter = { id: '123', position: 'Senior Nurse', tenant_id: 'tenant-1' };
      staffProfileRepository.findById
        .mockResolvedValueOnce(mockBefore)
        .mockResolvedValueOnce(mockAfter);
      staffProfileRepository.update.mockResolvedValue(mockAfter);

      const result = await staffProfileService.updateStaffProfile('123', mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining({
        id: '123',
        position: 'Senior Nurse',
      }));
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if staff profile not found', async () => {
      staffProfileRepository.findById.mockResolvedValue(null);

      await expect(
        staffProfileService.updateStaffProfile('nonexistent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteStaffProfile', () => {
    it('should delete staff profile and log audit', async () => {
      const mockProfile = { id: '123', tenant_id: 'tenant-1', staff_number: 'STF001' };
      staffProfileRepository.findById.mockResolvedValue(mockProfile);
      staffProfileRepository.softDelete.mockResolvedValue(undefined);

      await staffProfileService.deleteStaffProfile('123', mockUserId, mockIpAddress);

      expect(staffProfileRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if staff profile not found', async () => {
      staffProfileRepository.findById.mockResolvedValue(null);

      await expect(
        staffProfileService.deleteStaffProfile('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
