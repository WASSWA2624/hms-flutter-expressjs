const mockPrisma = {
  notification: {
    create: jest.fn(),
  },
  notification_delivery: {
    createMany: jest.fn(),
  },
};

jest.mock('@prisma/client', () => mockPrisma);

const biomedicalWorkspaceService = require('../../../../modules/biomedical-workspace/services/biomedical-workspace.service');
const biomedicalWorkspaceRepository = require('../../../../modules/biomedical-workspace/repositories/biomedical-workspace.repository');
const { createAuditLog } = require('@lib/audit');
const {
  emitToUser,
  emitToUsers,
  BIOMEDICAL_EVENTS,
  NOTIFICATION_EVENTS,
} = require('@lib/websocket');
const { resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');

jest.mock('../../../../modules/biomedical-workspace/repositories/biomedical-workspace.repository');
jest.mock('@lib/audit');
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  BIOMEDICAL_EVENTS: {
    BIOMEDICAL_FAULT_REPORTED: 'biomedical.fault_reported',
    BIOMEDICAL_WORKSPACE_UPDATED: 'biomedical.workspace_updated',
  },
  NOTIFICATION_EVENTS: {
    NOTIFICATION_CREATED: 'notification.created',
  },
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: (...values) =>
    values.find((entry) => typeof entry === 'string' && entry.trim()) || null,
  resolveIdentifierForFilter: jest.fn(),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(),
}));

describe('biomedical-workspace.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveIdentifierForFilter.mockImplementation(async ({ value }) => value || undefined);
    resolveModelIdByIdentifier.mockResolvedValue(null);
    mockPrisma.notification.create.mockImplementation(async ({ data }) => ({
      id: `notification-${data.user_id}`,
      human_friendly_id: null,
      read_at: null,
      created_at: new Date('2026-03-03T08:00:00.000Z'),
      updated_at: new Date('2026-03-03T08:00:00.000Z'),
      ...data,
    }));
    mockPrisma.notification_delivery.createMany.mockResolvedValue({ count: 0 });
  });

  it('creates a biomedical-native fault report with a work-order response and biomedical deep link', async () => {
    biomedicalWorkspaceRepository.resolveEquipmentRegistry.mockResolvedValue({
      id: 'equipment-uuid',
      human_friendly_id: 'EQ-001',
      equipment_name: 'Defibrillator',
      equipment_code: 'DEF-01',
    });
    biomedicalWorkspaceRepository.createFaultReport.mockResolvedValue({
      workOrder: {
        id: 'work-order-uuid',
        human_friendly_id: 'BWO-001',
        status: 'OPEN',
        priority: 'CRITICAL',
      },
      incidentReport: {
        id: 'incident-uuid',
        human_friendly_id: 'BIR-001',
        status: 'OPEN',
        severity: 'CRITICAL',
      },
      downtimeLog: {
        id: 'downtime-uuid',
        human_friendly_id: 'BDT-001',
      },
      clinicalAlert: null,
    });
    biomedicalWorkspaceRepository.findNotificationRecipients.mockResolvedValue([
      'user-1',
      'user-2',
    ]);

    const result = await biomedicalWorkspaceService.createFaultReport(
      {
        equipment_id: 'EQ-001',
        facility_id: 'FAC-001',
        room_id: 'ROOM-001',
        source_scope: 'icu',
        source_route: '/icu',
        severity: 'CRITICAL',
        priority: 'CRITICAL',
        symptoms: 'Power failure',
        patient_safety_risk: true,
        description: 'Unit shuts down unexpectedly',
        evidence_manifest: [{ kind: 'photo' }],
        context: { encounter_id: 'ENC-001' },
      },
      {
        id: 'user-77',
        tenant_id: 'tenant-1',
        facility_id: 'FAC-001',
      },
      '127.0.0.1'
    );

    expect(biomedicalWorkspaceRepository.createFaultReport).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        reportedByUserId: 'user-77',
        equipment: expect.objectContaining({ id: 'equipment-uuid' }),
      })
    );
    expect(result).toEqual(
      expect.objectContaining({
        equipment_work_order: expect.objectContaining({
          id: 'BWO-001',
          human_friendly_id: 'BWO-001',
          status: 'OPEN',
        }),
        fault_report: expect.objectContaining({
          id: 'BIR-001',
          severity: 'CRITICAL',
        }),
        deep_link:
          '/biomedical?panel=work-orders&resource=equipment-work-orders&queue=OPEN_WORK_ORDERS&id=BWO-001&action=triage',
      })
    );
    expect(result.maintenance_request).toBeUndefined();
    expect(emitToUsers).toHaveBeenCalledWith(
      ['user-1', 'user-2'],
      BIOMEDICAL_EVENTS.BIOMEDICAL_FAULT_REPORTED,
      expect.objectContaining({
        equipment_work_order_id: 'BWO-001',
      })
    );
    expect(mockPrisma.notification.create).toHaveBeenCalledTimes(2);
    expect(emitToUser).toHaveBeenCalledWith(
      'user-1',
      NOTIFICATION_EVENTS.NOTIFICATION_CREATED,
      expect.objectContaining({
        target_path:
          '/biomedical?panel=work-orders&resource=equipment-work-orders&queue=OPEN_WORK_ORDERS&id=BWO-001&action=triage',
      })
    );
  });

  it('creates a placeholder equipment record when the reporter provides a temporary equipment name', async () => {
    resolveIdentifierForFilter.mockImplementation(async ({ model, value }) => {
      if (model === 'equipment_registry') return undefined;
      return value || undefined;
    });
    biomedicalWorkspaceRepository.createPlaceholderEquipmentRegistry.mockResolvedValue({
      id: 'placeholder-equipment-uuid',
      human_friendly_id: 'EQ-NEW',
      equipment_name: 'Portable suction trolley',
      equipment_code: null,
    });
    biomedicalWorkspaceRepository.createFaultReport.mockResolvedValue({
      workOrder: {
        id: 'work-order-uuid',
        human_friendly_id: 'BWO-002',
        status: 'OPEN',
        priority: 'HIGH',
      },
      incidentReport: {
        id: 'incident-uuid',
        human_friendly_id: 'BIR-002',
        status: 'OPEN',
        severity: 'HIGH',
      },
      downtimeLog: null,
      clinicalAlert: null,
    });
    biomedicalWorkspaceRepository.findNotificationRecipients.mockResolvedValue([
      'biomed-user-1',
    ]);

    const result = await biomedicalWorkspaceService.createFaultReport(
      {
        reported_equipment_name: 'Portable suction trolley',
        facility_id: 'FAC-001',
        source_scope: 'dashboard_workspace',
        source_route: '/dashboard',
        severity: 'HIGH',
        priority: 'HIGH',
        symptoms: '',
        description: '',
        patient_safety_risk: false,
      },
      {
        id: 'user-77',
        tenant_id: 'tenant-1',
        facility_id: 'FAC-001',
      },
      '127.0.0.1'
    );

    expect(
      biomedicalWorkspaceRepository.createPlaceholderEquipmentRegistry
    ).toHaveBeenCalledWith(
      expect.objectContaining({
        tenantId: 'tenant-1',
        facilityId: 'FAC-001',
        reportedEquipmentName: 'Portable suction trolley',
      })
    );
    expect(
      biomedicalWorkspaceRepository.resolveEquipmentRegistry
    ).not.toHaveBeenCalled();
    expect(biomedicalWorkspaceRepository.createFaultReport).toHaveBeenCalledWith(
      expect.objectContaining({
        equipment: expect.objectContaining({
          id: 'placeholder-equipment-uuid',
          equipment_name: 'Portable suction trolley',
        }),
      })
    );
    expect(result.equipment_work_order.id).toBe('BWO-002');
  });
});
