jest.mock('@repositories/opd-flow/opd-flow.repository');
jest.mock('@lib/audit', () => ({ createAuditLog: jest.fn().mockResolvedValue({}) }));
jest.mock('@services/ipd-flow/ipd-flow.service', () => ({
  emitAdmissionRefreshEvent: jest.fn().mockResolvedValue(null)}));
jest.mock(
  '@services/clinical-alert-threshold/clinical-alert-threshold.service',
  () => ({ evaluateVitalAndCreateAlerts: jest.fn().mockResolvedValue(null) })
);

const mockEmitToUser = jest.fn();
const mockEmitToUsers = jest.fn();
jest.mock('@lib/websocket', () => ({
  emitToUser: (...args) => mockEmitToUser(...args),
  emitToUsers: (...args) => mockEmitToUsers(...args),
  publishDomainEvent: jest.fn(),
  OPD_EVENTS: { OPD_FLOW_UPDATED: 'opd.flow.updated' },
  NOTIFICATION_EVENTS: { NOTIFICATION_CREATED: 'notification.created' },
  BILLING_EVENTS: {
    BILLING_INVOICE_ISSUED: 'billing.invoice_issued',
    INVOICE_UPDATED: 'invoice.updated',
    BILLING_BALANCE_UPDATED: 'billing.balance_updated'}}));

jest.mock('@lib/billing/realtime', () => ({
  publishIssuedInvoiceBillingEvents: jest.fn(async () => {}),
  publishUpdatedInvoiceBillingEvents: jest.fn(async () => {}),
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
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() },
  notification_delivery: { createMany: jest.fn() },
  tenant: { findFirst: jest.fn() },
  facility: { findFirst: jest.fn() },
  patient: { findFirst: jest.fn() },
  user: { findFirst: jest.fn() },
  payment: { findMany: jest.fn() }}));

const prisma = require('@prisma/client');
const opdFlowRepository = require('@repositories/opd-flow/opd-flow.repository');
const opdFlowService = require('@services/opd-flow/opd-flow.service');

const DOCTOR_USER_ID = 'usr-doctor';
const BILLING_USER_ID = 'usr-billing';
const ACCOUNTANT_USER_ID = 'usr-accountant';

const buildEncounterAfterStart = ({ stage, consultation }) => ({
  id: 'enc-1',
  human_friendly_id: 'ENC0001',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-1',
  encounter_type: 'OPD',
  status: 'OPEN',
  provider_user_id: DOCTOR_USER_ID,
  extension_json: {
    opd_flow: {
      stage,
      next_step: stage === 'WAITING_CONSULTATION_PAYMENT' ? 'PAY_CONSULTATION' : 'RECORD_VITALS',
      consultation,
      timeline: []}},
  patient: { id: 'patient-1', human_friendly_id: 'PAT0001', first_name: 'Jane', last_name: 'Doe' },
  provider: { id: DOCTOR_USER_ID, human_friendly_id: 'USR0007', first_name: 'Ada', last_name: 'Ola' },
  tenant: { id: 'tenant-1', human_friendly_id: 'TEN0001' },
  facility: { id: 'facility-1', human_friendly_id: 'FAC0001' },
  vital_signs: [],
  clinical_notes: [],
  diagnoses: [],
  procedures: [],
  care_plans: []});

const buildTx = (encounterAfterStart) => ({
  admission: { findFirst: jest.fn().mockResolvedValue(null) },
  tenant: { findFirst: jest.fn().mockResolvedValue({ id: 'tenant-1' }) },
  appointment: { findFirst: jest.fn().mockResolvedValue(null), update: jest.fn() },
  patient: {
    findFirst: jest.fn().mockResolvedValue({
      id: 'patient-1',
      human_friendly_id: 'PAT0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      first_name: 'Jane',
      last_name: 'Doe'}),
    create: jest.fn()},
  user: {
    findFirst: jest.fn().mockResolvedValue({
      id: DOCTOR_USER_ID,
      human_friendly_id: 'USR0007',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      first_name: 'Ada',
      last_name: 'Ola'})},
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
    create: jest.fn().mockResolvedValue({ ...encounterAfterStart }),
    findFirst: jest.fn().mockResolvedValue(encounterAfterStart),
    update: jest.fn(),
    updateMany: jest.fn().mockResolvedValue({ count: 1 })},
  billable_charge_event: {
    findFirst: jest.fn().mockResolvedValue(null),
    create: jest.fn(),
    update: jest.fn()},
  invoice_item: { updateMany: jest.fn() }});

const notificationFor = (userId) => {
  const call = prisma.notification.create.mock.calls.find(
    ([args]) => args?.data?.user_id === userId
  );
  return call ? call[0].data : null;
};

const rolesQueriedForRecipients = () =>
  prisma.user_role.findMany.mock.calls.flatMap(
    ([args]) => args?.where?.role?.name?.in || []
  );

describe('startOpdFlow encounter-created notifications', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    opdFlowRepository.findOpenActiveEncounterForPatient.mockResolvedValue(null);
    prisma.user_role.findMany.mockResolvedValue([
      { user_id: BILLING_USER_ID },
      { user_id: ACCOUNTANT_USER_ID }]);
    prisma.notification.create.mockImplementation(async ({ data }) => ({
      ...data,
      id: `ntf-${data.user_id}`,
      human_friendly_id: `NTF-${data.user_id}`,
      created_at: new Date(),
      updated_at: new Date(),
      read_at: null}));
    prisma.notification_delivery.createMany.mockResolvedValue({ count: 1 });
    prisma.invoice.findFirst.mockResolvedValue(null);
  });

  it('notifies Billing and Accounting, and hands the assigned doctor their own alert', async () => {
    const encounterAfterStart = buildEncounterAfterStart({
      stage: 'WAITING_CONSULTATION_PAYMENT',
      consultation: {
        invoice_id: 'inv-start-1',
        consultation_fee: '25000.00',
        currency: 'UGX',
        require_payment: true,
        is_paid: false,
        payment_status: 'PENDING'}});
    const tx = buildTx(encounterAfterStart);
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await opdFlowService.startOpdFlow(
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        patient_id: 'patient-1',
        provider_user_id: DOCTOR_USER_ID,
        consultation_fee: '25000.00',
        currency: 'UGX',
        require_consultation_payment: true},
      { user_id: 'usr-reception', tenant_id: 'tenant-1', facility_id: 'facility-1' }
    );

    const roles = rolesQueriedForRecipients();
    expect(roles).toEqual(expect.arrayContaining(['BILLING', 'ACCOUNTANT']));

    const billingNotification = notificationFor(BILLING_USER_ID);
    expect(billingNotification).not.toBeNull();
    expect(billingNotification.title).toBe('OPD encounter started');
    expect(billingNotification.message).toContain('ENC0001');
    expect(billingNotification.message).toContain('25000.00 UGX');
    expect(billingNotification.message).toContain('payment required');

    expect(notificationFor(ACCOUNTANT_USER_ID)?.title).toBe('OPD encounter started');

    const doctorNotification = notificationFor(DOCTOR_USER_ID);
    expect(doctorNotification).not.toBeNull();
    expect(doctorNotification.title).toBe('New OPD patient assigned to you');
    expect(doctorNotification.priority).toBe('HIGH');

    // Instant delivery: every recipient gets the socket push, not just a row.
    expect(mockEmitToUsers).toHaveBeenCalledWith(
      expect.arrayContaining([BILLING_USER_ID, ACCOUNTANT_USER_ID, DOCTOR_USER_ID]),
      'opd.flow.updated',
      expect.objectContaining({ action: 'START_FLOW' })
    );
    expect(mockEmitToUser).toHaveBeenCalledWith(
      DOCTOR_USER_ID,
      'notification.created',
      expect.objectContaining({
        notification: expect.objectContaining({
          title: 'New OPD patient assigned to you'})})
    );
  });

  it('still reaches Billing and Accounting when the encounter needs no consultation payment', async () => {
    const encounterAfterStart = buildEncounterAfterStart({
      stage: 'WAITING_VITALS',
      consultation: {
        invoice_id: null,
        consultation_fee: '25000.00',
        currency: 'UGX',
        require_payment: false,
        is_paid: false,
        payment_status: 'NOT_REQUIRED'}});
    const tx = buildTx(encounterAfterStart);
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await opdFlowService.startOpdFlow(
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        patient_id: 'patient-1',
        provider_user_id: DOCTOR_USER_ID,
        consultation_fee: '25000.00',
        currency: 'UGX',
        require_consultation_payment: false},
      { user_id: 'usr-reception', tenant_id: 'tenant-1', facility_id: 'facility-1' }
    );

    // WAITING_VITALS routes to Nurses only; the revenue teams are unioned in.
    expect(rolesQueriedForRecipients()).toEqual(
      expect.arrayContaining(['NURSE', 'BILLING', 'ACCOUNTANT'])
    );
    const billingNotification = notificationFor(BILLING_USER_ID);
    expect(billingNotification?.title).toBe('OPD encounter started');
    expect(billingNotification?.message).not.toContain('payment required');
  });
});
