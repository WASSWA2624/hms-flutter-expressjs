/**
 * @jest-environment node
 */

const {
  isModuleEligibleForTier,
  resolveDefaultIncludedModuleIds,
  resolveEffectiveIncludedModuleIds} = require('@lib/subscriptions/plan-default-modules');

describe('plan-default-modules', () => {
  const modules = [
    {
      human_friendly_id: 'MOD-FREE-1',
      minimum_plan_tier_code: 'FREE',
      is_add_on: false},
    {
      human_friendly_id: 'MOD-BASIC-1',
      minimum_plan_tier_code: 'BASIC',
      is_add_on: false},
    {
      human_friendly_id: 'MOD-PRO-1',
      minimum_plan_tier_code: 'PRO',
      is_add_on: false},
    {
      human_friendly_id: 'MOD-ADDON-1',
      minimum_plan_tier_code: 'BASIC',
      is_add_on: true}];

  it('ranks module eligibility by plan tier', () => {
    expect(isModuleEligibleForTier('FREE', 'FREE')).toBe(true);
    expect(isModuleEligibleForTier('FREE', 'BASIC')).toBe(false);
    expect(isModuleEligibleForTier('PRO', 'BASIC')).toBe(true);
    expect(isModuleEligibleForTier('CUSTOM', 'ADVANCED')).toBe(true);
  });

  it('includes core modules at or below the plan tier', () => {
    expect(resolveDefaultIncludedModuleIds('FREE', modules)).toEqual([
      'MOD-FREE-1']);
    expect(resolveDefaultIncludedModuleIds('BASIC', modules)).toEqual([
      'MOD-FREE-1',
      'MOD-BASIC-1']);
    expect(resolveDefaultIncludedModuleIds('PRO', modules)).toEqual([
      'MOD-FREE-1',
      'MOD-BASIC-1',
      'MOD-PRO-1']);
  });

  it('prefers stored allowlists over tier defaults', () => {
    expect(
      resolveEffectiveIncludedModuleIds(['MOD-CUSTOM'], 'PRO', modules)
    ).toEqual(['MOD-CUSTOM']);
    expect(resolveEffectiveIncludedModuleIds([], 'BASIC', modules)).toEqual([
      'MOD-FREE-1',
      'MOD-BASIC-1']);
  });
});
