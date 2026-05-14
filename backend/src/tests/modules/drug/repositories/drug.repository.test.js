/**
 * Drug repository tests
 *
 * @module tests/modules/drug/repositories
 * @description Tests for drug repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const drugRepository = require('@repositories/drug/drug.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  drug: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Drug Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find drug by id', async () => {
      const mockDrug = { id: '123', name: 'Paracetamol', code: 'PARA500' };
      prisma.drug.findFirst.mockResolvedValue(mockDrug);

      const result = await drugRepository.findById('123');
      expect(result).toEqual(mockDrug);
      expect(prisma.drug.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if drug not found', async () => {
      prisma.drug.findFirst.mockResolvedValue(null);

      const result = await drugRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.drug.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(drugRepository.findById('123')).rejects.toThrow(HttpError);
    });

    it('should support include parameter', async () => {
      const mockDrug = { id: '123', name: 'Paracetamol', batches: [] };
      prisma.drug.findFirst.mockResolvedValue(mockDrug);

      const include = { batches: true };
      const result = await drugRepository.findById('123', include);
      expect(result).toEqual(mockDrug);
      expect(prisma.drug.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });
  });

  describe('findMany', () => {
    it('should find many drugs with pagination', async () => {
      const mockDrugs = [
        { id: '1', name: 'Paracetamol', code: 'PARA500' },
        { id: '2', name: 'Ibuprofen', code: 'IBU400' }
      ];
      prisma.drug.findMany.mockResolvedValue(mockDrugs);

      const result = await drugRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockDrugs);
      expect(prisma.drug.findMany).toHaveBeenCalled();
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '123', name: { contains: 'Para' } };
      prisma.drug.findMany.mockResolvedValue([]);

      await drugRepository.findMany(filters, 0, 20);
      expect(prisma.drug.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply custom ordering', async () => {
      prisma.drug.findMany.mockResolvedValue([]);

      await drugRepository.findMany({}, 0, 20, { name: 'asc' });
      expect(prisma.drug.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.drug.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(drugRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count drugs', async () => {
      prisma.drug.count.mockResolvedValue(42);

      const result = await drugRepository.count({});
      expect(result).toBe(42);
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '123' };
      prisma.drug.count.mockResolvedValue(10);

      await drugRepository.count(filters);
      expect(prisma.drug.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.drug.count.mockRejectedValue(new Error('DB Error'));

      await expect(drugRepository.count({})).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create drug', async () => {
      const mockData = { tenant_id: '123', name: 'Paracetamol', code: 'PARA500' };
      const mockDrug = { id: '456', ...mockData };
      prisma.drug.create.mockResolvedValue(mockDrug);

      const result = await drugRepository.create(mockData);
      expect(result).toEqual(mockDrug);
      expect(prisma.drug.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['code'] };
      prisma.drug.create.mockRejectedValue(error);

      await expect(drugRepository.create({})).rejects.toThrow(HttpError);
      await expect(drugRepository.create({})).rejects.toMatchObject({
        message: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.drug.create.mockRejectedValue(error);

      await expect(drugRepository.create({})).rejects.toThrow(HttpError);
      await expect(drugRepository.create({})).rejects.toMatchObject({
        message: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.drug.create.mockRejectedValue(new Error('DB Error'));

      await expect(drugRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update drug', async () => {
      const mockDrug = { id: '123', name: 'Paracetamol Updated', code: 'PARA500' };
      prisma.drug.update.mockResolvedValue(mockDrug);

      const result = await drugRepository.update('123', { name: 'Paracetamol Updated' });
      expect(result).toEqual(mockDrug);
      expect(prisma.drug.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { name: 'Paracetamol Updated' }
      });
    });

    it('should throw HttpError if drug not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.drug.update.mockRejectedValue(error);

      await expect(drugRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
      await expect(drugRepository.update('nonexistent', {})).rejects.toMatchObject({
        message: 'errors.drug.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['code'] };
      prisma.drug.update.mockRejectedValue(error);

      await expect(drugRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.drug.update.mockRejectedValue(error);

      await expect(drugRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete drug', async () => {
      const mockDrug = { id: '123', deleted_at: new Date() };
      prisma.drug.update.mockResolvedValue(mockDrug);

      const result = await drugRepository.softDelete('123');
      expect(result).toEqual(mockDrug);
      expect(prisma.drug.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if drug not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.drug.update.mockRejectedValue(error);

      await expect(drugRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
      await expect(drugRepository.softDelete('nonexistent')).rejects.toMatchObject({
        message: 'errors.drug.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.drug.update.mockRejectedValue(new Error('DB Error'));

      await expect(drugRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
