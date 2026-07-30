jest.mock('@repositories/biomedical-workspace/biomedical-workspace.repository');
jest.mock('@repositories/equipment-maintenance-plan/equipment-maintenance-plan.repository');
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
const equipmentMaintenancePlanRepository = require('@repositories/equipment-maintenance-plan/equipment-maintenance-plan.repository');
const equipmentWorkOrderRepository = require('@repositories/equipment-work-order/equipment-work-order.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const biomedicalWorkspaceService = require('@services/biomedical-workspace/biomedical-workspace.service');
const {
  createEquipmentMaintenancePlan,
} = require('@services/equipment-maintenance-plan/equipment-maintenance-plan.service');
const {
  createEquipmentWorkOrder,
} = require('@services/equipment-work-order/equipment-work-order.service');

describe('biomedical Preventive billing-sections scan', () => {
  const scopedUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    permissions: ['biomed:read', 'biomed:write'],
  };

  const maintenancePlanItem = {
    id: 'plan-uuid',
    human_friendly_id: 'PM-100',
    plan_name: 'Ventilator PM plan',
    name: 'Ventilator PM plan',
    status: 'DUE',
    maintenance_type: 'PREVENTIVE',
    next_due_at: new Date('2026-08-01T08:00:00.000Z'),
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
      overdue_pm: 1,
      open_work_orders: 0,
      critical_downtime: 0,
      active_recalls: 0,
    });
    biomedicalWorkspaceRepository.findQueueCounts.mockResolvedValue({
      OVERDUE_PM: 1,
      OPEN_WORK_ORDERS: 0,
      CRITICAL_DOWNTIME: 0,
      RECALL_ACTIONS: 0,
      RETURN_TO_SERVICE: 0,
    });
    biomedicalWorkspaceRepository.findItems.mockResolvedValue({
      items: [maintenancePlanItem],
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

  it('Preventive panel workspace read does not touch patient billing ledger', async () => {
    const data = await biomedicalWorkspaceService.getWorkspace(
      { panel: 'preventive' },
      1,
      20,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.filters.panel).toBe('preventive');
    expect(data.filters.resource).toBe('equipment-maintenance-plans');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].id).toBe('PM-100');
    expect(data.items[0].resource).toBe('equipment-maintenance-plans');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('Preventive workspace GET is idempotent on replay (no double billing post)', async () => {
    const query = { panel: 'preventive' };
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

  it('serializes maintenance-plan items without local paid flags or balances', async () => {
    const data = await biomedicalWorkspaceService.getWorkspace(
      { panel: 'preventive' },
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

  it('Schedule maintenance create stays NOT_BILLED (no patient ledger post)', async () => {
    equipmentMaintenancePlanRepository.create.mockResolvedValue({
      id: 'plan-uuid',
      human_friendly_id: 'PM-100',
      plan_name: 'Quarterly PM',
      status: 'SCHEDULED',
      tenant_id: 'tenant-123',
      equipment_registry_id: 'equipment-uuid',
      created_at: new Date('2026-07-01T08:00:00.000Z'),
      updated_at: new Date('2026-07-01T08:00:00.000Z'),
    });

    const result = await createEquipmentMaintenancePlan(
      {
        tenant_id: 'tenant-123',
        equipment_registry_id: 'equipment-uuid',
        plan_name: 'Quarterly PM',
        status: 'SCHEDULED',
      },
      {
        user: scopedUser,
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '127.0.0.1',
      }
    );

    expect(result.human_friendly_id).toBe('PM-100');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('Schedule maintenance create replay does not duplicate billing posts', async () => {
    equipmentMaintenancePlanRepository.create.mockResolvedValue({
      id: 'plan-uuid',
      human_friendly_id: 'PM-100',
      plan_name: 'Quarterly PM',
      status: 'SCHEDULED',
      tenant_id: 'tenant-123',
    });

    const payload = {
      tenant_id: 'tenant-123',
      equipment_registry_id: 'equipment-uuid',
      plan_name: 'Quarterly PM',
      status: 'SCHEDULED',
    };
    const context = {
      user: scopedUser,
      user_id: 'user-123',
      tenant_id: 'tenant-123',
      ip_address: '127.0.0.1',
    };

    await createEquipmentMaintenancePlan(payload, context);
    await createEquipmentMaintenancePlan(payload, context);

    expect(equipmentMaintenancePlanRepository.create).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('internal work-order create from Preventive detail stays NOT_BILLED', async () => {
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
        description: 'Internal maintenance from Preventive detail',
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

  it('unauthorized actor without write scopes still cannot settle via Preventive handlers', async () => {
    await biomedicalWorkspaceService.getWorkspace(
      { panel: 'preventive' },
      1,
      20,
      undefined,
      'desc',
      {
        id: 'user-readonly',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        permissions: ['biomed:read'],
      }
    );

    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
