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
  emitToUser: jest.fn(),
  NOTIFICATION_EVENTS: {
    NOTIFICATION_DELIVERY_UPDATED: 'notification.delivery_updated',
  },
}));

const notificationDeliveryService = require('@services/notification-delivery/notification-delivery.service');
const notificationDeliveryRepository = require('@repositories/notification-delivery/notification-delivery.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { createAuditLog } = require('@lib/audit');

/**
 * Deliveries tab may open delivery records via notification-delivery handlers.
 * Those handlers stay NOT_BILLED operational logs — no patient Billing posts.
 */
describe('notification-delivery billing-sections (Deliveries tab)', () => {
  const actor = {
    id: '123e4567-e89b-12d3-a456-426614174099',
    tenant_id: '123e4567-e89b-12d3-a456-426614174010',
    roles: ['FACILITY_ADMIN'],
  };

  const deliveryRecord = {
    id: '123e4567-e89b-12d3-a456-426614174321',
    human_friendly_id: 'NDL-1001',
    notification_id: '123e4567-e89b-12d3-a456-426614174001',
    channel: 'SMS',
    status: 'DELIVERED',
    recipient_target: '+256700000000',
    provider_name: 'AFRICAS_TALKING',
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
      title: 'Appointment reminder',
      target_path: '/patients/patient-1',
      tenant: {
        id: actor.tenant_id,
        human_friendly_id: 'TEN-1001',
        slug: 'tenant-1001',
        name: 'Tenant 1001',
      },
      user: {
        id: actor.id,
        human_friendly_id: 'USR-1001',
        email: 'admin@example.com',
        phone: '+256700000000',
      },
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('list deliveries stays NOT_BILLED (no patient ledger post)', async () => {
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
    expect(result.notificationDeliveries[0].id).toBe('NDL-1001');
    expect(result.notificationDeliveries[0]).not.toHaveProperty('payment_status');
    expect(result.notificationDeliveries[0]).not.toHaveProperty('balance');
    expect(result.notificationDeliveries[0]).not.toHaveProperty('amount_due');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('get delivery by id stays NOT_BILLED and is idempotent on replay', async () => {
    notificationDeliveryRepository.findByIdentifier.mockResolvedValue(deliveryRecord);

    const first = await notificationDeliveryService.getNotificationDeliveryById(
      'NDL-1001',
      actor
    );
    const second = await notificationDeliveryService.getNotificationDeliveryById(
      'NDL-1001',
      actor
    );

    expect(first.id).toBe('NDL-1001');
    expect(first.status).toBe('DELIVERED');
    expect(first).toEqual(second);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('create delivery audit stays NOT_BILLED (no Billing post)', async () => {
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
        channel: 'SMS',
        status: 'QUEUED',
      },
      actor,
      '127.0.0.1'
    );

    expect(result.id).toBe('NDL-2000');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'notification_delivery',
      })
    );
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('update delivery status stays NOT_BILLED (ops status ≠ payment status)', async () => {
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

    expect(result.status).toBe('FAILED');
    expect(result).not.toHaveProperty('payment_status');
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('non-admin recipient cannot settle via delivery handlers', async () => {
    const nonAdmin = {
      id: '123e4567-e89b-12d3-a456-426614174088',
      tenant_id: actor.tenant_id,
      roles: ['DOCTOR'],
    };
    notificationDeliveryRepository.findByIdentifier.mockResolvedValue(deliveryRecord);

    await expect(
      notificationDeliveryService.getNotificationDeliveryById('NDL-1001', nonAdmin)
    ).rejects.toMatchObject({ statusCode: 404 });

    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
