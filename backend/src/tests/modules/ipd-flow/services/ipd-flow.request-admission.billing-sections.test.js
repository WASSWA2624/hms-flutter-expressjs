/**
 * IPD admission request billing audit for Clinical In consultation
 * (`requestAdmission` → POST /ipd-flows/request).
 *
 * Request-time admission is NOT_REQUIRED; bed/admission charges post on IPD
 * start via persistAdmissionBilling when billing is supplied.
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
jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  admission: {
    findFirst: jest.fn(),
    update: jest.fn(),
    create: jest.fn()},
  tenant: { findFirst: jest.fn() },
  facility: { findFirst: jest.fn() },
  patient: { findFirst: jest.fn() },
  encounter: { findFirst: jest.fn() },
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() },
  follow_up: { create: jest.fn() }}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');

const now = new Date('2026-07-30T10:00:00.000Z');

const notRequiredSnapshot = {
  payment_status: 'NOT_REQUIRED',
  audit_code: 'ADMISSION_REQUEST_NO_CHARGE',
  note: 'Bed/admission charges post on IPD start when billing is supplied'};

const buildAdmission = (overrides = {}) => ({
  id: 'adm-new',
  human_friendly_id: 'ADM-NEW',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-1',
  encounter_id: 'enc-1',
  status: 'REQUESTED',
  admitted_at: now,
  discharged_at: null,
  billing_snapshot: notRequiredSnapshot,
  created_at: now,
  updated_at: now,
  tenant: {
    id: 'tenant-1',
    human_friendly_id: 'TEN-1',
    name: 'Demo Tenant'},
  facility: {
    id: 'facility-1',
    human_friendly_id: 'FAC-1',
    name: 'Main Facility',
    facility_type: 'HOSPITAL'},
  patient: {
    id: 'patient-1',
    human_friendly_id: 'PAT-1',
    first_name: 'Ada',
    last_name: 'Lovelace',
    date_of_birth: null,
    gender: 'FEMALE',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1'},
  encounter: null,
  bed_assignments: [],
  transfer_requests: [],
  discharge_summaries: [],
  icu_stays: [],
  ward_rounds: [],
  nursing_notes: [],
  medication_administrations: [],
  ...overrides});

describe('ipd-flow.requestIpdAdmission billing (Clinical In consultation)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.user_role.findMany.mockResolvedValue([]);
    prisma.notification.create.mockResolvedValue({ id: 'n-1' });
    prisma.follow_up.create.mockResolvedValue({ id: 'fu-1' });
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-new' });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());
  });

  it('writes NOT_REQUIRED billing_snapshot on new admission request (no charge)', async () => {
    const created = buildAdmission();

    const tx = {
      tenant: {
        findFirst: jest.fn().mockResolvedValue({ id: 'tenant-1' })},
      facility: {
        findFirst: jest.fn().mockResolvedValue({ id: 'facility-1' })},
      patient: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'patient-1',
          facility_id: 'facility-1'})},
      encounter: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'enc-1',
          patient_id: 'patient-1'})},
      admission: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue(created),
        update: jest.fn()}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    const result = await ipdFlowService.requestIpdAdmission(
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        patient_id: 'patient-1',
        encounter_id: 'enc-1',
        reason: 'Needs observation'},
      { tenant_id: 'tenant-1', facility_id: 'facility-1', user_id: 'user-1' }
    );

    expect(tx.admission.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          billing_snapshot: expect.objectContaining({
            payment_status: 'NOT_REQUIRED',
            audit_code: 'ADMISSION_REQUEST_NO_CHARGE'})})})
    );
    expect(result.billing_snapshot?.payment_status).toBe('NOT_REQUIRED');
    expect(tx.admission.create.mock.calls[0][0].data.billing_snapshot.invoice_id)
      .toBeUndefined();
  });

  it('does not overwrite an existing billing_snapshot on request update', async () => {
    const existing = {
      id: 'adm-existing',
      status: 'REQUESTED',
      facility_id: 'facility-1',
      encounter_id: 'enc-1',
      billing_snapshot: {
        payment_status: 'PENDING',
        invoice_id: 'inv-keep'}};
    const updated = {
      ...existing,
      updated_at: now};

    const tx = {
      tenant: {
        findFirst: jest.fn().mockResolvedValue({ id: 'tenant-1' })},
      facility: {
        findFirst: jest.fn().mockResolvedValue({ id: 'facility-1' })},
      patient: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'patient-1',
          facility_id: 'facility-1'})},
      encounter: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'enc-1',
          patient_id: 'patient-1'})},
      admission: {
        findFirst: jest.fn().mockResolvedValue(existing),
        create: jest.fn(),
        update: jest.fn().mockResolvedValue(updated)}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-existing' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        id: 'adm-existing',
        billing_snapshot: existing.billing_snapshot})
    );

    await ipdFlowService.requestIpdAdmission(
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        patient_id: 'patient-1',
        encounter_id: 'enc-1',
        reason: 'Still needs bed'},
      { tenant_id: 'tenant-1', facility_id: 'facility-1', user_id: 'user-1' }
    );

    expect(tx.admission.update).toHaveBeenCalled();
    const updateData = tx.admission.update.mock.calls[0][0].data;
    expect(updateData.billing_snapshot).toBeUndefined();
  });

  it('does not expose inline receive-payment / adjust on request path', () => {
    expect(ipdFlowService.receivePayment).toBeUndefined();
    expect(ipdFlowService.adjustInvoice).toBeUndefined();
  });
});
