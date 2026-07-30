/**
 * Mortuary MORTUARY_RELEASE charges + release unpaid gate for Release tab
 * billing-sections scan (`/mortuary?panel=release`).
 */

jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    applyClinicalRequestBilling: jest.fn().mockResolvedValue({
      invoice_id: 'inv-mort-rel-1',
      payment_status: 'PENDING',
      total_amount: '75.00',
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
  buildMortuaryBillableEventBilling,
  resolveMortuaryChargeKey,
  isMortuaryReleaseBlockedByOutstandingBilling,
  MORTUARY_CHARGE_KEYS,
} = require('@lib/billing/mortuary-billing');

const pendingReleaseBilling = {
  payment_status: 'PENDING',
  total_amount: '75.00',
  currency: 'UGX',
  line_items: [
    {
      id: 'release',
      label: 'Mortuary release',
      quantity: 1,
      unit_price: '75.00',
      line_total: '75.00',
    },
  ],
};

describe('mortuary-billing (Release tab)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('resolves RELEASE charge key for release fee event types', () => {
    expect(resolveMortuaryChargeKey('RELEASE_FEE')).toBe(
      MORTUARY_CHARGE_KEYS.RELEASE,
    );
    expect(resolveMortuaryChargeKey('RELEASE_CHARGE')).toBe(
      MORTUARY_CHARGE_KEYS.RELEASE,
    );
    expect(resolveMortuaryChargeKey('body_release')).toBe(
      MORTUARY_CHARGE_KEYS.RELEASE,
    );
  });

  it('builds pending release billing from explicit amount', () => {
    const billing = buildMortuaryBillableEventBilling({
      eventType: 'RELEASE_FEE',
      amount: '75.00',
      currency: 'UGX',
      description: 'Release preparation',
    });
    expect(billing).toBeTruthy();
    expect(billing.payment_status).toBe('PENDING');
    expect(billing.line_items[0].id).toContain('release');
  });

  it('posts release fee through applyClinicalRequestBilling (no bypass)', async () => {
    const tx = {};
    const result = await persistMortuaryBillableEventBilling(tx, {
      billableEventId: 'mbe-rel-1',
      patientId: 'patient-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      eventType: 'RELEASE_FEE',
      description: 'Release preparation',
      billing: pendingReleaseBilling,
    });

    expect(result).toEqual({
      invoice_id: 'inv-mort-rel-1',
      payment_status: 'PENDING',
      total_amount: '75.00',
    });
    expect(applyClinicalRequestBilling).toHaveBeenCalledTimes(1);
    expect(applyClinicalRequestBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        sourceModule: BILLABLE_SOURCE_MODULES.MORTUARY,
        sourceId: 'mbe-rel-1',
        chargeKey: MORTUARY_CHARGE_KEYS.RELEASE,
        patientId: 'patient-1',
        tenantId: 'tenant-1',
      }),
    );
  });

  it('idempotent replay reuses same sourceId + MORTUARY_RELEASE chargeKey', async () => {
    const tx = {};
    const args = {
      billableEventId: 'mbe-rel-1',
      patientId: 'patient-1',
      tenantId: 'tenant-1',
      eventType: 'RELEASE_FEE',
      billing: pendingReleaseBilling,
    };
    await persistMortuaryBillableEventBilling(tx, args);
    await persistMortuaryBillableEventBilling(tx, args);
    expect(applyClinicalRequestBilling).toHaveBeenCalledTimes(2);
    expect(applyClinicalRequestBilling.mock.calls[0][1].sourceId).toBe(
      'mbe-rel-1',
    );
    expect(applyClinicalRequestBilling.mock.calls[1][1].sourceId).toBe(
      'mbe-rel-1',
    );
    expect(applyClinicalRequestBilling.mock.calls[0][1].chargeKey).toBe(
      MORTUARY_CHARGE_KEYS.RELEASE,
    );
    expect(applyClinicalRequestBilling.mock.calls[1][1].chargeKey).toBe(
      MORTUARY_CHARGE_KEYS.RELEASE,
    );
  });

  it('skips NOT_REQUIRED (audited not-billable — no orphan charge)', async () => {
    const result = await persistMortuaryBillableEventBilling(
      {},
      {
        billableEventId: 'mbe-rel-1',
        patientId: 'patient-1',
        tenantId: 'tenant-1',
        billing: { payment_status: 'NOT_REQUIRED' },
      },
    );
    expect(result).toBeNull();
    expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('blocks release progress when billing is unsettled / pending / partial', () => {
    expect(isMortuaryReleaseBlockedByOutstandingBilling('UNSETTLED')).toBe(
      true,
    );
    expect(isMortuaryReleaseBlockedByOutstandingBilling('PENDING')).toBe(true);
    expect(isMortuaryReleaseBlockedByOutstandingBilling('PARTIAL')).toBe(true);
  });

  it('allows release when settled / paid / cancelled / explicit not-billable', () => {
    expect(isMortuaryReleaseBlockedByOutstandingBilling('SETTLED')).toBe(false);
    expect(isMortuaryReleaseBlockedByOutstandingBilling('PAID')).toBe(false);
    expect(isMortuaryReleaseBlockedByOutstandingBilling('CANCELLED')).toBe(
      false,
    );
    expect(isMortuaryReleaseBlockedByOutstandingBilling('NOT_REQUIRED')).toBe(
      false,
    );
    expect(isMortuaryReleaseBlockedByOutstandingBilling('NO_CHARGE')).toBe(
      false,
    );
    expect(isMortuaryReleaseBlockedByOutstandingBilling(null)).toBe(false);
    expect(isMortuaryReleaseBlockedByOutstandingBilling('')).toBe(false);
  });
});
