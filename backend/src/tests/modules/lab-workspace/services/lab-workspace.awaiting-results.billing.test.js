/**
 * Lab workspace Awaiting results (`/lab?section=awaiting-results`) billing
 * gates: collect + save-result must not bypass Billing payment status.
 */

jest.mock('@repositories/lab-workspace/lab-workspace.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined)}));
jest.mock('@lib/realtime', () => ({
  publishDomainEvent: jest.fn().mockResolvedValue(undefined)}));
jest.mock('@services/lab-workspace/lab.realtime', () => ({
  resolveLabRealtimeRecipients: jest.fn().mockResolvedValue([])}));
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  DIAGNOSTIC_EVENTS: {},
  NOTIFICATION_EVENTS: {}}));
jest.mock('@services/lab-workspace/lab.shared', () => {
  const actual = jest.requireActual('@services/lab-workspace/lab.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn()};
});

const labWorkspaceRepository = require('@repositories/lab-workspace/lab-workspace.repository');
const { resolveModelIdOrThrow } = require('@services/lab-workspace/lab.shared');
const {
  isLabOrderPaymentSatisfied,
  mapLabOrderWorkflowRecord} = require('@services/lab-workspace/lab.serializer');
const labWorkspaceService = require('@services/lab-workspace/lab-workspace.service');

const now = new Date('2026-07-30T08:00:00.000Z');

const buildOrder = (overrides = {}) => ({
  id: 'order-internal-await-1',
  human_friendly_id: 'LAB-AWAIT-1',
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  status: 'ORDERED',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  billing_snapshot: {
    payment_status: 'PENDING',
    invoice_id: 'inv-await-1',
    total_amount: '25.00',
    currency: 'USD'},
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT-AWAIT-1',
    first_name: 'Await',
    last_name: 'Results',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1'},
  encounter: {
    id: 'encounter-internal-1',
    human_friendly_id: 'ENC-AWAIT-1'},
  items: [
    {
      id: 'item-internal-1',
      human_friendly_id: 'LIT-AWAIT-1',
      status: 'IN_PROCESS',
      lab_order_id: 'order-internal-await-1',
      created_at: now,
      updated_at: now,
      lab_test: {
        id: 'lab-test-1',
        human_friendly_id: 'LBT-1',
        name: 'CBC',
        code: 'CBC',
        unit: null,
        result_kind: 'NUMERIC',
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      results: []}],
  samples: [],
  ...overrides});

describe('lab-workspace awaiting-results billing gates', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('blocks collect when Billing payment_status is PENDING', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-await-1');
    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(buildOrder());

    await expect(
      labWorkspaceService.collectLabOrder('LAB-AWAIT-1', {}, 'actor-1', '127.0.0.1')
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('blocks save-results when Billing payment_status is PENDING', async () => {
    resolveModelIdOrThrow
      .mockResolvedValueOnce('order-internal-await-1')
      .mockResolvedValueOnce('item-internal-1');
    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(
      buildOrder({ status: 'IN_PROCESS' })
    );

    await expect(
      labWorkspaceService.saveLabOrderResults(
        'LAB-AWAIT-1',
        {
          results: [
            {
              order_item_id: 'LIT-AWAIT-1',
              result_value: '12.1'}]},
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('blocks saveLabOrderItemResult when Billing payment_status is PENDING', async () => {
    resolveModelIdOrThrow.mockResolvedValue('item-internal-1');
    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'item-internal-1',
      status: 'IN_PROCESS',
      lab_order_id: 'order-internal-await-1',
      lab_order: buildOrder({ status: 'IN_PROCESS' }),
      lab_test: {
        id: 'lab-test-1',
        unit: null,
        result_kind: 'NUMERIC',
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      results: []});

    await expect(
      labWorkspaceService.saveLabOrderItemResult(
        'LIT-AWAIT-1',
        { result_value: '12.1' },
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('allows collect when payment_status is PAID (Billing parity)', async () => {
    const paidOrder = buildOrder({
      billing_snapshot: {
        payment_status: 'PAID',
        invoice_id: 'inv-await-paid',
        total_amount: '25.00',
        currency: 'USD'}});
    expect(isLabOrderPaymentSatisfied(paidOrder)).toBe(true);

    resolveModelIdOrThrow.mockResolvedValue('order-internal-await-1');
    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(paidOrder)
      .mockResolvedValueOnce({
        ...paidOrder,
        status: 'COLLECTED',
        samples: [
          {
            id: 'sample-1',
            status: 'COLLECTED',
            collected_at: now,
            created_at: now,
            updated_at: now}]});
    labWorkspaceRepository.txCreateSample.mockResolvedValue({
      id: 'sample-1',
      status: 'COLLECTED',
      collected_at: now});
    labWorkspaceRepository.txUpdateOrderItemsMany.mockResolvedValue({ count: 1 });
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({
      ...paidOrder,
      status: 'COLLECTED'});

    const result = await labWorkspaceService.collectLabOrder(
      'LAB-AWAIT-1',
      {},
      'actor-1',
      '127.0.0.1'
    );
    expect(result?.workflow?.order?.status || result?.order?.status).toBeTruthy();
  });

  it('serializer hides result-entry actions when billing gate blocked', () => {
    const workflow = mapLabOrderWorkflowRecord(
      buildOrder({
        status: 'IN_PROCESS',
        billing_snapshot: { payment_status: 'PENDING', invoice_id: 'inv-1' }})
    );
    expect(workflow.next_actions.billing_gate_blocked).toBe(true);
    expect(workflow.next_actions.can_enter_result).toBe(false);
    expect(workflow.next_actions.payment_status).toBe('PENDING');
  });

  it('explicit NOT_REQUIRED / NO_CHARGE / NOT_BILLED satisfy the gate', () => {
    for (const status of ['NOT_REQUIRED', 'NO_CHARGE', 'NOT_BILLED', 'PAID']) {
      expect(
        isLabOrderPaymentSatisfied({
          billing_snapshot: { payment_status: status }})
      ).toBe(true);
    }
    expect(
      isLabOrderPaymentSatisfied({
        billing_snapshot: { payment_status: 'PENDING' }})
    ).toBe(false);
  });

  it('lab workspace does not own receive-payment / adjust (no bypass cashier)', () => {
    expect(labWorkspaceService.receivePayment).toBeUndefined();
    expect(labWorkspaceService.adjustInvoice).toBeUndefined();
    expect(labWorkspaceService.collectLabOrder).toEqual(expect.any(Function));
    expect(labWorkspaceService.saveLabOrderResults).toEqual(expect.any(Function));
  });
});
