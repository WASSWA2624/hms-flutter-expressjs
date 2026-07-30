jest.mock('@repositories/hr-workspace/hr-workspace.repository');
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
jest.mock('@lib/websocket', () => ({
  emitToUsers: jest.fn().mockResolvedValue(undefined),
  HR_EVENTS: {
    HR_WORKSPACE_UPDATED: 'hr.workspace_updated',
  },
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: jest.fn((...values) => values.find((value) => value) || null),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || undefined),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value || null),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  normalizeIdentifier: jest.fn((value) => value),
  resolveModelRecordByIdentifier: jest.fn(),
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
}));

const prisma = require('@prisma/client');
const repo = require('@repositories/hr-workspace/hr-workspace.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { createAuditLog } = require('@lib/audit');
const hrWorkspaceService = require('@services/hr-workspace/hr-workspace.service');

/**
 * Billing & sections scan for HR Leave requests tab.
 * Leave request/approve/reject are staff attendance ops and must never post
 * patient Billing ledger rows. UNPAID leave type is payroll metadata only.
 */
describe('hr-workspace Leave requests billing-sections scan', () => {
  const leaveRecord = {
    id: 'leave-uuid-1',
    human_friendly_id: 'LV-1001',
    leave_type: 'ANNUAL',
    status: 'REQUESTED',
    staff_profile_id: 'staff-uuid-1',
    staff_profile: {
      id: 'staff-uuid-1',
      human_friendly_id: 'STF-1001',
      tenant_id: 'tenant-1',
      staff_number: 'EMP-1',
      position: 'Nurse',
      user: {
        email: 'ada@example.com',
        profile: { first_name: 'Ada', last_name: 'Leave' },
      },
    },
    start_date: new Date('2026-07-10T00:00:00.000Z'),
    end_date: new Date('2026-07-12T00:00:00.000Z'),
    is_half_day: false,
    half_day_period: null,
    reason: 'Family',
    handover_notes: null,
    covering_staff_profile_id: null,
    covering_staff_profile: null,
    created_at: new Date('2026-07-01T08:00:00.000Z'),
    updated_at: new Date('2026-07-01T08:00:00.000Z'),
  };

  const unpaidLeaveRecord = {
    ...leaveRecord,
    id: 'leave-uuid-2',
    human_friendly_id: 'LV-1002',
    leave_type: 'UNPAID',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.staff_leave = {
      update: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
    };
    prisma.user = {
      findMany: jest.fn().mockResolvedValue([]),
    };
    repo.findManyLeaves.mockResolvedValue([leaveRecord]);
    repo.countStaffLeaves.mockResolvedValue(1);
  });

  const expectNoPatientBillingTouched = () => {
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  };

  it('LEAVE_REQUESTS worklist read does not touch patient billing ledger', async () => {
    const data = await hrWorkspaceService.getWorkItems(
      { queue: 'LEAVE_REQUESTS' },
      1,
      20,
      'updated_at',
      'desc'
    );

    expect(data.items).toHaveLength(1);
    expect(data.items[0].queue).toBe('LEAVE_REQUESTS');
    expect(data.items[0].leave_type).toBe('ANNUAL');
    expectNoPatientBillingTouched();
  });

  it('LEAVE_REQUESTS worklist GET is idempotent on replay (no double billing post)', async () => {
    const query = { queue: 'LEAVE_REQUESTS' };
    const first = await hrWorkspaceService.getWorkItems(query, 1, 20, 'updated_at', 'desc');
    const second = await hrWorkspaceService.getWorkItems(query, 1, 20, 'updated_at', 'desc');

    expect(first.items).toEqual(second.items);
    expect(repo.findManyLeaves).toHaveBeenCalledTimes(2);
    expectNoPatientBillingTouched();
  });

  it('serializes leave items without local paid flags or balances', async () => {
    const data = await hrWorkspaceService.getWorkItems(
      { queue: 'LEAVE_REQUESTS' },
      1,
      20,
      'updated_at',
      'desc'
    );
    const item = data.items[0];

    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount_due');
    expect(item).not.toHaveProperty('paid');
    expect(item).not.toHaveProperty('invoice_id');
    expect(item).not.toHaveProperty('amount');
  });

  it('UNPAID leave_type stays ops/payroll metadata (NOT_BILLED), not ledger balance', async () => {
    repo.findManyLeaves.mockResolvedValue([unpaidLeaveRecord]);
    const data = await hrWorkspaceService.getWorkItems(
      { queue: 'LEAVE_REQUESTS' },
      1,
      20,
      'updated_at',
      'desc'
    );

    expect(data.items[0].leave_type).toBe('UNPAID');
    expect(data.items[0].status).toBe('REQUESTED');
    expect(data.items[0]).not.toHaveProperty('amount');
    expectNoPatientBillingTouched();
  });

  it('approveLeave does not post Billing and replays without double charge', async () => {
    resolveModelRecordByIdentifier.mockResolvedValue(leaveRecord);
    prisma.staff_leave.update
      .mockResolvedValueOnce({ ...leaveRecord, status: 'APPROVED' })
      .mockResolvedValue({ ...leaveRecord, status: 'APPROVED' });

    const first = await hrWorkspaceService.approveLeave('LV-1001', { reason: 'ok' }, 'user-1', '127.0.0.1');
    const second = await hrWorkspaceService.approveLeave('LV-1001', { reason: 'ok' }, 'user-1', '127.0.0.1');

    expect(first.leave.status).toBe('APPROVED');
    expect(second.leave.status).toBe('APPROVED');
    expect(prisma.staff_leave.update).toHaveBeenCalledTimes(2);
    expect(createAuditLog).toHaveBeenCalled();
    expectNoPatientBillingTouched();
  });

  it('rejectLeave does not settle or adjust patient Billing', async () => {
    resolveModelRecordByIdentifier.mockResolvedValue(leaveRecord);
    prisma.staff_leave.update.mockResolvedValue({ ...leaveRecord, status: 'REJECTED' });

    const result = await hrWorkspaceService.rejectLeave(
      'LV-1001',
      { reason: 'coverage gap' },
      'user-1',
      '127.0.0.1'
    );

    expect(result.leave.status).toBe('REJECTED');
    expect(prisma.staff_leave.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: leaveRecord.id },
        data: { status: 'REJECTED' },
      })
    );
    expectNoPatientBillingTouched();
  });

  it('unauthorized actor without billing scopes still cannot settle via Leave handlers', async () => {
    resolveModelRecordByIdentifier.mockResolvedValue(leaveRecord);
    prisma.staff_leave.update.mockResolvedValue({ ...leaveRecord, status: 'APPROVED' });

    await hrWorkspaceService.approveLeave('LV-1001', {}, 'user-readonly', '127.0.0.1');

    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
