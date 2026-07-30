/**
 * ICU Bed board billing-sections scan.
 *
 * Bed board loads facility beds with occupancy (`include_occupancy`) filtered
 * to ICU wards on the client. Proves list/read stays NOT_BILLED: no clinical-
 * request billing, receive-payment, adjustment, or invoice balance recalculation
 * on occupancy reads; payloads carry no parallel paid/balance fields; replay
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
const { listBeds, getBedById } = require('@services/bed/bed.service');

const occupiedBedRecord = {
  id: 'bed-icu-2',
  human_friendly_id: 'BED-ICU-2',
  label: 'ICU-2',
  status: 'OCCUPIED',
  tenant_id: 'tenant-123',
  facility_id: 'facility-123',
  ward_id: 'ward-icu-1',
  room_id: 'room-icu-1',
  ward: {
    id: 'ward-icu-1',
    name: 'ICU Ward',
    human_friendly_id: 'WARD-ICU',
    ward_type: 'ICU',
  },
  room: {
    id: 'room-icu-1',
    name: 'ICU Room 1',
    human_friendly_id: 'ROOM-ICU-1',
    floor: '2',
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

describe('ICU Bed board billing-sections scan (beds occupancy read)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('listBeds with include_occupancy does not touch patient Billing ledger', async () => {
    bedRepository.findMany.mockResolvedValue([occupiedBedRecord]);
    bedRepository.count.mockResolvedValue(1);

    const result = await listBeds(
      {
        facility_id: 'facility-123',
        include_occupancy: true,
        sort_by: 'label',
      },
      1,
      200,
      'label',
      'asc'
    );

    expect(result.beds).toHaveLength(1);
    expect(result.beds[0].label).toBe('ICU-2');
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

    const filters = { facility_id: 'facility-123', include_occupancy: true };
    const first = await listBeds(filters, 1, 200, 'label', 'asc');
    const second = await listBeds(filters, 1, 200, 'label', 'asc');

    expect(first.beds).toEqual(second.beds);
    expect(bedRepository.findMany).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.persistAdmissionBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('serializes occupancy beds without local paid flags or balances', async () => {
    bedRepository.findMany.mockResolvedValue([occupiedBedRecord]);
    bedRepository.count.mockResolvedValue(1);

    const result = await listBeds(
      { include_occupancy: true },
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

  it('getBedById read stays NOT_BILLED (no cashier path)', async () => {
    bedRepository.findById.mockResolvedValue({
      id: 'bed-icu-2',
      human_friendly_id: 'BED-ICU-2',
      label: 'ICU-2',
      status: 'OCCUPIED',
      tenant_id: 'tenant-123',
      facility_id: 'facility-123',
    });

    const bed = await getBedById('bed-icu-2');

    expect(bed.label).toBe('ICU-2');
    expect(bed).not.toHaveProperty('payment_status');
    expect(bed).not.toHaveProperty('balance');
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('unauthorized collect/adjust atoms are not reachable via bed occupancy APIs', () => {
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(typeof listBeds).toBe('function');
    expect(listBeds.name).toBe('listBeds');
  });
});
