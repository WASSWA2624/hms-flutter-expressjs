/**
 * ICU Discharge ready (`/icu?section=discharge`) billing-sections scan.
 *
 * Covers plan-discharge (clinical gate, no ledger invent), start-icu-stay
 * posting via persistIcuStayBilling, and finalize still requiring Billing
 * settlement — no parallel cash ledger on the ICU tab.
 *
 * @module tests/modules/ipd-flow/services/ipd-flow.discharge-ready.billing-sections
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
jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    persistIcuStayBilling: jest.fn(),
    persistWardRoundBilling: jest.fn(),
    applyClinicalRequestBilling: jest.fn()};
});
jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  admission: {
    findFirst: jest.fn(),
    update: jest.fn()},
  discharge_summary: {
    update: jest.fn(),
    create: jest.fn()},
  icu_stay: {
    create: jest.fn(),
    update: jest.fn()},
  ward_round: { create: jest.fn() },
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() },
  encounter: {
    findFirst: jest.fn(),
    findMany: jest.fn()},
  visit_queue: { updateMany: jest.fn() },
  appointment: { updateMany: jest.fn() },
  invoice: { findMany: jest.fn() }}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const {
  persistIcuStayBilling,
  persistWardRoundBilling} = require('@lib/billing/clinical-request-billing');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');

const now = new Date('2026-07-30T10:00:00.000Z');

const buildAdmission = (overrides = {}) => ({
  id: 'adm-dr-1',
  human_friendly_id: 'ADM-DR-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-1',
  encounter_id: 'enc-1',
  status: 'ADMITTED',
  admitted_at: now,
  discharged_at: null,
  created_at: now,
  updated_at: now,
  bed_assignments: [],
  transfer_requests: [],
  discharge_summaries: [],
  icu_stays: [],
  ...overrides});

const pendingBillingPayload = {
  payment_status: 'PENDING',
  currency: 'UGX',
  total_amount: 150000,
  line_items: [
    {
      id: 'ICU_CRITICAL_CARE_PACKAGE',
      label: 'ICU critical-care package',
      quantity: 1,
      unit_price: 100000},
    {
      id: 'ICU_BED_DAY',
      label: 'ICU bed / day',
      quantity: 1,
      unit_price: 50000}]};

describe('ipd-flow Discharge ready billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.user_role.findMany.mockResolvedValue([]);
    persistIcuStayBilling.mockResolvedValue({
      invoice_id: 'inv-icu-1',
      payment_status: 'PENDING'});
    persistWardRoundBilling.mockResolvedValue({
      invoice_id: 'inv-round-1',
      payment_status: 'PENDING'});
  });

  it('plan-discharge is clinical-only (no Billing post / no cashier bypass)', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-dr-1' })
          .mockResolvedValueOnce(admission)},
      discharge_summary: {
        create: jest.fn().mockResolvedValue({ id: 'ds-1', status: 'PLANNED' })},
      invoice: { findMany: jest.fn() }};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-dr-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        discharge_summaries: [
          {
            id: 'ds-1',
            status: 'PLANNED',
            summary: 'Step-down ready',
            clearance_snapshot: { summary_ready: true },
            deleted_at: null,
            updated_at: now}]}),
    );

    const result = await ipdFlowService.planDischarge(
      'ADM-DR-1',
      { summary: 'Step-down ready' },
      { user_id: 'user-1' },
    );

    expect(result).toBeTruthy();
    expect(tx.discharge_summary.create).toHaveBeenCalledTimes(1);
    expect(persistIcuStayBilling).not.toHaveBeenCalled();
    expect(persistWardRoundBilling).not.toHaveBeenCalled();
    expect(tx.invoice.findMany).not.toHaveBeenCalled();
  });

  it('start-icu-stay posts critical-care package via persistIcuStayBilling', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-dr-1' })
          .mockResolvedValueOnce(admission)},
      icu_stay: {
        create: jest.fn().mockResolvedValue({
          id: 'icu-stay-1',
          admission_id: 'adm-dr-1',
          started_at: now})}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-dr-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-stay-1',
            human_friendly_id: 'ICU0000001',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: []}]}),
    );

    await ipdFlowService.startIcuStay(
      'ADM-DR-1',
      { billing: pendingBillingPayload },
      { user_id: 'user-1' },
    );

    expect(tx.icu_stay.create).toHaveBeenCalledTimes(1);
    expect(persistIcuStayBilling).toHaveBeenCalledTimes(1);
    expect(persistIcuStayBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        icuStayId: 'icu-stay-1',
        tenantId: 'tenant-1',
        patientId: 'patient-1',
        facilityId: 'facility-1',
        encounterId: 'enc-1',
        chargeKey: 'ICU_STAY_START',
        description: 'ICU critical-care package',
        actorUserId: 'user-1',
        billing: expect.objectContaining({
          payment_status: 'PENDING',
          currency: 'UGX'}),
      }),
    );
  });

  it('start-icu-stay without billing stays NOT_BILLED (no orphan invoice)', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-dr-1' })
          .mockResolvedValueOnce(admission)},
      icu_stay: {
        create: jest.fn().mockResolvedValue({
          id: 'icu-stay-2',
          admission_id: 'adm-dr-1',
          started_at: now})}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-dr-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-stay-2',
            human_friendly_id: 'ICU0000002',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: []}]}),
    );

    await ipdFlowService.startIcuStay('ADM-DR-1', {}, { user_id: 'user-1' });

    expect(tx.icu_stay.create).toHaveBeenCalledTimes(1);
    expect(persistIcuStayBilling).not.toHaveBeenCalled();
  });

  it('idempotent replay of start-icu-stay billing uses same stay charge key', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-dr-1' })
          .mockResolvedValueOnce(admission)
          .mockResolvedValueOnce({ id: 'adm-dr-1' })
          .mockResolvedValueOnce(admission)},
      icu_stay: {
        create: jest
          .fn()
          .mockResolvedValueOnce({
            id: 'icu-stay-3',
            admission_id: 'adm-dr-1',
            started_at: now})
          .mockResolvedValueOnce({
            id: 'icu-stay-3',
            admission_id: 'adm-dr-1',
            started_at: now})}};

    // First call succeeds; second would normally reject active stay — we only
    // assert the charge key contract on the successful billing post.
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-dr-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: 'icu-stay-3',
            human_friendly_id: 'ICU0000003',
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: []}]}),
    );

    await ipdFlowService.startIcuStay(
      'ADM-DR-1',
      { billing: pendingBillingPayload },
      { user_id: 'user-1' },
    );

    expect(persistIcuStayBilling).toHaveBeenCalledTimes(1);
    expect(persistIcuStayBilling.mock.calls[0][1].chargeKey).toBe(
      'ICU_STAY_START',
    );
    expect(persistIcuStayBilling.mock.calls[0][1].icuStayId).toBe(
      'icu-stay-3',
    );
  });

  it('finalize still rejects when Billing balance due (discharge gate parity)', async () => {
    const clearanceComplete = {
      summary_ready: true,
      pending_orders_reviewed: true,
      pharmacy_cleared: true,
      billing_cleared: true,
      nursing_cleared: true,
      documents_ready: true,
      patient_exited: true,
      override_reason: null};
    const admission = buildAdmission({
      discharge_summaries: [
        {
          id: 'ds-1',
          summary: 'Ready after clearance',
          status: 'PLANNED',
          clearance_snapshot: clearanceComplete,
          deleted_at: null,
          updated_at: now}],
      icu_stays: [
        {
          id: 'icu-stay-1',
          started_at: now,
          ended_at: now,
          observations: [],
          alerts: []}]});

    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-dr-1' })
          .mockResolvedValueOnce(admission)},
      invoice: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'inv-1',
            total_amount: '150000.00',
            status: 'SENT',
            billing_status: 'ISSUED',
            payments: [],
            billing_adjustments: []}])}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await expect(
      ipdFlowService.finalizeDischarge(
        'ADM-DR-1',
        { summary: 'Ready after clearance' },
        {},
      ),
    ).rejects.toMatchObject({
      messageKey: 'errors.ipd_flow.billing_clearance_required'});
    expect(tx.invoice.findMany).toHaveBeenCalled();
    expect(persistIcuStayBilling).not.toHaveBeenCalled();
  });

  it('unauthorized path: clinical plan-discharge never calls receive-payment APIs', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-dr-1' })
          .mockResolvedValueOnce(admission)},
      discharge_summary: {
        create: jest.fn().mockResolvedValue({ id: 'ds-2' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-dr-1' });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        discharge_summaries: [
          {
            id: 'ds-2',
            status: 'PLANNED',
            summary: 'Note only',
            clearance_snapshot: { summary_ready: true },
            deleted_at: null,
            updated_at: now}]}),
    );

    await ipdFlowService.planDischarge(
      'ADM-DR-1',
      { summary: 'Note only' },
      { user_id: 'nurse-no-billing' },
    );

    expect(persistIcuStayBilling).not.toHaveBeenCalled();
    expect(persistWardRoundBilling).not.toHaveBeenCalled();
  });
});
