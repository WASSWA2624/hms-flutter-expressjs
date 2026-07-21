-- Durable high-priority flag for visit queue entries (Reception Prioritize).
ALTER TABLE `visit_queue`
  ADD COLUMN `is_prioritized` BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX `visit_queue_is_prioritized_idx` ON `visit_queue`(`is_prioritized`);
