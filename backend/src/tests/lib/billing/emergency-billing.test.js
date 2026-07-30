/**
 * Emergency billing helpers — deferred handoff / ambulance charges.
 *
 * @module tests/lib/billing/emergency-billing
 */

const {
  buildAmbulanceTripBilling,
  buildEmergencyAdmissionBilling,
  buildEmergencyTheatreBilling,
  persistAmbulanceTripBilling,
  AMBULANCE_TRIP_CHARGE_KEY,
  HANDOFF_ADMISSION_CHARGE_KEY,
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
  shouldApplyClinicalRequestBilling,
} = require('@lib/billing/clinical-request-billing');

describe('emergency-billing helpers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('buildAmbulanceTripBilling', () => {
    it('builds PENDING transport charge from facility fee', () => {
      const billing = buildAmbulanceTripBilling({
        facility: {
          extension_json: {
            billing: { ambulance_trip_fee: 150, currency: 'UGX' },
          },
        },
      });

      expect(billing).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          currency: 'UGX',
          total_amount: '150.00',
        })
      );
      expect(shouldApplyClinicalRequestBilling(billing)).toBe(true);
    });

    it('returns null when no fee resolves (NOT_REQUIRED path)', () => {
      expect(buildAmbulanceTripBilling({ facility: null })).toBeNull();
    });

    it('prefers explicit billing payload over facility defaults', () => {
      const billing = buildAmbulanceTripBilling({
        billing: {
          payment_status: 'PENDING',
          currency: 'USD',
          total_amount: '75.00',
          line_items: [
            {
              id: 'custom',
              label: 'Custom transport',
              quantity: 1,
              unit_price: '75.00',
              line_total: '75.00',
              catalog_type: 'SERVICE',
            },
          ],
        },
        facility: {
          extension_json: { billing: { ambulance_fee: 999 } },
        },
      });

      expect(billing.total_amount).toBe('75.00');
    });
  });

  describe('buildEmergencyAdmissionBilling', () => {
    it('builds deferred admission fee from facility settings', () => {
      const billing = buildEmergencyAdmissionBilling({
        facility: {
          extension_json: {
            billing: { admission_fee: '200.50', currency: 'USD' },
          },
        },
      });

      expect(billing).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          total_amount: '200.50',
        })
      );
      expect(HANDOFF_ADMISSION_CHARGE_KEY).toBe('EMERGENCY_HANDOFF_ADMISSION');
    });
  });

  describe('buildEmergencyTheatreBilling', () => {
    it('builds deferred theatre fee from facility settings', () => {
      const billing = buildEmergencyTheatreBilling({
        facility: {
          extension_json: { billing: { theatre_fee: 500 } },
        },
      });

      expect(billing).toEqual(
        expect.objectContaining({
          payment_status: 'PENDING',
          total_amount: '500.00',
        })
      );
    });
  });

  describe('persistAmbulanceTripBilling', () => {
    it('posts via shared clinical-request-billing with idempotent charge key', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-1',
        payment_status: 'PENDING',
      });

      const tx = {};
      const billing = buildAmbulanceTripBilling({
        billing: {
          payment_status: 'PENDING',
          currency: 'USD',
          total_amount: '100.00',
          line_items: [
            {
              id: 'ambulance-trip',
              label: 'Ambulance transport',
              quantity: 1,
              unit_price: '100.00',
              line_total: '100.00',
              catalog_type: 'SERVICE',
            },
          ],
        },
      });

      const snapshot = await persistAmbulanceTripBilling(tx, {
        tripId: 'trip-1',
        billing,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-1',
        actorUserId: 'user-1',
      });

      expect(snapshot).toEqual(
        expect.objectContaining({
          invoice_id: 'inv-1',
          payment_status: 'PENDING',
        })
      );
      expect(applyClinicalRequestBilling).toHaveBeenCalledWith(
        tx,
        expect.objectContaining({
          sourceId: 'trip-1',
          chargeKey: AMBULANCE_TRIP_CHARGE_KEY,
          patientId: 'patient-1',
          tenantId: 'tenant-1',
        })
      );
    });

    it('idempotent replay: second call still uses same charge key (no fork)', async () => {
      applyClinicalRequestBilling.mockResolvedValue({
        invoice_id: 'inv-1',
        payment_status: 'PENDING',
      });

      const billing = buildAmbulanceTripBilling({
        billing: {
          payment_status: 'PENDING',
          currency: 'USD',
          total_amount: '100.00',
          line_items: [
            {
              id: 'ambulance-trip',
              label: 'Ambulance transport',
              quantity: 1,
              unit_price: '100.00',
              line_total: '100.00',
              catalog_type: 'SERVICE',
            },
          ],
        },
      });

      const tx = {};
      await persistAmbulanceTripBilling(tx, {
        tripId: 'trip-1',
        billing,
        tenantId: 'tenant-1',
        patientId: 'patient-1',
      });
      await persistAmbulanceTripBilling(tx, {
        tripId: 'trip-1',
        billing,
        tenantId: 'tenant-1',
        patientId: 'patient-1',
      });

      expect(applyClinicalRequestBilling).toHaveBeenCalledTimes(2);
      expect(applyClinicalRequestBilling.mock.calls[0][1].chargeKey).toBe(
        AMBULANCE_TRIP_CHARGE_KEY
      );
      expect(applyClinicalRequestBilling.mock.calls[1][1].chargeKey).toBe(
        AMBULANCE_TRIP_CHARGE_KEY
      );
    });

    it('skips when required ids missing (no orphan invoice)', async () => {
      const result = await persistAmbulanceTripBilling({}, {
        tripId: null,
        billing: { payment_status: 'PENDING', total_amount: '10.00' },
        tenantId: 'tenant-1',
        patientId: 'patient-1',
      });
      expect(result).toBeNull();
      expect(applyClinicalRequestBilling).not.toHaveBeenCalled();
    });
  });
});
