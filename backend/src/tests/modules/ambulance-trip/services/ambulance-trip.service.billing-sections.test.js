/**
 * Ambulance trip billing & sections coverage for Emergency Ambulance tab.
 *
 * Proves transport charges post through shared emergency-billing /
 * clinical-request-billing (no parallel ledger), idempotent replay on
 * complete, NOT_REQUIRED audit when no fee, and no charge on non-complete
 * status-only updates.
 */

jest.mock('@repositories/ambulance-trip/ambulance-trip.repository');
jest.mock('@lib/audit');
jest.mock('@prisma/client', () => ({
  $transaction: jest.fn((fn) => fn({})),
}));
jest.mock('@lib/billing/emergency-billing', () => ({
  buildAmbulanceTripBilling: jest.fn(),
  persistAmbulanceTripBilling: jest.fn(),
}));

const ambulanceTripRepository = require('@repositories/ambulance-trip/ambulance-trip.repository');
const { createAuditLog } = require('@lib/audit');
const prisma = require('@prisma/client');
const {
  buildAmbulanceTripBilling,
  persistAmbulanceTripBilling,
} = require('@lib/billing/emergency-billing');
const {
  createAmbulanceTrip,
  updateAmbulanceTrip,
} = require('@services/ambulance-trip/ambulance-trip.service');

const baseCase = {
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-1',
  facility: {
    id: 'facility-1',
    extension_json: {
      billing: { ambulance_trip_fee: 120, currency: 'USD' },
    },
  },
};

const pendingBilling = {
  payment_status: 'PENDING',
  total_amount: '120.00',
  currency: 'USD',
  line_items: [
    {
      id: 'ambulance-trip',
      label: 'Ambulance transport',
      quantity: 1,
      unit_price: '120.00',
      line_total: '120.00',
      catalog_type: 'SERVICE',
    },
  ],
};

describe('ambulance-trip.service billing-sections (Emergency Ambulance)', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    prisma.$transaction.mockImplementation(async (fn) => fn({}));
    createAuditLog.mockResolvedValue(undefined);
  });

  it('posts Billing on create when explicit billing payload is supplied', async () => {
    const trip = {
      id: 'trip-amb-1',
      ambulance_id: 'amb-1',
      emergency_case_id: 'case-1',
      emergency_case: baseCase,
      ended_at: null,
    };

    ambulanceTripRepository.findMany.mockResolvedValue([]);
    ambulanceTripRepository.create.mockResolvedValue(trip);
    buildAmbulanceTripBilling.mockReturnValue(pendingBilling);
    persistAmbulanceTripBilling.mockResolvedValue({
      invoice_id: 'inv-amb-1',
      payment_status: 'PENDING',
    });

    const result = await createAmbulanceTrip(
      {
        ambulance_id: 'amb-1',
        emergency_case_id: 'case-1',
        billing: pendingBilling,
      },
      { user_id: 'user-1', tenant_id: 'tenant-1' }
    );

    expect(persistAmbulanceTripBilling).toHaveBeenCalledWith(
      {},
      expect.objectContaining({
        tripId: 'trip-amb-1',
        tenantId: 'tenant-1',
        patientId: 'patient-1',
        billing: pendingBilling,
      })
    );
    expect(result.billing.payment_status).toBe('PENDING');
    expect(result.billing_deferred).toBe(true);
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'AMBULANCE_TRIP_BILLED' })
    );
  });

  it('does not invent Billing on start-only create (no ended_at / no payload)', async () => {
    const trip = {
      id: 'trip-amb-2',
      ambulance_id: 'amb-1',
      emergency_case_id: 'case-1',
      emergency_case: baseCase,
      ended_at: null,
    };
    ambulanceTripRepository.findMany.mockResolvedValue([]);
    ambulanceTripRepository.create.mockResolvedValue(trip);

    const result = await createAmbulanceTrip(
      { ambulance_id: 'amb-1', emergency_case_id: 'case-1' },
      { user_id: 'user-1' }
    );

    expect(persistAmbulanceTripBilling).not.toHaveBeenCalled();
    expect(buildAmbulanceTripBilling).not.toHaveBeenCalled();
    expect(result.billing).toBeNull();
    expect(result.billing_deferred).toBe(false);
  });

  it('audits NOT_REQUIRED on complete when no billable amount', async () => {
    const before = {
      id: 'trip-amb-skip',
      ambulance_id: 'amb-1',
      emergency_case_id: 'case-1',
      started_at: new Date('2026-07-30T08:00:00Z'),
      ended_at: null,
      emergency_case: { ...baseCase, facility: { extension_json: {} } },
    };
    const after = {
      ...before,
      ended_at: new Date('2026-07-30T09:00:00Z'),
    };
    ambulanceTripRepository.findById.mockResolvedValue(before);
    ambulanceTripRepository.findMany.mockResolvedValue([]);
    ambulanceTripRepository.update.mockResolvedValue(after);
    buildAmbulanceTripBilling.mockReturnValue(null);

    const result = await updateAmbulanceTrip(
      'trip-amb-skip',
      { ended_at: '2026-07-30T09:00:00Z' },
      { user_id: 'user-1' }
    );

    expect(persistAmbulanceTripBilling).not.toHaveBeenCalled();
    expect(result.billing).toBeNull();
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'AMBULANCE_TRIP_BILLING_SKIPPED',
        details: expect.objectContaining({ reason: 'NOT_REQUIRED' }),
      })
    );
  });

  it('idempotently posts Billing on trip complete', async () => {
    const before = {
      id: 'trip-amb-3',
      ambulance_id: 'amb-1',
      emergency_case_id: 'case-1',
      started_at: new Date('2026-07-30T08:00:00Z'),
      ended_at: null,
      emergency_case: baseCase,
    };
    const after = {
      ...before,
      ended_at: new Date('2026-07-30T09:00:00Z'),
    };

    ambulanceTripRepository.findById.mockResolvedValue(before);
    ambulanceTripRepository.findMany.mockResolvedValue([]);
    ambulanceTripRepository.update.mockResolvedValue(after);
    buildAmbulanceTripBilling.mockReturnValue(pendingBilling);
    persistAmbulanceTripBilling.mockResolvedValue({
      invoice_id: 'inv-amb-3',
      payment_status: 'PENDING',
    });

    const first = await updateAmbulanceTrip(
      'trip-amb-3',
      { ended_at: '2026-07-30T09:00:00Z' },
      { user_id: 'user-1' }
    );
    expect(persistAmbulanceTripBilling).toHaveBeenCalledTimes(1);
    expect(first.billing.invoice_id).toBe('inv-amb-3');

    ambulanceTripRepository.findById.mockResolvedValue(after);
    ambulanceTripRepository.update.mockResolvedValue(after);
    const second = await updateAmbulanceTrip(
      'trip-amb-3',
      { billing: pendingBilling },
      { user_id: 'user-1' }
    );
    expect(persistAmbulanceTripBilling).toHaveBeenCalledTimes(2);
    expect(second.billing.payment_status).toBe('PENDING');
  });

  it('does not invent Billing on non-complete status-only update', async () => {
    const before = {
      id: 'trip-amb-4',
      ambulance_id: 'amb-1',
      emergency_case_id: 'case-1',
      started_at: null,
      ended_at: null,
      emergency_case: baseCase,
    };
    const after = {
      ...before,
      started_at: new Date('2026-07-30T08:00:00Z'),
    };
    ambulanceTripRepository.findById.mockResolvedValue(before);
    ambulanceTripRepository.findMany.mockResolvedValue([]);
    ambulanceTripRepository.update.mockResolvedValue(after);

    await updateAmbulanceTrip(
      'trip-amb-4',
      { started_at: '2026-07-30T08:00:00Z' },
      {}
    );

    expect(persistAmbulanceTripBilling).not.toHaveBeenCalled();
    expect(buildAmbulanceTripBilling).not.toHaveBeenCalled();
  });

  it('strips module-private billing payload from trip row persist', async () => {
    ambulanceTripRepository.findMany.mockResolvedValue([]);
    ambulanceTripRepository.create.mockResolvedValue({
      id: 'trip-amb-5',
      ambulance_id: 'amb-1',
      emergency_case_id: 'case-1',
      emergency_case: baseCase,
      ended_at: null,
    });
    buildAmbulanceTripBilling.mockReturnValue(null);

    await createAmbulanceTrip(
      {
        ambulance_id: 'amb-1',
        emergency_case_id: 'case-1',
        billing: { payment_status: 'PENDING', total_amount: 50 },
      },
      {}
    );

    const createPayload = ambulanceTripRepository.create.mock.calls[0][0];
    expect(createPayload.billing).toBeUndefined();
  });
});
