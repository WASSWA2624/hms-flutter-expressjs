/**
 * Nursing Handover pending — handover.service stage actions are NOT_BILLED.
 * Create/accept must not call clinical-request-billing or invent a cash ledger.
 */

const mockPersistNursingServiceBilling = jest.fn();
const mockPersistAdmissionBilling = jest.fn();

jest.mock('@lib/billing/clinical-request-billing', () => ({
  persistNursingServiceBilling: (...args) =>
    mockPersistNursingServiceBilling(...args),
  persistAdmissionBilling: (...args) => mockPersistAdmissionBilling(...args),
  persistWardRoundBilling: jest.fn(),
  persistIcuStayBilling: jest.fn()}));

jest.mock('@repositories/handover/handover.repository', () => ({
  findMany: jest.fn(),
  findById: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  count: jest.fn()}));
jest.mock('@repositories/office-context/office-context.repository', () => ({
  findById: jest.fn(),
  findCurrent: jest.fn(),
  update: jest.fn()}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined)}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier)}));
jest.mock('@lib/billing/identifiers', () => ({
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value)}));
jest.mock('@lib/last-office/events', () => ({
  emitLastOfficeEvent: jest.fn(),
  LAST_OFFICE_EVENTS: {}}));
jest.mock('@lib/telemetry/metrics', () => ({
  recordWorkflowEvent: jest.fn()}));
jest.mock('@middlewares/auth.middleware', () => ({
  getUserPermissions: jest.fn(() => [])}));
jest.mock('@lib/last-office/shared', () => {
  const actual = jest.requireActual('@lib/last-office/shared');
  return {
    ...actual,
    resolveScopedIdentifiers: jest.fn(async ({ context }) => ({
      tenant_id: context.tenant_id || 'tenant-1',
      facility_id: context.facility_id || 'facility-1'})),
    resolveListScopedIdentifiers: jest.fn(async ({ context }) => ({
      tenant_id: context.tenant_id || 'tenant-1',
      facility_id: context.facility_id || 'facility-1'})),
    serializeHandover: jest.fn((record) => ({
      id: record.id,
      human_friendly_id: record.human_friendly_id,
      status: record.status,
      office_context_id: record.office_context_id,
      from_user_id: record.from_user_id,
      to_user_id: record.to_user_id}))};
});

const handoverRepository = require('@repositories/handover/handover.repository');
const officeContextRepository = require('@repositories/office-context/office-context.repository');
const { createAuditLog } = require('@lib/audit');
const handoverService = require('@services/handover/handover.service');

const now = new Date('2026-07-30T10:00:00.000Z');

const officeContext = {
  id: 'oc-1',
  human_friendly_id: 'OC-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  version: 1,
  status: 'OPEN',
  deleted_at: null};

describe('handover.service Nursing Handover pending billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    officeContextRepository.findById.mockResolvedValue(officeContext);
    officeContextRepository.update.mockResolvedValue(officeContext);
    handoverRepository.findMany.mockResolvedValue([]);
  });

  it('AC2: createHandover does not post Billing / clinical-request-billing', async () => {
    handoverRepository.create.mockResolvedValue({
      id: 'ho-1',
      human_friendly_id: 'HND-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      office_context_id: 'oc-1',
      from_user_id: 'user-from',
      to_user_id: 'user-to',
      status: 'PENDING',
      submitted_at: now,
      version: 1});

    const result = await handoverService.createHandover(
      {
        office_context_id: 'oc-1',
        to_user_id: 'user-to',
        from_user_id: 'user-from',
        signoff_notes: 'Night shift',
        items_json: { admission_id: 'adm-hand-1' }},
      { tenant_id: 'tenant-1', facility_id: 'facility-1', user_id: 'user-from' },
    );

    expect(result.id).toBe('ho-1');
    expect(handoverRepository.create).toHaveBeenCalled();
    expect(mockPersistNursingServiceBilling).not.toHaveBeenCalled();
    expect(mockPersistAdmissionBilling).not.toHaveBeenCalled();
  });

  it('AC2: acceptHandover does not post Billing / clinical-request-billing', async () => {
    const pending = {
      id: 'ho-1',
      human_friendly_id: 'HND-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      office_context_id: 'oc-1',
      from_user_id: 'user-from',
      to_user_id: 'user-to',
      status: 'PENDING',
      version: 1,
      deleted_at: null};
    handoverRepository.findById.mockResolvedValue(pending);
    handoverRepository.update.mockResolvedValue({
      ...pending,
      status: 'ACCEPTED',
      accepted_notes: 'Received',
      accepted_at: now,
      version: 2});
    officeContextRepository.findById.mockResolvedValue({
      ...officeContext,
      status: 'HANDOVER_PENDING'});

    await handoverService.acceptHandover(
      'ho-1',
      { accepted_notes: 'Received' },
      { tenant_id: 'tenant-1', facility_id: 'facility-1', user_id: 'user-to' },
    );

    expect(mockPersistNursingServiceBilling).not.toHaveBeenCalled();
    expect(mockPersistAdmissionBilling).not.toHaveBeenCalled();
    expect(handoverRepository.update).toHaveBeenCalled();
  });

  it('AC4/AC6: handover service exposes no cashier / charge APIs', () => {
    expect(handoverService.receivePayment).toBeUndefined();
    expect(handoverService.adjustInvoice).toBeUndefined();
    expect(handoverService.refundPayment).toBeUndefined();
    expect(handoverService.createInvoice).toBeUndefined();
    expect(handoverService.persistNursingServiceBilling).toBeUndefined();
  });
});
