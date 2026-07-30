/**
 * Insurance Setup (Claims) billing-sections scan.
 *
 * Catalog creates from `/claims?section=insurance-setup` must stay NOT_BILLED:
 * they must not call clinical-request-billing upsert/receive/adjust. Price
 * resolve returns unit prices / coverage splits without writing ledger rows.
 */

jest.mock('@repositories/insurance-company/insurance-company.repository');
jest.mock('@repositories/coverage-plan/coverage-plan.repository');
jest.mock('@repositories/scheme-offer/scheme-offer.repository');
jest.mock('@repositories/patient-insurance-enrollment/patient-insurance-enrollment.repository');
jest.mock('@repositories/price-book-entry/price-book-entry.repository');
jest.mock('@repositories/insurer-integration/insurer-integration.repository');
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn()}));
jest.mock('@lib/billing/price-resolver', () => ({
  resolveUnitPrices: jest.fn()}));
jest.mock('@lib/billing/coverage-split', () => ({
  applyCoverageSplitToLineItems: jest.fn((items) => items),
  summarizeCoverageShares: jest.fn(() => ({
    patient_share_total: '20.00',
    insurer_share_total: '80.00'}))}));
jest.mock('@lib/billing/identifiers', () => ({
  sanitizeIdentifier: (value) => (typeof value === 'string' ? value.trim() : ''),
  resolvePublicIdentifier: (...values) => {
    for (const value of values) {
      const normalized =
        typeof value === 'string'
          ? value.trim()
          : value == null
            ? ''
            : String(value).trim();
      if (normalized) return normalized;
    }
    return null;
  },
  resolveIdentifierForFilter: async ({ value }) => value,
  resolveIdentifierForPayload: async ({ value, nullable = false }) => {
    if (value === undefined) return undefined;
    if (value === null && nullable) return null;
    return value;
  },
  resolveEntityId: async ({ identifier }) => identifier}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({})}));
jest.mock('@prisma/client', () => ({
  insurer_integration: { findMany: jest.fn() },
  coverage_plan: { findFirst: jest.fn() }}));

const insuranceCompanyRepository = require('@repositories/insurance-company/insurance-company.repository');
const coveragePlanRepository = require('@repositories/coverage-plan/coverage-plan.repository');
const schemeOfferRepository = require('@repositories/scheme-offer/scheme-offer.repository');
const patientInsuranceEnrollmentRepository = require('@repositories/patient-insurance-enrollment/patient-insurance-enrollment.repository');
const priceBookEntryRepository = require('@repositories/price-book-entry/price-book-entry.repository');
const insurerIntegrationRepository = require('@repositories/insurer-integration/insurer-integration.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const { resolveUnitPrices } = require('@lib/billing/price-resolver');
const {
  applyCoverageSplitToLineItems} = require('@lib/billing/coverage-split');
const { createAuditLog } = require('@lib/audit');
const prisma = require('@prisma/client');

const {
  createInsuranceCompany} = require('@services/insurance-company/insurance-company.service');
const {
  createCoveragePlan} = require('@services/coverage-plan/coverage-plan.service');
const {
  createSchemeOffer} = require('@services/scheme-offer/scheme-offer.service');
const {
  createPatientInsuranceEnrollment} = require('@services/patient-insurance-enrollment/patient-insurance-enrollment.service');
const {
  createPriceBookEntry,
  resolvePriceBookEntries} = require('@services/price-book-entry/price-book-entry.service');
const {
  createInsurerIntegration} = require('@services/insurer-integration/insurer-integration.service');

const assertNoPatientLedgerTouch = () => {
  expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
};

describe('Insurance Setup catalog billing-sections scan', () => {
  const userId = 'user-123';
  const ip = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('createInsuranceCompany does not touch patient billing ledger', async () => {
    const created = {
      id: 'co-1',
      human_friendly_id: 'INS0001',
      tenant_id: 'tenant-1',
      name: 'Acme',
      code: 'ACME'};
    insuranceCompanyRepository.create.mockResolvedValue(created);
    insuranceCompanyRepository.findById.mockResolvedValue(created);

    const result = await createInsuranceCompany(
      { tenant_id: 'tenant-1', name: 'Acme', code: 'ACME', is_active: true },
      userId,
      ip
    );

    expect(result).toEqual(
      expect.objectContaining({
        display_id: 'INS0001',
        name: 'Acme'})
    );
    expect(insuranceCompanyRepository.create).toHaveBeenCalledTimes(1);
    assertNoPatientLedgerTouch();
  });

  it('createCoveragePlan does not touch patient billing ledger', async () => {
    const created = {
      id: 'plan-1',
      human_friendly_id: 'PLN0001',
      tenant_id: 'tenant-1',
      name: 'Gold',
      coverage_percentage: 80};
    coveragePlanRepository.create.mockResolvedValue(created);
    coveragePlanRepository.findById.mockResolvedValue(created);

    await createCoveragePlan(
      {
        tenant_id: 'tenant-1',
        insurance_company_id: 'co-1',
        name: 'Gold',
        coverage_percentage: 80,
        status: 'ACTIVE'},
      userId,
      ip
    );

    expect(coveragePlanRepository.create).toHaveBeenCalledTimes(1);
    assertNoPatientLedgerTouch();
  });

  it('createSchemeOffer does not touch patient billing ledger', async () => {
    const created = {
      id: 'offer-1',
      human_friendly_id: 'OFF0001',
      tenant_id: 'tenant-1',
      coverage_plan_id: 'plan-1',
      catalog_item_id: 'LAB-1',
      unit_price: 100};
    schemeOfferRepository.create.mockResolvedValue(created);
    schemeOfferRepository.findById.mockResolvedValue(created);

    await createSchemeOffer(
      {
        tenant_id: 'tenant-1',
        coverage_plan_id: 'plan-1',
        catalog_type: 'LAB_TEST',
        catalog_item_id: 'LAB-1',
        unit_price: 100,
        is_active: true},
      userId,
      ip
    );

    expect(schemeOfferRepository.create).toHaveBeenCalledTimes(1);
    assertNoPatientLedgerTouch();
  });

  it('createPatientInsuranceEnrollment stays PENDING without ledger post', async () => {
    const created = {
      id: 'enr-1',
      human_friendly_id: 'ENR0001',
      tenant_id: 'tenant-1',
      patient_id: 'pat-1',
      coverage_plan_id: 'plan-1',
      member_id: 'M-1',
      status: 'PENDING'};
    patientInsuranceEnrollmentRepository.create.mockResolvedValue(created);
    patientInsuranceEnrollmentRepository.findById.mockResolvedValue(created);

    const result = await createPatientInsuranceEnrollment(
      {
        tenant_id: 'tenant-1',
        facility_id: 'fac-1',
        patient_id: 'pat-1',
        coverage_plan_id: 'plan-1',
        member_id: 'M-1',
        status: 'PENDING',
        is_primary: true},
      userId,
      ip
    );

    expect(result).toEqual(expect.objectContaining({ status: 'PENDING' }));
    expect(patientInsuranceEnrollmentRepository.create).toHaveBeenCalledTimes(1);
    expect(patientInsuranceEnrollmentRepository.update).not.toHaveBeenCalled();
    assertNoPatientLedgerTouch();
  });

  it('createPriceBookEntry does not create invoice/payment rows', async () => {
    const created = {
      id: 'pbe-1',
      human_friendly_id: 'PBE0001',
      tenant_id: 'tenant-1',
      catalog_item_id: 'LAB-1',
      unit_price: 50,
      payment_mode: 'SELF_PAY'};
    priceBookEntryRepository.create.mockResolvedValue(created);
    priceBookEntryRepository.findById.mockResolvedValue(created);

    await createPriceBookEntry(
      {
        tenant_id: 'tenant-1',
        facility_id: 'fac-1',
        catalog_type: 'LAB_TEST',
        catalog_item_id: 'LAB-1',
        payment_mode: 'SELF_PAY',
        billing_entity: 'FACILITY',
        unit_price: 50,
        currency: 'UGX',
        is_active: true},
      userId,
      ip
    );

    expect(priceBookEntryRepository.create).toHaveBeenCalledTimes(1);
    assertNoPatientLedgerTouch();
  });

  it('createInsurerIntegration does not touch patient billing ledger', async () => {
    const created = {
      id: 'int-1',
      human_friendly_id: 'INT0001',
      tenant_id: 'tenant-1',
      name: 'Stub adapter',
      adapter_type: 'STUB',
      is_enabled: true};
    insurerIntegrationRepository.create.mockResolvedValue(created);
    insurerIntegrationRepository.findById.mockResolvedValue(created);

    await createInsurerIntegration(
      {
        tenant_id: 'tenant-1',
        facility_id: 'fac-1',
        insurance_company_id: 'co-1',
        name: 'Stub adapter',
        adapter_type: 'STUB',
        is_enabled: true},
      userId,
      ip
    );

    expect(insurerIntegrationRepository.create).toHaveBeenCalledTimes(1);
    assertNoPatientLedgerTouch();
  });

  it('resolvePriceBookEntries returns splits without writing ledger (parity)', async () => {
    resolveUnitPrices.mockResolvedValue([
      {
        unitPrice: 100,
        currency: 'UGX',
        source: 'PRICE_BOOK'}]);
    prisma.coverage_plan.findFirst.mockResolvedValue({
      id: 'plan-1',
      coverage_percentage: 80,
      name: 'Gold',
      default_copay_type: 'NONE',
      default_copay_value: null,
      insurance_company_id: 'co-1'});
    applyCoverageSplitToLineItems.mockImplementation((items) =>
      items.map((item) => ({
        ...item,
        patient_share: '20.00',
        insurer_share: '80.00'}))
    );

    const result = await resolvePriceBookEntries({
      tenant_id: 'tenant-1',
      facility_id: 'fac-1',
      payment_mode: 'INSURANCE',
      coverage_plan_id: 'plan-1',
      insurance_company_id: 'co-1',
      items: [{ catalog_type: 'LAB_TEST', catalog_item_id: 'LAB-1', quantity: 1 }]});

    expect(resolveUnitPrices).toHaveBeenCalled();
    expect(applyCoverageSplitToLineItems).toHaveBeenCalled();
    expect(result).toEqual(
      expect.objectContaining({
        items: expect.any(Array),
        summary: expect.any(Object)})
    );
    expect(priceBookEntryRepository.create).not.toHaveBeenCalled();
    assertNoPatientLedgerTouch();
  });

  it('idempotent replay of catalog create does not double-post Billing', async () => {
    const created = {
      id: 'co-1',
      human_friendly_id: 'INS0001',
      tenant_id: 'tenant-1',
      name: 'Acme',
      code: 'ACME'};
    insuranceCompanyRepository.create.mockResolvedValue(created);
    insuranceCompanyRepository.findById.mockResolvedValue(created);

    const payload = {
      tenant_id: 'tenant-1',
      name: 'Acme',
      code: 'ACME',
      is_active: true};

    await createInsuranceCompany(payload, userId, ip);
    await createInsuranceCompany(payload, userId, ip);

    expect(insuranceCompanyRepository.create).toHaveBeenCalledTimes(2);
    assertNoPatientLedgerTouch();
  });
});
