/**
 * Commercial plan → module packaging matrix.
 *
 * Used ONLY for seeding / backfill defaults. Runtime entitlement must read
 * subscription_plan.extension_json.allowed_modules and module rows from the DB.
 *
 * Higher tiers include every module from lower tiers (cumulative).
 */

const PLAN_TIER_RANK = Object.freeze({
  FREE: 0,
  BASIC: 1,
  ADVANCED: 2,
  PRO: 3,
  CUSTOM: 4,
  DEVELOPER: 5,
});

/**
 * Commercial product modules and the minimum plan that includes them by default.
 * Platform infrastructure modules are seeded separately with
 * extension_json.is_platform_infrastructure = true.
 */
const COMMERCIAL_MODULE_MATRIX = Object.freeze([
  // —— Free (all packages) ——
  {
    code: 'auth_rbac_basics',
    slug: 'auth-rbac-basics',
    name: 'Auth and RBAC Basics',
    module_group: 1,
    minimum_plan_tier_code: 'FREE',
  },
  {
    code: 'patient_registry',
    slug: 'patient-registry',
    name: 'Patient Registry and Consent',
    module_group: 2,
    minimum_plan_tier_code: 'FREE',
  },
  {
    code: 'scheduling_queue',
    slug: 'scheduling-queue',
    name: 'Scheduling and Queue (OPD)',
    module_group: 3,
    minimum_plan_tier_code: 'BASIC',
  },
  {
    code: 'encounters_vitals',
    slug: 'encounters-vitals',
    name: 'Encounters and Vitals',
    module_group: 4,
    minimum_plan_tier_code: 'BASIC',
  },
  {
    code: 'lab_workflows',
    slug: 'lab-workflows',
    name: 'Lab Workflows',
    module_group: 8,
    minimum_plan_tier_code: 'ADVANCED',
  },
  {
    code: 'pharmacy_dispensing',
    slug: 'pharmacy-dispensing',
    name: 'Pharmacy Dispensing',
    module_group: 10,
    minimum_plan_tier_code: 'BASIC',
  },
  {
    code: 'billing_payments',
    slug: 'billing-payments',
    name: 'Billing, Payments, and Invoices',
    module_group: 13,
    minimum_plan_tier_code: 'BASIC',
  },
  {
    code: 'insurance_claims',
    slug: 'insurance-claims',
    name: 'Insurance and Claims',
    module_group: 13,
    minimum_plan_tier_code: 'ADVANCED',
  },
  {
    code: 'notifications_communications',
    slug: 'notifications-communications',
    name: 'Notifications and Communications',
    module_group: 16,
    minimum_plan_tier_code: 'BASIC',
  },

  // —— Basic ——
  {
    code: 'radiology_workflows',
    slug: 'radiology-workflows',
    name: 'Radiology Workflows',
    module_group: 9,
    minimum_plan_tier_code: 'ADVANCED',
  },

  // —— Pro ——
  {
    code: 'inpatient_bed_management',
    slug: 'inpatient-bed-management',
    name: 'IPD and Bed Management',
    module_group: 5,
    minimum_plan_tier_code: 'BASIC',
  },
  {
    code: 'theatre_anesthesia',
    slug: 'theatre-anesthesia',
    name: 'Theatre and Anesthesia',
    module_group: 7,
    minimum_plan_tier_code: 'PRO',
  },
  {
    code: 'physiotherapy',
    slug: 'physiotherapy',
    name: 'Physiotherapy and Rehabilitation',
    module_group: 7,
    minimum_plan_tier_code: 'ADVANCED',
  },
  {
    code: 'facilities_maintenance',
    slug: 'facilities-maintenance',
    name: 'Facilities and Maintenance',
    module_group: 15,
    minimum_plan_tier_code: 'PRO',
  },
  {
    code: 'reporting_analytics',
    slug: 'reporting-analytics',
    name: 'Reporting and Analytics',
    module_group: 17,
    minimum_plan_tier_code: 'FREE',
  },

  // —— Advanced ——
  {
    code: 'icu_critical_care',
    slug: 'icu-critical-care',
    name: 'ICU and Critical Care',
    module_group: 6,
    minimum_plan_tier_code: 'PRO',
  },
  {
    code: 'inventory_procurement_lite',
    slug: 'inventory-procurement-lite',
    name: 'Inventory and Procurement',
    module_group: 11,
    minimum_plan_tier_code: 'PRO',
  },
  {
    code: 'mortuary_operations',
    slug: 'mortuary',
    name: 'Mortuary',
    module_group: 12,
    minimum_plan_tier_code: 'PRO',
  },
  {
    code: 'biomedical_engineering_suite',
    slug: 'biomedical-engineering-suite',
    name: 'Biomedical Engineering Suite',
    module_group: 15,
    minimum_plan_tier_code: 'PRO',
  },
  {
    code: 'extra_storage',
    slug: 'extra-storage',
    name: 'Extra Storage',
    module_group: 17,
    minimum_plan_tier_code: 'ADVANCED',
  },
  {
    code: 'hr_rosters',
    slug: 'hr-rosters',
    name: 'HR and Rosters',
    module_group: 14,
    minimum_plan_tier_code: 'PRO',
  },

  // —— Custom / Developer ——
  {
    code: 'subscription_controls',
    slug: 'subscription-controls',
    name: 'Subscription and Licensing Controls',
    module_group: 18,
    minimum_plan_tier_code: 'BASIC',
    description:
      'Plan management, renewals, upgrades, licensing, and module self-service.',
  },
  {
    code: 'compliance_audit_core',
    slug: 'compliance-audit-core',
    name: 'Compliance and Audit Core',
    module_group: 19,
    minimum_plan_tier_code: 'CUSTOM',
  },
  {
    code: 'integrations_core',
    slug: 'integrations-core',
    name: 'Integrations and Webhooks',
    module_group: 20,
    minimum_plan_tier_code: 'PRO',
  },
  {
    code: 'advanced_analytics',
    slug: 'advanced-analytics',
    name: 'Advanced Analytics',
    module_group: 17,
    minimum_plan_tier_code: 'CUSTOM',
  },
  {
    code: 'sms_credits',
    slug: 'sms-credits',
    name: 'SMS Credits',
    module_group: 16,
    minimum_plan_tier_code: 'CUSTOM',
  },
  {
    code: 'developer_tools',
    slug: 'developer-tools',
    name: 'Developer Tools',
    module_group: 21,
    minimum_plan_tier_code: 'DEVELOPER',
    description:
      'API keys, webhook debugging, sandbox utilities, and full integration tooling.',
  },

  // Legacy aliases for older tenants / path maps (not preferred for new allowlists).
  {
    code: 'billing_insurance',
    slug: 'billing-insurance',
    name: 'Billing and Insurance (Legacy)',
    module_group: 13,
    minimum_plan_tier_code: 'FREE',
    extension_json: {
      legacy_alias_for: ['billing-payments', 'insurance-claims'],
      deprecated: true,
    },
  },
  {
    code: 'inventory_procurement',
    slug: 'inventory-procurement',
    name: 'Inventory and Procurement (Legacy)',
    module_group: 11,
    minimum_plan_tier_code: 'ADVANCED',
    extension_json: {
      legacy_alias_for: ['inventory-procurement-lite'],
      deprecated: true,
    },
  },
]);

/**
 * Platform / infrastructure API modules. Seeded into DB with
 * is_platform_infrastructure so middleware does not hardcode commercial access.
 */
const PLATFORM_INFRASTRUCTURE_MODULES = Object.freeze([
  {
    code: 'platform_identity',
    slug: 'platform-identity',
    name: 'Platform Identity and Access',
    module_group: 0,
    minimum_plan_tier_code: 'FREE',
    extension_json: {
      is_platform_infrastructure: true,
      api_path_segments: [
        'tenant',
        'user-session',
        'user',
        'user-profile',
        'user-mfa',
        'oauth-account',
        'role',
        'permission',
        'role-permission',
        'user-role',
        'auth',
        'me',
        'health',
      ],
    },
  },
  {
    code: 'platform_facility_structure',
    slug: 'platform-facility-structure',
    name: 'Platform Facility Structure',
    module_group: 0,
    minimum_plan_tier_code: 'FREE',
    extension_json: {
      is_platform_infrastructure: true,
      api_path_segments: [
        'facility',
        'department',
        'unit',
        'room',
        'ward',
        'bed',
        'address',
        'contact',
        'staff-position',
        'tenant-facility-workspace',
        'settings-workspace',
        'access-admin-workspace',
      ],
    },
  },
  {
    code: 'platform_workspace_shell',
    slug: 'platform-workspace-shell',
    name: 'Platform Workspace Shell',
    module_group: 0,
    minimum_plan_tier_code: 'FREE',
    extension_json: {
      is_platform_infrastructure: true,
      api_path_segments: [
        'dashboard-workspace',
        'dashboard-widget',
        'kpi-snapshot',
        'module',
        'modules',
        'module-subscription',
        'module-subscriptions',
        'subscription',
        'subscriptions',
        'subscription-plan',
        'subscription-plans',
        'subscription-invoice',
        'subscription-invoices',
        'license',
        'licenses',
        'subscriptions-workspace',
      ],
    },
  },
]);

const isEligibleForTier = (tierCode, minimumTierCode) =>
  (PLAN_TIER_RANK[String(tierCode || '').toUpperCase()] ?? -1) >=
  (PLAN_TIER_RANK[String(minimumTierCode || '').toUpperCase()] ?? 999);

const modulesForPlanTier = (tierCode, { includeLegacyAliases = true } = {}) =>
  COMMERCIAL_MODULE_MATRIX.filter((entry) => {
    if (
      !includeLegacyAliases &&
      entry.extension_json &&
      entry.extension_json.deprecated
    ) {
      return false;
    }
    return isEligibleForTier(tierCode, entry.minimum_plan_tier_code);
  });

module.exports = {
  COMMERCIAL_MODULE_MATRIX,
  PLATFORM_INFRASTRUCTURE_MODULES,
  PLAN_TIER_RANK,
  isEligibleForTier,
  modulesForPlanTier,
};
