-- Make Lab Workflows available on every subscription plan tier (FREE and above).
UPDATE `module`
SET
  `minimum_plan_tier_code` = 'FREE',
  `entitlement_policy_json` = JSON_SET(
    COALESCE(`entitlement_policy_json`, JSON_OBJECT()),
    '$.minimum_plan_tier_code',
    'FREE'
  ),
  `updated_at` = CURRENT_TIMESTAMP(3)
WHERE `deleted_at` IS NULL
  AND `slug` = 'lab-workflows';
