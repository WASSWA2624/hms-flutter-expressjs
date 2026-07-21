jest.mock('@prisma/client', () => ({
  patient: { findFirst: jest.fn() },
  encounter: { count: jest.fn(), findMany: jest.fn() },
  vital_sign: { count: jest.fn(), findMany: jest.fn() },
  clinical_note: { count: jest.fn() },
  diagnosis: { count: jest.fn() },
  lab_result: { count: jest.fn(), findMany: jest.fn() },
  radiology_result: { count: jest.fn(), findMany: jest.fn() },
  procedure: { count: jest.fn() },
  pharmacy_order: { count: jest.fn() },
  invoice: { count: jest.fn(), findMany: jest.fn() },
  appointment: { count: jest.fn() },
  admission: { count: jest.fn() },
  patient_allergy: { count: jest.fn() },
  patient_medical_history: { count: jest.fn() },
  patient_identifier: { count: jest.fn() },
  patient_contact: { count: jest.fn() },
  patient_guardian: { count: jest.fn() },
  patient_document: { count: jest.fn() },
  consent: { count: jest.fn() },
  phi_access_log: { create: jest.fn() }}));

jest.mock('@repositories/patient-report/patient-report.repository', () => ({
  create: jest.fn(),
  findById: jest.fn(),
  update: jest.fn(),
  findMany: jest.fn(),
  count: jest.fn()}));

jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined)}));

jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn()}));

jest.mock('@lib/reports/files', () => ({
  generateReportFile: jest.fn()}));

jest.mock('@lib/storage', () => ({
  createStorageService: jest.fn(() => ({
    upload: jest.fn().mockResolvedValue({ path: 'patient-reports/t/file.pdf' }),
    download: jest.fn().mockResolvedValue(Buffer.from('pdf'))}))}));

jest.mock('@lib/telemetry/metrics', () => ({
  recordBackgroundJob: jest.fn()}));

jest.mock('@middlewares/auth.middleware', () => ({
  getUserPermissions: jest.fn()}));

jest.mock('@lib/logging', () => ({
  logger: { warn: jest.fn(), info: jest.fn(), error: jest.fn() }}));

const prisma = require('@prisma/client');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { getUserPermissions } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const patientReportService = require('@services/patient-report/patient-report.service');

describe('patient-report.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    getUserPermissions.mockReturnValue([
      PERMISSIONS.PATIENT_READ,
      PERMISSIONS.LAB_READ,
      PERMISSIONS.CLINICAL_READ]);
    resolveModelIdByIdentifier.mockResolvedValue('patient-internal-1');
    prisma.patient.findFirst.mockResolvedValue({
      id: 'patient-internal-1',
      human_friendly_id: 'PAT-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      first_name: 'Ada',
      last_name: 'Lovelace'});
    prisma.phi_access_log.create.mockResolvedValue({
      id: 'phi-1',
      accessed_at: new Date()});
    prisma.encounter.count.mockResolvedValue(2);
    prisma.vital_sign.count.mockResolvedValue(0);
    prisma.clinical_note.count.mockResolvedValue(0);
    prisma.diagnosis.count.mockResolvedValue(0);
    prisma.lab_result.count.mockResolvedValue(4);
    prisma.radiology_result.count.mockResolvedValue(0);
    prisma.procedure.count.mockResolvedValue(0);
    prisma.pharmacy_order.count.mockResolvedValue(0);
    prisma.invoice.count.mockResolvedValue(0);
    prisma.appointment.count.mockResolvedValue(1);
    prisma.admission.count.mockResolvedValue(0);
    prisma.patient_allergy.count.mockResolvedValue(0);
    prisma.patient_medical_history.count.mockResolvedValue(0);
    prisma.patient_identifier.count.mockResolvedValue(1);
    prisma.patient_contact.count.mockResolvedValue(0);
    prisma.patient_guardian.count.mockResolvedValue(0);
    prisma.patient_document.count.mockResolvedValue(0);
    prisma.consent.count.mockResolvedValue(0);
  });

  test('listSections marks empty sections disabled and audits access', async () => {
    const result = await patientReportService.listSections(
      { patient_id: 'PAT-1' },
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        user_id: 'user-1',
        permissions: [
          PERMISSIONS.PATIENT_READ,
          PERMISSIONS.LAB_READ,
          PERMISSIONS.CLINICAL_READ]}
    );

    const vitals = result.sections.find((entry) => entry.id === 'vitals');
    const labs = result.sections.find((entry) => entry.id === 'laboratory_results');
    const billing = result.sections.find((entry) => entry.id === 'billing_information');

    expect(vitals.enabled).toBe(false);
    expect(vitals.selected_by_default).toBe(false);
    expect(labs.enabled).toBe(true);
    expect(labs.count).toBe(4);
    expect(billing).toBeUndefined();
    expect(prisma.phi_access_log.create).toHaveBeenCalled();
  });

  test('createJob rejects unauthorized sections', async () => {
    await expect(
      patientReportService.createJob(
        {
          patient_id: 'PAT-1',
          sections: ['billing_information']},
        {
          tenant_id: 'tenant-1',
          user_id: 'user-1',
          permissions: [PERMISSIONS.PATIENT_READ]}
      )
    ).rejects.toMatchObject({
      statusCode: 403});
  });
});
