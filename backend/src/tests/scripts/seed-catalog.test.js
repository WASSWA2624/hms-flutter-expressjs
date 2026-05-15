const {
  DEMO_ADD_ON_CATALOG,
  DEMO_PLAN_CATALOG,
  DEMO_ROLE_CODES,
  DEMO_TENANT,
} = require('../../../scripts/seeders/seed-catalog');

describe('seed-catalog', () => {
  it('keeps canonical plan tier coverage aligned to the pricing baseline', () => {
    expect(DEMO_PLAN_CATALOG.map((entry) => entry.code)).toEqual([
      'free',
      'basic',
      'pro',
      'advanced',
      'custom',
    ]);

    const basicPlan = DEMO_PLAN_CATALOG.find((entry) => entry.code === 'basic');
    expect(basicPlan.max_facilities).toBe(1);
    expect(basicPlan.extension_json.branch_allowance.included_branches).toBe(2);

    const proPlan = DEMO_PLAN_CATALOG.find((entry) => entry.code === 'pro');
    expect(proPlan.extension_json.price_notes.yearly).toBe(890);
  });

  it('enforces add-on eligibility rules and usage-based pricing notes', () => {
    const smsCredits = DEMO_ADD_ON_CATALOG.find((entry) => entry.code === 'sms_credits');
    expect(smsCredits.minimum_plan_tier_code).toBe('BASIC');
    expect(smsCredits.extension_json.billing_basis).toBe('usage_based');

    const biomedical = DEMO_ADD_ON_CATALOG.find((entry) => entry.code === 'biomedical_engineering_suite');
    expect(biomedical.minimum_plan_tier_code).toBe('PRO');
    expect(biomedical.extension_json.price_range_usd_monthly).toEqual([49, 199]);
  });

  it('pins the default seeded login emails for the demo workspace', () => {
    expect(DEMO_TENANT.users.map((entry) => entry.email)).toEqual([
      'super.admin@hosspi.com',
      'tenant.admin@hosspi.com',
      'facility.admin@hosspi.com',
      'doctor@hosspi.com',
      'nurse@hosspi.com',
      'lab@hosspi.com',
      'radiology@hosspi.com',
      'pharmacy@hosspi.com',
      'reception@hosspi.com',
      'billing@hosspi.com',
      'operations@hosspi.com',
      'hr@hosspi.com',
      'biomed@hosspi.com',
      'housekeeping@hosspi.com',
      'mortuary.staff@hosspi.com',
      'mortuary.manager@hosspi.com',
      'ambulance@hosspi.com',
      'patient.portal@hosspi.com',
    ]);
  });

  it('keeps every canonical seeded role assigned exactly once through primary or extra roles', () => {
    const assignedRoles = DEMO_TENANT.users.flatMap((entry) => [
      entry.role,
      ...((Array.isArray(entry.extra_roles) ? entry.extra_roles : []).filter(Boolean)),
    ]);

    expect([...assignedRoles].sort()).toEqual([...DEMO_ROLE_CODES].sort());
  });
});
