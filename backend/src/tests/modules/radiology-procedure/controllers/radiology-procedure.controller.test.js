/**
 * Radiology test controller tests
 *
 * @module tests/modules/radiology-procedure/controllers
 * @description Tests for radiology test controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

// Mock dependencies BEFORE requiring modules
jest.mock('@services/radiology-procedure/radiology-procedure.service', () => ({
  listRadiologyProcedures: jest.fn(),
  getRadiologyProcedureById: jest.fn(),
  createRadiologyProcedure: jest.fn(),
  updateRadiologyProcedure: jest.fn(),
  deleteRadiologyProcedure: jest.fn()
}));

jest.mock('@lib/response', () => ({
  sendSuccess: jest.fn(),
  sendPaginated: jest.fn(),
  sendNoContent: jest.fn()
}));

const radiologyProcedureController = require('@controllers/radiology-procedure/radiology-procedure.controller');
const radiologyProcedureService = require('@services/radiology-procedure/radiology-procedure.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

describe('Radiology Test Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'requester-id' },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listRadiologyProcedures', () => {
    const mockResult = {
      radiologyProcedures: [
        { id: '1', name: 'Chest X-Ray', code: 'CXR-001', modality: 'XRAY' },
        { id: '2', name: 'Brain MRI', code: 'MRI-001', modality: 'MRI' }
      ],
      pagination: {
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      }
    };

    it('should list radiology tests with default pagination', async () => {
      radiologyProcedureService.listRadiologyProcedures.mockResolvedValue(mockResult);

      await radiologyProcedureController.listRadiologyProcedures(req, res);

      expect(radiologyProcedureService.listRadiologyProcedures).toHaveBeenCalledWith(
        expect.any(Object),
        DEFAULT_PAGE,
        DEFAULT_PAGE_LIMIT,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.radiology_procedure.list.success',
        mockResult.radiologyProcedures,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'X-Ray',
        code: 'CXR',
        modality: 'XRAY',
        search: 'chest',
        page: '2',
        limit: '10',
        sort_by: 'name',
        order: 'desc'
      };
      radiologyProcedureService.listRadiologyProcedures.mockResolvedValue(mockResult);

      await radiologyProcedureController.listRadiologyProcedures(req, res);

      expect(radiologyProcedureService.listRadiologyProcedures).toHaveBeenCalledWith(
        {
          tenant_id: '550e8400-e29b-41d4-a716-446655440000',
          name: 'X-Ray',
          code: 'CXR',
          modality: 'XRAY',
          search: 'chest'
        },
        2,
        10,
        'name',
        'desc',
        'requester-id',
        '127.0.0.1'
      );
    });

    it('should handle missing user in request', async () => {
      req.user = undefined;
      radiologyProcedureService.listRadiologyProcedures.mockResolvedValue(mockResult);

      await radiologyProcedureController.listRadiologyProcedures(req, res);

      expect(radiologyProcedureService.listRadiologyProcedures).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        undefined,
        'asc',
        undefined,
        '127.0.0.1'
      );
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
      req.params = { id: radiologyTestId };
      radiologyProcedureService.getRadiologyProcedureById.mockResolvedValue(mockRadiologyTest);

      await radiologyProcedureController.getRadiologyProcedureById(req, res);

      expect(radiologyProcedureService.getRadiologyProcedureById).toHaveBeenCalledWith(
        radiologyTestId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.radiology_procedure.get.success',
        mockRadiologyTest
      );
    });

    it('should handle missing user in request', async () => {
      req.params = { id: radiologyTestId };
      req.user = undefined;
      radiologyProcedureService.getRadiologyProcedureById.mockResolvedValue(mockRadiologyTest);

      await radiologyProcedureController.getRadiologyProcedureById(req, res);

      expect(radiologyProcedureService.getRadiologyProcedureById).toHaveBeenCalledWith(
        radiologyTestId,
        undefined,
        '127.0.0.1'
      );
    });
  });

  describe('createRadiologyProcedure', () => {
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
      req.body = createData;
      radiologyProcedureService.createRadiologyProcedure.mockResolvedValue(mockCreatedRadiologyTest);

      await radiologyProcedureController.createRadiologyProcedure(req, res);

      expect(radiologyProcedureService.createRadiologyProcedure).toHaveBeenCalledWith(
        createData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.radiology_procedure.create.success',
        mockCreatedRadiologyTest
      );
    });

    it('should handle missing user in request', async () => {
      req.body = createData;
      req.user = undefined;
      radiologyProcedureService.createRadiologyProcedure.mockResolvedValue(mockCreatedRadiologyTest);

      await radiologyProcedureController.createRadiologyProcedure(req, res);

      expect(radiologyProcedureService.createRadiologyProcedure).toHaveBeenCalledWith(
        createData,
        undefined,
        '127.0.0.1'
      );
    });
  });

  describe('updateRadiologyProcedure', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      name: 'Updated X-Ray',
      modality: 'CT'
    };

    const mockUpdatedRadiologyTest = {
      id: radiologyTestId,
      ...updateData,
      code: 'CXR-001'
    };

    it('should update radiology test', async () => {
      req.params = { id: radiologyTestId };
      req.body = updateData;
      radiologyProcedureService.updateRadiologyProcedure.mockResolvedValue(mockUpdatedRadiologyTest);

      await radiologyProcedureController.updateRadiologyProcedure(req, res);

      expect(radiologyProcedureService.updateRadiologyProcedure).toHaveBeenCalledWith(
        radiologyTestId,
        updateData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.radiology_procedure.update.success',
        mockUpdatedRadiologyTest
      );
    });

    it('should handle missing user in request', async () => {
      req.params = { id: radiologyTestId };
      req.body = updateData;
      req.user = undefined;
      radiologyProcedureService.updateRadiologyProcedure.mockResolvedValue(mockUpdatedRadiologyTest);

      await radiologyProcedureController.updateRadiologyProcedure(req, res);

      expect(radiologyProcedureService.updateRadiologyProcedure).toHaveBeenCalledWith(
        radiologyTestId,
        updateData,
        undefined,
        '127.0.0.1'
      );
    });

    it('should handle service errors', async () => {
      req.params = { id: radiologyTestId };
      req.body = updateData;
      const error = new Error('Service error');
      radiologyProcedureService.updateRadiologyProcedure.mockRejectedValue(error);

      await expect(radiologyProcedureController.updateRadiologyProcedure(req, res)).rejects.toThrow(error);
    });
  });

  describe('deleteRadiologyProcedure', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete radiology test', async () => {
      req.params = { id: radiologyTestId };
      const deleted = { id: radiologyTestId, deleted_at: new Date().toISOString() };
      radiologyProcedureService.deleteRadiologyProcedure.mockResolvedValue(deleted);

      await radiologyProcedureController.deleteRadiologyProcedure(req, res);

      expect(radiologyProcedureService.deleteRadiologyProcedure).toHaveBeenCalledWith(
        radiologyTestId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.radiology_test.update.success',
        deleted
      );
    });

    it('should handle missing user in request', async () => {
      req.params = { id: radiologyTestId };
      req.user = undefined;
      radiologyProcedureService.deleteRadiologyProcedure.mockResolvedValue(undefined);

      await radiologyProcedureController.deleteRadiologyProcedure(req, res);

      expect(radiologyProcedureService.deleteRadiologyProcedure).toHaveBeenCalledWith(
        radiologyTestId,
        undefined,
        '127.0.0.1'
      );
    });
  });
});
