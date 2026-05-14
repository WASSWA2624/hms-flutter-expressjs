/**
 * Anesthesia record repository tests
 *
 * @module tests/modules/anesthesia-record/repositories
 * @description Tests for Anesthesia record data access layer
 * Per testing.mdc: Repository tests must mock Prisma
 */

const anesthesiaRecordRepository = require('@repositories/anesthesia-record/anesthesia-record.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  anesthesia_record: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Anesthesia record Repository', () => {
  const defaultIncludeMatcher = expect.objectContaining(
    anesthesiaRecordRepository.BASE_INCLUDE
  );

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const mockanesthesiaRecord = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      theatre_case_id: '550e8400-e29b-41d4-a716-446655440001',
      anesthetist_user_id: '550e8400-e29b-41d4-a716-446655440002',
      notes: 'Test notes',
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 1
    };

    it('should find Anesthesia record by id', async () => {
      prisma.anesthesia_record.findFirst.mockResolvedValue(mockanesthesiaRecord);

      const result = await anesthesiaRecordRepository.findById(mockanesthesiaRecord.id);

      expect(result).toEqual(mockanesthesiaRecord);
      expect(prisma.anesthesia_record.findFirst).toHaveBeenCalledWith({
        where: {
          id: mockanesthesiaRecord.id,
          deleted_at: null
        },
        include: defaultIncludeMatcher
      });
    });

    it('should return null if Anesthesia record not found', async () => {
      prisma.anesthesia_record.findFirst.mockResolvedValue(null);

      const result = await anesthesiaRecordRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.anesthesia_record.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(anesthesiaRecordRepository.findById('some-id'))
        .rejects
        .toThrow(HttpError);
    });

    it('should support include relations', async () => {
      const include = { encounter: true };
      prisma.anesthesia_record.findFirst.mockResolvedValue(mockanesthesiaRecord);

      await anesthesiaRecordRepository.findById(mockanesthesiaRecord.id, include);

      expect(prisma.anesthesia_record.findFirst).toHaveBeenCalledWith({
        where: {
          id: mockanesthesiaRecord.id,
          deleted_at: null
        },
        include: expect.objectContaining({
          ...anesthesiaRecordRepository.BASE_INCLUDE,
          ...include
        })
      });
    });
  });

  describe('findMany', () => {
    const mockanesthesiaRecords = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        theatre_case_id: '550e8400-e29b-41d4-a716-446655440001',
        anesthetist_user_id: '550e8400-e29b-41d4-a716-446655440002',
        notes: 'Test notes',
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

    it('should find many Anesthesia records', async () => {
      prisma.anesthesia_record.findMany.mockResolvedValue(mockanesthesiaRecords);

      const result = await anesthesiaRecordRepository.findMany();

      expect(result).toEqual(mockanesthesiaRecords);
      expect(prisma.anesthesia_record.findMany).toHaveBeenCalled();
    });

    it('should apply filters', async () => {
      const filters = { status: 'SCHEDULED' };
      prisma.anesthesia_record.findMany.mockResolvedValue([mockanesthesiaRecords[0]]);

      await anesthesiaRecordRepository.findMany(filters);

      expect(prisma.anesthesia_record.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            deleted_at: null,
            status: 'SCHEDULED'
          })
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.anesthesia_record.findMany.mockResolvedValue(mockanesthesiaRecords);

      await anesthesiaRecordRepository.findMany({}, 10, 5);

      expect(prisma.anesthesia_record.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 10,
          take: 5
        })
      );
    });

    it('should apply ordering', async () => {
      const orderBy = { scheduled_at: 'asc' };
      prisma.anesthesia_record.findMany.mockResolvedValue(mockanesthesiaRecords);

      await anesthesiaRecordRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.anesthesia_record.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.anesthesia_record.findMany.mockRejectedValue(new Error('Database error'));

      await expect(anesthesiaRecordRepository.findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count Anesthesia records', async () => {
      prisma.anesthesia_record.count.mockResolvedValue(10);

      const result = await anesthesiaRecordRepository.count();

      expect(result).toBe(10);
      expect(prisma.anesthesia_record.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count with filters', async () => {
      const filters = { status: 'SCHEDULED' };
      prisma.anesthesia_record.count.mockResolvedValue(5);

      const result = await anesthesiaRecordRepository.count(filters);

      expect(result).toBe(5);
      expect(prisma.anesthesia_record.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          status: 'SCHEDULED'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.anesthesia_record.count.mockRejectedValue(new Error('Database error'));

      await expect(anesthesiaRecordRepository.count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    const createData = {
      theatre_case_id: '550e8400-e29b-41d4-a716-446655440001',
      anesthetist_user_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'SCHEDULED'
    };

    const mockCreatedanesthesiaRecord = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData,
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 1
    };

    it('should create Anesthesia record', async () => {
      prisma.anesthesia_record.create.mockResolvedValue(mockCreatedanesthesiaRecord);

      const result = await anesthesiaRecordRepository.create(createData);

      expect(result).toEqual(mockCreatedanesthesiaRecord);
      expect(prisma.anesthesia_record.create).toHaveBeenCalledWith({
        data: createData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['encounter_id'] };
      prisma.anesthesia_record.create.mockRejectedValue(error);

      await expect(anesthesiaRecordRepository.create(createData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'encounter_id' };
      prisma.anesthesia_record.create.mockRejectedValue(error);

      await expect(anesthesiaRecordRepository.create(createData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.anesthesia_record.create.mockRejectedValue(new Error('Database error'));

      await expect(anesthesiaRecordRepository.create(createData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    const updateData = {
      status: 'IN_PROGRESS'
    };

    const mockUpdatedanesthesiaRecord = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      theatre_case_id: '550e8400-e29b-41d4-a716-446655440001',
      anesthetist_user_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'IN_PROGRESS',
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 2
    };

    it('should update Anesthesia record', async () => {
      prisma.anesthesia_record.update.mockResolvedValue(mockUpdatedanesthesiaRecord);

      const result = await anesthesiaRecordRepository.update(mockUpdatedanesthesiaRecord.id, updateData);

      expect(result).toEqual(mockUpdatedanesthesiaRecord);
      expect(prisma.anesthesia_record.update).toHaveBeenCalledWith({
        where: { id: mockUpdatedanesthesiaRecord.id },
        data: updateData
      });
    });

    it('should throw HttpError when Anesthesia record not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.anesthesia_record.update.mockRejectedValue(error);

      await expect(anesthesiaRecordRepository.update('non-existent-id', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['encounter_id'] };
      prisma.anesthesia_record.update.mockRejectedValue(error);

      await expect(anesthesiaRecordRepository.update('some-id', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'encounter_id' };
      prisma.anesthesia_record.update.mockRejectedValue(error);

      await expect(anesthesiaRecordRepository.update('some-id', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.anesthesia_record.update.mockRejectedValue(new Error('Database error'));

      await expect(anesthesiaRecordRepository.update('some-id', updateData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const mockDeletedanesthesiaRecord = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      theatre_case_id: '550e8400-e29b-41d4-a716-446655440001',
      anesthetist_user_id: '550e8400-e29b-41d4-a716-446655440002',
      notes: 'Test notes',
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: new Date(),
      version: 1
    };

    it('should soft delete Anesthesia record', async () => {
      prisma.anesthesia_record.update.mockResolvedValue(mockDeletedanesthesiaRecord);

      const result = await anesthesiaRecordRepository.softDelete(mockDeletedanesthesiaRecord.id);

      expect(result).toEqual(mockDeletedanesthesiaRecord);
      expect(prisma.anesthesia_record.update).toHaveBeenCalledWith({
        where: { id: mockDeletedanesthesiaRecord.id },
        data: expect.objectContaining({
          deleted_at: expect.any(Date)
        })
      });
    });

    it('should throw HttpError when Anesthesia record not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.anesthesia_record.update.mockRejectedValue(error);

      await expect(anesthesiaRecordRepository.softDelete('non-existent-id'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.anesthesia_record.update.mockRejectedValue(new Error('Database error'));

      await expect(anesthesiaRecordRepository.softDelete('some-id'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
