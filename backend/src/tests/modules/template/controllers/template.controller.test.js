/**
 * Template controller tests
 *
 * @module tests/modules/template/controllers
 * @description Tests for template request handlers
 */

const templateController = require('@modules/template/controllers/template.controller');
const templateService = require('@modules/template/services/template.service');

// Mock dependencies
jest.mock('@modules/template/services/template.service');

describe('Template Controller', () => {
  const mockTemplate = {
    id: '123e4567-e89b-12d3-a456-426614174000',
    tenant_id: '123e4567-e89b-12d3-a456-426614174001',
    name: 'Test Template',
    channel: 'EMAIL',
    body: 'Template body'
  };

  let req, res, next;

  beforeEach(() => {
    req = {
      params: {},
      query: {},
      body: {},
      user: { id: 'user-123' }
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
    next = jest.fn();
    jest.clearAllMocks();
  });

  describe('listTemplates', () => {
    it('should list templates with pagination', async () => {
      req.query = { page: '1', limit: '20' };
      templateService.listTemplates.mockResolvedValue({
        templates: [mockTemplate],
        total: 1
      });

      await templateController.listTemplates(req, res);

      expect(templateService.listTemplates).toHaveBeenCalled();
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          data: [mockTemplate],
          pagination: expect.objectContaining({
            page: 1,
            limit: 20,
            total: 1
          })
        })
      );
    });
  });

  describe('getTemplate', () => {
    it('should get template by ID', async () => {
      req.params = { id: mockTemplate.id };
      templateService.getTemplateById.mockResolvedValue(mockTemplate);

      await templateController.getTemplate(req, res);

      expect(templateService.getTemplateById).toHaveBeenCalledWith(mockTemplate.id);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          data: mockTemplate
        })
      );
    });
  });

  describe('createTemplate', () => {
    it('should create new template', async () => {
      req.body = {
        tenant_id: mockTemplate.tenant_id,
        name: mockTemplate.name,
        channel: mockTemplate.channel,
        body: mockTemplate.body
      };
      templateService.createTemplate.mockResolvedValue(mockTemplate);

      await templateController.createTemplate(req, res);

      expect(templateService.createTemplate).toHaveBeenCalledWith(
        req.body,
        req.user.id
      );
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 201,
          data: mockTemplate
        })
      );
    });
  });

  describe('updateTemplate', () => {
    it('should update template', async () => {
      req.params = { id: mockTemplate.id };
      req.body = { name: 'Updated Template' };
      const updatedTemplate = { ...mockTemplate, ...req.body };
      templateService.updateTemplate.mockResolvedValue(updatedTemplate);

      await templateController.updateTemplate(req, res);

      expect(templateService.updateTemplate).toHaveBeenCalledWith(
        mockTemplate.id,
        req.body,
        req.user.id
      );
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          data: updatedTemplate
        })
      );
    });
  });

  describe('deleteTemplate', () => {
    it('should delete template', async () => {
      req.params = { id: mockTemplate.id };
      templateService.deleteTemplate.mockResolvedValue();

      await templateController.deleteTemplate(req, res);

      expect(templateService.deleteTemplate).toHaveBeenCalledWith(
        mockTemplate.id,
        req.user.id
      );
      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
