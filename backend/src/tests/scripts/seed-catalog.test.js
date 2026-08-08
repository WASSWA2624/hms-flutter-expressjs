const {
  DEMO_ADD_ON_CATALOG,
  DEMO_PLAN_CATALOG,
  DEMO_ROLE_CODES,
  DEMO_TENANT} = require('../../../scripts/seeders/seed-catalog');

describe('seed-catalog', () => {
  it('keeps canonical plan tier coverage aligned to the pricing baseline', () => {
    expect(DEMO_PLAN_CATALOG.map((entry) => entry.code)).toEqual([
      'free',
      'basic',
      'advanced',
      'pro',
      'custom',
      'developer']);

    const basicPlan = DEMO_PLAN_CATALOG.find((entry) => entry.code === 'basic');
    expect(basicPlan.max_facilities).toBe(1);

    const proPlan = DEMO_PLAN_CATALOG.find((entry) => entry.code === 'pro');
    expect(proPlan.extension_json.price_notes.yearly).toBe(890);
  });

  it('keeps optional suites explicitly scoped to custom plans', () => {
    expect(DEMO_ADD_ON_CATALOG.map((entry) => entry.code)).toEqual([
      'compliance_audit_suite',
      'integrations_webhooks_pack']);
    expect(
      DEMO_ADD_ON_CATALOG.every(
        (entry) => entry.minimum_plan_tier_code === 'CUSTOM',
      ),
    ).toBe(true);
  });

  it('pins the default seeded login emails for the demo workspace', () => {
    expect(DEMO_TENANT.users.map((entry) => entry.email)).toEqual([
      'platform.owner@hosspi.com',
      'platform.admin@hosspi.com',
      'tenant.admin@hosspi.com',
      'facility.admin@hosspi.com',
      'integration.admin@hosspi.com',
      'hr.staff@hosspi.com',
      'operations.staff@hosspi.com',
      'discharge@hosspi.com',
      'dentist@hosspi.com',
      'radiologist@hosspi.com',
      'sonographer@hosspi.com',
      'accountant@hosspi.com',
      'support@hosspi.com',
      'visitor@hosspi.com',
      'doctor@hosspi.com',
      'nurse@hosspi.com',
      'lab@hosspi.com',
      'radiology@hosspi.com',
      'pharmacy@hosspi.com',
      'pharmacy2@hosspi.com',
      'reception@hosspi.com',
      'billing@hosspi.com',
      'operations@hosspi.com',
      'hr@hosspi.com',
      'biomed@hosspi.com',
      'housekeeping@hosspi.com',
      'ambulance@hosspi.com',
      'physio@hosspi.com',
      'mortuary.staff@hosspi.com',
      'mortuary.manager@hosspi.com',
      'patient.portal@hosspi.com']);
  });

  it('keeps every demo user role inside the complete shipped role catalog', () => {
    for (const entry of DEMO_TENANT.users) {
      const assignedRoles = [
        entry.role,
        ...((Array.isArray(entry.extra_roles) ? entry.extra_roles : []).filter(Boolean)),
      ];
      expect(new Set(assignedRoles).size).toBe(assignedRoles.length);
      expect(
        assignedRoles.every((role) => DEMO_ROLE_CODES.includes(role)),
      ).toBe(true);
    }
    expect(DEMO_TENANT.users.filter((entry) => entry.role === 'PHARMACIST')).toHaveLength(2);
    expect(DEMO_ROLE_CODES).toEqual(
      expect.arrayContaining([
        'INTEGRATION_ADMIN',
        'HR_STAFF',
        'DISCHARGE_PLANNER',
        'DENTIST',
        'RADIOLOGIST',
        'SONOGRAPHER',
        'ACCOUNTANT',
        'SUPPORT_STAFF',
        'VISITOR_GUEST',
        'PHARMACIST',
      ]),
    );
  });
});
