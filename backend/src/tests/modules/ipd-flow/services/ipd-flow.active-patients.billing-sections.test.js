/**
 * IPD Active Patients tab billing-sections scan (`/ipd?section=active`).
 *
 * Covers startIpdFlow → persistAdmissionBilling, assignBed → BED_ASSIGN,
 * updateTransfer COMPLETE → BED_TRANSFER rate change, addWardRound /
 * addNursingNote optional charges. Proves no bypass / no inline cashier,
 * idempotent charge keys, and unauthorized settle paths stay on Billing.
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
  invoice_id: 'inv-adm-1',
  payment_status: 'PENDING',
  total_amount: '80000.00'});
const mockPersistWardRoundBilling = jest.fn().mockResolvedValue({
  invoice_id: 'inv-round-1',
  payment_status: 'PENDING',
  total_amount: '25000.00'});
const mockPersistNursingServiceBilling = jest.fn().mockResolvedValue({
  invoice_id: 'inv-nurse-1',
  payment_status: 'PENDING',
  total_amount: '15000.00'});

jest.mock('@lib/billing/clinical-request-billing', () => ({
  persistAdmissionBilling: (...args) => mockPersistAdmissionBilling(...args),
  persistWardRoundBilling: (...args) => mockPersistWardRoundBilling(...args),
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
  bed: {
    findFirst: jest.fn(),
    update: jest.fn()},
  bed_assignment: {
    create: jest.fn(),
    update: jest.fn()},
  ward: { findFirst: jest.fn() },
  ward_round: { create: jest.fn() },
  nursing_note: { create: jest.fn(), update: jest.fn() },
  transfer_request: { update: jest.fn() },
  facility: { findFirst: jest.fn() },
  patient: { findFirst: jest.fn() },
  tenant: { findFirst: jest.fn() },
  encounter: { findFirst: jest.fn() },
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() }}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');
const {
  BED_ASSIGN_CHARGE_KEY,
  bedTransferChargeKey,
  buildBedDayBilling,
  admissionSnapshotHasBedCharge} = require('@lib/billing/admission-billing');

const now = new Date('2026-07-30T10:00:00.000Z');

const admissionBillingPayload = {
  payment_status: 'PENDING',
  currency: 'UGX',
  total_amount: '80000.00',
  line_items: [
    {
      id: 'ADMISSION_FEE',
      label: 'Admission fee',
      quantity: 1,
      unit_price: '80000.00',
      line_total: '80000.00'}]};

const buildAdmission = (overrides = {}) => ({
  id: 'adm-1',
  human_friendly_id: 'ADM-ACTIVE-1',
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

describe('ipd-flow Active Patients billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.user_role.findMany.mockResolvedValue([]);
    prisma.notification.create.mockResolvedValue({ id: 'n-1' });
  });

  it('startIpdFlow with billing posts via persistAdmissionBilling (no bypass)', async () => {
    const created = buildAdmission();
    const tx = {
      tenant: {
        findFirst: jest.fn().mockResolvedValue({ id: 'tenant-1' })},
      facility: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'facility-1',
          extension_json: {
            billing: { admission_fee: 80000, currency: 'UGX' }}})},
      patient: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'patient-1',
          facility_id: 'facility-1'})},
      encounter: { findFirst: jest.fn().mockResolvedValue(null) },
      admission: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue(created),
        update: jest.fn()}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(created);

    await ipdFlowService.startIpdFlow(
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        patient_id: 'patient-1',
        billing: admissionBillingPayload},
      { tenant_id: 'tenant-1', facility_id: 'facility-1', user_id: 'user-1' },
    );

    expect(mockPersistAdmissionBilling).toHaveBeenCalledTimes(1);
    expect(mockPersistAdmissionBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        admissionId: 'adm-1',
        chargeKey: 'ADMISSION_START',
        patientId: 'patient-1',
        actorUserId: 'user-1'}),
    );
  });

  it('assignBed posts BED_ASSIGN when snapshot has no prior charge', async () => {
    const admission = buildAdmission({
      billing_snapshot: {
        payment_status: 'NOT_REQUIRED',
        audit_code: 'ADMISSION_REQUEST_NO_CHARGE'}});
    const bed = {
      id: 'bed-1',
      status: 'AVAILABLE',
      ward_id: 'ward-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1'};

    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission)},
      bed: {
        findFirst: jest.fn().mockResolvedValue(bed),
        update: jest.fn()},
      bed_assignment: {
        create: jest.fn().mockResolvedValue({ id: 'ba-1' })},
      ward: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'ward-1',
          ward_type: 'GENERAL'})},
      facility: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'facility-1',
          extension_json: {
            billing: { bed_day_fee: 50000, currency: 'UGX' }}})}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.assignBed(
      'ADM-ACTIVE-1',
      { bed_id: 'bed-1' },
      { tenant_id: 'tenant-1', user_id: 'user-1' },
    );

    expect(mockPersistAdmissionBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        admissionId: 'adm-1',
        chargeKey: BED_ASSIGN_CHARGE_KEY,
        description: 'Bed / day'}),
    );
  });

  it('assignBed does not double-charge when admission snapshot already billed', async () => {
    const admission = buildAdmission({
      billing_snapshot: {
        payment_status: 'PENDING',
        invoice_id: 'inv-existing',
        line_items: [{ id: 'bed-day', label: 'Bed / day' }]}});
    const bed = {
      id: 'bed-1',
      status: 'AVAILABLE',
      ward_id: 'ward-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1'};

    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission)},
      bed: {
        findFirst: jest.fn().mockResolvedValue(bed),
        update: jest.fn()},
      bed_assignment: {
        create: jest.fn().mockResolvedValue({ id: 'ba-1' })},
      ward: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'ward-1',
          ward_type: 'GENERAL'})},
      facility: { findFirst: jest.fn() }};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.assignBed(
      'ADM-ACTIVE-1',
      { bed_id: 'bed-1' },
      { tenant_id: 'tenant-1' },
    );

    expect(mockPersistAdmissionBilling).not.toHaveBeenCalled();
  });

  it('updateTransfer COMPLETE posts transfer rate change via persistAdmissionBilling', async () => {
    const transferRequest = {
      id: 'tr-1',
      status: 'IN_PROGRESS',
      from_ward_id: 'ward-general',
      to_ward_id: null};
    const activeAssignment = {
      id: 'ba-active',
      bed_id: 'bed-general',
      released_at: null,
      bed: { ward_id: 'ward-general', status: 'OCCUPIED' }};
    const admission = buildAdmission({
      bed_assignments: [activeAssignment],
      transfer_requests: [transferRequest]});
    const destinationBed = {
      id: 'bed-icu',
      status: 'AVAILABLE',
      ward_id: 'ward-icu',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1'};

    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission)},
      bed: {
        findFirst: jest.fn().mockResolvedValue(destinationBed),
        update: jest.fn()},
      bed_assignment: {
        update: jest.fn(),
        create: jest.fn()},
      transfer_request: { update: jest.fn() },
      ward: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'ward-general', ward_type: 'GENERAL' })
          .mockResolvedValueOnce({ id: 'ward-icu', ward_type: 'ICU' })},
      facility: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'facility-1',
          extension_json: {
            billing: {
              bed_day_fee: 50000,
              icu_bed_day_fee: 150000,
              currency: 'UGX' }}})}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.updateTransfer(
      'ADM-ACTIVE-1',
      {
        action: 'COMPLETE',
        transfer_request_id: 'tr-1',
        to_bed_id: 'bed-icu'},
      { tenant_id: 'tenant-1', user_id: 'user-1' },
    );

    expect(mockPersistAdmissionBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        admissionId: 'adm-1',
        chargeKey: bedTransferChargeKey('tr-1'),
        description: 'Bed / day (transfer rate)'}),
    );
  });

  it('addWardRound with billing posts persistWardRoundBilling', async () => {
    const admission = buildAdmission({
      bed_assignments: [
        {
          id: 'ba-1',
          bed_id: 'bed-1',
          released_at: null,
          bed: { status: 'OCCUPIED' }}]});
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission)},
      ward_round: {
        create: jest.fn().mockResolvedValue({ id: 'wr-1' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.addWardRound(
      'ADM-ACTIVE-1',
      {
        notes: 'Stable',
        billing: {
          payment_status: 'PENDING',
          total_amount: '25000.00',
          currency: 'UGX',
          line_items: [
            {
              id: 'WARD_ROUND_FEE',
              label: 'Ward round',
              quantity: 1,
              unit_price: '25000.00',
              line_total: '25000.00'}]}},
      { tenant_id: 'tenant-1' },
    );

    expect(mockPersistWardRoundBilling).toHaveBeenCalledTimes(1);
  });

  it('addNursingNote with billing posts persistNursingServiceBilling', async () => {
    const admission = buildAdmission({
      bed_assignments: [
        {
          id: 'ba-1',
          bed_id: 'bed-1',
          released_at: null,
          bed: { status: 'OCCUPIED' }}]});
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission)},
      nursing_note: {
        create: jest.fn().mockResolvedValue({ id: 'nn-1' }),
        update: jest.fn()}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.addNursingNote(
      'ADM-ACTIVE-1',
      {
        note: 'Vitals stable',
        billing: {
          payment_status: 'PENDING',
          total_amount: '15000.00',
          currency: 'UGX',
          line_items: [
            {
              id: 'NURSING_SERVICE',
              label: 'Nursing',
              quantity: 1,
              unit_price: '15000.00',
              line_total: '15000.00'}]}},
      { tenant_id: 'tenant-1' },
    );

    expect(mockPersistNursingServiceBilling).toHaveBeenCalledTimes(1);
  });

  it('addNursingNote without billing does not invent a module cash ledger', async () => {
    const admission = buildAdmission({
      bed_assignments: [
        {
          id: 'ba-1',
          bed_id: 'bed-1',
          released_at: null,
          bed: { status: 'OCCUPIED' }}]});
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission)},
      nursing_note: {
        create: jest.fn().mockResolvedValue({ id: 'nn-2' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.addNursingNote(
      'ADM-ACTIVE-1',
      { note: 'Charted' },
      { tenant_id: 'tenant-1' },
    );

    expect(mockPersistNursingServiceBilling).not.toHaveBeenCalled();
  });

  it('does not expose receivePayment / adjust on IPD Active handlers', () => {
    expect(ipdFlowService.receivePayment).toBeUndefined();
    expect(ipdFlowService.adjustInvoice).toBeUndefined();
    expect(ipdFlowService.refundPayment).toBeUndefined();
  });

  it('admissionSnapshotHasBedCharge and buildBedDayBilling helpers stay consistent', () => {
    expect(
      admissionSnapshotHasBedCharge({
        payment_status: 'NOT_REQUIRED'}),
    ).toBe(false);
    expect(
      admissionSnapshotHasBedCharge({
        payment_status: 'PENDING',
        invoice_id: 'inv-1'}),
    ).toBe(true);
    expect(
      buildBedDayBilling({
        facility: {
          extension_json: {
            billing: { bed_day_fee: 40, currency: 'USD' }}}}),
    ).toEqual(
      expect.objectContaining({
        payment_status: 'PENDING'}),
    );
  });
});
