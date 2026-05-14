/**
 * Template repository tests
 *
 * @module tests/modules/template/repositories
 * @description Tests for template data access layer
 */

const templateRepository = require('@modules/template/repositories/template.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  template: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Template Repository', () => {
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

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find template by ID', async () => {
      prisma.template.findFirst.mockResolvedValue(mockTemplate);

      const result = await templateRepository.findById(mockTemplate.id);

      expect(result).toEqual(mockTemplate);
      expect(prisma.template.findFirst).toHaveBeenCalledWith({
        where: { id: mockTemplate.id, deleted_at: null },
        include: {}
      });
    });

    it('should return null if template not found', async () => {
      prisma.template.findFirst.mockResolvedValue(null);

      const result = await templateRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.template.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(templateRepository.findById(mockTemplate.id))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find multiple templates', async () => {
      const mockTemplates = [mockTemplate];
      prisma.template.findMany.mockResolvedValue(mockTemplates);

      const result = await templateRepository.findMany({}, 0, 20);

      expect(result).toEqual(mockTemplates);
      expect(prisma.template.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      const filters = { tenant_id: mockTemplate.tenant_id };
      prisma.template.findMany.mockResolvedValue([mockTemplate]);

      await templateRepository.findMany(filters);

      expect(prisma.template.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });
  });

  describe('count', () => {
    it('should count templates', async () => {
      prisma.template.count.mockResolvedValue(5);

      const result = await templateRepository.count({});

      expect(result).toBe(5);
      expect(prisma.template.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });
  });

  describe('create', () => {
    it('should create new template', async () => {
      const createData = {
        tenant_id: mockTemplate.tenant_id,
        name: mockTemplate.name,
        channel: mockTemplate.channel,
        body: mockTemplate.body
      };
      prisma.template.create.mockResolvedValue(mockTemplate);

      const result = await templateRepository.create(createData);

      expect(result).toEqual(mockTemplate);
      expect(prisma.template.create).toHaveBeenCalledWith({ data: createData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.template.create.mockRejectedValue(error);

      await expect(templateRepository.create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.template.create.mockRejectedValue(error);

      await expect(templateRepository.create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update template', async () => {
      const updateData = { name: 'Updated Template' };
      const updatedTemplate = { ...mockTemplate, ...updateData };
      prisma.template.update.mockResolvedValue(updatedTemplate);

      const result = await templateRepository.update(mockTemplate.id, updateData);

      expect(result).toEqual(updatedTemplate);
      expect(prisma.template.update).toHaveBeenCalledWith({
        where: { id: mockTemplate.id },
        data: updateData
      });
    });

    it('should throw HttpError if template not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.template.update.mockRejectedValue(error);

      await expect(templateRepository.update('non-existent-id', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete template', async () => {
      const deletedTemplate = { ...mockTemplate, deleted_at: new Date() };
      prisma.template.update.mockResolvedValue(deletedTemplate);

      const result = await templateRepository.softDelete(mockTemplate.id);

      expect(result.deleted_at).toBeTruthy();
      expect(prisma.template.update).toHaveBeenCalledWith({
        where: { id: mockTemplate.id },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if template not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.template.update.mockRejectedValue(error);

      await expect(templateRepository.softDelete('non-existent-id'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
