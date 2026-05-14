/**
 * Pricing Rule controller tests
 *
 * @module tests/modules/pricing-rule/controllers
 * @description Tests for pricing rule controller layer
 * Per testing.mdc: Mock services, test response handling
 */

const pricingRuleController = require('@controllers/pricing-rule/pricing-rule.controller');
const pricingRuleService = require('@services/pricing-rule/pricing-rule.service');

jest.mock('@services/pricing-rule/pricing-rule.service');

describe('Pricing Rule Controller', () => {
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

  describe('listPricingRules', () => {
    it('should list pricing rules', async () => {
      const mockResult = {
        pricingRules: [{ id: '1', name: 'Rule 1' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      pricingRuleService.listPricingRules.mockResolvedValue(mockResult);

      await pricingRuleController.listPricingRules(req, res);

      expect(pricingRuleService.listPricingRules).toHaveBeenCalled();
      expect(res.json).toHaveBeenCalled();
    });
  });

  describe('getPricingRuleById', () => {
    it('should get pricing rule by ID', async () => {
      const mockData = { id: '1', name: 'Test Rule' };
      req.params.id = '1';
      pricingRuleService.getPricingRuleById.mockResolvedValue(mockData);

      await pricingRuleController.getPricingRuleById(req, res);

      expect(pricingRuleService.getPricingRuleById).toHaveBeenCalledWith('1', req.user.id, req.ip);
    });
  });

  describe('createPricingRule', () => {
    it('should create pricing rule', async () => {
      const mockData = { id: '1', name: 'New Rule' };
      req.body = { name: 'New Rule', amount: 50, currency: 'USD' };
      pricingRuleService.createPricingRule.mockResolvedValue(mockData);

      await pricingRuleController.createPricingRule(req, res);

      expect(pricingRuleService.createPricingRule).toHaveBeenCalledWith(req.body, req.user.id, req.ip);
    });
  });

  describe('updatePricingRule', () => {
    it('should update pricing rule', async () => {
      const mockData = { id: '1', name: 'Updated Rule' };
      req.params.id = '1';
      req.body = { name: 'Updated Rule' };
      pricingRuleService.updatePricingRule.mockResolvedValue(mockData);

      await pricingRuleController.updatePricingRule(req, res);

      expect(pricingRuleService.updatePricingRule).toHaveBeenCalledWith('1', req.body, req.user.id, req.ip);
    });
  });

  describe('deletePricingRule', () => {
    it('should delete pricing rule', async () => {
      req.params.id = '1';
      pricingRuleService.deletePricingRule.mockResolvedValue(undefined);

      await pricingRuleController.deletePricingRule(req, res);

      expect(pricingRuleService.deletePricingRule).toHaveBeenCalledWith('1', req.user.id, req.ip);
    });
  });
});
