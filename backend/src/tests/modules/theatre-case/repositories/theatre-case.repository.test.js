/**
 * Theatre case repository tests
 *
 * @module tests/modules/theatre-case/repositories
 * @description Tests for theatre case data access layer
 * Per testing.mdc: Repository tests must mock Prisma
 */

const theatreCaseRepository = require('@repositories/theatre-case/theatre-case.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  theatre_case: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Theatre Case Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const mockTheatreCase = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'SCHEDULED',
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 1
    };

    it('should find theatre case by id', async () => {
      prisma.theatre_case.findFirst.mockResolvedValue(mockTheatreCase);

      const result = await theatreCaseRepository.findById(mockTheatreCase.id);

      expect(result).toEqual(mockTheatreCase);
      expect(prisma.theatre_case.findFirst).toHaveBeenCalledWith({
        where: {
          id: mockTheatreCase.id,
          deleted_at: null
        },
        include: theatreCaseRepository.BASE_INCLUDE
      });
    });

    it('should return null if theatre case not found', async () => {
      prisma.theatre_case.findFirst.mockResolvedValue(null);

      const result = await theatreCaseRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.theatre_case.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(theatreCaseRepository.findById('some-id'))
        .rejects
        .toThrow(HttpError);
    });

    it('should support include relations', async () => {
      const include = { encounter: true };
      prisma.theatre_case.findFirst.mockResolvedValue(mockTheatreCase);

      await theatreCaseRepository.findById(mockTheatreCase.id, include);

      expect(prisma.theatre_case.findFirst).toHaveBeenCalledWith({
        where: {
          id: mockTheatreCase.id,
          deleted_at: null
        },
        include: {
          ...theatreCaseRepository.BASE_INCLUDE,
          ...include,
        }
      });
    });
  });

  describe('findMany', () => {
    const mockTheatreCases = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        encounter_id: '550e8400-e29b-41d4-a716-446655440001',
        scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
        status: 'SCHEDULED',
        deleted_at: null
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440002',
        encounter_id: '550e8400-e29b-41d4-a716-446655440003',
        scheduled_at: new Date('2026-01-21T11:00:00.000Z'),
        status: 'IN_PROGRESS',
        deleted_at: null
      }
    ];

    it('should find many theatre cases', async () => {
      prisma.theatre_case.findMany.mockResolvedValue(mockTheatreCases);

      const result = await theatreCaseRepository.findMany();

      expect(result).toEqual(mockTheatreCases);
      expect(prisma.theatre_case.findMany).toHaveBeenCalled();
    });

    it('should apply filters', async () => {
      const filters = { status: 'SCHEDULED' };
      prisma.theatre_case.findMany.mockResolvedValue([mockTheatreCases[0]]);

      await theatreCaseRepository.findMany(filters);

      expect(prisma.theatre_case.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            deleted_at: null,
            status: 'SCHEDULED'
          })
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.theatre_case.findMany.mockResolvedValue(mockTheatreCases);

      await theatreCaseRepository.findMany({}, 10, 5);

      expect(prisma.theatre_case.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 10,
          take: 5
        })
      );
    });

    it('should apply ordering', async () => {
      const orderBy = { scheduled_at: 'asc' };
      prisma.theatre_case.findMany.mockResolvedValue(mockTheatreCases);

      await theatreCaseRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.theatre_case.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.theatre_case.findMany.mockRejectedValue(new Error('Database error'));

      await expect(theatreCaseRepository.findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count theatre cases', async () => {
      prisma.theatre_case.count.mockResolvedValue(10);

      const result = await theatreCaseRepository.count();

      expect(result).toBe(10);
      expect(prisma.theatre_case.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count with filters', async () => {
      const filters = { status: 'SCHEDULED' };
      prisma.theatre_case.count.mockResolvedValue(5);

      const result = await theatreCaseRepository.count(filters);

      expect(result).toBe(5);
      expect(prisma.theatre_case.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          status: 'SCHEDULED'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.theatre_case.count.mockRejectedValue(new Error('Database error'));

      await expect(theatreCaseRepository.count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    const createData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'SCHEDULED'
    };

    const mockCreatedTheatreCase = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData,
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 1
    };

    it('should create theatre case', async () => {
      prisma.theatre_case.create.mockResolvedValue(mockCreatedTheatreCase);

      const result = await theatreCaseRepository.create(createData);

      expect(result).toEqual(mockCreatedTheatreCase);
      expect(prisma.theatre_case.create).toHaveBeenCalledWith({
        data: createData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['encounter_id'] };
      prisma.theatre_case.create.mockRejectedValue(error);

      await expect(theatreCaseRepository.create(createData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'encounter_id' };
      prisma.theatre_case.create.mockRejectedValue(error);

      await expect(theatreCaseRepository.create(createData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.theatre_case.create.mockRejectedValue(new Error('Database error'));

      await expect(theatreCaseRepository.create(createData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    const updateData = {
      status: 'IN_PROGRESS'
    };

    const mockUpdatedTheatreCase = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'IN_PROGRESS',
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 2
    };

    it('should update theatre case', async () => {
      prisma.theatre_case.update.mockResolvedValue(mockUpdatedTheatreCase);

      const result = await theatreCaseRepository.update(mockUpdatedTheatreCase.id, updateData);

      expect(result).toEqual(mockUpdatedTheatreCase);
      expect(prisma.theatre_case.update).toHaveBeenCalledWith({
        where: { id: mockUpdatedTheatreCase.id },
        data: updateData
      });
    });

    it('should throw HttpError when theatre case not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.theatre_case.update.mockRejectedValue(error);

      await expect(theatreCaseRepository.update('non-existent-id', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['encounter_id'] };
      prisma.theatre_case.update.mockRejectedValue(error);

      await expect(theatreCaseRepository.update('some-id', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'encounter_id' };
      prisma.theatre_case.update.mockRejectedValue(error);

      await expect(theatreCaseRepository.update('some-id', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.theatre_case.update.mockRejectedValue(new Error('Database error'));

      await expect(theatreCaseRepository.update('some-id', updateData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const mockDeletedTheatreCase = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'SCHEDULED',
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: new Date(),
      version: 1
    };

    it('should soft delete theatre case', async () => {
      prisma.theatre_case.update.mockResolvedValue(mockDeletedTheatreCase);

      const result = await theatreCaseRepository.softDelete(mockDeletedTheatreCase.id);

      expect(result).toEqual(mockDeletedTheatreCase);
      expect(prisma.theatre_case.update).toHaveBeenCalledWith({
        where: { id: mockDeletedTheatreCase.id },
        data: expect.objectContaining({
          deleted_at: expect.any(Date)
        })
      });
    });

    it('should throw HttpError when theatre case not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.theatre_case.update.mockRejectedValue(error);

      await expect(theatreCaseRepository.softDelete('non-existent-id'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.theatre_case.update.mockRejectedValue(new Error('Database error'));

      await expect(theatreCaseRepository.softDelete('some-id'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
