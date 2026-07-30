/**
 * Lab Processing tab (`/lab?section=processing`) billing & sections coverage:
 * receive → IN_PROCESS stays payment-gated; save-result is allowed unpaid.
 * Create/delete charge posts reuse
 * `lab-order.service.billing-sections.test.js` (clinical-request-billing).
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-workspace/lab-workspace.repository');
jest.mock('@repositories/facility-lab-catalog/facility-lab-catalog.repository', () => ({
  findTestOffering: jest.fn().mockResolvedValue(null)}));
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
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const { resolveModelIdOrThrow } = require('@services/lab-workspace/lab.shared');
const labWorkspaceService = require('@services/lab-workspace/lab-workspace.service');
const {
  isLabOrderPaymentSatisfied,
  mapLabOrderWorkflowRecord} = require('@services/lab-workspace/lab.serializer');

const now = new Date('2026-07-30T06:00:00.000Z');

const buildBaseOrder = (overrides = {}) => ({
  id: 'order-internal-proc-1',
  human_friendly_id: 'LAB-PROC-1',
  status: 'IN_PROCESS',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  billing_snapshot: null,
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT-PROC-1',
    tenant_id: 'tenant-internal-1',
    facility_id: 'facility-internal-1',
    first_name: 'Processing',
    last_name: 'Patient'},
  encounter: {
    id: 'encounter-internal-1',
    human_friendly_id: 'ENC-PROC-1'},
  items: [
    {
      id: 'item-internal-1',
      human_friendly_id: 'LIT-PROC-1',
      status: 'IN_PROCESS',
      lab_order_id: 'order-internal-proc-1',
      created_at: now,
      updated_at: now,
      lab_test: {
        id: 'lab-test-internal-1',
        human_friendly_id: 'LBT-PROC-1',
        name: 'Glucose',
        code: 'GLU',
        unit: 'mg/dL',
        result_kind: 'NUMERIC',
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      results: []}],
  samples: [
    {
      id: 'sample-internal-1',
      human_friendly_id: 'S-PROC-1',
      status: 'COLLECTED',
      lab_order_id: 'order-internal-proc-1',
      collected_at: now,
      created_at: now,
      updated_at: now}],
  ...overrides});

const mockProgressCounts = () => {
  labWorkspaceRepository.txCountSamples.mockResolvedValue(0);
  labWorkspaceRepository.txCountOrderItems.mockResolvedValue(0);
  labWorkspaceRepository.txUpdateOrderItemsMany.mockResolvedValue({ count: 1 });
  labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-proc-1' });
};

describe('lab-workspace Processing tab billing sections', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    opdFlowService.syncDiagnosticsStage.mockResolvedValue(null);
  });

  it('payment parity: PAID / NOT_* satisfied; PENDING blocks progression', () => {
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'PAID' } })
      )
    ).toBe(true);
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'NOT_REQUIRED' } })
      )
    ).toBe(true);
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'NO_CHARGE' } })
      )
    ).toBe(true);
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'NOT_BILLED' } })
      )
    ).toBe(true);
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'PENDING' } })
      )
    ).toBe(false);
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'PARTIAL' } })
      )
    ).toBe(false);
  });

  it('receiveLabSample blocks unpaid required charges (no bypass into IN_PROCESS)', async () => {
    resolveModelIdOrThrow.mockResolvedValue('sample-internal-1');

    const unpaidOrder = buildBaseOrder({
      status: 'COLLECTED',
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '35.00',
        currency: 'USD',
        invoice_id: 'inv-proc-1'}});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindSampleById.mockResolvedValue({
      id: 'sample-internal-1',
      status: 'COLLECTED',
      lab_order_id: 'order-internal-proc-1'});
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);

    await expect(
      labWorkspaceService.receiveLabSample(
        'S-PROC-1',
        {},
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});

    expect(labWorkspaceRepository.txUpdateSample).not.toHaveBeenCalled();
    expect(labWorkspaceRepository.txUpdateOrder).not.toHaveBeenCalled();
  });

  it('saveLabOrderItemResult allows unpaid required charges on Processing path', async () => {
    resolveModelIdOrThrow.mockResolvedValue('item-internal-1');

    const unpaidOrder = buildBaseOrder({
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '35.00',
        currency: 'USD',
        invoice_id: 'inv-proc-1'}});
    const savedResult = {
      id: 'result-proc-1',
      human_friendly_id: 'LRS-PROC-1',
      status: 'NORMAL',
      result_value: '98',
      created_at: now,
      updated_at: now,
      lab_order_item_id: 'item-internal-1'};

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'item-internal-1',
      lab_order_id: 'order-internal-proc-1',
      status: 'IN_PROCESS',
      lab_test: unpaidOrder.items[0].lab_test,
      lab_order: unpaidOrder,
      results: []});
    labWorkspaceRepository.txFindFirstResult.mockResolvedValue(null);
    labWorkspaceRepository.txCreateResult.mockResolvedValue(savedResult);
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({ id: 'item-internal-1' });
    mockProgressCounts();
    labWorkspaceRepository.txFindOrderById.mockResolvedValue({
      ...unpaidOrder,
      items: [
        {
          ...unpaidOrder.items[0],
          status: 'COMPLETED',
          results: [savedResult]}]});

    const result = await labWorkspaceService.saveLabOrderItemResult(
      'LIT-PROC-1',
      { result_value: '98' },
      'actor-1',
      '127.0.0.1'
    );

    expect(result.workflow).toBeTruthy();
    expect(labWorkspaceRepository.txCreateResult).toHaveBeenCalled();
  });

  it('saveLabOrderResults allows unpaid required charges', async () => {
    resolveModelIdOrThrow
      .mockResolvedValueOnce('order-internal-proc-1')
      .mockResolvedValueOnce('item-internal-1');

    const unpaidOrder = buildBaseOrder({
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '35.00',
        currency: 'USD'}});
    const savedResult = {
      id: 'result-proc-1',
      human_friendly_id: 'LRS-PROC-1',
      status: 'NORMAL',
      result_value: '98',
      created_at: now,
      updated_at: now,
      lab_order_item_id: 'item-internal-1'};

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(unpaidOrder)
      .mockResolvedValueOnce({
        ...unpaidOrder,
        items: [
          {
            ...unpaidOrder.items[0],
            status: 'COMPLETED',
            results: [savedResult]}]});
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'item-internal-1',
      lab_order_id: 'order-internal-proc-1',
      status: 'IN_PROCESS',
      lab_test: unpaidOrder.items[0].lab_test,
      lab_order: unpaidOrder,
      results: []});
    labWorkspaceRepository.txFindFirstResult.mockResolvedValue(null);
    labWorkspaceRepository.txCreateResult.mockResolvedValue(savedResult);
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({ id: 'item-internal-1' });
    mockProgressCounts();

    const result = await labWorkspaceService.saveLabOrderResults(
      'LAB-PROC-1',
      {
        results: [
          {
            order_item_id: 'LIT-PROC-1',
            result_value: '98'}]},
      'actor-1',
      '127.0.0.1'
    );

    expect(result.workflow).toBeTruthy();
    expect(labWorkspaceRepository.txCreateResult).toHaveBeenCalled();
  });

  it('collectLabOrder blocks unpaid required charges on Processing path', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-proc-1');

    const unpaidOrder = buildBaseOrder({
      status: 'ORDERED',
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '40.00',
        currency: 'USD'},
      items: [
        {
          id: 'item-internal-1',
          human_friendly_id: 'LIT-PROC-1',
          status: 'ORDERED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            human_friendly_id: 'LBT-PROC-1',
            name: 'Glucose',
            code: 'GLU',
            unit: null},
          results: []}],
      samples: []});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);

    await expect(
      labWorkspaceService.collectLabOrder('LAB-PROC-1', {}, 'actor-1', '127.0.0.1')
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('unpaid save-results persists on repeat (no payment gate)', async () => {
    resolveModelIdOrThrow
      .mockResolvedValueOnce('order-internal-proc-1')
      .mockResolvedValueOnce('item-internal-1')
      .mockResolvedValueOnce('order-internal-proc-1')
      .mockResolvedValueOnce('item-internal-1');

    const unpaidOrder = buildBaseOrder({
      billing_snapshot: { payment_status: 'PENDING', invoice_id: 'inv-1' }});
    const savedResult = {
      id: 'result-proc-1',
      human_friendly_id: 'LRS-PROC-1',
      status: 'NORMAL',
      result_value: '98',
      created_at: now,
      updated_at: now,
      lab_order_item_id: 'item-internal-1'};

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'item-internal-1',
      lab_order_id: 'order-internal-proc-1',
      status: 'IN_PROCESS',
      lab_test: unpaidOrder.items[0].lab_test,
      lab_order: unpaidOrder,
      results: []});
    labWorkspaceRepository.txFindFirstResult.mockResolvedValue(null);
    labWorkspaceRepository.txCreateResult.mockResolvedValue(savedResult);
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({ id: 'item-internal-1' });
    mockProgressCounts();

    for (let i = 0; i < 2; i += 1) {
      await labWorkspaceService.saveLabOrderResults(
        'LAB-PROC-1',
        {
          results: [
            {
              order_item_id: 'LIT-PROC-1',
              result_value: '98'}]},
        'actor-1',
        '127.0.0.1'
      );
    }

    expect(labWorkspaceRepository.txUpdateOrderItem).toHaveBeenCalled();
  });

  it('serializer allows result-entry while billing gate blocked on IN_PROCESS', () => {
    const workflow = mapLabOrderWorkflowRecord(
      buildBaseOrder({
        billing_snapshot: { payment_status: 'PENDING', invoice_id: 'inv-1' }})
    );
    expect(workflow.next_actions.billing_gate_blocked).toBe(true);
    expect(workflow.next_actions.can_enter_result).toBe(true);
    expect(workflow.next_actions.can_collect).toBe(false);
    expect(workflow.next_actions.payment_status).toBe('PENDING');
  });

  it('explicit NOT_REQUIRED / NO_CHARGE / NOT_BILLED satisfy the gate', () => {
    for (const status of ['NOT_REQUIRED', 'NO_CHARGE', 'NOT_BILLED', 'PAID']) {
      expect(
        isLabOrderPaymentSatisfied({
          billing_snapshot: { payment_status: status }})
      ).toBe(true);
    }
  });

  it('workspace service does not own cashier settle/adjust APIs', () => {
    expect(labWorkspaceService.receivePayment).toBeUndefined();
    expect(labWorkspaceService.adjustInvoice).toBeUndefined();
    expect(labWorkspaceService.issueInvoice).toBeUndefined();
    expect(labWorkspaceService.refundPayment).toBeUndefined();
    expect(labWorkspaceService.receiveLabSample).toEqual(expect.any(Function));
    expect(labWorkspaceService.saveLabOrderResults).toEqual(expect.any(Function));
  });

  it('HttpError 402 is authoritative for unpaid collect/receive', () => {
    const err = new HttpError('errors.lab_order.payment_required', 402, [
      { field: 'payment_status' }]);
    expect(err.statusCode).toBe(402);
    expect(err.message).toBe('errors.lab_order.payment_required');
  });
});
