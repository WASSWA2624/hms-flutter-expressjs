const {
  resolveEffectiveAccess,
} = require('@lib/authorization/effective-access');
const { PERMISSIONS } = require('@config/permissions');

describe('custom role RBAC effective access', () => {
  test('embeds custom role permissions into the effective ceiling', () => {
    const access = resolveEffectiveAccess(
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        roles: [
          {
            role: {
              name: 'TESTING',
              permissions: [
                { permission: { name: PERMISSIONS.BILLING_READ } },
                { permission: { name: PERMISSIONS.LAB_READ } },
                { permission: { name: PERMISSIONS.CLINICAL_READ } },
              ],
            },
          },
        ],
      },
      {
        applyPlanGate: false,
        applyAssignedModuleGate: false,
      }
    );

    expect(access.permissions.sort()).toEqual(
      [
        PERMISSIONS.BILLING_READ,
        PERMISSIONS.CLINICAL_READ,
        PERMISSIONS.LAB_READ,
      ].sort()
    );
    expect(access.role_permissions.sort()).toEqual(
      [
        PERMISSIONS.BILLING_READ,
        PERMISSIONS.CLINICAL_READ,
        PERMISSIONS.LAB_READ,
      ].sort()
    );
  });

  test('does not invent catalog packs for unknown custom role names', () => {
    const access = resolveEffectiveAccess(
      {
        tenant_id: 'tenant-1',
        roles: [{ role: { name: 'TESTING', permissions: [] } }],
      },
      {
        applyPlanGate: false,
        applyAssignedModuleGate: false,
      }
    );

    expect(access.permissions).toEqual([]);
    expect(access.role_permissions).toEqual([]);
  });

  test('facility admin custom role carries facility:admin for setup APIs', () => {
    const access = resolveEffectiveAccess(
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        roles: [
          {
            role: {
              name: 'FACILITY_OPS',
              permissions: [{ permission: { name: PERMISSIONS.FACILITY_ADMIN } }],
            },
          },
        ],
      },
      {
        applyPlanGate: false,
        applyAssignedModuleGate: false,
      }
    );

    expect(access.permissions).toContain(PERMISSIONS.FACILITY_ADMIN);
  });
});
