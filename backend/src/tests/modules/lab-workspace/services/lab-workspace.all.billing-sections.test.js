/**
 * Lab All tab (`/lab?section=all|worklist`) billing & sections coverage:
 * create posts via clinical-request-billing (see lab-order billing-sections),
 * collect / receive / verify / release gate on Billing payment status,
 * and lab-order service does not expose receive-payment / adjust APIs.
 */

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
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const { resolveModelIdOrThrow } = require('@services/lab-workspace/lab.shared');
const labWorkspaceService = require('@services/lab-workspace/lab-workspace.service');
const {
  isLabOrderPaymentSatisfied,
  mapLabOrderWorkflowRecord} = require('@services/lab-workspace/lab.serializer');
const labOrderService = require('@services/lab-order/lab-order.service');

const now = new Date('2026-07-30T08:00:00.000Z');

const buildBaseOrder = (overrides = {}) => ({
  id: 'order-internal-all-1',
  human_friendly_id: 'LAB-ALL-1',
  status: 'ORDERED',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  billing_snapshot: null,
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT-ALL-1',
    tenant_id: 'tenant-internal-1',
    facility_id: 'facility-internal-1',
    first_name: 'All',
    last_name: 'Patient'},
  encounter: {
    id: 'encounter-internal-1',
    human_friendly_id: 'ENC-ALL-1'},
  items: [
    {
      id: 'item-internal-1',
      human_friendly_id: 'LIT-ALL-1',
      status: 'ORDERED',
      created_at: now,
      updated_at: now,
      lab_test: {
        id: 'lab-test-internal-1',
        human_friendly_id: 'LBT-ALL-1',
        name: 'CBC',
        code: 'CBC',
        unit: null},
      results: []}],
  samples: [
    {
      id: 'sample-internal-1',
      human_friendly_id: 'SMP-ALL-1',
      status: 'COLLECTED',
      lab_order_id: 'order-internal-all-1',
      created_at: now,
      updated_at: now}],
  ...overrides});

describe('lab-workspace All tab billing sections', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    opdFlowService.syncDiagnosticsStage.mockResolvedValue(null);
  });

  it('payment parity: PAID / NOT_* satisfied; PENDING / PARTIAL block', () => {
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

  it('serializer gates collect / receive / verify / release when unpaid', () => {
    const unpaid = buildBaseOrder({
      status: 'IN_PROCESS',
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '40.00',
        currency: 'USD',
        invoice_id: 'inv-all-1'},
      items: [
        {
          id: 'item-internal-1',
          human_friendly_id: 'LIT-ALL-1',
          status: 'IN_PROCESS',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            name: 'CBC',
            code: 'CBC'},
          results: []}],
      samples: [
        {
          id: 'sample-internal-1',
          status: 'COLLECTED',
          lab_order_id: 'order-internal-all-1'}]});

    const workflow = mapLabOrderWorkflowRecord(unpaid);
    expect(workflow.next_actions.billing_gate_blocked).toBe(true);
    expect(workflow.next_actions.can_collect).toBe(false);
    expect(workflow.next_actions.can_receive_sample).toBe(false);
    expect(workflow.next_actions.can_verify_result).toBe(false);
    expect(workflow.next_actions.can_verify_all).toBe(false);
    expect(workflow.next_actions.can_release_result).toBe(false);
    expect(workflow.next_actions.payment_status).toBe('PENDING');
  });

  it('collectLabOrder blocks unpaid required charges (no bypass)', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-all-1');
    const unpaidOrder = buildBaseOrder({
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '40.00',
        currency: 'USD'}});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);

    await expect(
      labWorkspaceService.collectLabOrder('LAB-ALL-1', {}, 'actor-1', '127.0.0.1')
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('receiveLabSample blocks unpaid required charges (no bypass)', async () => {
    resolveModelIdOrThrow.mockResolvedValue('sample-internal-1');
    const unpaidOrder = buildBaseOrder({
      status: 'COLLECTED',
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '40.00',
        currency: 'USD'}});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindSampleById.mockResolvedValue({
      id: 'sample-internal-1',
      status: 'COLLECTED',
      lab_order_id: 'order-internal-all-1'});
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);

    await expect(
      labWorkspaceService.receiveLabSample('SMP-ALL-1', {}, 'actor-1', '127.0.0.1')
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('verifyLabOrderResults blocks unpaid required charges (no bypass)', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-all-1');
    const unpaidOrder = buildBaseOrder({
      status: 'IN_PROCESS',
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '40.00',
        currency: 'USD',
        invoice_id: 'inv-all-2'},
      items: [
        {
          id: 'item-internal-1',
          human_friendly_id: 'LIT-ALL-1',
          status: 'IN_PROCESS',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            unit: null,
            reference_ranges: [],
            unit_options: [],
            result_options: []},
          results: []}]});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);

    await expect(
      labWorkspaceService.verifyLabOrderResults(
        'LAB-ALL-1',
        {
          results: [
            {
              order_item_id: 'LIT-ALL-1',
              result_value: '12.0'}]},
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('releaseLabOrderItem blocks unpaid required charges (no bypass)', async () => {
    resolveModelIdOrThrow.mockResolvedValue('item-internal-1');
    const unpaidOrder = buildBaseOrder({
      status: 'IN_PROCESS',
      billing_snapshot: {
        payment_status: 'PARTIAL',
        total_amount: '40.00',
        currency: 'USD'}});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'item-internal-1',
      lab_order_id: 'order-internal-all-1',
      status: 'IN_PROCESS',
      lab_test: {
        id: 'lab-test-internal-1',
        unit: null,
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      lab_order: unpaidOrder});

    await expect(
      labWorkspaceService.releaseLabOrderItem(
        'LIT-ALL-1',
        { result_value: '12.0' },
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('lab modules do not expose inline receive-payment / adjust (authorization)', () => {
    expect(labWorkspaceService.receivePayment).toBeUndefined();
    expect(labWorkspaceService.adjustInvoice).toBeUndefined();
    expect(labOrderService.receivePayment).toBeUndefined();
    expect(labOrderService.adjustInvoice).toBeUndefined();
  });

  it('HttpError payment_required remains 402 for unpaid gates', () => {
    const error = new HttpError('errors.lab_order.payment_required', 402, [
      { field: 'payment_status', payment_status: 'PENDING' }]);
    expect(error.statusCode).toBe(402);
  });
});
