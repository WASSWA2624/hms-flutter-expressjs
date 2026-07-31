-- Repair radiology billing snapshots created before invoice reconciliation
-- propagated payment status back to radiology orders.
UPDATE `radiology_order` o
INNER JOIN `invoice` i
  ON i.`id` = JSON_UNQUOTE(
    JSON_EXTRACT(o.`request_details`, '$.billing.invoice_id')
  )
SET o.`request_details` = JSON_SET(
  o.`request_details`,
  '$.billing.payment_status',
  CASE
    WHEN i.`billing_status` = 'PAID' THEN 'PAID'
    WHEN i.`billing_status` = 'PARTIAL' THEN 'PARTIAL'
    ELSE 'PENDING'
  END,
  '$.billing.invoice_status',
  i.`status`,
  '$.billing.billing_status',
  i.`billing_status`
)
WHERE o.`deleted_at` IS NULL
  AND i.`deleted_at` IS NULL
  AND JSON_EXTRACT(o.`request_details`, '$.billing.invoice_id') IS NOT NULL;
