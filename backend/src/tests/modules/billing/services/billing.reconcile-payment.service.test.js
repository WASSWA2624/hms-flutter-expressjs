jest.mock('@repositories/billing/billing.repository', () => ({
  withTransaction: jest.fn(),
  findPaymentById: jest.fn(),
  findInvoiceById: jest.fn(),
  findRealtimeRecipientUserIds: jest.fn(async () => ['billing-1', 'reception-1'])}));

jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: jest.fn(() => true)}));

jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelRecordByIdentifier: jest.fn()}));

jest.mock('@lib/notifications/sendEmail', () => ({
  sendEmail: jest.fn(async () => ({ sent: true, provider: 'smtp' }))}));

jest.mock('@lib/billing/pdf', () => ({
  generateInvoicePdfBuffer: jest.fn(async () => Buffer.from('pdf'))}));

jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(async () => {})}));

jest.mock('@lib/billing/financials', () => ({
  toDecimalNumber: (value) => Number(value || 0),
  toMoneyString: (value) => String(value ?? '0.00'),
  recalculateInvoiceStateTx: jest.fn(async (_tx, invoiceId) => ({
    invoice: {
      id: invoiceId,
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'PAID',
      status: 'SENT',
      total_amount: '100.00',
      currency: 'UGX'},
    financials: {
      balance_due: 0,
      net_paid_total: 100,
      effective_total: 100,
      gross_paid_total: 100}})),
  computeInvoiceFinancials: jest.fn(() => ({
    balance_due: 0,
    net_paid_total: 100,
    effective_total: 100}))}));

jest.mock('@lib/billing/clinical-request-billing', () => ({
  resolveClinicalInvoiceContexts: jest.fn(async () => ({})),
  resolveInvoiceIdsForEncounterToken: jest.fn(async () => []),
  resolveInvoiceIdsForSourceModule: jest.fn(async () => []),
  syncClinicalOrderBillingSnapshotsFromInvoiceTx: jest.fn(async () => ({
    labOrderIds: []}))}));

jest.mock('@services/lab-order/lab-order.service', () => ({
  notifyLabOrdersBillingUpdated: jest.fn(async () => {})}));

jest.mock('@lib/websocket', () => ({
  publishDomainEvent: jest.fn(),
  BILLING_EVENTS: {
    BILLING_INVOICE_ISSUED: 'billing.invoice_issued',
    BILLING_PAYMENT_RECEIVED: 'billing.payment_received',
    INVOICE_UPDATED: 'invoice.updated',
    BILLING_BALANCE_UPDATED: 'billing.balance_updated'},
  PAYMENT_EVENTS: {
    PAYMENT_RECONCILED: 'payment.reconciled'}}));

jest.mock('@lib/realtime/recipients', () => ({
  findRealtimeRecipientUserIds: jest.fn(async () => ['billing-1', 'reception-1'])}));

const mockSyncConsultationBillingFromInvoicePayment = jest.fn(async () => null);
jest.mock('@services/opd-flow/opd-flow.service', () => ({
  syncConsultationBillingFromInvoicePayment: (...args) =>
    mockSyncConsultationBillingFromInvoicePayment(...args)}));

const billingRepository = require('@repositories/billing/billing.repository');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { publishDomainEvent } = require('@lib/websocket');
const { findRealtimeRecipientUserIds } = require('@lib/realtime/recipients');
const billingService = require('@services/billing/billing.service');

describe('billing.service reconcilePayment', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('persists payment, emits billing events, and syncs OPD consultation', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'payment') {
        return {
          id: 'pay-1',
          human_friendly_id: 'PAY0001',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          invoice_id: 'inv-1',
          amount: '100.00',
          status: 'PENDING',
          paid_at: null,
          invoice: {
            id: 'inv-1',
            tenant_id: 'tenant-1',
            facility_id: 'facility-1',
            patient_id: 'patient-1',
            encounter_id: 'encounter-1'}};
      }
      return null;
    });

    billingRepository.withTransaction.mockImplementation(async (callback) => {
      const tx = {
        payment: {
          update: jest.fn(async () => ({
            id: 'pay-1',
            invoice_id: 'inv-1',
            status: 'COMPLETED',
            amount: '100.00',
            paid_at: new Date('2026-07-21T06:00:00.000Z')}))}};
      return callback(tx);
    });

    billingRepository.findPaymentById.mockResolvedValue({
      id: 'pay-1',
      human_friendly_id: 'PAY0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      invoice_id: 'inv-1',
      status: 'COMPLETED',
      amount: '100.00',
      method: 'CASH',
      paid_at: new Date('2026-07-21T06:00:00.000Z'),
      invoice: {
        id: 'inv-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        billing_status: 'PAID',
        status: 'SENT',
        total_amount: '100.00',
        currency: 'UGX',
        patient_id: 'patient-1',
        encounter_id: 'encounter-1'}});
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-1',
      human_friendly_id: 'INV0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'PAID',
      status: 'SENT',
      total_amount: '100.00',
      currency: 'UGX',
      patient_id: 'patient-1',
      encounter_id: 'encounter-1',
      payments: [],
      adjustments: []});

    const result = await billingService.reconcilePayment(
      'PAY0001',
      { status: 'COMPLETED' },
      { id: 'user-billing', tenant_id: 'tenant-1', facility_id: 'facility-1' },
      '127.0.0.1'
    );

    expect(result.payment.status).toBe('COMPLETED');
    expect(result.invoice.billing_status).toBe('PAID');
    expect(publishDomainEvent).toHaveBeenCalled();
    expect(mockSyncConsultationBillingFromInvoicePayment).toHaveBeenCalledWith(
      expect.objectContaining({
        invoiceId: 'inv-1',
        context: expect.objectContaining({
          user_id: 'user-billing',
          tenant_id: 'tenant-1'})})
    );
    expect(findRealtimeRecipientUserIds).toHaveBeenCalledWith(
      expect.objectContaining({
        roles: expect.arrayContaining(['BILLING', 'RECEPTIONIST'])})
    );
  });
});
