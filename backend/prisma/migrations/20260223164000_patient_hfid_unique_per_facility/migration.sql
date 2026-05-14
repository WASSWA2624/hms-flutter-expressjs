-- CreateIndex
CREATE UNIQUE INDEX `patient_facility_id_human_friendly_id_key` ON `patient`(`facility_id`, `human_friendly_id`);
