-- Refine clinical medication and imaging order workflows.
-- Adds structured prescription fields, structured radiology request metadata,
-- and expands clinically relevant medication/radiology enum values.

ALTER TABLE `pharmacy_order_item`
  ADD COLUMN `quantity_unit` VARCHAR(40) NULL,
  MODIFY COLUMN `dose_amount` DECIMAL(10, 3) NULL,
  MODIFY COLUMN `dose_unit` VARCHAR(40) NULL,
  MODIFY COLUMN `duration_unit` VARCHAR(40) NULL;

ALTER TABLE `pharmacy_order_item`
  MODIFY `frequency` ENUM('ONCE', 'OD', 'BID', 'TID', 'QID', 'Q4H', 'Q6H', 'Q8H', 'Q12H', 'QHS', 'WEEKLY', 'PRN', 'STAT', 'CUSTOM') NULL,
  MODIFY `route` ENUM('ORAL', 'IV', 'IM', 'SC', 'SUBLINGUAL', 'RECTAL', 'VAGINAL', 'TOPICAL', 'INHALATION', 'OPHTHALMIC', 'OTIC', 'NASAL', 'INTRADERMAL', 'OTHER') NULL;

CREATE INDEX `pharmacy_order_item_duration_unit_idx` ON `pharmacy_order_item`(`duration_unit`);
CREATE INDEX `pharmacy_order_item_dose_unit_idx` ON `pharmacy_order_item`(`dose_unit`);

ALTER TABLE `radiology_order`
  ADD COLUMN `clinical_note` TEXT NULL,
  ADD COLUMN `request_details` JSON NULL;

ALTER TABLE `radiology_test`
  MODIFY `modality` ENUM('XRAY', 'CT', 'MRI', 'ULTRASOUND', 'FLUOROSCOPY', 'MAMMOGRAPHY', 'PET', 'NUCLEAR_MEDICINE', 'INTERVENTIONAL_RADIOLOGY', 'ECG', 'ECHO', 'ENDO', 'GASTRO', 'OTHER') NOT NULL;

ALTER TABLE `imaging_study`
  MODIFY `modality` ENUM('XRAY', 'CT', 'MRI', 'ULTRASOUND', 'FLUOROSCOPY', 'MAMMOGRAPHY', 'PET', 'NUCLEAR_MEDICINE', 'INTERVENTIONAL_RADIOLOGY', 'ECG', 'ECHO', 'ENDO', 'GASTRO', 'OTHER') NOT NULL;
