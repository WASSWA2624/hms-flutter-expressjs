/**
 * Nursing All tab billing-sections scan (`/nursing` / `?scope=all`).
 *
 * Billable nursing notes and discharge clearance post through ipd-flow →
 * clinical-request-billing / Billing ledger. Proves posting, no bypass,
 * ledger-derived billing_cleared, idempotent charge keys, and no inline
 * cashier on nursing handlers.
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

const mockPersistNursingServiceBilling = jest.fn().mockResolvedValue({
  invoice_id: 'inv-nurse-all-1',
  payment_status: 'PENDING',
  total_amount: '15000.00'});

jest.mock('@lib/billing/clinical-request-billing', () => ({
  persistAdmissionBilling: jest.fn(),
  persistWardRoundBilling: jest.fn(),
  persistNursingServiceBilling: (...args) =>
    mockPersistNursingServiceBilling(...args),
  persistIcuStayBilling: jest.fn(),
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
    ...opts})),
  BILLABLE_SOURCE_MODULES: {
    ADMISSION: 'ADMISSION',
    WARD_ROUND: 'WARD_ROUND',
    NURSING: 'NURSING'}}));

jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  admission: {
    findFirst: jest.fn(),
    update: jest.fn(),
    create: jest.fn()},
  nursing_note: { create: jest.fn(), update: jest.fn() },
  discharge_summary: { update: jest.fn() },
  invoice: { findMany: jest.fn() },
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() }}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');
const nursingNoteService = require('@services/nursing-note/nursing-note.service');

const now = new Date('2026-07-30T10:00:00.000Z');

const buildAdmission = (overrides = {}) => ({
  id: 'adm-all-1',
  human_friendly_id: 'ADM-ALL-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-all-1',
  encounter_id: 'enc-all-1',
  status: 'ADMITTED',
  admitted_at: now,
  discharged_at: null,
  billing_snapshot: null,
  created_at: now,
  updated_at: now,
  bed_assignments: [
    {
      id: 'ba-1',
      bed_id: 'bed-1',
      released_at: null,
      bed: { status: 'OCCUPIED' }}],
  transfer_requests: [],
  discharge_summaries: [
    {
      id: 'ds-all-1',
      summary: 'Planned discharge',
      status: 'PLANNED',
      clearance_snapshot: {
        nursing_cleared: false,
        billing_cleared: false},
      deleted_at: null,
      updated_at: now}],
  icu_stays: [],
  ward_rounds: [],
  nursing_notes: [],
  medication_administrations: [],
  ...overrides});

const nursingBillingPayload = {
  payment_status: 'PENDING',
  currency: 'UGX',
  total_amount: '15000.00',
  line_items: [
    {
      id: 'NURSING_SERVICE',
      label: 'Nursing',
      quantity: 1,
      unit_price: '15000.00',
      line_total: '15000.00'}]};

describe('ipd-flow Nursing All billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.user_role.findMany.mockResolvedValue([]);
    prisma.notification.create.mockResolvedValue({ id: 'n-1' });
  });

  it('AC2: addNursingNote with billing posts persistNursingServiceBilling', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-all-1' })
          .mockResolvedValueOnce(admission)},
      user: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'user-1',
          human_friendly_id: 'USR-1'})},
      nursing_note: {
        create: jest.fn().mockResolvedValue({ id: 'nn-all-1' }),
        update: jest.fn()}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-all-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.addNursingNote(
      'ADM-ALL-1',
      {
        note: 'Dressing change',
        nurse_user_id: 'user-1',
        billing: nursingBillingPayload},
      { tenant_id: 'tenant-1', user_id: 'user-1' },
    );

    expect(mockPersistNursingServiceBilling).toHaveBeenCalledTimes(1);
    expect(mockPersistNursingServiceBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        nursingNoteId: 'nn-all-1',
        patientId: 'patient-all-1',
        actorUserId: 'user-1'}),
    );
  });

  it('AC2: addNursingNote without billing does not invent a module cash ledger', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-all-1' })
          .mockResolvedValueOnce(admission)},
      user: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'user-1',
          human_friendly_id: 'USR-1'})},
      nursing_note: {
        create: jest.fn().mockResolvedValue({ id: 'nn-all-2' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-all-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.addNursingNote(
      'ADM-ALL-1',
      { note: 'Charted vitals follow-up', nurse_user_id: 'user-1' },
      { tenant_id: 'tenant-1', user_id: 'user-1' },
    );

    expect(mockPersistNursingServiceBilling).not.toHaveBeenCalled();
  });

  it('AC3/AC6: idempotent charge keys are per nursing_note id', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-all-1' })
          .mockResolvedValueOnce(admission)},
      user: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'user-1',
          human_friendly_id: 'USR-1'})},
      nursing_note: {
        create: jest.fn().mockResolvedValue({ id: 'nn-all-3' }),
        update: jest.fn()}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-all-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    const payload = {
      note: 'Chargeable dressing',
      nurse_user_id: 'user-1',
      billing: nursingBillingPayload};
    const context = { tenant_id: 'tenant-1', user_id: 'user-1' };

    await ipdFlowService.addNursingNote('ADM-ALL-1', payload, context);
    expect(mockPersistNursingServiceBilling).toHaveBeenCalledTimes(1);

    tx.nursing_note.create.mockResolvedValue({ id: 'nn-all-3b' });
    await ipdFlowService.addNursingNote('ADM-ALL-1', payload, context);
    expect(mockPersistNursingServiceBilling).toHaveBeenCalledTimes(2);
    expect(mockPersistNursingServiceBilling.mock.calls[0][1].nursingNoteId).toBe(
      'nn-all-3',
    );
    expect(mockPersistNursingServiceBilling.mock.calls[1][1].nursingNoteId).toBe(
      'nn-all-3b',
    );
  });

  it('AC2/AC5: updateDischargeClearance sets nursing_cleared; billing_cleared from ledger', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-all-1' })
          .mockResolvedValueOnce(admission)},
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-all-1' })},
      invoice: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'inv-open',
            status: 'ISSUED',
            balance_due: '5000.00',
            deleted_at: null}])}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-all-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.updateDischargeClearance(
      'ADM-ALL-1',
      { nursing_cleared: true, billing_cleared: true },
      { tenant_id: 'tenant-1', user_id: 'user-1' },
    );

    expect(tx.discharge_summary.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          clearance_snapshot: expect.objectContaining({
            nursing_cleared: true,
            billing_cleared: false})})}),
    );
  });

  it('AC4: Nursing All path has no receivePayment / adjust / refund', () => {
    expect(ipdFlowService.receivePayment).toBeUndefined();
    expect(ipdFlowService.adjustInvoice).toBeUndefined();
    expect(ipdFlowService.refundPayment).toBeUndefined();
    expect(nursingNoteService.receivePayment).toBeUndefined();
    expect(nursingNoteService.persistNursingServiceBilling).toBeUndefined();
  });
});
