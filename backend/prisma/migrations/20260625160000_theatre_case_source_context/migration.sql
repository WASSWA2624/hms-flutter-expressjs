-- Theatre case source context and cross-module linkage
ALTER TABLE `theatre_case`
  ADD COLUMN `emergency_case_id` VARCHAR(36) NULL,
  ADD COLUMN `admission_id` VARCHAR(36) NULL,
  ADD COLUMN `procedure_name` VARCHAR(255) NULL,
  ADD COLUMN `source_kind` VARCHAR(40) NULL,
  ADD COLUMN `handover_destination` VARCHAR(40) NULL;

CREATE INDEX `theatre_case_emergency_case_id_idx` ON `theatre_case`(`emergency_case_id`);
CREATE INDEX `theatre_case_admission_id_idx` ON `theatre_case`(`admission_id`);

ALTER TABLE `theatre_case`
  ADD CONSTRAINT `theatre_case_emergency_case_id_fkey`
    FOREIGN KEY (`emergency_case_id`) REFERENCES `emergency_case`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `theatre_case`
  ADD CONSTRAINT `theatre_case_admission_id_fkey`
    FOREIGN KEY (`admission_id`) REFERENCES `admission`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE;
