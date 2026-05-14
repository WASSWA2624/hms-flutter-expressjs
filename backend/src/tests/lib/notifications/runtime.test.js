jest.mock('@lib/notifications', () => ({
  sendEmail: jest.fn(),
}));

jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));

jest.mock('@lib/logging', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  NOTIFICATION_EVENTS: {
    NOTIFICATION_DELIVERY_UPDATED: 'notification.delivery_updated',
  },
}));

jest.mock('@lib/telemetry/metrics', () => ({
  markSpanError: jest.fn(),
  recordBackgroundJob: jest.fn(),
}));

describe('notification delivery runtime', () => {
  const buildDelivery = (overrides = {}) => ({
    id: 'delivery-1',
    human_friendly_id: 'NDL-1001',
    channel: 'EMAIL',
    status: 'QUEUED',
    recipient_target: 'doctor@example.com',
    provider_name: null,
    attempt_count: 0,
    last_attempt_at: null,
    retryable: true,
    notification: {
      id: 'notification-1',
      tenant_id: 'tenant-1',
      user_id: 'user-1',
      title: 'Queue update',
      message: 'Your report is ready.',
      target_path: '/reports',
      user: {
        email: 'doctor@example.com',
        phone: '+256700000000',
      },
    },
    ...overrides,
  });

  const loadRuntime = ({ tableRows, deliveries = [], runImmediate = false } = {}) => {
    jest.resetModules();

    const prismaMock = {
      $queryRawUnsafe: jest.fn().mockResolvedValue(tableRows || []),
      notification_delivery: {
        findMany: jest.fn().mockResolvedValue(deliveries),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        update: jest.fn().mockResolvedValue({ id: 'delivery-1', status: 'SENT', attempt_count: 1 }),
        findFirst: jest.fn().mockResolvedValue({
          id: 'delivery-1',
          channel: 'EMAIL',
          status: 'SENT',
          recipient_target: 'doctor@example.com',
          provider_name: 'smtp',
          attempt_count: 1,
          sent_at: new Date('2026-03-03T10:00:00.000Z'),
          delivered_at: null,
          failed_at: null,
          retryable: false,
          error_message: null,
          notification: {
            user_id: 'user-1',
          },
        }),
      },
    };

    jest.doMock('@prisma/client', () => prismaMock);

    const intervalHandle = { unref: jest.fn() };
    jest.spyOn(global, 'setInterval').mockReturnValue(intervalHandle);
    jest.spyOn(global, 'clearInterval').mockImplementation(() => {});
    jest.spyOn(global, 'setImmediate').mockImplementation((callback) => {
      if (runImmediate && typeof callback === 'function') {
        callback();
      }
      return intervalHandle;
    });

    const runtime = require('@lib/notifications/runtime');
    const { sendEmail } = require('@lib/notifications');
    const { emitToUser } = require('@lib/websocket');
    const { logger } = require('@lib/logging');

    return { runtime, prismaMock, sendEmail, emitToUser, logger };
  };

  afterEach(() => {
    jest.restoreAllMocks();
    jest.clearAllMocks();
  });

  it('dispatches queued email deliveries on startup', async () => {
    const { runtime, prismaMock, sendEmail } = loadRuntime({
      tableRows: [
        { table_name: 'notification' },
        { table_name: 'notification_delivery' },
      ],
      deliveries: [buildDelivery()],
      runImmediate: true,
    });

    sendEmail.mockResolvedValue({ sent: true, provider: 'smtp' });

    const started = await runtime.startNotificationDeliveryRuntime();
    await Promise.resolve();
    await Promise.resolve();

    expect(started).toBe(true);
    expect(prismaMock.notification_delivery.findMany).toHaveBeenCalled();
    expect(sendEmail).toHaveBeenCalledWith(expect.objectContaining({
      to: 'doctor@example.com',
      subject: 'Queue update',
    }));
    expect(prismaMock.notification_delivery.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: 'delivery-1',
          status: 'QUEUED',
        }),
      })
    );
    expect(prismaMock.notification_delivery.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'delivery-1' },
        data: expect.objectContaining({
          status: 'SENT',
          provider_name: 'smtp',
        }),
      })
    );
  });

  it('does not start when required notification tables are missing', async () => {
    const { runtime, prismaMock, logger } = loadRuntime({
      tableRows: [{ table_name: 'notification' }],
    });

    const started = await runtime.startNotificationDeliveryRuntime();

    expect(started).toBe(false);
    expect(global.setInterval).not.toHaveBeenCalled();
    expect(prismaMock.notification_delivery.findMany).not.toHaveBeenCalled();
    expect(logger.warn).toHaveBeenCalledWith(
      'Notification delivery runtime disabled',
      expect.objectContaining({
        reason: 'missing_notification_runtime_tables',
        missing_tables: ['notification_delivery'],
      })
    );
  });
});
