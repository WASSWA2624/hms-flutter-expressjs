/**
 * Radiology test controller tests
 *
 * @module tests/modules/radiology-test/controllers
 * @description Tests for radiology test controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

// Mock dependencies BEFORE requiring modules
jest.mock('@services/radiology-test/radiology-test.service', () => ({
  listRadiologyTests: jest.fn(),
  getRadiologyTestById: jest.fn(),
  createRadiologyTest: jest.fn(),
  updateRadiologyTest: jest.fn(),
  deleteRadiologyTest: jest.fn()
}));

jest.mock('@lib/response', () => ({
  sendSuccess: jest.fn(),
  sendPaginated: jest.fn(),
  sendNoContent: jest.fn()
}));

const radiologyTestController = require('@controllers/radiology-test/radiology-test.controller');
const radiologyTestService = require('@services/radiology-test/radiology-test.service');
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

  describe('listRadiologyTests', () => {
    const mockResult = {
      radiologyTests: [
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
      radiologyTestService.listRadiologyTests.mockResolvedValue(mockResult);

      await radiologyTestController.listRadiologyTests(req, res);

      expect(radiologyTestService.listRadiologyTests).toHaveBeenCalledWith(
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
        'messages.radiology_test.list.success',
        mockResult.radiologyTests,
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
      radiologyTestService.listRadiologyTests.mockResolvedValue(mockResult);

      await radiologyTestController.listRadiologyTests(req, res);

      expect(radiologyTestService.listRadiologyTests).toHaveBeenCalledWith(
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
      radiologyTestService.listRadiologyTests.mockResolvedValue(mockResult);

      await radiologyTestController.listRadiologyTests(req, res);

      expect(radiologyTestService.listRadiologyTests).toHaveBeenCalledWith(
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

  describe('getRadiologyTestById', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyTest = {
      id: radiologyTestId,
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY'
    };

    it('should get radiology test by ID', async () => {
      req.params = { id: radiologyTestId };
      radiologyTestService.getRadiologyTestById.mockResolvedValue(mockRadiologyTest);

      await radiologyTestController.getRadiologyTestById(req, res);

      expect(radiologyTestService.getRadiologyTestById).toHaveBeenCalledWith(
        radiologyTestId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.radiology_test.get.success',
        mockRadiologyTest
      );
    });

    it('should handle missing user in request', async () => {
      req.params = { id: radiologyTestId };
      req.user = undefined;
      radiologyTestService.getRadiologyTestById.mockResolvedValue(mockRadiologyTest);

      await radiologyTestController.getRadiologyTestById(req, res);

      expect(radiologyTestService.getRadiologyTestById).toHaveBeenCalledWith(
        radiologyTestId,
        undefined,
        '127.0.0.1'
      );
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
      req.body = createData;
      radiologyTestService.createRadiologyTest.mockResolvedValue(mockCreatedRadiologyTest);

      await radiologyTestController.createRadiologyTest(req, res);

      expect(radiologyTestService.createRadiologyTest).toHaveBeenCalledWith(
        createData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.radiology_test.create.success',
        mockCreatedRadiologyTest
      );
    });

    it('should handle missing user in request', async () => {
      req.body = createData;
      req.user = undefined;
      radiologyTestService.createRadiologyTest.mockResolvedValue(mockCreatedRadiologyTest);

      await radiologyTestController.createRadiologyTest(req, res);

      expect(radiologyTestService.createRadiologyTest).toHaveBeenCalledWith(
        createData,
        undefined,
        '127.0.0.1'
      );
    });
  });

  describe('updateRadiologyTest', () => {
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
      radiologyTestService.updateRadiologyTest.mockResolvedValue(mockUpdatedRadiologyTest);

      await radiologyTestController.updateRadiologyTest(req, res);

      expect(radiologyTestService.updateRadiologyTest).toHaveBeenCalledWith(
        radiologyTestId,
        updateData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.radiology_test.update.success',
        mockUpdatedRadiologyTest
      );
    });

    it('should handle missing user in request', async () => {
      req.params = { id: radiologyTestId };
      req.body = updateData;
      req.user = undefined;
      radiologyTestService.updateRadiologyTest.mockResolvedValue(mockUpdatedRadiologyTest);

      await radiologyTestController.updateRadiologyTest(req, res);

      expect(radiologyTestService.updateRadiologyTest).toHaveBeenCalledWith(
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
      radiologyTestService.updateRadiologyTest.mockRejectedValue(error);

      await expect(radiologyTestController.updateRadiologyTest(req, res)).rejects.toThrow(error);
    });
  });

  describe('deleteRadiologyTest', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete radiology test', async () => {
      req.params = { id: radiologyTestId };
      radiologyTestService.deleteRadiologyTest.mockResolvedValue(undefined);

      await radiologyTestController.deleteRadiologyTest(req, res);

      expect(radiologyTestService.deleteRadiologyTest).toHaveBeenCalledWith(
        radiologyTestId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });

    it('should handle missing user in request', async () => {
      req.params = { id: radiologyTestId };
      req.user = undefined;
      radiologyTestService.deleteRadiologyTest.mockResolvedValue(undefined);

      await radiologyTestController.deleteRadiologyTest(req, res);

      expect(radiologyTestService.deleteRadiologyTest).toHaveBeenCalledWith(
        radiologyTestId,
        undefined,
        '127.0.0.1'
      );
    });
  });
});
