/**
 * Template Variable repository tests
 */

const templateVariableRepository = require('@modules/template-variable/repositories/template-variable.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  template_variable: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Template Variable Repository', () => {
  const mockTemplateVariable = {
    id: '123e4567-e89b-12d3-a456-426614174000',
    template_id: '123e4567-e89b-12d3-a456-426614174001',
    key: 'test_key',
    description: 'Test description',
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find template variable by ID', async () => {
      prisma.template_variable.findFirst.mockResolvedValue(mockTemplateVariable);
      const result = await templateVariableRepository.findById(mockTemplateVariable.id);
      expect(result).toEqual(mockTemplateVariable);
    });

    it('should return null if not found', async () => {
      prisma.template_variable.findFirst.mockResolvedValue(null);
      const result = await templateVariableRepository.findById('non-existent');
      expect(result).toBeNull();
    });
  });

  describe('findMany', () => {
    it('should find multiple template variables', async () => {
      prisma.template_variable.findMany.mockResolvedValue([mockTemplateVariable]);
      const result = await templateVariableRepository.findMany({}, 0, 20);
      expect(result).toEqual([mockTemplateVariable]);
    });
  });

  describe('count', () => {
    it('should count template variables', async () => {
      prisma.template_variable.count.mockResolvedValue(5);
      const result = await templateVariableRepository.count({});
      expect(result).toBe(5);
    });
  });

  describe('create', () => {
    it('should create template variable', async () => {
      prisma.template_variable.create.mockResolvedValue(mockTemplateVariable);
      const result = await templateVariableRepository.create({});
      expect(result).toEqual(mockTemplateVariable);
    });

    it('should throw on unique constraint', async () => {
      const error = new Error();
      error.code = 'P2002';
      error.meta = { target: ['key'] };
      prisma.template_variable.create.mockRejectedValue(error);
      await expect(templateVariableRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update template variable', async () => {
      prisma.template_variable.update.mockResolvedValue(mockTemplateVariable);
      const result = await templateVariableRepository.update(mockTemplateVariable.id, {});
      expect(result).toEqual(mockTemplateVariable);
    });

    it('should throw if not found', async () => {
      const error = new Error();
      error.code = 'P2025';
      prisma.template_variable.update.mockRejectedValue(error);
      await expect(templateVariableRepository.update('id', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete template variable', async () => {
      const deleted = { ...mockTemplateVariable, deleted_at: new Date() };
      prisma.template_variable.update.mockResolvedValue(deleted);
      const result = await templateVariableRepository.softDelete(mockTemplateVariable.id);
      expect(result.deleted_at).toBeTruthy();
    });
  });
});
