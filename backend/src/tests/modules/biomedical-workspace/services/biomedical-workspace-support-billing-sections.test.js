jest.mock('@repositories/biomedical-workspace/biomedical-workspace.repository');
jest.mock('@repositories/equipment-incident-report/equipment-incident-report.repository');
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
const equipmentIncidentReportRepository = require('@repositories/equipment-incident-report/equipment-incident-report.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const biomedicalWorkspaceService = require('@services/biomedical-workspace/biomedical-workspace.service');
const {
  createEquipmentIncidentReport,
} = require('@services/equipment-incident-report/equipment-incident-report.service');

describe('biomedical Support billing-sections scan', () => {
  const scopedUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    permissions: ['biomed:read', 'biomed:write'],
  };

  const vendorItem = {
    id: 'provider-uuid',
    human_friendly_id: 'SP-001',
    name: 'Acme Biomedical Support',
    status: 'ACTIVE',
    updated_at: new Date('2026-07-01T08:00:00.000Z'),
    created_at: new Date('2026-07-01T08:00:00.000Z'),
    contact_name: 'Support Desk',
  };

  beforeEach(() => {
    jest.clearAllMocks();
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
      items: [vendorItem],
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
    biomedicalWorkspaceRepository.findNotificationRecipients.mockResolvedValue([]);
  });

  it('Support panel workspace read does not touch patient billing ledger', async () => {
    const data = await biomedicalWorkspaceService.getWorkspace(
      { panel: 'support' },
      1,
      20,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.filters.panel).toBe('support');
    expect(data.filters.resource).toBe('equipment-service-providers');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].id).toBe('SP-001');
    expect(data.items[0].resource).toBe('equipment-service-providers');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('Support workspace GET is idempotent on replay (no double billing post)', async () => {
    const query = { panel: 'support' };
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

  it('serializes vendor items without local paid flags or balances', async () => {
    const data = await biomedicalWorkspaceService.getWorkspace(
      { panel: 'support' },
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

  it('report fault stays NOT_BILLED (no Billing post)', async () => {
    biomedicalWorkspaceRepository.resolveEquipmentRegistry.mockResolvedValue({
      id: 'equipment-uuid',
      human_friendly_id: 'EQ-001',
      equipment_name: 'Ventilator A',
      equipment_code: 'VENT-A',
    });
    biomedicalWorkspaceRepository.createFaultReport.mockResolvedValue({
      workOrder: {
        id: 'work-order-uuid',
        human_friendly_id: 'BWO-001',
        status: 'OPEN',
        priority: 'HIGH',
      },
      incidentReport: {
        id: 'incident-uuid',
        human_friendly_id: 'BIR-001',
        status: 'OPEN',
        severity: 'HIGH',
      },
      downtimeLog: null,
      clinicalAlert: null,
    });

    const result = await biomedicalWorkspaceService.createFaultReport(
      {
        equipment_id: 'EQ-001',
        facility_id: 'FAC-001',
        source_scope: 'biomedical',
        source_route: '/biomedical',
        severity: 'HIGH',
        priority: 'HIGH',
        symptoms: 'Alarm storm',
        patient_safety_risk: false,
        reported_equipment_name: 'Ventilator A',
      },
      scopedUser,
      '127.0.0.1'
    );

    expect(result.equipment_work_order.human_friendly_id).toBe('BWO-001');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(result).not.toHaveProperty('invoice_id');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('fault report replay does not duplicate billing posts', async () => {
    biomedicalWorkspaceRepository.resolveEquipmentRegistry.mockResolvedValue({
      id: 'equipment-uuid',
      human_friendly_id: 'EQ-001',
      equipment_name: 'Ventilator A',
    });
    biomedicalWorkspaceRepository.createFaultReport.mockResolvedValue({
      workOrder: {
        id: 'work-order-uuid',
        human_friendly_id: 'BWO-001',
        status: 'OPEN',
        priority: 'HIGH',
      },
      incidentReport: null,
      downtimeLog: null,
      clinicalAlert: null,
    });

    const payload = {
      equipment_id: 'EQ-001',
      severity: 'HIGH',
      priority: 'HIGH',
      symptoms: 'Alarm storm',
      reported_equipment_name: 'Ventilator A',
    };

    await biomedicalWorkspaceService.createFaultReport(payload, scopedUser, '127.0.0.1');
    await biomedicalWorkspaceService.createFaultReport(payload, scopedUser, '127.0.0.1');

    expect(biomedicalWorkspaceRepository.createFaultReport).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('log incident stays NOT_BILLED', async () => {
    equipmentIncidentReportRepository.create.mockResolvedValue({
      id: 'incident-uuid',
      human_friendly_id: 'BIR-002',
      status: 'OPEN',
      severity: 'MEDIUM',
      tenant_id: 'tenant-123',
      equipment_registry_id: 'equipment-uuid',
      created_at: new Date('2026-07-01T08:00:00.000Z'),
      updated_at: new Date('2026-07-01T08:00:00.000Z'),
    });

    const result = await createEquipmentIncidentReport(
      {
        tenant_id: 'tenant-123',
        equipment_registry_id: 'equipment-uuid',
        severity: 'MEDIUM',
        description: 'Vendor ticket follow-up',
      },
      {
        user: scopedUser,
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '127.0.0.1',
      }
    );

    expect(result.human_friendly_id).toBe('BIR-002');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('incident create replay does not duplicate billing posts', async () => {
    equipmentIncidentReportRepository.create.mockResolvedValue({
      id: 'incident-uuid',
      human_friendly_id: 'BIR-002',
      tenant_id: 'tenant-123',
    });

    const payload = {
      tenant_id: 'tenant-123',
      equipment_registry_id: 'equipment-uuid',
      severity: 'MEDIUM',
      description: 'Vendor ticket follow-up',
    };
    const context = {
      user: scopedUser,
      user_id: 'user-123',
      tenant_id: 'tenant-123',
      ip_address: '127.0.0.1',
    };

    await createEquipmentIncidentReport(payload, context);
    await createEquipmentIncidentReport(payload, context);

    expect(equipmentIncidentReportRepository.create).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('unauthorized actor without write scopes still cannot settle via Support handlers', async () => {
    await biomedicalWorkspaceService.getWorkspace(
      { panel: 'support' },
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
