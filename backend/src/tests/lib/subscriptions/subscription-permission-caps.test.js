/**
 * @jest-environment node
 */

const {
  PLAN_PERMISSION_CAPS,
} = require('@lib/subscriptions/subscription-permission-caps');
const {
  COMMERCIAL_MODULE_MATRIX,
  PLATFORM_INFRASTRUCTURE_MODULES,
} = require('@lib/subscriptions/plan-module-matrix');
const {
  isModuleScopedPermission,
  moduleForPermissionName,
} = require('@lib/authorization/permission-module-map');
const {
  isVersionDisabledPermission,
} = require('@config/version-disabled-permissions');
const { PERMISSIONS } = require('@config/permissions');

const ORDERED_TIERS = ['FREE', 'BASIC', 'ADVANCED', 'PRO'];
const TIER_RANK = Object.fromEntries(
  ORDERED_TIERS.map((tier, index) => [tier, index])
);

const MINIMUM_TIER_BY_SLUG = (() => {
  const map = {};
  for (const entry of PLATFORM_INFRASTRUCTURE_MODULES) {
    map[entry.slug] = 'FREE';
  }
  for (const entry of COMMERCIAL_MODULE_MATRIX) {
    map[entry.slug] = entry.minimum_plan_tier_code;
  }
  return map;
})();

describe('subscription permission caps', () => {
  it('only lists module-scoped permissions (core keys in a cap are inert)', () => {
    const inert = [];
    for (const tier of ORDERED_TIERS) {
      for (const permission of PLAN_PERMISSION_CAPS[tier]) {
        if (!isModuleScopedPermission(permission)) {
          inert.push(`${tier}: ${permission}`);
        }
      }
    }

    expect(inert).toEqual([]);
  });

  it('never grants a permission below its module minimum plan tier', () => {
    const violations = [];
    for (const tier of ORDERED_TIERS) {
      for (const permission of PLAN_PERMISSION_CAPS[tier]) {
        const slug = moduleForPermissionName(permission);
        if (!slug) continue;

        const minimum = MINIMUM_TIER_BY_SLUG[slug];
        expect(minimum).toBeDefined();

        // CUSTOM / DEVELOPER modules are not part of the cumulative ladder.
        if (TIER_RANK[minimum] === undefined) continue;
        if (TIER_RANK[minimum] > TIER_RANK[tier]) {
          violations.push(
            `${tier}: ${permission} -> ${slug} requires ${minimum}`
          );
        }
      }
    }

    expect(violations).toEqual([]);
  });

  it('omits version-disabled domains from every tier', () => {
    for (const tier of Object.keys(PLAN_PERMISSION_CAPS)) {
      const disabled = PLAN_PERMISSION_CAPS[tier].filter(
        isVersionDisabledPermission
      );
      expect(disabled).toEqual([]);
    }
  });

  it('caps every module-scoped catalog permission that is still shipped', () => {
    const pro = new Set(PLAN_PERMISSION_CAPS.PRO);
    const unreachable = Object.values(PERMISSIONS).filter(
      (permission) =>
        isModuleScopedPermission(permission) &&
        !isVersionDisabledPermission(permission) &&
        !pro.has(permission)
    );

    // A module-scoped key absent from every tier can never be granted, because
    // the cap is intersected with the grant union on all plans.
    expect(unreachable).toEqual([]);
  });

  it('keeps tiers cumulative', () => {
    for (let i = 1; i < ORDERED_TIERS.length; i += 1) {
      const lower = new Set(PLAN_PERMISSION_CAPS[ORDERED_TIERS[i - 1]]);
      const higher = new Set(PLAN_PERMISSION_CAPS[ORDERED_TIERS[i]]);
      const dropped = [...lower].filter((permission) => !higher.has(permission));
      expect(dropped).toEqual([]);
    }
  });

  it('places the ICU and theatre entry keys at PRO, matching their modules', () => {
    expect(PLAN_PERMISSION_CAPS.ADVANCED).not.toContain('icu:read');
    expect(PLAN_PERMISSION_CAPS.ADVANCED).not.toContain('theater:read');
    expect(PLAN_PERMISSION_CAPS.PRO).toContain('icu:read');
    expect(PLAN_PERMISSION_CAPS.PRO).toContain('theater:read');
  });
});
