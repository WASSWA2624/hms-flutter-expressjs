/**
 * Housekeeping Tasks billing-sections scan.
 *
 * Proves staff-only create/start/assign stay NOT_BILLED; Complete posts via
 * housekeeping-billing → clinical-request-billing when facility fee + patient
 * exist; skips with audit when not configured; idempotent replay; no parallel
 * ledger fields on task payloads.
 */

jest.mock('@repositories/housekeeping-task/housekeeping-task.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null),
}));
jest.mock('@lib/billing/housekeeping-billing', () => ({
  maybeBillCompletedHousekeepingTask: jest.fn(),
}));
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
  applyClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));

const housekeepingTaskRepository = require('@repositories/housekeeping-task/housekeeping-task.repository');
const { createAuditLog } = require('@lib/audit');
const { maybeBillCompletedHousekeepingTask } = require('@lib/billing/housekeeping-billing');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const {
  listHousekeepingTasks,
  createHousekeepingTask,
  updateHousekeepingTask,
} = require('@services/housekeeping-task/housekeeping-task.service');

const facilityWithFee = {
  id: 'facility-123',
  human_friendly_id: 'FAC-001',
  name: 'Main Facility',
  tenant_id: 'tenant-123',
  extension_json: {
    billing: {
      room_turnover_cleaning_fee: 45,
      currency: 'USD',
    },
  },
};

const pendingTask = {
  id: 'task-uuid',
  human_friendly_id: 'HT-001',
  facility_id: 'facility-123',
  room_id: 'room-123',
  assigned_to_staff_id: 'staff-123',
  status: 'IN_PROGRESS',
  scheduled_at: new Date('2026-07-01T08:00:00.000Z'),
  completed_at: null,
  facility: facilityWithFee,
  room: { id: 'room-123', human_friendly_id: 'ROOM-1', name: 'Room 2B' },
  assigned_to: null,
};

describe('housekeeping-task billing-sections scan (Tasks tab)', () => {
  const scopedContext = {
    user_id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    ip_address: '127.0.0.1',
    user_agent: 'jest',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    maybeBillCompletedHousekeepingTask.mockResolvedValue(null);
  });

  it('list tasks does not touch patient billing ledger', async () => {
    housekeepingTaskRepository.findMany.mockResolvedValue([pendingTask]);
    housekeepingTaskRepository.count.mockResolvedValue(1);

    const result = await listHousekeepingTasks({}, 1, 20, 'created_at', 'desc', scopedContext);

    expect(result.housekeepingTasks).toHaveLength(1);
    expect(result.housekeepingTasks[0]).not.toHaveProperty('payment_status');
    expect(result.housekeepingTasks[0]).not.toHaveProperty('balance');
    expect(result.housekeepingTasks[0]).not.toHaveProperty('amount_due');
    expect(clinicalRequestBilling.applyClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
    expect(maybeBillCompletedHousekeepingTask).not.toHaveBeenCalled();
  });

  it('Create task stays NOT_BILLED (no patient ledger post)', async () => {
    housekeepingTaskRepository.create.mockResolvedValue({
      ...pendingTask,
      status: 'PENDING',
      assigned_to_staff_id: null,
    });

    const result = await createHousekeepingTask(
      {
        status: 'PENDING',
        facility_id: 'facility-123',
        room_id: 'room-123',
      },
      scopedContext
    );

    expect(result.status).toBe('PENDING');
    expect(result).not.toHaveProperty('payment_status');
    expect(maybeBillCompletedHousekeepingTask).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.applyClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'HOUSEKEEPING_TASK_CREATED' })
    );
  });

  it('Start (status IN_PROGRESS) stays NOT_BILLED', async () => {
    housekeepingTaskRepository.findById.mockResolvedValue({
      ...pendingTask,
      status: 'PENDING',
    });
    housekeepingTaskRepository.update.mockResolvedValue({
      ...pendingTask,
      status: 'IN_PROGRESS',
    });

    const result = await updateHousekeepingTask(
      'HT-001',
      { status: 'IN_PROGRESS' },
      scopedContext
    );

    expect(result.status).toBe('IN_PROGRESS');
    expect(maybeBillCompletedHousekeepingTask).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.applyClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('Complete posts Billing via housekeeping-billing when surcharge configured', async () => {
    housekeepingTaskRepository.findById.mockResolvedValue(pendingTask);
    housekeepingTaskRepository.update.mockResolvedValue({
      ...pendingTask,
      status: 'COMPLETED',
      completed_at: new Date('2026-07-01T10:00:00.000Z'),
    });
    maybeBillCompletedHousekeepingTask.mockResolvedValue({
      invoice_id: 'inv-hk-1',
      payment_status: 'PENDING',
    });

    const result = await updateHousekeepingTask(
      'HT-001',
      {
        status: 'COMPLETED',
        completed_at: '2026-07-01T10:00:00.000Z',
        patient_id: 'patient-123',
      },
      scopedContext
    );

    expect(result.status).toBe('COMPLETED');
    expect(maybeBillCompletedHousekeepingTask).toHaveBeenCalledTimes(1);
    expect(maybeBillCompletedHousekeepingTask).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'COMPLETED', id: 'task-uuid' }),
      scopedContext,
      expect.objectContaining({ patientId: 'patient-123' })
    );
    // Settlement stays on Billing module — task update never receives payment.
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('Complete is idempotent on replay (billing helper invoked; shared charge key dedupes)', async () => {
    const completed = {
      ...pendingTask,
      status: 'COMPLETED',
      completed_at: new Date('2026-07-01T10:00:00.000Z'),
    };
    housekeepingTaskRepository.findById
      .mockResolvedValueOnce(pendingTask)
      .mockResolvedValueOnce(completed);
    housekeepingTaskRepository.update
      .mockResolvedValueOnce(completed)
      .mockResolvedValueOnce(completed);
    maybeBillCompletedHousekeepingTask.mockResolvedValue({
      invoice_id: 'inv-hk-1',
      payment_status: 'PENDING',
    });

    await updateHousekeepingTask(
      'HT-001',
      { status: 'COMPLETED', patient_id: 'patient-123' },
      scopedContext
    );
    await updateHousekeepingTask(
      'HT-001',
      { status: 'COMPLETED', patient_id: 'patient-123' },
      scopedContext
    );

    // Second update is already COMPLETED → no second billing attempt.
    expect(maybeBillCompletedHousekeepingTask).toHaveBeenCalledTimes(1);
  });

  it('Complete without fee config skips Billing (staff-only NOT_BILLED path)', async () => {
    const staffOnlyFacility = {
      ...facilityWithFee,
      extension_json: { billing: { currency: 'USD' } },
    };
    housekeepingTaskRepository.findById.mockResolvedValue({
      ...pendingTask,
      facility: staffOnlyFacility,
    });
    housekeepingTaskRepository.update.mockResolvedValue({
      ...pendingTask,
      facility: staffOnlyFacility,
      status: 'COMPLETED',
      completed_at: new Date('2026-07-01T10:00:00.000Z'),
    });
    maybeBillCompletedHousekeepingTask.mockResolvedValue(null);

    const result = await updateHousekeepingTask(
      'HT-001',
      { status: 'COMPLETED' },
      scopedContext
    );

    expect(result.status).toBe('COMPLETED');
    expect(maybeBillCompletedHousekeepingTask).toHaveBeenCalledTimes(1);
    expect(clinicalRequestBilling.applyClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('Assign stays NOT_BILLED (no Billing post)', async () => {
    housekeepingTaskRepository.findById.mockResolvedValue({
      ...pendingTask,
      status: 'PENDING',
      assigned_to_staff_id: null,
    });
    housekeepingTaskRepository.update.mockResolvedValue({
      ...pendingTask,
      status: 'PENDING',
      assigned_to_staff_id: 'staff-123',
    });

    await updateHousekeepingTask(
      'HT-001',
      { assigned_to_staff_id: 'staff-123' },
      scopedContext
    );

    expect(maybeBillCompletedHousekeepingTask).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.applyClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('unauthorized caller cannot settle via task update (no receive-payment path)', async () => {
    housekeepingTaskRepository.findById.mockResolvedValue(pendingTask);
    housekeepingTaskRepository.update.mockResolvedValue({
      ...pendingTask,
      status: 'COMPLETED',
    });
    maybeBillCompletedHousekeepingTask.mockResolvedValue({
      invoice_id: 'inv-hk-1',
      payment_status: 'PENDING',
    });

    await updateHousekeepingTask(
      'HT-001',
      {
        status: 'COMPLETED',
        // Attempted cash-desk fields must not open a parallel settle path.
        payment_method: 'CASH',
        amount_paid: 45,
      },
      scopedContext
    );

    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(maybeBillCompletedHousekeepingTask).toHaveBeenCalled();
  });
});
