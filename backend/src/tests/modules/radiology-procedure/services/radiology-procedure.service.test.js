/**
 * Radiology test service tests
 *
 * @module tests/modules/radiology-procedure/services
 * @description Tests for radiology test service
 * Per testing.mdc: Mock repository, test business logic
 */

const radiologyProcedureService = require('@services/radiology-procedure/radiology-procedure.service');
const radiologyProcedureRepository = require('@repositories/radiology-procedure/radiology-procedure.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/radiology-procedure/radiology-procedure.repository');
jest.mock('@lib/audit');

describe('Radiology Test Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listRadiologyProcedures', () => {
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
      radiologyProcedureRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyProcedureRepository.count.mockResolvedValue(2);

      const result = await radiologyProcedureService.listRadiologyProcedures({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('radiologyProcedures', mockRadiologyTests);
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
      radiologyProcedureRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyProcedureRepository.count.mockResolvedValue(2);

      await radiologyProcedureService.listRadiologyProcedures(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyProcedureRepository.findMany).toHaveBeenCalledWith(
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
      radiologyProcedureRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyProcedureRepository.count.mockResolvedValue(2);

      await radiologyProcedureService.listRadiologyProcedures(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyProcedureRepository.findMany).toHaveBeenCalledWith(
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
      radiologyProcedureRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyProcedureRepository.count.mockResolvedValue(2);

      await radiologyProcedureService.listRadiologyProcedures(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyProcedureRepository.findMany).toHaveBeenCalledWith(
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
      radiologyProcedureRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyProcedureRepository.count.mockResolvedValue(2);

      await radiologyProcedureService.listRadiologyProcedures(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyProcedureRepository.findMany).toHaveBeenCalledWith(
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
      radiologyProcedureRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyProcedureRepository.count.mockResolvedValue(42);

      const result = await radiologyProcedureService.listRadiologyProcedures({}, 2, 10, null, 'asc', 'user-id', '127.0.0.1');

      expect(result.pagination).toMatchObject({
        page: 2,
        limit: 10,
        total: 42,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true
      });
      expect(radiologyProcedureRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        10, // skip: (2-1) * 10
        10,
        expect.any(Object)
      );
    });

    it('should apply custom sorting', async () => {
      radiologyProcedureRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyProcedureRepository.count.mockResolvedValue(2);

      await radiologyProcedureService.listRadiologyProcedures({}, 1, 20, 'name', 'desc', 'user-id', '127.0.0.1');

      expect(radiologyProcedureRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        { name: 'desc' }
      );
    });

    it('should use default sorting when sortBy not provided', async () => {
      radiologyProcedureRepository.findMany.mockResolvedValue(mockRadiologyTests);
      radiologyProcedureRepository.count.mockResolvedValue(2);

      await radiologyProcedureService.listRadiologyProcedures({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyProcedureRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        { created_at: 'desc' }
      );
    });

    it('should include a large standard catalog when requested', async () => {
      radiologyProcedureRepository.findMany.mockResolvedValue([]);
      radiologyProcedureRepository.count.mockResolvedValue(0);

      const result = await radiologyProcedureService.listRadiologyProcedures(
        { include_standard_catalog: true },
        1,
        5000,
        'name',
        'asc',
        'user-id',
        '127.0.0.1'
      );

      expect(result.radiologyProcedures).toHaveLength(5000);
      expect(result.radiologyProcedures[0]).toEqual(
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
      radiologyProcedureRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyProcedureService.listRadiologyProcedures({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.unexpected', 500);
      radiologyProcedureRepository.findMany.mockRejectedValue(httpError);

      await expect(
        radiologyProcedureService.listRadiologyProcedures({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('getRadiologyProcedureById', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyTest = {
      id: radiologyTestId,
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY'
    };

    it('should get radiology test by ID', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockRadiologyTest);

      const result = await radiologyProcedureService.getRadiologyProcedureById(radiologyTestId, 'requester-id', '127.0.0.1');

      expect(result).toEqual(mockRadiologyTest);
      expect(radiologyProcedureRepository.findById).toHaveBeenCalledWith(radiologyTestId);
    });

    it('should throw HttpError if radiology test not found', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyProcedureService.getRadiologyProcedureById(radiologyTestId, 'requester-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyProcedureService.getRadiologyProcedureById(radiologyTestId, 'requester-id', '127.0.0.1')
      ).rejects.toMatchObject({
        message: 'errors.radiology_test.not_found',
        statusCode: 404
      });
    });

    it('should handle repository errors', async () => {
      radiologyProcedureRepository.findById.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyProcedureService.getRadiologyProcedureById(radiologyTestId, 'requester-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.unexpected', 500);
      radiologyProcedureRepository.findById.mockRejectedValue(httpError);

      await expect(
        radiologyProcedureService.getRadiologyProcedureById(radiologyTestId, 'requester-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('createRadiologyProcedure', () => {
    const createData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      name: 'Zzyx Custom Imaging Alpha',
      code: 'ZZYX-ALPHA-001',
      modality: 'XRAY'
    };

    const mockCreatedRadiologyTest = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData
    };

    beforeEach(() => {
      radiologyProcedureRepository.findMany.mockResolvedValue([]);
    });

    it('should create radiology test', async () => {
      radiologyProcedureRepository.create.mockResolvedValue(mockCreatedRadiologyTest);
      createAuditLog.mockResolvedValue({});

      const result = await radiologyProcedureService.createRadiologyProcedure(createData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockCreatedRadiologyTest);
      expect(radiologyProcedureRepository.create).toHaveBeenCalledWith({
        tenant_id: createData.tenant_id,
        name: createData.name,
        code: createData.code,
        modality: createData.modality
      });
      expect(radiologyProcedureRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: createData.tenant_id },
        0,
        7500,
        { name: 'asc' }
      );
    });

    it('should create audit log on success', async () => {
      radiologyProcedureRepository.create.mockResolvedValue(mockCreatedRadiologyTest);
      createAuditLog.mockResolvedValue({});

      await radiologyProcedureService.createRadiologyProcedure(createData, 'user-id', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'CREATE',
        entity: 'radiology_procedure',
        entity_id: mockCreatedRadiologyTest.id,
        diff: { after: mockCreatedRadiologyTest },
        ip_address: '127.0.0.1'
      });
    });

    it('should not fail if audit log fails', async () => {
      radiologyProcedureRepository.create.mockResolvedValue(mockCreatedRadiologyTest);
      createAuditLog.mockRejectedValue(new Error('Audit Error'));

      const result = await radiologyProcedureService.createRadiologyProcedure(createData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockCreatedRadiologyTest);
    });

    it('should reject exact name duplicates', async () => {
      radiologyProcedureRepository.findMany.mockResolvedValue([
        {
          id: 'existing-1',
          name: 'Zzyx Custom Imaging Alpha',
          code: 'OTHER',
          modality: 'XRAY'
        }
      ]);

      await expect(
        radiologyProcedureService.createRadiologyProcedure(createData, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        message: 'errors.radiology_test.duplicate_name',
        statusCode: 409
      });
      expect(radiologyProcedureRepository.create).not.toHaveBeenCalled();
    });

    it('should reject exact code duplicates', async () => {
      radiologyProcedureRepository.findMany.mockResolvedValue([
        {
          id: 'existing-1',
          name: 'Different Name',
          code: 'zzyx-alpha-001',
          modality: 'XRAY'
        }
      ]);

      await expect(
        radiologyProcedureService.createRadiologyProcedure(createData, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        message: 'errors.radiology_test.duplicate_code',
        statusCode: 409
      });
      expect(radiologyProcedureRepository.create).not.toHaveBeenCalled();
    });

    it('should reject similar names without confirm_similar', async () => {
      radiologyProcedureRepository.findMany.mockResolvedValue([
        {
          id: 'existing-1',
          name: 'Zzyx Custom Imaging Alph',
          code: 'OTHER',
          modality: 'XRAY'
        }
      ]);

      await expect(
        radiologyProcedureService.createRadiologyProcedure(createData, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        message: 'errors.radiology_test.similar_exists',
        statusCode: 409
      });
      expect(radiologyProcedureRepository.create).not.toHaveBeenCalled();
    });

    it('should create when confirm_similar is true for near matches', async () => {
      radiologyProcedureRepository.findMany.mockResolvedValue([
        {
          id: 'existing-1',
          name: 'Zzyx Custom Imaging Alph',
          code: 'OTHER',
          modality: 'XRAY'
        }
      ]);
      radiologyProcedureRepository.create.mockResolvedValue(mockCreatedRadiologyTest);
      createAuditLog.mockResolvedValue({});

      const result = await radiologyProcedureService.createRadiologyProcedure(
        { ...createData, confirm_similar: true },
        'user-id',
        '127.0.0.1'
      );

      expect(result).toEqual(mockCreatedRadiologyTest);
      expect(radiologyProcedureRepository.create).toHaveBeenCalledWith({
        tenant_id: createData.tenant_id,
        name: createData.name,
        code: createData.code,
        modality: createData.modality
      });
    });

    it('should handle repository errors', async () => {
      radiologyProcedureRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyProcedureService.createRadiologyProcedure(createData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.unique_field', 409);
      radiologyProcedureRepository.create.mockRejectedValue(httpError);

      await expect(
        radiologyProcedureService.createRadiologyProcedure(createData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('updateRadiologyProcedure', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      name: 'Zzyx Updated Imaging Beta',
      modality: 'CT'
    };

    const mockBeforeUpdate = {
      id: radiologyTestId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      name: 'Zzyx Custom Imaging Alpha',
      code: 'ZZYX-ALPHA-001',
      modality: 'XRAY'
    };

    const mockUpdatedRadiologyTest = {
      id: radiologyTestId,
      tenant_id: mockBeforeUpdate.tenant_id,
      ...updateData,
      code: 'ZZYX-ALPHA-001'
    };

    beforeEach(() => {
      radiologyProcedureRepository.findMany.mockResolvedValue([]);
    });

    it('should update radiology test', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockBeforeUpdate);
      radiologyProcedureRepository.update.mockResolvedValue(mockUpdatedRadiologyTest);
      createAuditLog.mockResolvedValue({});

      const result = await radiologyProcedureService.updateRadiologyProcedure(radiologyTestId, updateData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockUpdatedRadiologyTest);
      expect(radiologyProcedureRepository.update).toHaveBeenCalledWith(radiologyTestId, updateData);
      expect(radiologyProcedureRepository.findMany).toHaveBeenCalled();
    });

    it('should throw HttpError if radiology test not found', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyProcedureService.updateRadiologyProcedure(radiologyTestId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyProcedureService.updateRadiologyProcedure(radiologyTestId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        message: 'errors.radiology_test.not_found',
        statusCode: 404
      });
    });

    it('should reject similar names without confirm_similar', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockBeforeUpdate);
      radiologyProcedureRepository.findMany.mockResolvedValue([
        {
          id: 'existing-2',
          name: 'Zzyx Updated Imaging Bet',
          code: 'OTHER',
          modality: 'CT'
        }
      ]);

      await expect(
        radiologyProcedureService.updateRadiologyProcedure(radiologyTestId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        message: 'errors.radiology_test.similar_exists',
        statusCode: 409
      });
      expect(radiologyProcedureRepository.update).not.toHaveBeenCalled();
    });

    it('should update when confirm_similar is true for near matches', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockBeforeUpdate);
      radiologyProcedureRepository.findMany.mockResolvedValue([
        {
          id: 'existing-2',
          name: 'Zzyx Updated Imaging Bet',
          code: 'OTHER',
          modality: 'CT'
        }
      ]);
      radiologyProcedureRepository.update.mockResolvedValue(mockUpdatedRadiologyTest);
      createAuditLog.mockResolvedValue({});

      const result = await radiologyProcedureService.updateRadiologyProcedure(
        radiologyTestId,
        { ...updateData, confirm_similar: true },
        'user-id',
        '127.0.0.1'
      );

      expect(result).toEqual(mockUpdatedRadiologyTest);
      expect(radiologyProcedureRepository.update).toHaveBeenCalledWith(
        radiologyTestId,
        updateData
      );
    });

    it('should create audit log on success', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockBeforeUpdate);
      radiologyProcedureRepository.update.mockResolvedValue(mockUpdatedRadiologyTest);
      createAuditLog.mockResolvedValue({});

      await radiologyProcedureService.updateRadiologyProcedure(radiologyTestId, updateData, 'user-id', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'UPDATE',
        entity: 'radiology_procedure',
        entity_id: mockUpdatedRadiologyTest.id,
        diff: { before: mockBeforeUpdate, after: mockUpdatedRadiologyTest },
        ip_address: '127.0.0.1'
      });
    });

    it('should not fail if audit log fails', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockBeforeUpdate);
      radiologyProcedureRepository.update.mockResolvedValue(mockUpdatedRadiologyTest);
      createAuditLog.mockRejectedValue(new Error('Audit Error'));

      const result = await radiologyProcedureService.updateRadiologyProcedure(radiologyTestId, updateData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockUpdatedRadiologyTest);
    });

    it('should handle repository errors', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockBeforeUpdate);
      radiologyProcedureRepository.update.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyProcedureService.updateRadiologyProcedure(radiologyTestId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockBeforeUpdate);
      const httpError = new HttpError('errors.database.unique_field', 409);
      radiologyProcedureRepository.update.mockRejectedValue(httpError);

      await expect(
        radiologyProcedureService.updateRadiologyProcedure(radiologyTestId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('deleteRadiologyProcedure', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyTest = {
      id: radiologyTestId,
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY'
    };

    it('should delete radiology test', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockRadiologyTest);
      radiologyProcedureRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      await radiologyProcedureService.deleteRadiologyProcedure(radiologyTestId, 'user-id', '127.0.0.1');

      expect(radiologyProcedureRepository.softDelete).toHaveBeenCalledWith(radiologyTestId);
    });

    it('should throw HttpError if radiology test not found', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyProcedureService.deleteRadiologyProcedure(radiologyTestId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyProcedureService.deleteRadiologyProcedure(radiologyTestId, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        message: 'errors.radiology_test.not_found',
        statusCode: 404
      });
    });

    it('should create audit log on success', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockRadiologyTest);
      radiologyProcedureRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      await radiologyProcedureService.deleteRadiologyProcedure(radiologyTestId, 'user-id', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'DELETE',
        entity: 'radiology_procedure',
        entity_id: radiologyTestId,
        diff: { before: mockRadiologyTest },
        ip_address: '127.0.0.1'
      });
    });

    it('should not fail if audit log fails', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockRadiologyTest);
      radiologyProcedureRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockRejectedValue(new Error('Audit Error'));

      await radiologyProcedureService.deleteRadiologyProcedure(radiologyTestId, 'user-id', '127.0.0.1');

      expect(radiologyProcedureRepository.softDelete).toHaveBeenCalledWith(radiologyTestId);
    });

    it('should handle repository errors', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockRadiologyTest);
      radiologyProcedureRepository.softDelete.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyProcedureService.deleteRadiologyProcedure(radiologyTestId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      radiologyProcedureRepository.findById.mockResolvedValue(mockRadiologyTest);
      const httpError = new HttpError('errors.database.unexpected', 500);
      radiologyProcedureRepository.softDelete.mockRejectedValue(httpError);

      await expect(
        radiologyProcedureService.deleteRadiologyProcedure(radiologyTestId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });
});
