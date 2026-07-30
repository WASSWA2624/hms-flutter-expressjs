jest.mock('@repositories/hr-workspace/hr-workspace.repository');
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
  persistClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));
jest.mock('@services/billing/billing.service', () => ({
  receivePayment: jest.fn(),
  requestAdjustment: jest.fn(),
  reconcilePayment: jest.fn(),
  createInvoice: jest.fn(),
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
const billingService = require('@services/billing/billing.service');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { createAuditLog } = require('@lib/audit');
const hrWorkspaceService = require('@services/hr-workspace/hr-workspace.service');
const staffProfileService = require('@services/staff-profile/staff-profile.service');

jest.mock('@repositories/staff-profile/staff-profile.repository');
const staffProfileRepository = require('@repositories/staff-profile/staff-profile.repository');

/**
 * Billing & sections scan for HR Human resources (staff directory) tab.
 * Staff directory, compensation, consultation-fee catalog, payroll wizard,
 * and offboard+final-payroll are staff ops / payroll SoR — never patient
 * Billing ledger posts.
 */
describe('hr-workspace Human resources (staff) billing-sections scan', () => {
  const staffRecord = {
    id: 'staff-uuid-1',
    human_friendly_id: 'STF-1001',
    staff_number: 'EMP-1',
    tenant_id: 'tenant-1',
    user_id: 'user-1',
  };

  const expectNoPatientBillingTouched = () => {
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.persistClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
    expect(billingService.receivePayment).not.toHaveBeenCalled();
    expect(billingService.createInvoice).not.toHaveBeenCalled();
    expect(billingService.requestAdjustment).not.toHaveBeenCalled();
    expect(billingService.reconcilePayment).not.toHaveBeenCalled();
  };

  const stubWorkspaceRepo = () => {
    repo.countStaffProfiles.mockResolvedValue(1);
    repo.countStaffLeaves.mockResolvedValue(0);
    repo.countShiftSwaps.mockResolvedValue(0);
    repo.countRosters.mockResolvedValue(0);
    repo.countPayrollRuns.mockResolvedValue(0);
    repo.countShifts.mockResolvedValue(0);
    repo.findTimelineLeaves.mockResolvedValue([]);
    repo.findTimelineSwaps.mockResolvedValue([]);
    repo.findTimelineRosters.mockResolvedValue([]);
    repo.findTimelinePayrollRuns.mockResolvedValue([]);
    repo.findTimelineShifts.mockResolvedValue([]);
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    stubWorkspaceRepo();
    prisma.user = {
      findMany: jest.fn().mockResolvedValue([]),
      findFirst: jest.fn().mockResolvedValue({
        id: staffRecord.user_id,
        tenant_id: staffRecord.tenant_id,
        deleted_at: null,
      }),
      update: jest.fn().mockResolvedValue({}),
    };
    prisma.user_role = {
      findMany: jest.fn().mockResolvedValue([]),
    };
    prisma.staff_assignment = {
      updateMany: jest.fn().mockResolvedValue({ count: 0 }),
    };
    prisma.shift_assignment = {
      updateMany: jest.fn().mockResolvedValue({ count: 0 }),
    };
    prisma.staff_leave = {
      updateMany: jest.fn().mockResolvedValue({ count: 0 }),
    };
    prisma.staff_profile = {
      update: jest.fn().mockResolvedValue(staffRecord),
      findMany: jest.fn().mockResolvedValue([]),
    };
    prisma.payroll_run = {
      create: jest.fn().mockResolvedValue({
        id: 'payroll-uuid-1',
        human_friendly_id: 'PAY-1001',
        tenant_id: 'tenant-1',
        status: 'DRAFT',
      }),
      update: jest.fn(),
      findMany: jest.fn().mockResolvedValue([]),
    };
    prisma.payroll_item = {
      updateMany: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
    };
    prisma.$transaction = jest.fn(async (callback) =>
      callback({
        staff_assignment: prisma.staff_assignment,
        shift_assignment: prisma.shift_assignment,
        staff_leave: prisma.staff_leave,
        user: prisma.user,
        staff_profile: prisma.staff_profile,
        payroll_run: prisma.payroll_run,
        payroll_item: prisma.payroll_item,
      })
    );
    prisma.staff_compensation = {
      updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      create: jest.fn().mockResolvedValue({ id: 'comp-1' }),
    };
  });

  it('staffing workspace read does not touch patient billing ledger', async () => {
    const data = await hrWorkspaceService.getWorkspace(
      { panel: 'staffing', resource: 'staff-profiles' },
      1,
      20
    );

    expect(data.summary.total_staff).toBe(1);
    expectNoPatientBillingTouched();
  });

  it('staffing workspace GET is idempotent on replay (no double billing post)', async () => {
    const query = { panel: 'staffing', resource: 'staff-profiles' };
    const first = await hrWorkspaceService.getWorkspace(query, 1, 20);
    const second = await hrWorkspaceService.getWorkspace(query, 1, 20);

    expect(first.summary.total_staff).toBe(second.summary.total_staff);
    expect(repo.countStaffProfiles).toHaveBeenCalledTimes(2);
    expectNoPatientBillingTouched();
  });

  it('serializes workspace summary without patient paid flags or balances', async () => {
    const data = await hrWorkspaceService.getWorkspace(
      { panel: 'staffing' },
      1,
      20
    );

    expect(data.summary).not.toHaveProperty('payment_status');
    expect(data.summary).not.toHaveProperty('balance');
    expect(data.summary).not.toHaveProperty('amount_due');
    expect(data.summary).not.toHaveProperty('paid');
    expect(data.summary).not.toHaveProperty('invoice_id');
  });

  it('offboard without final payroll stays NOT_BILLED and never posts Billing', async () => {
    resolveModelRecordByIdentifier.mockResolvedValue(staffRecord);

    const result = await hrWorkspaceService.offboardStaff(
      'STF-1001',
      {
        separation_type: 'RESIGNATION',
        last_working_day: '2026-07-30T00:00:00.000Z',
        reason: 'relocating',
        schedule_final_payroll: false,
      },
      'actor-1',
      '127.0.0.1'
    );

    expect(result.status).toBe('SEPARATED');
    expect(result.schedule_final_payroll).toBe(false);
    expect(result.billing_status).toBe('NOT_BILLED');
    expect(result.final_payroll_run_id).toBeNull();
    expect(prisma.payroll_run.create).not.toHaveBeenCalled();
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        diff: expect.objectContaining({
          metadata: expect.objectContaining({
            schedule_final_payroll: false,
            billing_status: 'NOT_BILLED',
          }),
        }),
      })
    );
    expectNoPatientBillingTouched();
  });

  it('offboard schedule_final_payroll creates staff payroll DRAFT, not patient Billing', async () => {
    resolveModelRecordByIdentifier.mockResolvedValue(staffRecord);

    const result = await hrWorkspaceService.offboardStaff(
      'STF-1001',
      {
        separation_type: 'TERMINATION',
        last_working_day: '2026-07-30T00:00:00.000Z',
        schedule_final_payroll: true,
      },
      'actor-1',
      '127.0.0.1'
    );

    expect(result.schedule_final_payroll).toBe(true);
    expect(result.billing_status).toBe('NOT_BILLED');
    expect(result.final_payroll_run_id).toBeTruthy();
    expect(prisma.payroll_run.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          tenant_id: 'tenant-1',
          status: 'DRAFT',
          audit_trail_json: expect.objectContaining({
            operation: 'SCHEDULE_FINAL_PAYROLL',
            billing_status: 'NOT_BILLED',
          }),
        }),
      })
    );
    expectNoPatientBillingTouched();
  });

  it('offboard with final payroll is idempotent on replay without Billing posts', async () => {
    resolveModelRecordByIdentifier.mockResolvedValue(staffRecord);
    prisma.payroll_run.create
      .mockResolvedValueOnce({
        id: 'payroll-uuid-1',
        human_friendly_id: 'PAY-1001',
        tenant_id: 'tenant-1',
        status: 'DRAFT',
      })
      .mockResolvedValueOnce({
        id: 'payroll-uuid-2',
        human_friendly_id: 'PAY-1002',
        tenant_id: 'tenant-1',
        status: 'DRAFT',
      });

    const payload = {
      separation_type: 'RESIGNATION',
      last_working_day: '2026-07-30T00:00:00.000Z',
      schedule_final_payroll: true,
    };
    const first = await hrWorkspaceService.offboardStaff('STF-1001', payload, 'actor-1', '127.0.0.1');
    const second = await hrWorkspaceService.offboardStaff('STF-1001', payload, 'actor-1', '127.0.0.1');

    expect(first.billing_status).toBe('NOT_BILLED');
    expect(second.billing_status).toBe('NOT_BILLED');
    expect(prisma.payroll_run.create).toHaveBeenCalledTimes(2);
    expectNoPatientBillingTouched();
  });

  it('processPayrollRun posts staff payroll items only (no patient ledger)', async () => {
    const payrollRun = {
      id: 'payroll-uuid-1',
      human_friendly_id: 'PAY-1001',
      tenant_id: 'tenant-1',
      status: 'DRAFT',
      period_start: new Date('2026-07-01T00:00:00.000Z'),
      period_end: new Date('2026-07-15T00:00:00.000Z'),
    };
    resolveModelRecordByIdentifier.mockResolvedValue(payrollRun);
    prisma.staff_profile.findMany = jest.fn().mockResolvedValue([]);
    prisma.payroll_item.findFirst.mockResolvedValue(null);
    prisma.payroll_item.create.mockResolvedValue({ id: 'item-1' });
    prisma.payroll_run.update.mockResolvedValue({ ...payrollRun, status: 'PROCESSED' });

    // buildPayrollProposedItems needs staff activity stubs via internal loaders;
    // empty staff list yields zero items but still PROCESSED without Billing.
    const result = await hrWorkspaceService.processPayrollRun(
      'PAY-1001',
      { replace_existing_items: true, notes: 'final' },
      'actor-1',
      '127.0.0.1'
    );

    expect(result.processed_summary.status).toBe('PROCESSED');
    expectNoPatientBillingTouched();
  });

  it('staff profile compensation + consultation_fee create is catalog-only', async () => {
    const createdProfile = {
      id: staffRecord.id,
      human_friendly_id: staffRecord.human_friendly_id,
      tenant_id: staffRecord.tenant_id,
      user_id: staffRecord.user_id,
      staff_number: 'EMP-1',
      position: 'Nurse',
      practitioner_type: 'SPECIALIST',
      consultation_fee: 25000,
      consultation_currency: 'UGX',
    };
    staffProfileRepository.create.mockResolvedValue(createdProfile);
    staffProfileRepository.findById.mockResolvedValue(createdProfile);

    const result = await staffProfileService.createStaffProfile(
      {
        tenant_id: staffRecord.tenant_id,
        user_id: staffRecord.user_id,
        staff_number: 'EMP-1',
        position: 'Nurse',
        practitioner_type: 'SPECIALIST',
        consultation_fee: 25000,
        consultation_currency: 'UGX',
        compensations: [
          {
            pay_type: 'PER_MONTH',
            rate: 1000,
            currency: 'UGX',
            effective_from: new Date('2026-01-01'),
          },
        ],
      },
      'actor-1',
      '127.0.0.1'
    );

    expect(result).toEqual(
      expect.objectContaining({
        consultation_fee: 25000,
        staff_number: 'EMP-1',
      })
    );
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(result).not.toHaveProperty('paid');
    expectNoPatientBillingTouched();
  });

  it('unauthorized actor without billing scopes still cannot settle via staff handlers', async () => {
    resolveModelRecordByIdentifier.mockResolvedValue(staffRecord);

    await hrWorkspaceService.offboardStaff(
      'STF-1001',
      {
        separation_type: 'RESIGNATION',
        last_working_day: '2026-07-30T00:00:00.000Z',
        schedule_final_payroll: true,
      },
      'user-readonly',
      '127.0.0.1'
    );

    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(billingService.receivePayment).not.toHaveBeenCalled();
  });
});
