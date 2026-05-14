jest.mock('@services/reports-workspace/reports-workspace.service');
jest.mock('@lib/response');

const reportsWorkspaceService = require('@services/reports-workspace/reports-workspace.service');
const { sendSuccess } = require('@lib/response');
const {
  getLookups,
  getWorkspace,
} = require('@controllers/reports-workspace/reports-workspace.controller');

describe('Reports Workspace Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      query: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
      },
    };
    mockRes = {};
  });

  it('passes workspace filters, paging, and req.user to the service', async () => {
    const payload = { summary: [], items: [], pagination: null };
    mockReq.query = {
      panel: 'overview',
      page: '2',
      limit: '10',
      sort_by: 'queued_at',
      order: 'asc',
    };
    reportsWorkspaceService.getWorkspace.mockResolvedValue(payload);

    await getWorkspace(mockReq, mockRes);

    expect(reportsWorkspaceService.getWorkspace).toHaveBeenCalledWith(
      { panel: 'overview' },
      2,
      10,
      'queued_at',
      'asc',
      mockReq.user
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      mockRes,
      200,
      'messages.reports_workspace.workspace.success',
      payload
    );
  });

  it('passes lookup filters and req.user to the service', async () => {
    const payload = { facilities: [] };
    mockReq.query = { facilityId: 'facility-123' };
    reportsWorkspaceService.getLookups.mockResolvedValue(payload);

    await getLookups(mockReq, mockRes);

    expect(reportsWorkspaceService.getLookups).toHaveBeenCalledWith(
      { facilityId: 'facility-123' },
      mockReq.user
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      mockRes,
      200,
      'messages.reports_workspace.lookups.success',
      payload
    );
  });
});
