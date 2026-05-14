/**
 * Notification schema tests
 *
 * @module tests/modules/notification/schemas
 * @description Tests for notification validation schemas
 * Per testing.mdc: Schema tests verify validation logic
 */

const {
  createNotificationSchema,
  updateNotificationSchema,
  notificationIdParamsSchema,
  listNotificationsQuerySchema
} = require('@validations/notification/notification.schema');

describe('Notification Schemas', () => {
  describe('createNotificationSchema', () => {
    it('should validate valid create data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        notification_type: 'SYSTEM',
        priority: 'MEDIUM',
        title: 'Test Notification',
        message: 'This is a test message'
      };

      const result = createNotificationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = createNotificationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid notification_type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        notification_type: 'INVALID_TYPE',
        priority: 'MEDIUM',
        title: 'Test',
        message: 'Test message'
      };

      const result = createNotificationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid priority', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        notification_type: 'SYSTEM',
        priority: 'INVALID_PRIORITY',
        title: 'Test',
        message: 'Test message'
      };

      const result = createNotificationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        notification_type: 'SYSTEM',
        priority: 'MEDIUM',
        title: 'Test',
        message: 'Test message'
      };

      const result = createNotificationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should accept valid notification types', () => {
      const types = ['SYSTEM', 'APPOINTMENT', 'BILLING', 'LAB', 'PHARMACY'];
      
      types.forEach(type => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          notification_type: type,
          priority: 'MEDIUM',
          title: 'Test',
          message: 'Test message'
        };
        const result = createNotificationSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should accept valid priorities', () => {
      const priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];
      
      priorities.forEach(priority => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          notification_type: 'SYSTEM',
          priority,
          title: 'Test',
          message: 'Test message'
        };
        const result = createNotificationSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should reject title exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        notification_type: 'SYSTEM',
        priority: 'MEDIUM',
        title: 'a'.repeat(256),
        message: 'Test message'
      };

      const result = createNotificationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should accept optional user_id as null', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: null,
        notification_type: 'SYSTEM',
        priority: 'MEDIUM',
        title: 'Test',
        message: 'Test message'
      };

      const result = createNotificationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });

  describe('updateNotificationSchema', () => {
    it('should validate valid update data', () => {
      const validData = {
        title: 'Updated Title',
        priority: 'HIGH'
      };

      const result = updateNotificationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept empty object for partial update', () => {
      const result = updateNotificationSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should reject invalid field values', () => {
      const invalidData = {
        notification_type: 'INVALID_TYPE'
      };

      const result = updateNotificationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('notificationIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = notificationIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'invalid-uuid'
      };

      const result = notificationIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const result = notificationIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });

    it('should validate friendly id params', () => {
      const validData = {
        id: 'NOT0000001'
      };

      const result = notificationIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });

  describe('listNotificationsQuerySchema', () => {
    it('should validate valid query params', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        priority: 'HIGH',
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      };

      const result = listNotificationsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept empty query params', () => {
      const result = listNotificationsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should transform is_read string to boolean', () => {
      const data = { is_read: 'true' };
      const result = listNotificationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(result.data.is_read).toBe(true);
    });

    it('should reject invalid enum values', () => {
      const invalidData = {
        notification_type: 'INVALID_TYPE'
      };

      const result = listNotificationsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should accept friendly identifiers in query filters', () => {
      const validData = {
        tenant_id: 'TEN0000001',
        user_id: 'USR0000003',
      };

      const result = listNotificationsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });
});
