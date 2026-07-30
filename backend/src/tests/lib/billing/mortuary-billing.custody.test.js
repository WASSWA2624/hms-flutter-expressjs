/**
 * Mortuary MORTUARY source module + persistMortuaryBillableEventBilling
 * for Custody tab billing-sections scan.
 */

const {
  BILLABLE_SOURCE_MODULES,
  normalizeBillableSourceModule,
} = require('@lib/billing/clinical-request-billing');
const {
  persistMortuaryBillableEventBilling,
  buildMortuaryBillableEventBilling,
  resolveMortuaryChargeKey,
  isMortuaryCustodyLogisticsEvent,
  MORTUARY_CHARGE_KEYS,
} = require('@lib/billing/mortuary-billing');

describe('mortuary-billing (Custody tab)', () => {
  it('exposes MORTUARY in BILLABLE_SOURCE_MODULES', () => {
    expect(BILLABLE_SOURCE_MODULES.MORTUARY).toBe('MORTUARY');
  });

  it('exports persistMortuaryBillableEventBilling (no second billing engine)', () => {
    expect(typeof persistMortuaryBillableEventBilling).toBe('function');
  });

  it('maps MORTUARY tokens to MORTUARY source module', () => {
    expect(normalizeBillableSourceModule('MORTUARY')).toBe(
      BILLABLE_SOURCE_MODULES.MORTUARY,
    );
    expect(normalizeBillableSourceModule('mortuary-storage')).toBe(
      BILLABLE_SOURCE_MODULES.MORTUARY,
    );
  });

  it('resolves charge keys for storage / embalming / viewing / release', () => {
    expect(resolveMortuaryChargeKey('STORAGE_FEE')).toBe(
      MORTUARY_CHARGE_KEYS.STORAGE,
    );
    expect(resolveMortuaryChargeKey('EMBALMING')).toBe(
      MORTUARY_CHARGE_KEYS.EMBALMING,
    );
    expect(resolveMortuaryChargeKey('VIEWING')).toBe(
      MORTUARY_CHARGE_KEYS.VIEWING,
    );
    expect(resolveMortuaryChargeKey('RELEASE_CHARGE')).toBe(
      MORTUARY_CHARGE_KEYS.RELEASE,
    );
  });

  it('classifies custody transfers as logistics (NOT_REQUIRED — no ledger)', () => {
    expect(isMortuaryCustodyLogisticsEvent('TRANSFER')).toBe(true);
    expect(isMortuaryCustodyLogisticsEvent('RECEIVED')).toBe(true);
    expect(isMortuaryCustodyLogisticsEvent('STORAGE_ASSIGNED')).toBe(true);
    expect(isMortuaryCustodyLogisticsEvent('EMBALMING')).toBe(false);
  });

  it('builds pending billing from explicit amount', () => {
    const billing = buildMortuaryBillableEventBilling({
      eventType: 'STORAGE_FEE',
      amount: '50.00',
      currency: 'UGX',
      description: 'Cold storage day 1',
    });
    expect(billing).toBeTruthy();
    expect(billing.payment_status).toBe('PENDING');
    expect(shouldApply(billing)).toBe(true);
  });

  it('persistMortuaryBillableEventBilling skips without patient / event id', async () => {
    const applySpy = jest.fn();
    const result = await persistMortuaryBillableEventBilling(
      {},
      {
        billableEventId: null,
        patientId: 'patient-1',
        tenantId: 'tenant-1',
        billing: {
          payment_status: 'PENDING',
          total_amount: '50.00',
          currency: 'UGX',
          line_items: [
            {
              id: 'storage',
              label: 'Storage',
              quantity: 1,
              unit_price: '50.00',
              line_total: '50.00',
            },
          ],
        },
      },
    );
    expect(result).toBeNull();
    expect(applySpy).not.toHaveBeenCalled();
  });

  it('persistMortuaryBillableEventBilling skips NOT_BILLED / NOT_REQUIRED', async () => {
    const result = await persistMortuaryBillableEventBilling(
      {},
      {
        billableEventId: 'mbe-1',
        patientId: 'patient-1',
        tenantId: 'tenant-1',
        billing: { payment_status: 'NOT_REQUIRED' },
      },
    );
    expect(result).toBeNull();
  });
});

function shouldApply(billing) {
  const status = String(billing?.payment_status || '').toUpperCase();
  return (
    status !== 'NOT_BILLED' &&
    status !== 'NOT_REQUIRED' &&
    status !== 'NO_CHARGE'
  );
}
