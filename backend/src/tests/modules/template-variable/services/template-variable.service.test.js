/**
 * Template Variable service tests
 */

const templateVariableService = require('@modules/template-variable/services/template-variable.service');
const templateVariableRepository = require('@modules/template-variable/repositories/template-variable.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('@modules/template-variable/repositories/template-variable.repository');
jest.mock('@lib/audit');

describe('Template Variable Service', () => {
  const mockTemplateVariable = {
    id: '123e4567-e89b-12d3-a456-426614174000',
    template_id: '123e4567-e89b-12d3-a456-426614174001',
    key: 'test_key'
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listTemplateVariables', () => {
    it('should list with pagination', async () => {
      templateVariableRepository.findMany.mockResolvedValue([mockTemplateVariable]);
      templateVariableRepository.count.mockResolvedValue(1);
      const result = await templateVariableService.listTemplateVariables({}, 1, 20);
      expect(result.templateVariables).toEqual([mockTemplateVariable]);
      expect(result.total).toBe(1);
    });
  });

  describe('getTemplateVariableById', () => {
    it('should get by ID', async () => {
      templateVariableRepository.findById.mockResolvedValue(mockTemplateVariable);
      const result = await templateVariableService.getTemplateVariableById(mockTemplateVariable.id);
      expect(result).toEqual(mockTemplateVariable);
    });

    it('should throw if not found', async () => {
      templateVariableRepository.findById.mockResolvedValue(null);
      await expect(templateVariableService.getTemplateVariableById('id')).rejects.toThrow(HttpError);
    });
  });

  describe('createTemplateVariable', () => {
    it('should create and audit', async () => {
      templateVariableRepository.create.mockResolvedValue(mockTemplateVariable);
      await templateVariableService.createTemplateVariable({}, 'user', 'tenant');
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateTemplateVariable', () => {
    it('should update and audit', async () => {
      templateVariableRepository.findById.mockResolvedValue(mockTemplateVariable);
      templateVariableRepository.update.mockResolvedValue(mockTemplateVariable);
      await templateVariableService.updateTemplateVariable('id', {}, 'user', 'tenant');
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('deleteTemplateVariable', () => {
    it('should delete and audit', async () => {
      templateVariableRepository.findById.mockResolvedValue(mockTemplateVariable);
      templateVariableRepository.softDelete.mockResolvedValue(mockTemplateVariable);
      await templateVariableService.deleteTemplateVariable('id', 'user', 'tenant');
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
