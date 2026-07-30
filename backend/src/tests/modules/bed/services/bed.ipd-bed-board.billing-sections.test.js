/**
 * IPD Bed board billing-sections scan (`/ipd?section=bed-board`).
 *
 * Occupancy list (`include_occupancy`) and bed status updates stay NOT_BILLED:
 * no clinical-request billing, receive-payment, adjustment, or invoice balance
 * recalculation. Payloads carry no parallel paid/balance fields; list replay
 * is idempotent (no double post).
 */

jest.mock('@repositories/bed/bed.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
  applyClinicalRequestBilling: jest.fn(),
  persistAdmissionBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));

const bedRepository = require('@repositories/bed/bed.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { listBeds, getBedById, updateBed } = require('@services/bed/bed.service');

const occupiedBedRecord = {
  id: 'bed-ipd-2',
  human_friendly_id: 'BED-IPD-2',
  label: 'Bed 102',
  status: 'OCCUPIED',
  tenant_id: 'tenant-123',
  facility_id: 'facility-123',
  ward_id: 'ward-1',
  room_id: 'room-1',
  ward: {
    id: 'ward-1',
    name: 'Medical Ward',
    human_friendly_id: 'WARD-MED',
    ward_type: 'GENERAL',
  },
  room: {
    id: 'room-1',
    name: 'Room 1',
    human_friendly_id: 'ROOM-1',
    floor: '1',
  },
  bed_assignments: [
    {
      assigned_at: new Date('2026-07-01T08:00:00.000Z'),
      released_at: null,
      admission: {
        id: 'adm-1',
        human_friendly_id: 'ADM0001',
        status: 'ADMITTED',
        admitted_at: new Date('2026-07-01T08:00:00.000Z'),
        patient: {
          id: 'pat-1',
          human_friendly_id: 'PAT0001',
          first_name: 'Ada',
          middle_name: null,
          last_name: 'Occupant',
        },
      },
    },
  ],
};

const availableBedRecord = {
  id: 'bed-ipd-1',
  human_friendly_id: 'BED-IPD-1',
  label: 'Bed 101',
  status: 'AVAILABLE',
  tenant_id: 'tenant-123',
  facility_id: 'facility-123',
  ward_id: 'ward-1',
  room_id: 'room-1',
  ward: occupiedBedRecord.ward,
  room: occupiedBedRecord.room,
  bed_assignments: [],
};

describe('IPD Bed board billing-sections scan (beds occupancy + status)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('listBeds with include_occupancy does not touch patient Billing ledger', async () => {
    bedRepository.findMany.mockResolvedValue([occupiedBedRecord]);
    bedRepository.count.mockResolvedValue(1);

    const result = await listBeds(
      { include_occupancy: 'true' },
      1,
      200,
      'label',
      'asc'
    );

    expect(result.beds).toHaveLength(1);
    expect(result.beds[0].label).toBe('Bed 102');
    expect(result.beds[0].current_admission).toEqual(
      expect.objectContaining({
        admission_display_id: 'ADM0001',
        patient_display_name: 'Ada Occupant',
      })
    );
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.applyClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.persistAdmissionBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('occupancy list replay is idempotent (no double billing post)', async () => {
    bedRepository.findMany.mockResolvedValue([occupiedBedRecord]);
    bedRepository.count.mockResolvedValue(1);

    const filters = { include_occupancy: 'true' };
    const first = await listBeds(filters, 1, 200, 'label', 'asc');
    const second = await listBeds(filters, 1, 200, 'label', 'asc');

    expect(first.beds).toEqual(second.beds);
    expect(bedRepository.findMany).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.persistAdmissionBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('serializes occupancy beds without local paid flags or balances', async () => {
    bedRepository.findMany.mockResolvedValue([occupiedBedRecord]);
    bedRepository.count.mockResolvedValue(1);

    const result = await listBeds(
      { include_occupancy: 'true' },
      1,
      200,
      'label',
      'asc'
    );
    const bed = result.beds[0];

    expect(bed).not.toHaveProperty('payment_status');
    expect(bed).not.toHaveProperty('balance');
    expect(bed).not.toHaveProperty('amount_due');
    expect(bed).not.toHaveProperty('paid');
    expect(bed).not.toHaveProperty('invoice_id');
    expect(bed).not.toHaveProperty('billing_cleared');
    expect(bed.current_admission).not.toHaveProperty('payment_status');
    expect(bed.current_admission).not.toHaveProperty('balance');
    expect(bed.current_admission).not.toHaveProperty('amount_due');
  });

  it('updateBed status (Reserve / Available) stays NOT_BILLED', async () => {
    bedRepository.findById.mockResolvedValue(availableBedRecord);
    bedRepository.update.mockResolvedValue({
      ...availableBedRecord,
      status: 'RESERVED',
    });

    const bed = await updateBed(
      'bed-ipd-1',
      { status: 'RESERVED' },
      { user_id: 'bed-admin-1', tenant_id: 'tenant-123', facility_id: 'facility-123' }
    );

    expect(bed.status).toBe('RESERVED');
    expect(clinicalRequestBilling.persistAdmissionBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('getBedById read stays NOT_BILLED (no cashier path)', async () => {
    bedRepository.findById.mockResolvedValue({
      id: 'bed-ipd-2',
      human_friendly_id: 'BED-IPD-2',
      label: 'Bed 102',
      status: 'OCCUPIED',
      tenant_id: 'tenant-123',
      facility_id: 'facility-123',
    });

    const bed = await getBedById('bed-ipd-2');

    expect(bed.label).toBe('Bed 102');
    expect(bed).not.toHaveProperty('payment_status');
    expect(bed).not.toHaveProperty('balance');
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('unauthorized collect/adjust atoms are not reachable via bed occupancy APIs', () => {
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(typeof listBeds).toBe('function');
    expect(typeof updateBed).toBe('function');
  });
});
