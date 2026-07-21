const { HttpError } = require('@lib/errors');

jest.mock('@repositories/radiology-workspace/radiology-workspace.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn()}));
jest.mock('@lib/websocket', () => ({
  emitToUsers: jest.fn(),
  DIAGNOSTIC_EVENTS: {
    RADIOLOGY_WORKFLOW_UPDATED: 'diagnostic.radiology_workflow_updated',
    RADIOLOGY_RESULT_UPDATED: 'diagnostic.radiology_result_updated',
    RADIOLOGY_RESULT_READY: 'diagnostic.radiology_result_ready'}}));
jest.mock('@prisma/client', () => ({
  user_role: {
    findMany: jest.fn()}}));
jest.mock('@lib/dicomweb/client', () => ({
  isConfigured: jest.fn(),
  stowStudy: jest.fn(),
  buildStudyUrl: jest.fn()}));
jest.mock('@services/radiology-order/radiology-order.service', () => ({
  createRadiologyOrder: jest.fn()}));
jest.mock('@services/opd-flow/opd-flow.service', () => ({
  syncDiagnosticsStage: jest.fn().mockResolvedValue(null)}));
jest.mock('@services/radiology-workspace/radiology.shared', () => {
  const actual = jest.requireActual('@services/radiology-workspace/radiology.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn()};
});

const radiologyWorkspaceRepository = require('@repositories/radiology-workspace/radiology-workspace.repository');
const radiologyOrderService = require('@services/radiology-order/radiology-order.service');
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const { createAuditLog } = require('@lib/audit');
const { emitToUsers } = require('@lib/websocket');
const prisma = require('@prisma/client');
const dicomWebClient = require('@lib/dicomweb/client');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow} = require('@services/radiology-workspace/radiology.shared');
const radiologyWorkspaceService = require('@services/radiology-workspace/radiology-workspace.service');

const now = new Date('2026-02-27T10:20:00.000Z');

const buildOrder = (overrides = {}) => ({
  id: 'order-internal-1',
  human_friendly_id: 'RAD0000001',
  status: 'ORDERED',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT0000001',
    tenant_id: 'tenant-internal-1',
    facility_id: 'facility-internal-1',
    first_name: 'Amina',
    last_name: 'Stone'},
  encounter: {
    id: 'encounter-internal-1',
    human_friendly_id: 'ENC0000001'},
  radiology_test: {
    id: 'rtest-internal-1',
    human_friendly_id: 'RDT0000001',
    name: 'Chest XRay',
    code: 'CXR',
    modality: 'XRAY'},
  results: [],
  imaging_studies: [],
  ...overrides});

const flushAsync = () => new Promise((resolve) => setImmediate(resolve));

describe('radiology-workspace.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // clearAllMocks() does not drop queued mockResolvedValueOnce implementations,
    // so reset the shared id resolvers to keep each test fully isolated.
    resolveModelIdOrThrow.mockReset();
    resolveModelRecordOrThrow.mockReset();
    createAuditLog.mockResolvedValue({});
    opdFlowService.syncDiagnosticsStage.mockResolvedValue(null);
    prisma.user_role.findMany.mockResolvedValue([
      { user_id: 'user-1' },
      { user_id: 'actor-1' },
      { user_id: 'user-2' }]);
  });

  it('resolves legacy radiology route identifiers to canonical /radiology routes', async () => {
    resolveModelRecordOrThrow.mockResolvedValue({
      id: '19e508a6-ea17-4c7f-a0f4-b6f0ac401cb5',
      human_friendly_id: 'RADRES0005'});

    const resolved = await radiologyWorkspaceService.resolveLegacyRouteIdentifier(
      'radiology-results',
      '19e508a6-ea17-4c7f-a0f4-b6f0ac401cb5'
    );

    expect(resolved).toEqual({
      id: 'RADRES0005',
      resource: 'results',
      identifier: 'RADRES0005',
      route: '/radiology/results/RADRES0005',
      matched_by: 'uuid'});
  });

  it('assignRadiologyOrder persists scheduling fields and emits realtime update', async () => {
    resolveModelIdOrThrow
      .mockResolvedValueOnce('order-internal-1')
      .mockResolvedValueOnce('user-internal-9')
      .mockResolvedValueOnce('equip-internal-1');

    const before = buildOrder();
    const after = buildOrder({
      assigned_user_id: 'user-internal-9',
      scheduled_at: new Date('2026-03-01T09:00:00.000Z'),
      room: 'XRAY-1',
      equipment_registry_id: 'equip-internal-1',
      assigned_user: {
        id: 'user-internal-9',
        human_friendly_id: 'USR0000009',
        email: 'tech@example.com',
        profile: { first_name: 'Ray', last_name: 'Tech' }},
      equipment_registry: {
        id: 'equip-internal-1',
        human_friendly_id: 'EQP0000001',
        equipment_name: 'DR Room A',
        equipment_code: 'XR-A',
        status: 'ACTIVE'}});

    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    radiologyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(before)
      .mockResolvedValueOnce(after);
    radiologyWorkspaceRepository.txUpdateOrder.mockResolvedValue(after);

    const result = await radiologyWorkspaceService.assignRadiologyOrder(
      'RAD0000001',
      {
        assignee_user_id: 'USR0000009',
        scheduled_at: '2026-03-01T09:00:00.000Z',
        room: 'XRAY-1',
        equipment_registry_id: 'EQP0000001'},
      'actor-1',
      '127.0.0.1'
    );

    expect(radiologyWorkspaceRepository.txUpdateOrder).toHaveBeenCalledWith(
      {},
      'order-internal-1',
      expect.objectContaining({
        assigned_user_id: 'user-internal-9',
        room: 'XRAY-1',
        equipment_registry_id: 'equip-internal-1'})
    );
    expect(result?.workflow?.order?.id).toBe('RAD0000001');
    expect(result?.assignment?.room).toBe('XRAY-1');

    await flushAsync();

    expect(emitToUsers).toHaveBeenCalledWith(
      ['user-1', 'user-2'],
      'diagnostic.radiology_workflow_updated',
      expect.objectContaining({
        action: 'ASSIGN',
        order_id: 'RAD0000001'})
    );
  });

  it('startRadiologyOrder blocks unpaid orders at the billing gate', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    const unpaid = buildOrder({
      request_details: {
        billing: {
          payment_status: 'PENDING',
          total_amount: '80.00',
          currency: 'USD'}}});

    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    radiologyWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaid);

    await expect(
      radiologyWorkspaceService.startRadiologyOrder('RAD0000001', {}, 'actor-1', '127.0.0.1')
    ).rejects.toMatchObject({
      message: 'errors.radiology_order.payment_required',
      statusCode: 402});
  });

  it('addendumRadiologyResult creates a new version without mutating the FINAL report', async () => {
    resolveModelIdOrThrow.mockResolvedValue('result-internal-1');

    const finalResult = {
      id: 'result-internal-1',
      human_friendly_id: 'RRS0000001',
      radiology_order_id: 'order-internal-1',
      status: 'FINAL',
      report_text: 'Original final report',
      report_version: 1,
      reported_at: now,
      created_at: now,
      updated_at: now,
      attestations: []};
    const amendedResult = {
      id: 'result-internal-2',
      human_friendly_id: 'RRS0000002',
      radiology_order_id: 'order-internal-1',
      parent_result_id: 'result-internal-1',
      status: 'AMENDED',
      report_text: 'Original final report\n\nAddendum:\nClarified findings',
      addendum_text: 'Clarified findings',
      report_version: 2,
      reported_at: now,
      created_at: now,
      updated_at: now,
      attestations: []};
    const orderWithFinal = buildOrder({
      status: 'IN_PROCESS',
      results: [finalResult]});
    const orderWithAddendum = buildOrder({
      status: 'IN_PROCESS',
      results: [amendedResult, finalResult]});

    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    radiologyWorkspaceRepository.txFindResultById.mockResolvedValue(finalResult);
    radiologyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(orderWithFinal)
      .mockResolvedValueOnce(orderWithAddendum);
    radiologyWorkspaceRepository.txCreateResult.mockResolvedValue(amendedResult);
    radiologyWorkspaceRepository.txUpdateResult = jest.fn();

    const result = await radiologyWorkspaceService.addendumRadiologyResult(
      'RRS0000001',
      { addendum_text: 'Clarified findings' },
      'actor-1',
      '127.0.0.1'
    );

    expect(radiologyWorkspaceRepository.txCreateResult).toHaveBeenCalledWith(
      {},
      expect.objectContaining({
        parent_result_id: 'result-internal-1',
        status: 'AMENDED',
        addendum_text: 'Clarified findings',
        report_version: 2})
    );
    expect(radiologyWorkspaceRepository.txUpdateResult).not.toHaveBeenCalled();
    expect(result?.result?.status).toBe('AMENDED');
    expect(result?.result?.report_version).toBe(2);
    expect(result?.result?.parent_result_id).toBe('result-internal-1');
  });

  it('creates workspace radiology orders through the shared multi-test order service', async () => {
    radiologyOrderService.createRadiologyOrder.mockResolvedValue({
      display_id: 'RAD0000001',
      created_orders: [
        { id: 'order-internal-1', display_id: 'RAD0000001' },
        { id: 'order-internal-2', display_id: 'RAD0000002' }]});
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    radiologyWorkspaceRepository.findOrderById.mockResolvedValue(buildOrder());

    const result = await radiologyWorkspaceService.createRadiologyOrder(
      {
        patient_id: 'PAT0000001',
        encounter_id: 'ENC0000001',
        notes: 'Persistent request note',
        requested_tests: [
          {
            radiology_test_id: 'RADT000001',
            clinical_note: 'Chest pain',
            request_details: { modality: 'XRAY', priority: 'URGENT' }},
          {
            radiology_test_id: 'STD_RAD_TEST_RAD-00002',
            request_details: { modality: 'CT', body_region: 'Head' }}]},
      'actor-1',
      '127.0.0.1'
    );

    expect(radiologyOrderService.createRadiologyOrder).toHaveBeenCalledWith(
      expect.objectContaining({
        patient_id: 'PAT0000001',
        encounter_id: 'ENC0000001',
        requested_tests: [
          expect.objectContaining({
            radiology_test_id: 'RADT000001',
            clinical_note: 'Chest pain',
            request_details: expect.objectContaining({
              modality: 'XRAY',
              priority: 'URGENT'})}),
          expect.objectContaining({
            radiology_test_id: 'STD_RAD_TEST_RAD-00002',
            clinical_note: 'Persistent request note',
            request_details: expect.objectContaining({
              modality: 'CT',
              body_region: 'Head'})})]}),
      'actor-1',
      '127.0.0.1'
    );
    expect(result.created_orders).toHaveLength(2);
    expect(result.workflow.order.id).toBe('RAD0000001');
  });

  it('keeps legacy single-test workspace order payloads compatible', async () => {
    radiologyOrderService.createRadiologyOrder.mockResolvedValue({
      display_id: 'RAD0000001'});
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    radiologyWorkspaceRepository.findOrderById.mockResolvedValue(buildOrder());

    await radiologyWorkspaceService.createRadiologyOrder(
      {
        patient_id: 'PAT0000001',
        encounter_id: 'ENC0000001',
        radiology_test_id: 'RADT000001',
        notes: 'Legacy clinical note',
        request_details: { modality: 'XRAY', priority: 'ROUTINE' }},
      'actor-1',
      '127.0.0.1'
    );

    expect(radiologyOrderService.createRadiologyOrder).toHaveBeenCalledWith(
      expect.objectContaining({
        requested_tests: [
          expect.objectContaining({
            radiology_test_id: 'RADT000001',
            clinical_note: 'Legacy clinical note',
            request_details: expect.objectContaining({
              modality: 'XRAY',
              priority: 'ROUTINE'})})]}),
      'actor-1',
      '127.0.0.1'
    );
  });

  it('returns scoped reference data with friendly identifiers only', async () => {
    radiologyWorkspaceRepository.findReferencePatients.mockResolvedValue([
      {
        id: 'patient-internal-1',
        human_friendly_id: 'PAT0000001',
        first_name: 'Amina',
        last_name: 'Stone',
        contacts: [{ value: '+256700000001' }]}]);
    radiologyWorkspaceRepository.findReferenceEncounters.mockResolvedValue([
      {
        id: 'encounter-internal-1',
        human_friendly_id: 'ENC0000001',
        status: 'IN_PROGRESS',
        started_at: now,
        patient: {
          id: 'patient-internal-1',
          human_friendly_id: 'PAT0000001',
          first_name: 'Amina',
          last_name: 'Stone'}}]);
    radiologyWorkspaceRepository.findReferenceRadiologyTests.mockResolvedValue([
      {
        id: 'rtest-internal-1',
        human_friendly_id: 'RDT0000001',
        name: 'Chest XRay',
        code: 'CXR',
        modality: 'XRAY'}]);
    radiologyWorkspaceRepository.findReferenceUsers.mockResolvedValue([
      {
        id: 'user-internal-1',
        human_friendly_id: 'USR0000001',
        email: 'tech@example.com',
        profile: { first_name: 'Imani', middle_name: null, last_name: 'Tech' }}]);

    const data = await radiologyWorkspaceService.getRadiologyReferenceData(
      { search: 'amina' },
      { tenant_id: 'tenant-internal-1', facility_id: 'facility-internal-1' }
    );

    expect(data.patients[0]).toEqual(
      expect.objectContaining({
        value: 'PAT0000001'})
    );
    expect(data.encounters[0]).toEqual(
      expect.objectContaining({
        value: 'ENC0000001',
        patient_id: 'PAT0000001'})
    );
    expect(data.radiology_tests[0]).toEqual(
      expect.objectContaining({
        value: 'RDT0000001'})
    );
    expect(data.assignees[0]).toEqual(
      expect.objectContaining({
        value: 'USR0000001'})
    );
  });

  it('creates radiology order and returns workflow payload', async () => {
    resolveModelRecordOrThrow.mockResolvedValueOnce({
      id: 'patient-internal-1',
      tenant_id: 'tenant-internal-1'});
    resolveModelIdOrThrow
      .mockResolvedValueOnce('encounter-internal-1')
      .mockResolvedValueOnce('rtest-internal-1');
    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    radiologyWorkspaceRepository.txCreateOrder.mockResolvedValue({
      id: 'order-internal-1'});
    radiologyWorkspaceRepository.txFindOrderById.mockResolvedValue(buildOrder());

    const result = await radiologyWorkspaceService.createRadiologyOrder(
      {
        patient_id: 'PAT0000001',
        encounter_id: 'ENC0000001',
        radiology_test_id: 'RDT0000001'},
      'actor-1',
      '127.0.0.1'
    );

    expect(result.workflow?.order?.id).toBe('RAD0000001');
    expect(result.order?.id).toBe('RAD0000001');
  });


  it('updates request details and emits a radiology realtime refresh', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );

    const beforeOrder = buildOrder({
      clinical_note: 'Old notes',
      request_details: {
        modality: 'XRAY',
        body_region: 'Chest',
        priority: 'ROUTINE'}});
    const afterOrder = buildOrder({
      clinical_note: 'Updated notes',
      request_details: {
        modality: 'XRAY',
        body_region: 'Chest',
        laterality: 'LEFT',
        priority: 'URGENT'}});

    radiologyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(beforeOrder)
      .mockResolvedValueOnce(afterOrder);

    const response = await radiologyWorkspaceService.updateRadiologyOrderRequestDetails(
      'RAD0000001',
      {
        clinical_note: 'Updated notes',
        request_details: {
          laterality: 'LEFT',
          priority: 'URGENT'}},
      'actor-1',
      '127.0.0.1'
    );

    expect(radiologyWorkspaceRepository.txUpdateOrder).toHaveBeenCalledWith(
      {},
      'order-internal-1',
      {
        clinical_note: 'Updated notes',
        request_details: expect.objectContaining({
          modality: 'XRAY',
          body_region: 'Chest',
          laterality: 'LEFT',
          priority: 'URGENT'})}
    );
    expect(response.workflow.order.request_details).toEqual(
      expect.objectContaining({
        laterality: 'LEFT',
        priority: 'URGENT'})
    );

    await flushAsync();

    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'UPDATE_REQUEST_DETAILS',
        entity: 'radiology_order',
        entity_id: 'order-internal-1'})
    );
    expect(emitToUsers).toHaveBeenCalledWith(
      ['user-1', 'user-2'],
      'diagnostic.radiology_workflow_updated',
      expect.objectContaining({
        action: 'UPDATE_REQUEST_DETAILS',
        order_id: 'RAD0000001'})
    );
  });

  it('syncStudyToPacs returns FAILED status when pacs is not configured', async () => {
    resolveModelIdOrThrow.mockResolvedValue('study-internal-1');
    radiologyWorkspaceRepository.findStudyById.mockResolvedValue({
      id: 'study-internal-1',
      human_friendly_id: 'STD0000001',
      radiology_order_id: 'order-internal-1',
      modality: 'XRAY',
      assets: [],
      pacs_links: []});
    radiologyWorkspaceRepository.findOrderById.mockResolvedValue(buildOrder());
    dicomWebClient.isConfigured.mockReturnValue(false);

    const result = await radiologyWorkspaceService.syncStudyToPacs(
      'STD0000001',
      {},
      'actor-1',
      '127.0.0.1'
    );

    expect(result).toEqual(
      expect.objectContaining({
        sync_status: 'FAILED'})
    );
    expect(result.error).toContain('PACS_DICOMWEB_BASE_URL');
  });

  it('syncStudyToPacs returns refreshed workflow after successful sync', async () => {
    resolveModelIdOrThrow.mockResolvedValue('study-internal-1');
    radiologyWorkspaceRepository.findStudyById.mockResolvedValue({
      id: 'study-internal-1',
      human_friendly_id: 'STD0000001',
      radiology_order_id: 'order-internal-1',
      modality: 'XRAY',
      assets: [],
      pacs_links: []});
    radiologyWorkspaceRepository.findOrderById.mockResolvedValue(
      buildOrder({
        imaging_studies: [
          {
            id: 'study-internal-1',
            human_friendly_id: 'STD0000001',
            modality: 'XRAY',
            performed_at: now,
            created_at: now,
            updated_at: now,
            assets: [],
            pacs_links: []}]})
    );
    dicomWebClient.isConfigured.mockReturnValue(true);
    dicomWebClient.stowStudy.mockResolvedValue({ studyUid: '1.2.3' });
    dicomWebClient.buildStudyUrl.mockReturnValue('https://pacs.example/studies/1.2.3');

    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    radiologyWorkspaceRepository.txCreatePacsLink.mockResolvedValue({
      id: 'pacs-link-1',
      human_friendly_id: 'PAC0000001',
      url: 'https://pacs.example/studies/1.2.3',
      created_at: now,
      updated_at: now,
      imaging_study_id: 'study-internal-1'});
    radiologyWorkspaceRepository.txFindOrderById.mockResolvedValue(
      buildOrder({
        imaging_studies: [
          {
            id: 'study-internal-1',
            human_friendly_id: 'STD0000001',
            modality: 'XRAY',
            performed_at: now,
            created_at: now,
            updated_at: now,
            assets: [],
            pacs_links: [
              {
                id: 'pacs-link-1',
                human_friendly_id: 'PAC0000001',
                url: 'https://pacs.example/studies/1.2.3',
                created_at: now,
                updated_at: now}]}]})
    );

    const result = await radiologyWorkspaceService.syncStudyToPacs(
      'STD0000001',
      {},
      'actor-1',
      '127.0.0.1'
    );

    expect(result.sync_status).toBe('SUCCESS');
    expect(result.workflow?.order?.unsynced_study_count).toBe(0);
  });

  it('requestRadiologyResultFinalization records REQUEST attestation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('result-internal-1');

    const order = buildOrder({
      status: 'IN_PROCESS',
      results: [
        {
          id: 'result-internal-1',
          human_friendly_id: 'RADRES0001',
          radiology_order_id: 'order-internal-1',
          status: 'DRAFT',
          report_text: 'Draft report',
          reported_at: now,
          created_at: now,
          updated_at: now,
          attestations: []}]});

    const resultWithRequest = {
      ...order.results[0],
      attestations: [
        {
          id: 'att-request-1',
          human_friendly_id: 'RAT000001',
          radiology_result_id: 'result-internal-1',
          phase: 'REQUEST',
          attested_by_user_id: 'actor-1',
          attested_role: 'DOCTOR',
          attested_at: now,
          created_at: now,
          updated_at: now}]};

    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    radiologyWorkspaceRepository.txFindResultById
      .mockResolvedValueOnce(order.results[0])
      .mockResolvedValueOnce(resultWithRequest);
    radiologyWorkspaceRepository.txFindResultAttestation.mockResolvedValueOnce(null);
    radiologyWorkspaceRepository.txCreateResultAttestation.mockResolvedValue({
      id: 'att-request-1'});
    radiologyWorkspaceRepository.txFindOrderById.mockResolvedValue(order);

    const response = await radiologyWorkspaceService.requestRadiologyResultFinalization(
      'RADRES0001',
      { statement: 'Please finalize' },
      'actor-1',
      'DOCTOR',
      '127.0.0.1'
    );

    expect(response.result.finalization.requested).toBe(true);
    expect(response.result.finalization.pending_attestation).toBe(true);
  });

  it('attestRadiologyResultFinalization rejects same-user second signature', async () => {
    resolveModelIdOrThrow.mockResolvedValue('result-internal-1');

    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    radiologyWorkspaceRepository.txFindResultById.mockResolvedValue({
      id: 'result-internal-1',
      human_friendly_id: 'RADRES0001',
      radiology_order_id: 'order-internal-1',
      status: 'DRAFT',
      report_text: 'Draft report',
      reported_at: now,
      created_at: now,
      updated_at: now,
      attestations: []});
    radiologyWorkspaceRepository.txFindResultAttestation.mockResolvedValueOnce({
      id: 'att-request-1',
      phase: 'REQUEST',
      attested_by_user_id: 'actor-1'});

    await expect(
      radiologyWorkspaceService.attestRadiologyResultFinalization(
        'RADRES0001',
        {},
        'actor-1',
        'DOCTOR',
        '127.0.0.1'
      )
    ).rejects.toBeInstanceOf(HttpError);
  });

  it('startRadiologyOrder transitions ORDERED to IN_PROCESS', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    radiologyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(buildOrder({ status: 'ORDERED' }))
      .mockResolvedValueOnce(buildOrder({ status: 'IN_PROCESS' }));

    const response = await radiologyWorkspaceService.startRadiologyOrder(
      'RAD0000001',
      {},
      'actor-1',
      '127.0.0.1'
    );

    expect(radiologyWorkspaceRepository.txUpdateOrder).toHaveBeenCalledWith(
      {},
      'order-internal-1',
      { status: 'IN_PROCESS' }
    );
    expect(response.workflow.order.status).toBe('IN_PROCESS');
  });

  it('completeRadiologyOrder requires a FINAL result before completion', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    radiologyWorkspaceRepository.txFindOrderById.mockResolvedValue(
      buildOrder({ status: 'IN_PROCESS', results: [] })
    );

    await expect(
      radiologyWorkspaceService.completeRadiologyOrder(
        'RAD0000001',
        {},
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toBeInstanceOf(HttpError);
    expect(opdFlowService.syncDiagnosticsStage).not.toHaveBeenCalled();
  });

  it('completeRadiologyOrder syncs the OPD diagnostics stage on completion', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    const finalResult = {
      id: 'result-internal-1',
      human_friendly_id: 'RADRES0001',
      radiology_order_id: 'order-internal-1',
      status: 'FINAL',
      report_text: 'Final report',
      reported_at: now,
      created_at: now,
      updated_at: now,
      attestations: []};
    radiologyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(
        buildOrder({ status: 'IN_PROCESS', results: [finalResult] })
      )
      .mockResolvedValueOnce(
        buildOrder({ status: 'COMPLETED', results: [finalResult] })
      );

    const response = await radiologyWorkspaceService.completeRadiologyOrder(
      'RAD0000001',
      {},
      'actor-1',
      '127.0.0.1'
    );

    expect(response.workflow.order.status).toBe('COMPLETED');

    await flushAsync();

    expect(opdFlowService.syncDiagnosticsStage).toHaveBeenCalledWith(
      'encounter-internal-1',
      expect.objectContaining({ trigger: 'RADIOLOGY_ORDER_COMPLETED' })
    );
  });

  it('cancelRadiologyOrder syncs the OPD diagnostics stage on cancellation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    radiologyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(buildOrder({ status: 'ORDERED' }))
      .mockResolvedValueOnce(buildOrder({ status: 'CANCELLED' }));

    await radiologyWorkspaceService.cancelRadiologyOrder(
      'RAD0000001',
      { reason: 'Duplicate order' },
      'actor-1',
      '127.0.0.1'
    );

    await flushAsync();

    expect(opdFlowService.syncDiagnosticsStage).toHaveBeenCalledWith(
      'encounter-internal-1',
      expect.objectContaining({ trigger: 'RADIOLOGY_ORDER_CANCELLED' })
    );
  });

  it('finalizeRadiologyResult finalizes a draft and syncs the OPD diagnostics stage', async () => {
    resolveModelIdOrThrow.mockResolvedValue('result-internal-1');
    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    const draftResult = {
      id: 'result-internal-1',
      human_friendly_id: 'RADRES0001',
      radiology_order_id: 'order-internal-1',
      status: 'DRAFT',
      report_text: 'Draft report',
      reported_at: now,
      created_at: now,
      updated_at: now,
      attestations: []};
    const finalResult = { ...draftResult, status: 'FINAL' };
    radiologyWorkspaceRepository.txFindResultById.mockResolvedValue(draftResult);
    radiologyWorkspaceRepository.txUpdateResult.mockResolvedValue(finalResult);
    radiologyWorkspaceRepository.txFindOrderById.mockResolvedValue(
      buildOrder({ status: 'IN_PROCESS', results: [finalResult] })
    );

    const response = await radiologyWorkspaceService.finalizeRadiologyResult(
      'RADRES0001',
      {},
      'actor-1',
      '127.0.0.1'
    );

    expect(radiologyWorkspaceRepository.txUpdateResult).toHaveBeenCalledWith(
      {},
      'result-internal-1',
      expect.objectContaining({ status: 'FINAL' })
    );
    expect(response.result.status).toBe('FINAL');

    await flushAsync();

    expect(opdFlowService.syncDiagnosticsStage).toHaveBeenCalledWith(
      'encounter-internal-1',
      expect.objectContaining({ trigger: 'RADIOLOGY_RESULT_FINALIZED' })
    );
  });

  it('does not sync the OPD diagnostics stage for orders without an encounter', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    radiologyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(
        buildOrder({ status: 'ORDERED', encounter_id: null, encounter: null })
      )
      .mockResolvedValueOnce(
        buildOrder({ status: 'CANCELLED', encounter_id: null, encounter: null })
      );

    await radiologyWorkspaceService.cancelRadiologyOrder(
      'RAD0000001',
      { reason: 'Walk-in cancelled' },
      'actor-1',
      '127.0.0.1'
    );

    await flushAsync();

    expect(opdFlowService.syncDiagnosticsStage).not.toHaveBeenCalled();
  });

  it('throws not found when legacy resource identifier is missing', async () => {
    await expect(
      radiologyWorkspaceService.resolveLegacyRouteIdentifier('radiology-results', '')
    ).rejects.toBeInstanceOf(HttpError);
  });
});
