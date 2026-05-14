/**
 * Emergency response repository tests
 *
 * @module tests/modules/emergency-response/repositories
 * @description Tests for emergency response repository data access layer
 */

const emergencyResponseRepository = require('../../../../modules/emergency-response/repositories/emergency-response.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  emergency_response: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Emergency Response Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find emergency response by id', async () => {
      const mockResponse = {
        id: 'test-id',
        emergency_case_id: 'case-id',
        response_at: new Date(),
        notes: 'test notes',
        deleted_at: null
      };

      prisma.emergency_response.findFirst.mockResolvedValue(mockResponse);

      const result = await emergencyResponseRepository.findById('test-id');

      expect(prisma.emergency_response.findFirst).toHaveBeenCalledWith({
        where: { id: 'test-id', deleted_at: null },
        include: expect.any(Object)
      });
      expect(result).toEqual(mockResponse);
    });

    it('should return null if not found', async () => {
      prisma.emergency_response.findFirst.mockResolvedValue(null);

      const result = await emergencyResponseRepository.findById('non-existent');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.emergency_response.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(emergencyResponseRepository.findById('test-id')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find emergency responses with filters', async () => {
      const mockResponses = [
        { id: '1', emergency_case_id: 'case-id', deleted_at: null },
        { id: '2', emergency_case_id: 'case-id', deleted_at: null }
      ];

      prisma.emergency_response.findMany.mockResolvedValue(mockResponses);

      const filters = { emergency_case_id: 'case-id' };
      const result = await emergencyResponseRepository.findMany(filters, 0, 10);

      expect(prisma.emergency_response.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, emergency_case_id: 'case-id' },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: expect.any(Object)
      });
      expect(result).toEqual(mockResponses);
    });

    it('should throw HttpError on database error', async () => {
      prisma.emergency_response.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(emergencyResponseRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count emergency responses with filters', async () => {
      prisma.emergency_response.count.mockResolvedValue(8);

      const filters = { emergency_case_id: 'case-id' };
      const result = await emergencyResponseRepository.count(filters);

      expect(prisma.emergency_response.count).toHaveBeenCalledWith({
        where: { deleted_at: null, emergency_case_id: 'case-id' }
      });
      expect(result).toBe(8);
    });

    it('should throw HttpError on database error', async () => {
      prisma.emergency_response.count.mockRejectedValue(new Error('DB Error'));

      await expect(emergencyResponseRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new emergency response', async () => {
      const responseData = {
        emergency_case_id: 'case-id',
        response_at: new Date(),
        notes: 'test notes'
      };
      const mockCreated = { id: 'new-id', ...responseData };

      prisma.emergency_response.create.mockResolvedValue(mockCreated);

      const result = await emergencyResponseRepository.create(responseData);

      expect(prisma.emergency_response.create).toHaveBeenCalledWith({
        data: responseData,
        include: expect.any(Object)
      });
      expect(result).toEqual(mockCreated);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'emergency_case_id' } };
      prisma.emergency_response.create.mockRejectedValue(error);

      await expect(emergencyResponseRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update emergency response', async () => {
      const updateData = { notes: 'updated notes' };
      const mockUpdated = { id: 'test-id', ...updateData };

      prisma.emergency_response.update.mockResolvedValue(mockUpdated);

      const result = await emergencyResponseRepository.update('test-id', updateData);

      expect(prisma.emergency_response.update).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        data: updateData,
        include: expect.any(Object)
      });
      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError if not found', async () => {
      const error = { code: 'P2025' };
      prisma.emergency_response.update.mockRejectedValue(error);

      await expect(emergencyResponseRepository.update('non-existent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete emergency response', async () => {
      const mockDeleted = { id: 'test-id', deleted_at: new Date() };

      prisma.emergency_response.update.mockResolvedValue(mockDeleted);

      const result = await emergencyResponseRepository.softDelete('test-id');

      expect(prisma.emergency_response.update).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        data: { deleted_at: expect.any(Date) },
        include: expect.any(Object)
      });
      expect(result).toEqual(mockDeleted);
    });

    it('should throw HttpError if not found', async () => {
      const error = { code: 'P2025' };
      prisma.emergency_response.update.mockRejectedValue(error);

      await expect(emergencyResponseRepository.softDelete('non-existent')).rejects.toThrow(HttpError);
    });
  });
});
