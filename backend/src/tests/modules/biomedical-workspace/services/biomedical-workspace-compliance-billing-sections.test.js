jest.mock('@repositories/biomedical-workspace/biomedical-workspace.repository');
jest.mock('@repositories/equipment-calibration-log/equipment-calibration-log.repository');
jest.mock('@repositories/equipment-downtime-log/equipment-downtime-log.repository');
jest.mock('@repositories/equipment-recall-notice/equipment-recall-notice.repository');
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
const equipmentCalibrationLogRepository = require('@repositories/equipment-calibration-log/equipment-calibration-log.repository');
const equipmentDowntimeLogRepository = require('@repositories/equipment-downtime-log/equipment-downtime-log.repository');
const equipmentRecallNoticeRepository = require('@repositories/equipment-recall-notice/equipment-recall-notice.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const biomedicalWorkspaceService = require('@services/biomedical-workspace/biomedical-workspace.service');
const {
  createEquipmentCalibrationLog,
} = require('@services/equipment-calibration-log/equipment-calibration-log.service');
const {
  createEquipmentDowntimeLog,
  updateEquipmentDowntimeLog,
} = require('@services/equipment-downtime-log/equipment-downtime-log.service');
const {
  updateEquipmentRecallNotice,
} = require('@services/equipment-recall-notice/equipment-recall-notice.service');

describe('biomedical Compliance billing-sections scan', () => {
  const scopedUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    permissions: ['biomed:read', 'biomed:write'],
  };

  const calibrationItem = {
    id: 'cal-uuid',
    human_friendly_id: 'CAL-001',
    name: 'Ventilator calibration',
    status: 'DUE',
    calibrated_at: new Date('2026-07-01T08:00:00.000Z'),
    next_due_at: new Date('2026-10-01T08:00:00.000Z'),
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
    biomedicalWorkspaceRepository.findSummary.mockResolvedValue({
      total_equipment: 1,
      overdue_pm: 0,
      open_work_orders: 0,
      critical_downtime: 1,
      active_recalls: 1,
    });
    biomedicalWorkspaceRepository.findQueueCounts.mockResolvedValue({
      OVERDUE_PM: 0,
      OPEN_WORK_ORDERS: 0,
      CRITICAL_DOWNTIME: 1,
      RECALL_ACTIONS: 1,
      RETURN_TO_SERVICE: 0,
    });
    biomedicalWorkspaceRepository.findItems.mockResolvedValue({
      items: [calibrationItem],
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

  it('Compliance panel workspace read does not touch patient billing ledger', async () => {
    const data = await biomedicalWorkspaceService.getWorkspace(
      { panel: 'compliance' },
      1,
      20,
      undefined,
      'desc',
      scopedUser
    );

    expect(data.filters.panel).toBe('compliance');
    expect(data.filters.resource).toBe('equipment-calibration-logs');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].id).toBe('CAL-001');
    expect(data.items[0].resource).toBe('equipment-calibration-logs');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('Compliance workspace GET is idempotent on replay (no double billing post)', async () => {
    const query = { panel: 'compliance' };
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

  it('serializes compliance items without local paid flags or balances', async () => {
    const data = await biomedicalWorkspaceService.getWorkspace(
      { panel: 'compliance' },
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

  it('record calibration stays NOT_BILLED (no Billing post)', async () => {
    equipmentCalibrationLogRepository.create.mockResolvedValue({
      id: 'cal-uuid',
      human_friendly_id: 'CAL-001',
      name: 'Ventilator calibration',
      status: 'PASSED',
      tenant_id: 'tenant-123',
      equipment_registry_id: 'equipment-uuid',
      created_at: new Date('2026-07-01T08:00:00.000Z'),
      updated_at: new Date('2026-07-01T08:00:00.000Z'),
    });

    const result = await createEquipmentCalibrationLog(
      {
        tenant_id: 'tenant-123',
        equipment_registry_id: 'equipment-uuid',
        calibrated_at: '2026-07-01T08:00:00.000Z',
        result: 'PASSED',
      },
      {
        user: scopedUser,
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '127.0.0.1',
      }
    );

    expect(result.human_friendly_id).toBe('CAL-001');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('calibration create replay does not duplicate billing posts', async () => {
    equipmentCalibrationLogRepository.create.mockResolvedValue({
      id: 'cal-uuid',
      human_friendly_id: 'CAL-001',
      tenant_id: 'tenant-123',
    });

    const payload = {
      tenant_id: 'tenant-123',
      equipment_registry_id: 'equipment-uuid',
      calibrated_at: '2026-07-01T08:00:00.000Z',
      result: 'PASSED',
    };
    const context = {
      user: scopedUser,
      user_id: 'user-123',
      tenant_id: 'tenant-123',
      ip_address: '127.0.0.1',
    };

    await createEquipmentCalibrationLog(payload, context);
    await createEquipmentCalibrationLog(payload, context);

    expect(equipmentCalibrationLogRepository.create).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('report downtime stays NOT_BILLED', async () => {
    equipmentDowntimeLogRepository.create.mockResolvedValue({
      id: 'dt-uuid',
      human_friendly_id: 'DT-001',
      status: 'OPEN',
      tenant_id: 'tenant-123',
      started_at: new Date('2026-07-01T08:00:00.000Z'),
    });

    const result = await createEquipmentDowntimeLog(
      {
        tenant_id: 'tenant-123',
        equipment_registry_id: 'equipment-uuid',
        started_at: '2026-07-01T08:00:00.000Z',
        reason: 'Power failure',
      },
      {
        user: scopedUser,
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '127.0.0.1',
      }
    );

    expect(result.human_friendly_id).toBe('DT-001');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('close downtime stays NOT_BILLED', async () => {
    equipmentDowntimeLogRepository.findById.mockResolvedValue({
      id: 'dt-uuid',
      human_friendly_id: 'DT-001',
      tenant_id: 'tenant-123',
      status: 'OPEN',
    });
    equipmentDowntimeLogRepository.update.mockResolvedValue({
      id: 'dt-uuid',
      human_friendly_id: 'DT-001',
      tenant_id: 'tenant-123',
      status: 'CLOSED',
      ended_at: new Date('2026-07-01T10:00:00.000Z'),
    });

    const result = await updateEquipmentDowntimeLog(
      'dt-uuid',
      { ended_at: '2026-07-01T10:00:00.000Z', status: 'CLOSED' },
      {
        user: scopedUser,
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '127.0.0.1',
      }
    );

    expect(result.status).toBe('CLOSED');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('acknowledge recall stays NOT_BILLED', async () => {
    equipmentRecallNoticeRepository.findById.mockResolvedValue({
      id: 'rc-uuid',
      human_friendly_id: 'RC-001',
      tenant_id: 'tenant-123',
      status: 'ACTIVE',
    });
    equipmentRecallNoticeRepository.update.mockResolvedValue({
      id: 'rc-uuid',
      human_friendly_id: 'RC-001',
      tenant_id: 'tenant-123',
      status: 'ACKNOWLEDGED',
      acknowledged_at: new Date('2026-07-01T09:00:00.000Z'),
    });

    const result = await updateEquipmentRecallNotice(
      'rc-uuid',
      {
        status: 'ACKNOWLEDGED',
        acknowledged_at: '2026-07-01T09:00:00.000Z',
      },
      {
        user: scopedUser,
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '127.0.0.1',
      }
    );

    expect(result.status).toBe('ACKNOWLEDGED');
    expect(result).not.toHaveProperty('payment_status');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('unauthorized actor without write scopes still cannot settle via Compliance handlers', async () => {
    await biomedicalWorkspaceService.getWorkspace(
      { panel: 'compliance' },
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
