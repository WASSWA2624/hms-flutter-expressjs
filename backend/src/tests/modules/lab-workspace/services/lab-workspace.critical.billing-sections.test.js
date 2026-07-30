/**
 * Lab Critical tab (`/lab?section=critical`) billing & sections coverage:
 * verify/release payment gate, no parallel cashier, and clinical notify
 * remains NOT_BILLED. Create/delete charge posts reuse
 * `lab-order.service.billing-sections.test.js` (clinical-request-billing).
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
const prisma = require('@prisma/client');
const { resolveModelIdOrThrow } = require('@services/lab-workspace/lab.shared');
const labWorkspaceService = require('@services/lab-workspace/lab-workspace.service');
const {
  isLabOrderPaymentSatisfied} = require('@services/lab-workspace/lab.serializer');

const now = new Date('2026-07-30T06:00:00.000Z');

const buildBaseOrder = (overrides = {}) => ({
  id: 'order-internal-crit-1',
  human_friendly_id: 'LAB-CRIT-1',
  status: 'RESULTS_ENTERED',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  billing_snapshot: null,
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT-CRIT-1',
    tenant_id: 'tenant-internal-1',
    facility_id: 'facility-internal-1',
    first_name: 'Critical',
    last_name: 'Patient'},
  encounter: {
    id: 'encounter-internal-1',
    human_friendly_id: 'ENC-CRIT-1'},
  items: [],
  samples: [],
  ...overrides});

describe('lab-workspace Critical tab billing sections', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    opdFlowService.syncDiagnosticsStage.mockResolvedValue(null);
    prisma.notification.create.mockResolvedValue({
      id: 'notification-internal-1',
      human_friendly_id: 'NOT0000001',
      user_id: 'doctor-1',
      notification_type: 'LAB',
      priority: 'URGENT'});
    prisma.notification_delivery.create.mockResolvedValue({});
    prisma.user_role.findMany.mockResolvedValue([]);
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

  it('releaseLabOrderItem blocks unpaid required charges (no bypass)', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');

    const unpaidOrder = buildBaseOrder({
      status: 'RESULTS_ENTERED',
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '55.00',
        currency: 'USD',
        invoice_id: 'inv-crit-1'}});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'order-item-internal-1',
      lab_order_id: 'order-internal-crit-1',
      status: 'RESULTS_ENTERED',
      lab_test: {
        id: 'lab-test-internal-1',
        unit: 'mmol/L',
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      lab_order: unpaidOrder});

    await expect(
      labWorkspaceService.releaseLabOrderItem(
        'LIT-CRIT-1',
        { status: 'CRITICAL', result_value: '7.2' },
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('verifyLabOrderResults blocks unpaid required charges (no bypass)', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-crit-1');

    const unpaidOrder = buildBaseOrder({
      status: 'RESULTS_ENTERED',
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '55.00',
        currency: 'USD'},
      items: [
        {
          id: 'order-item-internal-1',
          human_friendly_id: 'LIT-CRIT-1',
          status: 'RESULTS_ENTERED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            human_friendly_id: 'LBT-CRIT-1',
            name: 'Potassium',
            code: 'K',
            unit: 'mmol/L'},
          results: []}]});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);

    await expect(
      labWorkspaceService.verifyLabOrderResults(
        'LAB-CRIT-1',
        {
          results: [
            {
              order_item_id: 'LIT-CRIT-1',
              status: 'CRITICAL',
              result_value: '7.2'}]},
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('collectLabOrder blocks unpaid required charges on Critical path', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-crit-1');

    const unpaidOrder = buildBaseOrder({
      status: 'ORDERED',
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '40.00',
        currency: 'USD'},
      items: [
        {
          id: 'item-internal-1',
          human_friendly_id: 'LIT-CRIT-1',
          status: 'ORDERED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            human_friendly_id: 'LBT-CRIT-1',
            name: 'Potassium',
            code: 'K',
            unit: null},
          results: []}],
      samples: []});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);

    await expect(
      labWorkspaceService.collectLabOrder('LAB-CRIT-1', {}, 'actor-1', '127.0.0.1')
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('idempotent gate: repeated unpaid release attempts stay 402 without mutation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');

    const unpaidOrder = buildBaseOrder({
      billing_snapshot: { payment_status: 'PENDING', invoice_id: 'inv-1' }});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'order-item-internal-1',
      lab_order_id: 'order-internal-crit-1',
      status: 'RESULTS_ENTERED',
      lab_test: {
        id: 'lab-test-internal-1',
        unit: 'mmol/L',
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      lab_order: unpaidOrder});

    for (let i = 0; i < 2; i += 1) {
      await expect(
        labWorkspaceService.releaseLabOrderItem(
          'LIT-CRIT-1',
          { status: 'CRITICAL', result_value: '7.2' },
          'actor-1',
          '127.0.0.1'
        )
      ).rejects.toMatchObject({ statusCode: 402 });
    }

    expect(labWorkspaceRepository.txUpdateResult).not.toHaveBeenCalled();
    expect(labWorkspaceRepository.txUpdateOrderItem).not.toHaveBeenCalled();
  });

  it('workspace service does not own cashier settle/adjust APIs', () => {
    expect(labWorkspaceService.receivePayment).toBeUndefined();
    expect(labWorkspaceService.adjustInvoice).toBeUndefined();
    expect(labWorkspaceService.issueInvoice).toBeUndefined();
    expect(labWorkspaceService.refundPayment).toBeUndefined();
  });

  it('HttpError 402 is authoritative for unpaid progression', () => {
    const err = new HttpError('errors.lab_order.payment_required', 402, [
      { field: 'payment_status' }]);
    expect(err.statusCode).toBe(402);
    expect(err.message).toBe('errors.lab_order.payment_required');
  });
});
