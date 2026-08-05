/**
 * @jest-environment node
 */

const {
  filterPermissionRecordsByPlanModules,
  isPermissionAllowedByPlan,
  moduleForPermissionName,
  normalizeEnabledModuleSet} = require('@lib/authorization/permission-module-map');
const { PERMISSIONS } = require('@config/permissions');

describe('permission-module-map', () => {
  it('maps domain prefixes to subscription modules', () => {
    expect(moduleForPermissionName(PERMISSIONS.LAB_READ)).toBe('lab-workflows');
    expect(moduleForPermissionName(PERMISSIONS.PATIENT_READ)).toBe(
      'patient-registry'
    );
    expect(moduleForPermissionName(PERMISSIONS.BILLING_READ)).toBe(
      'billing-payments'
    );
    expect(moduleForPermissionName(PERMISSIONS.PROFILE_READ)).toBeNull();
    expect(moduleForPermissionName(PERMISSIONS.TENANT_ADMIN)).toBeNull();
  });

  it('filters assignable permissions by plan modules', () => {
    const enabled = normalizeEnabledModuleSet([
      { module_slug: 'lab-workflows', is_active: true },
      { module_slug: 'patient-registry', is_active: true }]);

    const filtered = filterPermissionRecordsByPlanModules(
      [
        { id: '1', name: PERMISSIONS.LAB_READ },
        { id: '2', name: PERMISSIONS.PHARMACY_READ },
        { id: '3', name: PERMISSIONS.PROFILE_READ },
        { id: '4', name: PERMISSIONS.PATIENT_READ }],
      enabled
    );

    expect(filtered.map((entry) => entry.name)).toEqual([
      PERMISSIONS.LAB_READ,
      PERMISSIONS.PROFILE_READ,
      PERMISSIONS.PATIENT_READ]);
  });

  it('rejects module-scoped permissions outside the plan', () => {
    const enabled = normalizeEnabledModuleSet(['patient-registry']);
    expect(isPermissionAllowedByPlan(PERMISSIONS.PATIENT_READ, enabled)).toBe(
      true
    );
    expect(isPermissionAllowedByPlan(PERMISSIONS.LAB_WRITE, enabled)).toBe(
      false
    );
    expect(isPermissionAllowedByPlan(PERMISSIONS.PROFILE_READ, enabled)).toBe(
      true
    );
    // Reporting is platform infrastructure on every package.
    expect(isPermissionAllowedByPlan(PERMISSIONS.REPORTS_READ, enabled)).toBe(
      true
    );
  });

  it('filters permission name lists by plan modules', () => {
    const {
      filterPermissionNamesByPlanModules} = require('@lib/authorization/permission-module-map');
    const enabled = normalizeEnabledModuleSet(['lab-workflows']);
    expect(
      filterPermissionNamesByPlanModules(
        [
          PERMISSIONS.LAB_READ,
          PERMISSIONS.PHARMACY_READ,
          PERMISSIONS.PROFILE_READ],
        enabled
      )
    ).toEqual([PERMISSIONS.LAB_READ, PERMISSIONS.PROFILE_READ]);
  });
});
