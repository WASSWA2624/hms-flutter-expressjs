/**
 * Lab workspace Pending verification (`/lab?section=pending-verification`)
 * billing: save-result is allowed unpaid; collect/receive stay payment-gated.
 * `billing_gate_blocked` still reflects unpaid; `can_enter_result` does not.
 */

jest.mock('@repositories/lab-workspace/lab-workspace.repository');
jest.mock('@repositories/facility-lab-catalog/facility-lab-catalog.repository', () => ({
  findTestOffering: jest.fn().mockResolvedValue(null)}));
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
  id: 'order-internal-pv-1',
  human_friendly_id: 'LAB-PV-1',
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  status: 'IN_PROCESS',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  billing_snapshot: {
    payment_status: 'PENDING',
    invoice_id: 'inv-pv-1',
    total_amount: '35.00',
    currency: 'USD'},
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT-PV-1',
    first_name: 'Pending',
    last_name: 'Verify',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1'},
  encounter: {
    id: 'encounter-internal-1',
    human_friendly_id: 'ENC-PV-1'},
  items: [
    {
      id: 'item-internal-pv-1',
      human_friendly_id: 'LIT-PV-1',
      status: 'IN_PROCESS',
      lab_order_id: 'order-internal-pv-1',
      created_at: now,
      updated_at: now,
      lab_test: {
        id: 'lab-test-1',
        human_friendly_id: 'LBT-1',
        name: 'Glucose',
        code: 'GLU',
        unit: 'mmol/L',
        result_kind: 'NUMERIC',
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      results: [
        {
          id: 'result-pv-1',
          result_value: '5.4',
          status: 'ENTERED',
          created_at: now,
          updated_at: now}]}],
  samples: [
    {
      id: 'sample-pv-1',
      status: 'RECEIVED',
      collected_at: now,
      received_at: now,
      created_at: now,
      updated_at: now}],
  ...overrides});

const mockProgressCounts = () => {
  labWorkspaceRepository.txCountSamples.mockResolvedValue(1);
  labWorkspaceRepository.txCountOrderItems
    .mockResolvedValueOnce(0)
    .mockResolvedValueOnce(0)
    .mockResolvedValueOnce(1);
  labWorkspaceRepository.txUpdateOrderItemsMany.mockResolvedValue({ count: 1 });
  labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-pv-1' });
};

describe('lab-workspace pending-verification billing gates', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('allows save-results when Billing payment_status is PENDING', async () => {
    const unpaidOrder = buildOrder();
    const savedResult = {
      id: 'result-pv-1',
      human_friendly_id: 'LRS-PV-1',
      status: 'NORMAL',
      result_value: '5.4',
      created_at: now,
      updated_at: now,
      lab_order_item_id: 'item-internal-pv-1'};

    resolveModelIdOrThrow
      .mockResolvedValueOnce('order-internal-pv-1')
      .mockResolvedValueOnce('item-internal-pv-1');
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
      id: 'item-internal-pv-1',
      status: 'IN_PROCESS',
      lab_order_id: 'order-internal-pv-1',
      lab_order: unpaidOrder,
      lab_test: unpaidOrder.items[0].lab_test,
      results: unpaidOrder.items[0].results});
    labWorkspaceRepository.txFindFirstResult.mockResolvedValue({
      id: 'result-pv-1',
      status: 'ENTERED',
      result_value: '5.4'});
    labWorkspaceRepository.txUpdateResult.mockResolvedValue(savedResult);
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({
      id: 'item-internal-pv-1'});
    mockProgressCounts();

    const result = await labWorkspaceService.saveLabOrderResults(
      'LAB-PV-1',
      {
        results: [
          {
            order_item_id: 'LIT-PV-1',
            result_value: '5.4'}]},
      'actor-1',
      '127.0.0.1'
    );

    expect(result.workflow).toBeTruthy();
    expect(labWorkspaceRepository.txUpdateResult).toHaveBeenCalled();
    expect(labWorkspaceRepository.txUpdateOrderItem).toHaveBeenCalled();
  });

  it('allows saveLabOrderItemResult when Billing payment_status is PENDING', async () => {
    const unpaidOrder = buildOrder();
    const savedResult = {
      id: 'result-pv-1',
      human_friendly_id: 'LRS-PV-1',
      status: 'NORMAL',
      result_value: '5.4',
      created_at: now,
      updated_at: now,
      lab_order_item_id: 'item-internal-pv-1'};

    resolveModelIdOrThrow.mockResolvedValue('item-internal-pv-1');
    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'item-internal-pv-1',
      status: 'IN_PROCESS',
      lab_order_id: 'order-internal-pv-1',
      lab_order: unpaidOrder,
      lab_test: unpaidOrder.items[0].lab_test,
      results: unpaidOrder.items[0].results});
    labWorkspaceRepository.txFindFirstResult.mockResolvedValue({
      id: 'result-pv-1',
      status: 'ENTERED',
      result_value: '5.4'});
    labWorkspaceRepository.txUpdateResult.mockResolvedValue(savedResult);
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({
      id: 'item-internal-pv-1'});
    mockProgressCounts();
    labWorkspaceRepository.txFindOrderById.mockResolvedValue({
      ...unpaidOrder,
      items: [
        {
          ...unpaidOrder.items[0],
          status: 'COMPLETED',
          results: [savedResult]}]});

    const result = await labWorkspaceService.saveLabOrderItemResult(
      'LIT-PV-1',
      { result_value: '5.4' },
      'actor-1',
      '127.0.0.1'
    );

    expect(result.workflow).toBeTruthy();
    expect(labWorkspaceRepository.txUpdateResult).toHaveBeenCalled();
  });

  it('serializer enables result-entry when payment_status is PAID (Billing parity)', () => {
    const paidOrder = buildOrder({
      billing_snapshot: {
        payment_status: 'PAID',
        invoice_id: 'inv-pv-paid',
        total_amount: '35.00',
        currency: 'USD'}});
    expect(isLabOrderPaymentSatisfied(paidOrder)).toBe(true);

    const workflow = mapLabOrderWorkflowRecord(paidOrder);
    expect(workflow.next_actions.billing_gate_blocked).toBe(false);
    expect(workflow.next_actions.can_enter_result).toBe(true);
    expect(workflow.next_actions.can_enter_all).toBe(false);
    expect(workflow.next_actions.payment_status).toBe('PAID');
  });

  it('serializer keeps result-entry when billing gate blocked (open items)', () => {
    const workflow = mapLabOrderWorkflowRecord(buildOrder());
    expect(workflow.next_actions.billing_gate_blocked).toBe(true);
    expect(workflow.next_actions.can_enter_result).toBe(true);
    expect(workflow.next_actions.can_enter_all).toBe(false);
    expect(workflow.next_actions.payment_status).toBe('PENDING');
  });

  it('explicit NOT_REQUIRED / NO_CHARGE / NOT_BILLED / PAID satisfy the gate', () => {
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

  it('unpaid save-results persists on repeat (no payment gate)', async () => {
    const unpaidOrder = buildOrder();
    const savedResult = {
      id: 'result-pv-1',
      human_friendly_id: 'LRS-PV-1',
      status: 'NORMAL',
      result_value: '5.4',
      created_at: now,
      updated_at: now,
      lab_order_item_id: 'item-internal-pv-1'};

    resolveModelIdOrThrow
      .mockResolvedValueOnce('order-internal-pv-1')
      .mockResolvedValueOnce('item-internal-pv-1')
      .mockResolvedValueOnce('order-internal-pv-1')
      .mockResolvedValueOnce('item-internal-pv-1');
    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'item-internal-pv-1',
      status: 'IN_PROCESS',
      lab_order_id: 'order-internal-pv-1',
      lab_order: unpaidOrder,
      lab_test: unpaidOrder.items[0].lab_test,
      results: unpaidOrder.items[0].results});
    labWorkspaceRepository.txFindFirstResult.mockResolvedValue({
      id: 'result-pv-1',
      status: 'ENTERED',
      result_value: '5.4'});
    labWorkspaceRepository.txUpdateResult.mockResolvedValue(savedResult);
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({
      id: 'item-internal-pv-1'});
    labWorkspaceRepository.txCountSamples.mockResolvedValue(1);
    labWorkspaceRepository.txCountOrderItems.mockResolvedValue(0);
    labWorkspaceRepository.txUpdateOrderItemsMany.mockResolvedValue({ count: 1 });
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-pv-1' });

    const payload = {
      results: [{ order_item_id: 'LIT-PV-1', result_value: '5.4' }]};

    await labWorkspaceService.saveLabOrderResults(
      'LAB-PV-1',
      payload,
      'actor-1',
      '127.0.0.1'
    );
    await labWorkspaceService.saveLabOrderResults(
      'LAB-PV-1',
      payload,
      'actor-1',
      '127.0.0.1'
    );

    expect(labWorkspaceRepository.txUpdateOrderItem).toHaveBeenCalled();
  });

  it('lab workspace does not own receive-payment / adjust (no bypass cashier)', () => {
    expect(labWorkspaceService.receivePayment).toBeUndefined();
    expect(labWorkspaceService.adjustInvoice).toBeUndefined();
    expect(labWorkspaceService.saveLabOrderResults).toEqual(expect.any(Function));
    expect(labWorkspaceService.saveLabOrderItemResult).toEqual(expect.any(Function));
  });
});
