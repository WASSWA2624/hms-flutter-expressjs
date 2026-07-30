/**
 * Mortuary billing helpers — Intake tab (storage / embalming / viewing / release).
 *
 * @module tests/lib/billing/mortuary-billing.intake
 */

jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    applyClinicalRequestBilling: jest.fn(),
  };
});

const {
  applyClinicalRequestBilling,
  BILLABLE_SOURCE_MODULES,
  shouldApplyClinicalRequestBilling,
} = require('@lib/billing/clinical-request-billing');
const {
  MORTUARY_CHARGE_KEYS,
  applyMortuaryBillableEventBilling,
  buildMortuaryBillableEventBilling,
  persistMortuaryBillableEventBilling,
  resolveMortuaryChargeKey,
  resolveMortuaryLedgerPaymentStatus,
  mapLedgerPaymentStatusToMortuary,
  aggregateMortuaryCaseBillingStatus,
  isMortuaryCustodyLogisticsEvent,
} = require('@lib/billing/mortuary-billing');

describe('mortuary-billing (Intake tab)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('buildMortuaryBillableEventBilling (create-charge / no PAID bypass)', () => {
    it('builds PENDING storage fee from explicit amount', () => {
      const billing = buildMortuaryBillableEventBilling({
        eventType: 'STORAGE_FEE',
        amount: '75.00',
        currency: 'UGX',
        description: 'Cold storage day 1',
      });
      expect(billing).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          total_amount: '75.00',
          currency: 'UGX',
        })
      );
      expect(shouldApplyClinicalRequestBilling(billing)).toBe(true);
    });

    it('normalizes caller PAID payload to office PENDING (no pay-now bypass)', () => {
      const billing = buildMortuaryBillableEventBilling({
        billing: {
          payment_status: 'PAID',
          currency: 'USD',
          total_amount: '50.00',
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
      });
      expect(billing.payment_status).toBe('PENDING');
      expect(billing.total_amount).toBe('50.00');
    });

    it('resolves facility embalming / viewing / release fees', () => {
      const facility = {
        extension_json: {
          billing: {
            mortuary_embalming_fee: '200.00',
            mortuary_viewing_fee: '40.00',
            mortuary_release_fee: '90.00',
            currency: 'USD',
          },
        },
      };
      expect(
        buildMortuaryBillableEventBilling({
          eventType: 'EMBALMING',
          facility,
        }).total_amount
      ).toBe('200.00');
      expect(
        buildMortuaryBillableEventBilling({
          eventType: 'VIEWING',
          facility,
        }).total_amount
      ).toBe('40.00');
      expect(
        buildMortuaryBillableEventBilling({
          eventType: 'RELEASE',
          facility,
        }).total_amount
      ).toBe('90.00');
    });

    it('returns null when amount and facility fee are missing (NOT_BILLED)', () => {
      expect(
        buildMortuaryBillableEventBilling({ eventType: 'STORAGE' })
      ).toBeNull();
    });
  });

  describe('persistMortuaryBillableEventBilling (posting / idempotency / authz inputs)', () => {
    it('posts MORTUARY source with stable event id (no bypass)', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-mort-1',
        payment_status: 'PENDING',
      });

      const billing = buildMortuaryBillableEventBilling({
        eventType: 'STORAGE',
        amount: '50.00',
        currency: 'USD',
      });
      const snapshot = await persistMortuaryBillableEventBilling(
        {},
        {
          billableEventId: 'mbe-uuid-1',
          billing,
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          patientId: 'patient-1',
          actorUserId: 'user-1',
          eventType: 'STORAGE',
        }
      );

      expect(snapshot).toEqual(
        expect.objectContaining({
          invoice_id: 'inv-mort-1',
          payment_status: 'PENDING',
        })
      );
      expect(applyClinicalRequestBilling).toHaveBeenCalledWith(
        {},
        expect.objectContaining({
          sourceModule: BILLABLE_SOURCE_MODULES.MORTUARY,
          sourceId: 'mbe-uuid-1',
          chargeKey: MORTUARY_CHARGE_KEYS.STORAGE,
          patientId: 'patient-1',
          billing: expect.objectContaining({ payment_status: 'PENDING' }),
        })
      );
    });

    it('idempotent replay reuses applyClinicalRequestBilling (stable source)', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-mort-1',
        payment_status: 'PENDING',
      });
      const billing = buildMortuaryBillableEventBilling({
        eventType: 'EMBALMING',
        amount: '100.00',
      });
      const args = {
        billableEventId: 'mbe-embalm-1',
        billing,
        tenantId: 'tenant-1',
        patientId: 'patient-1',
        eventType: 'EMBALMING',
      };
      await persistMortuaryBillableEventBilling({}, args);
      await persistMortuaryBillableEventBilling({}, args);
      expect(applyClinicalRequestBilling).toHaveBeenCalledTimes(2);
      expect(applyClinicalRequestBilling.mock.calls[0][1].sourceId).toBe(
        applyClinicalRequestBilling.mock.calls[1][1].sourceId
      );
      expect(applyClinicalRequestBilling.mock.calls[0][1].chargeKey).toBe(
        MORTUARY_CHARGE_KEYS.EMBALMING
      );
    });

    it('returns null without patient / tenant (no invent)', async () => {
      const result = await persistMortuaryBillableEventBilling(
        {},
        {
          billableEventId: 'mbe-1',
          billing: { payment_status: 'PENDING', total_amount: '10.00' },
          tenantId: 'tenant-1',
          patientId: null,
        }
      );
      expect(result).toBeNull();
      expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
    });

    it('skips NOT_REQUIRED / NOT_BILLED payloads', async () => {
      const result = await persistMortuaryBillableEventBilling(
        {},
        {
          billableEventId: 'mbe-1',
          patientId: 'patient-1',
          tenantId: 'tenant-1',
          billing: { payment_status: 'NOT_REQUIRED' },
        }
      );
      expect(result).toBeNull();
      expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
    });
  });

  describe('applyMortuaryBillableEventBilling (mirror + continuity)', () => {
    it('posts and mirrors invoice onto local event + case', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-mirror-1',
        payment_status: 'PENDING',
      });
      const tx = {
        mortuary_billable_event: {
          update: jest.fn().mockResolvedValue({}),
        },
        mortuary_case: {
          update: jest.fn().mockResolvedValue({}),
        },
      };

      const snapshot = await applyMortuaryBillableEventBilling(tx, {
        billableEvent: {
          id: 'mbe-apply-1',
          event_type: 'VIEWING',
          amount: '30.00',
          currency: 'USD',
          tenant_id: 'tenant-1',
          patient_id: 'patient-1',
          facility_id: 'facility-1',
          mortuary_case_id: 'case-1',
          description: 'Family viewing',
        },
      });

      expect(snapshot).toEqual(
        expect.objectContaining({
          invoice_id: 'inv-mirror-1',
          payment_status: 'PENDING',
        })
      );
      expect(tx.mortuary_billable_event.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'mbe-apply-1' },
          data: expect.objectContaining({
            billing_reference_id: 'inv-mirror-1',
            status: 'PENDING',
          }),
        })
      );
      expect(tx.mortuary_case.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'case-1' },
          data: { billing_status: 'PENDING' },
        })
      );
    });

    it('marks custody logistics as NOT_REQUIRED without posting', async () => {
      const tx = {
        mortuary_billable_event: {
          update: jest.fn().mockResolvedValue({}),
        },
      };
      const snapshot = await applyMortuaryBillableEventBilling(tx, {
        billableEvent: {
          id: 'mbe-custody-1',
          event_type: 'TRANSFER',
          tenant_id: 'tenant-1',
          patient_id: 'patient-1',
        },
      });
      expect(snapshot).toEqual(
        expect.objectContaining({
          payment_status: 'NOT_REQUIRED',
          skipped: true,
        })
      );
      expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
    });
  });

  describe('ledger parity / false PAID leakage', () => {
    it('downgrades local SETTLED/PAID without ledger row to PENDING', async () => {
      const ledger = await resolveMortuaryLedgerPaymentStatus(
        {},
        {
          tenantId: 'tenant-1',
          billableEventId: 'mbe-orphan',
          eventType: 'STORAGE',
          localStatus: 'PAID',
        }
      );
      expect(ledger.payment_status).toBe('PENDING');
      expect(ledger.invoice_id).toBeNull();
    });

    it('maps and aggregates ledger statuses for case parity', () => {
      expect(mapLedgerPaymentStatusToMortuary('PAID')).toBe('PAID');
      expect(mapLedgerPaymentStatusToMortuary('PARTIAL')).toBe('PARTIAL');
      expect(aggregateMortuaryCaseBillingStatus(['PENDING', 'PAID'])).toBe(
        'PENDING'
      );
      expect(aggregateMortuaryCaseBillingStatus(['PAID', 'SETTLED'])).toBe(
        'SETTLED'
      );
    });

    it('classifies charge keys and custody logistics', () => {
      expect(resolveMortuaryChargeKey('INTAKE_STORAGE')).toBe(
        MORTUARY_CHARGE_KEYS.STORAGE
      );
      expect(isMortuaryCustodyLogisticsEvent('HANDOVER')).toBe(true);
      expect(isMortuaryCustodyLogisticsEvent('EMBALMING')).toBe(false);
    });
  });
});
