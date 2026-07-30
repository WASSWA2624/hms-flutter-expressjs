jest.mock('@repositories/biomedical-workspace/biomedical-workspace.repository');
jest.mock('@repositories/equipment-work-order/equipment-work-order.repository');
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
  emitToUsers: jest.fn(),
  BIOMEDICAL_EVENTS: {
    BIOMEDICAL_FAULT_REPORTED: 'biomedical.fault_reported',
    BIOMEDICAL_WORKSPACE_UPDATED: 'biomedical.workspace_updated',
    BIOMEDICAL_WORK_ORDER_ASSIGNED: 'biomedical.work_order_assigned',
  },
  NOTIFICATION_EVENTS: {
    NOTIFICATION_CREATED: 'notification.created',
  },
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: (...values) =>
    values.find((entry) => typeof entry === 'string' && entry.trim()) || null,
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || undefined),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value || undefined),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
}));

const biomedicalWorkspaceRepository = require('@repositories/biomedical-workspace/biomedical-workspace.repository');
const equipmentWorkOrderRepository = require('@repositories/equipment-work-order/equipment-work-order.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const biomedicalWorkspaceService = require('@services/biomedical-workspace/biomedical-workspace.service');
const {
  createEquipmentWorkOrder,
} = require('@services/equipment-work-order/equipment-work-order.service');

describe('biomedical Analytics billing-sections scan', () => {
  const scopedUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    permissions: ['biomed:read', 'biomed:write', 'reports:read'],
  };

  const utilizationItem = {
    id: 'util-uuid',
    human_friendly_id: 'UTIL-001',
    name: 'Ventilator utilization',
    status: 'ACTIVE',
    captured_at: new Date('2026-07-01T08:00:00.000Z'),
    updated_at: new Date('2026-07-01T08:00:00.000Z'),
    created_at: new Date('2026-07-01T08:00:00.000Z'),
    equipment_registry_id: 'equipment-uuid',
    equipment_registry: {
      id: 'equipment-uuid',
      human_friendly_id: 'EQ-001',
      equipment_name: 'Ventilator A',
      equipment_code: 'VENT-A',
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    equipmentWorkOrderRepository.findRecipientUserIds.mockResolvedValue([]);
    biomedicalWorkspaceRepository.findSummary.mockResolvedValue({
      total_equipment: 1,
      overdue_pm: 0,
      open_work_orders: 0,
      critical_downtime: 0,
      active_recalls: 0,
    });
    biomedicalWorkspaceRepository.findQueueCounts.mockResolvedValue({
      OVERDUE_PM: 0,
      OPEN_WORK_ORDERS: 0,
      CRITICAL_DOWNTIME: 0,
      RECALL_ACTIONS: 0,
      RETURN_TO_SERVICE: 0,
    });
    biomedicalWorkspaceRepository.findItems.mockResolvedValue({
      items: [utilizationItem],
      total: 1,
    });
    biomedicalWorkspaceRepository.findLookups.mockResolvedValue({
      facilities: [
        {
          id: 'facility-123',
          human_friendly_id: 'FAC-001',
          name: 'Main Facility',
          facility_type: 'HOSPITAL',
        },
      ],
      rooms: [],
      equipment: [
        {
          id: 'equipment-uuid',
          human_friendly_id: 'EQ-001',
          equipment_name: 'Ventilator A',
          equipment_code: 'VENT-A',
          status: 'ACTIVE',
        },
      ],
      categories: [],
      providers: [],
      engineerRoles: [],
    });
  });

  it('Analytics panel workspace read does not touch patient billing ledger', async () => {
    const data = await biomedicalWorkspaceService.getWorkspace(
      { panel: 'analytics' },
      1,
      20,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.filters.panel).toBe('analytics');
    expect(data.filters.resource).toBe('equipment-utilization-snapshots');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].id).toBe('UTIL-001');
    expect(data.items[0].resource).toBe('equipment-utilization-snapshots');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('Analytics workspace GET is idempotent on replay (no double billing post)', async () => {
    const query = { panel: 'analytics' };
    const first = await biomedicalWorkspaceService.getWorkspace(
      query,
      1,
      20,
      undefined,
      'desc',
      scopedUser
    );
    const second = await biomedicalWorkspaceService.getWorkspace(
      query,
      1,
      20,
      undefined,
      'desc',
      scopedUser
    );

    expect(first.items).toEqual(second.items);
    expect(biomedicalWorkspaceRepository.findItems).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('serializes utilization items without local paid flags or balances', async () => {
    const data = await biomedicalWorkspaceService.getWorkspace(
      { panel: 'analytics' },
      1,
      20,
      undefined,
      'desc',
      scopedUser
    );
    const item = data.items[0];

    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount_due');
    expect(item).not.toHaveProperty('paid');
    expect(item).not.toHaveProperty('invoice_id');
  });

  it('internal work-order create from Analytics detail stays NOT_BILLED', async () => {
    equipmentWorkOrderRepository.create.mockResolvedValue({
      id: 'work-order-uuid',
      human_friendly_id: 'BWO-001',
      title: 'Service ventilator',
      status: 'OPEN',
      priority: 'NORMAL',
      equipment_registry_id: 'equipment-uuid',
      equipment_registry: {
        id: 'equipment-uuid',
        human_friendly_id: 'EQ-001',
        equipment_name: 'Ventilator A',
        tenant_id: 'tenant-123',
      },
      created_at: new Date('2026-07-01T08:00:00.000Z'),
      updated_at: new Date('2026-07-01T08:00:00.000Z'),
    });

    const result = await createEquipmentWorkOrder(
      {
        tenant_id: 'tenant-123',
        equipment_registry_id: 'EQ-001',
        title: 'Service ventilator',
        description: 'Internal maintenance from Analytics detail',
        priority: 'NORMAL',
        status: 'OPEN',
      },
      {
        user: scopedUser,
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '127.0.0.1',
      }
    );

    expect(result.id).toBe('BWO-001');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('work-order create replay does not duplicate billing posts', async () => {
    equipmentWorkOrderRepository.create.mockResolvedValue({
      id: 'work-order-uuid',
      human_friendly_id: 'BWO-001',
      title: 'Service ventilator',
      status: 'OPEN',
      priority: 'NORMAL',
      equipment_registry: {
        id: 'equipment-uuid',
        human_friendly_id: 'EQ-001',
        equipment_name: 'Ventilator A',
        tenant_id: 'tenant-123',
      },
    });

    const payload = {
      tenant_id: 'tenant-123',
      equipment_registry_id: 'EQ-001',
      title: 'Service ventilator',
      status: 'OPEN',
    };
    const context = {
      user: scopedUser,
      user_id: 'user-123',
      tenant_id: 'tenant-123',
      ip_address: '127.0.0.1',
    };

    await createEquipmentWorkOrder(payload, context);
    await createEquipmentWorkOrder(payload, context);

    expect(equipmentWorkOrderRepository.create).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('unauthorized actor without write scopes still cannot settle via Analytics handlers', async () => {
    // Analytics workspace GET is read-scoped; settling patient balance is never
    // exposed on this path regardless of caller permissions.
    await biomedicalWorkspaceService.getWorkspace(
      { panel: 'analytics' },
      1,
      20,
      undefined,
      'desc',
      {
        id: 'user-readonly',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        permissions: ['biomed:read', 'reports:read'],
      }
    );

    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
