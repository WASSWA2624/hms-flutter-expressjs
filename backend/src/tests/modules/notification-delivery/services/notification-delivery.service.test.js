const notificationDeliveryService = require('@services/notification-delivery/notification-delivery.service');
const notificationDeliveryRepository = require('@repositories/notification-delivery/notification-delivery.repository');
const { createAuditLog } = require('@lib/audit');
const { emitToUser } = require('@lib/websocket');

jest.mock('@repositories/notification-delivery/notification-delivery.repository');
jest.mock('@lib/audit');
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  NOTIFICATION_EVENTS: {
    NOTIFICATION_DELIVERY_UPDATED: 'notification.delivery_updated',
  },
}));

describe('notification-delivery.service', () => {
  const actor = {
    id: '123e4567-e89b-12d3-a456-426614174099',
    tenant_id: '123e4567-e89b-12d3-a456-426614174010',
    roles: ['DOCTOR'],
  };

  const deliveryRecord = {
    id: '123e4567-e89b-12d3-a456-426614174321',
    human_friendly_id: 'NDL-1001',
    notification_id: '123e4567-e89b-12d3-a456-426614174001',
    channel: 'IN_APP',
    status: 'DELIVERED',
    recipient_target: 'doctor@example.com',
    provider_name: 'IN_APP',
    attempt_count: 1,
    last_attempt_at: null,
    sent_at: new Date('2026-03-01T10:00:00.000Z'),
    delivered_at: new Date('2026-03-01T10:00:01.000Z'),
    failed_at: null,
    retryable: false,
    error_message: null,
    created_at: new Date('2026-03-01T10:00:00.000Z'),
    updated_at: new Date('2026-03-01T10:00:01.000Z'),
    notification: {
      id: '123e4567-e89b-12d3-a456-426614174001',
      human_friendly_id: 'NTF-1001',
      tenant_id: actor.tenant_id,
      user_id: actor.id,
      title: 'Task',
      target_path: '/dashboard',
      tenant: {
        id: actor.tenant_id,
        human_friendly_id: 'TEN-1001',
        slug: 'tenant-1001',
        name: 'Tenant 1001',
      },
      user: {
        id: actor.id,
        human_friendly_id: 'USR-1001',
        email: 'doctor@example.com',
        phone: '+256700000000',
      },
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('lists notification deliveries for the scoped actor', async () => {
    notificationDeliveryRepository.findMany.mockResolvedValue([deliveryRecord]);
    notificationDeliveryRepository.count.mockResolvedValue(1);

    const result = await notificationDeliveryService.listNotificationDeliveries(
      {},
      1,
      20,
      'created_at',
      'desc',
      actor
    );

    expect(result.notificationDeliveries).toHaveLength(1);
    expect(result.notificationDeliveries[0]).toEqual(
      expect.objectContaining({
        id: 'NDL-1001',
        notification_id: 'NTF-1001',
        tenant_id: 'TEN-1001',
      })
    );
  });

  it('gets delivery by public id', async () => {
    notificationDeliveryRepository.findByIdentifier.mockResolvedValue(deliveryRecord);

    const result = await notificationDeliveryService.getNotificationDeliveryById('NDL-1001', actor);

    expect(result.id).toBe('NDL-1001');
    expect(result.notification_id).toBe('NTF-1001');
  });

  it('creates delivery with audit and realtime update', async () => {
    notificationDeliveryRepository.findNotificationByIdentifier.mockResolvedValue({
      id: deliveryRecord.notification_id,
      tenant_id: actor.tenant_id,
      user_id: actor.id,
      human_friendly_id: 'NTF-1001',
    });
    notificationDeliveryRepository.createPublicId.mockReturnValue('NDL-2000');
    notificationDeliveryRepository.create.mockResolvedValue({
      ...deliveryRecord,
      id: '123e4567-e89b-12d3-a456-426614174400',
      human_friendly_id: 'NDL-2000',
    });
    notificationDeliveryRepository.findById.mockResolvedValue({
      ...deliveryRecord,
      id: '123e4567-e89b-12d3-a456-426614174400',
      human_friendly_id: 'NDL-2000',
    });

    const result = await notificationDeliveryService.createNotificationDelivery(
      {
        notification_id: 'NTF-1001',
        channel: 'IN_APP',
        status: 'DELIVERED',
      },
      actor,
      '127.0.0.1'
    );

    expect(notificationDeliveryRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        notification_id: deliveryRecord.notification_id,
        human_friendly_id: 'NDL-2000',
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        action: 'CREATE',
      })
    );
    expect(emitToUser).toHaveBeenCalled();
    expect(result.id).toBe('NDL-2000');
  });

  it('updates delivery with audit and realtime update', async () => {
    notificationDeliveryRepository.findByIdentifier.mockResolvedValue(deliveryRecord);
    notificationDeliveryRepository.update.mockResolvedValue({ id: deliveryRecord.id });
    notificationDeliveryRepository.findById.mockResolvedValue({
      ...deliveryRecord,
      status: 'FAILED',
      retryable: true,
    });

    const result = await notificationDeliveryService.updateNotificationDelivery(
      'NDL-1001',
      { status: 'FAILED', retryable: true },
      actor,
      '127.0.0.1'
    );

    expect(notificationDeliveryRepository.update).toHaveBeenCalledWith(
      deliveryRecord.id,
      expect.objectContaining({
        status: 'FAILED',
        retryable: true,
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        action: 'UPDATE',
      })
    );
    expect(result.status).toBe('FAILED');
  });

  it('soft-deletes delivery with audit trail', async () => {
    notificationDeliveryRepository.findByIdentifier.mockResolvedValue(deliveryRecord);
    notificationDeliveryRepository.softDelete.mockResolvedValue({
      ...deliveryRecord,
      deleted_at: new Date(),
    });

    await notificationDeliveryService.deleteNotificationDelivery('NDL-1001', actor, '127.0.0.1');

    expect(notificationDeliveryRepository.softDelete).toHaveBeenCalledWith(deliveryRecord.id);
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        action: 'DELETE',
      })
    );
  });
});
