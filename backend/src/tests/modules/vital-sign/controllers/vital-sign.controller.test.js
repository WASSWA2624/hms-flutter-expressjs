/**
 * Vital Sign controller tests
 *
 * @module tests/modules/vital-sign/controllers
 * @description Tests for vital sign controller
 * Per testing.mdc: Controller tests with mocked service
 */

const vitalSignController = require('@controllers/vital-sign/vital-sign.controller');
const vitalSignService = require('@services/vital-sign/vital-sign.service');

jest.mock('@services/vital-sign/vital-sign.service');

describe('Vital Sign Controller', () => {
  let req, res;

  beforeEach(() => {
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-id-123' },
      ip: '127.0.0.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      send: jest.fn()
    };
  });

  afterEach(() => jest.clearAllMocks());

  it('should list vital signs', async () => {
    const mockResult = {
      vitalSigns: [{ id: '1', vital_type: 'TEMPERATURE' }],
      pagination: { page: 1, limit: 20, total: 1, totalPages: 1 }
    };
    vitalSignService.listVitalSigns.mockResolvedValue(mockResult);

    await vitalSignController.listVitalSigns(req, res);

    expect(vitalSignService.listVitalSigns).toHaveBeenCalled();
  });

  it('should get vital sign by ID', async () => {
    req.params.id = '1';
    const mockVitalSign = { id: '1', vital_type: 'TEMPERATURE' };
    vitalSignService.getVitalSignById.mockResolvedValue(mockVitalSign);

    await vitalSignController.getVitalSignById(req, res);

    expect(vitalSignService.getVitalSignById).toHaveBeenCalledWith('1', 'user-id-123', '127.0.0.1');
  });

  it('should create vital sign', async () => {
    req.body = { vital_type: 'TEMPERATURE', value: '98.6' };
    const createdVitalSign = { id: '1', ...req.body };
    vitalSignService.createVitalSign.mockResolvedValue(createdVitalSign);

    await vitalSignController.createVitalSign(req, res);

    expect(vitalSignService.createVitalSign).toHaveBeenCalledWith(req.body, 'user-id-123', '127.0.0.1');
  });
});
