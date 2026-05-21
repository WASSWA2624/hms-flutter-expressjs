jest.mock('@services/triage/triage.service');
jest.mock('@lib/response');

const triageService = require('@services/triage/triage.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const {
  listTriageQueue,
  getTriageCase,
  recordVitals,
  assignProvider,
  routeFromTriage,
  correctStage
} = require('@controllers/triage/triage.controller');

describe('Triage Controller', () => {
  let req;
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        roles: ['NURSE']
      },
      ip: '192.168.1.10',
      get: jest.fn((header) => (header === 'user-agent' ? 'Jest Agent' : null))
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  it('lists triage queue with scoped defaults and assigned provider context', async () => {
    const result = {
      items: [{ encounter: { id: 'enc-1' } }],
      pagination: { page: 1, limit: 20, total: 1 }
    };
    triageService.listTriageQueue.mockResolvedValue(result);

    req.query = {
      queue_scope: 'ASSIGNED',
      stage: 'WAITING_VITALS',
      triage_level: 'URGENT',
      page: '2',
      limit: '10',
      sort_by: 'created_at',
      order: 'desc'
    };

    await listTriageQueue(req, res);

    expect(triageService.listTriageQueue).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        provider_user_id: 'user-123',
        queue_scope: 'ASSIGNED',
        triage_status: 'WAITING_VITALS',
        urgency_level: 'URGENT'
      }),
      2,
      10,
      'created_at',
      'desc'
    );
    expect(sendPaginated).toHaveBeenCalledWith(
      res,
      'Triage queue loaded successfully.',
      result.items,
      result.pagination
    );
  });

  it('loads a triage case with request audit context', async () => {
    const flow = { encounter: { id: 'enc-1' } };
    triageService.getTriageCase.mockResolvedValue(flow);
    req.params = { id: 'ENC-1' };

    await getTriageCase(req, res);

    expect(triageService.getTriageCase).toHaveBeenCalledWith(
      'ENC-1',
      expect.objectContaining({
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        roles: ['NURSE'],
        ip_address: '192.168.1.10',
        user_agent: 'Jest Agent'
      })
    );
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'Triage case loaded successfully.', flow);
  });

  it('records vitals through the triage service', async () => {
    const flow = { flow: { stage: 'WAITING_DOCTOR_ASSIGNMENT' } };
    const body = {
      vitals: [{ vital_type: 'HEART_RATE', value: '92', unit: 'bpm' }],
      triage_level: 'LEVEL_2'
    };
    triageService.recordVitals.mockResolvedValue(flow);
    req.params = { id: 'ENC-1' };
    req.body = body;

    await recordVitals(req, res);

    expect(triageService.recordVitals).toHaveBeenCalledWith('ENC-1', body, expect.any(Object));
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'Triage vitals saved successfully.', flow);
  });

  it('assigns provider through the triage service', async () => {
    const flow = { flow: { stage: 'WAITING_DOCTOR_REVIEW' } };
    const body = { provider_user_id: 'USR-1' };
    triageService.assignProvider.mockResolvedValue(flow);
    req.params = { id: 'ENC-1' };
    req.body = body;

    await assignProvider(req, res);

    expect(triageService.assignProvider).toHaveBeenCalledWith('ENC-1', body, expect.any(Object));
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'Triage provider assigned successfully.', flow);
  });

  it('routes a triage case through the triage service', async () => {
    const flow = { flow: { stage: 'LAB_REQUESTED' } };
    const body = { route_to: 'LAB', notes: 'Send labs' };
    triageService.routeFromTriage.mockResolvedValue(flow);
    req.params = { id: 'ENC-1' };
    req.body = body;

    await routeFromTriage(req, res);

    expect(triageService.routeFromTriage).toHaveBeenCalledWith('ENC-1', body, expect.any(Object));
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'Triage route saved successfully.', flow);
  });

  it('corrects triage stage through the triage service', async () => {
    const flow = { flow: { stage: 'WAITING_VITALS' } };
    const body = { stage_to: 'WAITING_VITALS', reason: 'Correction' };
    triageService.correctStage.mockResolvedValue(flow);
    req.params = { id: 'ENC-1' };
    req.body = body;

    await correctStage(req, res);

    expect(triageService.correctStage).toHaveBeenCalledWith('ENC-1', body, expect.any(Object));
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'Triage stage corrected successfully.', flow);
  });
});
