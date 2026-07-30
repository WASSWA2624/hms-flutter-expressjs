/**
 * Mortuary MORTUARY source module + persistMortuaryBillableEventBilling
 * for Storage tab billing-sections scan.
 */

jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    applyClinicalRequestBilling: jest.fn().mockResolvedValue({
      invoice_id: 'inv-mort-storage-1',
      payment_status: 'PENDING',
      total_amount: '50.00',
    }),
  };
});

const {
  BILLABLE_SOURCE_MODULES,
} = require('@lib/billing/clinical-request-billing');
const {
  applyClinicalRequestBilling,
} = require('@lib/billing/clinical-request-billing');
const {
  persistMortuaryBillableEventBilling,
  applyMortuaryBillableEventBilling,
  buildMortuaryBillableEventBilling,
  resolveMortuaryChargeKey,
  isMortuaryCustodyLogisticsEvent,
  MORTUARY_CHARGE_KEYS,
} = require('@lib/billing/mortuary-billing');

const pendingBilling = {
  payment_status: 'PENDING',
  total_amount: '50.00',
  currency: 'UGX',
  line_items: [
    {
      id: 'storage',
      label: 'Cold storage',
      quantity: 1,
      unit_price: '50.00',
      line_total: '50.00',
    },
  ],
};

describe('mortuary-billing (Storage tab)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('exposes MORTUARY in BILLABLE_SOURCE_MODULES', () => {
    expect(BILLABLE_SOURCE_MODULES.MORTUARY).toBe('MORTUARY');
  });

  it('exports persistMortuaryBillableEventBilling (no second billing engine)', () => {
    expect(typeof persistMortuaryBillableEventBilling).toBe('function');
    expect(typeof applyMortuaryBillableEventBilling).toBe('function');
  });

  it('resolves charge keys for storage / embalming / viewing / release', () => {
    expect(resolveMortuaryChargeKey('STORAGE_FEE')).toBe(
      MORTUARY_CHARGE_KEYS.STORAGE,
    );
    expect(resolveMortuaryChargeKey('INTAKE_STORAGE')).toBe(
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

  it('classifies storage assignment as logistics (NOT_REQUIRED — no ledger)', () => {
    expect(isMortuaryCustodyLogisticsEvent('STORAGE_ASSIGNED')).toBe(true);
    expect(isMortuaryCustodyLogisticsEvent('MOVED')).toBe(true);
    expect(isMortuaryCustodyLogisticsEvent('STORAGE_FEE')).toBe(false);
  });

  it('builds pending billing from explicit storage amount', () => {
    const billing = buildMortuaryBillableEventBilling({
      eventType: 'STORAGE_FEE',
      amount: '50.00',
      currency: 'UGX',
      description: 'Cold storage day 1',
    });
    expect(billing).toBeTruthy();
    expect(billing.payment_status).toBe('PENDING');
  });

  it('posts storage fee through applyClinicalRequestBilling (no bypass)', async () => {
    const tx = {};
    const result = await persistMortuaryBillableEventBilling(tx, {
      billableEventId: 'mbe-storage-1',
      patientId: 'patient-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      eventType: 'STORAGE_FEE',
      description: 'Cold storage day 1',
      billing: pendingBilling,
    });

    expect(result).toEqual({
      invoice_id: 'inv-mort-storage-1',
      payment_status: 'PENDING',
      total_amount: '50.00',
    });
    expect(applyClinicalRequestBilling).toHaveBeenCalledTimes(1);
    expect(applyClinicalRequestBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        sourceModule: BILLABLE_SOURCE_MODULES.MORTUARY,
        sourceId: 'mbe-storage-1',
        chargeKey: MORTUARY_CHARGE_KEYS.STORAGE,
        patientId: 'patient-1',
        tenantId: 'tenant-1',
      }),
    );
  });

  it('idempotent replay reuses same sourceId + chargeKey', async () => {
    const tx = {};
    const args = {
      billableEventId: 'mbe-storage-1',
      patientId: 'patient-1',
      tenantId: 'tenant-1',
      eventType: 'STORAGE_FEE',
      billing: pendingBilling,
    };
    await persistMortuaryBillableEventBilling(tx, args);
    await persistMortuaryBillableEventBilling(tx, args);
    expect(applyClinicalRequestBilling).toHaveBeenCalledTimes(2);
    expect(applyClinicalRequestBilling.mock.calls[0][1].sourceId).toBe(
      'mbe-storage-1',
    );
    expect(applyClinicalRequestBilling.mock.calls[1][1].sourceId).toBe(
      'mbe-storage-1',
    );
    expect(applyClinicalRequestBilling.mock.calls[0][1].chargeKey).toBe(
      applyClinicalRequestBilling.mock.calls[1][1].chargeKey,
    );
  });

  it('skips without patient / event id (no orphan charge)', async () => {
    const result = await persistMortuaryBillableEventBilling(
      {},
      {
        billableEventId: null,
        patientId: 'patient-1',
        tenantId: 'tenant-1',
        billing: pendingBilling,
      },
    );
    expect(result).toBeNull();
    expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('audits NOT_REQUIRED for storage assignment logistics (no Billing post)', async () => {
    const tx = {
      mortuary_billable_event: {
        update: jest.fn().mockResolvedValue({}),
      },
    };

    const snapshot = await applyMortuaryBillableEventBilling(tx, {
      billableEvent: {
        id: 'mbe-assign-1',
        tenant_id: 'tenant-1',
        patient_id: 'patient-1',
        event_type: 'STORAGE_ASSIGNED',
      },
    });

    expect(snapshot).toEqual(
      expect.objectContaining({
        payment_status: 'NOT_REQUIRED',
        skipped: true,
        reason: 'NOT_REQUIRED',
      }),
    );
    expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('skips NOT_BILLED / NOT_REQUIRED (audited not-billable)', async () => {
    const result = await persistMortuaryBillableEventBilling(
      {},
      {
        billableEventId: 'mbe-storage-1',
        patientId: 'patient-1',
        tenantId: 'tenant-1',
        billing: { payment_status: 'NOT_REQUIRED' },
      },
    );
    expect(result).toBeNull();
    expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
