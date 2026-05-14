/**
 * Radiology Result service tests
 *
 * @module tests/modules/radiology-result/services
 * @description Tests for radiology result service
 * Per testing.mdc: Mock repository, test business logic
 */

const radiologyResultService = require('@services/radiology-result/radiology-result.service');
const radiologyResultRepository = require('@repositories/radiology-result/radiology-result.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/radiology-result/radiology-result.repository');
jest.mock('@lib/audit');

describe('Radiology Result Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listRadiologyResults', () => {
    const mockRadiologyResults = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'DRAFT',
        report_text: 'Preliminary findings.',
        reported_at: new Date('2026-01-19T14:30:00.000Z')
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440002',
        radiology_order_id: '550e8400-e29b-41d4-a716-446655440003',
        status: 'FINAL',
        report_text: 'Final report.',
        reported_at: new Date('2026-01-19T16:00:00.000Z')
      }
    ];

    it('should list radiology results with pagination', async () => {
      radiologyResultRepository.findMany.mockResolvedValue(mockRadiologyResults);
      radiologyResultRepository.count.mockResolvedValue(2);

      const result = await radiologyResultService.listRadiologyResults({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('radiology_results', mockRadiologyResults);
      expect(result).toHaveProperty('pagination');
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply filters correctly', async () => {
      const filters = {
        radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'DRAFT'
      };
      radiologyResultRepository.findMany.mockResolvedValue(mockRadiologyResults);
      radiologyResultRepository.count.mockResolvedValue(2);

      await radiologyResultService.listRadiologyResults(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyResultRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          radiology_order_id: filters.radiology_order_id,
          status: filters.status
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply search filter', async () => {
      const filters = { search: 'findings' };
      radiologyResultRepository.findMany.mockResolvedValue(mockRadiologyResults);
      radiologyResultRepository.count.mockResolvedValue(2);

      await radiologyResultService.listRadiologyResults(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyResultRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          report_text: { contains: 'findings' }
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      radiologyResultRepository.findMany.mockResolvedValue(mockRadiologyResults);
      radiologyResultRepository.count.mockResolvedValue(42);

      const result = await radiologyResultService.listRadiologyResults({}, 2, 10, null, 'asc', 'user-id', '127.0.0.1');

      expect(result.pagination).toMatchObject({
        page: 2,
        limit: 10,
        total: 42,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true
      });
      expect(radiologyResultRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        10,
        10,
        expect.any(Object)
      );
    });

    it('should handle repository errors', async () => {
      radiologyResultRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyResultService.listRadiologyResults({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getRadiologyResultById', () => {
    const radiologyResultId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyResult = {
      id: radiologyResultId,
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'DRAFT',
      report_text: 'Preliminary findings.',
      reported_at: new Date('2026-01-19T14:30:00.000Z')
    };

    it('should get radiology result by ID', async () => {
      radiologyResultRepository.findById.mockResolvedValue(mockRadiologyResult);

      const result = await radiologyResultService.getRadiologyResultById(radiologyResultId, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockRadiologyResult);
      expect(radiologyResultRepository.findById).toHaveBeenCalledWith(radiologyResultId);
    });

    it('should throw HttpError if radiology result not found', async () => {
      radiologyResultRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyResultService.getRadiologyResultById(radiologyResultId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyResultService.getRadiologyResultById(radiologyResultId, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.radiology_result.not_found',
        statusCode: 404
      });
    });
  });

  describe('createRadiologyResult', () => {
    const createData = {
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'DRAFT',
      report_text: 'Preliminary findings.',
      reported_at: new Date('2026-01-19T14:30:00.000Z')
    };

    const mockCreatedRadiologyResult = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData,
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 1
    };

    it('should create radiology result', async () => {
      radiologyResultRepository.create.mockResolvedValue(mockCreatedRadiologyResult);
      createAuditLog.mockResolvedValue({});

      const result = await radiologyResultService.createRadiologyResult(createData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockCreatedRadiologyResult);
      expect(radiologyResultRepository.create).toHaveBeenCalledWith(createData);
    });

    it('should create audit log on creation', async () => {
      radiologyResultRepository.create.mockResolvedValue(mockCreatedRadiologyResult);
      createAuditLog.mockResolvedValue({});

      await radiologyResultService.createRadiologyResult(createData, 'user-id', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'CREATE',
        entity: 'radiology_result',
        entity_id: mockCreatedRadiologyResult.id,
        diff: { after: mockCreatedRadiologyResult },
        ip_address: '127.0.0.1'
      });
    });
  });

  describe('updateRadiologyResult', () => {
    const radiologyResultId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      status: 'FINAL'
    };

    const mockBeforeRadiologyResult = {
      id: radiologyResultId,
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'DRAFT',
      report_text: 'Preliminary findings.',
      reported_at: new Date('2026-01-19T14:30:00.000Z')
    };

    const mockUpdatedRadiologyResult = {
      ...mockBeforeRadiologyResult,
      status: 'FINAL',
      updated_at: new Date()
    };

    it('should update radiology result', async () => {
      radiologyResultRepository.findById.mockResolvedValue(mockBeforeRadiologyResult);
      radiologyResultRepository.update.mockResolvedValue(mockUpdatedRadiologyResult);
      createAuditLog.mockResolvedValue({});

      const result = await radiologyResultService.updateRadiologyResult(radiologyResultId, updateData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockUpdatedRadiologyResult);
      expect(radiologyResultRepository.findById).toHaveBeenCalledWith(radiologyResultId);
      expect(radiologyResultRepository.update).toHaveBeenCalledWith(radiologyResultId, updateData);
    });

    it('should throw HttpError if radiology result not found', async () => {
      radiologyResultRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyResultService.updateRadiologyResult(radiologyResultId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyResultService.updateRadiologyResult(radiologyResultId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.radiology_result.not_found',
        statusCode: 404
      });
    });
  });

  describe('deleteRadiologyResult', () => {
    const radiologyResultId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyResult = {
      id: radiologyResultId,
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'DRAFT',
      report_text: 'Preliminary findings.',
      reported_at: new Date('2026-01-19T14:30:00.000Z')
    };

    it('should delete radiology result', async () => {
      radiologyResultRepository.findById.mockResolvedValue(mockRadiologyResult);
      radiologyResultRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      await radiologyResultService.deleteRadiologyResult(radiologyResultId, 'user-id', '127.0.0.1');

      expect(radiologyResultRepository.findById).toHaveBeenCalledWith(radiologyResultId);
      expect(radiologyResultRepository.softDelete).toHaveBeenCalledWith(radiologyResultId);
    });

    it('should throw HttpError if radiology result not found', async () => {
      radiologyResultRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyResultService.deleteRadiologyResult(radiologyResultId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyResultService.deleteRadiologyResult(radiologyResultId, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.radiology_result.not_found',
        statusCode: 404
      });
    });
  });
});
