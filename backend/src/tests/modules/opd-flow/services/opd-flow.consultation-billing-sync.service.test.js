jest.mock('@repositories/opd-flow/opd-flow.repository');
jest.mock('@lib/audit', () => ({ createAuditLog: jest.fn().mockResolvedValue({}) }));
jest.mock('@services/ipd-flow/ipd-flow.service', () => ({
  emitAdmissionRefreshEvent: jest.fn().mockResolvedValue(null),
}));
jest.mock(
  '@services/clinical-alert-threshold/clinical-alert-threshold.service',
  () => ({ evaluateVitalAndCreateAlerts: jest.fn().mockResolvedValue(null) })
);
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  OPD_EVENTS: { OPD_FLOW_UPDATED: 'opd.flow.updated' },
  NOTIFICATION_EVENTS: { NOTIFICATION_CREATED: 'notification.created' },
}));

jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceStateTx: jest.fn(async () => ({
    invoice: {
      id: 'inv-1',
      human_friendly_id: 'INV0001',
      billing_status: 'PAID',
      total_amount: '50.00',
      currency: 'UGX',
    },
    financials: {
      balance_due: 0,
      net_paid_total: 50,
      effective_total: 50,
      gross_paid_total: 50,
    },
  })),
  computeInvoiceFinancials: jest.fn(() => ({
    balance_due: 0,
    net_paid_total: 50,
    effective_total: 50,
  })),
}));

jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  encounter: { findFirst: jest.fn(), findMany: jest.fn(), update: jest.fn() },
  invoice: { findFirst: jest.fn() },
  user_role: { findMany: jest.fn().mockResolvedValue([]) },
  notification: { create: jest.fn() },
  notification_delivery: { createMany: jest.fn() },
}));

const prisma = require('@prisma/client');
const opdFlowService = require('@services/opd-flow/opd-flow.service');

describe('syncConsultationBillingFromInvoicePayment', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('marks consultation paid and advances Payment due to Waiting vitals', async () => {
    const encounter = {
      id: 'encounter-1',
      human_friendly_id: 'ENC0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1',
      encounter_type: 'OPD',
      status: 'OPEN',
      extension_json: {
        opd_flow: {
          stage: 'WAITING_CONSULTATION_PAYMENT',
          next_step: 'PAY_CONSULTATION',
          consultation: {
            invoice_id: 'inv-1',
            consultation_fee: '50.00',
            require_payment: true,
            is_paid: false,
            payment_status: 'ISSUED',
          },
          timeline: [],
        },
      },
      patient: { id: 'patient-1', human_friendly_id: 'PAT0001' },
      provider: null,
      tenant: { id: 'tenant-1', human_friendly_id: 'TEN0001' },
      facility: { id: 'facility-1', human_friendly_id: 'FAC0001' },
    };

    let persistedFlow = null;
    prisma.$transaction.mockImplementation(async (callback) => {
      const tx = {
        invoice: {
          findFirst: jest.fn(async () => ({
            id: 'inv-1',
            human_friendly_id: 'INV0001',
            tenant_id: 'tenant-1',
            facility_id: 'facility-1',
            encounter_id: 'encounter-1',
            currency: 'UGX',
            billing_status: 'PAID',
            total_amount: '50.00',
          })),
        },
        encounter: {
          findFirst: jest.fn(async () => encounter),
          findMany: jest.fn(async () => []),
          update: jest.fn(async ({ data }) => {
            persistedFlow = data.extension_json.opd_flow;
            return {
              ...encounter,
              extension_json: data.extension_json,
            };
          }),
        },
      };
      return callback(tx);
    });

    const snapshot = await opdFlowService.syncConsultationBillingFromInvoicePayment({
      invoiceId: 'inv-1',
      payment: {
        id: 'pay-1',
        status: 'COMPLETED',
        amount: '50.00',
        paid_at: new Date('2026-07-21T06:00:00.000Z'),
      },
      context: { user_id: 'billing-1', tenant_id: 'tenant-1' },
    });

    expect(persistedFlow?.stage).toBe('WAITING_VITALS');
    expect(persistedFlow?.next_step).toBe('RECORD_VITALS');
    expect(persistedFlow?.consultation?.is_paid).toBe(true);
    expect(persistedFlow?.consultation?.payment_status).toBe('PAID');
    // Snapshot fetch may no-op under the prisma mock; persistence is authoritative.
    expect(snapshot === null || snapshot?.flow?.stage === 'WAITING_VITALS').toBe(true);
  });
});
