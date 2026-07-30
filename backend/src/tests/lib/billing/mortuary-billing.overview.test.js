/**
 * Mortuary Overview billing helpers — storage / embalming / viewing / release
 * fees post through shared clinical-request-billing (MORTUARY). Custody is
 * NOT_REQUIRED logistics.
 *
 * @module tests/lib/billing/mortuary-billing.overview
 */

const {
  BILLABLE_SOURCE_MODULES,
  MORTUARY_CHARGE_KEYS,
  resolveMortuaryChargeKey,
  buildMortuaryBillableEventBilling,
  persistMortuaryBillableEventBilling,
  applyMortuaryBillableEventBilling,
  mapLedgerPaymentStatusToMortuary,
  aggregateMortuaryCaseBillingStatus,
  isMortuaryCustodyLogisticsEvent,
  shouldApplyClinicalRequestBilling,
} = require('@lib/billing/mortuary-billing');

jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    applyClinicalRequestBilling: jest.fn(),
  };
});

const {
  applyClinicalRequestBilling,
} = require('@lib/billing/clinical-request-billing');

describe('mortuary-billing (Overview / AC posting + parity)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('resolveMortuaryChargeKey', () => {
    it('maps storage / embalming / viewing / release event types', () => {
      expect(resolveMortuaryChargeKey('STORAGE_FEE')).toBe(
        MORTUARY_CHARGE_KEYS.STORAGE
      );
      expect(resolveMortuaryChargeKey('INTAKE_STORAGE')).toBe(
        MORTUARY_CHARGE_KEYS.STORAGE
      );
      expect(resolveMortuaryChargeKey('EMBALMING')).toBe(
        MORTUARY_CHARGE_KEYS.EMBALMING
      );
      expect(resolveMortuaryChargeKey('VIEWING_SESSION')).toBe(
        MORTUARY_CHARGE_KEYS.VIEWING
      );
      expect(resolveMortuaryChargeKey('RELEASE_PREP')).toBe(
        MORTUARY_CHARGE_KEYS.RELEASE
      );
    });
  });

  describe('isMortuaryCustodyLogisticsEvent', () => {
    it('treats custody transfers as NOT_REQUIRED logistics', () => {
      expect(isMortuaryCustodyLogisticsEvent('CUSTODY_TRANSFER')).toBe(true);
      expect(isMortuaryCustodyLogisticsEvent('STORAGE_ASSIGNED')).toBe(true);
      expect(isMortuaryCustodyLogisticsEvent('HANDOVER')).toBe(true);
      expect(isMortuaryCustodyLogisticsEvent('STORAGE_FEE')).toBe(false);
      expect(isMortuaryCustodyLogisticsEvent('EMBALMING')).toBe(false);
    });
  });

  describe('mapLedgerPaymentStatusToMortuary / aggregate', () => {
    it('maps Billing payment statuses for Overview parity', () => {
      expect(mapLedgerPaymentStatusToMortuary('PENDING')).toBe('PENDING');
      expect(mapLedgerPaymentStatusToMortuary('COMPLETED')).toBe('SETTLED');
      expect(mapLedgerPaymentStatusToMortuary('PARTIAL')).toBe('PARTIAL');
      expect(mapLedgerPaymentStatusToMortuary('NOT_REQUIRED')).toBe(
        'NOT_REQUIRED'
      );
    });

    it('aggregates case billing status from event rows', () => {
      expect(aggregateMortuaryCaseBillingStatus(['SETTLED', 'PAID'])).toBe(
        'SETTLED'
      );
      expect(aggregateMortuaryCaseBillingStatus(['PENDING', 'SETTLED'])).toBe(
        'PENDING'
      );
      expect(aggregateMortuaryCaseBillingStatus(['PARTIAL'])).toBe('PARTIAL');
    });
  });

  describe('buildMortuaryBillableEventBilling', () => {
    it('builds PENDING storage charge from facility fee', () => {
      const billing = buildMortuaryBillableEventBilling({
        eventType: 'STORAGE_FEE',
        facility: {
          extension_json: {
            billing: { mortuary_storage_fee: 80, currency: 'UGX' },
          },
        },
      });

      expect(billing).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          currency: 'UGX',
          total_amount: '80.00',
        })
      );
      expect(shouldApplyClinicalRequestBilling(billing)).toBe(true);
    });

    it('returns null when no fee resolves (NOT_REQUIRED path)', () => {
      expect(
        buildMortuaryBillableEventBilling({
          eventType: 'STORAGE_FEE',
          facility: null,
        })
      ).toBeNull();
    });

    it('prefers explicit amount over facility defaults', () => {
      const billing = buildMortuaryBillableEventBilling({
        eventType: 'EMBALMING',
        amount: 120,
        currency: 'USD',
        facility: {
          extension_json: { billing: { mortuary_embalming_fee: 999 } },
        },
      });
      expect(billing.total_amount).toBe('120.00');
    });
  });

  describe('persistMortuaryBillableEventBilling', () => {
    it('posts via shared clinical-request-billing with MORTUARY source', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-mort-1',
        payment_status: 'PENDING',
      });

      const billing = buildMortuaryBillableEventBilling({
        eventType: 'STORAGE_FEE',
        amount: 50,
        currency: 'USD',
      });

      const snapshot = await persistMortuaryBillableEventBilling(
        {},
        {
          billableEventId: 'mbe-1',
          billing,
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          patientId: 'patient-1',
          actorUserId: 'user-1',
          eventType: 'STORAGE_FEE',
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
          sourceId: 'mbe-1',
          chargeKey: MORTUARY_CHARGE_KEYS.STORAGE,
          patientId: 'patient-1',
          tenantId: 'tenant-1',
        })
      );
    });

    it('idempotent replay: second call reuses same sourceId + chargeKey', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-mort-1',
        payment_status: 'PENDING',
      });

      const billing = buildMortuaryBillableEventBilling({
        eventType: 'VIEWING',
        amount: 40,
        currency: 'USD',
      });
      const args = {
        billableEventId: 'mbe-view-1',
        billing,
        tenantId: 'tenant-1',
        patientId: 'patient-1',
        eventType: 'VIEWING',
      };

      await persistMortuaryBillableEventBilling({}, args);
      await persistMortuaryBillableEventBilling({}, args);

      expect(applyClinicalRequestBilling).toHaveBeenCalledTimes(2);
      expect(applyClinicalRequestBilling.mock.calls[0][1].sourceId).toBe(
        'mbe-view-1'
      );
      expect(applyClinicalRequestBilling.mock.calls[1][1].sourceId).toBe(
        'mbe-view-1'
      );
      expect(applyClinicalRequestBilling.mock.calls[0][1].chargeKey).toBe(
        MORTUARY_CHARGE_KEYS.VIEWING
      );
      expect(applyClinicalRequestBilling.mock.calls[1][1].chargeKey).toBe(
        MORTUARY_CHARGE_KEYS.VIEWING
      );
    });

    it('does not post without patient / tenant (no bypass orphan)', async () => {
      const billing = buildMortuaryBillableEventBilling({
        eventType: 'RELEASE',
        amount: 25,
      });
      const snapshot = await persistMortuaryBillableEventBilling(
        {},
        {
          billableEventId: 'mbe-2',
          billing,
          tenantId: null,
          patientId: null,
        }
      );
      expect(snapshot).toBeNull();
      expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
    });
  });

  describe('applyMortuaryBillableEventBilling', () => {
    it('posts charge and mirrors invoice onto local event + case', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-mort-2',
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
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          mortuary_case_id: 'case-1',
          patient_id: 'patient-1',
          event_type: 'STORAGE_AND_RELEASE',
          amount: 120,
          currency: 'USD',
          description: 'Storage plus release',
        },
      });

      expect(snapshot).toEqual(
        expect.objectContaining({
          invoice_id: 'inv-mort-2',
          payment_status: 'PENDING',
        })
      );
      expect(tx.mortuary_billable_event.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'mbe-apply-1' },
          data: expect.objectContaining({
            status: 'PENDING',
            billing_reference_id: 'inv-mort-2',
          }),
        })
      );
      expect(tx.mortuary_case.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'case-1' },
          data: { billing_status: 'PENDING' },
        })
      );
      expect(applyClinicalRequestBilling).toHaveBeenCalledWith(
        tx,
        expect.objectContaining({
          sourceModule: BILLABLE_SOURCE_MODULES.MORTUARY,
          sourceId: 'mbe-apply-1',
        })
      );
    });

    it('audits NOT_REQUIRED for custody logistics (no Billing post)', async () => {
      const tx = {
        mortuary_billable_event: {
          update: jest.fn().mockResolvedValue({}),
        },
      };

      const snapshot = await applyMortuaryBillableEventBilling(tx, {
        billableEvent: {
          id: 'mbe-custody-1',
          tenant_id: 'tenant-1',
          patient_id: 'patient-1',
          event_type: 'CUSTODY_TRANSFER',
        },
      });

      expect(snapshot).toEqual(
        expect.objectContaining({
          payment_status: 'NOT_REQUIRED',
          skipped: true,
          reason: 'NOT_REQUIRED',
        })
      );
      expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
      expect(tx.mortuary_billable_event.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: 'NOT_REQUIRED' }),
        })
      );
    });

    it('unauthorized path: no write when tx delegates absent', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-x',
        payment_status: 'PENDING',
      });

      const snapshot = await applyMortuaryBillableEventBilling(
        {},
        {
          billableEvent: {
            id: 'mbe-3',
            tenant_id: 'tenant-1',
            patient_id: 'patient-1',
            event_type: 'EMBALMING',
            amount: 90,
          },
        }
      );

      expect(snapshot?.invoice_id).toBe('inv-x');
      expect(applyClinicalRequestBilling).toHaveBeenCalled();
    });
  });
});
