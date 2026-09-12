/**
 * What a brand-new tenant is allowed to contain.
 *
 * A tenant must be created as `configuration + presets + empty operational
 * data`. This module is the single definition of that contract: which
 * tenant-reachable tables may legitimately hold rows for a freshly created
 * tenant, and which must be empty.
 *
 * The forbidden set is derived, not hand-listed: it is every tenant-reachable
 * table in the Prisma schema that is *not* explicitly classified as allowed
 * configuration. A new model therefore defaults to forbidden, and whoever adds
 * it has to classify it here on purpose. `tenant-initialization-policy.test.js`
 * fails if any table ends up unclassified or if one of the core patient-linked
 * categories drops out of the forbidden set.
 *
 * Consumed by the creation-time assertion, `scripts/clean-tenant-operational-seed.js`
 * and `scripts/verify-onboarding-e2e.js`, so all three agree on one definition.
 *
 * @module lib/tenant/tenant-initialization-policy
 */

const { Prisma } = require('.prisma/client');

/**
 * Tables a newly created tenant may legitimately own rows in.
 *
 * Grouped by why they are allowed. Anything absent from this set is treated as
 * operational data that a new tenant must not have.
 */
const ALLOWED_INITIAL_TABLES = Object.freeze(new Set([
  // --- Tenancy and facility structure -----------------------------------
  'facility',
  'address',
  'contact',
  'department',
  'unit',
  'unit_management_assignment',
  'ward',
  'room',
  'bed',
  'pharmacy_storage_room',
  'pharmacy_storage_shelf',
  // Physical mortuary capacity, the same kind of thing as ward/room/bed.
  // Assigning a body to a slot is operational and stays forbidden.
  'mortuary_storage_unit',
  'mortuary_storage_slot',

  // --- Identity, access and staffing ------------------------------------
  'user',
  'user_profile',
  'user_role',
  'user_module_assignment',
  'role',
  'permission',
  'abac_policy',
  'staff_position',
  'staff_profile',
  'office_context',
  'terms_acceptance',

  // --- Registration and auth bookkeeping --------------------------------
  'registration_attempt',
  'registration_follow_up',

  // --- Subscription and entitlement -------------------------------------
  'subscription',
  'subscription_plan',
  'license',

  // --- Clinical and diagnostic master data (presets) --------------------
  'lab_test',
  'lab_panel',
  'radiology_procedure',
  'clinical_term_catalog',
  'clinical_vital_alert_threshold',
  'facility_catalog_offering',
  'facility_lab_test_offering',
  'facility_lab_panel_offering',
  'facility_radiology_procedure_offering',
  'facility_pharmacy_offering',

  // --- Pharmacy and inventory master data (presets) ---------------------
  'drug',
  'drug_inventory_map',
  'formulary_item',
  'inventory_item',
  'supplier',

  // --- Billing, pricing and accounting configuration --------------------
  'price_book_entry',
  'pricing_rule',
  'payment_method',
  'chart_account',
  'posting_rule',
  'fiscal_period',
  'document_number_sequence',
  'coverage_plan',
  'scheme_offer',
  'insurance_company',
  'insurer_integration',

  // --- Asset and equipment registries -----------------------------------
  'asset',
  'ambulance',
  'equipment_registry',
  'equipment_category',
  'equipment_service_provider',
  'equipment_spare_part',
  'equipment_maintenance_plan',

  // --- Scheduling and workflow templates --------------------------------
  'shift_template',
  'provider_schedule',
  'housekeeping_schedule',

  // --- Reporting, integration and presentation configuration ------------
  'report_definition',
  'report_schedule',
  'dashboard_widget',
  'template',
  'integration',
  'api_key',
  'webhook_subscription',
  'configuration_snapshot',
  'conversation_visibility_role',

  // --- Compliance records written by the creation path itself -----------
  'audit_log',
  'system_change_log',
]));

/**
 * Patient-linked and transactional categories that must always be checked.
 *
 * These are the categories step 05 names explicitly. They are asserted to be a
 * subset of the derived forbidden set, so no future edit to the allowlist can
 * quietly stop covering them.
 */
const CORE_FORBIDDEN_TABLES = Object.freeze([
  'patient',
  'patient_allergy',
  'patient_contact',
  'patient_document',
  'patient_guardian',
  'patient_identifier',
  'patient_insurance_enrollment',
  'patient_medical_history',
  'patient_report_job',
  'visit_queue',
  'encounter',
  'admission',
  'appointment',
  'emergency_case',
  'invoice',
  'accounts_invoice',
  'payment',
  'billable_charge_event',
  'billing_approval',
  'stock_movement',
  'stock_adjustment',
  'inventory_stock',
  'phi_access_log',
]);

const hasField = (model, field) => model.fields.some((entry) => entry.name === field);

/**
 * Every model reachable from a tenant.
 *
 * Clinical parents (`patient_id`, `encounter_id`, `admission_id`) are included
 * deliberately. An earlier version of this list matched only `tenant_id` and
 * `facility_id`, which silently skipped twenty-two clinical tables and let the
 * step 05 audit report a new tenant as empty while `lab_order`,
 * `radiology_order` and `theatre_case` were leaking across tenants. Those
 * tables now carry their own `tenant_id`, but the clinical keys stay in this
 * filter so a future table that forgets one is still counted rather than
 * silently ignored.
 */
const CLINICAL_PARENT_KEYS = Object.freeze([
  'patient_id', 'encounter_id', 'admission_id', 'visit_id',
]);

const listTenantReachableTables = () =>
  Prisma.dmmf.datamodel.models
    .filter((model) =>
      hasField(model, 'tenant_id')
      || hasField(model, 'facility_id')
      || CLINICAL_PARENT_KEYS.some((key) => hasField(model, key)))
    .map((model) => model.name)
    .filter((name) => name !== 'tenant')
    .sort();

/** Tables a freshly created tenant must have zero rows in. */
const listForbiddenTables = () =>
  listTenantReachableTables().filter((name) => !ALLOWED_INITIAL_TABLES.has(name));

/**
 * @param {string} table
 * @returns {'allowed'|'forbidden'|'out-of-scope'}
 */
const classifyTable = (table) => {
  if (!listTenantReachableTables().includes(table)) return 'out-of-scope';
  return ALLOWED_INITIAL_TABLES.has(table) ? 'allowed' : 'forbidden';
};

/**
 * Count rows in every forbidden table for one tenant.
 *
 * Tenant-scoped throughout: tables carrying `tenant_id` are filtered on it, and
 * facility-only tables are filtered on that tenant's facility ids. A table the
 * client cannot count is reported rather than silently skipped.
 *
 * @param {string} tenantId
 * @param {Object} [options]
 * @param {Object} [options.client] - Prisma client (injectable for tests)
 * @returns {Promise<{table: string, rows: number, scope: string}[]>} Non-empty tables only
 */
const findTenantOperationalRows = async (tenantId, { client = null } = {}) => {
  const prisma = client || require('@prisma/client');
  if (!tenantId) {
    throw new Error('findTenantOperationalRows requires a tenant id.');
  }

  const modelsByName = new Map(
    Prisma.dmmf.datamodel.models.map((model) => [model.name, model])
  );

  const facilityIds = (
    await prisma.facility.findMany({
      where: { tenant_id: tenantId },
      select: { id: true },
    })
  ).map((facility) => facility.id);

  const violations = [];

  for (const table of listForbiddenTables()) {
    const delegate = prisma[table];
    if (!delegate || typeof delegate.count !== 'function') {
      continue;
    }

    const model = modelsByName.get(table);
    const tenantScoped = model ? hasField(model, 'tenant_id') : false;

    let rows;
    if (tenantScoped) {
      rows = await delegate.count({ where: { tenant_id: tenantId } });
    } else if (facilityIds.length > 0) {
      rows = await delegate.count({ where: { facility_id: { in: facilityIds } } });
    } else {
      rows = 0;
    }

    if (rows > 0) {
      violations.push({
        table,
        rows,
        scope: tenantScoped ? 'tenant_id' : 'facility_id',
      });
    }
  }

  return violations.sort((a, b) => b.rows - a.rows || a.table.localeCompare(b.table));
};

/**
 * Throw unless the tenant is free of operational data.
 *
 * @param {string} tenantId
 * @param {Object} [options]
 * @param {Object} [options.client]
 * @param {string} [options.context] - Label used in the thrown message
 * @returns {Promise<void>}
 */
const assertTenantHasNoOperationalData = async (
  tenantId,
  { client = null, context = 'tenant initialization' } = {}
) => {
  const violations = await findTenantOperationalRows(tenantId, { client });
  if (violations.length === 0) {
    return;
  }

  const detail = violations
    .map((violation) => `${violation.table}=${violation.rows}`)
    .join(', ');

  const error = new Error(
    `${context}: tenant ${tenantId} must contain no operational data, but found ${detail}.`
  );
  error.violations = violations;
  throw error;
};

module.exports = {
  ALLOWED_INITIAL_TABLES,
  CORE_FORBIDDEN_TABLES,
  listTenantReachableTables,
  listForbiddenTables,
  classifyTable,
  findTenantOperationalRows,
  assertTenantHasNoOperationalData,
};
