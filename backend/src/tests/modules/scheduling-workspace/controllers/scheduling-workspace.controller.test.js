jest.mock('@services/scheduling-workspace/scheduling-workspace.service');
jest.mock('@lib/response');

const subject = require('@controllers/scheduling-workspace/scheduling-workspace.controller');
const service = require('@services/scheduling-workspace/scheduling-workspace.service');
const { sendSuccess } = require('@lib/response');

describe('scheduling-workspace.controller', () => {
  let req;
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };
  });

  it('loads workspace payload', async () => {
    service.getWorkspace.mockResolvedValue({ summary_cards: [] });
    req.query = { page: '1', limit: '12', panel: 'overview' };

    await subject.getWorkspace(req, res);

    expect(service.getWorkspace).toHaveBeenCalledWith(
      expect.objectContaining({ panel: 'overview' }),
      1,
      12
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.scheduling_workspace.workspace.success',
      expect.any(Object)
    );
  });

  it('loads reference data payload', async () => {
    service.getReferenceData.mockResolvedValue({ facilities: [], providers: [] });

    await subject.getReferenceData(req, res);

    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.scheduling_workspace.reference_data.success',
      expect.any(Object)
    );
  });

  it('resolves legacy route payload', async () => {
    service.resolveLegacyRouteIdentifier.mockResolvedValue({ target_path: '/scheduling' });
    req.params = { resource: 'appointments', id: 'APT0001' };

    await subject.resolveLegacyRoute(req, res);

    expect(service.resolveLegacyRouteIdentifier).toHaveBeenCalledWith('appointments', 'APT0001');
  });
});
