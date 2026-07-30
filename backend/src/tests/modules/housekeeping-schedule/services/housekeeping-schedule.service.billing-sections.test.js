/**
 * Housekeeping Schedules billing-sections scan
 *
 * Proves schedule CRUD stays NOT_BILLED (no patient ledger posts), replay is
 * idempotent with respect to Billing, and schedule payloads never carry
 * parallel paid/balance fields.
 *
 * @module tests/modules/housekeeping-schedule/services
 */

jest.mock('@repositories/housekeeping-schedule/housekeeping-schedule.repository');
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || undefined),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value || undefined),
  resolvePublicIdentifier: (...values) =>
    values.find((entry) => typeof entry === 'string' && entry.trim()) || null,
}));

const housekeepingScheduleRepository = require('@repositories/housekeeping-schedule/housekeeping-schedule.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { createAuditLog } = require('@lib/audit');
const {
  listHousekeepingSchedules,
  getHousekeepingScheduleById,
  createHousekeepingSchedule,
  updateHousekeepingSchedule,
  deleteHousekeepingSchedule,
} = require('@services/housekeeping-schedule/housekeeping-schedule.service');

describe('housekeeping Schedules billing-sections scan', () => {
  const context = {
    user_id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    ip_address: '127.0.0.1',
    user_agent: 'jest',
  };

  const scheduleRecord = {
    id: 'schedule-uuid',
    human_friendly_id: 'HS-001',
    facility_id: 'facility-123',
    room_id: 'room-123',
    frequency: 'Daily',
    start_date: new Date('2026-07-01T00:00:00.000Z'),
    end_date: null,
    facility: {
      id: 'facility-123',
      human_friendly_id: 'FAC-001',
      name: 'Main Campus',
    },
    room: {
      id: 'room-123',
      human_friendly_id: 'ROOM-001',
      name: 'Corridor A',
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  const expectNoPatientBilling = () => {
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  };

  const expectNoLocalPaidFields = (record) => {
    expect(record).not.toHaveProperty('payment_status');
    expect(record).not.toHaveProperty('balance');
    expect(record).not.toHaveProperty('amount_due');
    expect(record).not.toHaveProperty('paid');
    expect(record).not.toHaveProperty('invoice_id');
  };

  it('list Schedules does not touch patient billing ledger', async () => {
    housekeepingScheduleRepository.findMany.mockResolvedValue([scheduleRecord]);
    housekeepingScheduleRepository.count.mockResolvedValue(1);

    const result = await listHousekeepingSchedules({}, 1, 20, 'created_at', 'desc', context);

    expect(result.housekeepingSchedules).toHaveLength(1);
    expect(result.housekeepingSchedules[0].id).toBe('HS-001');
    expectNoLocalPaidFields(result.housekeepingSchedules[0]);
    expectNoPatientBilling();
  });

  it('list Schedules is idempotent on replay (no double billing post)', async () => {
    housekeepingScheduleRepository.findMany.mockResolvedValue([scheduleRecord]);
    housekeepingScheduleRepository.count.mockResolvedValue(1);

    const first = await listHousekeepingSchedules({}, 1, 20, 'created_at', 'desc', context);
    const second = await listHousekeepingSchedules({}, 1, 20, 'created_at', 'desc', context);

    expect(first.housekeepingSchedules).toEqual(second.housekeepingSchedules);
    expect(housekeepingScheduleRepository.findMany).toHaveBeenCalledTimes(2);
    expectNoPatientBilling();
  });

  it('get schedule by id stays NOT_BILLED', async () => {
    housekeepingScheduleRepository.findById.mockResolvedValue(scheduleRecord);

    const result = await getHousekeepingScheduleById('HS-001', context);

    expect(result.id).toBe('HS-001');
    expect(result.frequency).toBe('Daily');
    expectNoLocalPaidFields(result);
    expectNoPatientBilling();
  });

  it('Create schedule primary stays NOT_BILLED (no patient ledger post)', async () => {
    housekeepingScheduleRepository.create.mockResolvedValue(scheduleRecord);

    const result = await createHousekeepingSchedule(
      {
        facility_id: 'FAC-001',
        room_id: 'ROOM-001',
        frequency: 'Daily',
        start_date: '2026-07-01T00:00:00.000Z',
      },
      context
    );

    expect(result.id).toBe('HS-001');
    expect(result.frequency).toBe('Daily');
    expectNoLocalPaidFields(result);
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'HOUSEKEEPING_SCHEDULE_CREATED',
        entity: 'housekeeping_schedule',
      })
    );
    expectNoPatientBilling();
  });

  it('Create schedule replay stays idempotent w.r.t. Billing', async () => {
    housekeepingScheduleRepository.create.mockResolvedValue(scheduleRecord);

    const payload = {
      facility_id: 'FAC-001',
      room_id: 'ROOM-001',
      frequency: 'Weekly',
    };

    await createHousekeepingSchedule(payload, context);
    await createHousekeepingSchedule(payload, context);

    expect(housekeepingScheduleRepository.create).toHaveBeenCalledTimes(2);
    expectNoPatientBilling();
  });

  it('Update schedule stays NOT_BILLED', async () => {
    housekeepingScheduleRepository.findById.mockResolvedValue(scheduleRecord);
    housekeepingScheduleRepository.update.mockResolvedValue({
      ...scheduleRecord,
      frequency: 'Weekly',
    });

    const result = await updateHousekeepingSchedule(
      'HS-001',
      { frequency: 'Weekly' },
      context
    );

    expect(result.frequency).toBe('Weekly');
    expectNoLocalPaidFields(result);
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'HOUSEKEEPING_SCHEDULE_UPDATED',
      })
    );
    expectNoPatientBilling();
  });

  it('Delete schedule stays NOT_BILLED', async () => {
    housekeepingScheduleRepository.findById.mockResolvedValue(scheduleRecord);
    housekeepingScheduleRepository.softDelete.mockResolvedValue(scheduleRecord);

    await deleteHousekeepingSchedule('HS-001', context);

    expect(housekeepingScheduleRepository.softDelete).toHaveBeenCalled();
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'HOUSEKEEPING_SCHEDULE_DELETED',
      })
    );
    expectNoPatientBilling();
  });

  it('unauthorized context without billing permissions still cannot invent ledger posts', async () => {
    housekeepingScheduleRepository.create.mockResolvedValue(scheduleRecord);

    // Schedule service does not call Billing regardless of caller permissions;
    // patient collect/adjust remain owned by Billing module handlers.
    await createHousekeepingSchedule(
      { facility_id: 'FAC-001', frequency: 'Daily' },
      {
        user_id: 'reader-1',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
      }
    );

    expectNoPatientBilling();
  });
});
