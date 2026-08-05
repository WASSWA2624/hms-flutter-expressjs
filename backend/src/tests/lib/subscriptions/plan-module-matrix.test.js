const {
  COMMERCIAL_MODULE_MATRIX,
  PLATFORM_INFRASTRUCTURE_MODULES,
  modulesForPlanTier,
  isEligibleForTier} = require('@lib/subscriptions/plan-module-matrix');

describe('plan-module-matrix', () => {
  test('defines platform infrastructure modules with path segments', () => {
    expect(PLATFORM_INFRASTRUCTURE_MODULES.length).toBeGreaterThanOrEqual(3);
    for (const entry of PLATFORM_INFRASTRUCTURE_MODULES) {
      expect(entry.extension_json?.is_platform_infrastructure).toBe(true);
      expect(Array.isArray(entry.extension_json?.api_path_segments)).toBe(true);
      expect(entry.extension_json.api_path_segments.length).toBeGreaterThan(0);
    }
  });

  test('Free tier is limited to identity and registry commercial modules', () => {
    const freeSlugs = modulesForPlanTier('FREE', {
      includeLegacyAliases: false}).map((entry) => entry.slug);

    expect(freeSlugs).toEqual(
      expect.arrayContaining([
        'auth-rbac-basics',
        'patient-registry'])
    );
    expect(freeSlugs).not.toContain('reporting-analytics');
    expect(freeSlugs).not.toContain('radiology-workflows');
    expect(freeSlugs).not.toContain('inpatient-bed-management');
    expect(freeSlugs).not.toContain('hr-rosters');
    expect(freeSlugs).not.toContain('subscription-controls');
    expect(freeSlugs).not.toContain('developer-tools');
  });

  test('reporting-analytics is platform infrastructure for every package', () => {
    const reporting = PLATFORM_INFRASTRUCTURE_MODULES.find(
      (entry) => entry.slug === 'reporting-analytics'
    );
    expect(reporting).toBeDefined();
    expect(reporting.extension_json.is_platform_infrastructure).toBe(true);
    expect(reporting.extension_json.api_path_segments).toEqual(
      expect.arrayContaining([
        'report-definitions',
        'report-runs',
        'report-schedules',
        'reports-workspace'])
    );
  });

  test('Basic adds core administration and outpatient operations', () => {
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
    expect(added).toEqual(
      expect.arrayContaining([
        'scheduling-queue',
        'encounters-vitals',
        'pharmacy-dispensing',
        'billing-payments',
        'notifications-communications',
        'inpatient-bed-management',
        'subscription-controls'])
    );
    expect(added).not.toContain('lab-workflows');
    expect(added).not.toContain('radiology-workflows');
  });

  test('Advanced / Pro / Custom accumulate in catalog order', () => {
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
        'icu-critical-care',
        'hr-rosters',
        'integrations-core'])
    );

    const advanced = modulesForPlanTier('ADVANCED', {
      includeLegacyAliases: false}).map((entry) => entry.slug);
    expect(advanced).toEqual(
      expect.arrayContaining([
        'lab-workflows',
        'radiology-workflows',
        'insurance-claims',
        'physiotherapy'])
    );
    expect(advanced).not.toContain('icu-critical-care');
    expect(advanced).not.toContain('hr-rosters');
    expect(advanced).not.toContain('developer-tools');

    const custom = modulesForPlanTier('CUSTOM', {
      includeLegacyAliases: false}).map((entry) => entry.slug);
    expect(custom).toEqual(
      expect.arrayContaining([
        'subscription-controls',
        'compliance-audit-core',
        'advanced-analytics',
        'sms-credits'])
    );
    expect(custom).not.toContain('developer-tools');

    const developer = modulesForPlanTier('DEVELOPER', {
      includeLegacyAliases: false}).map((entry) => entry.slug);
    expect(developer).toContain('developer-tools');
  });

  test('commercial matrix has unique slugs', () => {
    const slugs = COMMERCIAL_MODULE_MATRIX.map((entry) => entry.slug);
    expect(new Set(slugs).size).toBe(slugs.length);
  });
});
