/**
 * Template service tests
 *
 * @module tests/modules/template/services
 * @description Tests for template business logic layer
 */

const templateService = require('@modules/template/services/template.service');
const templateRepository = require('@modules/template/repositories/template.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@modules/template/repositories/template.repository');
jest.mock('@lib/audit');

describe('Template Service', () => {
  const mockTemplate = {
    id: '123e4567-e89b-12d3-a456-426614174000',
    tenant_id: '123e4567-e89b-12d3-a456-426614174001',
    name: 'Test Template',
    channel: 'EMAIL',
    body: 'Template body',
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  const userId = 'user-123';

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listTemplates', () => {
    it('should list templates with pagination', async () => {
      const mockTemplates = [mockTemplate];
      templateRepository.findMany.mockResolvedValue(mockTemplates);
      templateRepository.count.mockResolvedValue(1);

      const result = await templateService.listTemplates({}, 1, 20);

      expect(result.templates).toEqual(mockTemplates);
      expect(result.total).toBe(1);
      expect(templateRepository.findMany).toHaveBeenCalled();
      expect(templateRepository.count).toHaveBeenCalled();
    });

    it('should apply search filter', async () => {
      templateRepository.findMany.mockResolvedValue([mockTemplate]);
      templateRepository.count.mockResolvedValue(1);

      await templateService.listTemplates({ search: 'test' }, 1, 20);

      expect(templateRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            { name: { contains: 'test' } },
            { body: { contains: 'test' } }
          ])
        }),
        expect.any(Number),
        expect.any(Number)
      );
    });
  });

  describe('getTemplateById', () => {
    it('should get template by ID', async () => {
      templateRepository.findById.mockResolvedValue(mockTemplate);

      const result = await templateService.getTemplateById(mockTemplate.id);

      expect(result).toEqual(mockTemplate);
      expect(templateRepository.findById).toHaveBeenCalledWith(
        mockTemplate.id,
        { variables: true }
      );
    });

    it('should throw HttpError if template not found', async () => {
      templateRepository.findById.mockResolvedValue(null);

      await expect(templateService.getTemplateById('non-existent-id'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createTemplate', () => {
    it('should create template and audit log', async () => {
      const createData = {
        tenant_id: mockTemplate.tenant_id,
        name: mockTemplate.name,
        channel: mockTemplate.channel,
        body: mockTemplate.body
      };
      templateRepository.create.mockResolvedValue(mockTemplate);

      const result = await templateService.createTemplate(createData, userId);

      expect(result).toEqual(mockTemplate);
      expect(templateRepository.create).toHaveBeenCalledWith(createData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'CREATE',
        entity: 'template',
        entity_id: mockTemplate.id,
        tenant_id: mockTemplate.tenant_id,
        user_id: userId,
        changes: { new: mockTemplate }
      });
    });
  });

  describe('updateTemplate', () => {
    it('should update template and create audit log', async () => {
      const updateData = { name: 'Updated Template' };
      const updatedTemplate = { ...mockTemplate, ...updateData };
      templateRepository.findById.mockResolvedValue(mockTemplate);
      templateRepository.update.mockResolvedValue(updatedTemplate);

      const result = await templateService.updateTemplate(
        mockTemplate.id,
        updateData,
        userId
      );

      expect(result).toEqual(updatedTemplate);
      expect(templateRepository.update).toHaveBeenCalledWith(mockTemplate.id, updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'UPDATE',
        entity: 'template',
        entity_id: mockTemplate.id,
        tenant_id: mockTemplate.tenant_id,
        user_id: userId,
        changes: { old: mockTemplate, new: updatedTemplate }
      });
    });

    it('should throw HttpError if template not found', async () => {
      templateRepository.findById.mockResolvedValue(null);

      await expect(templateService.updateTemplate('non-existent-id', {}, userId))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteTemplate', () => {
    it('should soft delete template and create audit log', async () => {
      templateRepository.findById.mockResolvedValue(mockTemplate);
      templateRepository.softDelete.mockResolvedValue(mockTemplate);

      await templateService.deleteTemplate(mockTemplate.id, userId);

      expect(templateRepository.softDelete).toHaveBeenCalledWith(mockTemplate.id);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'DELETE',
        entity: 'template',
        entity_id: mockTemplate.id,
        tenant_id: mockTemplate.tenant_id,
        user_id: userId,
        changes: { old: mockTemplate }
      });
    });

    it('should throw HttpError if template not found', async () => {
      templateRepository.findById.mockResolvedValue(null);

      await expect(templateService.deleteTemplate('non-existent-id', userId))
        .rejects
        .toThrow(HttpError);
    });
  });
});
