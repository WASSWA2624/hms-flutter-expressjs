-- Durable controlled-drug marker for pharmacy balance / regulatory reports.
ALTER TABLE `drug`
  ADD COLUMN `is_controlled` BOOLEAN NOT NULL DEFAULT false AFTER `supplier_id`;

CREATE INDEX `drug_is_controlled_idx` ON `drug`(`is_controlled`);
