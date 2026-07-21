const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-workspace/lab-workspace.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn()}));
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  DIAGNOSTIC_EVENTS: {
    LAB_WORKFLOW_UPDATED: 'diagnostic.lab_workflow_updated',
    LAB_RESULT_READY: 'diagnostic.lab_result_ready',
    LAB_RESULT_UPDATED: 'diagnostic.lab_result_updated',
    LAB_RESULT_CRITICAL: 'diagnostic.lab_result_critical'},
  NOTIFICATION_EVENTS: {
    NOTIFICATION_CREATED: 'notification.created'}}));
jest.mock('@services/opd-flow/opd-flow.service', () => ({
  syncDiagnosticsStage: jest.fn().mockResolvedValue(null)}));
jest.mock('@prisma/client', () => ({
  user_role: {
    findMany: jest.fn()},
  notification: {
    create: jest.fn()},
  notification_delivery: {
    create: jest.fn()}}));
jest.mock('@services/lab-workspace/lab.shared', () => {
  const actual = jest.requireActual('@services/lab-workspace/lab.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn()};
});

const labWorkspaceRepository = require('@repositories/lab-workspace/lab-workspace.repository');
const { createAuditLog } = require('@lib/audit');
const { emitToUser, emitToUsers } = require('@lib/websocket');
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const prisma = require('@prisma/client');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow} = require('@services/lab-workspace/lab.shared');
const labWorkspaceService = require('@services/lab-workspace/lab-workspace.service');

const now = new Date('2026-02-27T09:15:00.000Z');

const buildBaseOrder = (overrides = {}) => ({
  id: 'order-internal-1',
  human_friendly_id: 'LAB0000001',
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
  items: [],
  samples: [],
  ...overrides});

const flushAsync = () => new Promise((resolve) => setImmediate(resolve));

describe('lab-workspace.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    opdFlowService.syncDiagnosticsStage.mockResolvedValue(null);
    prisma.notification.create.mockResolvedValue({
      id: 'notification-internal-1',
      human_friendly_id: 'NOT0000001',
      user_id: 'doctor-1',
      notification_type: 'LAB',
      priority: 'URGENT',
      title: 'Critical lab result',
      message: 'Critical lab result for Amina Stone requires review.',
      target_path: '/lab?id=LAB0000001',
      created_at: now});
    prisma.notification_delivery.create.mockResolvedValue({});
    prisma.user_role.findMany.mockResolvedValue([
      { user_id: 'user-1' },
      { user_id: 'actor-1' },
      { user_id: 'user-2' }]);
  });

  it('resolves legacy lab route identifiers to canonical /lab routes', async () => {
    resolveModelRecordOrThrow.mockResolvedValue({
      id: '46e0498d-c2be-4f1d-bc69-d6a72fd6fb85',
      human_friendly_id: 'LABRES0005'});

    const resolved = await labWorkspaceService.resolveLegacyRouteIdentifier(
      'lab-results',
      '46e0498d-c2be-4f1d-bc69-d6a72fd6fb85'
    );

    expect(resolved).toEqual({
      id: 'LABRES0005',
      resource: 'results',
      identifier: 'LABRES0005',
      route: '/lab/results/LABRES0005',
      matched_by: 'uuid'});
  });

  it('returns a stable empty patient workbench response', async () => {
    labWorkspaceRepository.findManyOrders.mockResolvedValue(undefined);
    labWorkspaceRepository.countOrders.mockResolvedValue(undefined);
    labWorkspaceRepository.countOrderItems.mockResolvedValue(undefined);
    labWorkspaceRepository.countResults.mockResolvedValue(undefined);
    labWorkspaceRepository.countSamples.mockResolvedValue(undefined);

    const result = await labWorkspaceService.getLabWorkbench(
      { view: 'PATIENTS' },
      1,
      25,
      'ordered_at',
      'desc'
    );

    expect(result).toEqual(
      expect.objectContaining({
        summary: expect.objectContaining({
          view: 'patients',
          total_orders: 0,
          total_patients: 0,
          actionable_patients: 0}),
        worklist: [],
        pagination: expect.objectContaining({
          page: 1,
          limit: 25,
          total: 0,
          hasNextPage: false,
          hasPreviousPage: false})})
    );
  });

  it('scopes lab workbench queries through patient tenant and facility fields', async () => {
    labWorkspaceRepository.findManyOrders.mockResolvedValue([]);
    labWorkspaceRepository.countOrders.mockResolvedValue(0);
    labWorkspaceRepository.countOrderItems.mockResolvedValue(0);
    labWorkspaceRepository.countResults.mockResolvedValue(0);
    labWorkspaceRepository.countSamples.mockResolvedValue(0);

    await labWorkspaceService.getLabWorkbench(
      { view: 'ORDERS' },
      1,
      25,
      'ordered_at',
      'desc',
      {
        tenant_id: 'tenant-internal-1',
        facility_id: 'facility-internal-1'}
    );

    const orderWhere = labWorkspaceRepository.findManyOrders.mock.calls[0][0];

    expect(orderWhere.AND).toEqual(
      expect.arrayContaining([
        {
          patient: {
            deleted_at: null,
            tenant_id: 'tenant-internal-1',
            facility_id: 'facility-internal-1'}},
        {
          items: {
            some: { deleted_at: null, status: { not: 'CANCELLED' } }}}])
    );
  });

  it('searches lab order context patients through lab-scoped patient fields', async () => {
    labWorkspaceRepository.findManyPatients.mockResolvedValue([
      {
        id: 'patient-internal-1',
        human_friendly_id: 'PAT0000001',
        first_name: 'Amina',
        last_name: 'Stone',
        contacts: [
          { contact_type: 'PHONE', value: '+256700000001', is_primary: true }],
        identifiers: [
          { identifier_value: 'NIN123', is_primary: true }]}]);

    const result = await labWorkspaceService.searchLabOrderContextPatients(
      { search: 'Amina', limit: '8' },
      { tenant_id: 'tenant-internal-1', facility_id: 'facility-internal-1' }
    );

    expect(labWorkspaceRepository.findManyPatients).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-internal-1',
        facility_id: 'facility-internal-1',
        OR: expect.arrayContaining([
          { first_name: { contains: 'Amina' } },
          { human_friendly_id: { contains: 'AMINA' } }])}),
      0,
      8,
      [{ updated_at: 'desc' }, { created_at: 'desc' }],
      expect.any(Object)
    );
    expect(result.patients).toEqual([
      {
        id: 'PAT0000001',
        display_id: 'PAT0000001',
        display_name: 'Amina Stone',
        identifier: 'NIN123',
        primary_phone: '+256700000001'}]);
  });

  it('loads lab order patient context without requiring patient module access', async () => {
    labWorkspaceRepository.findPatientById.mockResolvedValue({
      id: 'patient-internal-1',
      human_friendly_id: 'PAT0000001',
      first_name: 'Amina',
      last_name: 'Stone',
      contacts: [],
      identifiers: [],
      encounters: [
        {
          id: 'encounter-internal-1',
          human_friendly_id: 'ENC0000001',
          encounter_type: 'OPD',
          status: 'OPEN',
          started_at: now,
          ended_at: null}]});

    const result = await labWorkspaceService.getLabOrderPatientContext(
      'PAT0000001',
      { tenant_id: 'tenant-internal-1' }
    );

    expect(labWorkspaceRepository.findPatientById).toHaveBeenCalledWith(
      'PAT0000001',
      { tenant_id: 'tenant-internal-1' },
      expect.any(Object)
    );
    expect(result).toEqual({
      patient: expect.objectContaining({
        id: 'PAT0000001',
        display_name: 'Amina Stone'}),
      encounters: [
        {
          id: 'ENC0000001',
          display_id: 'ENC0000001',
          title: 'ENC0000001',
          status: 'OPEN',
          type: 'OPD',
          started_at: now,
          ended_at: null}]});
  });

  it('returns an order workbench response with pagination total', async () => {
    labWorkspaceRepository.findManyOrders
      .mockResolvedValueOnce([buildBaseOrder()])
      .mockResolvedValueOnce([buildBaseOrder()]);
    labWorkspaceRepository.countOrders
      .mockResolvedValueOnce(1)
      .mockResolvedValueOnce(1)
      .mockResolvedValueOnce(1)
      .mockResolvedValueOnce(0)
      .mockResolvedValueOnce(0)
      .mockResolvedValueOnce(0);
    labWorkspaceRepository.countOrderItems.mockResolvedValue(0);
    labWorkspaceRepository.countResults.mockResolvedValue(0);
    labWorkspaceRepository.countSamples.mockResolvedValue(0);

    const result = await labWorkspaceService.getLabWorkbench(
      { view: 'ORDERS' },
      1,
      25,
      'ordered_at',
      'desc'
    );

    expect(result.summary).toEqual(
      expect.objectContaining({
        view: 'orders',
        total_orders: 1})
    );
    expect(result.worklist).toHaveLength(1);
    expect(result.worklist[0]).toEqual(
      expect.objectContaining({
        id: 'LAB0000001',
        display_id: 'LAB0000001',
        patient_id: 'PAT0000001'})
    );
    expect(result.pagination).toEqual(
      expect.objectContaining({
        page: 1,
        limit: 25,
        total: 1})
    );
  });

  it('returns requested tests and panel metadata in order workflow detail', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    labWorkspaceRepository.findOrderById.mockResolvedValue(
      buildBaseOrder({
        items: [
          {
            id: 'order-item-internal-1',
            human_friendly_id: 'LIT0000001',
            lab_order_id: 'order-internal-1',
            lab_test_id: 'lab-test-internal-1',
            panel_id: 'LPN0000001',
            panel_display_name: 'Full blood count',
            panel_code: 'FBC',
            panel_sort_order: 1,
            panel_item_sort_order: 10,
            status: 'ORDERED',
            created_at: now,
            updated_at: now,
            lab_test: {
              id: 'lab-test-internal-1',
              human_friendly_id: 'LBT0000001',
              name: 'Hemoglobin',
              code: 'HGB',
              unit: 'g/dL',
              reference_ranges: [],
              unit_options: [],
              result_options: []},
            results: []},
          {
            id: '550e8400-e29b-41d4-a716-446655440001',
            human_friendly_id: null,
            lab_order_id: 'order-internal-1',
            lab_test_id: 'lab-test-internal-2',
            status: 'ORDERED',
            created_at: now,
            updated_at: now,
            lab_test: {
              id: 'lab-test-internal-2',
              human_friendly_id: 'LBT0000002',
              name: 'White Blood Cell Count',
              code: 'WBC',
              unit: '10^9/L',
              reference_ranges: [],
              unit_options: [],
              result_options: []},
            results: []}]})
    );

    const result = await labWorkspaceService.getLabOrderWorkflow('LAB0000001');

    expect(result.order.items).toEqual([
      expect.objectContaining({
        id: 'LIT0000001',
        display_id: 'LIT0000001',
        lab_test_id: 'LBT0000001',
        panel_id: 'LPN0000001',
        panel_display_name: 'Full blood count',
        panel_code: 'FBC',
        panel_sort_order: 1,
        panel_item_sort_order: 10,
        test_display_name: 'Hemoglobin'}),
      expect.objectContaining({
        id: '550e8400-e29b-41d4-a716-446655440001',
        display_id: null,
        lab_test_id: 'LBT0000002',
        test_display_name: 'White Blood Cell Count'})]);
  });

  it('groups patient workbench records without losing order identifiers', async () => {
    const secondOrder = buildBaseOrder({
      id: 'order-internal-2',
      human_friendly_id: 'LAB0000002',
      status: 'COLLECTED'});
    const records = [buildBaseOrder(), secondOrder];
    labWorkspaceRepository.findManyOrders
      .mockResolvedValueOnce(records)
      .mockResolvedValueOnce(records);
    labWorkspaceRepository.countOrders
      .mockResolvedValueOnce(2)
      .mockResolvedValueOnce(2)
      .mockResolvedValueOnce(0)
      .mockResolvedValueOnce(0)
      .mockResolvedValueOnce(0);
    labWorkspaceRepository.countOrderItems.mockResolvedValue(0);
    labWorkspaceRepository.countResults.mockResolvedValue(0);
    labWorkspaceRepository.countSamples.mockResolvedValue(0);

    const result = await labWorkspaceService.getLabWorkbench(
      { view: 'PATIENTS' },
      1,
      25,
      'ordered_at',
      'desc'
    );

    expect(result.worklist).toHaveLength(1);
    expect(result.worklist[0]).toEqual(
      expect.objectContaining({
        patient_worklist: true,
        order_count: 2,
        active_order_count: 2,
        order_ids: ['LAB0000001', 'LAB0000002'],
        order_display_ids: ['LAB0000001', 'LAB0000002']})
    );
    expect(result.pagination.total).toBe(1);
  });

  it('collectLabOrder emits lab workflow realtime update without blocking mutation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    const initialOrder = buildBaseOrder({
      status: 'ORDERED',
      items: [
        {
          id: 'item-internal-1',
          human_friendly_id: 'LIT0000001',
          status: 'ORDERED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            human_friendly_id: 'LBT0000001',
            name: 'CBC',
            code: 'CBC',
            unit: null},
          results: []}],
      samples: []});

    const refreshedOrder = buildBaseOrder({
      status: 'COLLECTED',
      items: [
        {
          id: 'item-internal-1',
          human_friendly_id: 'LIT0000001',
          status: 'COLLECTED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            human_friendly_id: 'LBT0000001',
            name: 'CBC',
            code: 'CBC',
            unit: null},
          results: []}],
      samples: [
        {
          id: 'sample-internal-1',
          human_friendly_id: 'LSP0000001',
          status: 'COLLECTED',
          collected_at: now,
          received_at: null,
          created_at: now,
          updated_at: now}]});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(initialOrder)
      .mockResolvedValueOnce(refreshedOrder);
    labWorkspaceRepository.txCreateSample.mockResolvedValue({
      id: 'sample-internal-1'});
    labWorkspaceRepository.txUpdateOrderItemsMany.mockResolvedValue({ count: 1 });
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-1' });

    const result = await labWorkspaceService.collectLabOrder(
      'LAB0000001',
      { notes: 'Collected at bedside' },
      'actor-1',
      '127.0.0.1'
    );

    expect(result?.workflow?.order?.id).toBe('LAB0000001');

    await flushAsync();

    expect(emitToUsers).toHaveBeenCalledWith(
      ['user-1', 'user-2'],
      'diagnostic.lab_workflow_updated',
      expect.objectContaining({
        action: 'COLLECT',
        order_id: 'LAB0000001'})
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-internal-1',
        entity: 'lab_order'})
    );
  });

  it('collectLabOrder blocks when pay-now billing is unpaid', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    const unpaidOrder = buildBaseOrder({
      status: 'ORDERED',
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '40.00',
        currency: 'USD'},
      items: [
        {
          id: 'item-internal-1',
          human_friendly_id: 'LIT0000001',
          status: 'ORDERED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            human_friendly_id: 'LBT0000001',
            name: 'CBC',
            code: 'CBC',
            unit: null},
          results: []}],
      samples: []});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);

    await expect(
      labWorkspaceService.collectLabOrder('LAB0000001', {}, 'actor-1', '127.0.0.1')
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('releaseLabOrderItem emits workflow and compatibility result realtime events', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');

    const releasedResultInternal = {
      id: 'result-internal-1',
      human_friendly_id: 'LRS0000001',
      status: 'CRITICAL',
      result_value: '12.8',
      result_unit: 'mg/dL',
      result_text: 'Critical potassium level',
      result_flag: 'CRITICAL_HIGH',
      is_positive: false,
      reference_range_label: 'Adult',
      reference_range_summary: 'Adult | Unit mg/dL | 3.5 - 5.1',
      reported_at: now,
      created_at: now,
      updated_at: now,
      lab_order_item_id: 'order-item-internal-1'};

    const refreshedOrder = buildBaseOrder({
      status: 'COMPLETED',
      items: [
        {
          id: 'order-item-internal-1',
          human_friendly_id: 'LIT0000002',
          status: 'COMPLETED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-2',
            human_friendly_id: 'LBT0000002',
            name: 'Potassium',
            code: 'K',
            unit: 'mg/dL'},
          results: [releasedResultInternal]}],
      samples: []});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'order-item-internal-1',
      lab_order_id: 'order-internal-1',
      status: 'IN_PROCESS',
      lab_test: {
        id: 'lab-test-internal-2',
        unit: 'mg/dL',
        reference_ranges: [
          {
            label: 'Adult',
            unit: 'mg/dL',
            age_min_value: 18,
            age_min_unit: 'YEAR',
            normal_min_value: '3.5',
            normal_max_value: '5.1',
            critical_min_value: '2.5',
            critical_max_value: '6.5',
            sort_order: 0}],
        unit_options: [],
        result_options: []},
      lab_order: {
        id: 'order-internal-1',
        status: 'IN_PROCESS',
        patient: {
          gender: 'FEMALE',
          date_of_birth: new Date('1994-06-01T00:00:00.000Z')}}});
    labWorkspaceRepository.txFindFirstResult
      .mockResolvedValueOnce({
        id: 'result-internal-1',
        status: 'PENDING',
        result_value: null,
        result_unit: null,
        result_text: null,
        reported_at: null})
      .mockResolvedValueOnce(null);
    labWorkspaceRepository.txUpdateResult.mockResolvedValue(releasedResultInternal);
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({
      id: 'order-item-internal-1'});
    labWorkspaceRepository.txCountOrderItems.mockResolvedValue(0);
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-1' });
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(refreshedOrder);

    const result = await labWorkspaceService.releaseLabOrderItem(
      'LIT0000002',
      {
        status: 'CRITICAL',
        result_value: '12.8',
        result_unit: 'mg/dL',
        result_text: 'Critical potassium level'},
      'actor-1',
      '127.0.0.1'
    );

    expect(result?.released_result?.id).toBe('LRS0000001');
    expect(labWorkspaceRepository.txUpdateResult).toHaveBeenCalledWith(
      {},
      'result-internal-1',
      expect.objectContaining({
        status: 'CRITICAL',
        result_flag: 'CRITICAL_HIGH',
        applied_reference_range_json: expect.objectContaining({
          label: 'Adult',
          unit: 'mg/dL',
          source: 'APPLIED_RULE'})})
    );

    await flushAsync();

    const emittedEvents = emitToUsers.mock.calls.map((call) => call[1]);
    expect(emittedEvents).toContain('diagnostic.lab_workflow_updated');
    expect(emittedEvents).toContain('diagnostic.lab_result_updated');
    expect(emittedEvents).toContain('diagnostic.lab_result_ready');

    const resultUpdatedPayload = emitToUsers.mock.calls.find(
      (call) => call[1] === 'diagnostic.lab_result_updated'
    )?.[2];
    expect(resultUpdatedPayload).toEqual(
      expect.objectContaining({
        result_id: 'LRS0000001',
        result_status: 'CRITICAL'})
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-internal-1',
        entity: 'lab_order_item'})
    );
  });

  it('releaseLabOrderItem escalates a critical result and syncs the OPD flow stage', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');

    const releasedResultInternal = {
      id: 'result-internal-9',
      human_friendly_id: 'LRS0000009',
      status: 'CRITICAL',
      result_value: '12.8',
      result_unit: 'mg/dL',
      result_text: 'Critical potassium level',
      result_flag: 'CRITICAL_HIGH',
      is_positive: false,
      reported_at: now,
      created_at: now,
      updated_at: now,
      lab_order_item_id: 'order-item-internal-1'};

    const refreshedOrder = buildBaseOrder({
      status: 'COMPLETED',
      ordered_by_user_id: 'doctor-1',
      encounter: {
        id: 'encounter-internal-1',
        human_friendly_id: 'ENC0000001',
        encounter_type: 'OPD',
        provider_user_id: 'provider-1'},
      items: [
        {
          id: 'order-item-internal-1',
          human_friendly_id: 'LIT0000009',
          status: 'COMPLETED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-9',
            human_friendly_id: 'LBT0000009',
            name: 'Potassium',
            code: 'K',
            unit: 'mg/dL'},
          results: [releasedResultInternal]}],
      samples: []});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'order-item-internal-1',
      lab_order_id: 'order-internal-1',
      status: 'IN_PROCESS',
      lab_test: {
        id: 'lab-test-internal-9',
        unit: 'mg/dL',
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      lab_order: { id: 'order-internal-1', status: 'IN_PROCESS', patient: {} }});
    labWorkspaceRepository.txFindFirstResult
      .mockResolvedValueOnce({
        id: 'result-internal-9',
        status: 'PENDING',
        result_value: null,
        result_unit: null,
        result_text: null,
        reported_at: null})
      .mockResolvedValueOnce(null);
    labWorkspaceRepository.txUpdateResult.mockResolvedValue(releasedResultInternal);
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({
      id: 'order-item-internal-1'});
    labWorkspaceRepository.txCountOrderItems.mockResolvedValue(0);
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-1' });
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(refreshedOrder);

    await labWorkspaceService.releaseLabOrderItem(
      'LIT0000009',
      { status: 'CRITICAL', result_value: '12.8', result_unit: 'mg/dL' },
      'actor-1',
      '127.0.0.1'
    );

    await flushAsync();
    await flushAsync();

    const emittedEvents = emitToUsers.mock.calls.map((call) => call[1]);
    expect(emittedEvents).toContain('diagnostic.lab_result_critical');

    const criticalCall = emitToUsers.mock.calls.find(
      (call) => call[1] === 'diagnostic.lab_result_critical'
    );
    expect(criticalCall?.[0]).toEqual(
      expect.arrayContaining(['doctor-1', 'provider-1'])
    );
    expect(criticalCall?.[0]).not.toContain('actor-1');

    expect(prisma.notification.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          tenant_id: 'tenant-internal-1',
          notification_type: 'LAB',
          priority: 'URGENT',
          context_type: 'lab_order'})})
    );
    expect(emitToUser).toHaveBeenCalledWith(
      'doctor-1',
      'notification.created',
      expect.objectContaining({ target_path: expect.any(String) })
    );

    expect(opdFlowService.syncDiagnosticsStage).toHaveBeenCalledWith(
      'encounter-internal-1',
      expect.objectContaining({ trigger: 'LAB_RESULT_RELEASED' })
    );
  });

  it('reverseLabOrderWorkflow reopens the latest released result and emits realtime updates', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    const releaseTimestamp = new Date('2026-02-27T10:45:00.000Z');
    const currentOrder = buildBaseOrder({
      status: 'COMPLETED',
      samples: [
        {
          id: 'sample-internal-1',
          human_friendly_id: 'LSP0000001',
          status: 'RECEIVED',
          collected_at: now,
          received_at: now,
          created_at: now,
          updated_at: now}],
      items: [
        {
          id: 'order-item-internal-3',
          human_friendly_id: 'LIT0000003',
          status: 'COMPLETED',
          created_at: now,
          updated_at: releaseTimestamp,
          lab_test: {
            id: 'lab-test-internal-3',
            human_friendly_id: 'LBT0000003',
            name: 'CBC',
            code: 'CBC',
            unit: 'g/dL'},
          results: [
            {
              id: 'result-internal-3',
              human_friendly_id: 'LRS0000003',
              status: 'NORMAL',
              result_value: '13.4',
              result_unit: 'g/dL',
              result_text: 'Normal result',
              result_flag: null,
              is_positive: false,
              reference_range_label: 'Adult',
              reference_range_summary: 'Adult | Unit g/dL | 11.5 - 15.5',
              reported_at: releaseTimestamp,
              created_at: now,
              updated_at: releaseTimestamp,
              lab_order_item_id: 'order-item-internal-3'}]}]});

    const reopenedOrder = buildBaseOrder({
      status: 'IN_PROCESS',
      samples: [
        {
          id: 'sample-internal-1',
          human_friendly_id: 'LSP0000001',
          status: 'RECEIVED',
          collected_at: now,
          received_at: now,
          created_at: now,
          updated_at: now}],
      items: [
        {
          id: 'order-item-internal-3',
          human_friendly_id: 'LIT0000003',
          status: 'IN_PROCESS',
          created_at: now,
          updated_at: releaseTimestamp,
          lab_test: {
            id: 'lab-test-internal-3',
            human_friendly_id: 'LBT0000003',
            name: 'CBC',
            code: 'CBC',
            unit: 'g/dL'},
          results: [
            {
              id: 'result-internal-3',
              human_friendly_id: 'LRS0000003',
              status: 'PENDING',
              result_value: '13.4',
              result_unit: 'g/dL',
              result_text: 'Normal result',
              result_flag: null,
              is_positive: false,
              reference_range_label: 'Adult',
              reference_range_summary: 'Adult | Unit g/dL | 11.5 - 15.5',
              reported_at: null,
              created_at: now,
              updated_at: releaseTimestamp,
              lab_order_item_id: 'order-item-internal-3'}]}]});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(currentOrder)
      .mockResolvedValueOnce(reopenedOrder);
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'order-item-internal-3',
      status: 'COMPLETED'});
    labWorkspaceRepository.txFindResultById.mockResolvedValue({
      id: 'result-internal-3',
      status: 'NORMAL',
      reported_at: releaseTimestamp});
    labWorkspaceRepository.txUpdateResult.mockResolvedValue({
      id: 'result-internal-3'});
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({
      id: 'order-item-internal-3'});
    labWorkspaceRepository.txCountSamples
      .mockResolvedValueOnce(1)
      .mockResolvedValueOnce(0);
    labWorkspaceRepository.txCountOrderItems
      .mockResolvedValueOnce(0)
      .mockResolvedValueOnce(0)
      .mockResolvedValueOnce(1);
    labWorkspaceRepository.txUpdateOrderItemsMany.mockResolvedValue({ count: 1 });
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-1' });

    const result = await labWorkspaceService.reverseLabOrderWorkflow(
      'LAB0000001',
      { reason: 'Released by mistake' },
      'actor-1',
      '127.0.0.1'
    );

    expect(result?.workflow?.order?.id).toBe('LAB0000001');
    expect(labWorkspaceRepository.txUpdateResult).toHaveBeenCalledWith(
      {},
      'result-internal-3',
      expect.objectContaining({
        status: 'PENDING',
        reported_at: null})
    );
    expect(labWorkspaceRepository.txUpdateOrderItemsMany).toHaveBeenCalledWith(
      {},
      expect.objectContaining({
        lab_order_id: 'order-internal-1'}),
      { status: 'IN_PROCESS' }
    );

    await flushAsync();

    expect(emitToUsers).toHaveBeenCalledWith(
      ['user-1', 'user-2'],
      'diagnostic.lab_workflow_updated',
      expect.objectContaining({
        action: 'REVERSE',
        order_id: 'LAB0000001'})
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-internal-1',
        action: 'REVERSE',
        entity: 'lab_order'})
    );
  });

  it('rejects reverseLabOrderWorkflow when no reversible workflow step exists', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(
      buildBaseOrder({
        status: 'ORDERED',
        samples: [
          {
            id: 'sample-internal-1',
            human_friendly_id: 'LSP0000001',
            status: 'PENDING',
            collected_at: null,
            received_at: null,
            created_at: now,
            updated_at: now}],
        items: [
          {
            id: 'order-item-internal-1',
            human_friendly_id: 'LIT0000001',
            status: 'ORDERED',
            created_at: now,
            updated_at: now,
            lab_test: {
              id: 'lab-test-internal-1',
              human_friendly_id: 'LBT0000001',
              name: 'CBC',
              code: 'CBC',
              unit: null},
            results: []}]})
    );

    await expect(
      labWorkspaceService.reverseLabOrderWorkflow(
        'LAB0000001',
        { reason: 'Wrong status' },
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toBeInstanceOf(HttpError);
  });

  it('restoreLabOrderItem un-cancels a cancelled test and reactivates the order', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'order-item-internal-1',
      lab_order_id: 'order-internal-1',
      status: 'CANCELLED',
      lab_order: { id: 'order-internal-1', status: 'CANCELLED' }});
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({
      id: 'order-item-internal-1'});
    labWorkspaceRepository.txCountSamples.mockResolvedValue(0);
    labWorkspaceRepository.txCountOrderItems.mockResolvedValue(1);
    labWorkspaceRepository.txUpdateOrderItemsMany.mockResolvedValue({ count: 1 });
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-1' });
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(
      buildBaseOrder({ status: 'ORDERED', encounter_id: 'encounter-internal-1' })
    );

    const result = await labWorkspaceService.restoreLabOrderItem(
      'LIT0000001',
      { reason: 'Cancelled in error' },
      'actor-1',
      '127.0.0.1'
    );

    expect(result?.workflow?.order?.id).toBe('LAB0000001');
    expect(labWorkspaceRepository.txUpdateOrderItem).toHaveBeenCalledWith(
      {},
      'order-item-internal-1',
      expect.objectContaining({
        status: 'ORDERED',
        rejection_reason: null,
        rejection_notes: null,
        rejected_at: null})
    );

    await flushAsync();

    expect(opdFlowService.syncDiagnosticsStage).toHaveBeenCalledWith(
      'encounter-internal-1',
      expect.objectContaining({ trigger: 'LAB_ORDER_ITEM_RESTORED' })
    );
  });

  it('restoreLabOrderItem rejects items that are not cancelled', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');
    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'order-item-internal-1',
      lab_order_id: 'order-internal-1',
      status: 'IN_PROCESS',
      lab_order: { id: 'order-internal-1', status: 'IN_PROCESS' }});

    await expect(
      labWorkspaceService.restoreLabOrderItem('LIT0000001', {}, 'actor-1', '127.0.0.1')
    ).rejects.toBeInstanceOf(HttpError);
  });

  it('deleteLabOrderItems soft-deletes all tests within a panel', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(buildBaseOrder({ status: 'ORDERED' }))
      .mockResolvedValueOnce(
        buildBaseOrder({ status: 'ORDERED', encounter_id: 'encounter-internal-1' })
      );
    labWorkspaceRepository.txFindManyOrderItems.mockResolvedValue([
      { id: 'order-item-internal-1' },
      { id: 'order-item-internal-2' }]);
    labWorkspaceRepository.txCountOrderItems.mockResolvedValue(3);
    labWorkspaceRepository.txCountSamples.mockResolvedValue(0);
    labWorkspaceRepository.txUpdateResultsMany.mockResolvedValue({ count: 2 });
    labWorkspaceRepository.txUpdateOrderItemsMany.mockResolvedValue({ count: 2 });
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-1' });

    const result = await labWorkspaceService.deleteLabOrderItems(
      'LAB0000001',
      { panel_id: 'FBC', reason: 'Ordered by mistake' },
      'actor-1',
      '127.0.0.1'
    );

    expect(result?.deleted_item_count).toBe(2);
    expect(labWorkspaceRepository.txUpdateOrderItemsMany).toHaveBeenCalledWith(
      {},
      { id: { in: ['order-item-internal-1', 'order-item-internal-2'] } },
      expect.objectContaining({ deleted_at: expect.any(Date) })
    );
    expect(labWorkspaceRepository.txUpdateResultsMany).toHaveBeenCalledWith(
      {},
      { lab_order_item_id: { in: ['order-item-internal-1', 'order-item-internal-2'] } },
      expect.objectContaining({ deleted_at: expect.any(Date) })
    );

    await flushAsync();

    expect(opdFlowService.syncDiagnosticsStage).toHaveBeenCalledWith(
      'encounter-internal-1',
      expect.objectContaining({ trigger: 'LAB_ORDER_ITEMS_DELETED' })
    );
  });

  it('deleteLabOrderItems refuses to remove the last active test', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(
      buildBaseOrder({ status: 'ORDERED' })
    );
    labWorkspaceRepository.txFindManyOrderItems.mockResolvedValue([
      { id: 'order-item-internal-1' },
      { id: 'order-item-internal-2' }]);
    labWorkspaceRepository.txCountOrderItems.mockResolvedValue(2);

    await expect(
      labWorkspaceService.deleteLabOrderItems(
        'LAB0000001',
        { panel_id: 'FBC' },
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toBeInstanceOf(HttpError);
    expect(labWorkspaceRepository.txUpdateOrderItemsMany).not.toHaveBeenCalled();
  });

  it('throws not found when legacy resource identifier is missing', async () => {
    await expect(
      labWorkspaceService.resolveLegacyRouteIdentifier('lab-results', '')
    ).rejects.toBeInstanceOf(HttpError);
  });
});
