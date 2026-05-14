const controller = require('../../../../modules/settings-workspace/controllers/settings-workspace.controller');
const service = require('../../../../modules/settings-workspace/services/settings-workspace.service');
const { sendSuccess } = require('@lib/response');

jest.mock('../../../../modules/settings-workspace/services/settings-workspace.service');
jest.mock('@lib/response');

describe('settings-workspace controller', () => {
  let req;
  let res;

  beforeEach(() => {
    req = {
      query: {},
      user: { id: 'user-1', role: 'TENANT_ADMIN' },
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('returns workspace payload with success envelope', async () => {
    const data = { state: 'ready', summary_cards: [] };
    service.getWorkspace.mockResolvedValue(data);

    await controller.getWorkspace(req, res);

    expect(service.getWorkspace).toHaveBeenCalledWith(req.query, req.user);
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.settings_workspace.workspace.success',
      data
    );
  });

  it('returns reference data payload with success envelope', async () => {
    const data = { state: 'ready', tenants: [], facilities: [] };
    service.getReferenceData.mockResolvedValue(data);

    await controller.getReferenceData(req, res);

    expect(service.getReferenceData).toHaveBeenCalledWith(req.query, req.user);
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.settings_workspace.reference_data.success',
      data
    );
  });
});
