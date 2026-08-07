const createModelMeta = (fields) => ({
  fieldByName: new Map(fields.map((field) => [field.name, field]))});

const {
  DEMO_ROLE_CODES,
  DEMO_TENANT} = require('../../../scripts/seeders/seed-catalog');

const buildUserRoleRows = (users = DEMO_TENANT.users) =>
  users.flatMap((entry) => [
    {
      role: { name: entry.role },
      user: { email: entry.email }},
    ...((entry.extra_roles || []).map((role) => ({
      role: { name: role },
      user: { email: entry.email }})))]);

const mockPrisma = {
  tenant: { findMany: jest.fn() },
  facility: { findMany: jest.fn() },
  user: { count: jest.fn() },
  role: { findMany: jest.fn() },
  user_role: { findMany: jest.fn(), count: jest.fn() },
  subscription_plan: { findMany: jest.fn() },
  subscription: { findMany: jest.fn() },
  module_subscription: { findMany: jest.fn() },
  subscription_invoice: { findMany: jest.fn() },
  license: { findMany: jest.fn() },
  patient: { count: jest.fn() },
  appointment: { count: jest.fn(), groupBy: jest.fn() },
  encounter: { count: jest.fn(), groupBy: jest.fn() },
  admission: { count: jest.fn() },
  lab_result: { count: jest.fn() },
  radiology_result: { count: jest.fn() },
  pharmacy_order: { count: jest.fn(), groupBy: jest.fn() },
  pharmacy_dispense_attestation: { count: jest.fn() },
  dispense_log: { count: jest.fn(), findMany: jest.fn() },
  inventory_stock: { findMany: jest.fn() },
  payment: { count: jest.fn() },
  invoice: { count: jest.fn(), groupBy: jest.fn() },
  lab_order: { count: jest.fn(), groupBy: jest.fn() },
  stock_movement: { count: jest.fn() },
  stock_adjustment: { count: jest.fn() },
  purchase_request: { count: jest.fn() },
  purchase_order: { count: jest.fn() },
  goods_receipt: { count: jest.fn() },
  supplier: { count: jest.fn() },
  drug: { count: jest.fn() },
  mortuary_case: { count: jest.fn(), groupBy: jest.fn() },
  conversation: { findMany: jest.fn() },
  notification: { findMany: jest.fn(), count: jest.fn() },
  notification_delivery: { findMany: jest.fn() },
  template: { findMany: jest.fn() },
  emergency_case: { count: jest.fn() },
  ambulance_trip: { count: jest.fn() },
  diagnosis: { count: jest.fn() },
  vital_sign: { count: jest.fn() },
  procedure: { count: jest.fn() },
  nursing_note: { count: jest.fn() },
  visit_queue: { count: jest.fn(), groupBy: jest.fn() },
  refund: { count: jest.fn() },
  billing_adjustment: { count: jest.fn() },
  insurance_claim: { count: jest.fn(), groupBy: jest.fn() },
  pre_authorization: { count: jest.fn() },
  triage_assessment: { count: jest.fn() },
  report_run: { count: jest.fn(), groupBy: jest.fn() },
  kpi_snapshot: { count: jest.fn() },
  analytics_event: { count: jest.fn() },
  patient_report_job: { count: jest.fn() },
  shift: { count: jest.fn() },
  clinical_note: { count: jest.fn() },
  patient_allergy: { count: jest.fn() },
  care_plan: { count: jest.fn() },
  clinical_alert: { count: jest.fn() },
  theatre_case: { count: jest.fn() },
  patient_insurance_enrollment: { count: jest.fn() },
  price_book_entry: { count: jest.fn() },
  bed_assignment: { count: jest.fn() },
  imaging_study: { count: jest.fn() },
  referral: { count: jest.fn() },
  follow_up: { count: jest.fn() },
  report_schedule: { count: jest.fn() },
  bed: { count: jest.fn() },
  message: { count: jest.fn() },
  equipment_maintenance_plan: { count: jest.fn() },
  equipment_work_order: { count: jest.fn() },
  equipment_calibration_log: { count: jest.fn() },
  equipment_safety_test_log: { count: jest.fn() },
  equipment_downtime_log: { count: jest.fn() },
  equipment_spare_part: { count: jest.fn() },
  equipment_incident_report: { count: jest.fn() },
  equipment_recall_notice: { count: jest.fn() },
  equipment_utilization_snapshot: { count: jest.fn() },
  equipment_disposal_transfer: { count: jest.fn() },
  audit_log: { count: jest.fn() },
  phi_access_log: { count: jest.fn() },
  data_processing_log: { count: jest.fn() },
  breach_notification: { count: jest.fn() },
  system_change_log: { count: jest.fn() },
  abac_policy: { count: jest.fn() },
  break_glass_access: { findMany: jest.fn() },
  break_glass_review: { count: jest.fn() },
  office_context: { findMany: jest.fn() },
  shift_close: { findMany: jest.fn() },
  day_close: { findMany: jest.fn() },
  handover: { findMany: jest.fn() },
  custody_snapshot: { findMany: jest.fn() },
  closeout_pack: { findMany: jest.fn() },
  integration: { count: jest.fn() },
  webhook_subscription: { count: jest.fn() },
  address: { count: jest.fn() },
  contact: { count: jest.fn() },
  $disconnect: jest.fn()};

jest.mock('../../../scripts/seeders/seed-runtime', () => ({
  prisma: mockPrisma,
  DEFAULT_RANDOM_SEED: 20260302,
  parseSchemaMetadata: jest.fn(() => ({
    modelsByName: new Map([
      ['tenant', createModelMeta([{ name: 'deleted_at' }])],
      ['facility', createModelMeta([{ name: 'deleted_at' }, { name: 'tenant_id', isOptional: false }])],
      ['address', createModelMeta([
        { name: 'tenant_id', isOptional: false },
        { name: 'facility_id', isOptional: true },
        { name: 'deleted_at' }])],
      ['contact', createModelMeta([
        { name: 'tenant_id', isOptional: false },
        { name: 'facility_id', isOptional: true },
        { name: 'deleted_at' }])]])}))}));

describe('verify-demo-data', () => {
  beforeEach(() => {
    jest.resetModules();
    jest.clearAllMocks();
    process.env.SEED_RECORD_COUNT = '0';

    mockPrisma.tenant.findMany.mockResolvedValue([
      { id: 'tenant-demo', slug: 'democare-general-hospital', name: 'DemoCare General Hospital' }]);
    mockPrisma.facility.findMany.mockResolvedValue([
      { id: 'facility-demo', tenant_id: 'tenant-demo', name: 'DemoCare General Hospital' },
      { id: 'facility-annex', tenant_id: 'tenant-demo', name: 'DemoCare Annex Pharmacy' }]);
    mockPrisma.user.count.mockResolvedValue(DEMO_TENANT.users.length);
    mockPrisma.role.findMany.mockResolvedValue(DEMO_ROLE_CODES.map((name) => ({ name })));
    mockPrisma.user_role.findMany.mockResolvedValue(buildUserRoleRows());

    mockPrisma.subscription_plan.findMany.mockResolvedValue([
      {
        code: 'advanced',
        max_facilities: 50,
        extension_json: { commercial_terms: { setup_range_usd: [2500, 7500] } }},
      {
        code: 'basic',
        max_facilities: 1},
      {
        code: 'custom',
        max_facilities: null,
        extension_json: { commercial_terms: { annual_support_percent_range: [15, 25] } }},
      {
        code: 'developer',
        max_facilities: 1},
      {
        code: 'free',
        max_facilities: 1,
        extension_json: { usage_limits: { new_patients_per_day: 5 } }},
      {
        code: 'pro',
        max_facilities: 3,
        extension_json: { price_notes: { yearly: 890 } }}]);
    mockPrisma.subscription.findMany.mockResolvedValue([
      { id: 'sub-1', tenant_id: 'tenant-demo', change_status: 'NONE', plan_fit_status: 'HEALTHY', status: 'ACTIVE' }]);
    mockPrisma.module_subscription.findMany.mockResolvedValue([
      { is_active: true, module: { is_add_on: true }, subscription: { tenant_id: 'tenant-demo' } },
      { is_active: true, module: { is_add_on: false }, subscription: { tenant_id: 'tenant-demo' } }]);
    mockPrisma.subscription_invoice.findMany.mockResolvedValue([
      { invoice: { status: 'PAID' }, subscription: { tenant_id: 'tenant-demo' } }]);
    mockPrisma.license.findMany.mockResolvedValue([
      { status: 'ACTIVE', tenant_id: 'tenant-demo', expires_at: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000) }]);
    mockPrisma.patient.count.mockResolvedValue(5);
    mockPrisma.appointment.count.mockResolvedValue(1);
    mockPrisma.encounter.count.mockResolvedValue(5);
    mockPrisma.admission.count.mockResolvedValue(1);
    mockPrisma.lab_result.count.mockResolvedValue(3);
    mockPrisma.radiology_result.count.mockResolvedValue(1);
    mockPrisma.pharmacy_order.count.mockResolvedValue(2);
    mockPrisma.dispense_log.count.mockResolvedValue(2);
    mockPrisma.dispense_log.findMany.mockResolvedValue([]);
    mockPrisma.inventory_stock.findMany.mockResolvedValue([
      { quantity: 5, reorder_level: 40 },
      { quantity: 180, reorder_level: 40 },
    ]);
    mockPrisma.inventory_stock.count = jest.fn().mockResolvedValue(1);
    mockPrisma.drug_batch = { count: jest.fn().mockResolvedValue(1) };
    mockPrisma.payment.count.mockResolvedValue(2);
    mockPrisma.invoice = { count: jest.fn().mockResolvedValue(2), groupBy: jest.fn().mockResolvedValue([]) };
    mockPrisma.lab_order = { count: jest.fn().mockResolvedValue(2), groupBy: jest.fn().mockResolvedValue([]) };
    mockPrisma.notification.count = jest.fn().mockResolvedValue(3);
    mockPrisma.stock_movement = { count: jest.fn().mockResolvedValue(1) };
    mockPrisma.stock_adjustment = { count: jest.fn().mockResolvedValue(1) };
    mockPrisma.purchase_request = { count: jest.fn().mockResolvedValue(1) };
    mockPrisma.mortuary_case = { count: jest.fn().mockResolvedValue(3), groupBy: jest.fn().mockResolvedValue([]) };
    mockPrisma.emergency_case.count.mockResolvedValue(1);
    mockPrisma.ambulance_trip.count.mockResolvedValue(1);
    mockPrisma.conversation.findMany.mockResolvedValue([
      {
        conversation_type: 'DIRECT',
        status: 'OPEN',
        is_sensitive: false,
        participants: [{ last_read_at: new Date('2026-03-01T09:00:00Z') }],
        messages: [{ attachments: [{ attachment_kind: 'IMAGE' }, { attachment_kind: 'DOCUMENT' }] }],
        visibility_roles: []},
      {
        conversation_type: 'GROUP',
        status: 'ARCHIVED',
        is_sensitive: false,
        participants: [{ archived_at: new Date('2026-03-01T12:00:00Z') }],
        messages: [],
        visibility_roles: []},
      {
        conversation_type: 'GROUP',
        status: 'OPEN',
        is_sensitive: true,
        participants: [{ last_read_at: new Date('2026-03-01T12:00:00Z') }],
        messages: [],
        visibility_roles: [{ role_code: 'BIOMED' }]}]);
    mockPrisma.notification.findMany.mockResolvedValue([
      { read_at: null, context_type: 'conversation', context_public_id: 'CONV-1', deliveries: [] },
      { read_at: new Date('2026-03-01T11:00:00Z'), context_type: 'invoice', context_public_id: 'INV-1', deliveries: [] }]);
    mockPrisma.notification_delivery.findMany.mockResolvedValue([
      { channel: 'IN_APP', status: 'DELIVERED', retryable: false },
      { channel: 'SMS', status: 'FAILED', retryable: true },
      { channel: 'SMS', status: 'SENT', retryable: false }]);
    mockPrisma.template.findMany.mockResolvedValue([
      { variables: [{ key: 'patient_name' }] },
      { variables: [{ key: 'device_name' }] }]);
    mockPrisma.abac_policy.count.mockResolvedValue(2);
    mockPrisma.break_glass_access.findMany.mockResolvedValue([
      { status: 'REQUESTED', review_status: 'PENDING' },
      { status: 'ACTIVE', review_status: 'APPROVED' }]);
    mockPrisma.break_glass_review.count.mockResolvedValue(1);
    mockPrisma.office_context.findMany.mockResolvedValue([{ status: 'OPEN' }]);
    mockPrisma.shift_close.findMany.mockResolvedValue([{ status: 'APPROVED' }]);
    mockPrisma.day_close.findMany.mockResolvedValue([{ status: 'APPROVED' }]);
    mockPrisma.handover.findMany.mockResolvedValue([{ status: 'ACCEPTED' }]);
    mockPrisma.custody_snapshot.findMany.mockResolvedValue([{ status: 'FINALIZED' }]);
    mockPrisma.closeout_pack.findMany.mockResolvedValue([{ status: 'READY' }]);

    for (const key of [
      'equipment_maintenance_plan',
      'equipment_work_order',
      'equipment_calibration_log',
      'equipment_safety_test_log',
      'equipment_downtime_log',
      'equipment_spare_part',
      'equipment_incident_report',
      'equipment_recall_notice',
      'equipment_utilization_snapshot',
      'equipment_disposal_transfer',
      'audit_log',
      'phi_access_log',
      'data_processing_log',
      'breach_notification',
      'system_change_log',
      'integration',
      'webhook_subscription',
      'address',
      'contact',
      'diagnosis',
      'vital_sign',
      'procedure',
      'nursing_note',
      'visit_queue',
      'refund',
      'billing_adjustment',
      'insurance_claim',
      'pre_authorization',
      'triage_assessment',
      'report_run',
      'kpi_snapshot',
      'analytics_event',
      'patient_report_job',
      'shift',
      'message',
      'clinical_note',
      'patient_allergy',
      'care_plan',
      'clinical_alert',
      'theatre_case',
      'patient_insurance_enrollment',
      'price_book_entry',
      'bed_assignment',
      'imaging_study',
      'referral',
      'follow_up',
      'report_schedule',
      'bed']) {
      mockPrisma[key].count.mockResolvedValue(1);
    }

    mockPrisma.address.count.mockResolvedValue(0);
    mockPrisma.contact.count.mockResolvedValue(0);
  });

  it('passes when the single-tenant demo invariants are present', async () => {
    const { verifyDemoData } = require('../../../scripts/verify-demo-data');
    const result = await verifyDemoData();

    expect(result.errors).toEqual([]);
    expect(result.ok).toBe(true);
  });

  it('fails when ownership data leaks outside the seeded facility', async () => {
    mockPrisma.contact.count.mockImplementation(async ({ where } = {}) =>
      where?.facility_id ? 1 : 0
    );

    const { verifyDemoData } = require('../../../scripts/verify-demo-data');
    const result = await verifyDemoData();

    expect(result.ok).toBe(false);
    expect(result.errors).toContain('Found facility ownership mismatches: contact(1).');
  });

  it('fails when a seeded role email does not match the canonical login', async () => {
    mockPrisma.user_role.findMany.mockResolvedValue(
      buildUserRoleRows(DEMO_TENANT.users.map((entry) => ({
        ...entry,
        email: entry.role === 'SUPER_ADMIN' ? 'superadmin@legacy.test' : entry.email})))
    );

    const { verifyDemoData } = require('../../../scripts/verify-demo-data');
    const result = await verifyDemoData();

    expect(result.ok).toBe(false);
    expect(result.errors).toContain(
      'Expected role SUPER_ADMIN to use email super.admin@hosspi.com but found superadmin@legacy.test.'
    );
  });

  it('enforces volume floors when SEED_RECORD_COUNT enables volume mode', async () => {
    process.env.SEED_RECORD_COUNT = '100';
    mockPrisma.patient.count.mockResolvedValue(20);
    mockPrisma.appointment.count.mockResolvedValue(20);
    mockPrisma.encounter.count.mockResolvedValue(20);
    mockPrisma.appointment.groupBy = jest.fn().mockResolvedValue([]);
    mockPrisma.encounter.groupBy = jest.fn().mockResolvedValue([]);
    mockPrisma.lab_order.groupBy = jest.fn().mockResolvedValue([]);
    mockPrisma.pharmacy_order = {
      count: jest.fn().mockResolvedValue(20),
      groupBy: jest.fn().mockResolvedValue([]),
    };
    mockPrisma.invoice.groupBy = jest.fn().mockResolvedValue([]);
    mockPrisma.mortuary_case.groupBy = jest.fn().mockResolvedValue([]);
    mockPrisma.pharmacy_dispense_attestation = { count: jest.fn().mockResolvedValue(20) };
    mockPrisma.user_role.count = jest.fn().mockResolvedValue(2);
    mockPrisma.drug = { count: jest.fn().mockResolvedValue(20) };
    mockPrisma.purchase_order = { count: jest.fn().mockResolvedValue(20) };
    mockPrisma.goods_receipt = {
      count: jest.fn().mockResolvedValue(20),
      findMany: jest.fn().mockResolvedValue([]),
    };
    mockPrisma.supplier = { count: jest.fn().mockResolvedValue(2) };
    mockPrisma.audit_log.count = jest.fn().mockResolvedValue(20);

    const { verifyDemoData } = require('../../../scripts/verify-demo-data');
    const result = await verifyDemoData();

    expect(result.ok).toBe(false);
    expect(result.errors.some((entry) => entry.includes('patients for volume demo seed'))).toBe(true);
  });
});
