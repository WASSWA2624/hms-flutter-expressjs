/**
 * Access admin workspace repository tests.
 *
 * @module tests/modules/access-admin-workspace/repositories
 */

jest.mock('@prisma/client', () => ({
  role: {
    findMany: jest.fn(),
    count: jest.fn()
  },
  facility: {
    findMany: jest.fn()
  }
}));
jest.mock('@lib/authorization/assignable-access', () => ({
  buildRoleScopeWhere: jest.fn(() => ({}))
}));
jest.mock('@repositories/tenant-facility-workspace/tenant-facility-workspace.repository', () => ({
  resolveWorkspaceScope: jest.fn()
}));

const prisma = require('@prisma/client');
const { countRoles, findRoles } = require('@repositories/access-admin-workspace/access-admin-workspace.repository');

describe('access admin workspace repository role search', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    prisma.role.findMany.mockResolvedValue([]);
    prisma.role.count.mockResolvedValue(0);
    prisma.facility.findMany.mockResolvedValue([]);
  });

  it('searches role display names in list and count queries', async () => {
    await findRoles({ filters: { search: 'Testing' } });
    await countRoles({}, { search: 'Testing' });

    const displayNameFilter = {
      display_name: { contains: 'Testing' }
    };
    expect(prisma.role.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          OR: expect.arrayContaining([displayNameFilter])
        })
      })
    );
    expect(prisma.role.count).toHaveBeenCalledWith({
      where: expect.objectContaining({
        OR: expect.arrayContaining([displayNameFilter])
      })
    });
  });
});
