/**
 * Dashboard widget repository tests
 *
 * @module tests/modules/dashboard-widget/repositories
 * @description Tests for dashboard widget repository operations
 * Per testing.mdc: Comprehensive repository tests with mocked Prisma client
 */

const dashboardWidgetRepository = require('@modules/dashboard-widget/repositories/dashboard-widget.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  dashboard_widget: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  },
  notification: {
    count: jest.fn()
  }
}));

describe('Dashboard Widget Repository', () => {
  const defaultIncludeMatcher = expect.objectContaining({
    tenant: expect.any(Object),
    report_definition: expect.any(Object),
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  const mockDashboardWidget = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    tenant_id: '660e8400-e29b-41d4-a716-446655440000',
    name: 'Sales Dashboard',
    config_json: { layout: 'grid' },
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  describe('findById', () => {
    it('should find dashboard widget by ID', async () => {
      prisma.dashboard_widget.findFirst.mockResolvedValue(mockDashboardWidget);

      const result = await dashboardWidgetRepository.findById(mockDashboardWidget.id);

      expect(result).toEqual(mockDashboardWidget);
      expect(prisma.dashboard_widget.findFirst).toHaveBeenCalledWith({
        where: { id: mockDashboardWidget.id, deleted_at: null },
        include: defaultIncludeMatcher,
      });
    });

    it('should return null if dashboard widget not found', async () => {
      prisma.dashboard_widget.findFirst.mockResolvedValue(null);

      const result = await dashboardWidgetRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.dashboard_widget.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(dashboardWidgetRepository.findById('some-id')).rejects.toThrow(HttpError);
    });

    it('should accept include parameter', async () => {
      prisma.dashboard_widget.findFirst.mockResolvedValue(mockDashboardWidget);

      await dashboardWidgetRepository.findById(mockDashboardWidget.id, { tenant: true });

      expect(prisma.dashboard_widget.findFirst).toHaveBeenCalledWith({
        where: { id: mockDashboardWidget.id, deleted_at: null },
        include: expect.objectContaining({
          tenant: true,
          report_definition: expect.any(Object),
        }),
      });
    });
  });

  describe('findMany', () => {
    it('should find dashboard widgets with default parameters', async () => {
      prisma.dashboard_widget.findMany.mockResolvedValue([mockDashboardWidget]);

      const result = await dashboardWidgetRepository.findMany();

      expect(result).toEqual([mockDashboardWidget]);
      expect(prisma.dashboard_widget.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: defaultIncludeMatcher,
      });
    });

    it('should apply filters correctly', async () => {
      const filters = { tenant_id: mockDashboardWidget.tenant_id };
      prisma.dashboard_widget.findMany.mockResolvedValue([mockDashboardWidget]);

      await dashboardWidgetRepository.findMany(filters);

      expect(prisma.dashboard_widget.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: defaultIncludeMatcher,
      });
    });

    it('should apply pagination correctly', async () => {
      prisma.dashboard_widget.findMany.mockResolvedValue([mockDashboardWidget]);

      await dashboardWidgetRepository.findMany({}, 10, 5);

      expect(prisma.dashboard_widget.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 10,
        take: 5,
        orderBy: { created_at: 'desc' },
        include: defaultIncludeMatcher,
      });
    });

    it('should apply custom orderBy', async () => {
      prisma.dashboard_widget.findMany.mockResolvedValue([mockDashboardWidget]);

      await dashboardWidgetRepository.findMany({}, 0, 20, { name: 'asc' });

      expect(prisma.dashboard_widget.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' },
        include: defaultIncludeMatcher,
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.dashboard_widget.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(dashboardWidgetRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count dashboard widgets with default filters', async () => {
      prisma.dashboard_widget.count.mockResolvedValue(10);

      const result = await dashboardWidgetRepository.count();

      expect(result).toBe(10);
      expect(prisma.dashboard_widget.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should apply filters when counting', async () => {
      const filters = { tenant_id: mockDashboardWidget.tenant_id };
      prisma.dashboard_widget.count.mockResolvedValue(5);

      const result = await dashboardWidgetRepository.count(filters);

      expect(result).toBe(5);
      expect(prisma.dashboard_widget.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.dashboard_widget.count.mockRejectedValue(new Error('DB Error'));

      await expect(dashboardWidgetRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create dashboard widget', async () => {
      const createData = {
        tenant_id: mockDashboardWidget.tenant_id,
        name: mockDashboardWidget.name,
        config_json: mockDashboardWidget.config_json
      };
      prisma.dashboard_widget.create.mockResolvedValue(mockDashboardWidget);

      const result = await dashboardWidgetRepository.create(createData);

      expect(result).toEqual(mockDashboardWidget);
      expect(prisma.dashboard_widget.create).toHaveBeenCalledWith({
        data: createData,
        include: defaultIncludeMatcher,
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.dashboard_widget.create.mockRejectedValue(error);

      await expect(dashboardWidgetRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.dashboard_widget.create.mockRejectedValue(error);

      await expect(dashboardWidgetRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.dashboard_widget.create.mockRejectedValue(new Error('DB Error'));

      await expect(dashboardWidgetRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update dashboard widget', async () => {
      const updateData = { name: 'Updated Dashboard' };
      const updated = { ...mockDashboardWidget, ...updateData };
      prisma.dashboard_widget.update.mockResolvedValue(updated);

      const result = await dashboardWidgetRepository.update(mockDashboardWidget.id, updateData);

      expect(result).toEqual(updated);
      expect(prisma.dashboard_widget.update).toHaveBeenCalledWith({
        where: { id: mockDashboardWidget.id },
        data: updateData,
        include: defaultIncludeMatcher,
      });
    });

    it('should throw HttpError when dashboard widget not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.dashboard_widget.update.mockRejectedValue(error);

      await expect(dashboardWidgetRepository.update('non-existent', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.dashboard_widget.update.mockRejectedValue(error);

      await expect(dashboardWidgetRepository.update(mockDashboardWidget.id, {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.dashboard_widget.update.mockRejectedValue(new Error('DB Error'));

      await expect(dashboardWidgetRepository.update(mockDashboardWidget.id, {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete dashboard widget', async () => {
      const deleted = { ...mockDashboardWidget, deleted_at: new Date() };
      prisma.dashboard_widget.update.mockResolvedValue(deleted);

      const result = await dashboardWidgetRepository.softDelete(mockDashboardWidget.id);

      expect(result.deleted_at).toBeTruthy();
      expect(prisma.dashboard_widget.update).toHaveBeenCalledWith({
        where: { id: mockDashboardWidget.id },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when dashboard widget not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.dashboard_widget.update.mockRejectedValue(error);

      await expect(dashboardWidgetRepository.softDelete('non-existent')).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.dashboard_widget.update.mockRejectedValue(new Error('DB Error'));

      await expect(dashboardWidgetRepository.softDelete(mockDashboardWidget.id)).rejects.toThrow(HttpError);
    });
  });

  describe('relation-scoped where builders', () => {
    const scope = {
      tenant_id: '660e8400-e29b-41d4-a716-446655440000',
      facility_id: '770e8400-e29b-41d4-a716-446655440000'
    };

    it('builds lab order scope via patient relation chain', () => {
      const where = dashboardWidgetRepository.__private__.buildLabOrderScopeWhere(scope);
      expect(where).toEqual({
        deleted_at: null,
        patient: {
          deleted_at: null,
          tenant_id: scope.tenant_id,
          facility_id: scope.facility_id
        }
      });
    });

    it('builds lab result scope via lab_order_item -> lab_order -> patient chain', () => {
      const where = dashboardWidgetRepository.__private__.buildLabResultScopeWhere(scope);
      expect(where).toEqual({
        deleted_at: null,
        lab_order_item: {
          deleted_at: null,
          lab_order: {
            deleted_at: null,
            patient: {
              deleted_at: null,
              tenant_id: scope.tenant_id,
              facility_id: scope.facility_id
            }
          }
        }
      });
    });

    it('builds pharmacy order and dispense-log relation scopes via patient chain', () => {
      const orderWhere = dashboardWidgetRepository.__private__.buildPharmacyOrderScopeWhere(scope);
      expect(orderWhere).toEqual({
        deleted_at: null,
        patient: {
          deleted_at: null,
          tenant_id: scope.tenant_id,
          facility_id: scope.facility_id
        }
      });

      const dispenseWhere = dashboardWidgetRepository.__private__.buildDispenseLogScopeWhere(scope);
      expect(dispenseWhere).toEqual({
        deleted_at: null,
        pharmacy_order_item: {
          deleted_at: null,
          pharmacy_order: {
            deleted_at: null,
            patient: {
              deleted_at: null,
              tenant_id: scope.tenant_id,
              facility_id: scope.facility_id
            }
          }
        }
      });
    });

    it('builds inventory and ambulance relation scopes', () => {
      const inventoryWhere = dashboardWidgetRepository.__private__.buildInventoryStockScopeWhere(scope);
      expect(inventoryWhere).toEqual({
        deleted_at: null,
        inventory_item: {
          deleted_at: null,
          tenant_id: scope.tenant_id
        },
        facility_id: scope.facility_id
      });

      const dispatchWhere = dashboardWidgetRepository.__private__.buildAmbulanceDispatchScopeWhere(scope);
      expect(dispatchWhere).toEqual({
        deleted_at: null,
        emergency_case: {
          deleted_at: null,
          tenant_id: scope.tenant_id,
          facility_id: scope.facility_id
        }
      });

      const tripWhere = dashboardWidgetRepository.__private__.buildAmbulanceTripScopeWhere(scope);
      expect(tripWhere).toEqual({
        deleted_at: null,
        emergency_case: {
          deleted_at: null,
          tenant_id: scope.tenant_id,
          facility_id: scope.facility_id
        }
      });
    });
  });

  describe('countUnreadOpdNotifications', () => {
    it('counts unread OPD notifications scoped to user and tenant', async () => {
      prisma.notification.count.mockResolvedValue(5);

      const result = await dashboardWidgetRepository.countUnreadOpdNotifications({
        scope: { tenant_id: 'tenant-1' },
        userId: 'user-1',
      });

      expect(result).toBe(5);
      expect(prisma.notification.count).toHaveBeenCalledWith({
        where: expect.objectContaining({
          deleted_at: null,
          read_at: null,
          tenant_id: 'tenant-1',
          user_id: 'user-1',
          AND: expect.any(Array),
        }),
      });

      const whereArg = prisma.notification.count.mock.calls[0]?.[0]?.where;
      expect(whereArg.AND).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            AND: expect.arrayContaining([
              expect.objectContaining({ notification_type: 'SYSTEM' }),
              expect.objectContaining({
                OR: expect.arrayContaining([
                  expect.objectContaining({ title: { contains: 'OPD flow update' } }),
                  expect.objectContaining({ message: { contains: 'triage' } }),
                ]),
              }),
            ]),
          }),
        ])
      );
    });

    it('throws HttpError on notification count failure', async () => {
      prisma.notification.count.mockRejectedValue(new Error('DB Error'));

      await expect(
        dashboardWidgetRepository.countUnreadOpdNotifications({ scope: { tenant_id: 'tenant-1' } })
      ).rejects.toThrow(HttpError);
    });
  });
});
