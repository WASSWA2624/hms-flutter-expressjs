/**
 * Role-Permission repository tests
 *
 * @module tests/modules/role-permission/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  role_permission: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/role-permission/role-permission.repository');

const prisma = require('@prisma/client');

describe('Role-Permission Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find role-permission by ID', async () => {
      const mock = {
        id: 'rp-123',
        role_id: 'role-123',
        permission_id: 'permission-123'
      };
      prisma.role_permission.findFirst.mockResolvedValue(mock);

      const result = await findById('rp-123');

      expect(result).toEqual(mock);
    });
  });

  describe('findMany', () => {
    it('should find many role-permissions', async () => {
      const mocks = [{ id: 'rp-1' }, { id: 'rp-2' }];
      prisma.role_permission.findMany.mockResolvedValue(mocks);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mocks);
    });
  });

  describe('count', () => {
    it('should count role-permissions', async () => {
      prisma.role_permission.count.mockResolvedValue(5);
      const result = await count({});
      expect(result).toBe(5);
    });
  });

  describe('create', () => {
    it('should create role-permission', async () => {
      const mock = { id: 'rp-123', role_id: 'role-123' };
      prisma.role_permission.create.mockResolvedValue(mock);

      const result = await create(mock);

      expect(result).toEqual(mock);
    });
  });

  describe('update', () => {
    it('should update role-permission', async () => {
      const mock = { id: 'rp-123', role_id: 'role-456' };
      prisma.role_permission.update.mockResolvedValue(mock);

      const result = await update('rp-123', { role_id: 'role-456' });

      expect(result).toEqual(mock);
    });
  });

  describe('softDelete', () => {
    it('should soft delete role-permission', async () => {
      const mock = { id: 'rp-123', deleted_at: new Date() };
      prisma.role_permission.update.mockResolvedValue(mock);

      const result = await softDelete('rp-123');

      expect(result).toEqual(mock);
    });
  });
});
