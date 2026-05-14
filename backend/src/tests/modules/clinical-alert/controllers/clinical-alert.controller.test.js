/**
 * Clinical Alert controller tests
 *
 * @module tests/modules/clinical-alert/controllers
 * @description Tests for clinical alert controller
 * Per testing.mdc: Controller tests with mocked service
 */

const clinicalAlertController = require('@controllers/clinical-alert/clinical-alert.controller');
const clinicalAlertService = require('@services/clinical-alert/clinical-alert.service');

jest.mock('@services/clinical-alert/clinical-alert.service');

describe('Clinical Alert Controller', () => {
  let req, res;

  beforeEach(() => {
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-id-123' },
      ip: '127.0.0.1'
    };
    res = { status: jest.fn().mockReturnThis(), json: jest.fn(), send: jest.fn() };
  });

  afterEach(() => jest.clearAllMocks());

  it('should list clinical alerts', async () => {
    const mockResult = { clinicalAlerts: [{ id: '1' }], pagination: {} };
    clinicalAlertService.listClinicalAlerts.mockResolvedValue(mockResult);

    await clinicalAlertController.listClinicalAlerts(req, res);

    expect(clinicalAlertService.listClinicalAlerts).toHaveBeenCalled();
  });

  it('should create clinical alert', async () => {
    req.body = { severity: 'HIGH', message: 'New alert' };
    const created = { id: '1', ...req.body };
    clinicalAlertService.createClinicalAlert.mockResolvedValue(created);

    await clinicalAlertController.createClinicalAlert(req, res);

    expect(clinicalAlertService.createClinicalAlert).toHaveBeenCalled();
  });
});
