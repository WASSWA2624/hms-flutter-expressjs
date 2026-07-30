jest.mock('@repositories/interop/interop.repository');
jest.mock('@lib/dicomweb/client', () => ({
  isConfigured: jest.fn(),
  searchStudies: jest.fn(),
}));
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));

const interopRepository = require('@repositories/interop/interop.repository');
const dicomWebClient = require('@lib/dicomweb/client');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { createAuditLog } = require('@lib/audit');
const interopService = require('@services/interop/interop.service');

/**
 * Billing & sections scan for Integrations Interop tab.
 * FHIR / HL7 / DICOM / migration handlers are readiness / exchange stubs and
 * must never post patient Billing ledger rows from this surface. When payloads
 * later create clinical orders or settlements they must call shared Billing
 * (clinical-request billing / receive-payment / adjustment) with idempotency.
 */
describe('interop service billing-sections scan (Interop tab)', () => {
  const context = {
    user_id: '123e4567-e89b-12d3-a456-426614174099',
    tenant_id: '123e4567-e89b-12d3-a456-426614174010',
    ip_address: '127.0.0.1',
  };

  const expectNoPatientBillingTouch = () => {
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  };

  beforeEach(() => {
    jest.clearAllMocks();
    interopRepository.buildFhirExportPayload.mockReturnValue({
      format: 'FHIR',
      resource: 'Patient',
      exported_at: '2026-07-01T08:00:00.000Z',
      total_records: 0,
      records: [],
    });
    interopRepository.buildFhirImportResult.mockReturnValue({
      format: 'FHIR',
      resource: 'Patient',
      imported_at: '2026-07-01T08:00:00.000Z',
      mode: 'merge',
      accepted_records: 1,
      rejected_records: 0,
    });
    interopRepository.buildHl7Result.mockReturnValue({
      accepted: true,
      received_at: '2026-07-01T08:00:00.000Z',
      ack_id: 'ACK-1001',
    });
    interopRepository.buildMigrationExportPayload.mockReturnValue({
      format: 'HMS_MIGRATION_BUNDLE',
      exported_at: '2026-07-01T08:00:00.000Z',
      version: '1.0.0',
      entities: [],
    });
    interopRepository.buildMigrationImportResult.mockReturnValue({
      imported: true,
      imported_at: '2026-07-01T08:00:00.000Z',
      mode: 'append',
    });
    dicomWebClient.isConfigured.mockReturnValue(false);
  });

  it('FHIR export stays NOT_BILLED (no patient ledger post)', async () => {
    const result = await interopService.exportFhirResource('Patient');

    expect(result).toEqual(
      expect.objectContaining({ format: 'FHIR', resource: 'Patient' })
    );
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('invoice_id');
    expect(result).not.toHaveProperty('amount_due');
    expectNoPatientBillingTouch();
  });

  it('FHIR import does not post Billing and audits ops metadata only', async () => {
    const result = await interopService.importFhirResource(
      'Patient',
      {
        records: [{ id: 'patient-1' }],
        mode: 'merge',
        source_system: 'EXTERNAL_EHR',
      },
      context
    );

    expect(result.accepted_records).toBe(1);
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'FHIR_IMPORT',
        entity: 'interop',
      })
    );
    expect(result).not.toHaveProperty('paid');
    expect(result).not.toHaveProperty('balance');
    expectNoPatientBillingTouch();
  });

  it('FHIR import replay is idempotent on billing bypass (no double charge)', async () => {
    const payload = {
      records: [{ id: 'patient-1' }],
      mode: 'merge',
      source_system: 'EXTERNAL_EHR',
    };

    await interopService.importFhirResource('Patient', payload, context);
    await interopService.importFhirResource('Patient', payload, context);

    expect(interopRepository.buildFhirImportResult).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expectNoPatientBillingTouch();
  });

  it('HL7 submit stays NOT_BILLED and never settles patient responsibility', async () => {
    const result = await interopService.submitHl7Message(
      { message: 'MSH|^~\\&|', source_system: 'LIS' },
      context
    );

    expect(result.accepted).toBe(true);
    expect(result.ack_id).toBe('ACK-1001');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('amount');
    expectNoPatientBillingTouch();
  });

  it('HL7 submit replay does not double-post Billing', async () => {
    const payload = { message: 'MSH|^~\\&|', source_system: 'LIS' };

    await interopService.submitHl7Message(payload, context);
    await interopService.submitHl7Message(payload, context);

    expect(interopRepository.buildHl7Result).toHaveBeenCalledTimes(2);
    expectNoPatientBillingTouch();
  });

  it('DICOM study link stays NOT_BILLED (PACS ops, not cashier)', async () => {
    const result = await interopService.linkDicomStudy(
      'study-1',
      { study_uid: '1.2.3', pacs_url: 'https://pacs.example' },
      context
    );

    expect(result.study_id).toBe('study-1');
    expect(result.status).toBe('FAILED');
    expect(result).not.toHaveProperty('invoice_id');
    expect(result).not.toHaveProperty('payment_method');
    expectNoPatientBillingTouch();
  });

  it('migration export / import stay NOT_BILLED internal ops', async () => {
    const exported = await interopService.exportMigrations();
    const imported = await interopService.importMigrations(
      { mode: 'append', source_system: 'LEGACY' },
      context
    );

    expect(exported.format).toBe('HMS_MIGRATION_BUNDLE');
    expect(imported.imported).toBe(true);
    expect(exported).not.toHaveProperty('balance');
    expect(imported).not.toHaveProperty('paid');
    expectNoPatientBillingTouch();
  });

  it('status parity: interop results expose ops fields only (no ledger balances)', async () => {
    const importResult = await interopService.importFhirResource(
      'Encounter',
      { records: [], mode: 'merge' },
      context
    );
    const hl7Result = await interopService.submitHl7Message(
      { message: 'MSH' },
      context
    );

    for (const item of [importResult, hl7Result]) {
      expect(item).not.toHaveProperty('payment_status');
      expect(item).not.toHaveProperty('balance');
      expect(item).not.toHaveProperty('amount_due');
      expect(item).not.toHaveProperty('invoice_id');
      expect(item).not.toHaveProperty('paid');
    }
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('unauthorized financial mutation paths are absent — no receive/adjust APIs on interop service', () => {
    expect(interopService.receivePayment).toBeUndefined();
    expect(interopService.adjustInvoice).toBeUndefined();
    expect(interopService.refundPayment).toBeUndefined();
    expect(interopService.issueInvoice).toBeUndefined();
    expect(typeof interopService.importFhirResource).toBe('function');
    expect(typeof interopService.submitHl7Message).toBe('function');
  });
});
