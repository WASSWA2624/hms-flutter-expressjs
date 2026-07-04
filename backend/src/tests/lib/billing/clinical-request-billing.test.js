/**
 * @module tests/lib/billing/clinical-request-billing
 */

const {
  buildPendingClinicalRequestBilling,
  normalizeBillingOfficeClinicalBilling,
  resolveInvoicePaymentStatus,
} = require('@lib/billing/clinical-request-billing');

describe('clinical-request-billing helpers', () => {
  it('buildPendingClinicalRequestBilling returns pending payload with totals', () => {
    const billing = buildPendingClinicalRequestBilling({
      lineItems: [
        {
          id: 'LAB-CBC',
          label: 'Complete blood count',
          quantity: 1,
          unit_price: '25.00',
          line_total: '25.00',
        },
      ],
      currency: 'USD',
    });

    expect(billing).toEqual(
      expect.objectContaining({
        payment_status: 'PENDING',
        currency: 'USD',
        total_amount: '25.00',
      })
    );
    expect(billing.line_items).toHaveLength(1);
  });

  it('normalizeBillingOfficeClinicalBilling strips pay-now fields', () => {
    const billing = normalizeBillingOfficeClinicalBilling({
      payment_status: 'PAID',
      paid_amount: '25.00',
      payment_method: 'CASH',
      currency: 'USD',
      line_items: [
        {
          id: 'LAB-CBC',
          label: 'Complete blood count',
          quantity: 1,
          unit_price: '25.00',
          line_total: '25.00',
        },
      ],
    });

    expect(billing).toEqual(
      expect.objectContaining({
        payment_status: 'PENDING',
        total_amount: '25.00',
      })
    );
    expect(billing.paid_amount).toBeUndefined();
    expect(billing.payment_method).toBeUndefined();
  });

  it('resolveInvoicePaymentStatus returns PAID when billing_status is PAID', () => {
    expect(
      resolveInvoicePaymentStatus({
        billing_status: 'PAID',
        total_amount: '40.00',
        payments: [],
      })
    ).toBe('PAID');
  });

  it('resolveInvoicePaymentStatus returns PARTIAL for partial payments', () => {
    expect(
      resolveInvoicePaymentStatus({
        billing_status: 'PARTIAL',
        total_amount: '40.00',
        payments: [{ status: 'COMPLETED', amount: '10.00' }],
      })
    ).toBe('PARTIAL');
  });
});
