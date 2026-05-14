/**
 * ICU Stay repository tests
 *
 * @module tests/modules/icu-stay/repositories
 * @description Tests for ICU stay repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const icuStayRepository = require('@repositories/icu-stay/icu-stay.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  icu_stay: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('ICU Stay Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find ICU stay by id', async () => {
      const mockIcuStay = { 
        id: '123', 
        admission_id: '456',
        started_at: new Date(),
        ended_at: null
      };
      prisma.icu_stay.findFirst.mockResolvedValue(mockIcuStay);

      const result = await icuStayRepository.findById('123');
      expect(result).toEqual(mockIcuStay);
      expect(prisma.icu_stay.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if ICU stay not found', async () => {
      prisma.icu_stay.findFirst.mockResolvedValue(null);

      const result = await icuStayRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.icu_stay.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(icuStayRepository.findById('123')).rejects.toThrow(HttpError);
    });

    it('should accept include parameter for relations', async () => {
      const mockIcuStay = { id: '123', admission_id: '456' };
      const include = { observations: true };
      prisma.icu_stay.findFirst.mockResolvedValue(mockIcuStay);

      await icuStayRepository.findById('123', include);
      expect(prisma.icu_stay.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });
  });

  describe('findMany', () => {
    it('should find many ICU stays with pagination', async () => {
      const mockIcuStays = [
        { id: '1', admission_id: '100', started_at: new Date() },
        { id: '2', admission_id: '200', started_at: new Date() }
      ];
      prisma.icu_stay.findMany.mockResolvedValue(mockIcuStays);

      const result = await icuStayRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockIcuStays);
      expect(prisma.icu_stay.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      prisma.icu_stay.findMany.mockResolvedValue([]);
      const filters = { admission_id: '456' };

      await icuStayRepository.findMany(filters, 0, 20);
      expect(prisma.icu_stay.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply custom ordering', async () => {
      prisma.icu_stay.findMany.mockResolvedValue([]);
      const orderBy = { started_at: 'asc' };

      await icuStayRepository.findMany({}, 0, 20, orderBy);
      expect(prisma.icu_stay.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy,
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.icu_stay.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(icuStayRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count ICU stays', async () => {
      prisma.icu_stay.count.mockResolvedValue(42);

      const result = await icuStayRepository.count({});
      expect(result).toBe(42);
    });

    it('should count with filters', async () => {
      prisma.icu_stay.count.mockResolvedValue(10);
      const filters = { admission_id: '456' };

      await icuStayRepository.count(filters);
      expect(prisma.icu_stay.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.icu_stay.count.mockRejectedValue(new Error('DB Error'));

      await expect(icuStayRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create ICU stay', async () => {
      const mockData = { admission_id: '123', started_at: new Date() };
      const mockIcuStay = { id: '456', ...mockData };
      prisma.icu_stay.create.mockResolvedValue(mockIcuStay);

      const result = await icuStayRepository.create(mockData);
      expect(result).toEqual(mockIcuStay);
      expect(prisma.icu_stay.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['admission_id'] };
      prisma.icu_stay.create.mockRejectedValue(error);

      await expect(icuStayRepository.create({})).rejects.toThrow(HttpError);
      await expect(icuStayRepository.create({})).rejects.toMatchObject({
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'admission_id' };
      prisma.icu_stay.create.mockRejectedValue(error);

      await expect(icuStayRepository.create({})).rejects.toThrow(HttpError);
      await expect(icuStayRepository.create({})).rejects.toMatchObject({
        statusCode: 400
      });
    });

    it('should throw HttpError on generic database error', async () => {
      prisma.icu_stay.create.mockRejectedValue(new Error('Generic DB Error'));

      await expect(icuStayRepository.create({})).rejects.toThrow(HttpError);
      await expect(icuStayRepository.create({})).rejects.toMatchObject({
        statusCode: 500
      });
    });
  });

  describe('update', () => {
    it('should update ICU stay', async () => {
      const mockIcuStay = { id: '123', admission_id: '456', ended_at: new Date() };
      prisma.icu_stay.update.mockResolvedValue(mockIcuStay);

      const result = await icuStayRepository.update('123', { ended_at: new Date() });
      expect(result).toEqual(mockIcuStay);
      expect(prisma.icu_stay.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { ended_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if ICU stay not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.icu_stay.update.mockRejectedValue(error);

      await expect(icuStayRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
      await expect(icuStayRepository.update('nonexistent', {})).rejects.toMatchObject({
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['admission_id'] };
      prisma.icu_stay.update.mockRejectedValue(error);

      await expect(icuStayRepository.update('123', {})).rejects.toThrow(HttpError);
      await expect(icuStayRepository.update('123', {})).rejects.toMatchObject({
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'admission_id' };
      prisma.icu_stay.update.mockRejectedValue(error);

      await expect(icuStayRepository.update('123', {})).rejects.toThrow(HttpError);
      await expect(icuStayRepository.update('123', {})).rejects.toMatchObject({
        statusCode: 400
      });
    });
  });

  describe('softDelete', () => {
    it('should soft delete ICU stay', async () => {
      const mockIcuStay = { id: '123', deleted_at: new Date() };
      prisma.icu_stay.update.mockResolvedValue(mockIcuStay);

      const result = await icuStayRepository.softDelete('123');
      expect(result).toEqual(mockIcuStay);
      expect(prisma.icu_stay.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if ICU stay not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.icu_stay.update.mockRejectedValue(error);

      await expect(icuStayRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
      await expect(icuStayRepository.softDelete('nonexistent')).rejects.toMatchObject({
        statusCode: 404
      });
    });

    it('should throw HttpError on generic database error', async () => {
      prisma.icu_stay.update.mockRejectedValue(new Error('Generic DB Error'));

      await expect(icuStayRepository.softDelete('123')).rejects.toThrow(HttpError);
      await expect(icuStayRepository.softDelete('123')).rejects.toMatchObject({
        statusCode: 500
      });
    });
  });
});
