/**
 * @module tests/lib/billing/clinical-request-billing.engine
 */

const {
  BILLABLE_SOURCE_MODULES,
  buildConsultationBillingPayload,
  shouldApplyClinicalRequestBilling,
  buildPendingClinicalRequestBilling,
} = require('@lib/billing/clinical-request-billing');
const { resolveOfflinePolicy } = require('@config/offline-policies');

describe('billing engine integration helpers', () => {
  describe('buildConsultationBillingPayload', () => {
    it('builds catalogue-typed consultation line items', () => {
      const billing = buildConsultationBillingPayload({
        consultationFee: '75.00',
        currency: 'USD',
        catalogItemId: 'staff-profile-1',
        paymentStatus: 'PENDING',
      });

      expect(billing).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          currency: 'USD',
          total_amount: '75.00',
        })
      );
      expect(billing.line_items[0]).toEqual(
        expect.objectContaining({
          catalog_type: 'CONSULTATION',
          catalog_item_id: 'staff-profile-1',
          unit_price: '75.00',
        })
      );
      expect(shouldApplyClinicalRequestBilling(billing)).toBe(true);
    });

    it('returns null when fee is zero', () => {
      expect(
        buildConsultationBillingPayload({
          consultationFee: '0',
          currency: 'USD',
        })
      ).toBeNull();
    });

    it('marks pay-now as PAID with payment details', () => {
      const billing = buildConsultationBillingPayload({
        consultationFee: '40.00',
        currency: 'UGX',
        payNow: {
          status: 'COMPLETED',
          amount: '40.00',
          method: 'CASH',
          transaction_ref: 'RCPT-1',
        },
      });

      expect(billing).toEqual(
        expect.objectContaining({
          payment_status: 'PAID',
          paid_amount: '40.00',
          payment_method: 'CASH',
          payment_reference: 'RCPT-1',
        })
      );
    });
  });

  describe('source modules', () => {
    it('exposes canonical billable source modules', () => {
      expect(BILLABLE_SOURCE_MODULES.CONSULTATION).toBe('CONSULTATION');
      expect(BILLABLE_SOURCE_MODULES.ADMISSION).toBe('ADMISSION');
      expect(BILLABLE_SOURCE_MODULES.NURSING).toBe('NURSING');
      expect(BILLABLE_SOURCE_MODULES.CONSUMABLE).toBe('CONSUMABLE');
    });
  });

  describe('pending clinical billing', () => {
    it('preserves catalog refs on pending payloads', () => {
      const billing = buildPendingClinicalRequestBilling({
        lineItems: [
          {
            id: 'svc-1',
            label: 'Admission fee',
            quantity: 1,
            unit_price: '100.00',
            line_total: '100.00',
            catalog_type: 'SERVICE',
          },
        ],
        currency: 'USD',
      });

      expect(billing.line_items[0].catalog_type).toBe('SERVICE');
      expect(shouldApplyClinicalRequestBilling(billing)).toBe(true);
    });
  });
});

describe('online-only financial offline policy', () => {
  it('marks payment mutations as online-only and not queueable', () => {
    const policy = resolveOfflinePolicy({
      method: 'POST',
      path: '/api/v1/payments',
    });
    expect(policy.cache).toBe('no-store');
    expect(policy.online_only).toBe(true);
    expect(policy.allow_offline_queue).toBe(false);
  });

  it('marks billing workspace mutations as online-only', () => {
    const policy = resolveOfflinePolicy({
      method: 'POST',
      path: '/api/v1/billing/invoices/INV-1/payments',
    });
    expect(policy.online_only).toBe(true);
    expect(policy.allow_offline_queue).toBe(false);
  });

  it('marks refunds and closeout as online-only', () => {
    expect(
      resolveOfflinePolicy({ method: 'POST', path: '/api/v1/refunds' }).online_only
    ).toBe(true);
    expect(
      resolveOfflinePolicy({ method: 'POST', path: '/api/v1/shift-closes' })
        .online_only
    ).toBe(true);
    expect(
      resolveOfflinePolicy({ method: 'POST', path: '/api/v1/day-closes' })
        .online_only
    ).toBe(true);
  });

  it('allows non-financial list GETs to remain sync-capable', () => {
    const policy = resolveOfflinePolicy({
      method: 'GET',
      path: '/api/v1/appointments',
    });
    expect(policy.cache).toBe('sync');
    expect(policy.online_only).toBe(false);
  });
});
