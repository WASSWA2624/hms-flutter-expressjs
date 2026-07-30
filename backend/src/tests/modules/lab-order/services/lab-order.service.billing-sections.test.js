/**
 * Lab-order billing & sections coverage for Clinical Waiting review
 * (`/clinical?section=waiting-review`) request-lab / cancel flows that
 * post through clinical-request-billing.
 */

jest.mock('@repositories/lab-order/lab-order.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined)}));
jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    buildLabOrderBillingFromRequest: jest.fn().mockResolvedValue(null),
    normalizeBillingOfficeClinicalBilling: jest.fn((billing) => billing),
    persistLabOrderBilling: jest.fn().mockResolvedValue({
      payment_status: 'PENDING',
      invoice_id: 'inv-lab-1'}),
    reverseClinicalRequestBilling: jest.fn().mockResolvedValue(null),
    extractStoredClinicalBilling: jest.fn().mockReturnValue(null)};
});
jest.mock('@services/lab-workspace/lab.shared', () => {
  const actual = jest.requireActual('@services/lab-workspace/lab.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn(),
    resolveLabOrderEncounterId: jest.fn()};
});
jest.mock('@lib/realtime', () => ({
  publishDomainEvent: jest.fn().mockResolvedValue(undefined)}));

const prisma = require('@prisma/client');
const labOrderRepository = require('@repositories/lab-order/lab-order.repository');
const { createAuditLog } = require('@lib/audit');
const {
  normalizeBillingOfficeClinicalBilling,
  persistLabOrderBilling,
  reverseClinicalRequestBilling,
  extractStoredClinicalBilling,
  buildLabOrderBillingFromRequest} = require('@lib/billing/clinical-request-billing');
const {
  resolveModelRecordOrThrow,
  resolveLabOrderEncounterId} = require('@services/lab-workspace/lab.shared');
const labOrderService = require('@services/lab-order/lab-order.service');

const mockUserId = 'user-waiting-review';
const mockIpAddress = '127.0.0.1';
const now = new Date('2026-07-30T06:00:00.000Z');

const buildOrderRecord = (overrides = {}) => ({
  id: 'order-internal-wr-1',
  human_friendly_id: 'LAB-WR-1',
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  status: 'ORDERED',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  billing_snapshot: null,
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT-WR-1',
    first_name: 'Waiting',
    last_name: 'Review'},
  encounter: {
    id: 'encounter-internal-1',
    human_friendly_id: 'ENC-WR-1'},
  items: [{ id: 'item-1', lab_test_id: 'lab-test-1', status: 'ORDERED' }],
  samples: [],
  ...overrides});

describe('lab-order.service billing (Clinical Waiting review)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.$transaction = jest.fn(async (fn) => fn(prisma));
    prisma.encounter = {
      findFirst: jest.fn().mockResolvedValue({
        id: 'encounter-internal-1',
        human_friendly_id: 'ENC-WR-1'})};
    buildLabOrderBillingFromRequest.mockResolvedValue(null);
    normalizeBillingOfficeClinicalBilling.mockImplementation((billing) => billing);
    persistLabOrderBilling.mockResolvedValue({
      payment_status: 'PENDING',
      invoice_id: 'inv-lab-1'});
    reverseClinicalRequestBilling.mockResolvedValue(null);
    extractStoredClinicalBilling.mockReturnValue(null);
  });

  it('posts Billing via persistLabOrderBilling when billing payload is present', async () => {
    resolveModelRecordOrThrow
      .mockResolvedValueOnce({
        id: 'patient-internal-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1'})
      .mockResolvedValueOnce({ id: 'lab-test-1' });
    resolveLabOrderEncounterId.mockResolvedValueOnce('encounter-internal-1');
    labOrderRepository.create.mockResolvedValue({ id: 'order-internal-wr-1' });
    labOrderRepository.findById.mockResolvedValue(buildOrderRecord());

    const billing = {
      payment_status: 'PENDING',
      currency: 'USD',
      total_amount: 15,
      line_items: [
        {
          id: 'lab-test-1',
          label: 'CBC',
          quantity: 1,
          unit_price: 15,
          line_total: 15}]};

    await labOrderService.createLabOrder(
      {
        patient_id: 'PAT-WR-1',
        encounter_id: 'ENC-WR-1',
        requested_tests: [{ lab_test_id: 'LBT0000001' }],
        billing},
      mockUserId,
      mockIpAddress
    );

    expect(normalizeBillingOfficeClinicalBilling).toHaveBeenCalledWith(billing);
    expect(persistLabOrderBilling).toHaveBeenCalledTimes(1);
    expect(persistLabOrderBilling).toHaveBeenCalledWith(
      prisma,
      expect.objectContaining({
        orderId: 'order-internal-wr-1',
        billing,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-internal-1'})
    );
    expect(createAuditLog).toHaveBeenCalled();
  });

  it('does not invent a parallel ledger when billing resolves empty', async () => {
    resolveModelRecordOrThrow
      .mockResolvedValueOnce({
        id: 'patient-internal-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1'})
      .mockResolvedValueOnce({ id: 'lab-test-1' });
    resolveLabOrderEncounterId.mockResolvedValueOnce('encounter-internal-1');
    labOrderRepository.create.mockResolvedValue({ id: 'order-internal-wr-1' });
    labOrderRepository.findById.mockResolvedValue(buildOrderRecord());
    normalizeBillingOfficeClinicalBilling.mockReturnValue(null);
    buildLabOrderBillingFromRequest.mockResolvedValue(null);

    await labOrderService.createLabOrder(
      {
        patient_id: 'PAT-WR-1',
        encounter_id: 'ENC-WR-1',
        requested_tests: [{ lab_test_id: 'LBT0000001' }]},
      mockUserId,
      mockIpAddress
    );

    expect(persistLabOrderBilling).not.toHaveBeenCalled();
  });

  it('idempotent replay shape: same billing payload posts once per create', async () => {
    const billing = {
      payment_status: 'PENDING',
      currency: 'USD',
      total_amount: 15,
      line_items: [{ id: 'lab-test-1', label: 'CBC', quantity: 1, unit_price: 15 }]};

    for (let i = 0; i < 2; i += 1) {
      resolveModelRecordOrThrow
        .mockResolvedValueOnce({
          id: 'patient-internal-1',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1'})
        .mockResolvedValueOnce({ id: 'lab-test-1' });
      resolveLabOrderEncounterId.mockResolvedValueOnce('encounter-internal-1');
      labOrderRepository.create.mockResolvedValue({ id: `order-internal-wr-${i}` });
      labOrderRepository.findById.mockResolvedValue(
        buildOrderRecord({ id: `order-internal-wr-${i}` })
      );

      await labOrderService.createLabOrder(
        {
          patient_id: 'PAT-WR-1',
          encounter_id: 'ENC-WR-1',
          requested_tests: [{ lab_test_id: 'LBT0000001' }],
          billing},
        mockUserId,
        mockIpAddress
      );
    }

    expect(persistLabOrderBilling).toHaveBeenCalledTimes(2);
    expect(persistLabOrderBilling.mock.calls[0][1].billing).toEqual(billing);
    expect(persistLabOrderBilling.mock.calls[1][1].billing).toEqual(billing);
  });

  it('cancel reverses clinical-request billing when invoice snapshot exists', async () => {
    const before = buildOrderRecord({
      billing_snapshot: { invoice_id: 'inv-lab-9', payment_status: 'PENDING' }});
    resolveModelRecordOrThrow.mockResolvedValue(before);
    extractStoredClinicalBilling.mockReturnValue(before.billing_snapshot);
    labOrderRepository.update.mockResolvedValue(before);
    labOrderRepository.findById.mockResolvedValue({
      ...before,
      status: 'CANCELLED'});

    await labOrderService.updateLabOrder(
      'LAB-WR-1',
      { status: 'CANCELLED' },
      mockUserId,
      mockIpAddress
    );

    expect(reverseClinicalRequestBilling).toHaveBeenCalled();
  });

  it('unauthorized collect path is not owned by lab-order service', () => {
    expect(labOrderService.receivePayment).toBeUndefined();
    expect(labOrderService.adjustInvoice).toBeUndefined();
  });
});
