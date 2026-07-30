/**
 * @module tests/modules/ipd-flow/services/ipd-flow.completed-billing-sections
 *
 * Billing & sections scan for Discharge Completed (`/discharge?section=completed`).
 * Completed rows are produced by finalizeDischarge, which must assert Billing
 * ledger settlement (no module-local paid bypass). Pharmacy take-home from the
 * Completed detail posts via clinical-request-billing (covered by pharmacy-order
 * + clinical-request-billing idempotency suites).
 */

jest.mock('@repositories/ipd-flow/ipd-flow.repository');
jest.mock('@lib/audit');
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  IPD_EVENTS: {
    IPD_FLOW_UPDATED: 'ipd.flow.updated',
  },
  ADMISSION_BED_EVENTS: {
    PATIENT_ADMITTED: 'admission.patient_admitted',
    PATIENT_TRANSFERRED: 'admission.patient_transferred',
    PATIENT_DISCHARGED: 'admission.patient_discharged',
    BED_ASSIGNMENT_CHANGED: 'admission.bed_assignment_changed',
  },
  NOTIFICATION_EVENTS: {
    NOTIFICATION_CREATED: 'notification.created',
  },
}));
jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  admission: {
    findFirst: jest.fn(),
    update: jest.fn(),
  },
  discharge_summary: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  bed_assignment: {
    update: jest.fn(),
  },
  bed: {
    update: jest.fn(),
  },
  invoice: {
    findMany: jest.fn(),
  },
  user_role: {
    findMany: jest.fn(),
  },
  notification: {
    create: jest.fn(),
  },
  follow_up: {
    create: jest.fn(),
  },
}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');
const { computeInvoiceFinancials } = require('@lib/billing/financials');

const now = new Date('2026-07-30T10:00:00.000Z');

const completeClearance = {
  summary_ready: true,
  pending_orders_reviewed: true,
  pharmacy_cleared: true,
  billing_cleared: true,
  nursing_cleared: true,
  documents_ready: true,
  patient_exited: true,
  override_reason: null,
};

const buildAdmissionReadyToFinalize = (overrides = {}) => ({
  id: 'adm-1',
  human_friendly_id: 'ADM0000001',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'pat-1',
  encounter_id: null,
  status: 'ADMITTED',
  admitted_at: now,
  discharged_at: null,
  created_at: now,
  updated_at: now,
  tenant: {
    id: 'tenant-1',
    human_friendly_id: 'TEN0000001',
    name: 'Demo Tenant',
  },
  facility: {
    id: 'facility-1',
    human_friendly_id: 'FAC0000001',
    name: 'Main Facility',
    facility_type: 'HOSPITAL',
  },
  patient: {
    id: 'pat-1',
    human_friendly_id: 'PAT0000001',
    first_name: 'Carol',
    last_name: 'Completed',
    date_of_birth: null,
    gender: 'FEMALE',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
  },
  encounter: null,
  bed_assignments: [],
  transfer_requests: [],
  discharge_summaries: [
    {
      id: 'ds-1',
      human_friendly_id: 'DS0000001',
      status: 'PLANNED',
      summary: 'Recovered; follow up in clinic.',
      discharged_at: null,
      clearance_snapshot: completeClearance,
      created_at: now,
      updated_at: now,
      deleted_at: null,
    },
  ],
  icu_stays: [],
  ward_rounds: [],
  nursing_notes: [],
  medication_administrations: [],
  ...overrides,
});

const openBalanceInvoice = {
  id: 'inv-open',
  patient_id: 'pat-1',
  tenant_id: 'tenant-1',
  status: 'ISSUED',
  billing_status: 'PARTIAL',
  total_amount: 1000,
  deleted_at: null,
  payments: [
    {
      id: 'pay-1',
      amount: 200,
      status: 'COMPLETED',
      deleted_at: null,
      refunds: [],
    },
  ],
  billing_adjustments: [],
};

const settledInvoice = {
  id: 'inv-paid',
  patient_id: 'pat-1',
  tenant_id: 'tenant-1',
  status: 'ISSUED',
  billing_status: 'PAID',
  total_amount: 1000,
  deleted_at: null,
  payments: [
    {
      id: 'pay-full',
      amount: 1000,
      status: 'COMPLETED',
      deleted_at: null,
      refunds: [],
    },
  ],
  billing_adjustments: [],
};

const stubSnapshot = (admission) => {
  prisma.admission.findFirst.mockResolvedValue({
    id: admission.id,
    human_friendly_id: admission.human_friendly_id,
  });
  ipdFlowRepository.findById.mockResolvedValue({
    ...admission,
    status: 'DISCHARGED',
    discharged_at: now,
    discharge_summaries: [
      {
        ...(admission.discharge_summaries?.[0] || {}),
        status: 'COMPLETED',
        discharged_at: now,
      },
    ],
  });
};

describe('ipd-flow Completed tab billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.user_role.findMany.mockResolvedValue([]);
    prisma.follow_up.create.mockResolvedValue({ id: 'fu-1' });
    prisma.notification.create.mockImplementation(async ({ data }) => ({
      id: `notif-${data.user_id}`,
      ...data,
      read_at: null,
      created_at: now,
      updated_at: now,
    }));
  });

  it('AC1/AC2: open Billing balance blocks finalize (no local paid bypass)', async () => {
    expect(
      Number(computeInvoiceFinancials(openBalanceInvoice).balance_due),
    ).toBeGreaterThan(0.009);

    const admission = buildAdmissionReadyToFinalize({
      discharge_summaries: [
        {
          id: 'ds-1',
          status: 'PLANNED',
          summary: 'Ready',
          clearance_snapshot: {
            ...completeClearance,
            // Module-local flag claims cleared — ledger must still win.
            billing_cleared: true,
          },
          deleted_at: null,
        },
      ],
    });

    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission),
      },
      invoice: {
        findMany: jest.fn().mockResolvedValue([openBalanceInvoice]),
      },
      discharge_summary: {
        update: jest.fn(),
      },
    };
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await expect(
      ipdFlowService.finalizeDischarge(
        'ADM0000001',
        { summary: 'Ready to go' },
        {},
      ),
    ).rejects.toMatchObject({
      messageKey: 'errors.ipd_flow.billing_clearance_required',
    });
    expect(tx.invoice.findMany).toHaveBeenCalled();
    expect(tx.discharge_summary.update).not.toHaveBeenCalled();
  });

  it('AC2: override_reason defers unpaid clearance (audited defer path)', async () => {
    const admission = buildAdmissionReadyToFinalize();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission),
        update: jest.fn().mockResolvedValue({
          ...admission,
          status: 'DISCHARGED',
          discharged_at: now,
        }),
      },
      invoice: {
        findMany: jest.fn().mockResolvedValue([openBalanceInvoice]),
      },
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-1' }),
      },
    };
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    stubSnapshot(admission);

    await ipdFlowService.finalizeDischarge(
      'ADM0000001',
      {
        summary: 'Ready to go',
        override_reason: 'CHARITY_WAIVER_PENDING_BILLING',
      },
      { user_id: 'user-1', tenant_id: 'tenant-1' },
    );

    expect(tx.discharge_summary.update).toHaveBeenCalled();
    expect(tx.admission.update).toHaveBeenCalled();
  });

  it('AC2/AC3: settled Billing ledger allows finalize (status parity path)', async () => {
    expect(
      Number(computeInvoiceFinancials(settledInvoice).balance_due),
    ).toBeLessThanOrEqual(0.009);

    const admission = buildAdmissionReadyToFinalize();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission),
        update: jest.fn().mockResolvedValue({
          ...admission,
          status: 'DISCHARGED',
          discharged_at: now,
        }),
      },
      invoice: {
        findMany: jest.fn().mockResolvedValue([settledInvoice]),
      },
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-1' }),
      },
    };
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    stubSnapshot(admission);

    await ipdFlowService.finalizeDischarge(
      'ADM0000001',
      { summary: 'Ready to go' },
      { user_id: 'user-1', tenant_id: 'tenant-1' },
    );

    expect(tx.invoice.findMany).toHaveBeenCalled();
    expect(tx.discharge_summary.update).toHaveBeenCalled();
    expect(tx.admission.update).toHaveBeenCalled();
  });

  it('AC2: updateDischargeClearance derives billing_cleared from Billing ledger', async () => {
    const admission = buildAdmissionReadyToFinalize();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission),
      },
      invoice: {
        findMany: jest.fn().mockResolvedValue([openBalanceInvoice]),
      },
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-1' }),
      },
    };
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    stubSnapshot(admission);

    await ipdFlowService.updateDischargeClearance(
      'ADM0000001',
      { billing_cleared: true },
      { user_id: 'user-1', tenant_id: 'tenant-1' },
    );

    expect(tx.invoice.findMany).toHaveBeenCalled();
    expect(tx.discharge_summary.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          clearance_snapshot: expect.objectContaining({
            billing_cleared: false,
          }),
        }),
      }),
    );
  });

  it('AC3: idempotent balance_due replay stays settled (no double charge invent)', () => {
    const first = computeInvoiceFinancials(settledInvoice);
    const second = computeInvoiceFinancials(settledInvoice);
    expect(first.balance_due).toBe(second.balance_due);
    expect(Number(first.balance_due)).toBeLessThanOrEqual(0.009);
  });

  it('AC2: clearance update with settled ledger sets billing_cleared true', async () => {
    const admission = buildAdmissionReadyToFinalize({
      discharge_summaries: [
        {
          id: 'ds-1',
          status: 'PLANNED',
          summary: 'Ready',
          clearance_snapshot: {
            ...completeClearance,
            billing_cleared: false,
          },
          deleted_at: null,
        },
      ],
    });
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission),
      },
      invoice: {
        findMany: jest.fn().mockResolvedValue([settledInvoice]),
      },
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-1' }),
      },
    };
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    stubSnapshot(admission);

    await ipdFlowService.updateDischargeClearance(
      'ADM0000001',
      { nursing_cleared: true },
      { user_id: 'user-1', tenant_id: 'tenant-1' },
    );

    expect(tx.discharge_summary.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          clearance_snapshot: expect.objectContaining({
            billing_cleared: true,
          }),
        }),
      }),
    );
  });
});
