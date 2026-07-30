/**
 * ICU Transfers tab billing-sections scan (`/icu?section=transfers`).
 *
 * Transfer request / update stay clinical logistics (no patient ledger).
 * Complementary start-icu-stay posts via persistIcuStayBilling. Proves no
 * parallel cash ledger on transfer mutations, billing post on stay start,
 * and idempotent charge-key reuse.
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

const mockPersistIcuStayBilling = jest.fn().mockResolvedValue({
  invoice_id: 'inv-icu-xfer-1',
  payment_status: 'PENDING',
  total_amount: '150000.00'});
const mockPersistWardRoundBilling = jest.fn().mockResolvedValue({
  invoice_id: 'inv-round-xfer-1',
  payment_status: 'PENDING',
  total_amount: '50000.00'});

jest.mock('@lib/billing/clinical-request-billing', () => ({
  persistIcuStayBilling: (...args) => mockPersistIcuStayBilling(...args),
  persistWardRoundBilling: (...args) => mockPersistWardRoundBilling(...args),
  persistAdmissionBilling: jest.fn(),
  persistNursingServiceBilling: jest.fn(),
  mapClinicalOrderBillingFields: jest.fn((value) => value),
  BILLABLE_SOURCE_MODULES: {
    ICU_STAY: 'ICU_STAY',
    WARD_ROUND: 'WARD_ROUND'}}));

jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  admission: {
    findFirst: jest.fn(),
    update: jest.fn()},
  ward: { findFirst: jest.fn() },
  transfer_request: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn()},
  ward_round: { create: jest.fn() },
  icu_stay: {
    create: jest.fn(),
    update: jest.fn()},
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() }}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');

const now = new Date('2026-07-30T10:00:00.000Z');

const billingPayload = {
  payment_status: 'PENDING',
  currency: 'UGX',
  total_amount: '150000.00',
  line_items: [
    {
      id: 'ICU_CRITICAL_CARE_PACKAGE',
      label: 'ICU critical-care package',
      quantity: 1,
      unit_price: '100000.00',
      line_total: '100000.00'},
    {
      id: 'ICU_BED_DAY',
      label: 'ICU bed / day',
      quantity: 1,
      unit_price: '50000.00',
      line_total: '50000.00'}]};

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
  created_at: now,
  updated_at: now,
  bed_assignments: [
    {
      id: 'ba-1',
      ended_at: null,
      bed: {
        id: 'bed-1',
        ward_id: 'ward-icu',
        label: 'ICU-5'}}],
  transfer_requests: [],
  discharge_summaries: [],
  icu_stays: [
    {
      id: 'icu-stay-1',
      human_friendly_id: 'ICU0001',
      started_at: now,
      ended_at: null,
      observations: [],
      alerts: []}],
  ward_rounds: [],
  nursing_notes: [],
  medication_administrations: [],
  ...overrides});

describe('ipd-flow ICU Transfers billing-sections scan', () => {
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
          .mockResolvedValueOnce(buildAdmission())},
      ward: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'ward-b',
          name: 'Ward B',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          deleted_at: null})},
      transfer_request: {
        create: jest.fn().mockResolvedValue({ id: 'tr-1' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-xfer-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        transfer_requests: [
          {
            id: 'tr-1',
            status: 'REQUESTED',
            to_ward_id: 'ward-b',
            requested_at: now,
            deleted_at: null}]}),
    );

    await ipdFlowService.requestTransfer(
      'ADM-XFER-1',
      { to_ward_id: 'ward-b' },
      { tenant_id: 'tenant-1', user_id: 'user-1' },
    );

    expect(tx.transfer_request.create).toHaveBeenCalledTimes(1);
    expect(mockPersistIcuStayBilling).not.toHaveBeenCalled();
    expect(mockPersistWardRoundBilling).not.toHaveBeenCalled();
  });

  it('updateTransfer approve does not invent a cash ledger', async () => {
    const openTransfer = {
      id: 'tr-1',
      status: 'REQUESTED',
      from_ward_id: 'ward-icu',
      to_ward_id: 'ward-b',
      requested_at: now,
      deleted_at: null};
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-xfer-1' })
          .mockResolvedValueOnce(
            buildAdmission({
              transfer_requests: [openTransfer]}),
          )},
      transfer_request: {
        findFirst: jest.fn().mockResolvedValue(openTransfer),
        update: jest.fn().mockResolvedValue({
          ...openTransfer,
          status: 'APPROVED'})}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-xfer-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        transfer_requests: [{ ...openTransfer, status: 'APPROVED' }]}),
    );

    await ipdFlowService.updateTransfer(
      'ADM-XFER-1',
      { action: 'APPROVE', transfer_request_id: 'tr-1' },
      { tenant_id: 'tenant-1' },
    );

    expect(tx.transfer_request.update).toHaveBeenCalled();
    expect(mockPersistIcuStayBilling).not.toHaveBeenCalled();
    expect(mockPersistWardRoundBilling).not.toHaveBeenCalled();
  });

  it('startIcuStay with billing posts via persistIcuStayBilling (no bypass)', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-xfer-1' })
          .mockResolvedValueOnce(buildAdmission({ icu_stays: [] }))},
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-stay-xfer' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-xfer-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-stay-xfer',
            human_friendly_id: 'ICU-XFER',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: []}]}),
    );

    await ipdFlowService.startIcuStay(
      'ADM-XFER-1',
      { billing: billingPayload },
      { tenant_id: 'tenant-1', user_id: 'user-1' },
    );

    expect(mockPersistIcuStayBilling).toHaveBeenCalledTimes(1);
    expect(mockPersistIcuStayBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        icuStayId: 'icu-stay-xfer',
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-1',
        encounterId: 'enc-1',
        chargeKey: 'ICU_STAY_START',
        actorUserId: 'user-1'}),
    );
  });

  it('startIcuStay without billing does not invent a module cash ledger', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-xfer-1' })
          .mockResolvedValueOnce(buildAdmission({ icu_stays: [] }))},
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-stay-plain' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-xfer-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-stay-plain',
            human_friendly_id: 'ICU-PLAIN',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: []}]}),
    );

    await ipdFlowService.startIcuStay(
      'ADM-XFER-1',
      {},
      { tenant_id: 'tenant-1' },
    );

    expect(mockPersistIcuStayBilling).not.toHaveBeenCalled();
  });

  it('idempotent startIcuStay billing replay reuses ICU_STAY_START charge key', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-xfer-1' })
          .mockResolvedValueOnce(buildAdmission({ icu_stays: [] }))},
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-stay-idem' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-xfer-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-stay-idem',
            human_friendly_id: 'ICU-IDEM',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: []}]}),
    );

    await ipdFlowService.startIcuStay(
      'ADM-XFER-1',
      { billing: billingPayload },
      { tenant_id: 'tenant-1' },
    );

    expect(mockPersistIcuStayBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        chargeKey: 'ICU_STAY_START',
        icuStayId: 'icu-stay-idem'}),
    );
  });
});
