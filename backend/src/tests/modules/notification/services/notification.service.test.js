const notificationService = require('@services/notification/notification.service');
const notificationRepository = require('@repositories/notification/notification.repository');
const notificationDeliveryRepository = require('@repositories/notification-delivery/notification-delivery.repository');
const { createAuditLog } = require('@lib/audit');
const { emitToUser } = require('@lib/websocket');

jest.mock('@repositories/notification/notification.repository');
jest.mock('@repositories/notification-delivery/notification-delivery.repository');
jest.mock('@lib/audit');
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  NOTIFICATION_EVENTS: {
    NOTIFICATION_CREATED: 'notification.created',
    NOTIFICATION_DELIVERY_UPDATED: 'notification.delivery_updated',
  },
}));

describe('notification.service', () => {
  const actor = {
    id: '123e4567-e89b-12d3-a456-426614174099',
    tenant_id: '123e4567-e89b-12d3-a456-426614174010',
    roles: ['DOCTOR'],
  };

  const notificationRecord = {
    id: '123e4567-e89b-12d3-a456-426614174001',
    human_friendly_id: 'NTF-0001',
    tenant_id: actor.tenant_id,
    user_id: actor.id,
    notification_type: 'SYSTEM',
    priority: 'MEDIUM',
    title: 'New task',
    message: 'A new task is ready',
    read_at: null,
    target_path: '/dashboard',
    context_type: null,
    context_public_id: null,
    created_at: new Date('2026-03-01T10:00:00.000Z'),
    updated_at: new Date('2026-03-01T10:00:00.000Z'),
    tenant: {
      id: actor.tenant_id,
      human_friendly_id: 'TEN-1001',
      slug: 'tenant-1001',
      name: 'Tenant 1001',
    },
    user: {
      id: actor.id,
      human_friendly_id: 'USR-3001',
      email: 'doctor@example.com',
      phone: '+256700000000',
    },
    deliveries: [
      {
        id: '123e4567-e89b-12d3-a456-426614174777',
        human_friendly_id: 'NDL-1001',
        channel: 'IN_APP',
        status: 'DELIVERED',
        recipient_target: 'doctor@example.com',
        provider_name: 'IN_APP',
        attempt_count: 1,
        sent_at: new Date('2026-03-01T10:00:00.000Z'),
        delivered_at: new Date('2026-03-01T10:00:01.000Z'),
        failed_at: null,
        retryable: false,
        error_message: null,
        updated_at: new Date('2026-03-01T10:00:01.000Z'),
      },
    ],
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    notificationDeliveryRepository.create.mockResolvedValue({});
    notificationDeliveryRepository.createPublicId.mockReturnValue('NDL-9000');
    notificationRepository.findUserByIdentifier.mockResolvedValue(notificationRecord.user);
  });

  it('lists notifications with mapped public identifiers', async () => {
    notificationRepository.findMany.mockResolvedValue([notificationRecord]);
    notificationRepository.count.mockResolvedValue(1);

    const result = await notificationService.listNotifications({}, 1, 20, 'created_at', 'desc', actor);

    expect(result.notifications).toHaveLength(1);
    expect(result.notifications[0]).toEqual(
      expect.objectContaining({
        id: 'NTF-0001',
        tenant_id: 'TEN-1001',
        user_id: 'USR-3001',
        unread: true,
      })
    );
    expect(result.pagination.total).toBe(1);
    expect(notificationRepository.findMany).toHaveBeenCalled();
  });

  it('creates notification scoped to actor for non-admin users', async () => {
    notificationRepository.createPublicId.mockReturnValue('NTF-9000');
    notificationRepository.create.mockResolvedValue({
      ...notificationRecord,
      id: '123e4567-e89b-12d3-a456-426614174500',
      human_friendly_id: 'NTF-9000',
    });
    notificationRepository.findById
      .mockResolvedValueOnce({
        ...notificationRecord,
        id: '123e4567-e89b-12d3-a456-426614174500',
        human_friendly_id: 'NTF-9000',
        deliveries: [],
      })
      .mockResolvedValueOnce({
        ...notificationRecord,
        id: '123e4567-e89b-12d3-a456-426614174500',
        human_friendly_id: 'NTF-9000',
      });

    const result = await notificationService.createNotification(
      {
        tenant_id: 'TEN-OTHER',
        notification_type: 'SYSTEM',
        priority: 'MEDIUM',
        title: 'Create',
        message: 'Create message',
      },
      actor,
      '127.0.0.1'
    );

    expect(notificationRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        user_id: actor.id,
        human_friendly_id: 'NTF-9000',
      })
    );
    expect(notificationDeliveryRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        notification_id: '123e4567-e89b-12d3-a456-426614174500',
        channel: 'IN_APP',
        status: 'DELIVERED',
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        action: 'CREATE',
        entity: 'notification',
      })
    );
    expect(emitToUser).toHaveBeenCalled();
    expect(result.id).toBe('NTF-9000');
  });

  it('rejects unsupported delivery channels before creating the notification', async () => {
    await expect(
      notificationService.createNotification(
        {
          tenant_id: actor.tenant_id,
          notification_type: 'SYSTEM',
          priority: 'MEDIUM',
          title: 'Create',
          message: 'Create message',
          delivery_channels: ['SMS'],
        },
        actor,
        '127.0.0.1'
      )
    ).rejects.toThrow('errors.validation.invalid');

    expect(notificationRepository.create).not.toHaveBeenCalled();
    expect(notificationDeliveryRepository.create).not.toHaveBeenCalled();
  });

  it('rejects direct delivery channels without a resolvable recipient target', async () => {
    const adminActor = {
      id: '123e4567-e89b-12d3-a456-426614174200',
      tenant_id: actor.tenant_id,
      roles: ['TENANT_ADMIN'],
    };

    await expect(
      notificationService.createNotification(
        {
          tenant_id: actor.tenant_id,
          user_id: null,
          notification_type: 'SYSTEM',
          priority: 'MEDIUM',
          title: 'Create',
          message: 'Create message',
          delivery_channels: ['EMAIL'],
        },
        adminActor,
        '127.0.0.1'
      )
    ).rejects.toThrow('errors.validation.invalid');

    expect(notificationRepository.create).not.toHaveBeenCalled();
    expect(notificationDeliveryRepository.create).not.toHaveBeenCalled();
  });

  it('updates read state and emits realtime update', async () => {
    notificationRepository.findByIdentifier.mockResolvedValue(notificationRecord);
    notificationRepository.update.mockResolvedValue({ id: notificationRecord.id });
    notificationRepository.findById.mockResolvedValue({
      ...notificationRecord,
      read_at: new Date('2026-03-01T11:00:00.000Z'),
    });

    const result = await notificationService.setNotificationReadState(
      'NTF-0001',
      true,
      actor,
      '127.0.0.1'
    );

    expect(notificationRepository.update).toHaveBeenCalledWith(
      notificationRecord.id,
      expect.objectContaining({ read_at: expect.any(Date) })
    );
    expect(result.is_read).toBe(true);
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        action: 'UPDATE',
      })
    );
    expect(emitToUser).toHaveBeenCalled();
  });

  it('bulk updates read state for accessible notifications', async () => {
    notificationRepository.findManyByIdentifiers
      .mockResolvedValueOnce([
        {
          id: notificationRecord.id,
          tenant_id: actor.tenant_id,
          user_id: actor.id,
          read_at: null,
          human_friendly_id: 'NTF-0001',
        },
      ])
      .mockResolvedValueOnce([notificationRecord]);
    notificationRepository.updateMany.mockResolvedValue({ count: 1 });

    const result = await notificationService.bulkUpdateReadState(
      ['NTF-0001'],
      true,
      actor,
      '127.0.0.1'
    );

    expect(result.processed_count).toBe(1);
    expect(result.affected_count).toBe(1);
    expect(result.notifications[0].id).toBe('NTF-0001');
  });

  it('returns notification metrics for scoped actor', async () => {
    notificationRepository.count
      .mockResolvedValueOnce(10)
      .mockResolvedValueOnce(4)
      .mockResolvedValueOnce(2)
      .mockResolvedValueOnce(1)
      .mockResolvedValueOnce(1);
    notificationRepository.findMany.mockResolvedValueOnce([
      { created_at: new Date('2026-03-03T09:00:00.000Z') },
    ]);

    const metrics = await notificationService.getNotificationMetrics({}, actor);

    expect(metrics).toEqual(
      expect.objectContaining({
        total: 10,
        unread: 4,
        read: 6,
        attention_required: 2,
        failed_deliveries: 1,
      })
    );
  });

  it('rejects listing when actor scope is missing', async () => {
    await expect(
      notificationService.listNotifications({}, 1, 20, 'created_at', 'desc', {
        id: '',
        tenant_id: '',
        roles: ['DOCTOR'],
      })
    ).rejects.toThrow('errors.auth.insufficient_permissions');
  });
});
