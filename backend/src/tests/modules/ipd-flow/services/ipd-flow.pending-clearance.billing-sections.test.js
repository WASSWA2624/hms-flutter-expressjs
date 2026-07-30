/**
 * Discharge Pending clearance billing-sections scan.
 *
 * Covers finalize / update-clearance Billing ledger gates used by
 * `/discharge?section=pending-clearance` (no parallel cash ledger).
 *
 * @module tests/modules/ipd-flow/services/ipd-flow.pending-clearance.billing-sections
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
    update: jest.fn()},
  discharge_summary: {
    update: jest.fn(),
    create: jest.fn()},
  user_role: { findMany: jest.fn() },
  notification: { create: jest.fn() },
  encounter: {
    findFirst: jest.fn(),
    findMany: jest.fn()},
  visit_queue: { updateMany: jest.fn() },
  appointment: { updateMany: jest.fn() }}));

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const ipdFlowRepository = require('@repositories/ipd-flow/ipd-flow.repository');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');

const now = new Date('2026-07-30T10:00:00.000Z');

const clearanceComplete = {
  summary_ready: true,
  pending_orders_reviewed: true,
  pharmacy_cleared: true,
  billing_cleared: true,
  nursing_cleared: true,
  documents_ready: true,
  patient_exited: true,
  override_reason: null};

const buildAdmission = (overrides = {}) => ({
  id: 'adm-1',
  human_friendly_id: 'ADM-PC-1',
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
  discharge_summaries: [
    {
      id: 'ds-1',
      summary: 'Ready after clearance',
      status: 'PLANNED',
      clearance_snapshot: clearanceComplete,
      deleted_at: null,
      updated_at: now}],
  ...overrides});

describe('ipd-flow Pending clearance billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.user_role.findMany.mockResolvedValue([]);
  });

  it('rejects finalize when Billing still has balance (no module-local bypass)', async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(buildAdmission())},
      invoice: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'inv-1',
            total_amount: '2500.00',
            status: 'SENT',
            billing_status: 'ISSUED',
            payments: [],
            billing_adjustments: []}])}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await expect(
      ipdFlowService.finalizeDischarge(
        'ADM-PC-1',
        { summary: 'Ready after clearance' },
        {},
      ),
    ).rejects.toMatchObject({
      messageKey: 'errors.ipd_flow.billing_clearance_required'});
    expect(tx.invoice.findMany).toHaveBeenCalled();
  });

  it('allows finalize when Billing ledger balance is settled', async () => {
    const admission = buildAdmission();
    const paidInvoice = {
      id: 'inv-1',
      total_amount: '2500.00',
      status: 'PAID',
      billing_status: 'PAID',
      payments: [
        {
          amount: '2500.00',
          status: 'COMPLETED',
          deleted_at: null,
          refunds: []}],
      billing_adjustments: []};
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission),
        update: jest.fn().mockResolvedValue({
          ...admission,
          status: 'DISCHARGED'})},
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-1' })},
      invoice: {
        findMany: jest.fn().mockResolvedValue([paidInvoice])},
      encounter: {
        findFirst: jest.fn(),
        findMany: jest.fn().mockResolvedValue([])},
      visit_queue: { updateMany: jest.fn() },
      appointment: { updateMany: jest.fn() }};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({ status: 'DISCHARGED', discharged_at: now }),
    );

    const result = await ipdFlowService.finalizeDischarge(
      'ADM-PC-1',
      { summary: 'Ready after clearance' },
      {},
    );

    expect(result).toBeTruthy();
    expect(tx.invoice.findMany).toHaveBeenCalledTimes(1);
    expect(tx.discharge_summary.update).toHaveBeenCalledTimes(1);
  });

  it('idempotent replay: second finalize gate does not invent a second ledger row', async () => {
    const admission = buildAdmission();
    const paidInvoice = {
      id: 'inv-1',
      total_amount: '100.00',
      status: 'PAID',
      billing_status: 'PAID',
      payments: [
        {
          amount: '100.00',
          status: 'COMPLETED',
          deleted_at: null,
          refunds: []}],
      billing_adjustments: []};
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission),
        update: jest.fn().mockResolvedValue({
          ...admission,
          status: 'DISCHARGED'})},
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-1' })},
      invoice: {
        findMany: jest.fn().mockResolvedValue([paidInvoice])},
      encounter: {
        findFirst: jest.fn(),
        findMany: jest.fn().mockResolvedValue([])},
      visit_queue: { updateMany: jest.fn() },
      appointment: { updateMany: jest.fn() }};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({ status: 'DISCHARGED', discharged_at: now }),
    );

    await ipdFlowService.finalizeDischarge(
      'ADM-PC-1',
      { summary: 'Ready after clearance' },
      {},
    );

    expect(tx.invoice.findMany).toHaveBeenCalledTimes(1);
    expect(tx.discharge_summary.create).not.toHaveBeenCalled();
  });

  it('update clearance cannot force billing_cleared while balance remains', async () => {
    const admission = buildAdmission({
      discharge_summaries: [
        {
          id: 'ds-1',
          summary: 'Ready',
          status: 'PLANNED',
          clearance_snapshot: {
            ...clearanceComplete,
            billing_cleared: false,
            patient_exited: false},
          deleted_at: null,
          updated_at: now}]});
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-1' })
          .mockResolvedValueOnce(admission)},
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-1' })},
      invoice: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'inv-open',
            total_amount: '99.00',
            status: 'SENT',
            billing_status: 'ISSUED',
            payments: [],
            billing_adjustments: []}])}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.updateDischargeClearance(
      'ADM-PC-1',
      { billing_cleared: true },
      {},
    );

    expect(tx.discharge_summary.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          clearance_snapshot: expect.objectContaining({
            billing_cleared: false})})}),
    );
  });
});
