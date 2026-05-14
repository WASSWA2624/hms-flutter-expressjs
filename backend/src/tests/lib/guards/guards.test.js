/**
 * adaptability guard utility tests
 */

const {
  checkPolicyGuard,
  checkWorkflowStateGuard,
  runDynamicFormValidationHooks,
  checkFeatureFlagGuard,
  isFeatureFlagEnabled
} = require('@lib/guards');

describe('adaptability guards', () => {
  it('evaluates policy guards from boolean and function policies', () => {
    const allowResult = checkPolicyGuard('allow_policy', { allow_policy: true });
    const denyResult = checkPolicyGuard(
      'deny_policy',
      { deny_policy: (ctx) => ctx.role === 'TENANT_ADMIN' },
      { role: 'DOCTOR' }
    );

    expect(allowResult.allowed).toBe(true);
    expect(denyResult.allowed).toBe(false);
  });

  it('validates workflow transitions against transition map', () => {
    const transitions = {
      draft: ['submitted', 'cancelled'],
      submitted: ['approved', 'rejected']
    };

    const allowed = checkWorkflowStateGuard('draft', 'submitted', transitions);
    const denied = checkWorkflowStateGuard('draft', 'approved', transitions);

    expect(allowed.allowed).toBe(true);
    expect(denied.allowed).toBe(false);
  });

  it('runs dynamic form validation hooks and returns collected errors', () => {
    const hooks = [
      (payload) => (!payload.name ? { field: 'name', message: 'errors.validation.required' } : null),
      (payload) => (payload.age < 18 ? 'errors.validation.age_restricted' : null)
    ];

    const invalid = runDynamicFormValidationHooks({ age: 16 }, hooks);
    const valid = runDynamicFormValidationHooks({ name: 'Alice', age: 30 }, hooks);

    expect(invalid.allowed).toBe(false);
    expect(invalid.errors).toHaveLength(2);
    expect(valid.allowed).toBe(true);
    expect(valid.errors).toHaveLength(0);
  });

  it('evaluates feature flags with role and tenant constraints', () => {
    const flags = {
      advanced_reports: {
        enabled: true,
        allowed_roles: ['TENANT_ADMIN', 'FACILITY_ADMIN'],
        blocked_tenants: ['tenant-blocked']
      }
    };

    const allowed = checkFeatureFlagGuard('advanced_reports', flags, {
      role: 'TENANT_ADMIN',
      tenant_id: 'tenant-1'
    });
    const deniedByRole = checkFeatureFlagGuard('advanced_reports', flags, {
      role: 'DOCTOR',
      tenant_id: 'tenant-1'
    });
    const deniedByTenant = checkFeatureFlagGuard('advanced_reports', flags, {
      role: 'TENANT_ADMIN',
      tenant_id: 'tenant-blocked'
    });

    expect(allowed.enabled).toBe(true);
    expect(deniedByRole.enabled).toBe(false);
    expect(deniedByTenant.enabled).toBe(false);
    expect(isFeatureFlagEnabled('advanced_reports', flags, {
      role: 'TENANT_ADMIN',
      tenant_id: 'tenant-1'
    })).toBe(true);
  });
});
