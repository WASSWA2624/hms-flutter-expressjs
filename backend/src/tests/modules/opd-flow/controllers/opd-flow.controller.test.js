/**
 * OPD flow controller tests
 *
 * @module tests/modules/opd-flow/controllers
 * @description Tests service delegation, request context propagation, and response helpers.
 */

const opdFlowController = require('@controllers/opd-flow/opd-flow.controller');
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

jest.mock('@services/opd-flow/opd-flow.service');
jest.mock('@lib/response');

describe('opd-flow.controller', () => {
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
        facility_id: 'facility-1'
      },
      ip: '127.0.0.1',
      get: jest.fn(() => 'jest-agent')
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  it('lists OPD flows and sends paginated response', async () => {
    opdFlowService.listOpdFlows.mockResolvedValue({
      items: [{ encounter: { id: 'enc-1' }, flow: { stage: 'WAITING_VITALS' } }],
      pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
    });
    req.query = { page: '1', limit: '20', stage: 'WAITING_VITALS' };

    await opdFlowController.listOpdFlows(req, res);

    expect(opdFlowService.listOpdFlows).toHaveBeenCalledWith(
      expect.objectContaining({ stage: 'WAITING_VITALS' }),
      1,
      20,
      'started_at',
      'desc'
    );
    expect(sendPaginated).toHaveBeenCalledWith(
      res,
      'messages.opd_flow.list.success',
      expect.any(Array),
      expect.any(Object)
    );
  });

  it('gets OPD flow by id and sends success response', async () => {
    opdFlowService.getOpdFlowById.mockResolvedValue({ encounter: { id: 'enc-1' }, flow: { stage: 'WAITING_VITALS' } });
    req.params.id = 'enc-1';

    await opdFlowController.getOpdFlowById(req, res);

    expect(opdFlowService.getOpdFlowById).toHaveBeenCalledWith('enc-1');
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.opd_flow.get.success', expect.any(Object));
  });

  it('resolves emergency legacy route and sends success response', async () => {
    opdFlowService.resolveLegacyRoute.mockResolvedValue({
      encounter_id: 'ENC00001',
      emergency_case_id: 'EMC00001',
      resource: 'emergency-cases',
      resource_id: 'EMC00001',
      panel: 'queue',
      action: 'open_case',
    });
    req.params = { resource: 'emergency-cases', id: 'EMC00001' };

    await opdFlowController.resolveLegacyRoute(req, res);

    expect(opdFlowService.resolveLegacyRoute).toHaveBeenCalledWith('emergency-cases', 'EMC00001');
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.opd_flow.resolve_legacy.success',
      expect.objectContaining({ resource: 'emergency-cases' })
    );
  });

  it('starts OPD flow, injects tenant_id fallback, and propagates context', async () => {
    opdFlowService.startOpdFlow.mockResolvedValue({ encounter: { id: 'enc-1' }, flow: { stage: 'WAITING_VITALS' } });
    req.body = {
      patient_id: 'pat-1'
    };

    await opdFlowController.startOpdFlow(req, res);

    expect(opdFlowService.startOpdFlow).toHaveBeenCalledWith(
      expect.objectContaining({
        patient_id: 'pat-1',
        tenant_id: 'tenant-1'
      }),
      {
        user_id: 'usr-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        ip_address: '127.0.0.1',
        user_agent: 'jest-agent'
      }
    );
    expect(sendSuccess).toHaveBeenCalledWith(res, 201, 'messages.opd_flow.start.success', expect.any(Object));
  });

  it('delegates pay consultation endpoint and returns 200', async () => {
    opdFlowService.payConsultation.mockResolvedValue({ encounter: { id: 'enc-1' }, flow: { stage: 'WAITING_VITALS' } });
    req.params.id = 'enc-1';
    req.body = { method: 'CASH', amount: '40.00' };

    await opdFlowController.payConsultation(req, res);

    expect(opdFlowService.payConsultation).toHaveBeenCalledWith('enc-1', req.body, expect.any(Object));
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.opd_flow.pay_consultation.success', expect.any(Object));
  });

  it('delegates record vitals endpoint and returns 200', async () => {
    opdFlowService.recordVitals.mockResolvedValue({
      encounter: { id: 'enc-1' },
      flow: { stage: 'WAITING_DOCTOR_ASSIGNMENT' }
    });
    req.params.id = 'enc-1';
    req.body = { vitals: [{ vital_type: 'TEMPERATURE', value: '37.1' }] };

    await opdFlowController.recordVitals(req, res);

    expect(opdFlowService.recordVitals).toHaveBeenCalledWith('enc-1', req.body, expect.any(Object));
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.opd_flow.record_vitals.success', expect.any(Object));
  });

  it('delegates assign doctor endpoint and returns 200', async () => {
    opdFlowService.assignDoctor.mockResolvedValue({
      encounter: { id: 'enc-1' },
      flow: { stage: 'WAITING_DOCTOR_REVIEW' }
    });
    req.params.id = 'enc-1';
    req.body = { provider_user_id: 'doc-1' };

    await opdFlowController.assignDoctor(req, res);

    expect(opdFlowService.assignDoctor).toHaveBeenCalledWith('enc-1', req.body, expect.any(Object));
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.opd_flow.assign_doctor.success', expect.any(Object));
  });

  it('delegates doctor review endpoint and returns 200', async () => {
    opdFlowService.doctorReview.mockResolvedValue({
      encounter: { id: 'enc-1' },
      flow: { stage: 'LAB_AND_RADIOLOGY_REQUESTED' }
    });
    req.params.id = 'enc-1';
    req.body = { note: 'Reviewed', lab_requests: [{ lab_test_id: 'lab-test-1' }] };

    await opdFlowController.doctorReview(req, res);

    expect(opdFlowService.doctorReview).toHaveBeenCalledWith('enc-1', req.body, expect.any(Object));
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.opd_flow.doctor_review.success', expect.any(Object));
  });

  it('delegates disposition endpoint and returns 200', async () => {
    opdFlowService.disposition.mockResolvedValue({
      encounter: { id: 'enc-1' },
      flow: { stage: 'DISCHARGED' }
    });
    req.params.id = 'enc-1';
    req.body = { decision: 'DISCHARGE' };

    await opdFlowController.disposition(req, res);

    expect(opdFlowService.disposition).toHaveBeenCalledWith('enc-1', req.body, expect.any(Object));
    expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.opd_flow.disposition.success', expect.any(Object));
  });
});
