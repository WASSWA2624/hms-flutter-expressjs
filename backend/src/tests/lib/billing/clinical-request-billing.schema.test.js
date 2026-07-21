/**
 * Clinical request billing schema tests
 *
 * @module tests/lib/billing/clinical-request-billing.schema
 */

const {
  clinicalRequestBillingSchema} = require('@lib/billing/clinical-request-billing.schema');
const {
  shouldApplyClinicalRequestBilling,
  resolveScopedBillingAmount} = require('@lib/billing/clinical-request-billing');

describe('Clinical request billing schema', () => {
  it('accepts a pay-now billing payload', () => {
    const result = clinicalRequestBillingSchema.safeParse({
      payment_status: 'PAID',
      currency: 'USD',
      total_amount: 25,
      paid_amount: 25,
      payment_method: 'CASH',
      line_items: [
        {
          id: 'LBT0001',
          label: 'CBC',
          quantity: 1,
          unit_price: 25,
          line_total: 25}]});

    expect(result.success).toBe(true);
    expect(result.data.payment_status).toBe('PAID');
    expect(result.data.total_amount).toBe('25.00');
  });

  it('defaults missing payment status to NOT_BILLED', () => {
    const result = clinicalRequestBillingSchema.safeParse({
      currency: 'USD',
      total_amount: 10});

    expect(result.success).toBe(true);
    expect(result.data.payment_status).toBe('NOT_BILLED');
  });
});

describe('Clinical request billing helpers', () => {
  it('skips NOT_BILLED payloads', () => {
    expect(
      shouldApplyClinicalRequestBilling({
        payment_status: 'NOT_BILLED',
        total_amount: 10})
    ).toBe(false);
  });

  it('prefers line_amount for scoped radiology billing', () => {
    expect(
      resolveScopedBillingAmount({
        total_amount: 100,
        line_amount: 40})
    ).toBe('40.00');
  });
});
