/**
 * Mortuary MORTUARY source module + persistMortuaryBillableEventBilling
 * for Reports tab billing-sections scan (export / post-mortem surface).
 */

jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    applyClinicalRequestBilling: jest.fn().mockResolvedValue({
      invoice_id: 'inv-mort-reports-1',
      payment_status: 'PENDING',
      total_amount: '75.00',
    }),
  };
});

const {
  BILLABLE_SOURCE_MODULES,
  applyClinicalRequestBilling,
} = require('@lib/billing/clinical-request-billing');
const {
  persistMortuaryBillableEventBilling,
  buildMortuaryBillableEventBilling,
  resolveMortuaryChargeKey,
  isMortuaryCustodyLogisticsEvent,
  MORTUARY_CHARGE_KEYS,
} = require('@lib/billing/mortuary-billing');

const pendingBilling = {
  payment_status: 'PENDING',
  total_amount: '75.00',
  currency: 'UGX',
  line_items: [
    {
      id: 'viewing',
      label: 'Viewing session',
      quantity: 1,
      unit_price: '75.00',
      line_total: '75.00',
    },
  ],
};

describe('mortuary-billing (Reports tab)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('posts viewing fee through applyClinicalRequestBilling (no bypass)', async () => {
    const tx = {};
    const result = await persistMortuaryBillableEventBilling(tx, {
      billableEventId: 'mbe-reports-1',
      patientId: 'patient-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      eventType: 'VIEWING',
      description: 'Family viewing',
      billing: pendingBilling,
    });

    expect(result).toEqual({
      invoice_id: 'inv-mort-reports-1',
      payment_status: 'PENDING',
      total_amount: '75.00',
    });
    expect(applyClinicalRequestBilling).toHaveBeenCalledTimes(1);
    expect(applyClinicalRequestBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        sourceModule: BILLABLE_SOURCE_MODULES.MORTUARY,
        sourceId: 'mbe-reports-1',
        chargeKey: MORTUARY_CHARGE_KEYS.VIEWING,
        patientId: 'patient-1',
        tenantId: 'tenant-1',
      }),
    );
  });

  it('idempotent replay reuses same sourceId + chargeKey', async () => {
    const tx = {};
    const args = {
      billableEventId: 'mbe-reports-1',
      patientId: 'patient-1',
      tenantId: 'tenant-1',
      eventType: 'VIEWING',
      billing: pendingBilling,
    };
    await persistMortuaryBillableEventBilling(tx, args);
    await persistMortuaryBillableEventBilling(tx, args);
    expect(applyClinicalRequestBilling).toHaveBeenCalledTimes(2);
    expect(applyClinicalRequestBilling.mock.calls[0][1].sourceId).toBe(
      'mbe-reports-1',
    );
    expect(applyClinicalRequestBilling.mock.calls[1][1].sourceId).toBe(
      'mbe-reports-1',
    );
    expect(applyClinicalRequestBilling.mock.calls[0][1].chargeKey).toBe(
      applyClinicalRequestBilling.mock.calls[1][1].chargeKey,
    );
  });

  it('skips NOT_REQUIRED (audited not-billable) without orphan charge', async () => {
    const result = await persistMortuaryBillableEventBilling(
      {},
      {
        billableEventId: 'mbe-reports-1',
        patientId: 'patient-1',
        tenantId: 'tenant-1',
        billing: { payment_status: 'NOT_REQUIRED' },
      },
    );
    expect(result).toBeNull();
    expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('custody logistics remain non-billable; fees still map to charge keys', () => {
    expect(isMortuaryCustodyLogisticsEvent('TRANSFER')).toBe(true);
    expect(resolveMortuaryChargeKey('RELEASE_FEE')).toBe(
      MORTUARY_CHARGE_KEYS.RELEASE,
    );
    expect(typeof buildMortuaryBillableEventBilling).toBe('function');
  });
});
