const theatreFlowController = require('@controllers/theatre-flow/theatre-flow.controller');
const theatreFlowService = require('@services/theatre-flow/theatre-flow.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

jest.mock('@services/theatre-flow/theatre-flow.service');
jest.mock('@lib/response');

describe('theatre-flow.controller', () => {
  let req;
  let res;

  beforeEach(() => {
    req = {
      params: {},
      query: {},
      body: {},
      user: { id: 'user-1', tenant_id: 'TEN-1', facility_id: 'FAC-1', roles: ['DOCTOR'] },
      ip: '127.0.0.1',
      get: jest.fn(() => 'jest-agent'),
    };
    res = {};
    jest.clearAllMocks();
  });

  it('lists theatre flows with pagination envelope', async () => {
    theatreFlowService.listTheatreFlows.mockResolvedValue({
      items: [{ id: 'TC-001' }],
      pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false },
    });

    await theatreFlowController.listTheatreFlows(req, res);

    expect(theatreFlowService.listTheatreFlows).toHaveBeenCalled();
    expect(sendPaginated).toHaveBeenCalledWith(
      res,
      'messages.theatre_flow.list.success',
      [{ id: 'TC-001' }],
      expect.any(Object)
    );
  });

  it('starts theatre flow and returns success envelope', async () => {
    req.body = { encounter_id: 'ENC-001' };
    theatreFlowService.startTheatreFlow.mockResolvedValue({ id: 'TC-001' });

    await theatreFlowController.startTheatreFlow(req, res);

    expect(theatreFlowService.startTheatreFlow).toHaveBeenCalledWith(
      req.body,
      expect.objectContaining({ user_id: 'user-1', tenant_id: 'TEN-1', facility_id: 'FAC-1' })
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      201,
      'messages.theatre_flow.start.success',
      { id: 'TC-001' }
    );
  });
});

