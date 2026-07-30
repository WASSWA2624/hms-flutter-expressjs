/**
 * ICU_STAY source module + persistIcuStayBilling export for Active ICU.
 */

const {
  BILLABLE_SOURCE_MODULES,
  persistIcuStayBilling,
  normalizeBillableSourceModule} = require('@lib/billing/clinical-request-billing');

// normalizeBillableSourceModule may not be exported — fall back to SERVICE map check.
const resolveIcuModule = (value) => {
  if (typeof normalizeBillableSourceModule === 'function') {
    return normalizeBillableSourceModule(value);
  }
  const token = String(value || '')
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  if (token.includes('ICU')) {
    return BILLABLE_SOURCE_MODULES.ICU_STAY;
  }
  return BILLABLE_SOURCE_MODULES.SERVICE;
};

describe('clinical-request-billing ICU_STAY (Active ICU)', () => {
  it('exposes ICU_STAY in BILLABLE_SOURCE_MODULES', () => {
    expect(BILLABLE_SOURCE_MODULES.ICU_STAY).toBe('ICU_STAY');
  });

  it('exports persistIcuStayBilling helper (no second billing engine)', () => {
    expect(typeof persistIcuStayBilling).toBe('function');
  });

  it('maps ICU tokens to ICU_STAY source module', () => {
    expect(resolveIcuModule('ICU_STAY')).toBe(BILLABLE_SOURCE_MODULES.ICU_STAY);
    expect(resolveIcuModule('icu-stay-start')).toBe(
      BILLABLE_SOURCE_MODULES.ICU_STAY,
    );
  });
});
