/**
 * Theatre case service tests
 *
 * @module tests/modules/theatre-case/services
 * @description Tests for theatre case business logic layer
 * Per testing.mdc: Service tests must mock repositories
 */

const theatreCaseService = require('@services/theatre-case/theatre-case.service');
const theatreCaseRepository = require('@repositories/theatre-case/theatre-case.repository');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/theatre-case/theatre-case.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(),
  resolveModelRecordByIdentifier: jest.fn(),
}));

describe('Theatre Case Service', () => {
  const userId = 'user-123';
  const ipAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    resolveModelIdByIdentifier.mockResolvedValue(null);
    resolveModelRecordByIdentifier.mockResolvedValue(null);
  });

  describe('listTheatreCases', () => {
    const mockTheatreCases = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        encounter_id: '550e8400-e29b-41d4-a716-446655440001',
        scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
        status: 'SCHEDULED'
      }
    ];

    it('should list theatre cases with pagination', async () => {
      theatreCaseRepository.findMany.mockResolvedValue(mockTheatreCases);
      theatreCaseRepository.count.mockResolvedValue(1);

      const result = await theatreCaseService.listTheatreCases({}, 1, 20, 'created_at', 'desc', userId, ipAddress);

      expect(result.theatre_cases).toEqual([
        expect.objectContaining(mockTheatreCases[0]),
      ]);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply encounter_id filter', async () => {
      const filters = { encounter_id: '550e8400-e29b-41d4-a716-446655440001' };
      theatreCaseRepository.findMany.mockResolvedValue(mockTheatreCases);
      theatreCaseRepository.count.mockResolvedValue(1);

      await theatreCaseService.listTheatreCases(filters, 1, 20, null, 'asc', userId, ipAddress);

      expect(theatreCaseRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          encounter_id: filters.encounter_id
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply status filter', async () => {
      const filters = { status: 'SCHEDULED' };
      theatreCaseRepository.findMany.mockResolvedValue(mockTheatreCases);
      theatreCaseRepository.count.mockResolvedValue(1);

      await theatreCaseService.listTheatreCases(filters, 1, 20, null, 'asc', userId, ipAddress);

      expect(theatreCaseRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'SCHEDULED'
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply date range filters', async () => {
      const filters = {
        scheduled_from: '2026-01-20T00:00:00.000Z',
        scheduled_to: '2026-01-20T23:59:59.000Z'
      };
      theatreCaseRepository.findMany.mockResolvedValue(mockTheatreCases);
      theatreCaseRepository.count.mockResolvedValue(1);

      await theatreCaseService.listTheatreCases(filters, 1, 20, null, 'asc', userId, ipAddress);

      expect(theatreCaseRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          scheduled_at: {
            gte: new Date(filters.scheduled_from),
            lte: new Date(filters.scheduled_to)
          }
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      theatreCaseRepository.findMany.mockResolvedValue(mockTheatreCases);
      theatreCaseRepository.count.mockResolvedValue(45);

      const result = await theatreCaseService.listTheatreCases({}, 2, 20, null, 'asc', userId, ipAddress);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 45,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });

    it('should throw HttpError on repository error', async () => {
      theatreCaseRepository.findMany.mockRejectedValue(new Error('Database error'));

      await expect(
        theatreCaseService.listTheatreCases({}, 1, 20, null, 'asc', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getTheatreCaseById', () => {
    const mockTheatreCase = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'SCHEDULED'
    };

    it('should get theatre case by id', async () => {
      resolveModelRecordByIdentifier.mockResolvedValue({ id: mockTheatreCase.id });
      theatreCaseRepository.findById.mockResolvedValue(mockTheatreCase);

      const result = await theatreCaseService.getTheatreCaseById(mockTheatreCase.id, userId, ipAddress);

      expect(result).toEqual(expect.objectContaining(mockTheatreCase));
      expect(theatreCaseRepository.findById).toHaveBeenCalledWith(mockTheatreCase.id);
    });

    it('should throw HttpError when theatre case not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValue(null);

      await expect(
        theatreCaseService.getTheatreCaseById('non-existent-id', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      resolveModelRecordByIdentifier.mockResolvedValue({ id: 'some-id' });
      theatreCaseRepository.findById.mockRejectedValue(new Error('Database error'));

      await expect(
        theatreCaseService.getTheatreCaseById('some-id', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should resolve friendly theatre case ids before loading the record', async () => {
      resolveModelRecordByIdentifier.mockResolvedValue({ id: mockTheatreCase.id });
      theatreCaseRepository.findById.mockResolvedValue(mockTheatreCase);

      const result = await theatreCaseService.getTheatreCaseById('THC-1001');

      expect(result).toEqual(expect.objectContaining(mockTheatreCase));
      expect(resolveModelRecordByIdentifier).toHaveBeenCalledWith(
        expect.objectContaining({
          model: 'theatre_case',
          identifier: 'THC-1001',
        })
      );
      expect(theatreCaseRepository.findById).toHaveBeenCalledWith(mockTheatreCase.id);
    });
  });

  describe('createTheatreCase', () => {
    const createData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'SCHEDULED'
    };

    const mockCreatedTheatreCase = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData
    };

    it('should create theatre case', async () => {
      theatreCaseRepository.create.mockResolvedValue(mockCreatedTheatreCase);
      theatreCaseRepository.findById.mockResolvedValue(mockCreatedTheatreCase);
      createAuditLog.mockResolvedValue({});

      const result = await theatreCaseService.createTheatreCase(createData, userId, ipAddress);

      expect(result).toEqual(expect.objectContaining(mockCreatedTheatreCase));
      expect(theatreCaseRepository.create).toHaveBeenCalledWith(createData);
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: null,
        user_id: userId,
        action: 'CREATE',
        entity: 'theatre_case',
        entity_id: mockCreatedTheatreCase.id,
        diff: {
          after: mockCreatedTheatreCase,
        },
        ip_address: ipAddress,
      });
    });

    it('should throw HttpError on repository error', async () => {
      theatreCaseRepository.create.mockRejectedValue(new Error('Database error'));

      await expect(
        theatreCaseService.createTheatreCase(createData, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.foreign_key_field', 400);
      theatreCaseRepository.create.mockRejectedValue(httpError);

      await expect(
        theatreCaseService.createTheatreCase(createData, userId, ipAddress)
      ).rejects.toThrow(httpError);
    });
  });

  describe('updateTheatreCase', () => {
    const theatreCaseId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      status: 'IN_PROGRESS'
    };

    const mockExistingTheatreCase = {
      id: theatreCaseId,
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'SCHEDULED'
    };

    const mockUpdatedTheatreCase = {
      ...mockExistingTheatreCase,
      status: 'IN_PROGRESS'
    };

    it('should update theatre case', async () => {
      resolveModelRecordByIdentifier.mockResolvedValue({ id: theatreCaseId });
      theatreCaseRepository.findById
        .mockResolvedValueOnce(mockExistingTheatreCase)
        .mockResolvedValueOnce(mockUpdatedTheatreCase);
      theatreCaseRepository.update.mockResolvedValue(mockUpdatedTheatreCase);
      createAuditLog.mockResolvedValue({});

      const result = await theatreCaseService.updateTheatreCase(theatreCaseId, updateData, userId, ipAddress);

      expect(result).toEqual(expect.objectContaining(mockUpdatedTheatreCase));
      expect(theatreCaseRepository.findById).toHaveBeenCalledWith(theatreCaseId);
      expect(theatreCaseRepository.update).toHaveBeenCalledWith(theatreCaseId, updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: null,
        user_id: userId,
        action: 'UPDATE',
        entity: 'theatre_case',
        entity_id: theatreCaseId,
        diff: {
          before: mockExistingTheatreCase,
          after: mockUpdatedTheatreCase
        },
        ip_address: ipAddress,
      });
    });

    it('should throw HttpError when theatre case not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValue(null);

      await expect(
        theatreCaseService.updateTheatreCase('non-existent-id', updateData, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      resolveModelRecordByIdentifier.mockResolvedValue({ id: theatreCaseId });
      theatreCaseRepository.findById.mockResolvedValue(mockExistingTheatreCase);
      theatreCaseRepository.update.mockRejectedValue(new Error('Database error'));

      await expect(
        theatreCaseService.updateTheatreCase(theatreCaseId, updateData, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteTheatreCase', () => {
    const theatreCaseId = '550e8400-e29b-41d4-a716-446655440000';

    const mockExistingTheatreCase = {
      id: theatreCaseId,
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'SCHEDULED'
    };

    it('should delete theatre case', async () => {
      resolveModelRecordByIdentifier.mockResolvedValue({ id: theatreCaseId });
      theatreCaseRepository.findById.mockResolvedValue(mockExistingTheatreCase);
      theatreCaseRepository.softDelete.mockResolvedValue(mockExistingTheatreCase);
      createAuditLog.mockResolvedValue({});

      await theatreCaseService.deleteTheatreCase(theatreCaseId, userId, ipAddress);

      expect(theatreCaseRepository.findById).toHaveBeenCalledWith(theatreCaseId);
      expect(theatreCaseRepository.softDelete).toHaveBeenCalledWith(theatreCaseId);
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: null,
        user_id: userId,
        action: 'DELETE',
        entity: 'theatre_case',
        entity_id: theatreCaseId,
        diff: { before: mockExistingTheatreCase },
        ip_address: ipAddress,
      });
    });

    it('should throw HttpError when theatre case not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValue(null);

      await expect(
        theatreCaseService.deleteTheatreCase('non-existent-id', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      resolveModelRecordByIdentifier.mockResolvedValue({ id: theatreCaseId });
      theatreCaseRepository.findById.mockResolvedValue(mockExistingTheatreCase);
      theatreCaseRepository.softDelete.mockRejectedValue(new Error('Database error'));

      await expect(
        theatreCaseService.deleteTheatreCase(theatreCaseId, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
