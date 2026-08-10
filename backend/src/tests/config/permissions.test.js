const { ROLES, normalizeRoleName } = require('@config/roles');
const { PERMISSIONS, ROLE_PERMISSIONS } = require('@config/permissions');

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
    expect(values).toHaveLength(83);
    for (const value of values) {
      expect(value).toMatch(/^[a-z0-9_]+:[a-z0-9_]+$/);
      expect(value.split(':')).toHaveLength(2);
    }
  });
});
