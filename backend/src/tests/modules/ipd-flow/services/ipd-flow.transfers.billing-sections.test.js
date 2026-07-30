/**
 * IPD Transfers tab billing-sections scan (`/ipd?section=transfers`).
 *
 * Request / approve / start / cancel stay clinical logistics (no ledger).
 * COMPLETE posts via buildBedTransferBilling → persistAdmissionBilling when
 * destination rate differs (idempotent BED_TRANSFER:{transferId}).
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
  invoice_id: 'inv-xfer-1',
  payment_status: 'PENDING',
  total_amount: '150000.00'});
const mockPersistWardRoundBilling = jest.fn();
const mockPersistIcuStayBilling = jest.fn();

jest.mock('@lib/billing/clinical-request-billing', () => ({
  persistAdmissionBilling: (...args) => mockPersistAdmissionBilling(...args),
  persistWardRoundBilling: (...args) => mockPersistWardRoundBilling(...args),
  persistIcuStayBilling: (...args) => mockPersistIcuStayBilling(...args),
  persistNursingServiceBilling: jest.fn(),
  mapClinicalOrderBillingFields: jest.fn((value) => value),
  normalizeBillingOfficeClinicalBilling: jest.requireActual(
    '@lib/billing/clinical-request-billing',
  ).normalizeBillingOfficeClinicalBilling,
  shouldApplyClinicalRequestBilling: jest.requireActual(
    '@lib/billing/clinical-request-billing',
  ).shouldApplyClinicalRequestBilling,
  buildPendingClinicalRequestBilling: jest.requireActual(
    '@lib/billing/clinical-request-billing',
  ).buildPendingClinicalRequestBilling,
  BILLABLE_SOURCE_MODULES: {
    ADMISSION: 'ADMISSION',
    ICU_STAY: 'ICU_STAY',
    WARD_ROUND: 'WARD_ROUND'}}));

jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  admission: {
    findFirst: jest.fn(),
    update: jest.fn()},
  ward: { findFirst: jest.fn() },
  bed: { findFirst: jest.fn(), update: jest.fn() },
  bed_assignment: { create: jest.fn(), update: jest.fn() },
  facility: { findFirst: jest.fn() },
  transfer_request: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn()},
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() }}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');

const now = new Date('2026-07-30T10:00:00.000Z');

const wardGeneralId = '11111111-1111-4111-8111-111111111111';
const wardIcuId = '22222222-2222-4222-8222-222222222222';
const bedFromId = '33333333-3333-4333-8333-333333333333';
const bedToId = '44444444-4444-4444-8444-444444444444';
const transferId = '55555555-5555-4555-8555-555555555555';
const assignmentId = '66666666-6666-4666-8666-666666666666';

const facilityWithRates = {
  id: 'facility-1',
  deleted_at: null,
  extension_json: {
    billing: {
      bed_day_fee: 50000,
      icu_bed_day_fee: 150000,
      currency: 'UGX'}}};

const billingPayload = {
  payment_status: 'PENDING',
  currency: 'UGX',
  total_amount: '99000.00',
  line_items: [
    {
      id: 'override-transfer',
      label: 'Transfer override',
      quantity: 1,
      unit_price: '99000.00',
      line_total: '99000.00'}]};

const openTransfer = {
  id: transferId,
  status: 'IN_PROGRESS',
  from_ward_id: wardGeneralId,
  to_ward_id: wardIcuId,
  requested_at: now,
  deleted_at: null};

const buildAdmission = (overrides = {}) => ({
  id: 'adm-xfer-1',
  human_friendly_id: 'ADM-XFER-1',
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
  bed_assignments: [
    {
      id: assignmentId,
      bed_id: bedFromId,
      released_at: null,
      deleted_at: null,
      bed: {
        id: bedFromId,
        ward_id: wardGeneralId,
        label: 'G-1',
        status: 'OCCUPIED'}}],
  transfer_requests: [openTransfer],
  discharge_summaries: [],
  icu_stays: [],
  ward_rounds: [],
  nursing_notes: [],
  medication_administrations: [],
  ...overrides});

const stubWardLookups = (tx) => {
  tx.ward = {
    findFirst: jest.fn().mockImplementation(async ({ where }) => {
      const id = where?.id;
      if (id === wardGeneralId) {
        return {
          id: wardGeneralId,
          name: 'General',
          ward_type: 'GENERAL',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          deleted_at: null};
      }
      if (id === wardIcuId) {
        return {
          id: wardIcuId,
          name: 'ICU',
          ward_type: 'ICU',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          deleted_at: null};
      }
      return null;
    })};
};

describe('ipd-flow IPD Transfers billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.user_role.findMany.mockResolvedValue([]);
    prisma.notification.create.mockResolvedValue({ id: 'n-1' });
  });

  it('requestTransfer does not post Billing (NOT_REQUIRED logistics)', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-xfer-1' })
          .mockResolvedValueOnce(buildAdmission({ transfer_requests: [] }))},
      ward: {
        findFirst: jest.fn().mockResolvedValue({
          id: wardIcuId,
          name: 'ICU',
          ward_type: 'ICU',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          deleted_at: null})},
      transfer_request: {
        create: jest.fn().mockResolvedValue({ id: transferId })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-xfer-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        transfer_requests: [
          {
            ...openTransfer,
            status: 'REQUESTED'}]}),
    );

    await ipdFlowService.requestTransfer(
      'ADM-XFER-1',
      { to_ward_id: wardIcuId },
      { tenant_id: 'tenant-1', user_id: 'user-1' },
    );

    expect(tx.transfer_request.create).toHaveBeenCalledTimes(1);
    expect(mockPersistAdmissionBilling).not.toHaveBeenCalled();
  });

  it('updateTransfer approve does not invent a cash ledger', async () => {
    const requested = { ...openTransfer, status: 'REQUESTED' };
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-xfer-1' })
          .mockResolvedValueOnce(
            buildAdmission({ transfer_requests: [requested] }),
          )},
      transfer_request: {
        findFirst: jest.fn().mockResolvedValue(requested),
        update: jest.fn().mockResolvedValue({
          ...requested,
          status: 'APPROVED'})}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-xfer-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        transfer_requests: [{ ...requested, status: 'APPROVED' }]}),
    );

    await ipdFlowService.updateTransfer(
      'ADM-XFER-1',
      { action: 'APPROVE', transfer_request_id: transferId },
      { tenant_id: 'tenant-1' },
    );

    expect(tx.transfer_request.update).toHaveBeenCalled();
    expect(mockPersistAdmissionBilling).not.toHaveBeenCalled();
  });

  it('COMPLETE with rate change posts via persistAdmissionBilling (no bypass)', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-xfer-1' })
          .mockResolvedValueOnce(buildAdmission())},
      bed: {
        findFirst: jest.fn().mockResolvedValue({
          id: bedToId,
          status: 'AVAILABLE',
          ward_id: wardIcuId,
          room_id: null,
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          human_friendly_id: 'BED-ICU-1',
          label: 'ICU-1',
          deleted_at: null}),
        update: jest.fn().mockResolvedValue({})},
      bed_assignment: {
        update: jest.fn().mockResolvedValue({}),
        create: jest.fn().mockResolvedValue({ id: 'ba-new' })},
      facility: {
        findFirst: jest.fn().mockResolvedValue(facilityWithRates)},
      transfer_request: {
        findFirst: jest.fn().mockResolvedValue(openTransfer),
        update: jest.fn().mockResolvedValue({
          ...openTransfer,
          status: 'COMPLETED'})}};
    stubWardLookups(tx);

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-xfer-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        transfer_requests: [{ ...openTransfer, status: 'COMPLETED' }]}),
    );

    await ipdFlowService.updateTransfer(
      'ADM-XFER-1',
      {
        action: 'COMPLETE',
        transfer_request_id: transferId,
        to_bed_id: bedToId},
      { tenant_id: 'tenant-1', user_id: 'user-1' },
    );

    expect(mockPersistAdmissionBilling).toHaveBeenCalledTimes(1);
    expect(mockPersistAdmissionBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        admissionId: 'adm-xfer-1',
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-1',
        encounterId: 'enc-1',
        chargeKey: `BED_TRANSFER:${transferId}`,
        actorUserId: 'user-1',
        billing: expect.objectContaining({
          payment_status: 'PENDING'})}),
    );
    expect(mockPersistWardRoundBilling).not.toHaveBeenCalled();
  });

  it('COMPLETE same-rate does not post a duplicate bed/day charge', async () => {
    const sameWardTransfer = {
      ...openTransfer,
      to_ward_id: wardGeneralId};
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-xfer-1' })
          .mockResolvedValueOnce(
            buildAdmission({ transfer_requests: [sameWardTransfer] }),
          )},
      bed: {
        findFirst: jest.fn().mockResolvedValue({
          id: bedToId,
          status: 'AVAILABLE',
          ward_id: wardGeneralId,
          room_id: null,
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          human_friendly_id: 'BED-G-2',
          label: 'G-2',
          deleted_at: null}),
        update: jest.fn().mockResolvedValue({})},
      bed_assignment: {
        update: jest.fn().mockResolvedValue({}),
        create: jest.fn().mockResolvedValue({ id: 'ba-new' })},
      facility: {
        findFirst: jest.fn().mockResolvedValue(facilityWithRates)},
      transfer_request: {
        findFirst: jest.fn().mockResolvedValue(sameWardTransfer),
        update: jest.fn().mockResolvedValue({
          ...sameWardTransfer,
          status: 'COMPLETED'})}};
    stubWardLookups(tx);

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-xfer-1' });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());

    await ipdFlowService.updateTransfer(
      'ADM-XFER-1',
      {
        action: 'COMPLETE',
        transfer_request_id: transferId,
        to_bed_id: bedToId},
      { tenant_id: 'tenant-1' },
    );

    expect(tx.transfer_request.update).toHaveBeenCalled();
    expect(mockPersistAdmissionBilling).not.toHaveBeenCalled();
  });

  it('COMPLETE with explicit billing posts PENDING and reuses BED_TRANSFER key', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-xfer-1' })
          .mockResolvedValueOnce(buildAdmission())},
      bed: {
        findFirst: jest.fn().mockResolvedValue({
          id: bedToId,
          status: 'AVAILABLE',
          ward_id: wardIcuId,
          room_id: null,
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          human_friendly_id: 'BED-ICU-1',
          label: 'ICU-1',
          deleted_at: null}),
        update: jest.fn().mockResolvedValue({})},
      bed_assignment: {
        update: jest.fn().mockResolvedValue({}),
        create: jest.fn().mockResolvedValue({ id: 'ba-new' })},
      facility: {
        findFirst: jest.fn().mockResolvedValue(facilityWithRates)},
      transfer_request: {
        findFirst: jest.fn().mockResolvedValue(openTransfer),
        update: jest.fn().mockResolvedValue({
          ...openTransfer,
          status: 'COMPLETED'})}};
    stubWardLookups(tx);

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-xfer-1' });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());

    await ipdFlowService.updateTransfer(
      'ADM-XFER-1',
      {
        action: 'COMPLETE',
        transfer_request_id: transferId,
        to_bed_id: bedToId,
        billing: billingPayload},
      { tenant_id: 'tenant-1' },
    );

    expect(mockPersistAdmissionBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        chargeKey: `BED_TRANSFER:${transferId}`,
        billing: expect.objectContaining({
          payment_status: 'PENDING',
          total_amount: '99000.00'})}),
    );
  });

  it('payment status parity: persisted snapshot is PENDING (Billing SoR)', async () => {
    mockPersistAdmissionBilling.mockResolvedValueOnce({
      invoice_id: 'inv-parity',
      payment_status: 'PENDING',
      total_amount: '150000.00'});

    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-xfer-1' })
          .mockResolvedValueOnce(buildAdmission())},
      bed: {
        findFirst: jest.fn().mockResolvedValue({
          id: bedToId,
          status: 'AVAILABLE',
          ward_id: wardIcuId,
          room_id: null,
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          human_friendly_id: 'BED-ICU-1',
          label: 'ICU-1',
          deleted_at: null}),
        update: jest.fn().mockResolvedValue({})},
      bed_assignment: {
        update: jest.fn().mockResolvedValue({}),
        create: jest.fn().mockResolvedValue({ id: 'ba-new' })},
      facility: {
        findFirst: jest.fn().mockResolvedValue(facilityWithRates)},
      transfer_request: {
        findFirst: jest.fn().mockResolvedValue(openTransfer),
        update: jest.fn().mockResolvedValue({
          ...openTransfer,
          status: 'COMPLETED'})}};
    stubWardLookups(tx);

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-xfer-1' });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());

    await ipdFlowService.updateTransfer(
      'ADM-XFER-1',
      {
        action: 'COMPLETE',
        transfer_request_id: transferId,
        to_bed_id: bedToId},
      { tenant_id: 'tenant-1' },
    );

    const persisted = mockPersistAdmissionBilling.mock.results[0].value;
    await expect(persisted).resolves.toEqual(
      expect.objectContaining({
        payment_status: 'PENDING',
        invoice_id: 'inv-parity'}),
    );
  });
});
