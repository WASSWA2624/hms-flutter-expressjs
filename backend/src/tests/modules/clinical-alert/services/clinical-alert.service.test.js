/**
 * Clinical Alert service tests
 *
 * @module tests/modules/clinical-alert/services
 * @description Tests for clinical alert service
 * Per testing.mdc: Service tests with mocked repository
 */

const clinicalAlertService = require('@services/clinical-alert/clinical-alert.service');
const clinicalAlertRepository = require('@repositories/clinical-alert/clinical-alert.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/clinical-alert/clinical-alert.repository');
jest.mock('@lib/audit');

describe('Clinical Alert Service', () => {
  const mockUserId = 'user-id-123';
  const mockIpAddress = '127.0.0.1';

  afterEach(() => jest.clearAllMocks());

  it('should list clinical alerts', async () => {
    const mockAlerts = [{ id: '1', severity: 'HIGH', message: 'Test alert' }];
    clinicalAlertRepository.findMany.mockResolvedValue(mockAlerts);
    clinicalAlertRepository.count.mockResolvedValue(1);

    const result = await clinicalAlertService.listClinicalAlerts({}, 1, 20, null, 'asc', mockUserId, mockIpAddress);

    expect(result.clinicalAlerts).toEqual(mockAlerts);
  });

  it('should create clinical alert', async () => {
    const newAlert = { severity: 'HIGH', message: 'New alert' };
    const createdAlert = { id: '1', ...newAlert };
    clinicalAlertRepository.create.mockResolvedValue(createdAlert);
    createAuditLog.mockReturnValue(Promise.resolve({}));

    const result = await clinicalAlertService.createClinicalAlert(newAlert, mockUserId, mockIpAddress);

    expect(result).toEqual(createdAlert);
  });

  it('should update clinical alert', async () => {
    const existing = { id: '1', severity: 'HIGH' };
    const updated = { id: '1', severity: 'CRITICAL' };
    clinicalAlertRepository.findById.mockResolvedValue(existing);
    clinicalAlertRepository.update.mockResolvedValue(updated);
    createAuditLog.mockResolvedValue({});

    const result = await clinicalAlertService.updateClinicalAlert('1', { severity: 'CRITICAL' }, mockUserId, mockIpAddress);

    expect(result).toEqual(updated);
  });
});
