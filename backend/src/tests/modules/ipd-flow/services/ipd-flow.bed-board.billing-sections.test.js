/**
 * IPD Bed board Start admission billing-sections scan (`/ipd?section=bed-board`).
 *
 * Covers startIpdFlow → buildAdmissionBilling → persistAdmissionBilling for
 * deposits / admission fee / bed-day lines mounted from Bed board Start
 * admission. Proves request billing posts, facility fee fallback, no parallel
 * cash ledger, and idempotent ADMISSION_START charge key. Inline
 * receive-payment / adjust stay off the IPD flow service.
 */

jest.mock('@repositories/ipd-flow/ipd-flow.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined)}));
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  IPD_EVENTS: { IPD_FLOW_UPDATED: 'ipd.flow.updated' },
  ADMISSION_BED_EVENTS: {
    PATIENT_ADMITTED: 'admission.patient_admitted',
    PATIENT_TRANSFERRED: 'admission.patient_transferred',
    PATIENT_DISCHARGED: 'admission.patient_discharged',
    BED_ASSIGNMENT_CHANGED: 'admission.bed_assignment_changed'},
  NOTIFICATION_EVENTS: { NOTIFICATION_CREATED: 'notification.created' }}));

const mockPersistAdmissionBilling = jest.fn().mockResolvedValue({
  invoice_id: 'inv-bed-board-1',
  payment_status: 'PENDING',
  total_amount: '150000.00'});

jest.mock('@lib/billing/clinical-request-billing', () => ({
  persistAdmissionBilling: (...args) => mockPersistAdmissionBilling(...args),
  persistWardRoundBilling: jest.fn(),
  persistIcuStayBilling: jest.fn(),
  persistNursingServiceBilling: jest.fn(),
  mapClinicalOrderBillingFields: jest.fn((value) => value),
  normalizeBillingOfficeClinicalBilling: jest.fn((billing) => billing || null),
  shouldApplyClinicalRequestBilling: jest.fn((billing) => {
    if (!billing) return false;
    const status = String(billing.payment_status || '').toUpperCase();
    return (
      status !== 'NOT_BILLED' &&
      status !== 'NOT_REQUIRED' &&
      status !== 'NO_CHARGE'
    );
  }),
  buildPendingClinicalRequestBilling: jest.fn((opts) => ({
    payment_status: 'PENDING',
    currency: opts?.currency || 'USD',
    line_items: opts?.lineItems || opts?.line_items || [],
    total_amount: '0.00'})),
  BILLABLE_SOURCE_MODULES: {
    ADMISSION: 'ADMISSION',
    WARD_ROUND: 'WARD_ROUND'}}));

jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  admission: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn()},
  tenant: { findFirst: jest.fn() },
  facility: { findFirst: jest.fn() },
  patient: { findFirst: jest.fn() },
  encounter: { findFirst: jest.fn() },
  bed: { findFirst: jest.fn(), update: jest.fn() },
  bed_assignment: { create: jest.fn() },
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() }}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');
const {
  buildAdmissionBilling,
  ADMISSION_START_CHARGE_KEY} = require('@lib/billing/admission-billing');

const now = new Date('2026-07-30T08:00:00.000Z');

const billingPayload = {
  payment_status: 'PENDING',
  currency: 'UGX',
  total_amount: '150000.00',
  line_items: [
    {
      id: 'ADMISSION_FEE',
      label: 'Admission fee',
      quantity: 1,
      unit_price: '50000.00',
      line_total: '50000.00'},
    {
      id: 'ADMISSION_DEPOSIT',
      label: 'Admission deposit',
      quantity: 1,
      unit_price: '50000.00',
      line_total: '50000.00'},
    {
      id: 'BED_DAY',
      label: 'Bed / day',
      quantity: 1,
      unit_price: '50000.00',
      line_total: '50000.00'}]};

const buildAdmission = (overrides = {}) => ({
  id: 'adm-bed-board-1',
  human_friendly_id: 'ADM-BB-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-1',
  encounter_id: 'enc-1',
  status: 'ADMITTED',
  admitted_at: now,
  discharged_at: null,
  billing_snapshot: null,
  created_at: now,
  updated_at: now,
  bed_assignments: [],
  transfer_requests: [],
  discharge_summaries: [],
  icu_stays: [],
  ward_rounds: [],
  nursing_notes: [],
  medication_administrations: [],
  ...overrides});

const buildStartTx = ({ facility = null } = {}) => ({
  tenant: {
    findFirst: jest.fn().mockResolvedValue(null)},
  facility: {
    findFirst: jest.fn().mockResolvedValue(facility)},
  patient: {
    findFirst: jest.fn().mockResolvedValue({
      id: 'patient-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1'})},
  encounter: {
    findFirst: jest.fn().mockResolvedValue(null)},
  admission: {
    findFirst: jest.fn().mockResolvedValue(null),
    create: jest.fn().mockResolvedValue({ id: 'adm-bed-board-1' }),
    update: jest.fn()},
  bed: {
    findFirst: jest.fn(),
    update: jest.fn()},
  bed_assignment: {
    create: jest.fn()}});

describe('ipd-flow Bed board Start admission billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.user_role.findMany.mockResolvedValue([]);
    prisma.notification.create.mockResolvedValue({ id: 'n-1' });
  });

  it('AC2: startIpdFlow with billing posts via persistAdmissionBilling (no bypass)', async () => {
    const tx = buildStartTx();
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-bed-board-1' });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());

    await ipdFlowService.startIpdFlow(
      {
        patient_id: 'patient-1',
        billing: billingPayload},
      { tenant_id: 'tenant-1', facility_id: 'facility-1', user_id: 'user-1' }
    );

    expect(mockPersistAdmissionBilling).toHaveBeenCalledTimes(1);
    expect(mockPersistAdmissionBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        admissionId: 'adm-bed-board-1',
        billing: billingPayload,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-1',
        chargeKey: 'ADMISSION_START',
        actorUserId: 'user-1'})
    );
  });

  it('AC2: facility fee fallback posts PENDING admission / deposit / bed-day', async () => {
    const facility = {
      id: 'facility-1',
      extension_json: {
        billing: {
          admission_fee: 80000,
          admission_deposit: 20000,
          bed_day_fee: 50000,
          currency: 'UGX'}}};

    const tx = buildStartTx({ facility });
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-bed-board-1' });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());

    await ipdFlowService.startIpdFlow(
      { patient_id: 'patient-1' },
      { tenant_id: 'tenant-1', facility_id: 'facility-1' }
    );

    expect(mockPersistAdmissionBilling).toHaveBeenCalledTimes(1);
    expect(mockPersistAdmissionBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        admissionId: 'adm-bed-board-1',
        chargeKey: 'ADMISSION_START',
        billing: expect.objectContaining({
          payment_status: 'PENDING',
          line_items: expect.arrayContaining([
            expect.objectContaining({ id: 'admission-fee' }),
            expect.objectContaining({ id: 'admission-deposit' }),
            expect.objectContaining({ id: 'bed-day' })])})})
    );
  });

  it('AC2: start without billing or facility fees does not invent a cash ledger', async () => {
    const tx = buildStartTx({
      facility: { id: 'facility-1', extension_json: { billing: {} } }});
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-bed-board-1' });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());

    await ipdFlowService.startIpdFlow(
      { patient_id: 'patient-1' },
      { tenant_id: 'tenant-1', facility_id: 'facility-1' }
    );

    expect(mockPersistAdmissionBilling).not.toHaveBeenCalled();
  });

  it('AC6: idempotent start billing replay stays on shared Billing helper', async () => {
    const tx = buildStartTx();
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-bed-board-1' });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());

    await ipdFlowService.startIpdFlow(
      {
        patient_id: 'patient-1',
        billing: billingPayload},
      { tenant_id: 'tenant-1', facility_id: 'facility-1' }
    );

    expect(mockPersistAdmissionBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        chargeKey: ADMISSION_START_CHARGE_KEY,
        admissionId: 'adm-bed-board-1'})
    );
    expect(buildAdmissionBilling({ billing: billingPayload })).toEqual(
      billingPayload
    );
  });

  it('AC4/AC6: unauthorized path — no receive-payment / adjust on IPD flow', () => {
    expect(ipdFlowService.receivePayment).toBeUndefined();
    expect(ipdFlowService.adjustBilling).toBeUndefined();
    expect(mockPersistAdmissionBilling).not.toHaveBeenCalled();
  });
});
