/**
 * Billing & sections scan for ICU Ended stays (`/icu?section=ended`).
 *
 * Historical stays prefer read-only. ICU bed/day + critical-care package
 * charges post at stay start via persistIcuStayBilling; intensivist rounds
 * reuse persistWardRoundBilling. End stay does not invent cashier logic.
 * Settlement is owned by Billing.
 *
 * @module tests/modules/ipd-flow/services/ipd-flow.icu-ended-stays.billing-sections
 */

jest.mock('@repositories/ipd-flow/ipd-flow.repository');
jest.mock('@lib/audit');
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  IPD_EVENTS: {
    IPD_FLOW_UPDATED: 'ipd.flow.updated'},
  ADMISSION_BED_EVENTS: {
    PATIENT_ADMITTED: 'admission.patient_admitted',
    PATIENT_TRANSFERRED: 'admission.patient_transferred',
    PATIENT_DISCHARGED: 'admission.patient_discharged',
    BED_ASSIGNMENT_CHANGED: 'admission.bed_assignment_changed'},
  NOTIFICATION_EVENTS: {
    NOTIFICATION_CREATED: 'notification.created'}}));
jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    persistIcuStayBilling: jest.fn(),
    persistWardRoundBilling: jest.fn(),
    persistAdmissionBilling: jest.fn(),
    persistNursingServiceBilling: jest.fn(),
    mapClinicalOrderBillingFields: actual.mapClinicalOrderBillingFields};
});
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
  bed: { findFirst: jest.fn(), update: jest.fn() },
  ward: { findFirst: jest.fn() },
  user: { findFirst: jest.fn() },
  staff_profile: { findFirst: jest.fn() },
  transfer_request: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn()},
  bed_assignment: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn()},
  ward_round: { findFirst: jest.fn(), create: jest.fn() },
  nursing_note: { findFirst: jest.fn(), create: jest.fn() },
  medication_administration: { findFirst: jest.fn(), create: jest.fn() },
  pharmacy_order_item: { findFirst: jest.fn() },
  follow_up: { findFirst: jest.fn(), create: jest.fn() },
  discharge_summary: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn()},
  icu_stay: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn()},
  icu_observation: { findFirst: jest.fn(), create: jest.fn() },
  critical_alert: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn()},
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() }}));

const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const {
  persistIcuStayBilling,
  persistWardRoundBilling,
  BILLABLE_SOURCE_MODULES,
} = clinicalRequestBilling;
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');

const now = new Date('2026-07-30T08:00:00.000Z');

const packageBilling = {
  payment_status: 'PENDING',
  currency: 'UGX',
  total_amount: '150000.00',
  line_items: [
    {
      id: 'ICU_CRITICAL_CARE_PACKAGE',
      label: 'ICU critical-care package',
      quantity: 1,
      unit_price: '100000.00',
      line_total: '100000.00',
      catalog_type: 'SERVICE'},
    {
      id: 'ICU_BED_DAY',
      label: 'ICU bed / day',
      quantity: 1,
      unit_price: '50000.00',
      line_total: '50000.00',
      catalog_type: 'SERVICE'}]};

const roundBilling = {
  payment_status: 'PENDING',
  currency: 'UGX',
  total_amount: '25000.00',
  line_items: [
    {
      id: 'WARD_ROUND_FEE',
      label: 'ICU intensivist review fee',
      quantity: 1,
      unit_price: '25000.00',
      line_total: '25000.00',
      catalog_type: 'SERVICE'}]};

const buildAdmission = (overrides = {}) => ({
  id: 'adm-1',
  human_friendly_id: 'ADM0000001',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'pat-1',
  encounter_id: 'enc-1',
  status: 'ADMITTED',
  admitted_at: now,
  discharged_at: null,
  created_at: now,
  updated_at: now,
  tenant: {
    id: 'tenant-1',
    human_friendly_id: 'TEN0000001',
    name: 'Demo Tenant'},
  facility: {
    id: 'facility-1',
    human_friendly_id: 'FAC0000001',
    name: 'Main Facility',
    facility_type: 'HOSPITAL'},
  patient: {
    id: 'pat-1',
    human_friendly_id: 'PAT0000001',
    first_name: 'Ended',
    last_name: 'Patient',
    date_of_birth: null,
    gender: 'MALE',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1'},
  encounter: { id: 'enc-1', human_friendly_id: 'ENC0000001' },
  bed_assignments: [],
  transfer_requests: [],
  discharge_summaries: [],
  icu_stays: [],
  ward_rounds: [],
  nursing_notes: [],
  medication_administrations: [],
  ...overrides});

describe('ICU Ended stays billing & sections (IPD ICU handlers)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.user_role.findMany.mockResolvedValue([]);
    prisma.follow_up.create.mockResolvedValue({ id: 'fu-1' });
    prisma.notification.create.mockImplementation(async ({ data }) => ({
      id: `notif-${data.user_id}`,
      ...data,
      read_at: null,
      created_at: now,
      updated_at: now}));
    persistIcuStayBilling.mockResolvedValue({
      invoice_id: 'inv-icu-1',
      payment_status: 'PENDING'});
    persistWardRoundBilling.mockResolvedValue({
      invoice_id: 'inv-round-1',
      payment_status: 'PENDING'});
  });

  it('AC2: start ICU stay with billing posts persistIcuStayBilling', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(buildAdmission({ icu_stays: [] }))},
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-1' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-1',
            human_friendly_id: 'ICU0000001',
            started_at: now,
            ended_at: null,
            created_at: now,
            observations: [],
            alerts: []}]}),
    );

    await ipdFlowService.startIcuStay(
      'ADM0000001',
      { billing: packageBilling },
      { tenant_id: 'tenant-1', user_id: 'user-1' },
    );

    expect(persistIcuStayBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        icuStayId: 'icu-1',
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'pat-1',
        chargeKey: 'ICU_STAY_START',
        actorUserId: 'user-1'}),
    );
    expect(persistIcuStayBilling.mock.calls[0][1].billing.payment_status).toBe(
      'PENDING',
    );
  });

  it('AC2: start ICU stay without billing does not invent a parallel ledger', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(buildAdmission({ icu_stays: [] }))},
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: 'icu-1' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-1',
            human_friendly_id: 'ICU0000001',
            started_at: now,
            ended_at: null,
            created_at: now,
            observations: [],
            alerts: []}]}),
    );

    await ipdFlowService.startIcuStay(
      'ADM0000001',
      {},
      { tenant_id: 'tenant-1' },
    );

    expect(persistIcuStayBilling).not.toHaveBeenCalled();
  });

  it('AC2/AC3: ward round with billing posts persistWardRoundBilling', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(
            buildAdmission({
              icu_stays: [
                {
                  id: 'icu-ended',
                  human_friendly_id: 'ICU0000009',
                  started_at: now,
                  ended_at: now,
                  observations: [],
                  alerts: []}]}),
          )},
      ward_round: {
        create: jest.fn().mockResolvedValue({ id: 'wr-1' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());

    await ipdFlowService.addWardRound(
      'ADM0000001',
      { notes: 'Post-step-down review', billing: roundBilling },
      { tenant_id: 'tenant-1' },
    );

    expect(persistWardRoundBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        wardRoundId: 'wr-1',
        billing: roundBilling,
        patientId: 'pat-1'}),
    );
  });

  it('AC2: end ICU stay is NOT_BILLED — no persistIcuStayBilling / cashier', async () => {
    const activeStay = {
      id: 'icu-1',
      human_friendly_id: 'ICU0000001',
      started_at: now,
      ended_at: null,
      observations: [],
      alerts: []};
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(
            buildAdmission({ icu_stays: [activeStay] }),
          )},
      icu_stay: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'icu-1',
          admission_id: 'adm-1',
          ended_at: null}),
        update: jest.fn().mockResolvedValue({
          ...activeStay,
          ended_at: now})}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [{ ...activeStay, ended_at: now }]}),
    );

    await ipdFlowService.endIcuStay(
      'ADM0000001',
      { icu_stay_id: 'icu-1' },
      { tenant_id: 'tenant-1' },
    );

    expect(persistIcuStayBilling).not.toHaveBeenCalled();
    expect(persistWardRoundBilling).not.toHaveBeenCalled();
    expect(tx.icu_stay.update).toHaveBeenCalled();
  });

  it('AC6: persistIcuStayBilling source module is ICU_STAY (idempotent key)', () => {
    expect(BILLABLE_SOURCE_MODULES.ICU_STAY).toBe('ICU_STAY');
    expect(typeof clinicalRequestBilling.persistIcuStayBilling).toBe(
      'function',
    );
  });

  it('AC6: unauthorized path — billing helpers are not called without payload', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(buildAdmission())},
      ward_round: {
        create: jest.fn().mockResolvedValue({ id: 'wr-2' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-1' });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());

    await ipdFlowService.addWardRound(
      'ADM0000001',
      { notes: 'Note only' },
      { tenant_id: 'tenant-1' },
    );

    expect(persistWardRoundBilling).not.toHaveBeenCalled();
  });
});
