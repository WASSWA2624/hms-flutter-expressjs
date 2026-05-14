/**
 * Module service tests
 *
 * @module tests/modules/module/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/module/module.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null),
}));

const moduleRepository = require('@repositories/module/module.repository');
const { createAuditLog } = require('@lib/audit');
const { resolveEntityId, resolvePublicIdentifier } = require('@lib/billing/identifiers');
const {
  listModules,
  getModuleById,
  createModule,
  updateModule,
  deleteModule,
} = require('@services/module/module.service');

describe('Module Service', () => {
  const moduleRecord = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    human_friendly_id: 'MOD0001',
    name: 'Test Module',
    slug: 'test-module',
    description: 'Test description',
    created_at: new Date('2026-01-01T00:00:00.000Z'),
    updated_at: new Date('2026-01-02T00:00:00.000Z'),
    version: 3,
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveEntityId.mockImplementation(async ({ identifier }) => identifier);
    resolvePublicIdentifier.mockImplementation((...values) => values.find(Boolean) || null);
  });

  describe('listModules', () => {
    it('should list modules with default pagination', async () => {
      moduleRepository.findMany.mockResolvedValue([moduleRecord]);
      moduleRepository.count.mockResolvedValue(10);

      const result = await listModules({}, 1, 20);

      expect(result.modules).toEqual([
        expect.objectContaining({
          id: 'MOD0001',
          display_id: 'MOD0001',
          name: 'Test Module',
          slug: 'test-module',
          description: 'Test description',
          version: 3,
        }),
      ]);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      });
      expect(moduleRepository.findMany).toHaveBeenCalledWith({}, 0, 20, {
        created_at: 'desc',
      });
    });

    it('should filter by search term', async () => {
      moduleRepository.findMany.mockResolvedValue([moduleRecord]);
      moduleRepository.count.mockResolvedValue(1);

      const result = await listModules({ search: 'test' }, 1, 20);

      expect(result.modules).toHaveLength(1);
      expect(moduleRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            { name: { contains: 'test', mode: 'insensitive' } },
            { description: { contains: 'test', mode: 'insensitive' } },
          ]),
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should calculate pagination correctly for multiple pages', async () => {
      moduleRepository.findMany.mockResolvedValue([moduleRecord]);
      moduleRepository.count.mockResolvedValue(50);

      const result = await listModules({}, 2, 20);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 50,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true,
      });
      expect(moduleRepository.findMany).toHaveBeenCalledWith({}, 20, 20, {
        created_at: 'desc',
      });
    });

    it('should use custom sort order', async () => {
      moduleRepository.findMany.mockResolvedValue([moduleRecord]);
      moduleRepository.count.mockResolvedValue(1);

      await listModules({}, 1, 20, 'name', 'asc');

      expect(moduleRepository.findMany).toHaveBeenCalledWith({}, 0, 20, {
        name: 'asc',
      });
    });
  });

  describe('getModuleById', () => {
    it('should return module by ID', async () => {
      moduleRepository.findById.mockResolvedValue(moduleRecord);

      const result = await getModuleById(moduleRecord.id);

      expect(result).toEqual(
        expect.objectContaining({
          id: 'MOD0001',
          display_id: 'MOD0001',
          name: 'Test Module',
        })
      );
      expect(moduleRepository.findById).toHaveBeenCalledWith(moduleRecord.id);
    });

    it('should throw HttpError if module not found', async () => {
      moduleRepository.findById.mockResolvedValue(null);

      await expect(getModuleById(moduleRecord.id)).rejects.toThrow(HttpError);
      await expect(getModuleById(moduleRecord.id)).rejects.toThrow('errors.module.not_found');
    });
  });

  describe('createModule', () => {
    it('should create a new module and log audit', async () => {
      const moduleData = {
        name: 'New Module',
        slug: 'new-module',
        description: 'New description',
      };
      const createdRecord = {
        ...moduleRecord,
        name: 'New Module',
        slug: 'new-module',
        description: 'New description',
      };
      const context = {
        user: { id: 'user-123' },
        ip: '127.0.0.1',
        tenant_id: 'tenant-123',
      };

      moduleRepository.create.mockResolvedValue(createdRecord);
      moduleRepository.findById.mockResolvedValue(createdRecord);

      const result = await createModule(moduleData, context);

      expect(result).toEqual(
        expect.objectContaining({
          id: 'MOD0001',
          name: 'New Module',
          slug: 'new-module',
          description: 'New description',
        })
      );
      expect(moduleRepository.create).toHaveBeenCalledWith(
        expect.objectContaining(moduleData)
      );
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'CREATE',
        entity: 'module',
        entity_id: createdRecord.id,
        diff: { after: createdRecord },
        ip_address: '127.0.0.1',
        tenant_id: 'tenant-123',
      });
    });

    it('should create module even if audit log fails', async () => {
      const createdRecord = { ...moduleRecord, name: 'New Module' };
      const context = {
        user: { id: 'user-123' },
        ip: '127.0.0.1',
        tenant_id: 'tenant-123',
      };

      moduleRepository.create.mockResolvedValue(createdRecord);
      moduleRepository.findById.mockResolvedValue(createdRecord);
      createAuditLog.mockImplementation(() => Promise.reject(new Error('Audit failed')));

      const result = await createModule({ name: 'New Module' }, context);

      expect(result).toEqual(
        expect.objectContaining({
          id: 'MOD0001',
          name: 'New Module',
        })
      );
    });
  });

  describe('updateModule', () => {
    it('should update module and log audit', async () => {
      const existingModule = moduleRecord;
      const updatedModule = {
        ...moduleRecord,
        name: 'Updated Module',
      };
      const context = {
        user: { id: 'user-123' },
        ip: '127.0.0.1',
        tenant_id: 'tenant-123',
      };

      moduleRepository.findById
        .mockResolvedValueOnce(existingModule)
        .mockResolvedValueOnce(updatedModule);
      moduleRepository.update.mockResolvedValue(updatedModule);

      const result = await updateModule(moduleRecord.id, { name: 'Updated Module' }, context);

      expect(result).toEqual(
        expect.objectContaining({
          id: 'MOD0001',
          name: 'Updated Module',
        })
      );
      expect(moduleRepository.update).toHaveBeenCalledWith(moduleRecord.id, {
        name: 'Updated Module',
      });
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'UPDATE',
        entity: 'module',
        entity_id: updatedModule.id,
        diff: { before: existingModule, after: updatedModule },
        ip_address: '127.0.0.1',
        tenant_id: 'tenant-123',
      });
    });

    it('should throw HttpError if module not found', async () => {
      moduleRepository.findById.mockResolvedValue(null);

      await expect(updateModule(moduleRecord.id, { name: 'Updated' }, {})).rejects.toThrow(
        HttpError
      );
      await expect(updateModule(moduleRecord.id, { name: 'Updated' }, {})).rejects.toThrow(
        'errors.module.not_found'
      );
    });
  });

  describe('deleteModule', () => {
    it('should soft delete module and log audit', async () => {
      const existingModule = moduleRecord;
      const deletedModule = {
        ...moduleRecord,
        deleted_at: new Date('2026-01-03T00:00:00.000Z'),
      };
      const context = {
        user: { id: 'user-123' },
        ip: '127.0.0.1',
        tenant_id: 'tenant-123',
      };

      moduleRepository.findById.mockResolvedValue(existingModule);
      moduleRepository.softDelete.mockResolvedValue(deletedModule);

      const result = await deleteModule(moduleRecord.id, context);

      expect(result).toEqual(deletedModule);
      expect(moduleRepository.findById).toHaveBeenCalledWith(moduleRecord.id);
      expect(moduleRepository.softDelete).toHaveBeenCalledWith(moduleRecord.id);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'DELETE',
        entity: 'module',
        entity_id: deletedModule.id,
        diff: { before: existingModule, after: deletedModule },
        ip_address: '127.0.0.1',
        tenant_id: 'tenant-123',
      });
    });

    it('should throw HttpError if module not found', async () => {
      moduleRepository.findById.mockResolvedValue(null);

      await expect(deleteModule(moduleRecord.id, {})).rejects.toThrow(HttpError);
      await expect(deleteModule(moduleRecord.id, {})).rejects.toThrow('errors.module.not_found');
    });
  });
});
