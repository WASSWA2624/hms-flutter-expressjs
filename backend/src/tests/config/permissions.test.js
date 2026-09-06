const {
  ROLES,
  ROLE_VALUES,
  LEGACY_ROLE_ALIASES,
  normalizeRoleName,
} = require('@config/roles');
const {
  PERMISSIONS,
  ROLE_PERMISSIONS,
  ROLE_PERMISSION_TEMPLATES,
} = require('@config/permissions');

describe('permissions config', () => {
  it('includes AMBULANCE_OPERATOR in the canonical role catalog', () => {
    expect(ROLES.AMBULANCE_OPERATOR).toBe('AMBULANCE_OPERATOR');
    expect(ROLE_PERMISSIONS[ROLES.AMBULANCE_OPERATOR]).toBeDefined();
  });

  it('includes RADIOLOGY_TECH in the canonical role catalog', () => {
    expect(ROLES.RADIOLOGY_TECH).toBe('RADIOLOGY_TECH');
    expect(ROLE_PERMISSIONS[ROLES.RADIOLOGY_TECH]).toEqual(
      expect.arrayContaining([PERMISSIONS.RADIOLOGY_READ, PERMISSIONS.RADIOLOGY_WRITE, PERMISSIONS.PATIENT_READ])
    );
  });

  it('grants emergency read/write and not emergency delete to AMBULANCE_OPERATOR', () => {
    const permissions = ROLE_PERMISSIONS[ROLES.AMBULANCE_OPERATOR] || [];

    expect(permissions).toEqual(
      expect.arrayContaining([PERMISSIONS.PROFILE_READ, PERMISSIONS.EMERGENCY_READ, PERMISSIONS.EMERGENCY_WRITE])
    );
    expect(permissions).not.toContain(PERMISSIONS.EMERGENCY_DELETE);
  });

  it('grants emergency delete to admin roles', () => {
    const superAdminPermissions = ROLE_PERMISSIONS[ROLES.PLATFORM_ADMIN] || [];
    const tenantAdminPermissions = ROLE_PERMISSIONS[ROLES.TENANT_ADMIN] || [];
    const facilityAdminPermissions = ROLE_PERMISSIONS[ROLES.FACILITY_ADMIN] || [];

    expect(superAdminPermissions).toContain(PERMISSIONS.EMERGENCY_DELETE);
    expect(tenantAdminPermissions).toContain(PERMISSIONS.EMERGENCY_DELETE);
    expect(facilityAdminPermissions).toContain(PERMISSIONS.EMERGENCY_DELETE);
  });

  it('keeps EMT, PARAMEDIC, and CHARGE_NURSE as distinct canonical roles', () => {
    expect(normalizeRoleName('EMT')).toBe(ROLES.EMT);
    expect(normalizeRoleName('paramedic')).toBe(ROLES.PARAMEDIC);
    expect(normalizeRoleName('CHARGE_NURSE')).toBe(ROLES.CHARGE_NURSE);
    expect(normalizeRoleName('ambulance_driver')).toBe(ROLES.AMBULANCE_OPERATOR);
    expect(normalizeRoleName('FACILITY_BILLING')).toBe(ROLES.BILLING);
  });

  it('normalizes ambulance legacy aliases to AMBULANCE_OPERATOR', () => {
    expect(normalizeRoleName('ambulance_driver')).toBe(ROLES.AMBULANCE_OPERATOR);
  });

  it('differentiates specialty packs from their former template clones', () => {
    expect(ROLE_PERMISSIONS[ROLES.FACILITY_BILLING]).toBeUndefined();
    expect(ROLE_PERMISSIONS[ROLES.PHARMACY_TECHNICIAN]).not.toEqual(
      ROLE_PERMISSIONS[ROLES.PHARMACIST]
    );
    expect(ROLE_PERMISSIONS[ROLES.MEDICAL_CODER]).not.toEqual(
      ROLE_PERMISSIONS[ROLES.BILLING]
    );
    expect(ROLE_PERMISSIONS[ROLES.ACCOUNTANT]).not.toEqual(
      ROLE_PERMISSIONS[ROLES.BILLING]
    );
    expect(ROLE_PERMISSIONS[ROLES.CHARGE_NURSE]).not.toEqual(
      ROLE_PERMISSIONS[ROLES.WARD_MANAGER]
    );
    expect(ROLE_PERMISSIONS[ROLES.SURGEON]).not.toEqual(
      ROLE_PERMISSIONS[ROLES.DOCTOR]
    );
    expect(ROLE_PERMISSIONS[ROLES.EMERGENCY_PHYSICIAN]).toEqual(
      expect.arrayContaining([PERMISSIONS.EMERGENCY_READ, PERMISSIONS.EMERGENCY_WRITE])
    );
    expect(ROLE_PERMISSIONS[ROLES.EMT]).not.toEqual(
      ROLE_PERMISSIONS[ROLES.PARAMEDIC]
    );
    expect(ROLE_PERMISSIONS[ROLES.DOCTOR]).not.toContain(PERMISSIONS.NURSING_READ);
  });

  it('normalizes radiology legacy aliases to RADIOLOGY_TECH', () => {
    expect(normalizeRoleName('radiographer')).toBe(ROLES.RADIOLOGY_TECH);
    expect(normalizeRoleName('radiology_technician')).toBe(ROLES.RADIOLOGY_TECH);
    expect(normalizeRoleName('imaging_tech')).toBe(ROLES.RADIOLOGY_TECH);
  });

  it('grants pharmacy, patient read, and reports read to PHARMACIST', () => {
    expect(ROLE_PERMISSIONS[ROLES.PHARMACIST]).toEqual(
      expect.arrayContaining([
        PERMISSIONS.PHARMACY_READ,
        PERMISSIONS.PHARMACY_WRITE,
        PERMISSIONS.PRICING_PHARMACY_READ,
        PERMISSIONS.PRICING_PHARMACY_WRITE,
        PERMISSIONS.PATIENT_READ,
        PERMISSIONS.REPORTS_READ])
    );
    expect(ROLE_PERMISSIONS[ROLES.PHARMACIST]).not.toContain(
      PERMISSIONS.PATIENT_WRITE
    );
    expect(ROLE_PERMISSIONS[ROLES.PHARMACIST]).not.toContain(
      PERMISSIONS.PATIENTS_READ
    );
    expect(ROLE_PERMISSIONS[ROLES.PHARMACIST]).not.toContain(
      PERMISSIONS.PRICING_FACILITY_WRITE
    );
  });

  it('grants facility pricing to BILLING and not pharmacy retail pricing', () => {
    expect(ROLE_PERMISSIONS[ROLES.BILLING]).toEqual(
      expect.arrayContaining([
        PERMISSIONS.BILLING_READ,
        PERMISSIONS.BILLING_WRITE,
        PERMISSIONS.PRICING_FACILITY_READ,
        PERMISSIONS.PRICING_FACILITY_WRITE,
      ])
    );
    expect(ROLE_PERMISSIONS[ROLES.BILLING]).not.toContain(
      PERMISSIONS.PRICING_PHARMACY_WRITE
    );
    // patients:read omitted — no Patients registry; patient:read for embeds.
    expect(ROLE_PERMISSIONS[ROLES.BILLING]).not.toContain(
      PERMISSIONS.PATIENTS_READ
    );
    expect(ROLE_PERMISSIONS[ROLES.BILLING]).toContain(PERMISSIONS.PATIENT_READ);
    expect(ROLE_PERMISSIONS[ROLES.ACCOUNTANT]).toEqual(
      expect.arrayContaining([
        PERMISSIONS.ACCOUNTS_READ,
        PERMISSIONS.ACCOUNTS_WRITE,
        PERMISSIONS.BILLING_READ,
        PERMISSIONS.FINANCIAL_APPROVE,
        PERMISSIONS.PRICING_FACILITY_READ,
      ])
    );
    expect(ROLE_PERMISSIONS[ROLES.ACCOUNTANT]).not.toContain(
      PERMISSIONS.LAST_OFFICE_WRITE
    );
    expect(ROLE_PERMISSIONS[ROLES.ACCOUNTANT]).not.toContain(
      PERMISSIONS.PATIENTS_READ
    );
  });

  it('normalizes display-form administrator roles to canonical roles', () => {
    expect(normalizeRoleName('Platform Admin')).toBe(ROLES.PLATFORM_ADMIN);
    expect(normalizeRoleName('super-admin')).toBe(ROLES.PLATFORM_ADMIN);
    expect(normalizeRoleName('superadmin')).toBe(ROLES.PLATFORM_ADMIN);
    expect(normalizeRoleName('Administrator')).toBe(ROLES.TENANT_ADMIN);
  });

  it('grants reports:read to every default role pack', () => {
    for (const [role, permissions] of Object.entries(ROLE_PERMISSIONS)) {
      expect(permissions).toEqual(
        expect.arrayContaining([PERMISSIONS.REPORTS_READ])
      );
    }
  });

  it('exposes atomic domain:action permission keys only', () => {
    const values = Object.values(PERMISSIONS);
    expect(values).toHaveLength(85);
    for (const value of values) {
      expect(value).toMatch(/^[a-z0-9_]+:[a-z0-9_]+$/);
      expect(value.split(':')).toHaveLength(2);
    }
  });

  it('documents Accounts role-pack matrix (accounts.md §9 / 02-roles)', () => {
    // | Role pack              | accounts:read | accounts:write | Notes              |
    // | ACCOUNTANT             | yes           | yes            | Books desk primary |
    // | PLATFORM_* / *_ADMIN   | yes           | yes            | Admin access       |
    // | HR / HR_STAFF          | no            | no             | Explicit exclusion |
    // | BILLING / other packs  | no (default)  | no (default)   | Unless assigned    |
    const yes = [PERMISSIONS.ACCOUNTS_READ, PERMISSIONS.ACCOUNTS_WRITE];

    for (const role of [
      ROLES.ACCOUNTANT,
      ROLES.PLATFORM_OWNER,
      ROLES.PLATFORM_ADMIN,
      ROLES.TENANT_ADMIN,
      ROLES.FACILITY_ADMIN,
    ]) {
      expect(ROLE_PERMISSIONS[role]).toEqual(expect.arrayContaining(yes));
    }

    // Accountant keeps finance embeds; not last-office cashier.
    expect(ROLE_PERMISSIONS[ROLES.ACCOUNTANT]).toEqual(
      expect.arrayContaining([
        PERMISSIONS.FINANCIAL_APPROVE,
        PERMISSIONS.BILLING_READ,
        PERMISSIONS.BILLING_WRITE,
      ])
    );
    expect(ROLE_PERMISSIONS[ROLES.ACCOUNTANT]).not.toContain(
      PERMISSIONS.LAST_OFFICE_READ
    );

    for (const role of [
      ROLES.HR,
      ROLES.HR_STAFF,
      ROLES.BILLING,
      ROLES.PHARMACY_BILLING,
      ROLES.DOCTOR,
      ROLES.RECEPTIONIST,
      ROLES.OPERATIONS,
      ROLES.NURSE,
    ]) {
      expect(ROLE_PERMISSIONS[role]).not.toContain(PERMISSIONS.ACCOUNTS_READ);
      expect(ROLE_PERMISSIONS[role]).not.toContain(PERMISSIONS.ACCOUNTS_WRITE);
    }

    expect(PERMISSIONS.ACCOUNTS_READ).toBe('accounts:read');
    expect(PERMISSIONS.ACCOUNTS_WRITE).toBe('accounts:write');
  });
});

// Shape assertions behind `.cursor/access/default_user_roles.mdc`. Changing a
// count here means the rule file must change with it.
describe('shipped role catalog shape', () => {
  const baseRoles = ROLE_VALUES.filter(
    (role) => !ROLE_PERMISSION_TEMPLATES[role]
  );

  const packSignature = (role) =>
    [...new Set(ROLE_PERMISSIONS[role] || [])].sort().join('|');

  it('ships 70 canonical roles, 40 base packs and 30 template roles', () => {
    expect(ROLE_VALUES).toHaveLength(70);
    expect(baseRoles).toHaveLength(40);
    expect(Object.keys(ROLE_PERMISSION_TEMPLATES)).toHaveLength(30);
    expect(Object.keys(ROLE_PERMISSIONS)).toHaveLength(70);
  });

  it('gives every canonical role a resolvable permission pack', () => {
    const missing = ROLE_VALUES.filter(
      (role) => !Array.isArray(ROLE_PERMISSIONS[role])
    );
    expect(missing).toEqual([]);
  });

  it('resolves every template role to its parent pack byte-for-byte', () => {
    for (const [role, parent] of Object.entries(ROLE_PERMISSION_TEMPLATES)) {
      expect(ROLE_PERMISSIONS[role]).toEqual(ROLE_PERMISSIONS[parent]);
    }
  });

  it('keeps base packs distinct apart from two pinned historical pairs', () => {
    const bySignature = new Map();
    for (const role of baseRoles) {
      const signature = packSignature(role);
      bySignature.set(signature, [
        ...(bySignature.get(signature) || []),
        role,
      ]);
    }

    const duplicates = [...bySignature.values()]
      .filter((roles) => roles.length > 1)
      .map((roles) => roles.sort())
      .sort((left, right) => left[0].localeCompare(right[0]));

    // Two base packs are byte-identical to a sibling. They stay separate roles
    // for job title and ABAC scope. Any *new* duplicate is a bug: give the new
    // role rights of its own, or make it a ROLE_PERMISSION_TEMPLATES entry.
    expect(duplicates).toEqual([
      ['AMBULANCE_OPERATOR', 'EMT'],
      ['ANESTHESIOLOGIST', 'SURGEON'],
    ]);
    expect(bySignature.size).toBe(38);
  });

  it('never aliases one canonical role onto another', () => {
    const canonical = new Set(ROLE_VALUES);
    const aliasKeys = Object.keys(LEGACY_ROLE_ALIASES);

    expect(aliasKeys).toHaveLength(40);
    expect(aliasKeys.filter((alias) => canonical.has(alias))).toEqual([]);
    for (const target of Object.values(LEGACY_ROLE_ALIASES)) {
      expect(canonical.has(target)).toBe(true);
    }
  });
});
