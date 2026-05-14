const ipdFlowController = require('@controllers/ipd-flow/ipd-flow.controller');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

jest.mock('@services/ipd-flow/ipd-flow.service');
jest.mock('@lib/response');

describe('ipd-flow.controller', () => {
  let req;
  let res;

  beforeEach(() => {
    jest.clearAllMocks();

    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'usr-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
      },
      ip: '127.0.0.1',
      get: jest.fn(() => 'jest-agent'),
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };
  });

  it('lists IPD flows and sends paginated response', async () => {
    ipdFlowService.listIpdFlows.mockResolvedValue({
      items: [{ admission: { id: 'adm-1' }, flow: { stage: 'ADMITTED_IN_BED' } }],
      pagination: {
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      },
    });
    req.query = { page: '1', limit: '20', stage: 'ADMITTED_IN_BED', queue_scope: 'ALL' };

    await ipdFlowController.listIpdFlows(req, res);

    expect(ipdFlowService.listIpdFlows).toHaveBeenCalledWith(
      expect.objectContaining({ stage: 'ADMITTED_IN_BED', queue_scope: 'ALL' }),
      1,
      20,
      'admitted_at',
      'desc'
    );
    expect(sendPaginated).toHaveBeenCalledWith(
      res,
      'messages.ipd_flow.list.success',
      expect.any(Array),
      expect.any(Object)
    );
  });

  it('gets IPD flow by id and sends success response', async () => {
    ipdFlowService.getIpdFlowById.mockResolvedValue({ admission: { id: 'adm-1' } });
    req.params.id = 'ADM0000001';
    req.query = { include_icu: true };

    await ipdFlowController.getIpdFlowById(req, res);

    expect(ipdFlowService.getIpdFlowById).toHaveBeenCalledWith('ADM0000001', {
      include_icu: true,
    });
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.ipd_flow.get.success', expect.any(Object));
  });

  it('starts IPD flow with tenant fallback and propagates context', async () => {
    ipdFlowService.startIpdFlow.mockResolvedValue({ admission: { id: 'adm-1' } });
    req.body = { patient_id: 'PAT0001' };

    await ipdFlowController.startIpdFlow(req, res);

    expect(ipdFlowService.startIpdFlow).toHaveBeenCalledWith(
      expect.objectContaining({ tenant_id: 'tenant-1', patient_id: 'PAT0001' }),
      {
        user_id: 'usr-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        ip_address: '127.0.0.1',
        user_agent: 'jest-agent',
      }
    );
    expect(sendSuccess).toHaveBeenCalledWith(res, 201, 'messages.ipd_flow.start.success', expect.any(Object));
  });

  it('delegates finalize discharge and returns 200', async () => {
    ipdFlowService.finalizeDischarge.mockResolvedValue({ admission: { id: 'adm-1' } });
    req.params.id = 'ADM0001';
    req.body = { summary: 'Recovered', discharged_at: new Date().toISOString() };

    await ipdFlowController.finalizeDischarge(req, res);

    expect(ipdFlowService.finalizeDischarge).toHaveBeenCalledWith('ADM0001', req.body, expect.any(Object));
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.ipd_flow.finalize_discharge.success',
      expect.any(Object)
    );
  });

  it('resolves legacy route and returns success response', async () => {
    ipdFlowService.resolveLegacyRoute.mockResolvedValue({
      admission_id: 'ADM0001',
      resource: 'admissions',
      panel: 'snapshot',
      action: 'open_admission',
    });
    req.params = { resource: 'admissions', id: 'ADM0001' };

    await ipdFlowController.resolveLegacyRoute(req, res);

    expect(ipdFlowService.resolveLegacyRoute).toHaveBeenCalledWith('admissions', 'ADM0001');
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.ipd_flow.resolve_legacy.success',
      expect.any(Object)
    );
  });

  it('starts ICU stay and returns updated snapshot', async () => {
    ipdFlowService.startIcuStay.mockResolvedValue({ id: 'ADM0000001', icu_status: 'ACTIVE' });
    req.params.id = 'ADM0000001';
    req.body = { started_at: '2026-02-01T00:00:00.000Z' };

    await ipdFlowController.startIcuStay(req, res);

    expect(ipdFlowService.startIcuStay).toHaveBeenCalledWith('ADM0000001', req.body, expect.any(Object));
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.ipd_flow.start_icu_stay.success',
      expect.any(Object)
    );
  });

  it('resolves critical alert and returns updated snapshot', async () => {
    ipdFlowService.resolveCriticalAlert.mockResolvedValue({ id: 'ADM0000001', has_critical_alert: false });
    req.params.id = 'ADM0000001';
    req.body = { critical_alert_id: 'CAL0000001' };

    await ipdFlowController.resolveCriticalAlert(req, res);

    expect(ipdFlowService.resolveCriticalAlert).toHaveBeenCalledWith(
      'ADM0000001',
      req.body,
      expect.any(Object)
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.ipd_flow.resolve_critical_alert.success',
      expect.any(Object)
    );
  });
});
