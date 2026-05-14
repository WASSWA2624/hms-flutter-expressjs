/**
 * Analytics event schema tests
 *
 * @module tests/modules/analytics-event/schemas
 * @description Tests for analytics event validation schemas
 */

const {
  createAnalyticsEventSchema,
  updateAnalyticsEventSchema,
  analyticsEventIdParamsSchema,
  listAnalyticsEventsQuerySchema,
} = require('@modules/analytics-event/schemas/analytics-event.schema');

describe('Analytics Event Schemas', () => {
  describe('createAnalyticsEventSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      user_id: '660e8400-e29b-41d4-a716-446655440000',
      event_name: 'page_view',
      event_category: 'navigation',
      severity: 'INFO',
      payload_json: { page: '/dashboard', duration: 5000 },
    };

    it('should validate correct analytics event data', () => {
      expect(createAnalyticsEventSchema.safeParse(validData).success).toBe(true);
    });

    it('should require event_name, event_category, and severity', () => {
      expect(createAnalyticsEventSchema.safeParse({ ...validData, event_name: undefined }).success).toBe(
        false
      );
      expect(
        createAnalyticsEventSchema.safeParse({ ...validData, event_category: undefined }).success
      ).toBe(false);
      expect(createAnalyticsEventSchema.safeParse({ ...validData, severity: undefined }).success).toBe(
        false
      );
    });

    it('should accept optional and nullable identifiers', () => {
      expect(createAnalyticsEventSchema.safeParse({ ...validData, tenant_id: undefined }).success).toBe(true);
      expect(createAnalyticsEventSchema.safeParse({ ...validData, user_id: null }).success).toBe(true);
      expect(createAnalyticsEventSchema.safeParse({ ...validData, facility_id: null }).success).toBe(true);
      expect(createAnalyticsEventSchema.safeParse({ ...validData, branch_id: null }).success).toBe(true);
    });

    it('should accept payload_json as optional and reject arrays', () => {
      expect(createAnalyticsEventSchema.safeParse({ ...validData, payload_json: undefined }).success).toBe(
        true
      );
      expect(createAnalyticsEventSchema.safeParse({ ...validData, payload_json: ['item1'] }).success).toBe(
        false
      );
    });

    it('should trim string fields', () => {
      const result = createAnalyticsEventSchema.safeParse({
        ...validData,
        event_name: '  page_view  ',
        event_category: '  navigation  ',
        entity_type: '  report  ',
        entity_public_id: '  KPI0000001  ',
      });

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.event_name).toBe('page_view');
        expect(result.data.event_category).toBe('navigation');
        expect(result.data.entity_type).toBe('report');
        expect(result.data.entity_public_id).toBe('KPI0000001');
      }
    });
  });

  describe('updateAnalyticsEventSchema', () => {
    it('should validate correct update data', () => {
      expect(
        updateAnalyticsEventSchema.safeParse({
          event_name: 'button_click',
          event_category: 'interaction',
          severity: 'WARNING',
          payload_json: { button: 'submit' },
          version: 2,
        }).success
      ).toBe(true);
    });

    it('should accept partial updates and nullable fields', () => {
      expect(updateAnalyticsEventSchema.safeParse({ event_name: 'Updated Event' }).success).toBe(true);
      expect(updateAnalyticsEventSchema.safeParse({ payload_json: null, occurred_at: null }).success).toBe(
        true
      );
      expect(updateAnalyticsEventSchema.safeParse({}).success).toBe(true);
    });
  });

  describe('analyticsEventIdParamsSchema', () => {
    it('should validate UUID and friendly identifiers', () => {
      expect(
        analyticsEventIdParamsSchema.safeParse({ id: '550e8400-e29b-41d4-a716-446655440000' }).success
      ).toBe(true);
      expect(analyticsEventIdParamsSchema.safeParse({ id: 'ANL0000001' }).success).toBe(true);
    });
  });

  describe('listAnalyticsEventsQuerySchema', () => {
    it('should validate empty query', () => {
      expect(listAnalyticsEventsQuerySchema.safeParse({}).success).toBe(true);
    });

    it('should validate current filter params', () => {
      expect(
        listAnalyticsEventsQuerySchema.safeParse({
          tenant_id: '550e8400-e29b-41d4-a716-446655440000',
          user_id: '660e8400-e29b-41d4-a716-446655440000',
          facility_id: '770e8400-e29b-41d4-a716-446655440000',
          branch_id: '880e8400-e29b-41d4-a716-446655440000',
          event_category: 'navigation',
          entity_type: 'report',
          severity: 'ERROR',
          search: 'click',
          since: '2026-01-01T00:00:00Z',
          from: '2026-01-01T00:00:00Z',
          to: '2026-01-31T23:59:59Z',
          page: '1',
          limit: '20',
          sort_by: 'event_name',
          order: 'asc',
        }).success
      ).toBe(true);
    });
  });
});
