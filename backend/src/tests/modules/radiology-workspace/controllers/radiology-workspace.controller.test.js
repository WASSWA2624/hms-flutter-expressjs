const radiologyWorkspaceController = require('@controllers/radiology-workspace/radiology-workspace.controller');
const radiologyWorkspaceService = require('@services/radiology-workspace/radiology-workspace.service');
const { sendSuccess } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

jest.mock('@services/radiology-workspace/radiology-workspace.service');
jest.mock('@lib/response');

describe('Radiology Workspace Controller', () => {
  let req;
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'actor-1', tenant_id: 'tenant-1', facility_id: 'facility-1' },
      ip: '127.0.0.1'};
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()};
  });

  it('forwards the workbench view query parameter to service filters', async () => {
    const payload = { summary: {}, orders: [] };
    radiologyWorkspaceService.getRadiologyWorkbench.mockResolvedValue(payload);
    req.query = {
      view: 'ORDERS',
      stage: 'ORDERED',
      status: 'IN_PROCESS',
      modality: 'CT',
      patient_id: 'PAT0000001',
      encounter_id: 'ENC0000001',
      search: 'abdomen',
      page: '2',
      limit: '25',
      sort_by: 'ordered_at',
      order: 'desc'};

    await radiologyWorkspaceController.getRadiologyWorkbench(req, res);

    expect(radiologyWorkspaceService.getRadiologyWorkbench).toHaveBeenCalledWith(
      expect.objectContaining({
        view: 'ORDERS',
        stage: 'ORDERED',
        status: 'IN_PROCESS',
        modality: 'CT',
        patient_id: 'PAT0000001',
        encounter_id: 'ENC0000001',
        search: 'abdomen'}),
      2,
      25,
      'ordered_at',
      'desc'
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.radiology_workspace.workbench.success',
      payload
    );
  });

  it('uses default workbench pagination when query pagination is absent', async () => {
    const payload = { summary: {}, orders: [] };
    radiologyWorkspaceService.getRadiologyWorkbench.mockResolvedValue(payload);

    await radiologyWorkspaceController.getRadiologyWorkbench(req, res);

    expect(radiologyWorkspaceService.getRadiologyWorkbench).toHaveBeenCalledWith(
      expect.any(Object),
      DEFAULT_PAGE,
      DEFAULT_PAGE_LIMIT,
      undefined,
      'desc'
    );
  });
});
