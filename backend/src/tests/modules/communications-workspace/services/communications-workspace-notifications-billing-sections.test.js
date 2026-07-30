jest.mock('@repositories/communications-workspace/communications-workspace.repository');
jest.mock('@repositories/notification/notification.repository');
jest.mock('@repositories/notification-delivery/notification-delivery.repository');
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

const workspaceRepository = require('@repositories/communications-workspace/communications-workspace.repository');
const notificationRepository = require('@repositories/notification/notification.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const communicationsWorkspaceService = require('@services/communications-workspace/communications-workspace.service');
const notificationService = require('@services/notification/notification.service');

/**
 * Billing & sections scan for Communications Notifications tab.
 * Workspace GET for panel=notifications and mark-read / archive mutations are
 * notification-center ops and must never post patient Billing ledger rows.
 * Commercial SMS packages stay on the subscriptions invoice path (not mounted).
 */
describe('communications Notifications billing-sections scan', () => {
  const scopedUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    permissions: ['communications:read', 'communications:write'],
    roles: ['NURSE'],
  };

  const notificationRecord = {
    id: 'notification-uuid',
    human_friendly_id: 'NTF-1001',
    tenant_id: 'tenant-123',
    user_id: 'user-123',
    notification_type: 'LAB_ALERT',
    priority: 'HIGH',
    title: 'Critical lab result',
    message: 'Potassium critically high',
    read_at: null,
    target_path: '/patients/patient-1',
    context_type: 'LAB_ORDER',
    context_public_id: 'LAB-1001',
    created_at: new Date('2026-07-01T08:00:00.000Z'),
    updated_at: new Date('2026-07-01T08:00:00.000Z'),
    deleted_at: null,
    tenant: {
      id: 'tenant-123',
      human_friendly_id: 'TEN-1001',
      slug: 'tenant-1001',
      name: 'Tenant 1001',
    },
    user: {
      id: 'user-123',
      human_friendly_id: 'USR-1001',
      email: 'nurse@example.com',
      phone: '+256700000000',
      profile: { first_name: 'Nurse', last_name: 'One' },
    },
    deliveries: [
      {
        id: 'delivery-uuid',
        human_friendly_id: 'NDL-1001',
        channel: 'IN_APP',
        status: 'DELIVERED',
        recipient_target: 'nurse@example.com',
        provider_name: 'IN_APP',
        attempt_count: 1,
        sent_at: new Date('2026-07-01T08:00:00.000Z'),
        delivered_at: new Date('2026-07-01T08:00:01.000Z'),
        failed_at: null,
        retryable: false,
        error_message: null,
      },
    ],
  };

  beforeEach(() => {
    jest.clearAllMocks();
    workspaceRepository.listConversations.mockResolvedValue([]);
    workspaceRepository.listNotifications.mockResolvedValue([notificationRecord]);
    workspaceRepository.listDeliveries.mockResolvedValue([]);
    workspaceRepository.listTemplates.mockResolvedValue([]);
    workspaceRepository.findConversationUnreadStats.mockResolvedValue({
      unread: 0,
      archived: 0,
      sensitive: 0,
    });
    workspaceRepository.countNotifications.mockResolvedValue(1);
    workspaceRepository.countDeliveries.mockResolvedValue(0);
    workspaceRepository.countTemplates.mockResolvedValue(0);
  });

  it('Notifications panel workspace read does not touch patient billing ledger', async () => {
    const data = await communicationsWorkspaceService.getWorkspace(
      { panel: 'notifications' },
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.filters.panel).toBe('notifications');
    expect(data.notifications).toHaveLength(1);
    expect(data.notifications[0].id).toBe('NTF-1001');
    expect(data.notifications[0].title).toBe('Critical lab result');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('Notifications workspace GET is idempotent on replay (no double billing post)', async () => {
    const query = { panel: 'notifications' };
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

    expect(first.notifications).toEqual(second.notifications);
    expect(workspaceRepository.listNotifications).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('serializes notifications without local paid flags or balances', async () => {
    const data = await communicationsWorkspaceService.getWorkspace(
      { panel: 'notifications' },
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );
    const item = data.notifications[0];

    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount_due');
    expect(item).not.toHaveProperty('paid');
    expect(item).not.toHaveProperty('invoice_id');
    expect(item).not.toHaveProperty('amount');
  });

  it('status parity: read_at remains ops telemetry (NOT_BILLED), not ledger balance', async () => {
    const data = await communicationsWorkspaceService.getWorkspace(
      { panel: 'notifications' },
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.notifications[0].read_at).toBeNull();
    expect(data.summary.some((entry) => entry.id === 'notifications')).toBe(true);
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('mark read mutation does not post Billing and is idempotent on replay', async () => {
    const readRecord = {
      ...notificationRecord,
      read_at: new Date('2026-07-01T09:00:00.000Z'),
    };
    notificationRepository.findByIdentifier
      .mockResolvedValueOnce(notificationRecord)
      .mockResolvedValue(readRecord);
    notificationRepository.update.mockResolvedValue({ id: notificationRecord.id });
    notificationRepository.findById.mockResolvedValue(readRecord);

    const first = await notificationService.setNotificationReadState(
      'NTF-1001',
      true,
      scopedUser,
      '127.0.0.1'
    );
    const second = await notificationService.setNotificationReadState(
      'NTF-1001',
      true,
      scopedUser,
      '127.0.0.1'
    );

    expect(first.is_read).toBe(true);
    expect(second.is_read).toBe(true);
    expect(notificationRepository.update).toHaveBeenCalledTimes(1);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('archive mutation does not settle or adjust patient Billing', async () => {
    notificationRepository.findManyByIdentifiers.mockResolvedValue([notificationRecord]);
    notificationRepository.updateMany.mockResolvedValue({ count: 1 });

    const result = await notificationService.bulkArchiveNotifications(
      ['NTF-1001'],
      scopedUser,
      '127.0.0.1'
    );

    expect(result.archived_count).toBe(1);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('unauthorized actor without billing scopes still cannot settle via Notifications handlers', async () => {
    await communicationsWorkspaceService.getWorkspace(
      { panel: 'notifications' },
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
