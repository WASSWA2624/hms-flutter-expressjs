/**
 * ICU Observation repository tests
 *
 * @module tests/modules/icu-observation/repositories
 * @description Tests for ICU observation repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const icuObservationRepository = require('@repositories/icu-observation/icu-observation.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  icu_observation: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('ICU Observation Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find ICU observation by id', async () => {
      const mockObservation = { id: '123', icu_stay_id: '456', observation: 'Test' };
      prisma.icu_observation.findFirst.mockResolvedValue(mockObservation);

      const result = await icuObservationRepository.findById('123');
      expect(result).toEqual(mockObservation);
      expect(prisma.icu_observation.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if ICU observation not found', async () => {
      prisma.icu_observation.findFirst.mockResolvedValue(null);

      const result = await icuObservationRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.icu_observation.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(icuObservationRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many ICU observations with pagination', async () => {
      const mockObservations = [
        { id: '1', icu_stay_id: '100', observation: 'Test 1' },
        { id: '2', icu_stay_id: '200', observation: 'Test 2' }
      ];
      prisma.icu_observation.findMany.mockResolvedValue(mockObservations);

      const result = await icuObservationRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockObservations);
    });

    it('should throw HttpError on database error', async () => {
      prisma.icu_observation.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(icuObservationRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count ICU observations', async () => {
      prisma.icu_observation.count.mockResolvedValue(42);

      const result = await icuObservationRepository.count({});
      expect(result).toBe(42);
    });

    it('should throw HttpError on database error', async () => {
      prisma.icu_observation.count.mockRejectedValue(new Error('DB Error'));

      await expect(icuObservationRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create ICU observation', async () => {
      const mockData = { icu_stay_id: '123', observation: 'Test' };
      const mockObservation = { id: '456', ...mockData };
      prisma.icu_observation.create.mockResolvedValue(mockObservation);

      const result = await icuObservationRepository.create(mockData);
      expect(result).toEqual(mockObservation);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'icu_stay_id' };
      prisma.icu_observation.create.mockRejectedValue(error);

      await expect(icuObservationRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update ICU observation', async () => {
      const mockObservation = { id: '123', observation: 'Updated' };
      prisma.icu_observation.update.mockResolvedValue(mockObservation);

      const result = await icuObservationRepository.update('123', { observation: 'Updated' });
      expect(result).toEqual(mockObservation);
    });

    it('should throw HttpError if ICU observation not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.icu_observation.update.mockRejectedValue(error);

      await expect(icuObservationRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete ICU observation', async () => {
      const mockObservation = { id: '123', deleted_at: new Date() };
      prisma.icu_observation.update.mockResolvedValue(mockObservation);

      const result = await icuObservationRepository.softDelete('123');
      expect(result).toEqual(mockObservation);
      expect(prisma.icu_observation.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if ICU observation not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.icu_observation.update.mockRejectedValue(error);

      await expect(icuObservationRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
    });
  });
});
