-- Extend radiology modalities and persist structured imaging request details.
ALTER TABLE `radiology_test`
  MODIFY `modality` ENUM(
    'XRAY', 'CT', 'MRI', 'ULTRASOUND', 'FLUOROSCOPY', 'MAMMOGRAPHY',
    'PET', 'SPECT', 'NUCLEAR_MEDICINE', 'INTERVENTIONAL_RADIOLOGY',
    'ANGIOGRAPHY', 'DEXA', 'DENTAL', 'ECG', 'ECHO', 'ENDO', 'GASTRO', 'OTHER'
  ) NOT NULL;

ALTER TABLE `imaging_study`
  MODIFY `modality` ENUM(
    'XRAY', 'CT', 'MRI', 'ULTRASOUND', 'FLUOROSCOPY', 'MAMMOGRAPHY',
    'PET', 'SPECT', 'NUCLEAR_MEDICINE', 'INTERVENTIONAL_RADIOLOGY',
    'ANGIOGRAPHY', 'DEXA', 'DENTAL', 'ECG', 'ECHO', 'ENDO', 'GASTRO', 'OTHER'
  ) NOT NULL;

ALTER TABLE `radiology_order`
  ADD COLUMN `request_kind` VARCHAR(32) NULL AFTER `ordered_at`,
  ADD COLUMN `clinical_indication` TEXT NULL AFTER `request_kind`,
  ADD COLUMN `body_region` VARCHAR(120) NULL AFTER `clinical_indication`,
  ADD COLUMN `laterality` VARCHAR(40) NULL AFTER `body_region`,
  ADD COLUMN `contrast_preference` VARCHAR(60) NULL AFTER `laterality`,
  ADD COLUMN `priority` VARCHAR(40) NULL AFTER `contrast_preference`,
  ADD COLUMN `request_notes` TEXT NULL AFTER `priority`,
  ADD COLUMN `custom_request_details` JSON NULL AFTER `request_notes`;

CREATE INDEX `radiology_order_priority_idx` ON `radiology_order` (`priority`);
