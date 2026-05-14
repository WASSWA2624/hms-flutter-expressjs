/**
 * Shift repository tests
 *
 * @module tests/modules/shift/repositories
 * @description Tests for shift repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const shiftRepository = require('@repositories/shift/shift.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  shift: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Shift Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find shift by id', async () => {
      const mockShift = {
        id: '123',
        tenant_id: '456',
        shift_type: 'DAY',
        status: 'SCHEDULED',
        start_time: new Date('2026-01-20T08:00:00.000Z'),
        end_time: new Date('2026-01-20T16:00:00.000Z')
      };
      prisma.shift.findFirst.mockResolvedValue(mockShift);

      const result = await shiftRepository.findById('123');
      expect(result).toEqual(mockShift);
      expect(prisma.shift.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if shift not found', async () => {
      prisma.shift.findFirst.mockResolvedValue(null);

      const result = await shiftRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.shift.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(shiftRepository.findById('123')).rejects.toThrow(HttpError);
    });

    it('should accept include parameter for relations', async () => {
      const mockShift = { id: '123', tenant_id: '456' };
      const include = { assignments: true };
      prisma.shift.findFirst.mockResolvedValue(mockShift);

      await shiftRepository.findById('123', include);
      expect(prisma.shift.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });
  });

  describe('findMany', () => {
    it('should find many shifts with pagination', async () => {
      const mockShifts = [
        { id: '1', tenant_id: '456', shift_type: 'DAY', status: 'SCHEDULED' },
        { id: '2', tenant_id: '456', shift_type: 'NIGHT', status: 'SCHEDULED' }
      ];
      prisma.shift.findMany.mockResolvedValue(mockShifts);

      const result = await shiftRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockShifts);
      expect(prisma.shift.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      const filters = { tenant_id: '456', shift_type: 'DAY' };
      prisma.shift.findMany.mockResolvedValue([]);

      await shiftRepository.findMany(filters, 0, 20);
      expect(prisma.shift.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply custom orderBy', async () => {
      const orderBy = { start_time: 'asc' };
      prisma.shift.findMany.mockResolvedValue([]);

      await shiftRepository.findMany({}, 0, 20, orderBy);
      expect(prisma.shift.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy,
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.shift.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(shiftRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count shifts', async () => {
      prisma.shift.count.mockResolvedValue(42);

      const result = await shiftRepository.count({});
      expect(result).toBe(42);
      expect(prisma.shift.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count with filters', async () => {
      const filters = { tenant_id: '456', status: 'SCHEDULED' };
      prisma.shift.count.mockResolvedValue(10);

      const result = await shiftRepository.count(filters);
      expect(result).toBe(10);
      expect(prisma.shift.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.shift.count.mockRejectedValue(new Error('DB Error'));

      await expect(shiftRepository.count({})).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create shift', async () => {
      const mockData = {
        tenant_id: '123',
        shift_type: 'DAY',
        status: 'SCHEDULED',
        start_time: new Date('2026-01-20T08:00:00.000Z'),
        end_time: new Date('2026-01-20T16:00:00.000Z')
      };
      const mockShift = { id: '456', ...mockData };
      prisma.shift.create.mockResolvedValue(mockShift);

      const result = await shiftRepository.create(mockData);
      expect(result).toEqual(mockShift);
      expect(prisma.shift.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.shift.create.mockRejectedValue(error);

      await expect(shiftRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.shift.create.mockRejectedValue(error);

      await expect(shiftRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.shift.create.mockRejectedValue(new Error('DB Error'));

      await expect(shiftRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update shift', async () => {
      const mockShift = {
        id: '123',
        tenant_id: '456',
        shift_type: 'NIGHT',
        status: 'SCHEDULED'
      };
      prisma.shift.update.mockResolvedValue(mockShift);

      const result = await shiftRepository.update('123', { shift_type: 'NIGHT' });
      expect(result).toEqual(mockShift);
      expect(prisma.shift.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { shift_type: 'NIGHT' }
      });
    });

    it('should throw HttpError if shift not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.shift.update.mockRejectedValue(error);

      await expect(shiftRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.shift.update.mockRejectedValue(error);

      await expect(shiftRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };
      prisma.shift.update.mockRejectedValue(error);

      await expect(shiftRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete shift', async () => {
      const mockShift = { id: '123', deleted_at: new Date() };
      prisma.shift.update.mockResolvedValue(mockShift);

      const result = await shiftRepository.softDelete('123');
      expect(result).toEqual(mockShift);
      expect(prisma.shift.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if shift not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.shift.update.mockRejectedValue(error);

      await expect(shiftRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.shift.update.mockRejectedValue(new Error('DB Error'));

      await expect(shiftRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
