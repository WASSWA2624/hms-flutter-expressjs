/**
 * Staff profile repository tests
 *
 * @module tests/modules/staff-profile/repositories
 * @description Tests for staff profile repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const staffProfileRepository = require('@repositories/staff-profile/staff-profile.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  staff_profile: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Staff Profile Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find staff profile by id', async () => {
      const mockProfile = { id: '123', tenant_id: 'tenant-1', user_id: 'user-1', staff_number: 'STF001' };
      prisma.staff_profile.findFirst.mockResolvedValue(mockProfile);

      const result = await staffProfileRepository.findById('123');
      expect(result).toEqual(mockProfile);
      expect(prisma.staff_profile.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if staff profile not found', async () => {
      prisma.staff_profile.findFirst.mockResolvedValue(null);

      const result = await staffProfileRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.staff_profile.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(staffProfileRepository.findById('123')).rejects.toThrow(HttpError);
    });

    it('should support include parameter', async () => {
      const mockProfile = { id: '123', user: {} };
      prisma.staff_profile.findFirst.mockResolvedValue(mockProfile);

      const include = { user: true };
      await staffProfileRepository.findById('123', include);
      expect(prisma.staff_profile.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });
  });

  describe('findMany', () => {
    it('should find many staff profiles with pagination', async () => {
      const mockProfiles = [
        { id: '1', staff_number: 'STF001' },
        { id: '2', staff_number: 'STF002' }
      ];
      prisma.staff_profile.findMany.mockResolvedValue(mockProfiles);

      const result = await staffProfileRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockProfiles);
      expect(prisma.staff_profile.findMany).toHaveBeenCalled();
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '123', department_id: 'dept-1' };
      prisma.staff_profile.findMany.mockResolvedValue([]);

      await staffProfileRepository.findMany(filters, 0, 20);
      expect(prisma.staff_profile.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.staff_profile.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(staffProfileRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count staff profiles', async () => {
      prisma.staff_profile.count.mockResolvedValue(42);

      const result = await staffProfileRepository.count({});
      expect(result).toBe(42);
    });

    it('should throw HttpError on database error', async () => {
      prisma.staff_profile.count.mockRejectedValue(new Error('DB Error'));

      await expect(staffProfileRepository.count({})).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create staff profile', async () => {
      const mockData = { tenant_id: '123', user_id: 'user-1', staff_number: 'STF001' };
      const mockProfile = { id: '456', ...mockData };
      prisma.staff_profile.create.mockResolvedValue(mockProfile);

      const result = await staffProfileRepository.create(mockData);
      expect(result).toEqual(mockProfile);
      expect(prisma.staff_profile.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['user_id'] };
      prisma.staff_profile.create.mockRejectedValue(error);

      await expect(staffProfileRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'user_id' };
      prisma.staff_profile.create.mockRejectedValue(error);

      await expect(staffProfileRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update staff profile', async () => {
      const mockData = { position: 'Senior Nurse' };
      const mockProfile = { id: '123', ...mockData };
      prisma.staff_profile.update.mockResolvedValue(mockProfile);

      const result = await staffProfileRepository.update('123', mockData);
      expect(result).toEqual(mockProfile);
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.staff_profile.update.mockRejectedValue(error);

      await expect(staffProfileRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete staff profile', async () => {
      const mockProfile = { id: '123', deleted_at: new Date() };
      prisma.staff_profile.update.mockResolvedValue(mockProfile);

      const result = await staffProfileRepository.softDelete('123');
      expect(result).toEqual(mockProfile);
      expect(prisma.staff_profile.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.staff_profile.update.mockRejectedValue(error);

      await expect(staffProfileRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
