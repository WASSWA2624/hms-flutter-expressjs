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
 * Billing & sections scan for Communications Templates tab.
 * Workspace GET for panel=templates is a read-only template catalog/preview
 * and must never post patient Billing ledger rows. Commercial SMS packages
 * stay on the subscriptions invoice path (not mounted here). Template CRUD
 * mutations are not exposed on this workspace API.
 */
describe('communications Templates billing-sections scan', () => {
  const scopedUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    permissions: ['communications:read', 'communications:write'],
    roles: ['NURSE'],
  };

  const templateRecord = {
    id: 'template-uuid',
    human_friendly_id: 'TPL-1001',
    name: 'Discharge summary',
    channel: 'EMAIL',
    subject: 'Your discharge summary',
    description: 'Patient discharge template',
    body: 'Hello {{patientName}}, your discharge is ready.',
    is_active: true,
    variables: [
      {
        id: 'var-1',
        human_friendly_id: 'TV-1',
        key: 'patientName',
        description: 'Patient full name',
        sample_value: 'Jane Doe',
      },
    ],
  };

  beforeEach(() => {
    jest.clearAllMocks();
    repository.listConversations.mockResolvedValue([]);
    repository.listNotifications.mockResolvedValue([]);
    repository.listDeliveries.mockResolvedValue([]);
    repository.listTemplates.mockResolvedValue([templateRecord]);
    repository.findConversationUnreadStats.mockResolvedValue({
      unread: 0,
      archived: 0,
      sensitive: 0,
    });
    repository.countNotifications.mockResolvedValue(0);
    repository.countDeliveries.mockResolvedValue(0);
    repository.countTemplates.mockResolvedValue(1);
  });

  const expectNoPatientBillingTouch = () => {
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  };

  it('Templates panel workspace read does not touch patient billing ledger', async () => {
    const data = await communicationsWorkspaceService.getWorkspace(
      { panel: 'templates' },
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.filters.panel).toBe('templates');
    expect(data.templates).toHaveLength(1);
    expect(data.templates[0].id).toBe('TPL-1001');
    expect(data.templates[0].name).toBe('Discharge summary');
    expect(data.templates[0].channel).toBe('EMAIL');
    expect(data.templates[0].is_active).toBe(true);
    expectNoPatientBillingTouch();
  });

  it('Templates workspace GET is idempotent on replay (no double billing post)', async () => {
    const query = { panel: 'templates' };
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

    expect(first.templates).toEqual(second.templates);
    expect(repository.listTemplates).toHaveBeenCalledTimes(2);
    expectNoPatientBillingTouch();
  });

  it('serializes templates without local paid flags or balances', async () => {
    const data = await communicationsWorkspaceService.getWorkspace(
      { panel: 'templates' },
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );
    const item = data.templates[0];

    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount_due');
    expect(item).not.toHaveProperty('paid');
    expect(item).not.toHaveProperty('invoice_id');
    expect(item).not.toHaveProperty('amount');
  });

  it('status parity: template is_active remains ops catalog (NOT_BILLED), not ledger balance', async () => {
    const data = await communicationsWorkspaceService.getWorkspace(
      { panel: 'templates' },
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.templates[0].is_active).toBe(true);
    expect(data.templates[0].preview).toEqual(
      expect.objectContaining({
        subject: 'Your discharge summary',
        body: 'Hello Jane Doe, your discharge is ready.',
      })
    );
    expect(data.summary.some((entry) => entry.id === 'templates')).toBe(true);
    expectNoPatientBillingTouch();
  });

  it('unauthorized actor without billing scopes still cannot settle via Templates handlers', async () => {
    await communicationsWorkspaceService.getWorkspace(
      { panel: 'templates' },
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

    expectNoPatientBillingTouch();
  });

  it('billing:write alone does not invent template cash collection path', async () => {
    await communicationsWorkspaceService.getWorkspace(
      { panel: 'templates' },
      1,
      30,
      undefined,
      'desc',
      {
        id: 'user-billing',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        permissions: ['communications:read', 'billing:write'],
        roles: ['CASHIER'],
      }
    );

    expectNoPatientBillingTouch();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });
});
