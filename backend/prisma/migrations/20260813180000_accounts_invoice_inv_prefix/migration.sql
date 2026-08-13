-- Accounts outflow invoices: INV prefix (aligned with billing invoices) + unique per tenant.

-- Remap legacy ACC######## numbers to INV########.
UPDATE `accounts_invoice`
SET `human_friendly_id` = CONCAT('INV', SUBSTRING(`human_friendly_id`, 4))
WHERE `human_friendly_id` REGEXP '^ACC[0-9]{7}$';

-- Ensure INV counters continue past any remapped / existing accounts invoice sequences.
INSERT INTO `human_id_counter`
  (`id`, `model_name`, `prefix`, `scope_key`, `last_value`, `created_at`, `updated_at`, `version`)
SELECT
  UUID(),
  'invoice',
  'INV',
  REPLACE(
    REPLACE(c.`scope_key`, ':model:accounts_invoice:', ':model:invoice:'),
    ':prefix:ACC',
    ':prefix:INV'
  ),
  c.`last_value`,
  NOW(3),
  NOW(3),
  1
FROM `human_id_counter` c
WHERE c.`model_name` = 'accounts_invoice'
  AND c.`prefix` = 'ACC'
  AND c.`deleted_at` IS NULL
ON DUPLICATE KEY UPDATE
  `last_value` = GREATEST(`human_id_counter`.`last_value`, VALUES(`last_value`)),
  `updated_at` = NOW(3);

-- Also raise invoice INV counters from the highest INV sequence already on accounts invoices.
INSERT INTO `human_id_counter`
  (`id`, `model_name`, `prefix`, `scope_key`, `last_value`, `created_at`, `updated_at`, `version`)
SELECT
  UUID(),
  'invoice',
  'INV',
  CASE
    WHEN ai.`facility_id` IS NOT NULL AND ai.`facility_id` <> ''
      THEN CONCAT('facility:', ai.`facility_id`, ':model:invoice:prefix:INV')
    ELSE CONCAT('tenant:', ai.`tenant_id`, ':model:invoice:prefix:INV')
  END,
  MAX(CAST(SUBSTRING(ai.`human_friendly_id`, 4) AS UNSIGNED)),
  NOW(3),
  NOW(3),
  1
FROM `accounts_invoice` ai
WHERE ai.`human_friendly_id` REGEXP '^INV[0-9]{7}$'
  AND ai.`deleted_at` IS NULL
GROUP BY
  CASE
    WHEN ai.`facility_id` IS NOT NULL AND ai.`facility_id` <> ''
      THEN CONCAT('facility:', ai.`facility_id`, ':model:invoice:prefix:INV')
    ELSE CONCAT('tenant:', ai.`tenant_id`, ':model:invoice:prefix:INV')
  END
ON DUPLICATE KEY UPDATE
  `last_value` = GREATEST(`human_id_counter`.`last_value`, VALUES(`last_value`)),
  `updated_at` = NOW(3);

CREATE UNIQUE INDEX `accounts_invoice_tenant_id_human_friendly_id_key`
  ON `accounts_invoice`(`tenant_id`, `human_friendly_id`);
