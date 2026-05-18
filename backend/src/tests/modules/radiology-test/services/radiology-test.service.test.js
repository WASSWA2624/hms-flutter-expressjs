/**
 * Radiology test service tests
 *
 * @module tests/modules/radiology-test/services
 * @description Tests for radiology test service
 * Per testing.mdc: Mock repository, test business logic
 */

const radiologyTestService = require('@services/radiology-test/radiology-test.service');
const radiologyTestRepository = require('@repositories/radiology-test/radiology-test.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/radiology-test/radiology-test.repository');
jest.mock('@lib/audit');

describe('Radiology Test Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listRadiologyTests', () => {
    const mockRadiologyTests = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Chest X-Ray',
        code: 'CXR-001',
        modality: 'XRAY'
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440001',
        name: 'Brain MRI',
        code: 'MRI-001',
        modality: 'MRI'
      }
    ];

    it('should list radiology tests with pagination', async () => {
      radiologyTestRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyTestRepository.count.mockResolvedValue(2);

      const result = await radiologyTestService.listRadiologyTests({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('radiologyTests', mockRadiologyTests);
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
        tenant_id: '550e8400-e29b-41d4-a716-446655440002',
        modality: 'XRAY'
      };
      radiologyTestRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyTestRepository.count.mockResolvedValue(2);

      await radiologyTestService.listRadiologyTests(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyTestRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: filters.tenant_id,
          modality: filters.modality
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply name filter with contains', async () => {
      const filters = { name: 'X-Ray' };
      radiologyTestRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyTestRepository.count.mockResolvedValue(2);

      await radiologyTestService.listRadiologyTests(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyTestRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          name: { contains: 'X-Ray' }
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply code filter with contains', async () => {
      const filters = { code: 'CXR' };
      radiologyTestRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyTestRepository.count.mockResolvedValue(2);

      await radiologyTestService.listRadiologyTests(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyTestRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          code: { contains: 'CXR' }
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply search filter with OR clause', async () => {
      const filters = { search: 'chest' };
      radiologyTestRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyTestRepository.count.mockResolvedValue(2);

      await radiologyTestService.listRadiologyTests(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyTestRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            { name: { contains: 'chest' } },
            { code: { contains: 'chest' } }
          ])
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      radiologyTestRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyTestRepository.count.mockResolvedValue(42);

      const result = await radiologyTestService.listRadiologyTests({}, 2, 10, null, 'asc', 'user-id', '127.0.0.1');

      expect(result.pagination).toMatchObject({
        page: 2,
        limit: 10,
        total: 42,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true
      });
      expect(radiologyTestRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        10, // skip: (2-1) * 10
        10,
        expect.any(Object)
      );
    });

    it('should apply custom sorting', async () => {
      radiologyTestRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyTestRepository.count.mockResolvedValue(2);

      await radiologyTestService.listRadiologyTests({}, 1, 20, 'name', 'desc', 'user-id', '127.0.0.1');

      expect(radiologyTestRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        { name: 'desc' }
      );
    });

    it('should use default sorting when sortBy not provided', async () => {
      radiologyTestRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyTestRepository.count.mockResolvedValue(2);

      await radiologyTestService.listRadiologyTests({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyTestRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        { created_at: 'desc' }
      );
    });

    it('should include a large standard catalog when requested', async () => {
      radiologyTestRepository.findMany.mockResolvedValue([]);
      radiologyTestRepository.count.mockResolvedValue(0);

      const result = await radiologyTestService.listRadiologyTests(
        { include_standard_catalog: true },
        1,
        5000,
        'name',
        'asc',
        'user-id',
        '127.0.0.1'
      );

      expect(result.radiologyTests).toHaveLength(5000);
      expect(result.radiologyTests[0]).toEqual(
        expect.objectContaining({
          id: expect.stringMatching(/^STD_RAD_TEST_/),
          modality: expect.any(String),
          equipment: expect.any(String),
          procedure_type: expect.any(String)
        })
      );
      expect(result.pagination.total).toBeGreaterThanOrEqual(5000);
    });

    it('should handle repository errors', async () => {
      radiologyTestRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyTestService.listRadiologyTests({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.unexpected', 500);
      radiologyTestRepository.findMany.mockRejectedValue(httpError);

      await expect(
        radiologyTestService.listRadiologyTests({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('getRadiologyTestById', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyTest = {
      id: radiologyTestId,
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY'
    };

    it('should get radiology test by ID', async () => {
      radiologyTestRepository.findById.mockResolvedValue(mockRadiologyTest);

      const result = await radiologyTestService.getRadiologyTestById(radiologyTestId, 'requester-id', '127.0.0.1');

      expect(result).toEqual(mockRadiologyTest);
      expect(radiologyTestRepository.findById).toHaveBeenCalledWith(radiologyTestId);
    });

    it('should throw HttpError if radiology test not found', async () => {
      radiologyTestRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyTestService.getRadiologyTestById(radiologyTestId, 'requester-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyTestService.getRadiologyTestById(radiologyTestId, 'requester-id', '127.0.0.1')
      ).rejects.toMatchObject({
        message: 'errors.radiology_test.not_found',
        statusCode: 404
      });
    });

    it('should handle repository errors', async () => {
      radiologyTestRepository.findById.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyTestService.getRadiologyTestById(radiologyTestId, 'requester-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.unexpected', 500);
      radiologyTestRepository.findById.mockRejectedValue(httpError);

      await expect(
        radiologyTestService.getRadiologyTestById(radiologyTestId, 'requester-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('createRadiologyTest', () => {
    const createData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY'
    };

    const mockCreatedRadiologyTest = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData
    };

    it('should create radiology test', async () => {
      radiologyTestRepository.create.mockResolvedValue(mockCreatedRadiologyTest);
      createAuditLog.mockResolvedValue({});

      const result = await radiologyTestService.createRadiologyTest(createData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockCreatedRadiologyTest);
      expect(radiologyTestRepository.create).toHaveBeenCalledWith(createData);
    });

    it('should create audit log on success', async () => {
      radiologyTestRepository.create.mockResolvedValue(mockCreatedRadiologyTest);
      createAuditLog.mockResolvedValue({});

      await radiologyTestService.createRadiologyTest(createData, 'user-id', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'CREATE',
        entity: 'radiology_test',
        entity_id: mockCreatedRadiologyTest.id,
        diff: { after: mockCreatedRadiologyTest },
        ip_address: '127.0.0.1'
      });
    });

    it('should not fail if audit log fails', async () => {
      radiologyTestRepository.create.mockResolvedValue(mockCreatedRadiologyTest);
      createAuditLog.mockRejectedValue(new Error('Audit Error'));

      const result = await radiologyTestService.createRadiologyTest(createData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockCreatedRadiologyTest);
    });

    it('should handle repository errors', async () => {
      radiologyTestRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyTestService.createRadiologyTest(createData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.unique_field', 409);
      radiologyTestRepository.create.mockRejectedValue(httpError);

      await expect(
        radiologyTestService.createRadiologyTest(createData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('updateRadiologyTest', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      name: 'Updated X-Ray',
      modality: 'CT'
    };

    const mockBeforeUpdate = {
      id: radiologyTestId,
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY'
    };

    const mockUpdatedRadiologyTest = {
      id: radiologyTestId,
      ...updateData,
      code: 'CXR-001'
    };

    it('should update radiology test', async () => {
      radiologyTestRepository.findById.mockResolvedValue(mockBeforeUpdate);
      radiologyTestRepository.update.mockResolvedValue(mockUpdatedRadiologyTest);
      createAuditLog.mockResolvedValue({});

      const result = await radiologyTestService.updateRadiologyTest(radiologyTestId, updateData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockUpdatedRadiologyTest);
      expect(radiologyTestRepository.update).toHaveBeenCalledWith(radiologyTestId, updateData);
    });

    it('should throw HttpError if radiology test not found', async () => {
      radiologyTestRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyTestService.updateRadiologyTest(radiologyTestId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyTestService.updateRadiologyTest(radiologyTestId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        message: 'errors.radiology_test.not_found',
        statusCode: 404
      });
    });

    it('should create audit log on success', async () => {
      radiologyTestRepository.findById.mockResolvedValue(mockBeforeUpdate);
      radiologyTestRepository.update.mockResolvedValue(mockUpdatedRadiologyTest);
      createAuditLog.mockResolvedValue({});

      await radiologyTestService.updateRadiologyTest(radiologyTestId, updateData, 'user-id', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'UPDATE',
        entity: 'radiology_test',
        entity_id: mockUpdatedRadiologyTest.id,
        diff: { before: mockBeforeUpdate, after: mockUpdatedRadiologyTest },
        ip_address: '127.0.0.1'
      });
    });

    it('should not fail if audit log fails', async () => {
      radiologyTestRepository.findById.mockResolvedValue(mockBeforeUpdate);
      radiologyTestRepository.update.mockResolvedValue(mockUpdatedRadiologyTest);
      createAuditLog.mockRejectedValue(new Error('Audit Error'));

      const result = await radiologyTestService.updateRadiologyTest(radiologyTestId, updateData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockUpdatedRadiologyTest);
    });

    it('should handle repository errors', async () => {
      radiologyTestRepository.findById.mockResolvedValue(mockBeforeUpdate);
      radiologyTestRepository.update.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyTestService.updateRadiologyTest(radiologyTestId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      radiologyTestRepository.findById.mockResolvedValue(mockBeforeUpdate);
      const httpError = new HttpError('errors.database.unique_field', 409);
      radiologyTestRepository.update.mockRejectedValue(httpError);

      await expect(
        radiologyTestService.updateRadiologyTest(radiologyTestId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('deleteRadiologyTest', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyTest = {
      id: radiologyTestId,
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY'
    };

    it('should delete radiology test', async () => {
      radiologyTestRepository.findById.mockResolvedValue(mockRadiologyTest);
      radiologyTestRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      await radiologyTestService.deleteRadiologyTest(radiologyTestId, 'user-id', '127.0.0.1');

      expect(radiologyTestRepository.softDelete).toHaveBeenCalledWith(radiologyTestId);
    });

    it('should throw HttpError if radiology test not found', async () => {
      radiologyTestRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyTestService.deleteRadiologyTest(radiologyTestId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyTestService.deleteRadiologyTest(radiologyTestId, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        message: 'errors.radiology_test.not_found',
        statusCode: 404
      });
    });

    it('should create audit log on success', async () => {
      radiologyTestRepository.findById.mockResolvedValue(mockRadiologyTest);
      radiologyTestRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      await radiologyTestService.deleteRadiologyTest(radiologyTestId, 'user-id', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'DELETE',
        entity: 'radiology_test',
        entity_id: radiologyTestId,
        diff: { before: mockRadiologyTest },
        ip_address: '127.0.0.1'
      });
    });

    it('should not fail if audit log fails', async () => {
      radiologyTestRepository.findById.mockResolvedValue(mockRadiologyTest);
      radiologyTestRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockRejectedValue(new Error('Audit Error'));

      await radiologyTestService.deleteRadiologyTest(radiologyTestId, 'user-id', '127.0.0.1');

      expect(radiologyTestRepository.softDelete).toHaveBeenCalledWith(radiologyTestId);
    });

    it('should handle repository errors', async () => {
      radiologyTestRepository.findById.mockResolvedValue(mockRadiologyTest);
      radiologyTestRepository.softDelete.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyTestService.deleteRadiologyTest(radiologyTestId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      radiologyTestRepository.findById.mockResolvedValue(mockRadiologyTest);
      const httpError = new HttpError('errors.database.unexpected', 500);
      radiologyTestRepository.softDelete.mockRejectedValue(httpError);

      await expect(
        radiologyTestService.deleteRadiologyTest(radiologyTestId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });
});
