/**
 * Realtime configuration for audit-driven CRUD broadcasts.
 */

const { ROLES } = require('@config/roles');

const DEFAULT_RECIPIENT_ROLES = Object.freeze([
  ROLES.RECEPTIONIST,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
  ROLES.RADIOLOGY_TECH,
  ROLES.PHARMACIST,
  ROLES.BILLING,
  ROLES.OPERATIONS,
  ROLES.HR,
  ROLES.BIOMED,
  ROLES.HOUSE_KEEPER,
  ROLES.AMBULANCE_OPERATOR,
  ROLES.UNIT_MANAGER,
  ROLES.WARD_MANAGER,
  ROLES.ICU_MANAGER,
  ROLES.THEATRE_MANAGER,
  ROLES.HOUSEKEEPING_MANAGER,
  ROLES.BIOMED_MANAGER,
  ROLES.MORTUARY_STAFF,
  ROLES.MORTUARY_MANAGER,
  ROLES.FACILITY_ADMIN,
  ROLES.TENANT_ADMIN
]);

/**
 * Entities with bespoke websocket publishers in their services.
 * Audit-driven auto emission is skipped to avoid duplicate events.
 */
const REALTIME_SKIP_ENTITIES = new Set([
  'patient',
  'encounter',
  'visit_queue',
  'payment',
  'invoice',
  'billing',
  'opd_flow',
  'ipd_flow',
  'subscription',
  'tenant',
  'facility',
  'role',
  'user',
  'ward',
  'room',
  'bed',
  'notification',
  'notification_delivery',
  'equipment_work_order',
  'maintenance_request',
  'follow_up',
  'lab_order',
  'lab_result',
  'lab_workflow',
  'radiology_order',
  'radiology_result',
  'pharmacy_order',
  'pharmacy_workspace',
  'biomedical_workspace',
  'hr_workspace',
  'communications_workspace',
  'conversation',
  'message'
]);

/**
 * Optional per-entity event overrides when audit auto emission is enabled.
 */
const REALTIME_EVENT_OVERRIDES = Object.freeze({
  appointment_rescheduled: 'appointment.rescheduled'
});

/**
 * Optional per-entity recipient role overrides.
 */
const ENTITY_RECIPIENT_ROLES = Object.freeze({
  department: Object.freeze([ROLES.FACILITY_ADMIN, ROLES.TENANT_ADMIN, ROLES.UNIT_MANAGER]),
  facility: Object.freeze([ROLES.FACILITY_ADMIN, ROLES.TENANT_ADMIN]),
  tenant: Object.freeze([ROLES.TENANT_ADMIN]),
  role: Object.freeze([ROLES.TENANT_ADMIN]),
  permission: Object.freeze([ROLES.TENANT_ADMIN]),
  user: Object.freeze([ROLES.FACILITY_ADMIN, ROLES.TENANT_ADMIN]),
  user_role: Object.freeze([ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN]),
  api_key: Object.freeze([ROLES.TENANT_ADMIN]),
  integration: Object.freeze([ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN]),
  webhook_subscription: Object.freeze([ROLES.TENANT_ADMIN]),
  subscription_plan: Object.freeze([ROLES.TENANT_ADMIN]),
  module_subscription: Object.freeze([ROLES.TENANT_ADMIN]),
  report_definition: Object.freeze([ROLES.FACILITY_ADMIN, ROLES.TENANT_ADMIN]),
  report_schedule: Object.freeze([ROLES.FACILITY_ADMIN, ROLES.TENANT_ADMIN]),
  report_run: Object.freeze([ROLES.FACILITY_ADMIN, ROLES.TENANT_ADMIN]),
  patient_report_job: Object.freeze([
    ROLES.RECEPTIONIST,
    ROLES.DOCTOR,
    ROLES.NURSE,
    ROLES.LAB_TECH,
    ROLES.RADIOLOGY_TECH,
    ROLES.PHARMACIST,
    ROLES.BILLING,
    ROLES.FACILITY_ADMIN,
    ROLES.TENANT_ADMIN,
  ]),
});

const REALTIME_MUTATION_ACTIONS = new Set(['CREATE', 'UPDATE', 'DELETE']);

module.exports = {
  DEFAULT_RECIPIENT_ROLES,
  REALTIME_SKIP_ENTITIES,
  REALTIME_EVENT_OVERRIDES,
  ENTITY_RECIPIENT_ROLES,
  REALTIME_MUTATION_ACTIONS
};
