/**
 * Procedure service billing coverage for Clinical Urgent reopen / order flows
 * that call POST /procedures with request-time billing.
 */

jest.mock('@repositories/procedure/procedure.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined)}));
jest.mock('@prisma/client', () => ({
  encounter: {
    findFirst: jest.fn()},
  procedure: {
    update: jest.fn()},
  $transaction: jest.fn()}));
jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    persistProcedureBilling: jest.fn().mockResolvedValue({
      payment_status: 'PENDING',
      invoice_id: 'inv-urgent-1'}),
    reverseClinicalRequestBilling: jest.fn().mockResolvedValue(null),
    extractStoredClinicalBilling: jest.fn().mockReturnValue(null)};
});

const prisma = require('@prisma/client');
const procedureRepository = require('@repositories/procedure/procedure.repository');
const { createAuditLog } = require('@lib/audit');
const {
  persistProcedureBilling,
  reverseClinicalRequestBilling,
  extractStoredClinicalBilling} = require('@lib/billing/clinical-request-billing');
const procedureService = require('@services/procedure/procedure.service');

const mockUserId = 'user-urgent';
const mockIpAddress = '127.0.0.1';

describe('procedure.service billing (Clinical Urgent)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.$transaction.mockImplementation(async (fn) => fn(prisma));
    prisma.encounter.findFirst.mockResolvedValue({
      id: '550e8400-e29b-41d4-a716-446655440000',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1'});
    prisma.procedure.update.mockResolvedValue({});
  });

  it('posts Billing via persistProcedureBilling when billing payload is present', async () => {
    const created = {
      id: 'proc-urgent-1',
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      description: 'Urgent wound dressing',
      code: '10060'};
    procedureRepository.create.mockResolvedValue(created);

    const billing = {
      payment_status: 'PENDING',
      currency: 'USD',
      total_amount: 40,
      line_items: [
        {
          id: 'proc-catalog-1',
          label: 'Wound dressing',
          quantity: 1,
          unit_price: 40,
          line_total: 40}]};

    const result = await procedureService.createProcedure(
      {
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        code: '10060',
        description: 'Urgent wound dressing',
        billing},
      mockUserId,
      mockIpAddress
    );

    expect(result).toEqual(created);
    expect(persistProcedureBilling).toHaveBeenCalledTimes(1);
    expect(persistProcedureBilling).toHaveBeenCalledWith(
      prisma,
      expect.objectContaining({
        procedureId: 'proc-urgent-1',
        billing,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-1'})
    );
  });

  it('does not invent a parallel ledger when billing is omitted', async () => {
    procedureRepository.create.mockResolvedValue({
      id: 'proc-urgent-2',
      description: 'Suture'});

    await procedureService.createProcedure(
      {
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        description: 'Suture'},
      mockUserId,
      mockIpAddress
    );

    expect(persistProcedureBilling).not.toHaveBeenCalled();
  });

  it('idempotent replay shape: same billing payload reuses persistProcedureBilling once per create', async () => {
    procedureRepository.create.mockResolvedValue({
      id: 'proc-urgent-3',
      description: 'Injection'});
    const billing = {
      payment_status: 'PENDING',
      currency: 'USD',
      total_amount: 15,
      line_items: [{ id: 'a', label: 'Injection', quantity: 1, unit_price: 15 }]};

    await procedureService.createProcedure(
      {
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        description: 'Injection',
        billing},
      mockUserId,
      mockIpAddress
    );
    await procedureService.createProcedure(
      {
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        description: 'Injection',
        billing},
      mockUserId,
      mockIpAddress
    );

    expect(persistProcedureBilling).toHaveBeenCalledTimes(2);
    expect(persistProcedureBilling.mock.calls[0][1].billing).toEqual(billing);
    expect(persistProcedureBilling.mock.calls[1][1].billing).toEqual(billing);
  });

  it('delete reverses clinical-request billing when snapshot exists', async () => {
    const before = {
      id: 'proc-urgent-4',
      billing_snapshot: { invoice_id: 'inv-9', payment_status: 'PENDING' }};
    procedureRepository.findById.mockResolvedValue(before);
    extractStoredClinicalBilling.mockReturnValue(before.billing_snapshot);
    procedureRepository.softDelete.mockResolvedValue(before);

    await procedureService.deleteProcedure(
      'proc-urgent-4',
      mockUserId,
      mockIpAddress
    );

    expect(reverseClinicalRequestBilling).toHaveBeenCalled();
    expect(procedureRepository.softDelete).toHaveBeenCalledWith('proc-urgent-4');
  });

  it('unauthorized collect path is not owned by procedure service', () => {
    expect(procedureService.receivePayment).toBeUndefined();
    expect(procedureService.adjustInvoice).toBeUndefined();
  });
});
