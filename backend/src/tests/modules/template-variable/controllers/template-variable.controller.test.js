/**
 * Template Variable controller tests
 */

const templateVariableController = require('@modules/template-variable/controllers/template-variable.controller');
const templateVariableService = require('@modules/template-variable/services/template-variable.service');

jest.mock('@modules/template-variable/services/template-variable.service');

describe('Template Variable Controller', () => {
  const mockTemplateVariable = {
    id: '123e4567-e89b-12d3-a456-426614174000',
    template_id: '123e4567-e89b-12d3-a456-426614174001',
    key: 'test_key'
  };

  let req, res;

  beforeEach(() => {
    req = {
      params: {},
      query: {},
      body: {},
      user: { id: 'user-123', tenant_id: 'tenant-123' }
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
    jest.clearAllMocks();
  });

  describe('listTemplateVariables', () => {
    it('should list with pagination', async () => {
      req.query = { page: '1', limit: '20' };
      templateVariableService.listTemplateVariables.mockResolvedValue({
        templateVariables: [mockTemplateVariable],
        total: 1
      });
      await templateVariableController.listTemplateVariables(req, res);
      expect(res.json).toHaveBeenCalled();
    });
  });

  describe('getTemplateVariable', () => {
    it('should get by ID', async () => {
      req.params = { id: mockTemplateVariable.id };
      templateVariableService.getTemplateVariableById.mockResolvedValue(mockTemplateVariable);
      await templateVariableController.getTemplateVariable(req, res);
      expect(res.json).toHaveBeenCalled();
    });
  });

  describe('createTemplateVariable', () => {
    it('should create', async () => {
      req.body = { template_id: mockTemplateVariable.template_id, key: 'key' };
      templateVariableService.createTemplateVariable.mockResolvedValue(mockTemplateVariable);
      await templateVariableController.createTemplateVariable(req, res);
      expect(res.json).toHaveBeenCalled();
    });
  });

  describe('updateTemplateVariable', () => {
    it('should update', async () => {
      req.params = { id: mockTemplateVariable.id };
      req.body = { key: 'new_key' };
      templateVariableService.updateTemplateVariable.mockResolvedValue(mockTemplateVariable);
      await templateVariableController.updateTemplateVariable(req, res);
      expect(res.json).toHaveBeenCalled();
    });
  });

  describe('deleteTemplateVariable', () => {
    it('should delete', async () => {
      req.params = { id: mockTemplateVariable.id };
      templateVariableService.deleteTemplateVariable.mockResolvedValue();
      await templateVariableController.deleteTemplateVariable(req, res);
      expect(res.status).toHaveBeenCalledWith(204);
    });
  });
});
