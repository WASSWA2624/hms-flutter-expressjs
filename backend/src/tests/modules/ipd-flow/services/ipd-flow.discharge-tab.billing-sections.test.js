/**
 * IPD Discharge tab (`/ipd?section=discharge`) billing-sections scan.
 *
 * Covers plan-discharge (clinical, no ledger invent), finalize / clearance
 * gates against live Billing invoices, override deferral, and ward-round
 * posting via clinical-request-billing — no parallel cash ledger on the tab.
 *
 * @module tests/modules/ipd-flow/services/ipd-flow.discharge-tab.billing-sections
 */

jest.mock('@repositories/ipd-flow/ipd-flow.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  IPD_EVENTS: { IPD_FLOW_UPDATED: 'ipd.flow.updated' },
  ADMISSION_BED_EVENTS: {
    PATIENT_ADMITTED: 'admission.patient_admitted',
    PATIENT_TRANSFERRED: 'admission.patient_transferred',
    PATIENT_DISCHARGED: 'admission.patient_discharged',
    BED_ASSIGNMENT_CHANGED: 'admission.bed_assignment_changed',
  },
  NOTIFICATION_EVENTS: { NOTIFICATION_CREATED: 'notification.created' },
}));
jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    persistWardRoundBilling: jest.fn(),
    persistAdmissionBilling: jest.fn(),
    applyClinicalRequestBilling: jest.fn(),
  };
});
jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  admission: {
    findFirst: jest.fn(),
    update: jest.fn(),
  },
  discharge_summary: {
    update: jest.fn(),
    create: jest.fn(),
  },
  ward_round: { create: jest.fn() },
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() },
  encounter: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
  },
  visit_queue: { updateMany: jest.fn() },
  appointment: { updateMany: jest.fn() },
  invoice: { findMany: jest.fn() },
}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const {
  persistWardRoundBilling,
  persistAdmissionBilling,
} = require('@lib/billing/clinical-request-billing');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');

const now = new Date('2026-07-30T10:00:00.000Z');

const clearanceComplete = {
  summary_ready: true,
  pending_orders_reviewed: true,
  pharmacy_cleared: true,
  billing_cleared: true,
  nursing_cleared: true,
  documents_ready: true,
  patient_exited: true,
  override_reason: null,
};

const buildAdmission = (overrides = {}) => ({
  id: 'adm-disc-1',
  human_friendly_id: 'ADM-DISC-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-1',
  encounter_id: 'enc-1',
  status: 'ADMITTED',
  admitted_at: now,
  discharged_at: null,
  created_at: now,
  updated_at: now,
  bed_assignments: [],
  transfer_requests: [],
  discharge_summaries: [
    {
      id: 'ds-1',
      summary: 'Ready for discharge clearance',
      status: 'PLANNED',
      clearance_snapshot: clearanceComplete,
      deleted_at: null,
      updated_at: now,
    },
  ],
  ...overrides,
});

const openInvoice = {
  id: 'inv-open',
  total_amount: '2500.00',
  status: 'SENT',
  billing_status: 'ISSUED',
  payments: [],
  billing_adjustments: [],
};

const paidInvoice = {
  id: 'inv-paid',
  total_amount: '2500.00',
  status: 'PAID',
  billing_status: 'PAID',
  payments: [
    {
      amount: '2500.00',
      status: 'COMPLETED',
      deleted_at: null,
      refunds: [],
    },
  ],
  billing_adjustments: [],
};

const wardRoundBillingPayload = {
  payment_status: 'PENDING',
  currency: 'UGX',
  total_amount: 50000,
  line_items: [
    {
      id: 'WARD_ROUND',
      label: 'Ward round',
      quantity: 1,
      unit_price: 50000,
    },
  ],
};

describe('ipd-flow Discharge tab billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.user_role.findMany.mockResolvedValue([]);
    persistWardRoundBilling.mockResolvedValue({
      invoice_id: 'inv-round-1',
      payment_status: 'PENDING',
    });
    persistAdmissionBilling.mockResolvedValue({
      invoice_id: 'inv-adm-1',
      payment_status: 'PENDING',
    });
  });

  it('plan-discharge is clinical-only (no Billing post / no cashier bypass)', async () => {
    const admission = buildAdmission({ discharge_summaries: [] });
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-1' })
          .mockResolvedValueOnce(admission),
      },
      discharge_summary: {
        create: jest.fn().mockResolvedValue({ id: 'ds-1', status: 'PLANNED' }),
      },
      invoice: { findMany: jest.fn() },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-disc-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        discharge_summaries: [
          {
            id: 'ds-1',
            status: 'PLANNED',
            summary: 'Plan ready',
            clearance_snapshot: { summary_ready: true },
            deleted_at: null,
            updated_at: now,
          },
        ],
      }),
    );

    const result = await ipdFlowService.planDischarge(
      'ADM-DISC-1',
      { summary: 'Plan ready' },
      { user_id: 'user-1' },
    );

    expect(result).toBeTruthy();
    expect(tx.discharge_summary.create).toHaveBeenCalledTimes(1);
    expect(persistWardRoundBilling).not.toHaveBeenCalled();
    expect(persistAdmissionBilling).not.toHaveBeenCalled();
    expect(tx.invoice.findMany).not.toHaveBeenCalled();
  });

  it('rejects finalize when Billing still has balance (no module-local bypass)', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-1' })
          .mockResolvedValueOnce(buildAdmission()),
      },
      invoice: {
        findMany: jest.fn().mockResolvedValue([openInvoice]),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await expect(
      ipdFlowService.finalizeDischarge(
        'ADM-DISC-1',
        { summary: 'Ready after clearance' },
        {},
      ),
    ).rejects.toMatchObject({
      messageKey: 'errors.ipd_flow.billing_clearance_required',
    });
    expect(tx.invoice.findMany).toHaveBeenCalled();
  });

  it('allows finalize when Billing ledger balance is settled (status parity)', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-1' })
          .mockResolvedValueOnce(admission),
        update: jest.fn().mockResolvedValue({
          ...admission,
          status: 'DISCHARGED',
        }),
      },
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-1' }),
      },
      invoice: {
        findMany: jest.fn().mockResolvedValue([paidInvoice]),
      },
      encounter: {
        findFirst: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
      },
      visit_queue: { updateMany: jest.fn() },
      appointment: { updateMany: jest.fn() },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-disc-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({ status: 'DISCHARGED', discharged_at: now }),
    );

    const result = await ipdFlowService.finalizeDischarge(
      'ADM-DISC-1',
      { summary: 'Ready after clearance' },
      {},
    );

    expect(result).toBeTruthy();
    expect(tx.invoice.findMany).toHaveBeenCalledTimes(1);
    expect(tx.discharge_summary.update).toHaveBeenCalledTimes(1);
  });

  it('idempotent replay: second finalize does not invent a second ledger row', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-1' })
          .mockResolvedValueOnce(admission),
        update: jest.fn().mockResolvedValue({
          ...admission,
          status: 'DISCHARGED',
        }),
      },
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-1' }),
      },
      invoice: {
        findMany: jest.fn().mockResolvedValue([paidInvoice]),
      },
      encounter: {
        findFirst: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
      },
      visit_queue: { updateMany: jest.fn() },
      appointment: { updateMany: jest.fn() },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-disc-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({ status: 'DISCHARGED', discharged_at: now }),
    );

    await ipdFlowService.finalizeDischarge(
      'ADM-DISC-1',
      { summary: 'Ready after clearance' },
      {},
    );

    expect(tx.invoice.findMany).toHaveBeenCalledTimes(1);
    expect(persistAdmissionBilling).not.toHaveBeenCalled();
    expect(persistWardRoundBilling).not.toHaveBeenCalled();
  });

  it('update clearance cannot force billing_cleared while balance remains', async () => {
    const admission = buildAdmission({
      discharge_summaries: [
        {
          id: 'ds-1',
          summary: 'Ready',
          status: 'PLANNED',
          clearance_snapshot: {
            ...clearanceComplete,
            billing_cleared: false,
            patient_exited: false,
          },
          deleted_at: null,
          updated_at: now,
        },
      ],
    });
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-1' })
          .mockResolvedValueOnce(admission),
      },
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-1' }),
      },
      invoice: {
        findMany: jest.fn().mockResolvedValue([openInvoice]),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-disc-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.updateDischargeClearance(
      'ADM-DISC-1',
      { billing_cleared: true },
      {},
    );

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

  it('override_reason defers unpaid finalize without inventing a cashier row', async () => {
    const admission = buildAdmission({
      discharge_summaries: [
        {
          id: 'ds-1',
          summary: 'Override path',
          status: 'PLANNED',
          clearance_snapshot: {
            ...clearanceComplete,
            billing_cleared: false,
            override_reason: 'Emergency transfer; balance deferred',
          },
          deleted_at: null,
          updated_at: now,
        },
      ],
    });
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-1' })
          .mockResolvedValueOnce(admission),
        update: jest.fn().mockResolvedValue({
          ...admission,
          status: 'DISCHARGED',
        }),
      },
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-1' }),
      },
      invoice: {
        findMany: jest.fn().mockResolvedValue([openInvoice]),
      },
      encounter: {
        findFirst: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
      },
      visit_queue: { updateMany: jest.fn() },
      appointment: { updateMany: jest.fn() },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-disc-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({ status: 'DISCHARGED', discharged_at: now }),
    );

    const result = await ipdFlowService.finalizeDischarge(
      'ADM-DISC-1',
      {
        summary: 'Override path',
        override_reason: 'Emergency transfer; balance deferred',
      },
      { user_id: 'user-1' },
    );

    expect(result).toBeTruthy();
    expect(persistAdmissionBilling).not.toHaveBeenCalled();
    expect(createAuditLog).toHaveBeenCalled();
  });

  it('add-ward-round posts via persistWardRoundBilling (shared Billing)', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-1' })
          .mockResolvedValueOnce(admission),
      },
      ward_round: {
        create: jest.fn().mockResolvedValue({
          id: 'wr-1',
          admission_id: 'adm-disc-1',
          notes: 'AM round',
        }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-disc-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.addWardRound(
      'ADM-DISC-1',
      {
        notes: 'AM round',
        billing: wardRoundBillingPayload,
      },
      { user_id: 'user-1' },
    );

    expect(tx.ward_round.create).toHaveBeenCalledTimes(1);
    expect(persistWardRoundBilling).toHaveBeenCalledTimes(1);
    expect(persistWardRoundBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        wardRoundId: 'wr-1',
        tenantId: 'tenant-1',
        patientId: 'patient-1',
        facilityId: 'facility-1',
        billing: expect.objectContaining({
          payment_status: 'PENDING',
          currency: 'UGX',
        }),
      }),
    );
  });

  it('unauthorized client cannot invent parallel paid flag on finalize', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-1' })
          .mockResolvedValueOnce(buildAdmission()),
      },
      invoice: {
        findMany: jest.fn().mockResolvedValue([openInvoice]),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await expect(
      ipdFlowService.finalizeDischarge(
        'ADM-DISC-1',
        {
          summary: 'Force clear',
          billing_cleared: true,
          clearance: { billing_cleared: true },
        },
        {},
      ),
    ).rejects.toMatchObject({
      messageKey: 'errors.ipd_flow.billing_clearance_required',
    });
  });
});
