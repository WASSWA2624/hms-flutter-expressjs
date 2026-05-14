/**
 * Dashboard widget schema tests
 *
 * @module tests/modules/dashboard-widget/schemas
 * @description Tests for dashboard widget validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createDashboardWidgetSchema,
  updateDashboardWidgetSchema,
  dashboardWidgetIdParamsSchema,
  listDashboardWidgetsQuerySchema,
  dashboardSummaryQuerySchema
} = require('../../../../modules/dashboard-widget/schemas/dashboard-widget.schema');

describe('Dashboard Widget Schemas', () => {
  describe('createDashboardWidgetSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      name: 'Sales Dashboard',
      widget_type: 'KPI',
      config_json: { layout: 'grid', columns: 3 }
    };

    it('should validate correct dashboard widget data', () => {
      const result = createDashboardWidgetSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow tenant_id to be omitted because scope can come from auth context', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should require name', () => {
      const data = { ...validData };
      delete data.name;
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require widget_type', () => {
      const data = { ...validData };
      delete data.widget_type;
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require config_json', () => {
      const data = { ...validData };
      delete data.config_json;
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim string fields', () => {
      const data = { ...validData, name: '  Sales Dashboard  ' };
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Sales Dashboard');
      }
    });

    it('should enforce max length for name', () => {
      const data = { ...validData, name: 'a'.repeat(256) };
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id format', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const data = { ...validData, name: '' };
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept complex config_json object', () => {
      const data = { 
        ...validData, 
        config_json: { 
          layout: 'grid', 
          columns: 3, 
          widgets: ['chart1', 'table1'], 
          settings: { theme: 'dark' } 
        } 
      };
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty config_json object', () => {
      const data = { ...validData, config_json: {} };
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject config_json as string', () => {
      const data = { ...validData, config_json: 'not an object' };
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject config_json as array', () => {
      const data = { ...validData, config_json: ['item1', 'item2'] };
      const result = createDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateDashboardWidgetSchema', () => {
    it('should validate correct update data', () => {
      const data = {
        name: 'Updated Dashboard',
        config_json: { layout: 'list', columns: 2 }
      };
      const result = updateDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept partial updates', () => {
      const data = { name: 'Updated Name' };
      const result = updateDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty object', () => {
      const result = updateDashboardWidgetSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should trim string fields', () => {
      const data = { name: '  Updated Name  ' };
      const result = updateDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Name');
      }
    });

    it('should enforce max length for name', () => {
      const data = { name: 'a'.repeat(256) };
      const result = updateDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const data = { name: '' };
      const result = updateDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept complex config_json object in updates', () => {
      const data = { 
        config_json: { 
          layout: 'flex', 
          responsive: true, 
          breakpoints: { sm: 576, md: 768 } 
        } 
      };
      const result = updateDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject config_json as non-object', () => {
      const data = { config_json: 'invalid' };
      const result = updateDashboardWidgetSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('dashboardWidgetIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = dashboardWidgetIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const data = { id: 'invalid-uuid' };
      const result = dashboardWidgetIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const data = {};
      const result = dashboardWidgetIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject non-string id', () => {
      const data = { id: 12345 };
      const result = dashboardWidgetIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listDashboardWidgetsQuerySchema', () => {
    it('should validate empty query', () => {
      const result = listDashboardWidgetsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate pagination params', () => {
      const data = { page: '1', limit: '20' };
      const result = listDashboardWidgetsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate sort params', () => {
      const data = { sort_by: 'name', order: 'asc' };
      const result = listDashboardWidgetsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate filter params', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Sales'
      };
      const result = listDashboardWidgetsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate search param', () => {
      const data = { search: 'dashboard' };
      const result = listDashboardWidgetsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid tenant_id format', () => {
      const data = { tenant_id: 'invalid-uuid' };
      const result = listDashboardWidgetsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim string query params', () => {
      const data = { name: '  Sales  ', search: '  dashboard  ' };
      const result = listDashboardWidgetsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Sales');
        expect(result.data.search).toBe('dashboard');
      }
    });

    it('should accept complete query with all params', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Dashboard',
        search: 'sales',
        placement: 'home',
        widget_type: 'KPI',
        is_pinned: 'true',
        page: '2',
        limit: '50',
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listDashboardWidgetsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.is_pinned).toBe(true);
      }
    });
  });

  describe('dashboardSummaryQuerySchema', () => {
    it('should allow empty query and default days to 7', () => {
      const result = dashboardSummaryQuerySchema.safeParse({});
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.days).toBe(7);
      }
    });

    it('should validate tenant/facility/branch UUID filters', () => {
      const result = dashboardSummaryQuerySchema.safeParse({
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        branch_id: '550e8400-e29b-41d4-a716-446655440002',
        days: 30
      });
      expect(result.success).toBe(true);
    });

    it('should reject days outside 1..30', () => {
      expect(dashboardSummaryQuerySchema.safeParse({ days: 0 }).success).toBe(false);
      expect(dashboardSummaryQuerySchema.safeParse({ days: 31 }).success).toBe(false);
    });
  });
});
