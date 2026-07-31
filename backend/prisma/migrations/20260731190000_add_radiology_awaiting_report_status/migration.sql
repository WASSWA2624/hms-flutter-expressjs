-- Add explicit AWAITING_REPORT state to the radiology order lifecycle:
-- ORDERED / IN_PROCESS (procedure not done) -> AWAITING_REPORT (procedure done,
-- report not ready) -> COMPLETED (report released as FINAL/AMENDED).
ALTER TABLE `radiology_order`
  MODIFY `status` ENUM('ORDERED', 'IN_PROCESS', 'AWAITING_REPORT', 'COMPLETED', 'CANCELLED') NOT NULL;

-- Backfill: any order with a released (FINAL/AMENDED) report is COMPLETED.
UPDATE `radiology_order` o
SET o.`status` = 'COMPLETED'
WHERE o.`status` <> 'CANCELLED'
  AND EXISTS (
    SELECT 1 FROM `radiology_result` r
    WHERE r.`radiology_order_id` = o.`id`
      AND r.`deleted_at` IS NULL
      AND r.`status` IN ('FINAL', 'AMENDED')
  );

-- Backfill: procedure done (study recorded, draft report started, or legacy
-- COMPLETED without a released report) but report not ready -> AWAITING_REPORT.
UPDATE `radiology_order` o
SET o.`status` = 'AWAITING_REPORT'
WHERE o.`status` IN ('ORDERED', 'IN_PROCESS', 'COMPLETED')
  AND NOT EXISTS (
    SELECT 1 FROM `radiology_result` r
    WHERE r.`radiology_order_id` = o.`id`
      AND r.`deleted_at` IS NULL
      AND r.`status` IN ('FINAL', 'AMENDED')
  )
  AND (
    o.`status` = 'COMPLETED'
    OR EXISTS (
      SELECT 1 FROM `imaging_study` s
      WHERE s.`radiology_order_id` = o.`id`
        AND s.`deleted_at` IS NULL
    )
    OR EXISTS (
      SELECT 1 FROM `radiology_result` d
      WHERE d.`radiology_order_id` = o.`id`
        AND d.`deleted_at` IS NULL
        AND d.`status` = 'DRAFT'
    )
  );
