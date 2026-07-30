/**
 * Billing & sections scan for HR Payroll drafts tab (`/hr?section=payroll`).
 *
 * Preview / process mutate payroll_run / payroll_item (staff compensation).
 * They must never post patient Billing ledger rows. Patient create-charge /
 * receive-payment / adjustment stay on Billing module of record.
 */

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
  emitToUsers: jest.fn(),
  emitToUser: jest.fn(),
  HR_EVENTS: {
    HR_WORKSPACE_UPDATED: 'hr.workspace_updated',
  },
  NOTIFICATION_EVENTS: {
    NOTIFICATION_CREATED: 'notification.created',
  },
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: (...values) =>
    values.find((entry) => typeof entry === 'string' && entry.trim()) || null,
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || undefined),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value || undefined),
}));

const prisma = require('@prisma/client');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { createAuditLog } = require('@lib/audit');
const hrWorkspaceService = require('@services/hr-workspace/hr-workspace.service');
const { HttpError } = require('@lib/errors');

describe('hr-workspace Payroll drafts billing-sections scan', () => {
  const payrollRun = {
    id: 'payroll-run-uuid',
    human_friendly_id: 'PR-1001',
    tenant_id: 'tenant-123',
    status: 'DRAFT',
    period_start: new Date('2026-07-01T00:00:00.000Z'),
    period_end: new Date('2026-07-31T23:59:59.999Z'),
  };

  beforeEach(() => {
    jest.clearAllMocks();

    prisma.payroll_run = {
      findFirst: jest.fn().mockResolvedValue(payrollRun),
      findMany: jest.fn().mockResolvedValue([payrollRun]),
      update: jest.fn().mockImplementation(async ({ data }) => ({
        ...payrollRun,
        ...data,
      })),
      count: jest.fn().mockResolvedValue(1),
    };
    prisma.payroll_item = {
      findFirst: jest.fn().mockResolvedValue(null),
      updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      update: jest.fn(),
      create: jest.fn().mockResolvedValue({ id: 'item-1' }),
    };
    prisma.staff_profile = {
      findMany: jest.fn().mockResolvedValue([]),
    };
    prisma.$transaction = jest.fn(async (fn) => fn(prisma));
  });

  const expectNoPatientBillingPosts = () => {
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  };

  it('previewPayrollRun stays NOT_BILLED (no patient ledger post)', async () => {
    const preview = await hrWorkspaceService.previewPayrollRun('PR-1001');

    expect(preview).toEqual(
      expect.objectContaining({
        run_summary: expect.objectContaining({
          status: 'DRAFT',
        }),
        proposed_items: [],
      })
    );
    expect(preview).not.toHaveProperty('payment_status');
    expect(preview).not.toHaveProperty('balance');
    expect(preview).not.toHaveProperty('invoice_id');
    expect(prisma.payroll_run.update).toHaveBeenCalled();
    expectNoPatientBillingPosts();
  });

  it('previewPayrollRun replay is idempotent (no billing double post)', async () => {
    const first = await hrWorkspaceService.previewPayrollRun('PR-1001');
    const second = await hrWorkspaceService.previewPayrollRun('PR-1001');

    expect(first.proposed_items).toEqual(second.proposed_items);
    expect(prisma.payroll_run.findFirst).toHaveBeenCalledTimes(2);
    expectNoPatientBillingPosts();
  });

  it('processPayrollRun posts payroll_run PROCESSED only (NOT_BILLED)', async () => {
    const result = await hrWorkspaceService.processPayrollRun(
      'PR-1001',
      { replace_existing_items: true, notes: 'July close' },
      'user-123',
      '127.0.0.1'
    );

    expect(result.processed_summary).toEqual(
      expect.objectContaining({
        status: 'PROCESSED',
        processed_items: 0,
      })
    );
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(result).not.toHaveProperty('invoice_id');
    expect(prisma.$transaction).toHaveBeenCalled();
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        entity: 'payroll_run',
        action: 'UPDATE',
        diff: expect.objectContaining({
          metadata: expect.objectContaining({
            operation: 'PAYROLL_PROCESS',
          }),
        }),
      })
    );
    expectNoPatientBillingPosts();
  });

  it('processPayrollRun status parity: PROCESSED ≠ patient payment status', async () => {
    const result = await hrWorkspaceService.processPayrollRun(
      'PR-1001',
      {},
      'user-123',
      '127.0.0.1'
    );

    expect(result.processed_summary.status).toBe('PROCESSED');
    expect(result.processed_summary).not.toHaveProperty('payment_status');
    expect(result.processed_summary).not.toHaveProperty('amount_due');
    expectNoPatientBillingPosts();
  });

  it('processPayrollRun replay does not invent patient Billing posts', async () => {
    await hrWorkspaceService.processPayrollRun('PR-1001', {}, 'user-123', '127.0.0.1');
    await hrWorkspaceService.processPayrollRun('PR-1001', {}, 'user-123', '127.0.0.1');

    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
    expectNoPatientBillingPosts();
  });

  it('already-paid payroll rejects without Billing mutation', async () => {
    prisma.payroll_run.findFirst.mockResolvedValue({
      ...payrollRun,
      status: 'PAID',
    });

    await expect(
      hrWorkspaceService.processPayrollRun('PR-1001', {}, 'user-123', '127.0.0.1')
    ).rejects.toBeInstanceOf(HttpError);

    expect(prisma.$transaction).not.toHaveBeenCalled();
    expectNoPatientBillingPosts();
  });

  it('process with proposed compensation items never touches Billing', async () => {
    prisma.staff_profile.findMany.mockResolvedValue([
      {
        id: 'staff-uuid',
        human_friendly_id: 'STF-1',
        staff_number: 'EMP-1',
        user_id: 'user-staff',
        consultation_fee: null,
        consultation_currency: null,
        compensations: [
          {
            pay_type: 'PER_MONTH',
            rate: 1000,
            currency: 'USD',
            effective_from: payrollRun.period_start,
            effective_to: null,
            metadata_json: {},
          },
        ],
        user: {
          id: 'user-staff',
          email: 'casey@example.com',
          profile: { first_name: 'Casey', last_name: 'Payroll' },
        },
      },
    ]);

    // loadStaffPayrollActivity dependencies — empty activity is fine.
    prisma.shift_assignment = {
      findMany: jest.fn().mockResolvedValue([]),
    };
    prisma.staff_availability = {
      findMany: jest.fn().mockResolvedValue([]),
    };
    prisma.staff_leave = {
      findMany: jest.fn().mockResolvedValue([]),
    };
    prisma.encounter = {
      findMany: jest.fn().mockResolvedValue([]),
    };
    prisma.procedure_order = {
      findMany: jest.fn().mockResolvedValue([]),
    };

    const result = await hrWorkspaceService.processPayrollRun(
      'PR-1001',
      { replace_existing_items: true },
      'user-123',
      '127.0.0.1'
    );

    expect(result.processed_summary.status).toBe('PROCESSED');
    expect(result.items.length).toBeGreaterThanOrEqual(0);
    expectNoPatientBillingPosts();
  });
});
