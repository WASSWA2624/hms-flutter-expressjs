/**
 * Emergency deferred billing helpers (Critical acuity tab).
 *
 * Critical filters open high-acuity cases; deferred ambulance / handoff
 * charges must still post PENDING Billing records through shared helpers
 * (no pay-now bypass, idempotent trip keys).
 *
 * @module tests/lib/billing/emergency-billing.critical
 */

const {
  buildAmbulanceTripBilling,
  buildEmergencyAdmissionBilling,
  buildEmergencyTheatreBilling,
  persistAmbulanceTripBilling,
  persistEmergencyCaseServiceBilling,
  resolveDeferredEmergencyBilling,
  AMBULANCE_TRIP_CHARGE_KEY,
  HANDOFF_ADMISSION_CHARGE_KEY,
  HANDOFF_THEATRE_CHARGE_KEY,
} = require('@lib/billing/emergency-billing');

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

describe('emergency-billing (Critical tab)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('resolveDeferredEmergencyBilling', () => {
    it('builds PENDING payload from amount (create-charge / defer)', () => {
      const billing = resolveDeferredEmergencyBilling(null, {
        id: 'ambulance-trip',
        label: 'Ambulance transport',
        amount: '175.00',
        currency: 'UGX',
      });

      expect(billing).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          total_amount: '175.00',
          currency: 'UGX',
        })
      );
      expect(shouldApplyClinicalRequestBilling(billing)).toBe(true);
    });

    it('returns null when amount is missing (NOT_REQUIRED)', () => {
      expect(resolveDeferredEmergencyBilling(null, { label: 'x' })).toBeNull();
      expect(buildAmbulanceTripBilling({})).toBeNull();
    });

    it('normalizes caller PAID status to PENDING (no pay-now bypass)', () => {
      const billing = resolveDeferredEmergencyBilling({
        payment_status: 'PAID',
        currency: 'USD',
        total_amount: '90.00',
        line_items: [
          {
            id: 'ambulance-trip',
            label: 'Ambulance transport',
            quantity: 1,
            unit_price: '90.00',
            line_total: '90.00',
          },
        ],
      });

      expect(billing.payment_status).toBe('PENDING');
      expect(billing.total_amount).toBe('90.00');
    });
  });

  describe('facility fee resolution for critical handoff / trip', () => {
    it('builds ambulance trip billing from facility extension', () => {
      const billing = buildAmbulanceTripBilling({
        facility: {
          extension_json: {
            billing: { ambulance_trip_fee: '220.00', currency: 'USD' },
          },
        },
      });

      expect(billing).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          total_amount: '220.00',
          currency: 'USD',
        })
      );
    });

    it('builds admission / theatre deferred fees from facility', () => {
      expect(
        buildEmergencyAdmissionBilling({
          facility: {
            extension_json: { billing: { admission_fee: '500.00' } },
          },
        })
      ).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          total_amount: '500.00',
        })
      );

      expect(
        buildEmergencyTheatreBilling({
          facility: {
            extension_json: { billing: { theatre_fee: '900.00' } },
          },
        })
      ).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          total_amount: '900.00',
        })
      );
    });
  });

  describe('persistAmbulanceTripBilling (Critical trip complete)', () => {
    it('posts SERVICE charge with stable trip source id (no bypass)', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-crit-1',
        payment_status: 'PENDING',
      });

      const billing = buildAmbulanceTripBilling({
        billing: {
          payment_status: 'PENDING',
          currency: 'USD',
          line_items: [
            {
              id: 'ambulance-trip',
              label: 'Ambulance transport',
              quantity: 1,
              unit_price: '120.00',
              line_total: '120.00',
            },
          ],
          total_amount: '120.00',
        },
      });

      const snapshot = await persistAmbulanceTripBilling(
        {},
        {
          tripId: 'trip-crit-uuid-1',
          billing,
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          patientId: 'patient-1',
          actorUserId: 'user-1',
        }
      );

      expect(snapshot).toEqual(
        expect.objectContaining({
          invoice_id: 'inv-crit-1',
          payment_status: 'PENDING',
        })
      );
      expect(applyClinicalRequestBilling).toHaveBeenCalledWith(
        {},
        expect.objectContaining({
          sourceModule: BILLABLE_SOURCE_MODULES.SERVICE,
          sourceId: 'trip-crit-uuid-1',
          chargeKey: AMBULANCE_TRIP_CHARGE_KEY,
          tenantId: 'tenant-1',
          patientId: 'patient-1',
          billing: expect.objectContaining({ payment_status: 'PENDING' }),
        })
      );
    });

    it('skips when billing payload is not chargeable', async () => {
      const snapshot = await persistAmbulanceTripBilling(
        {},
        {
          tripId: 'trip-1',
          billing: null,
          tenantId: 'tenant-1',
          patientId: 'patient-1',
        }
      );
      expect(snapshot).toBeNull();
      expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
    });

    it('idempotent replay reuses source id + charge key', async () => {
      applyClinicalRequestBilling
        .mockResolvedValueOnce({
          invoice_id: 'inv-crit-replay',
          payment_status: 'PENDING',
        })
        .mockResolvedValueOnce({
          invoice_id: 'inv-crit-replay',
          payment_status: 'PENDING',
        });

      const billing = buildAmbulanceTripBilling({
        billing: {
          payment_status: 'PENDING',
          currency: 'USD',
          line_items: [
            {
              id: 'ambulance-trip',
              label: 'Ambulance transport',
              quantity: 1,
              unit_price: '50.00',
              line_total: '50.00',
            },
          ],
          total_amount: '50.00',
        },
      });
      const args = {
        tripId: 'trip-crit-replay',
        billing,
        tenantId: 'tenant-1',
        patientId: 'patient-1',
      };

      const first = await persistAmbulanceTripBilling({}, args);
      const second = await persistAmbulanceTripBilling({}, args);

      expect(first.invoice_id).toBe(second.invoice_id);
      expect(applyClinicalRequestBilling).toHaveBeenCalledTimes(2);
      expect(applyClinicalRequestBilling.mock.calls[0][1].sourceId).toBe(
        applyClinicalRequestBilling.mock.calls[1][1].sourceId
      );
      expect(applyClinicalRequestBilling.mock.calls[0][1].chargeKey).toBe(
        AMBULANCE_TRIP_CHARGE_KEY
      );
    });
  });

  describe('persistEmergencyCaseServiceBilling (Critical handoff fallback)', () => {
    it('posts deferred admission charge keyed by case + charge key', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-adm-crit',
        payment_status: 'PENDING',
      });

      const billing = buildEmergencyAdmissionBilling({
        facility: {
          extension_json: { billing: { admission_fee: '500.00' } },
        },
      });

      const snapshot = await persistEmergencyCaseServiceBilling(
        {},
        {
          emergencyCaseId: 'eme-crit-1',
          chargeKey: HANDOFF_ADMISSION_CHARGE_KEY,
          billing,
          tenantId: 'tenant-1',
          patientId: 'patient-1',
          description: 'Emergency admission fee',
        }
      );

      expect(snapshot).toEqual(
        expect.objectContaining({
          invoice_id: 'inv-adm-crit',
          payment_status: 'PENDING',
        })
      );
      expect(applyClinicalRequestBilling).toHaveBeenCalledWith(
        {},
        expect.objectContaining({
          sourceModule: BILLABLE_SOURCE_MODULES.SERVICE,
          sourceId: 'eme-crit-1',
          chargeKey: HANDOFF_ADMISSION_CHARGE_KEY,
        })
      );
    });

    it('posts deferred theatre charge with theatre charge key', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-thr-crit',
        payment_status: 'PENDING',
      });

      const billing = buildEmergencyTheatreBilling({
        facility: {
          extension_json: { billing: { theatre_fee: '900.00' } },
        },
      });

      await persistEmergencyCaseServiceBilling(
        {},
        {
          emergencyCaseId: 'eme-crit-2',
          chargeKey: HANDOFF_THEATRE_CHARGE_KEY,
          billing,
          tenantId: 'tenant-1',
          patientId: 'patient-1',
        }
      );

      expect(applyClinicalRequestBilling).toHaveBeenCalledWith(
        {},
        expect.objectContaining({
          chargeKey: HANDOFF_THEATRE_CHARGE_KEY,
          sourceId: 'eme-crit-2',
        })
      );
    });
  });
});
