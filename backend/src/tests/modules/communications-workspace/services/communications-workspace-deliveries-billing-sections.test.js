jest.mock('@repositories/communications-workspace/communications-workspace.repository');
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
  NOTIFICATION_EVENTS: {
    NOTIFICATION_CREATED: 'notification.created',
    NOTIFICATION_DELIVERY_UPDATED: 'notification.delivery_updated',
    CONVERSATION_THREAD_UPDATED: 'conversation.thread_updated',
    CONVERSATION_MESSAGE_CREATED: 'conversation.message_created',
  },
}));
jest.mock('@lib/storage', () => ({
  createStorageService: jest.fn(() => ({
    upload: jest.fn(),
    getUrl: jest.fn(),
  })),
}));

const repository = require('@repositories/communications-workspace/communications-workspace.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const communicationsWorkspaceService = require('@services/communications-workspace/communications-workspace.service');

/**
 * Billing & sections scan for Communications Deliveries tab.
 * Workspace GET for panel=deliveries is read-only delivery telemetry and must
 * never post patient Billing ledger rows. Commercial SMS packages stay on the
 * subscriptions invoice path (not mounted here).
 */
describe('communications Deliveries billing-sections scan', () => {
  const scopedUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    permissions: ['communications:read', 'communications:write'],
    roles: ['NURSE'],
  };

  const deliveryRecord = {
    id: 'delivery-uuid',
    human_friendly_id: 'NDL-1001',
    notification_id: 'notification-uuid',
    channel: 'SMS',
    status: 'FAILED',
    recipient_target: '+256700000000',
    provider_name: 'AFRICAS_TALKING',
    attempt_count: 2,
    sent_at: new Date('2026-07-01T08:00:00.000Z'),
    delivered_at: null,
    failed_at: new Date('2026-07-01T08:01:00.000Z'),
    retryable: true,
    error_message: 'Provider timeout',
    notification: {
      id: 'notification-uuid',
      human_friendly_id: 'NTF-1001',
      title: 'Critical lab result',
      target_path: '/patients/patient-1',
      user: {
        id: 'user-123',
        human_friendly_id: 'USR-1001',
        email: 'nurse@example.com',
        phone: '+256700000000',
        profile: { first_name: 'Nurse', last_name: 'One' },
      },
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    repository.listConversations.mockResolvedValue([]);
    repository.listNotifications.mockResolvedValue([]);
    repository.listDeliveries.mockResolvedValue([deliveryRecord]);
    repository.listTemplates.mockResolvedValue([]);
    repository.findConversationUnreadStats.mockResolvedValue({
      unread: 0,
      archived: 0,
      sensitive: 0,
    });
    repository.countNotifications.mockResolvedValue(0);
    repository.countDeliveries.mockResolvedValue(1);
    repository.countTemplates.mockResolvedValue(0);
  });

  it('Deliveries panel workspace read does not touch patient billing ledger', async () => {
    const data = await communicationsWorkspaceService.getWorkspace(
      { panel: 'deliveries' },
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.filters.panel).toBe('deliveries');
    expect(data.deliveries).toHaveLength(1);
    expect(data.deliveries[0].id).toBe('NDL-1001');
    expect(data.deliveries[0].status).toBe('FAILED');
    expect(data.deliveries[0].channel).toBe('SMS');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('Deliveries workspace GET is idempotent on replay (no double billing post)', async () => {
    const query = { panel: 'deliveries' };
    const first = await communicationsWorkspaceService.getWorkspace(
      query,
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );
    const second = await communicationsWorkspaceService.getWorkspace(
      query,
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );

    expect(first.deliveries).toEqual(second.deliveries);
    expect(repository.listDeliveries).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('serializes deliveries without local paid flags or balances', async () => {
    const data = await communicationsWorkspaceService.getWorkspace(
      { panel: 'deliveries' },
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );
    const item = data.deliveries[0];

    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount_due');
    expect(item).not.toHaveProperty('paid');
    expect(item).not.toHaveProperty('invoice_id');
    expect(item).not.toHaveProperty('amount');
  });

  it('status parity: delivery status remains ops telemetry (NOT_BILLED), not ledger balance', async () => {
    const data = await communicationsWorkspaceService.getWorkspace(
      { panel: 'deliveries' },
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.deliveries[0].status).toBe('FAILED');
    expect(data.summary.some((entry) => entry.id === 'failed_deliveries')).toBe(true);
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('unauthorized actor without billing scopes still cannot settle via Deliveries handlers', async () => {
    await communicationsWorkspaceService.getWorkspace(
      { panel: 'deliveries' },
      1,
      30,
      undefined,
      'desc',
      {
        id: 'user-readonly',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        permissions: ['communications:read'],
        roles: ['NURSE'],
      }
    );

    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
