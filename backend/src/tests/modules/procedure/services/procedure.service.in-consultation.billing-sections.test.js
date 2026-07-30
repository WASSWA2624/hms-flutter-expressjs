/**
 * Procedure service billing for Clinical In consultation flows that call
 * POST /procedures with request-time billing (richest nested action bar).
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
      invoice_id: 'inv-consult-1'}),
    reverseClinicalRequestBilling: jest.fn().mockResolvedValue(null),
    extractStoredClinicalBilling: jest.fn().mockReturnValue(null)};
});

const prisma = require('@prisma/client');
const procedureRepository = require('@repositories/procedure/procedure.repository');
const { createAuditLog } = require('@lib/audit');
const {
  persistProcedureBilling} = require('@lib/billing/clinical-request-billing');
const procedureService = require('@services/procedure/procedure.service');

const mockUserId = 'user-consult';
const mockIpAddress = '127.0.0.1';

describe('procedure.service billing (Clinical In consultation)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.$transaction.mockImplementation(async (fn) => fn(prisma));
    prisma.encounter.findFirst.mockResolvedValue({
      id: '550e8400-e29b-41d4-a716-446655440099',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1'});
    prisma.procedure.update.mockResolvedValue({});
  });

  it('posts Billing via persistProcedureBilling when billing payload is present', async () => {
    const created = {
      id: 'proc-consult-1',
      encounter_id: '550e8400-e29b-41d4-a716-446655440099',
      description: 'Wound dressing',
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
        encounter_id: '550e8400-e29b-41d4-a716-446655440099',
        code: '10060',
        description: 'Wound dressing',
        billing},
      mockUserId,
      mockIpAddress
    );

    expect(result).toEqual(created);
    expect(persistProcedureBilling).toHaveBeenCalledTimes(1);
    expect(persistProcedureBilling).toHaveBeenCalledWith(
      prisma,
      expect.objectContaining({
        procedureId: 'proc-consult-1',
        billing,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-1'})
    );
  });

  it('does not invent a parallel ledger when billing is omitted', async () => {
    procedureRepository.create.mockResolvedValue({
      id: 'proc-consult-2',
      description: 'Suture'});

    await procedureService.createProcedure(
      {
        encounter_id: '550e8400-e29b-41d4-a716-446655440099',
        description: 'Suture'},
      mockUserId,
      mockIpAddress
    );

    expect(persistProcedureBilling).not.toHaveBeenCalled();
  });

  it('unauthorized collect path is not owned by procedure service', () => {
    expect(procedureService.receivePayment).toBeUndefined();
    expect(procedureService.adjustInvoice).toBeUndefined();
  });
});
