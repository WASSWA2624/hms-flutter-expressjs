/**
 * Breach notification schema tests
 *
 * @module tests/modules/breach-notification/schemas
 * @description Tests for breach notification validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createBreachNotificationSchema,
  updateBreachNotificationSchema,
  resolveBreachNotificationSchema,
  breachNotificationIdParamsSchema,
  listBreachNotificationsQuerySchema
} = require('@validations/breach-notification/breach-notification.schema');

describe('Breach Notification Schemas', () => {
  describe('createBreachNotificationSchema', () => {
    const validData = {
      severity: 'HIGH',
      status: 'OPEN',
      description: 'Security breach detected in patient records system',
      reported_at: '2024-01-01T10:00:00Z'
    };

    it('should validate correct breach notification data', () => {
      const result = createBreachNotificationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require severity', () => {
      const data = { ...validData };
      delete data.severity;
      const result = createBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate severity enum values', () => {
      const data = { ...validData, severity: 'INVALID' };
      const result = createBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid severity values', () => {
      const severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
      severities.forEach(severity => {
        const data = { ...validData, severity };
        const result = createBreachNotificationSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['OPEN', 'INVESTIGATING', 'RESOLVED', 'REPORTED'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createBreachNotificationSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should default status to OPEN when not provided', () => {
      const data = { ...validData };
      delete data.status;
      const result = createBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.status).toBe('OPEN');
      }
    });

    it('should allow optional description', () => {
      const data = { ...validData };
      delete data.description;
      const result = createBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow nullable description', () => {
      const data = { ...validData, description: null };
      const result = createBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional reported_at', () => {
      const data = { ...validData };
      delete data.reported_at;
      const result = createBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate reported_at datetime format', () => {
      const data = { ...validData, reported_at: 'invalid-date' };
      const result = createBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateBreachNotificationSchema', () => {
    it('should validate update with all fields', () => {
      const data = {
        severity: 'CRITICAL',
        status: 'INVESTIGATING',
        description: 'Updated description',
        reported_at: '2024-01-02T10:00:00Z',
        resolved_at: '2024-01-03T10:00:00Z'
      };
      const result = updateBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { status: 'INVESTIGATING' };
      const result = updateBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty update object', () => {
      const data = {};
      const result = updateBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow nullable resolved_at', () => {
      const data = { resolved_at: null };
      const result = updateBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate resolved_at datetime format', () => {
      const data = { resolved_at: 'invalid-date' };
      const result = updateBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('resolveBreachNotificationSchema', () => {
    it('should validate resolve with resolved_at', () => {
      const data = { resolved_at: '2024-01-03T10:00:00Z' };
      const result = resolveBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional resolved_at', () => {
      const data = {};
      const result = resolveBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate resolved_at datetime format', () => {
      const data = { resolved_at: 'invalid-date' };
      const result = resolveBreachNotificationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('breachNotificationIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = breachNotificationIdParamsSchema.safeParse(params);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const params = { id: 'invalid-uuid' };
      const result = breachNotificationIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });
  });

  describe('listBreachNotificationsQuerySchema', () => {
    it('should validate query with all optional filters', () => {
      const query = {
        severity: 'HIGH',
        status: 'OPEN',
        from_date: '2024-01-01T00:00:00Z',
        to_date: '2024-01-31T23:59:59Z',
        page: 1,
        limit: 20
      };
      const result = listBreachNotificationsQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should validate query with no filters', () => {
      const query = {};
      const result = listBreachNotificationsQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should validate severity filter', () => {
      const query = { severity: 'INVALID' };
      const result = listBreachNotificationsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });

    it('should validate status filter', () => {
      const query = { status: 'INVALID' };
      const result = listBreachNotificationsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });

    it('should validate from_date format', () => {
      const query = { from_date: 'invalid-date' };
      const result = listBreachNotificationsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });

    it('should validate to_date format', () => {
      const query = { to_date: 'invalid-date' };
      const result = listBreachNotificationsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });
  });
});
