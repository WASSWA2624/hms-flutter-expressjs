const mockPrisma = {
  equipment_registry: {
    count: jest.fn(),
  },
  equipment_maintenance_plan: {
    count: jest.fn(),
  },
  equipment_work_order: {
    count: jest.fn(),
  },
  equipment_downtime_log: {
    count: jest.fn(),
  },
  equipment_recall_notice: {
    count: jest.fn(),
  },
  equipment_disposal_transfer: {
    findMany: jest.fn(),
    count: jest.fn(),
  },
};

jest.mock('@prisma/client', () => mockPrisma);

const biomedicalWorkspaceRepository = require('../../../../modules/biomedical-workspace/repositories/biomedical-workspace.repository');

describe('biomedical-workspace.repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    mockPrisma.equipment_registry.count.mockResolvedValue(0);
    mockPrisma.equipment_maintenance_plan.count.mockResolvedValue(0);
    mockPrisma.equipment_work_order.count.mockResolvedValue(0);
    mockPrisma.equipment_downtime_log.count.mockResolvedValue(0);
    mockPrisma.equipment_recall_notice.count.mockResolvedValue(0);
    mockPrisma.equipment_disposal_transfer.findMany.mockResolvedValue([]);
    mockPrisma.equipment_disposal_transfer.count.mockResolvedValue(0);
  });

  it('scopes summary counts by facility, equipment, and engineer filters', async () => {
    await biomedicalWorkspaceRepository.findSummary({
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      equipmentId: 'equipment-1',
      engineerId: 'engineer-1',
    });

    expect(mockPrisma.equipment_registry.count).toHaveBeenCalledWith({
      where: {
        tenant_id: 'tenant-1',
        deleted_at: null,
        facility_id: 'facility-1',
        id: 'equipment-1',
      },
    });

    expect(mockPrisma.equipment_maintenance_plan.count).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenant_id: 'tenant-1',
          deleted_at: null,
          equipment_registry_id: 'equipment-1',
          equipment_registry: { facility_id: 'facility-1' },
          is_active: true,
        }),
      })
    );

    expect(mockPrisma.equipment_work_order.count).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenant_id: 'tenant-1',
          deleted_at: null,
          equipment_registry_id: 'equipment-1',
          assigned_engineer_user_id: 'engineer-1',
          equipment_registry: { facility_id: 'facility-1' },
        }),
      })
    );
  });

  it('scopes queue counts by facility, equipment, and engineer filters', async () => {
    await biomedicalWorkspaceRepository.findQueueCounts({
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      equipmentId: 'equipment-1',
      engineerId: 'engineer-1',
    });

    expect(mockPrisma.equipment_maintenance_plan.count).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenant_id: 'tenant-1',
          equipment_registry_id: 'equipment-1',
          equipment_registry: { facility_id: 'facility-1' },
        }),
      })
    );

    expect(mockPrisma.equipment_work_order.count).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({
        where: expect.objectContaining({
          tenant_id: 'tenant-1',
          equipment_registry_id: 'equipment-1',
          assigned_engineer_user_id: 'engineer-1',
          equipment_registry: { facility_id: 'facility-1' },
        }),
      })
    );

    expect(mockPrisma.equipment_work_order.count).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        where: expect.objectContaining({
          tenant_id: 'tenant-1',
          equipment_registry_id: 'equipment-1',
          assigned_engineer_user_id: 'engineer-1',
          equipment_registry: { facility_id: 'facility-1' },
        }),
      })
    );
  });

  it('scopes disposal transfer list queries to the selected facility', async () => {
    await biomedicalWorkspaceRepository.findItems({
      resource: 'equipment-disposal-transfers',
      filters: {
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        equipmentId: 'equipment-1',
      },
      skip: 0,
      take: 20,
      orderBy: { updated_at: 'desc' },
    });

    expect(mockPrisma.equipment_disposal_transfer.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenant_id: 'tenant-1',
          deleted_at: null,
          equipment_registry_id: 'equipment-1',
          equipment_registry: { facility_id: 'facility-1' },
        }),
      })
    );

    expect(mockPrisma.equipment_disposal_transfer.count).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          equipment_registry: { facility_id: 'facility-1' },
        }),
      })
    );
  });
});
