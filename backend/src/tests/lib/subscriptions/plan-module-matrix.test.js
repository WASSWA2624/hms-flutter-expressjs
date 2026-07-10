const {
  COMMERCIAL_MODULE_MATRIX,
  PLATFORM_INFRASTRUCTURE_MODULES,
  modulesForPlanTier,
  isEligibleForTier,
} = require('@lib/subscriptions/plan-module-matrix');

describe('plan-module-matrix', () => {
  test('defines platform infrastructure modules with path segments', () => {
    expect(PLATFORM_INFRASTRUCTURE_MODULES.length).toBeGreaterThanOrEqual(3);
    for (const entry of PLATFORM_INFRASTRUCTURE_MODULES) {
      expect(entry.extension_json?.is_platform_infrastructure).toBe(true);
      expect(Array.isArray(entry.extension_json?.api_path_segments)).toBe(true);
      expect(entry.extension_json.api_path_segments.length).toBeGreaterThan(0);
    }
  });

  test('Free tier includes core clinic stack and excludes higher tiers', () => {
    const freeSlugs = modulesForPlanTier('FREE', {
      includeLegacyAliases: false,
    }).map((entry) => entry.slug);

    expect(freeSlugs).toEqual(
      expect.arrayContaining([
        'auth-rbac-basics',
        'patient-registry',
        'scheduling-queue',
        'encounters-vitals',
        'lab-workflows',
        'pharmacy-dispensing',
        'billing-payments',
        'insurance-claims',
        'notifications-communications',
      ])
    );
    expect(freeSlugs).not.toContain('radiology-workflows');
    expect(freeSlugs).not.toContain('inpatient-bed-management');
    expect(freeSlugs).not.toContain('hr-rosters');
    expect(freeSlugs).not.toContain('subscription-controls');
    expect(freeSlugs).not.toContain('developer-tools');
  });

  test('Basic adds radiology only beyond Free', () => {
    const basic = new Set(
      modulesForPlanTier('BASIC', { includeLegacyAliases: false }).map(
        (entry) => entry.slug
      )
    );
    const free = new Set(
      modulesForPlanTier('FREE', { includeLegacyAliases: false }).map(
        (entry) => entry.slug
      )
    );
    const added = [...basic].filter((slug) => !free.has(slug));
    expect(added).toEqual(['radiology-workflows']);
  });

  test('Pro / Advanced / Custom accumulate correctly', () => {
    expect(isEligibleForTier('PRO', 'BASIC')).toBe(true);
    expect(isEligibleForTier('BASIC', 'PRO')).toBe(false);

    const pro = modulesForPlanTier('PRO', { includeLegacyAliases: false }).map(
      (entry) => entry.slug
    );
    expect(pro).toEqual(
      expect.arrayContaining([
        'inpatient-bed-management',
        'theatre-anesthesia',
        'physiotherapy',
        'facilities-maintenance',
        'reporting-analytics',
      ])
    );
    expect(pro).not.toContain('icu-critical-care');
    expect(pro).not.toContain('hr-rosters');

    const advanced = modulesForPlanTier('ADVANCED', {
      includeLegacyAliases: false,
    }).map((entry) => entry.slug);
    expect(advanced).toEqual(
      expect.arrayContaining([
        'icu-critical-care',
        'inventory-procurement-lite',
        'mortuary',
        'biomedical-engineering-suite',
        'extra-storage',
        'hr-rosters',
      ])
    );
    expect(advanced).not.toContain('developer-tools');

    const custom = modulesForPlanTier('CUSTOM', {
      includeLegacyAliases: false,
    }).map((entry) => entry.slug);
    expect(custom).toEqual(
      expect.arrayContaining([
        'subscription-controls',
        'compliance-audit-core',
        'integrations-core',
        'advanced-analytics',
        'sms-credits',
        'developer-tools',
      ])
    );
  });

  test('commercial matrix has unique slugs', () => {
    const slugs = COMMERCIAL_MODULE_MATRIX.map((entry) => entry.slug);
    expect(new Set(slugs).size).toBe(slugs.length);
  });
});
