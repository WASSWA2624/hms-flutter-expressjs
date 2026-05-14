const controller = require('../../../../modules/subscriptions-workspace/controllers/subscriptions-workspace.controller');
const service = require('../../../../modules/subscriptions-workspace/services/subscriptions-workspace.service');
const { sendSuccess } = require('@lib/response');

jest.mock('../../../../modules/subscriptions-workspace/services/subscriptions-workspace.service');
jest.mock('@lib/response');

describe('subscriptions-workspace controller', () => {
  let req;
  let res;

  beforeEach(() => {
    req = {
      query: {},
      params: {},
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
    const data = { summary: [], pagination: { page: 1, totalPages: 1 } };
    req.query = { page: '2', limit: '25', panel: 'operations' };
    service.getWorkspace.mockResolvedValue(data);

    await controller.getWorkspace(req, res);

    expect(service.getWorkspace).toHaveBeenCalledWith(
      { panel: 'operations' },
      2,
      25,
      undefined,
      'desc',
      req.user
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.subscriptions_workspace.workspace.success',
      data
    );
  });

  it('returns reference data with success envelope', async () => {
    const data = { tenants: [{ id: 'TEN0001', label: 'Acme' }] };
    req.query = { tenantId: 'TEN0001' };
    service.getReferenceData.mockResolvedValue(data);

    await controller.getReferenceData(req, res);

    expect(service.getReferenceData).toHaveBeenCalledWith(req.query, req.user);
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.subscriptions_workspace.reference_data.success',
      data
    );
  });

  it('returns resolved legacy route with success envelope', async () => {
    const data = {
      panel: 'operations',
      resource: 'subscriptions',
      id: 'SUB0100',
      action: 'view',
    };
    req.params = { resource: 'subscriptions', id: 'SUB0100' };
    service.resolveLegacyRoute.mockResolvedValue(data);

    await controller.resolveLegacyRoute(req, res);

    expect(service.resolveLegacyRoute).toHaveBeenCalledWith(
      'subscriptions',
      'SUB0100',
      req.user
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.subscriptions_workspace.resolve_legacy.success',
      data
    );
  });
});
