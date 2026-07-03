/**
 * Application Constants
 * 
 * All constants must live in this file (per constants-env.mdc)
 * Naming convention: UPPER_SNAKE_CASE for constants
 * Config objects: PascalCase
 */

// Pagination Constants
const DEFAULT_PAGE = 1;
const DEFAULT_PAGE_LIMIT = 20;
const MAX_PAGE_LIMIT = 100;

const API_VERSION = 'v1';
const DEPRECATED_API_VERSIONS = [];
const DEPRECATION_SUNSET = null;

// Storage
const LOCAL_STORAGE_DIR = 'uploads';
const STORAGE_ENCRYPTION_MAGIC = 'BMP1';

// Resilience defaults (per error-logging.mdc)
const RETRY_MAX_ATTEMPTS = 3;
const RETRY_INITIAL_DELAY_MS = 100;
const RETRY_BACKOFF_MULTIPLIER = 2;
const RETRY_MAX_DELAY_MS = 5000;
const DEFAULT_REQUEST_TIMEOUT_MS = 30000;

const SUPPORTED_LOCALES = [
  'en'
];
const DEFAULT_LOCALE = 'en';
const DEFAULT_SEED_RECORD_COUNT = 50;
const SEED_COUNTS = Object.freeze({
  subscription_plan: 5,
  subscription: 7,
  subscription_invoice: 6,
  module: 24,
  module_subscription: 24,
  license: 6,
  configuration_snapshot: 10,
  audit_log: 20,
  phi_access_log: 8,
  data_processing_log: 8,
  breach_notification: 5,
  system_change_log: 8,
  integration: 6,
  integration_log: 10,
  webhook_subscription: 8,
  analytics_event: 20,
  kpi_snapshot: 10
});

const HMS_SEED_MODEL_ORDER = Object.freeze([
  // Group 1: Tenancy and org
  'tenant',
  'facility',
  'branch',
  'department',
  'unit',
  'room',
  'ward',
  'bed',
  'address',
  'contact',

  // Group 2: Access
  'role',
  'permission',
  'role_permission',
  'user',
  'user_profile',
  'user_role',
  'api_key',
  'api_key_permission',
  'user_mfa',
  'oauth_account',
  'user_session',

  // Group 3: Patients and consent
  'patient',
  'patient_identifier',
  'patient_contact',
  'patient_guardian',
  'patient_allergy',
  'patient_medical_history',
  'patient_document',
  'consent',
  'terms_acceptance',

  // Group 4: Scheduling and clinical
  'appointment',
  'appointment_participant',
  'appointment_reminder',
  'provider_schedule',
  'availability_slot',
  'visit_queue',
  'encounter',
  'clinical_note',
  'diagnosis',
  'procedure',
  'vital_sign',
  'care_plan',
  'clinical_alert',
  'referral',
  'follow_up',

  // Group 5: IPD/ICU/Theatre
  'admission',
  'bed_assignment',
  'ward_round',
  'nursing_note',
  'medication_administration',
  'discharge_summary',
  'transfer_request',
  'icu_stay',
  'icu_observation',
  'critical_alert',
  'theatre_case',
  'anesthesia_record',
  'post_op_note',

  // Group 6: Diagnostics
  'lab_test',
  'lab_panel',
  'lab_order',
  'lab_order_item',
  'lab_sample',
  'lab_result',
  'lab_qc_log',
  'radiology_test',
  'radiology_order',
  'radiology_result',
  'imaging_study',
  'imaging_asset',
  'pacs_link',

  // Group 7: Pharmacy and inventory
  'drug',
  'drug_batch',
  'formulary_item',
  'pharmacy_order',
  'pharmacy_order_item',
  'dispense_log',
  'adverse_event',
  'inventory_item',
  'inventory_stock',
  'stock_movement',
  'supplier',
  'purchase_request',
  'purchase_order',
  'goods_receipt',
  'stock_adjustment',

  // Group 8: Emergency
  'emergency_case',
  'triage_assessment',
  'emergency_response',
  'ambulance',
  'ambulance_dispatch',
  'ambulance_trip',

  // Group 9: Billing/HR/Facilities
  'invoice',
  'invoice_item',
  'payment',
  'refund',
  'pricing_rule',
  'coverage_plan',
  'insurance_claim',
  'pre_authorization',
  'billing_adjustment',
  'staff_position',
  'staff_profile',
  'staff_assignment',
  'staff_leave',
  'shift',
  'shift_assignment',
  'shift_swap_request',
  'payroll_run',
  'payroll_item',
  'nurse_roster',
  'shift_template',
  'roster_day_off',
  'staff_availability',
  'housekeeping_task',
  'housekeeping_schedule',
  'maintenance_request',
  'asset',
  'asset_service_log',

  // Group 10: Biomedical
  'equipment_category',
  'equipment_registry',
  'equipment_location_history',
  'equipment_maintenance_plan',
  'equipment_work_order',
  'equipment_calibration_log',
  'equipment_safety_test_log',
  'equipment_downtime_log',
  'equipment_spare_part',
  'equipment_warranty_contract',
  'equipment_service_provider',
  'equipment_incident_report',
  'equipment_recall_notice',
  'equipment_utilization_snapshot',
  'equipment_disposal_transfer',

  // Group 11: Comms/Analytics/Compliance/Integrations
  'notification',
  'notification_delivery',
  'conversation',
  'message',
  'template',
  'template_variable',
  'report_definition',
  'report_run',
  'dashboard_widget',
  'kpi_snapshot',
  'analytics_event',
  'subscription_plan',
  'subscription',
  'subscription_invoice',
  'module',
  'module_subscription',
  'license',
  'audit_log',
  'phi_access_log',
  'data_processing_log',
  'breach_notification',
  'system_change_log',
  'integration',
  'integration_log',
  'webhook_subscription'
]);

const SEED_CANONICAL_PLAN_DEFINITIONS = Object.freeze([
  {
    code: 'free',
    name: 'Free',
    tier_code: 'FREE',
    price: 0,
    billing_cycle: 'MONTHLY',
    max_users: 1,
    max_facilities: 1,
    max_storage_mb: 200,
    max_modules: 8,
    extension_json: {
      price_notes: { monthly: 0 },
      usage_limits: { new_patients_per_day: 5 },
      support: 'best_effort'
    }
  },
  {
    code: 'basic',
    name: 'Basic',
    tier_code: 'BASIC',
    price: 39,
    billing_cycle: 'MONTHLY',
    max_users: 5,
    max_facilities: 1,
    max_storage_mb: 5120,
    max_modules: 20,
    extension_json: {
      price_notes: { monthly: 39, yearly: 390, extra_user_monthly: 6, extra_user_yearly: 60 },
      branch_allowance: { included_branches: 2 },
      support: 'email_48_72h'
    }
  },
  {
    code: 'pro',
    name: 'Pro',
    tier_code: 'PRO',
    price: 89,
    billing_cycle: 'MONTHLY',
    max_users: 10,
    max_facilities: 3,
    max_storage_mb: 20480,
    max_modules: 80,
    extension_json: {
      price_notes: {
        monthly: 89,
        yearly: 890,
        extra_user_monthly: 8,
        extra_user_yearly: 80,
        extra_facility_monthly: 15,
        extra_facility_yearly: 150
      },
      support: 'priority_24_48h'
    }
  },
  {
    code: 'advanced',
    name: 'Advanced',
    tier_code: 'ADVANCED',
    price: 600,
    billing_cycle: 'YEARLY',
    max_users: 300,
    max_facilities: 50,
    max_storage_mb: 102400,
    max_modules: 160,
    extension_json: {
      commercial_terms: {
        setup_range_usd: [2500, 7500],
        annual_maintenance_range_usd: [600, 1500],
        hosting_model: 'on_prem_standard'
      },
      support: 'priority_optional_sla'
    }
  },
  {
    code: 'custom',
    name: 'Custom',
    tier_code: 'CUSTOM',
    price: 10000,
    billing_cycle: 'YEARLY',
    max_users: null,
    max_facilities: null,
    max_storage_mb: null,
    max_modules: null,
    extension_json: {
      commercial_terms: {
        setup_from_usd: 10000,
        annual_support_percent_range: [15, 25],
        hosting_model: 'cloud_on_prem_hybrid',
        contracting_model: 'sow'
      },
      support: 'dedicated_custom_sla'
    }
  }
]);

const SEED_ADD_ON_CATALOG = Object.freeze([
  {
    code: 'inventory_procurement_lite',
    slug: 'inventory-procurement-lite',
    name: 'Inventory and Procurement Lite',
    minimum_plan_tier_code: 'BASIC',
    module_group: 11,
    add_on_price: 39,
    add_on_billing_cycle: 'MONTHLY',
    extension_json: { price_range_usd_monthly: [19, 59] }
  },
  {
    code: 'biomedical_engineering_suite',
    slug: 'biomedical-engineering-suite',
    name: 'Biomedical Engineering Suite',
    minimum_plan_tier_code: 'PRO',
    module_group: 15,
    add_on_price: 129,
    add_on_billing_cycle: 'MONTHLY',
    extension_json: { price_range_usd_monthly: [49, 199] }
  },
  {
    code: 'compliance_audit_suite',
    slug: 'compliance-audit-suite',
    name: 'Compliance and Audit Suite',
    minimum_plan_tier_code: 'PRO',
    module_group: 19,
    add_on_price: 89,
    add_on_billing_cycle: 'MONTHLY',
    extension_json: { price_range_usd_monthly: [39, 149] }
  },
  {
    code: 'advanced_analytics',
    slug: 'advanced-analytics',
    name: 'Advanced Analytics',
    minimum_plan_tier_code: 'PRO',
    module_group: 17,
    add_on_price: 59,
    add_on_billing_cycle: 'MONTHLY',
    extension_json: { price_range_usd_monthly: [29, 99] }
  },
  {
    code: 'integrations_webhooks_pack',
    slug: 'integrations-webhooks-pack',
    name: 'Integrations/Webhooks Pack',
    minimum_plan_tier_code: 'PRO',
    module_group: 20,
    add_on_price: 79,
    add_on_billing_cycle: 'MONTHLY',
    extension_json: { price_range_usd_monthly: [49, 149] }
  },
  {
    code: 'extra_storage',
    slug: 'extra-storage',
    name: 'Extra Storage',
    minimum_plan_tier_code: 'BASIC',
    module_group: 18,
    add_on_price: 5,
    add_on_billing_cycle: 'MONTHLY',
    extension_json: { billing_basis: 'per_10gb' }
  },
  {
    code: 'sms_credits',
    slug: 'sms-credits',
    name: 'SMS Credits',
    minimum_plan_tier_code: 'BASIC',
    module_group: 16,
    add_on_price: 0,
    add_on_billing_cycle: 'MONTHLY',
    extension_json: { billing_basis: 'usage_based' }
  }
]);

const SEED_FREE_CORE_MODULE_CATALOG = Object.freeze([
  {
    code: 'auth_rbac_basics',
    slug: 'auth-rbac-basics',
    name: 'Auth and RBAC Basics',
    module_group: 1
  },
  {
    code: 'patient_registry_basic',
    slug: 'patient-registry-basic',
    name: 'Patient Registry Basic',
    module_group: 2
  },
  {
    code: 'scheduling_queue_basic',
    slug: 'scheduling-queue-basic',
    name: 'Scheduling and Queue Basic',
    module_group: 3
  },
  {
    code: 'encounters_vitals_basic',
    slug: 'encounters-vitals-basic',
    name: 'Encounters and Vitals Basic',
    module_group: 4
  },
  {
    code: 'billing_basic',
    slug: 'billing-basic',
    name: 'Billing Basic',
    module_group: 13
  },
  {
    code: 'dashboard_view_only',
    slug: 'dashboard-view-only',
    name: 'Dashboard View Only',
    module_group: 17
  },
  {
    code: 'notification_templates',
    slug: 'notification-templates',
    name: 'Notification Templates',
    module_group: 16
  },
  {
    code: 'equipment_fault_reporting',
    slug: 'equipment-fault-reporting',
    name: 'Equipment Fault Reporting',
    module_group: 15
  }
]);

module.exports = {
  DEFAULT_PAGE,
  DEFAULT_PAGE_LIMIT,
  MAX_PAGE_LIMIT,
  LOCAL_STORAGE_DIR,
  STORAGE_ENCRYPTION_MAGIC,
  RETRY_MAX_ATTEMPTS,
  RETRY_INITIAL_DELAY_MS,
  RETRY_BACKOFF_MULTIPLIER,
  RETRY_MAX_DELAY_MS,
  DEFAULT_REQUEST_TIMEOUT_MS,
  SUPPORTED_LOCALES,
  DEFAULT_LOCALE,
  DEFAULT_SEED_RECORD_COUNT,
  SEED_COUNTS,
  HMS_SEED_MODEL_ORDER,
  SEED_CANONICAL_PLAN_DEFINITIONS,
  SEED_ADD_ON_CATALOG,
  SEED_FREE_CORE_MODULE_CATALOG,
  API_VERSION,
  DEPRECATED_API_VERSIONS,
  DEPRECATION_SUNSET
};

