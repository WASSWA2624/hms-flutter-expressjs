jest.mock('@repositories/opd-flow/opd-flow.repository');
jest.mock('@lib/audit', () => ({ createAuditLog: jest.fn().mockResolvedValue({}) }));
jest.mock('@services/ipd-flow/ipd-flow.service', () => ({
  emitAdmissionRefreshEvent: jest.fn().mockResolvedValue(null)}));
jest.mock(
  '@services/clinical-alert-threshold/clinical-alert-threshold.service',
  () => ({ evaluateVitalAndCreateAlerts: jest.fn().mockResolvedValue(null) })
);
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  publishDomainEvent: jest.fn(),
  OPD_EVENTS: { OPD_FLOW_UPDATED: 'opd.flow.updated' },
  NOTIFICATION_EVENTS: { NOTIFICATION_CREATED: 'notification.created' },
  BILLING_EVENTS: {
    BILLING_INVOICE_ISSUED: 'billing.invoice_issued',
    INVOICE_UPDATED: 'invoice.updated',
    BILLING_BALANCE_UPDATED: 'billing.balance_updated'}}));

const mockPublishIssued = jest.fn(async () => {});
const mockPublishUpdated = jest.fn(async () => {});
jest.mock('@lib/billing/realtime', () => ({
  publishIssuedInvoiceBillingEvents: (...args) => mockPublishIssued(...args),
  publishUpdatedInvoiceBillingEvents: (...args) => mockPublishUpdated(...args),
  publishBillingRealtimeUpdate: jest.fn()}));

jest.mock('@lib/billing/clinical-request-billing', () => ({
  buildConsultationBillingPayload: jest.fn(({ consultationFee, currency }) => ({
    payment_status: 'PENDING',
    lines: [{ description: 'Consultation fee', quantity: 1, unit_price: consultationFee }],
    currency})),
  persistConsultationBilling: jest.fn(async () => ({
    invoice_id: 'inv-start-1',
    payment_status: 'PENDING',
    total_amount: '25000.00',
    currency: 'UGX'})),
  cancelInvoiceIfReversible: jest.fn(async () => true)}));

jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  encounter: { findFirst: jest.fn(), findMany: jest.fn(), update: jest.fn() },
  invoice: { findFirst: jest.fn() },
  user_role: { findMany: jest.fn().mockResolvedValue([]) },
  notification: { create: jest.fn() },
  notification_delivery: { createMany: jest.fn() },
  tenant: { findFirst: jest.fn() },
  facility: { findFirst: jest.fn() },
  patient: { findFirst: jest.fn() },
  user: { findFirst: jest.fn() },
  payment: { findMany: jest.fn() }}));

const prisma = require('@prisma/client');
const opdFlowRepository = require('@repositories/opd-flow/opd-flow.repository');
const {
  persistConsultationBilling,
  cancelInvoiceIfReversible} = require('@lib/billing/clinical-request-billing');
const opdFlowService = require('@services/opd-flow/opd-flow.service');

describe('startOpdFlow consultation billing realtime', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    opdFlowRepository.findOpenActiveEncounterForPatient.mockResolvedValue(null);
    prisma.user_role.findMany.mockResolvedValue([]);
    prisma.invoice.findFirst.mockResolvedValue({
      id: 'inv-start-1',
      human_friendly_id: 'INV000099',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1',
      billing_status: 'ISSUED',
      status: 'SENT',
      total_amount: '25000.00',
      currency: 'UGX',
      patient: {
        id: 'patient-1',
        human_friendly_id: 'PAT0001',
        first_name: 'Jane',
        last_name: 'Doe'}});
  });

  it('publishes Billing invoice events when Start OPD creates a consultation payable', async () => {
    const encounterAfterStart = {
      id: 'enc-1',
      human_friendly_id: 'ENC0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1',
      encounter_type: 'OPD',
      status: 'OPEN',
      provider_user_id: null,
      extension_json: {
        opd_flow: {
          stage: 'WAITING_CONSULTATION_PAYMENT',
          next_step: 'PAY_CONSULTATION',
          consultation: {
            invoice_id: 'inv-start-1',
            consultation_fee: '25000.00',
            require_payment: true,
            is_paid: false,
            payment_status: 'PENDING'},
          timeline: []}},
      patient: { id: 'patient-1', human_friendly_id: 'PAT0001', first_name: 'Jane', last_name: 'Doe' },
      provider: null,
      tenant: { id: 'tenant-1', human_friendly_id: 'TEN0001' },
      facility: { id: 'facility-1', human_friendly_id: 'FAC0001' },
      vital_signs: [],
      clinical_notes: [],
      diagnoses: [],
      procedures: [],
      care_plans: []};

    const tx = {
      admission: { findFirst: jest.fn().mockResolvedValue(null) },
      tenant: { findFirst: jest.fn().mockResolvedValue({ id: 'tenant-1' }) },
      appointment: { findFirst: jest.fn().mockResolvedValue(null), update: jest.fn() },
      patient: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'patient-1',
          human_friendly_id: 'PAT0001',
          first_name: 'Jane',
          last_name: 'Doe'}),
        create: jest.fn()},
      facility: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'facility-1',
          human_friendly_id: 'FAC0001',
          tenant_id: 'tenant-1'})},
      invoice: {
        create: jest.fn(),
        findFirst: jest.fn().mockResolvedValue({
          id: 'inv-start-1',
          total_amount: '25000.00',
          currency: 'UGX',
          billing_status: 'ISSUED',
          status: 'SENT',
          payments: []}),
        update: jest.fn()},
      payment: { create: jest.fn(), findFirst: jest.fn(), updateMany: jest.fn() },
      emergency_case: { create: jest.fn(), findFirst: jest.fn() },
      triage_assessment: { create: jest.fn(), findFirst: jest.fn() },
      visit_queue: { create: jest.fn().mockResolvedValue({ id: 'vq-1' }), findFirst: jest.fn() },
      encounter: {
        create: jest.fn().mockResolvedValue({
          id: 'enc-1',
          human_friendly_id: 'ENC0001',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          patient_id: 'patient-1',
          encounter_type: 'OPD',
          status: 'OPEN',
          extension_json: { opd_flow: { stage: 'WAITING_CONSULTATION_PAYMENT' } }}),
        findFirst: jest.fn().mockResolvedValue(encounterAfterStart),
        update: jest.fn(),
        updateMany: jest.fn().mockResolvedValue({ count: 1 })},
      billable_charge_event: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        update: jest.fn()},
      invoice_item: { updateMany: jest.fn() }};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    const result = await opdFlowService.startOpdFlow(
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        patient_id: 'patient-1',
        consultation_fee: '25000.00',
        currency: 'UGX',
        require_consultation_payment: true},
      { user_id: 'usr-reception', tenant_id: 'tenant-1', facility_id: 'facility-1' }
    );

    expect(persistConsultationBilling).toHaveBeenCalled();
    expect(result.flow.stage).toBe('WAITING_CONSULTATION_PAYMENT');
    expect(result.flow.consultation.invoice_id).toBe('inv-start-1');
    expect(mockPublishIssued).toHaveBeenCalledWith(
      expect.objectContaining({
        invoice: expect.objectContaining({ id: 'inv-start-1' }),
        actorUserId: 'usr-reception',
        action: 'ISSUED'})
    );
    expect(mockPublishUpdated).not.toHaveBeenCalled();
  });

  it('publishes Billing cancel events when encounter cancel voids consultation invoice', async () => {
    const encounter = {
      id: 'enc-2',
      human_friendly_id: 'ENC0002',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1',
      encounter_type: 'OPD',
      status: 'OPEN',
      provider_user_id: null,
      extension_json: {
        opd_flow: {
          stage: 'WAITING_CONSULTATION_PAYMENT',
          consultation: {
            invoice_id: 'inv-cancel-1',
            require_payment: true,
            is_paid: false},
          timeline: []}},
      patient: { id: 'patient-1', human_friendly_id: 'PAT0001' },
      provider: null,
      tenant: { id: 'tenant-1' },
      facility: { id: 'facility-1' },
      vital_signs: [],
      clinical_notes: [],
      diagnoses: [],
      procedures: [],
      care_plans: []};

    const finalized = {
      ...encounter,
      status: 'CANCELLED',
      extension_json: {
        opd_flow: {
          ...encounter.extension_json.opd_flow,
          stage: 'WAITING_CONSULTATION_PAYMENT',
          consultation: { invoice_id: 'inv-cancel-1' }}}};

    const tx = {
      encounter: {
        findFirst: jest.fn().mockResolvedValue(encounter),
        update: jest.fn().mockResolvedValue(finalized)},
      visit_queue: { update: jest.fn() },
      appointment: { findFirst: jest.fn().mockResolvedValue(null), update: jest.fn() },
      emergency_case: { update: jest.fn() },
      invoice: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'inv-cancel-1',
          status: 'SENT',
          billing_status: 'ISSUED',
          payments: []}),
        update: jest.fn()},
      invoice_item: { updateMany: jest.fn() },
      payment: { updateMany: jest.fn() },
      billable_charge_event: {
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn()}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.invoice.findFirst.mockResolvedValue({
      id: 'inv-cancel-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1',
      billing_status: 'CANCELLED',
      status: 'CANCELLED',
      total_amount: '25000.00',
      currency: 'UGX'});

    // getOpdFlowById after cancel uses another transaction
    prisma.$transaction
      .mockImplementationOnce(async (callback) => callback(tx))
      .mockImplementationOnce(async (callback) =>
        callback({
          ...tx,
          encounter: {
            findFirst: jest.fn().mockResolvedValue(finalized)}})
      );

    await opdFlowService.cancelEncounter(
      'enc-2',
      { reason_code: 'PATIENT_LEFT' },
      { user_id: 'usr-reception', tenant_id: 'tenant-1' }
    );

    expect(cancelInvoiceIfReversible).toHaveBeenCalledWith(tx, 'inv-cancel-1');
    expect(mockPublishUpdated).toHaveBeenCalledWith(
      expect.objectContaining({
        invoice: expect.objectContaining({ id: 'inv-cancel-1' }),
        action: 'CANCELLED'})
    );
  });
});
