/**
 * KPI snapshot schema tests
 *
 * @module tests/modules/kpi-snapshot/schemas
 * @description Tests for KPI snapshot validation schemas
 */

const {
  createKpiSnapshotSchema,
  updateKpiSnapshotSchema,
  kpiSnapshotIdParamsSchema,
  listKpiSnapshotsQuerySchema,
} = require('@modules/kpi-snapshot/schemas/kpi-snapshot.schema');

describe('KPI Snapshot Schemas', () => {
  describe('createKpiSnapshotSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      name: 'Revenue',
      metric_key: 'daily_revenue',
      metric_group: 'finance',
      threshold_state: 'NORMAL',
      value: '12500.50',
    };

    it('should validate correct KPI snapshot data', () => {
      expect(createKpiSnapshotSchema.safeParse(validData).success).toBe(true);
    });

    it('should require name, metric_key, metric_group, threshold_state, and value', () => {
      expect(createKpiSnapshotSchema.safeParse({ ...validData, name: undefined }).success).toBe(false);
      expect(createKpiSnapshotSchema.safeParse({ ...validData, metric_key: undefined }).success).toBe(false);
      expect(createKpiSnapshotSchema.safeParse({ ...validData, metric_group: undefined }).success).toBe(
        false
      );
      expect(
        createKpiSnapshotSchema.safeParse({ ...validData, threshold_state: undefined }).success
      ).toBe(false);
      expect(createKpiSnapshotSchema.safeParse({ ...validData, value: undefined }).success).toBe(false);
    });

    it('should accept recorded_at as optional', () => {
      expect(
        createKpiSnapshotSchema.safeParse({
          ...validData,
          recorded_at: '2026-01-19T12:00:00Z',
        }).success
      ).toBe(true);
    });

    it('should accept both numeric strings and numbers for value', () => {
      expect(createKpiSnapshotSchema.safeParse({ ...validData, value: '123.45678' }).success).toBe(true);
      expect(createKpiSnapshotSchema.safeParse({ ...validData, value: 123.45678 }).success).toBe(true);
    });

    it('should trim string fields', () => {
      const result = createKpiSnapshotSchema.safeParse({
        ...validData,
        name: '  Revenue  ',
        metric_key: '  daily_revenue  ',
        metric_group: '  finance  ',
        value: '  123.45  ',
      });

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Revenue');
        expect(result.data.metric_key).toBe('daily_revenue');
        expect(result.data.metric_group).toBe('finance');
        expect(result.data.value).toBe(123.45);
      }
    });
  });

  describe('updateKpiSnapshotSchema', () => {
    it('should validate correct update data', () => {
      expect(
        updateKpiSnapshotSchema.safeParse({
          name: 'Updated Revenue',
          metric_key: 'revenue_delta',
          metric_group: 'finance',
          threshold_state: 'WARNING',
          value: '15000.75',
          version: 2,
        }).success
      ).toBe(true);
    });

    it('should accept partial updates and empty objects', () => {
      expect(updateKpiSnapshotSchema.safeParse({ name: 'Updated Name' }).success).toBe(true);
      expect(updateKpiSnapshotSchema.safeParse({}).success).toBe(true);
    });

    it('should accept nullable recorded_at', () => {
      expect(updateKpiSnapshotSchema.safeParse({ recorded_at: null }).success).toBe(true);
    });
  });

  describe('kpiSnapshotIdParamsSchema', () => {
    it('should validate UUID and friendly identifiers', () => {
      expect(kpiSnapshotIdParamsSchema.safeParse({ id: '550e8400-e29b-41d4-a716-446655440000' }).success).toBe(
        true
      );
      expect(kpiSnapshotIdParamsSchema.safeParse({ id: 'KPI0000001' }).success).toBe(true);
    });
  });

  describe('listKpiSnapshotsQuerySchema', () => {
    it('should validate empty query', () => {
      expect(listKpiSnapshotsQuerySchema.safeParse({}).success).toBe(true);
    });

    it('should validate current filter params', () => {
      expect(
        listKpiSnapshotsQuerySchema.safeParse({
          tenant_id: '550e8400-e29b-41d4-a716-446655440000',
          facility_id: '550e8400-e29b-41d4-a716-446655440001',
          branch_id: '550e8400-e29b-41d4-a716-446655440002',
          metric_key: 'daily_revenue',
          metric_group: 'finance',
          threshold_state: 'CRITICAL',
          search: 'revenue',
          since: '2026-01-01T00:00:00Z',
          from: '2026-01-01T00:00:00Z',
          to: '2026-01-31T23:59:59Z',
          page: '1',
          limit: '20',
          sort_by: 'name',
          order: 'asc',
        }).success
      ).toBe(true);
    });
  });
});
