jest.mock('@services/lab-workspace/lab-workspace.service');
jest.mock('@lib/response');

const subject = require('@controllers/lab-workspace/lab-workspace.controller');
const service = require('@services/lab-workspace/lab-workspace.service');
const { sendSuccess } = require('@lib/response');

describe('lab-workspace.controller', () => {
  let req;
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-1' },
      ip: '127.0.0.1',
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };
  });

  it('loads the lab workbench payload', async () => {
    service.getLabWorkbench.mockResolvedValue({ summary: {}, worklist: [] });
    req.query = {
      stage: 'COLLECTION',
      page: '2',
      limit: '15',
      order: 'asc',
      sort_by: 'ordered_at',
    };

    await subject.getLabWorkbench(req, res);

    expect(service.getLabWorkbench).toHaveBeenCalledWith(
      expect.objectContaining({ stage: 'COLLECTION' }),
      2,
      15,
      'ordered_at',
      'asc'
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.lab_workspace.workbench.success',
      expect.any(Object)
    );
  });

  it('loads an order workflow payload', async () => {
    service.getLabOrderWorkflow.mockResolvedValue({ order: { id: 'LAB000001' } });
    req.params = { id: 'LAB000001' };

    await subject.getLabOrderWorkflow(req, res);

    expect(service.getLabOrderWorkflow).toHaveBeenCalledWith('LAB000001');
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.lab_workspace.workflow.success',
      expect.any(Object)
    );
  });

  it('submits collect and receive workflow actions', async () => {
    service.collectLabOrder.mockResolvedValue({ workflow: { order: { id: 'LAB000001' } } });
    service.receiveLabSample.mockResolvedValue({ workflow: { order: { id: 'LAB000001' } } });

    req.params = { id: 'LAB000001' };
    req.body = { sample_id: 'LSP000001' };
    await subject.collectLabOrder(req, res);

    expect(service.collectLabOrder).toHaveBeenCalledWith(
      'LAB000001',
      { sample_id: 'LSP000001' },
      'user-1',
      '127.0.0.1'
    );

    req.params = { id: 'LSP000001' };
    req.body = { received_at: '2026-03-11T08:45:00.000Z' };
    await subject.receiveLabSample(req, res);

    expect(service.receiveLabSample).toHaveBeenCalledWith(
      'LSP000001',
      { received_at: '2026-03-11T08:45:00.000Z' },
      'user-1',
      '127.0.0.1'
    );
  });

  it('submits reject and release workflow actions', async () => {
    service.rejectLabSample.mockResolvedValue({ workflow: { order: { id: 'LAB000001' } } });
    service.releaseLabOrderItem.mockResolvedValue({
      workflow: { order: { id: 'LAB000001' } },
      released_result: { id: 'LRS000001' },
    });

    req.params = { id: 'LSP000001' };
    req.body = { reason: 'Hemolysed specimen' };
    await subject.rejectLabSample(req, res);

    expect(service.rejectLabSample).toHaveBeenCalledWith(
      'LSP000001',
      { reason: 'Hemolysed specimen' },
      'user-1',
      '127.0.0.1'
    );

    req.params = { id: 'LIT000001' };
    req.body = { result_id: 'LRS000001', status: 'NORMAL' };
    await subject.releaseLabOrderItem(req, res);

    expect(service.releaseLabOrderItem).toHaveBeenCalledWith(
      'LIT000001',
      { result_id: 'LRS000001', status: 'NORMAL' },
      'user-1',
      '127.0.0.1'
    );
  });

  it('submits reverse workflow actions against the selected order', async () => {
    service.reverseLabOrderWorkflow.mockResolvedValue({
      workflow: { order: { id: 'LAB000001' } },
    });

    req.params = { id: 'LAB000001' };
    req.body = { reason: 'Released by mistake' };
    await subject.reverseLabOrderWorkflow(req, res);

    expect(service.reverseLabOrderWorkflow).toHaveBeenCalledWith(
      'LAB000001',
      { reason: 'Released by mistake' },
      'user-1',
      '127.0.0.1'
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.lab_workspace.reverse.success',
      expect.any(Object)
    );
  });

  it('resolves legacy lab routes', async () => {
    service.resolveLegacyRouteIdentifier.mockResolvedValue({
      identifier: 'LAB000001',
      route: '/lab/orders/LAB000001',
    });
    req.params = { resource: 'lab-orders', id: 'LAB000001' };

    await subject.resolveLegacyRoute(req, res);

    expect(service.resolveLegacyRouteIdentifier).toHaveBeenCalledWith(
      'lab-orders',
      'LAB000001'
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.lab_workspace.resolve_legacy.success',
      expect.any(Object)
    );
  });
});
