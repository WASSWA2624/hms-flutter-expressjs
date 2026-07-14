UPDATE `subscription_plan`
SET `tier_code` = 'DEVELOPER',
    `updated_at` = CURRENT_TIMESTAMP(3),
    `version` = `version` + 1
WHERE LOWER(`code`) = 'developer'
  AND `deleted_at` IS NULL;

UPDATE `module`
SET `minimum_plan_tier_code` = CASE
  WHEN `slug` IN (
    'auth-rbac-basics',
    'patient-registry',
    'reporting-analytics',
    'platform-identity',
    'platform-facility-structure',
    'platform-workspace-shell'
  ) THEN 'FREE'
  WHEN `slug` IN (
    'scheduling-queue',
    'encounters-vitals',
    'pharmacy-dispensing',
    'billing-payments',
    'notifications-communications',
    'inpatient-bed-management',
    'subscription-controls'
  ) THEN 'BASIC'
  WHEN `slug` IN (
    'lab-workflows',
    'radiology-workflows',
    'insurance-claims',
    'physiotherapy',
    'billing-insurance'
  ) THEN 'ADVANCED'
  WHEN `slug` IN (
    'theatre-anesthesia',
    'facilities-maintenance',
    'icu-critical-care',
    'inventory-procurement-lite',
    'inventory-procurement',
    'mortuary',
    'biomedical-engineering-suite',
    'hr-rosters',
    'integrations-core'
  ) THEN 'PRO'
  WHEN `slug` = 'developer-tools' THEN 'DEVELOPER'
  ELSE 'CUSTOM'
END,
`updated_at` = CURRENT_TIMESTAMP(3),
`version` = `version` + 1
WHERE `deleted_at` IS NULL
  AND `slug` IS NOT NULL;

-- Rollback: restore values from the previous deployment's catalog snapshot.
