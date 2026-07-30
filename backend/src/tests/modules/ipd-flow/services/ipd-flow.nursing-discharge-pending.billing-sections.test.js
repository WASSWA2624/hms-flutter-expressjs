/**
 * Nursing Discharge pending billing-sections scan.
 *
 * Covers handlers used by `/nursing?scope=discharge-pending`: nursing
 * clearance via updateDischargeClearance (ledger-derived billing_cleared),
 * optional nursing service charges via addNursingNote →
 * persistNursingServiceBilling, and no parallel cashier on nursing paths.
 *
 * @module tests/modules/ipd-flow/services/ipd-flow.nursing-discharge-pending.billing-sections
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
  payment_status: 'PENDING',
  invoice_id: 'inv-nursing-1'});

jest.mock('@lib/billing/clinical-request-billing', () => ({
  persistNursingServiceBilling: (...args) =>
    mockPersistNursingServiceBilling(...args),
  persistWardRoundBilling: jest.fn(),
  persistAdmissionBilling: jest.fn(),
  persistIcuStayBilling: jest.fn(),
  mapClinicalOrderBillingFields: jest.fn(),
  extractStoredClinicalBilling: jest.fn()}));

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

const clearanceBase = {
  summary_ready: true,
  pending_orders_reviewed: true,
  pharmacy_cleared: true,
  billing_cleared: false,
  nursing_cleared: false,
  documents_ready: true,
  patient_exited: false,
  override_reason: null};

const buildAdmission = (overrides = {}) => ({
  id: 'adm-disc-pending',
  human_friendly_id: 'ADM-NDP-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-ndp-1',
  encounter_id: 'enc-ndp-1',
  status: 'ADMITTED',
  admitted_at: now,
  discharged_at: null,
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
      id: 'ds-ndp-1',
      summary: 'Awaiting nursing + billing clearance',
      status: 'PLANNED',
      clearance_snapshot: clearanceBase,
      deleted_at: null,
      updated_at: now}],
  ...overrides});

describe('ipd-flow Nursing Discharge pending billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.user_role.findMany.mockResolvedValue([]);
  });

  it('updateDischargeClearance sets nursing_cleared but cannot force billing_cleared while balance remains', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-pending' })
          .mockResolvedValueOnce(admission)},
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-ndp-1' })},
      invoice: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'inv-open',
            total_amount: '1500.00',
            status: 'SENT',
            billing_status: 'ISSUED',
            payments: [],
            billing_adjustments: []}])}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-disc-pending' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.updateDischargeClearance(
      'ADM-NDP-1',
      { nursing_cleared: true, billing_cleared: true },
      { tenant_id: 'tenant-1', user_id: 'nurse-1' },
    );

    expect(tx.invoice.findMany).toHaveBeenCalled();
    expect(tx.discharge_summary.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          clearance_snapshot: expect.objectContaining({
            nursing_cleared: true,
            billing_cleared: false})})}),
    );
  });

  it('updateDischargeClearance derives billing_cleared true when ledger is settled', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-pending' })
          .mockResolvedValueOnce(admission)},
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-ndp-1' })},
      invoice: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'inv-paid',
            total_amount: '1500.00',
            status: 'PAID',
            billing_status: 'PAID',
            payments: [
              {
                amount: '1500.00',
                status: 'COMPLETED',
                deleted_at: null,
                refunds: []}],
            billing_adjustments: []}])}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-disc-pending' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.updateDischargeClearance(
      'ADM-NDP-1',
      { nursing_cleared: true },
      { tenant_id: 'tenant-1', user_id: 'nurse-1' },
    );

    expect(tx.discharge_summary.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          clearance_snapshot: expect.objectContaining({
            nursing_cleared: true,
            billing_cleared: true})})}),
    );
  });

  it('idempotent replay of updateDischargeClearance does not invent a second ledger row', async () => {
    const admission = buildAdmission({
      discharge_summaries: [
        {
          id: 'ds-ndp-1',
          summary: 'Cleared once',
          status: 'PLANNED',
          clearance_snapshot: {
            ...clearanceBase,
            nursing_cleared: true,
            billing_cleared: true},
          deleted_at: null,
          updated_at: now}]});
    let findFirstCalls = 0;
    const tx = {
      admission: {
        findFirst: jest.fn(async () => {
          findFirstCalls += 1;
          return findFirstCalls % 2 === 1
            ? { id: 'adm-disc-pending' }
            : admission;
        })},
      discharge_summary: {
        update: jest.fn().mockResolvedValue({ id: 'ds-ndp-1' })},
      invoice: {
        findMany: jest.fn().mockResolvedValue([])}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-disc-pending' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.updateDischargeClearance(
      'ADM-NDP-1',
      { nursing_cleared: true },
      { tenant_id: 'tenant-1', user_id: 'nurse-1' },
    );
    await ipdFlowService.updateDischargeClearance(
      'ADM-NDP-1',
      { nursing_cleared: true },
      { tenant_id: 'tenant-1', user_id: 'nurse-1' },
    );

    expect(mockPersistNursingServiceBilling).not.toHaveBeenCalled();
    expect(tx.discharge_summary.update).toHaveBeenCalledTimes(2);
  });

  it('addNursingNote with billing posts persistNursingServiceBilling (create-charge)', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-pending' })
          .mockResolvedValueOnce(admission)},
      user: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'nurse-1',
          human_friendly_id: 'USR-N1'})},
      nursing_note: {
        create: jest.fn().mockResolvedValue({ id: 'nn-ndp-1' }),
        update: jest.fn()}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-disc-pending' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.addNursingNote(
      'ADM-NDP-1',
      {
        note: '[DISCHARGE_CLEARANCE] Education complete',
        nurse_user_id: 'nurse-1',
        billing: {
          payment_status: 'PENDING',
          total_amount: '12000.00',
          currency: 'UGX',
          line_items: [
            {
              id: 'NURSING_SERVICE',
              label: 'Nursing service',
              quantity: 1,
              unit_price: '12000.00',
              line_total: '12000.00'}]}},
      { tenant_id: 'tenant-1', user_id: 'nurse-1' },
    );

    expect(mockPersistNursingServiceBilling).toHaveBeenCalledTimes(1);
    expect(mockPersistNursingServiceBilling).toHaveBeenCalledWith(
      tx,
      expect.objectContaining({
        nursingNoteId: 'nn-ndp-1',
        patientId: 'patient-ndp-1',
        tenantId: 'tenant-1'}),
    );
  });

  it('addNursingNote without billing does not invent a module cash ledger (NOT_BILLED path)', async () => {
    const admission = buildAdmission();
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-pending' })
          .mockResolvedValueOnce(admission)},
      user: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'nurse-1',
          human_friendly_id: 'USR-N1'})},
      nursing_note: {
        create: jest.fn().mockResolvedValue({ id: 'nn-ndp-2' })}};

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: 'adm-disc-pending' });
    ipdFlowRepository.findById.mockResolvedValue(admission);

    await ipdFlowService.addNursingNote(
      'ADM-NDP-1',
      {
        note: '[DISCHARGE_CLEARANCE] Belongings returned',
        nurse_user_id: 'nurse-1'},
      { tenant_id: 'tenant-1', user_id: 'nurse-1' },
    );

    expect(mockPersistNursingServiceBilling).not.toHaveBeenCalled();
    expect(tx.nursing_note.create).toHaveBeenCalled();
  });

  it('rejects finalize when Billing still has balance (no nursing-local bypass)', async () => {
    const admission = buildAdmission({
      discharge_summaries: [
        {
          id: 'ds-ndp-1',
          summary: 'Ready',
          status: 'PLANNED',
          clearance_snapshot: {
            ...clearanceBase,
            nursing_cleared: true,
            billing_cleared: true,
            patient_exited: true},
          deleted_at: null,
          updated_at: now}]});
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: 'adm-disc-pending' })
          .mockResolvedValueOnce(admission)},
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
        'ADM-NDP-1',
        { summary: 'Ready after nursing clearance' },
        {},
      ),
    ).rejects.toMatchObject({
      messageKey: 'errors.ipd_flow.billing_clearance_required'});
    expect(tx.invoice.findMany).toHaveBeenCalled();
  });

  it('does not expose receivePayment / adjust / refund on nursing discharge handlers', () => {
    expect(ipdFlowService.receivePayment).toBeUndefined();
    expect(ipdFlowService.adjustInvoice).toBeUndefined();
    expect(ipdFlowService.refundPayment).toBeUndefined();
  });
});
