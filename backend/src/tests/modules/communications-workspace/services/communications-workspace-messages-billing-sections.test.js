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
  NOTIFICATION_EVENTS: {
    CONVERSATION_READ_STATE_UPDATED: 'conversation.read_state_updated',
    CONVERSATION_THREAD_UPDATED: 'conversation.thread_updated',
    CONVERSATION_MESSAGE_CREATED: 'conversation.message_created',
    NOTIFICATION_CREATED: 'notification.created',
  },
}));
jest.mock('@lib/storage', () => ({
  createStorageService: jest.fn(() => ({
    upload: jest.fn(),
    getUrl: jest.fn(),
  })),
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: (...values) =>
    values.find((entry) => typeof entry === 'string' && entry.trim()) || null,
  sanitizeIdentifier: (value) => value,
}));

const repository = require('@repositories/communications-workspace/communications-workspace.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { createAuditLog } = require('@lib/audit');
const service = require('@services/communications-workspace/communications-workspace.service');

describe('communications Messages (inbox) billing-sections scan', () => {
  const scopedUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    roles: ['NURSE'],
    permissions: ['communications:read', 'communications:write'],
  };

  const peerUser = {
    id: 'user-456',
    human_friendly_id: 'USR-456',
    email: 'peer@example.com',
    profile: { first_name: 'Peer', last_name: 'Nurse' },
  };

  const conversationRecord = {
    id: 'conversation-uuid',
    human_friendly_id: 'COM-100',
    tenant_id: 'tenant-123',
    subject: 'Critical lab follow-up',
    conversation_type: 'DIRECT',
    is_sensitive: false,
    created_by_user_id: 'user-123',
    last_message_at: new Date('2026-07-01T08:00:00.000Z'),
    status: 'OPEN',
    participants: [
      {
        id: 'participant-1',
        user_id: 'user-123',
        deleted_at: null,
        last_read_at: null,
        is_favorite: false,
        is_flagged: false,
        archived_at: null,
        user: {
          id: 'user-123',
          human_friendly_id: 'USR-123',
          email: 'nurse@example.com',
          profile: { first_name: 'Alex', last_name: 'Nurse' },
        },
      },
      {
        id: 'participant-2',
        user_id: 'user-456',
        deleted_at: null,
        last_read_at: null,
        is_favorite: false,
        is_flagged: false,
        archived_at: null,
        user: peerUser,
      },
    ],
    messages: [
      {
        id: 'message-uuid',
        human_friendly_id: 'MSG-1',
        conversation_id: 'conversation-uuid',
        sender_user_id: 'user-123',
        content: 'Please review potassium',
        message_type: 'TEXT',
        sent_at: new Date('2026-07-01T08:00:00.000Z'),
        attachments: [],
        sender_user: {
          id: 'user-123',
          human_friendly_id: 'USR-123',
          email: 'nurse@example.com',
          profile: { first_name: 'Alex', last_name: 'Nurse' },
        },
      },
    ],
  };

  beforeEach(() => {
    jest.clearAllMocks();
    repository.listConversations.mockResolvedValue([conversationRecord]);
    repository.listNotifications.mockResolvedValue([]);
    repository.listDeliveries.mockResolvedValue([]);
    repository.listTemplates.mockResolvedValue([]);
    repository.findConversationUnreadStats.mockResolvedValue({
      unread: 1,
      archived: 0,
      sensitive: 0,
    });
    repository.countNotifications.mockResolvedValue(0);
    repository.countDeliveries.mockResolvedValue(0);
    repository.countTemplates.mockResolvedValue(0);
    repository.getConversation.mockResolvedValue(conversationRecord);
    repository.resolveUserId.mockImplementation(async (id) => id);
    repository.createPublicId.mockImplementation((prefix) => `${prefix}-NEW`);
    repository.findExistingDirectConversation.mockResolvedValue(null);
    repository.prisma = {
      $transaction: jest.fn(async (fn) =>
        fn({
          conversation: {
            create: jest.fn().mockResolvedValue({
              id: 'conversation-new',
              human_friendly_id: 'COM-NEW',
            }),
            update: jest.fn().mockResolvedValue({}),
          },
          conversation_participant: {
            create: jest.fn().mockResolvedValue({}),
            update: jest.fn().mockResolvedValue({}),
          },
          conversation_visibility_role: {
            create: jest.fn().mockResolvedValue({}),
          },
          message: {
            create: jest.fn().mockResolvedValue({
              id: 'message-new',
              human_friendly_id: 'MSG-NEW',
              content: 'Follow-up sent',
              conversation_id: 'conversation-uuid',
              sender_user_id: 'user-123',
              message_type: 'TEXT',
              sent_at: new Date(),
              attachments: [],
            }),
          },
          message_attachment: {
            create: jest.fn().mockResolvedValue({}),
          },
          notification: {
            create: jest.fn().mockResolvedValue({ id: 'notif-1' }),
            updateMany: jest.fn().mockResolvedValue({ count: 0 }),
          },
        })
      ),
      conversation_participant: {
        update: jest.fn().mockResolvedValue({}),
        create: jest.fn().mockResolvedValue({}),
      },
      conversation: {
        update: jest.fn().mockResolvedValue({}),
      },
    };
  });

  const expectNoPatientBillingTouch = () => {
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  };

  it('Messages inbox workspace read does not touch patient billing ledger', async () => {
    const data = await service.getWorkspace(
      { panel: 'inbox' },
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.filters.panel).toBe('inbox');
    expect(data.conversations).toHaveLength(1);
    expect(data.conversations[0].id).toBe('COM-100');
    expectNoPatientBillingTouch();
  });

  it('Messages inbox GET is idempotent on replay (no double billing post)', async () => {
    const query = { panel: 'inbox' };
    const first = await service.getWorkspace(query, 1, 30, undefined, 'desc', scopedUser);
    const second = await service.getWorkspace(query, 1, 30, undefined, 'desc', scopedUser);

    expect(first.conversations).toEqual(second.conversations);
    expect(repository.listConversations).toHaveBeenCalledTimes(2);
    expectNoPatientBillingTouch();
  });

  it('serializes conversations without local paid flags or balances', async () => {
    const data = await service.getWorkspace(
      { panel: 'inbox' },
      1,
      30,
      undefined,
      'desc',
      scopedUser
    );
    const item = data.conversations[0];

    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount_due');
    expect(item).not.toHaveProperty('paid');
    expect(item).not.toHaveProperty('invoice_id');
  });

  it('create conversation (New message) stays NOT_BILLED (no patient ledger post)', async () => {
    repository.getConversation.mockResolvedValue({
      ...conversationRecord,
      id: 'conversation-new',
      human_friendly_id: 'COM-NEW',
    });

    const result = await service.createConversation(
      {
        participant_ids: ['user-456'],
        conversation_type: 'DIRECT',
        subject: 'Lab consult',
      },
      scopedUser
    );

    expect(result.id).toBe('COM-NEW');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'communications_workspace_conversation',
      })
    );
    expectNoPatientBillingTouch();
  });

  it('create conversation DIRECT replay returns existing without billing post', async () => {
    repository.findExistingDirectConversation.mockResolvedValue(conversationRecord);

    const first = await service.createConversation(
      {
        participant_ids: ['user-456'],
        conversation_type: 'DIRECT',
      },
      scopedUser
    );
    const second = await service.createConversation(
      {
        participant_ids: ['user-456'],
        conversation_type: 'DIRECT',
      },
      scopedUser
    );

    expect(first.id).toBe('COM-100');
    expect(second.id).toBe('COM-100');
    expect(repository.prisma.$transaction).not.toHaveBeenCalled();
    expectNoPatientBillingTouch();
  });

  it('create conversation message (compose/send) stays NOT_BILLED', async () => {
    const result = await service.createConversationMessage(
      'COM-100',
      { content: 'Follow-up sent' },
      scopedUser
    );

    expect(result.id).toBe('COM-100');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'communications_workspace_message',
      })
    );
    expectNoPatientBillingTouch();
  });

  it('mark conversation read stays NOT_BILLED', async () => {
    await service.markConversationRead('COM-100', scopedUser);
    expectNoPatientBillingTouch();
  });

  it('archive conversation stays NOT_BILLED', async () => {
    await service.archiveConversation('COM-100', scopedUser, true);
    expectNoPatientBillingTouch();
  });

  it('unauthorized user without tenant cannot collect or post billing via Messages', async () => {
    await expect(
      service.createConversationMessage(
        'COM-100',
        { content: 'Should fail' },
        { id: 'user-123', permissions: ['billing:write'] }
      )
    ).rejects.toMatchObject({ status: 403 });
    expectNoPatientBillingTouch();
  });

  it('non-participant cannot send (no billing bypass)', async () => {
    await expect(
      service.createConversationMessage(
        'COM-100',
        { content: 'Intruder' },
        {
          id: 'outsider',
          tenant_id: 'tenant-123',
          permissions: ['communications:write', 'billing:write'],
        }
      )
    ).rejects.toMatchObject({ status: 403 });
    expectNoPatientBillingTouch();
  });
});
