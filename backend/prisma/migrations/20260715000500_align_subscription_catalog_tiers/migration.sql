UPDATE `subscription_plan`
SET `tier_code` = 'DEVELOPER',
    `updated_at` = CURRENT_TIMESTAMP(3),
    `version` = `version` + 1
WHERE LOWER(`code`) = 'developer'
  AND `deleted_at` IS NULL;

UPDATE `subscription_plan`
SET `tier_code` = 'CUSTOM',
    `updated_at` = CURRENT_TIMESTAMP(3),
    `version` = `version` + 1
WHERE LOWER(`code`) = 'custom'
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

-- Upgrade demo subscriptions from ADVANCED to PRO so PRO-tier modules
-- (hr-rosters, icu-critical-care, theatre-anesthesia, etc.) are entitled.
UPDATE `subscription` s
  JOIN `subscription_plan` p ON s.`plan_id` = p.`id`
SET s.`plan_id` = (
      SELECT sp.`id`
      FROM `subscription_plan` sp
      WHERE LOWER(sp.`code`) = 'pro'
        AND sp.`deleted_at` IS NULL
      LIMIT 1
    ),
    s.`updated_at` = CURRENT_TIMESTAMP(3),
    s.`version` = s.`version` + 1
WHERE LOWER(p.`code`) = 'advanced'
  AND s.`deleted_at` IS NULL
  AND s.`status` IN ('ACTIVE', 'TRIAL');

-- Activate PRO-tier module_subscription rows that were previously denied.
UPDATE `module_subscription` ms
  JOIN `subscription` s ON ms.`subscription_id` = s.`id`
  JOIN `subscription_plan` p ON s.`plan_id` = p.`id`
  JOIN `module` m ON ms.`module_id` = m.`id`
SET ms.`is_active` = 1,
    ms.`entitlement_denied` = 0,
    ms.`entitlement_denial_reason` = NULL,
    ms.`activated_at` = COALESCE(ms.`activated_at`, CURRENT_TIMESTAMP(3)),
    ms.`updated_at` = CURRENT_TIMESTAMP(3),
    ms.`version` = ms.`version` + 1
WHERE LOWER(p.`tier_code`) = 'pro'
  AND ms.`is_active` = 0
  AND ms.`deleted_at` IS NULL
  AND s.`deleted_at` IS NULL
  AND m.`deleted_at` IS NULL
  AND m.`minimum_plan_tier_code` IN ('FREE', 'BASIC', 'ADVANCED', 'PRO');

-- Rollback: restore values from the previous deployment's catalog snapshot.
