/**
 * Ambulance Trip repository tests
 *
 * @module tests/modules/ambulance-trip/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  ambulance_trip: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/ambulance-trip/ambulance-trip.repository');

const prisma = require('@prisma/client');

describe('Ambulance Trip Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find ambulance trip by ID', async () => {
      const mockTrip = {
        id: 'trip-123',
        ambulance_id: 'ambulance-123',
        emergency_case_id: 'case-123',
        started_at: new Date('2026-01-19T10:00:00Z'),
        ended_at: new Date('2026-01-19T11:00:00Z'),
        created_at: new Date('2026-01-19'),
        deleted_at: null
      };
      prisma.ambulance_trip.findFirst.mockResolvedValue(mockTrip);

      const result = await findById('trip-123');

      expect(result).toEqual(mockTrip);
    });

    it('should return null if trip not found', async () => {
      prisma.ambulance_trip.findFirst.mockResolvedValue(null);

      const result = await findById('trip-123');

      expect(result).toBeNull();
    });
  });

  describe('findMany', () => {
    it('should find many trips', async () => {
      const mockTrips = [
        { id: 'trip-1', ambulance_id: 'ambulance-1' },
        { id: 'trip-2', ambulance_id: 'ambulance-2' }
      ];
      prisma.ambulance_trip.findMany.mockResolvedValue(mockTrips);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockTrips);
    });
  });

  describe('count', () => {
    it('should count trips', async () => {
      prisma.ambulance_trip.count.mockResolvedValue(10);

      const result = await count({});

      expect(result).toBe(10);
    });
  });

  describe('create', () => {
    it('should create trip', async () => {
      const mockTrip = {
        id: 'trip-123',
        ambulance_id: 'ambulance-123',
        emergency_case_id: 'case-123'
      };
      prisma.ambulance_trip.create.mockResolvedValue(mockTrip);

      const result = await create(mockTrip);

      expect(result).toEqual(mockTrip);
    });
  });

  describe('update', () => {
    it('should update trip', async () => {
      const mockTrip = {
        id: 'trip-123',
        ended_at: new Date('2026-01-19T11:00:00Z')
      };
      prisma.ambulance_trip.update.mockResolvedValue(mockTrip);

      const result = await update('trip-123', { ended_at: new Date('2026-01-19T11:00:00Z') });

      expect(result).toEqual(mockTrip);
    });
  });

  describe('softDelete', () => {
    it('should soft delete trip', async () => {
      const mockTrip = {
        id: 'trip-123',
        deleted_at: new Date('2026-01-19')
      };
      prisma.ambulance_trip.update.mockResolvedValue(mockTrip);

      const result = await softDelete('trip-123');

      expect(result).toEqual(mockTrip);
    });
  });
});
