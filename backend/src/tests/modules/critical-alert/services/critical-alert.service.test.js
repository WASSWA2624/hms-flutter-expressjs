const criticalAlertService = require('@services/critical-alert/critical-alert.service');
const criticalAlertRepository = require('@repositories/critical-alert/critical-alert.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');

jest.mock('@repositories/critical-alert/critical-alert.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/resolve-entity-id');

const buildInternalCriticalAlert = () => ({
  id: '550e8400-e29b-41d4-a716-446655440310',
  human_friendly_id: 'ICALERT-001',
  severity: 'CRITICAL',
  message: 'Sustained hypotension',
  created_at: '2026-03-04T10:15:00.000Z',
  updated_at: '2026-03-04T10:15:00.000Z',
  icu_stay: {
    id: '550e8400-e29b-41d4-a716-446655440320',
    human_friendly_id: 'ICU-001',
    admission: {
      id: '550e8400-e29b-41d4-a716-446655440330',
      tenant_id: 'tenant-001',
      human_friendly_id: 'ADM-001',
      patient: {
        id: '550e8400-e29b-41d4-a716-446655440340',
        human_friendly_id: 'PAT-001',
        first_name: 'Jane',
        last_name: 'Doe',
      },
    },
  },
});

describe('Critical Alert Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('lists critical alerts with public identifiers only', async () => {
    criticalAlertRepository.findMany.mockResolvedValue([buildInternalCriticalAlert()]);
    criticalAlertRepository.count.mockResolvedValue(1);

    const result = await criticalAlertService.listCriticalAlerts(
      {},
      1,
      20,
      'created_at',
      'desc'
    );

    expect(result.critical_alerts[0]).toMatchObject({
      id: 'ICALERT-001',
      icu_stay_id: 'ICU-001',
      admission_display_id: 'ADM-001',
      patient_display_id: 'PAT-001',
      patient_display_name: 'Jane Doe',
      severity: 'CRITICAL',
    });
  });

  it('resolves ICU stay filters before querying the repository', async () => {
    resolveModelIdByIdentifier.mockResolvedValueOnce({
      id: '550e8400-e29b-41d4-a716-446655440320',
      admission: { tenant_id: 'tenant-001' },
    });
    criticalAlertRepository.findMany.mockResolvedValue([]);
    criticalAlertRepository.count.mockResolvedValue(0);

    await criticalAlertService.listCriticalAlerts(
      { icu_stay_id: 'ICU-001', severity: 'CRITICAL' },
      1,
      20,
      'created_at',
      'desc'
    );

    expect(criticalAlertRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        icu_stay_id: '550e8400-e29b-41d4-a716-446655440320',
        severity: 'CRITICAL',
      }),
      0,
      20,
      { created_at: 'desc' },
      expect.any(Object)
    );
  });

  it('creates critical alerts with internal ids and tenant-aware audit logs', async () => {
    resolveModelIdByIdentifier.mockResolvedValueOnce({
      id: '550e8400-e29b-41d4-a716-446655440320',
      admission: { tenant_id: 'tenant-001' },
    });
    criticalAlertRepository.create.mockResolvedValue({
      id: '550e8400-e29b-41d4-a716-446655440310',
    });
    criticalAlertRepository.findById.mockResolvedValue(buildInternalCriticalAlert());

    const result = await criticalAlertService.createCriticalAlert(
      {
        icu_stay_id: 'ICU-001',
        severity: 'CRITICAL',
        message: 'Sustained hypotension',
      },
      'user-001',
      '127.0.0.1'
    );

    expect(criticalAlertRepository.create).toHaveBeenCalledWith({
      icu_stay_id: '550e8400-e29b-41d4-a716-446655440320',
      severity: 'CRITICAL',
      message: 'Sustained hypotension',
    });
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-001',
        action: 'CREATE',
        entity: 'critical_alert',
      })
    );
    expect(result.id).toBe('ICALERT-001');
  });

  it('updates and deletes by resolved public identifier', async () => {
    resolveModelIdByIdentifier.mockResolvedValue({
      id: '550e8400-e29b-41d4-a716-446655440310',
    });
    criticalAlertRepository.findById.mockResolvedValue(buildInternalCriticalAlert());
    criticalAlertRepository.update.mockResolvedValue({
      id: '550e8400-e29b-41d4-a716-446655440310',
    });
    criticalAlertRepository.softDelete.mockResolvedValue({});

    await criticalAlertService.updateCriticalAlert(
      'ICALERT-001',
      { severity: 'HIGH' },
      'user-001',
      '127.0.0.1'
    );
    await criticalAlertService.deleteCriticalAlert(
      'ICALERT-001',
      'user-001',
      '127.0.0.1'
    );

    expect(criticalAlertRepository.update).toHaveBeenCalledWith(
      '550e8400-e29b-41d4-a716-446655440310',
      { severity: 'HIGH' }
    );
    expect(criticalAlertRepository.softDelete).toHaveBeenCalledWith(
      '550e8400-e29b-41d4-a716-446655440310'
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-001',
        action: 'DELETE',
      })
    );
  });

  it('throws when the critical alert cannot be resolved', async () => {
    resolveModelIdByIdentifier.mockResolvedValueOnce(null);

    await expect(
      criticalAlertService.getCriticalAlertById('ICALERT-404')
    ).rejects.toThrow(HttpError);
  });
});
