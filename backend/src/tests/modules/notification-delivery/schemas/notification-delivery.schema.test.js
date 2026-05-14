const {
  createNotificationDeliverySchema,
  updateNotificationDeliverySchema,
  notificationDeliveryIdParamsSchema,
  listNotificationDeliveriesQuerySchema,
} = require('@validations/notification-delivery/notification-delivery.schema');

describe('notification-delivery.schema', () => {
  describe('createNotificationDeliverySchema', () => {
    it('accepts valid payload', () => {
      const result = createNotificationDeliverySchema.safeParse({
        notification_id: 'NTF-1001',
        channel: 'IN_APP',
        status: 'QUEUED',
        recipient_target: 'doctor@example.com',
        attempt_count: 0,
      });
      expect(result.success).toBe(true);
    });

    it('rejects unsupported channel', () => {
      const result = createNotificationDeliverySchema.safeParse({
        notification_id: 'NTF-1001',
        channel: 'FAX',
      });
      expect(result.success).toBe(false);
    });

    it('rejects unsupported status', () => {
      const result = createNotificationDeliverySchema.safeParse({
        notification_id: 'NTF-1001',
        channel: 'IN_APP',
        status: 'PROCESSING',
      });
      expect(result.success).toBe(false);
    });
  });

  describe('updateNotificationDeliverySchema', () => {
    it('accepts partial updates', () => {
      const result = updateNotificationDeliverySchema.safeParse({
        status: 'FAILED',
        retryable: true,
        error_message: 'Provider timeout',
      });
      expect(result.success).toBe(true);
    });
  });

  describe('notificationDeliveryIdParamsSchema', () => {
    it('accepts uuid or friendly id', () => {
      expect(
        notificationDeliveryIdParamsSchema.safeParse({
          id: '123e4567-e89b-12d3-a456-426614174000',
        }).success
      ).toBe(true);
      expect(
        notificationDeliveryIdParamsSchema.safeParse({
          id: 'NDL-1001',
        }).success
      ).toBe(true);
    });
  });

  describe('listNotificationDeliveriesQuerySchema', () => {
    it('accepts query filters', () => {
      const result = listNotificationDeliveriesQuerySchema.safeParse({
        notification_id: 'NTF-1001',
        channel: 'IN_APP',
        status: 'DELIVERED',
        retryable: 'false',
        sort_by: 'created_at',
        order: 'desc',
      });
      expect(result.success).toBe(true);
      expect(result.data.retryable).toBe(false);
    });
  });
});
