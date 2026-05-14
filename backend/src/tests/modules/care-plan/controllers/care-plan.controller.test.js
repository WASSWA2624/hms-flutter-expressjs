/**
 * Care Plan controller tests
 *
 * @module tests/modules/care-plan/controllers
 * @description Tests for care plan controller
 * Per testing.mdc: Controller tests with mocked service
 */

const carePlanController = require('@controllers/care-plan/care-plan.controller');
const carePlanService = require('@services/care-plan/care-plan.service');

jest.mock('@services/care-plan/care-plan.service');

describe('Care Plan Controller', () => {
  let req, res;

  beforeEach(() => {
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-id-123' },
      ip: '127.0.0.1'
    };
    res = { status: jest.fn().mockReturnThis(), json: jest.fn(), send: jest.fn() };
  });

  afterEach(() => jest.clearAllMocks());

  it('should list care plans', async () => {
    const mockResult = { carePlans: [{ id: '1' }], pagination: {} };
    carePlanService.listCarePlans.mockResolvedValue(mockResult);

    await carePlanController.listCarePlans(req, res);

    expect(carePlanService.listCarePlans).toHaveBeenCalled();
  });

  it('should create care plan', async () => {
    req.body = { plan: 'New plan' };
    const created = { id: '1', ...req.body };
    carePlanService.createCarePlan.mockResolvedValue(created);

    await carePlanController.createCarePlan(req, res);

    expect(carePlanService.createCarePlan).toHaveBeenCalled();
  });
});
