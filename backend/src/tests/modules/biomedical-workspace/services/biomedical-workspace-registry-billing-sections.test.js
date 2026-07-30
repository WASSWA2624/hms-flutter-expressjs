jest.mock('@repositories/biomedical-workspace/biomedical-workspace.repository');
jest.mock('@repositories/equipment-registry/equipment-registry.repository');
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
const equipmentRegistryRepository = require('@repositories/equipment-registry/equipment-registry.repository');
const equipmentWorkOrderRepository = require('@repositories/equipment-work-order/equipment-work-order.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const biomedicalWorkspaceService = require('@services/biomedical-workspace/biomedical-workspace.service');
const {
  createEquipmentRegistry,
} = require('@services/equipment-registry/equipment-registry.service');
const {
  createEquipmentWorkOrder,
} = require('@services/equipment-work-order/equipment-work-order.service');

describe('biomedical Registry billing-sections scan', () => {
  const scopedUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    permissions: ['biomed:read', 'biomed:write'],
  };

  const registryItem = {
    id: 'equipment-uuid',
    human_friendly_id: 'EQ-001',
    equipment_name: 'Defibrillator',
    equipment_code: 'DEF-001',
    serial_number: 'SN-001',
    status: 'ACTIVE',
    priority: 'HIGH',
    updated_at: new Date('2026-07-01T08:00:00.000Z'),
    created_at: new Date('2026-07-01T08:00:00.000Z'),
    facility_id: 'facility-123',
    equipment_category_id: 'category-uuid',
    category: {
      id: 'category-uuid',
      human_friendly_id: 'CAT-001',
      name: 'Life Support',
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
      items: [registryItem],
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
          equipment_name: 'Defibrillator',
          equipment_code: 'DEF-001',
          status: 'ACTIVE',
        },
      ],
      categories: [
        {
          id: 'category-uuid',
          human_friendly_id: 'CAT-001',
          name: 'Life Support',
        },
      ],
      providers: [],
      engineerRoles: [],
    });
  });

  it('Registry panel workspace read does not touch patient billing ledger', async () => {
    const data = await biomedicalWorkspaceService.getWorkspace(
      { panel: 'registry' },
      1,
      20,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.filters.panel).toBe('registry');
    expect(data.filters.resource).toBe('equipment-registries');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].id).toBe('EQ-001');
    expect(data.items[0].resource).toBe('equipment-registries');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('Registry workspace GET is idempotent on replay (no double billing post)', async () => {
    const query = { panel: 'registry' };
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

  it('serializes registry items without local paid flags or balances', async () => {
    const data = await biomedicalWorkspaceService.getWorkspace(
      { panel: 'registry' },
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

  it('Register asset create stays NOT_BILLED (no patient ledger post)', async () => {
    equipmentRegistryRepository.create.mockResolvedValue({
      id: 'equipment-uuid',
      human_friendly_id: 'EQ-001',
      equipment_name: 'Defibrillator',
      equipment_code: 'DEF-001',
      status: 'ACTIVE',
      tenant_id: 'tenant-123',
      created_at: new Date('2026-07-01T08:00:00.000Z'),
      updated_at: new Date('2026-07-01T08:00:00.000Z'),
    });

    const result = await createEquipmentRegistry(
      {
        tenant_id: 'tenant-123',
        equipment_name: 'Defibrillator',
        equipment_code: 'DEF-001',
        status: 'ACTIVE',
      },
      {
        user: scopedUser,
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '127.0.0.1',
      }
    );

    expect(result.human_friendly_id).toBe('EQ-001');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('Register asset create replay does not duplicate billing posts', async () => {
    equipmentRegistryRepository.create.mockResolvedValue({
      id: 'equipment-uuid',
      human_friendly_id: 'EQ-001',
      equipment_name: 'Defibrillator',
      status: 'ACTIVE',
      tenant_id: 'tenant-123',
    });

    const payload = {
      tenant_id: 'tenant-123',
      equipment_name: 'Defibrillator',
      equipment_code: 'DEF-001',
      status: 'ACTIVE',
    };
    const context = {
      user: scopedUser,
      user_id: 'user-123',
      tenant_id: 'tenant-123',
      ip_address: '127.0.0.1',
    };

    await createEquipmentRegistry(payload, context);
    await createEquipmentRegistry(payload, context);

    expect(equipmentRegistryRepository.create).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('internal work-order create from Registry detail stays NOT_BILLED', async () => {
    equipmentWorkOrderRepository.create.mockResolvedValue({
      id: 'work-order-uuid',
      human_friendly_id: 'BWO-001',
      title: 'Service defibrillator',
      status: 'OPEN',
      priority: 'NORMAL',
      equipment_registry_id: 'equipment-uuid',
      equipment_registry: {
        id: 'equipment-uuid',
        human_friendly_id: 'EQ-001',
        equipment_name: 'Defibrillator',
        tenant_id: 'tenant-123',
      },
      created_at: new Date('2026-07-01T08:00:00.000Z'),
      updated_at: new Date('2026-07-01T08:00:00.000Z'),
    });

    const result = await createEquipmentWorkOrder(
      {
        tenant_id: 'tenant-123',
        equipment_registry_id: 'EQ-001',
        title: 'Service defibrillator',
        description: 'Internal maintenance from Registry detail',
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

  it('unauthorized actor without write scopes still cannot settle via Registry handlers', async () => {
    await biomedicalWorkspaceService.getWorkspace(
      { panel: 'registry' },
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
