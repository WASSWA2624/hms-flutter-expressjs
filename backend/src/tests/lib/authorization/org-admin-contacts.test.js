/**
 * @jest-environment node
 */

jest.mock('@prisma/client', () => ({
  user_role: {
    findMany: jest.fn(),
  },
}));

jest.mock('@config/env', () => ({
  PLATFORM_ADMIN_EMAIL: 'support@hosspi.com',
  PLATFORM_ADMIN_PHONE: '+256700000001',
}));

const prisma = require('@prisma/client');
const { ROLES } = require('@config/roles');
const {
  resolveOrgAdminContacts,
  serializeAdminContact,
  appendEnvPlatformSupportContact,
} = require('@lib/authorization/org-admin-contacts');

const adminRow = ({
  id,
  email,
  phone = null,
  firstName,
  lastName,
  roleName,
  facilityId = null,
}) => ({
  id: `ur-${id}`,
  facility_id: facilityId,
  created_at: new Date('2026-01-01T00:00:00.000Z'),
  role: { id: `role-${roleName}`, name: roleName },
  user: {
    id,
    email,
    phone,
    status: 'ACTIVE',
    profile: {
      first_name: firstName,
      middle_name: null,
      last_name: lastName,
    },
  },
});

describe('org-admin-contacts', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('serializes admin contact fields', () => {
    expect(
      serializeAdminContact(
        adminRow({
          id: 'u1',
          email: 'admin@example.com',
          phone: '+256700000002',
          firstName: 'Ada',
          lastName: 'Admin',
          roleName: ROLES.TENANT_ADMIN,
        })
      )
    ).toEqual({
      id: 'u1',
      full_name: 'Ada Admin',
      email: 'admin@example.com',
      phone: '+256700000002',
      role_name: ROLES.TENANT_ADMIN,
    });
  });

  it('returns all tenant/facility/platform admins without a take cap', async () => {
    prisma.user_role.findMany.mockImplementation(async ({ where }) => {
      const roleName = where?.role?.name;
      const roleNames = Array.isArray(roleName?.in)
        ? roleName.in
        : roleName
          ? [roleName]
          : [];
      if (roleName === ROLES.TENANT_ADMIN) {
        return [
          adminRow({
            id: 't1',
            email: 'tenant1@example.com',
            firstName: 'Tenant',
            lastName: 'One',
            roleName: ROLES.TENANT_ADMIN,
          }),
          adminRow({
            id: 't2',
            email: 'tenant2@example.com',
            firstName: 'Tenant',
            lastName: 'Two',
            roleName: ROLES.TENANT_ADMIN,
          }),
          adminRow({
            id: 't3',
            email: 'tenant3@example.com',
            firstName: 'Tenant',
            lastName: 'Three',
            roleName: ROLES.TENANT_ADMIN,
          }),
          adminRow({
            id: 't4',
            email: 'tenant4@example.com',
            firstName: 'Tenant',
            lastName: 'Four',
            roleName: ROLES.TENANT_ADMIN,
          }),
        ];
      }
      if (roleName === ROLES.FACILITY_ADMIN && where.facility_id === 'fac-1') {
        return [
          adminRow({
            id: 'f1',
            email: 'facility1@example.com',
            firstName: 'Facility',
            lastName: 'One',
            roleName: ROLES.FACILITY_ADMIN,
            facilityId: 'fac-1',
          }),
        ];
      }
      if (roleName === ROLES.FACILITY_ADMIN && where.facility_id === null) {
        return [
          adminRow({
            id: 'f2',
            email: 'facility2@example.com',
            firstName: 'Facility',
            lastName: 'Wide',
            roleName: ROLES.FACILITY_ADMIN,
          }),
        ];
      }
      if (
        roleNames.includes(ROLES.PLATFORM_ADMIN) ||
        roleNames.includes(ROLES.PLATFORM_OWNER)
      ) {
        return [
          adminRow({
            id: 'p1',
            email: 'platform1@example.com',
            firstName: 'Platform',
            lastName: 'One',
            roleName: ROLES.PLATFORM_ADMIN,
          }),
          adminRow({
            id: 'p2',
            email: 'platform2@example.com',
            firstName: 'Platform',
            lastName: 'Two',
            roleName: ROLES.PLATFORM_ADMIN,
          }),
        ];
      }
      return [];
    });

    const result = await resolveOrgAdminContacts({
      tenantId: 'tenant-1',
      facilityId: 'fac-1',
    });

    expect(result.tenant_admins).toHaveLength(4);
    expect(result.facility_admins.map((row) => row.id)).toEqual(['f1', 'f2']);
    expect(result.platform_admins.map((row) => row.email)).toEqual([
      'platform1@example.com',
      'platform2@example.com',
    ]);
    expect(
      result.platform_admins.every((row) => row.is_support_channel !== true)
    ).toBe(true);
    expect(
      prisma.user_role.findMany.mock.calls.every(
        ([args]) => args.take === undefined
      )
    ).toBe(true);
  });

  it('does not append env support when live platform admins already exist', () => {
    const contacts = appendEnvPlatformSupportContact([
      {
        id: 'p1',
        full_name: 'Support Twin',
        email: 'support@hosspi.com',
        phone: '+256700000001',
        role_name: ROLES.PLATFORM_ADMIN,
      },
    ]);
    expect(contacts).toHaveLength(1);
  });

  it('appends env support when no live platform admins exist', () => {
    const contacts = appendEnvPlatformSupportContact([]);
    expect(contacts).toEqual([
      expect.objectContaining({
        email: 'support@hosspi.com',
        is_support_channel: true,
        role_name: 'PLATFORM_SUPPORT',
      }),
    ]);
  });
});
