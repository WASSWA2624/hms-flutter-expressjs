jest.mock('@repositories/hr-workspace/hr-workspace.repository');
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: jest.fn((...values) => values.find((value) => value) || null),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || undefined),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value || null),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  normalizeIdentifier: jest.fn((value) => value),
  resolveModelRecordByIdentifier: jest.fn(),
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));
jest.mock('@lib/websocket', () => ({
  emitToUsers: jest.fn(),
  HR_EVENTS: {
    WORKSPACE_UPDATED: 'hr.workspace.updated',
  },
}));
jest.mock('@services/hr-workspace/hr-roster-engine', () => ({
  buildWorkflow: jest.fn(),
  generateRosterAssignments: jest.fn(),
  resolveRecordOrThrow: jest.fn(),
  resolveDisplayId: jest.fn((item = {}) => item.human_friendly_id || item.id || null),
}));
jest.mock('@services/hr-workspace/payroll-calculation', () => ({
  calculateCompensationAmount: jest.fn(),
  computeEligibleWorkdays: jest.fn(),
  normalizeMoney: jest.fn((value) => value),
  sumCompensationAmounts: jest.fn(),
}));
jest.mock('@services/hr-workspace/hr-payroll-activity', () => ({
  loadStaffPayrollActivity: jest.fn(),
}));

const prisma = require('@prisma/client');
const repo = require('@repositories/hr-workspace/hr-workspace.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { resolveIdentifierForPayload } = require('@lib/billing/identifiers');
const {
  buildWorkflow,
  generateRosterAssignments,
  resolveRecordOrThrow,
} = require('@services/hr-workspace/hr-roster-engine');
const hrWorkspaceService = require('@services/hr-workspace/hr-workspace.service');

/**
 * Billing & sections scan for HR Shifts tab (`/hr?section=shifts`).
 * Roster drafts, unassigned/overdue shifts, swap approve/reject, publish, and
 * override are staff scheduling ops and must never post patient Billing rows.
 * Staff payroll compensation stays on the Payroll drafts path (not mounted).
 */
describe('hr-workspace Shifts billing-sections scan', () => {
  const scopedUser = {
    id: '123e4567-e89b-12d3-a456-426614174099',
    tenant_id: '123e4567-e89b-12d3-a456-426614174010',
    facility_id: '123e4567-e89b-12d3-a456-426614174011',
    permissions: ['hr:read', 'hr:write', 'roster:write', 'roster:publish', 'roster:approve'],
    roles: ['HR'],
  };

  const rosterRecord = {
    id: 'roster-uuid',
    human_friendly_id: 'RST-1001',
    tenant_id: scopedUser.tenant_id,
    facility_id: scopedUser.facility_id,
    status: 'DRAFT',
    published_at: null,
    period_start: new Date('2026-07-01T00:00:00.000Z'),
    period_end: new Date('2026-07-07T00:00:00.000Z'),
    facility: { id: scopedUser.facility_id, human_friendly_id: 'FAC-1' },
    department: null,
    updated_at: new Date('2026-07-01T08:00:00.000Z'),
    created_at: new Date('2026-07-01T08:00:00.000Z'),
  };

  const shiftRecord = {
    id: 'shift-uuid',
    human_friendly_id: 'SHF-1001',
    tenant_id: scopedUser.tenant_id,
    facility_id: scopedUser.facility_id,
    shift_type: 'DAY',
    status: 'SCHEDULED',
    start_time: new Date('2026-07-02T08:00:00.000Z'),
    end_time: new Date('2026-07-02T17:00:00.000Z'),
    nurse_roster_id: 'roster-uuid',
    nurse_roster: { id: 'roster-uuid', human_friendly_id: 'RST-1001' },
    facility: { id: scopedUser.facility_id, human_friendly_id: 'FAC-1' },
    shift_template: null,
    assignments: [],
    updated_at: new Date('2026-07-01T08:00:00.000Z'),
    created_at: new Date('2026-07-01T08:00:00.000Z'),
  };

  const swapRecord = {
    id: 'swap-uuid',
    human_friendly_id: 'SWP-1001',
    status: 'SCHEDULED',
    shift_id: 'shift-uuid',
    requester_staff_id: 'staff-a',
    target_staff_id: 'staff-b',
    shift: {
      tenant_id: scopedUser.tenant_id,
      facility_id: scopedUser.facility_id,
      human_friendly_id: 'SHF-1001',
    },
    requester: { human_friendly_id: 'STF-A', staff_number: 'A-1' },
    target: { human_friendly_id: 'STF-B', staff_number: 'B-1' },
    updated_at: new Date('2026-07-01T08:00:00.000Z'),
    created_at: new Date('2026-07-01T08:00:00.000Z'),
  };

  const expectNoPatientBillingTouch = () => {
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  };

  beforeEach(() => {
    jest.clearAllMocks();

    prisma.user_role = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.nurse_roster = {
      update: jest.fn().mockResolvedValue({
        ...rosterRecord,
        status: 'PUBLISHED',
        published_at: new Date('2026-07-01T09:00:00.000Z'),
      }),
    };
    prisma.shift = {
      findUnique: jest.fn().mockResolvedValue(shiftRecord),
    };
    prisma.shift_assignment = {
      updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      findFirst: jest.fn().mockResolvedValue({
        id: 'assignment-uuid',
        shift_id: 'shift-uuid',
        staff_profile_id: 'staff-a',
      }),
      create: jest.fn(),
      update: jest.fn(),
    };
    prisma.shift_swap_request = {
      update: jest.fn().mockResolvedValue({
        ...swapRecord,
        status: 'COMPLETED',
      }),
    };
    prisma.$transaction = jest.fn(async (callback) =>
      callback({
        shift_assignment: prisma.shift_assignment,
        shift_swap_request: prisma.shift_swap_request,
      })
    );

    repo.findManyRosters.mockResolvedValue([rosterRecord]);
    repo.countRosters.mockResolvedValue(1);
    repo.findManyUnassignedShifts.mockResolvedValue([shiftRecord]);
    repo.countShifts.mockResolvedValue(1);
    repo.findManyOverdueShifts.mockResolvedValue([]);
    repo.findManyShiftSwaps.mockResolvedValue([swapRecord]);
    repo.countShiftSwaps.mockResolvedValue(1);
    repo.findManyLeaves.mockResolvedValue([]);
    repo.countStaffLeaves.mockResolvedValue(0);
    repo.findManyPayrollRuns.mockResolvedValue([]);
    repo.countPayrollRuns.mockResolvedValue(0);

    buildWorkflow.mockResolvedValue({
      gaps: [],
      coverage: { percent: 100 },
    });
    generateRosterAssignments.mockResolvedValue({
      dry_run: true,
      assignment_count: 12,
      coverage_percent: 90,
      gap_count: 1,
    });
    resolveRecordOrThrow.mockResolvedValue(shiftRecord);
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'nurse_roster') return rosterRecord;
      if (model === 'shift_swap_request') return swapRecord;
      return null;
    });
    resolveIdentifierForPayload.mockImplementation(async ({ value }) => value);
  });

  it('ROSTER_DRAFTS worklist read does not touch patient billing ledger', async () => {
    const data = await hrWorkspaceService.getWorkItems(
      { queue: 'ROSTER_DRAFTS' },
      1,
      20
    );

    expect(data.queue).toBe('ROSTER_DRAFTS');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].id).toBe('RST-1001');
    expect(data.items[0]).not.toHaveProperty('payment_status');
    expect(data.items[0]).not.toHaveProperty('balance');
    expect(data.items[0]).not.toHaveProperty('amount_due');
    expect(data.items[0]).not.toHaveProperty('invoice_id');
    expectNoPatientBillingTouch();
  });

  it('UNASSIGNED_SHIFTS worklist read does not touch patient billing ledger', async () => {
    const data = await hrWorkspaceService.getWorkItems(
      { queue: 'UNASSIGNED_SHIFTS' },
      1,
      20
    );

    expect(data.queue).toBe('UNASSIGNED_SHIFTS');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].id).toBe('SHF-1001');
    expect(data.items[0]).not.toHaveProperty('paid');
    expect(data.items[0]).not.toHaveProperty('amount');
    expectNoPatientBillingTouch();
  });

  it('SWAP_REQUESTS worklist is idempotent on replay (no double billing post)', async () => {
    const query = { queue: 'SWAP_REQUESTS' };
    const first = await hrWorkspaceService.getWorkItems(query, 1, 20);
    const second = await hrWorkspaceService.getWorkItems(query, 1, 20);

    expect(first.items).toEqual(second.items);
    expect(repo.findManyShiftSwaps).toHaveBeenCalledTimes(2);
    expectNoPatientBillingTouch();
  });

  it('publishRoster does not post or settle patient Billing', async () => {
    const result = await hrWorkspaceService.publishRoster(
      'RST-1001',
      { notify_staff: false, allow_partial_publish: false },
      scopedUser.id,
      '127.0.0.1'
    );

    expect(result).toEqual(
      expect.objectContaining({
        published_roster: expect.objectContaining({ status: 'PUBLISHED' }),
      })
    );
    expect(prisma.nurse_roster.update).toHaveBeenCalled();
    expectNoPatientBillingTouch();
  });

  it('publishRoster replay does not double-post Billing', async () => {
    await hrWorkspaceService.publishRoster('RST-1001', {}, scopedUser.id, '127.0.0.1');
    await hrWorkspaceService.publishRoster('RST-1001', {}, scopedUser.id, '127.0.0.1');

    expect(prisma.nurse_roster.update).toHaveBeenCalledTimes(2);
    expectNoPatientBillingTouch();
  });

  it('overrideShiftAssignment does not create patient ledger rows', async () => {
    prisma.$transaction.mockImplementation(async (callback) =>
      callback({
        shift_assignment: {
          updateMany: jest.fn().mockResolvedValue({ count: 0 }),
          create: jest.fn().mockResolvedValue({
            id: 'assignment-new',
            shift: shiftRecord,
            staff_profile: {
              id: 'staff-b',
              human_friendly_id: 'STF-B',
              staff_number: 'B-1',
            },
          }),
        },
      })
    );

    const result = await hrWorkspaceService.overrideShiftAssignment(
      'SHF-1001',
      { staff_profile_id: 'staff-b', reason: 'Coverage gap' },
      scopedUser.id,
      '127.0.0.1'
    );

    expect(result).toEqual(
      expect.objectContaining({
        assignment: expect.anything(),
      })
    );
    expectNoPatientBillingTouch();
  });

  it('approveSwap does not settle or adjust patient Billing', async () => {
    prisma.$transaction.mockImplementation(async (callback) =>
      callback({
        shift_swap_request: {
          update: jest.fn().mockResolvedValue({ ...swapRecord, status: 'COMPLETED' }),
        },
        shift_assignment: {
          findFirst: jest.fn().mockResolvedValue({
            id: 'assignment-uuid',
            shift_id: 'shift-uuid',
            staff_profile_id: 'staff-a',
          }),
          update: jest.fn().mockResolvedValue({ id: 'assignment-uuid' }),
          create: jest.fn(),
        },
      })
    );

    const result = await hrWorkspaceService.approveSwap(
      'SWP-1001',
      { reason: 'Approved' },
      scopedUser.id,
      '127.0.0.1'
    );

    expect(result).toEqual(
      expect.objectContaining({
        swap: expect.objectContaining({ status: 'COMPLETED' }),
      })
    );
    expectNoPatientBillingTouch();
  });

  it('rejectSwap does not reverse or write off patient Billing', async () => {
    resolveModelRecordByIdentifier.mockResolvedValueOnce(swapRecord);
    prisma.shift_swap_request.update.mockResolvedValue({
      ...swapRecord,
      status: 'CANCELLED',
    });

    const result = await hrWorkspaceService.rejectSwap(
      'SWP-1001',
      { reason: 'Conflict' },
      scopedUser.id,
      '127.0.0.1'
    );

    expect(result).toEqual(
      expect.objectContaining({
        swap: expect.objectContaining({ status: 'CANCELLED' }),
      })
    );
    expectNoPatientBillingTouch();
  });

  it('generateRosterAssignments dry-run stays NOT_BILLED ops telemetry', async () => {
    const result = await hrWorkspaceService.generateRosterAssignments({
      rosterIdentifier: 'RST-1001',
      dryRun: true,
      userId: scopedUser.id,
      ipAddress: '127.0.0.1',
    });

    expect(result).toEqual(
      expect.objectContaining({
        dry_run: true,
        assignment_count: 12,
      })
    );
    expect(generateRosterAssignments).toHaveBeenCalled();
    expectNoPatientBillingTouch();
  });

  it('status parity: roster/shift status remains ops telemetry, not ledger balance', async () => {
    const data = await hrWorkspaceService.getWorkItems(
      { queue: 'ROSTER_DRAFTS' },
      1,
      20
    );

    expect(data.items[0].status).toBe('DRAFT');
    expect(data.items[0]).not.toHaveProperty('payment_status');
    expectNoPatientBillingTouch();
  });

  it('unauthorized actor without billing scopes still cannot settle via Shifts handlers', async () => {
    await hrWorkspaceService.getWorkItems({ queue: 'ROSTER_DRAFTS' }, 1, 20);
    await hrWorkspaceService.publishRoster(
      'RST-1001',
      {},
      'user-no-billing',
      '127.0.0.1'
    );

    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
