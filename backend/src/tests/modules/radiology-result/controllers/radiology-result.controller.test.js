/**
 * Radiology Result controller tests
 *
 * @module tests/modules/radiology-result/controllers
 * @description Tests for radiology result controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const radiologyResultController = require('@controllers/radiology-result/radiology-result.controller');
const radiologyResultService = require('@services/radiology-result/radiology-result.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/radiology-result/radiology-result.service');
jest.mock('@lib/response');

describe('Radiology Result Controller', () => {
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

  describe('listRadiologyResults', () => {
    const mockResult = {
      radiology_results: [
        { 
          id: '550e8400-e29b-41d4-a716-446655440000', 
          radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
          status: 'DRAFT' 
        },
        { 
          id: '550e8400-e29b-41d4-a716-446655440002', 
          radiology_order_id: '550e8400-e29b-41d4-a716-446655440003',
          status: 'FINAL' 
        }
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

    it('should list radiology results with default pagination', async () => {
      radiologyResultService.listRadiologyResults.mockResolvedValue(mockResult);

      await radiologyResultController.listRadiologyResults(req, res);

      expect(radiologyResultService.listRadiologyResults).toHaveBeenCalledWith(
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
        'messages.radiology_result.list.success',
        mockResult.radiology_results,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        radiology_order_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'DRAFT',
        search: 'findings',
        page: '2',
        limit: '10',
        sort_by: 'reported_at',
        order: 'desc'
      };
      radiologyResultService.listRadiologyResults.mockResolvedValue(mockResult);

      await radiologyResultController.listRadiologyResults(req, res);

      expect(radiologyResultService.listRadiologyResults).toHaveBeenCalledWith(
        {
          radiology_order_id: '550e8400-e29b-41d4-a716-446655440000',
          status: 'DRAFT',
          search: 'findings'
        },
        2,
        10,
        'reported_at',
        'desc',
        'requester-id',
        '127.0.0.1'
      );
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
      req.params = { id: radiologyResultId };
      radiologyResultService.getRadiologyResultById.mockResolvedValue(mockRadiologyResult);

      await radiologyResultController.getRadiologyResultById(req, res);

      expect(radiologyResultService.getRadiologyResultById).toHaveBeenCalledWith(
        radiologyResultId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.radiology_result.get.success',
        mockRadiologyResult
      );
    });
  });

  describe('createRadiologyResult', () => {
    const createData = {
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440000',
      status: 'DRAFT',
      report_text: 'Preliminary findings.',
      reported_at: '2026-01-19T14:30:00.000Z'
    };

    const mockCreatedRadiologyResult = {
      id: '550e8400-e29b-41d4-a716-446655440002',
      ...createData,
      created_at: new Date(),
      updated_at: new Date()
    };

    it('should create radiology result', async () => {
      req.body = createData;
      radiologyResultService.createRadiologyResult.mockResolvedValue(mockCreatedRadiologyResult);

      await radiologyResultController.createRadiologyResult(req, res);

      expect(radiologyResultService.createRadiologyResult).toHaveBeenCalledWith(
        createData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.radiology_result.create.success',
        mockCreatedRadiologyResult
      );
    });
  });

  describe('updateRadiologyResult', () => {
    const radiologyResultId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      status: 'FINAL'
    };

    const mockUpdatedRadiologyResult = {
      id: radiologyResultId,
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'FINAL',
      report_text: 'Final report.',
      reported_at: new Date('2026-01-19T16:00:00.000Z')
    };

    it('should update radiology result', async () => {
      req.params = { id: radiologyResultId };
      req.body = updateData;
      radiologyResultService.updateRadiologyResult.mockResolvedValue(mockUpdatedRadiologyResult);

      await radiologyResultController.updateRadiologyResult(req, res);

      expect(radiologyResultService.updateRadiologyResult).toHaveBeenCalledWith(
        radiologyResultId,
        updateData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.radiology_result.update.success',
        mockUpdatedRadiologyResult
      );
    });
  });

  describe('deleteRadiologyResult', () => {
    const radiologyResultId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete radiology result', async () => {
      req.params = { id: radiologyResultId };
      radiologyResultService.deleteRadiologyResult.mockResolvedValue();

      await radiologyResultController.deleteRadiologyResult(req, res);

      expect(radiologyResultService.deleteRadiologyResult).toHaveBeenCalledWith(
        radiologyResultId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
