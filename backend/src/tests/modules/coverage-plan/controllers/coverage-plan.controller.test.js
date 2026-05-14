/**
 * Coverage Plan controller tests
 *
 * @module tests/modules/coverage-plan/controllers
 * @description Tests for coverage plan controller layer
 * Per testing.mdc: Mock services, test response handling
 */

const coveragePlanController = require('@controllers/coverage-plan/coverage-plan.controller');
const coveragePlanService = require('@services/coverage-plan/coverage-plan.service');

jest.mock('@services/coverage-plan/coverage-plan.service');

describe('Coverage Plan Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: '550e8400-e29b-41d4-a716-446655440000' },
      ip: '127.0.0.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      send: jest.fn()
    };
  });

  describe('listCoveragePlans', () => {
    it('should list coverage plans', async () => {
      const mockResult = {
        coveragePlans: [{ id: '1', name: 'Plan 1' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      coveragePlanService.listCoveragePlans.mockResolvedValue(mockResult);

      await coveragePlanController.listCoveragePlans(req, res);

      expect(coveragePlanService.listCoveragePlans).toHaveBeenCalled();
    });
  });

  describe('getCoveragePlanById', () => {
    it('should get coverage plan by ID', async () => {
      const mockData = { id: '1', name: 'Test Plan' };
      req.params.id = '1';
      coveragePlanService.getCoveragePlanById.mockResolvedValue(mockData);

      await coveragePlanController.getCoveragePlanById(req, res);

      expect(coveragePlanService.getCoveragePlanById).toHaveBeenCalled();
    });
  });

  describe('createCoveragePlan', () => {
    it('should create coverage plan', async () => {
      const mockData = { id: '1', name: 'New Plan' };
      req.body = { name: 'New Plan', coverage_percentage: 80 };
      coveragePlanService.createCoveragePlan.mockResolvedValue(mockData);

      await coveragePlanController.createCoveragePlan(req, res);

      expect(coveragePlanService.createCoveragePlan).toHaveBeenCalled();
    });
  });

  describe('updateCoveragePlan', () => {
    it('should update coverage plan', async () => {
      const mockData = { id: '1', name: 'Updated Plan' };
      req.params.id = '1';
      req.body = { name: 'Updated Plan' };
      coveragePlanService.updateCoveragePlan.mockResolvedValue(mockData);

      await coveragePlanController.updateCoveragePlan(req, res);

      expect(coveragePlanService.updateCoveragePlan).toHaveBeenCalled();
    });
  });

  describe('deleteCoveragePlan', () => {
    it('should delete coverage plan', async () => {
      req.params.id = '1';
      coveragePlanService.deleteCoveragePlan.mockResolvedValue(undefined);

      await coveragePlanController.deleteCoveragePlan(req, res);

      expect(coveragePlanService.deleteCoveragePlan).toHaveBeenCalled();
    });
  });
});
