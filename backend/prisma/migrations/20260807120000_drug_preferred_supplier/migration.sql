-- Optional preferred supplier attachment on pharmacy catalog drugs.
ALTER TABLE `drug`
  ADD COLUMN `supplier_id` VARCHAR(36) NULL AFTER `currency`;

CREATE INDEX `drug_supplier_id_idx` ON `drug`(`supplier_id`);

ALTER TABLE `drug`
  ADD CONSTRAINT `drug_supplier_id_fkey`
  FOREIGN KEY (`supplier_id`) REFERENCES `supplier`(`id`)
  ON DELETE SET NULL
  ON UPDATE CASCADE;
