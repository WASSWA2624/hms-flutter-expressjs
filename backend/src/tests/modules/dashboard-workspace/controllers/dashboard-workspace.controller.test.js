const controller = require('../../../../modules/dashboard-workspace/controllers/dashboard-workspace.controller');
const service = require('../../../../modules/dashboard-workspace/services/dashboard-workspace.service');
const { sendSuccess } = require('@lib/response');

jest.mock('../../../../modules/dashboard-workspace/services/dashboard-workspace.service');
jest.mock('@lib/response');

describe('dashboard-workspace controller', () => {
  let req;
  let res;

  beforeEach(() => {
    req = {
      query: {},
      user: { id: 'user-1' },
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
    const data = { state: 'ready', queue: { items: [] } };
    req.query = { panel: 'queue', page: '2', limit: '15', order: 'asc' };
    service.getWorkspace.mockResolvedValue(data);

    await controller.getWorkspace(req, res);

    expect(service.getWorkspace).toHaveBeenCalledWith(
      { panel: 'queue' },
      2,
      15,
      undefined,
      'asc',
      req.user
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.dashboard_workspace.workspace.success',
      data
    );
  });

  it('returns lookups payload with success envelope', async () => {
    const data = { tenants: [{ id: 'TEN0001', label: 'Acme' }] };
    req.query = { tenantId: 'TEN0001' };
    service.getLookups.mockResolvedValue(data);

    await controller.getLookups(req, res);

    expect(service.getLookups).toHaveBeenCalledWith(req.query, req.user);
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.dashboard_workspace.lookups.success',
      data
    );
  });
});
