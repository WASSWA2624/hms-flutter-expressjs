-- CreateIndex
CREATE INDEX `patient_contact_value_idx` ON `patient_contact`(`value`);

-- CreateIndex
CREATE INDEX `patient_guardian_phone_idx` ON `patient_guardian`(`phone`);

-- CreateIndex
CREATE INDEX `patient_guardian_email_idx` ON `patient_guardian`(`email`);

-- CreateIndex
CREATE INDEX `patient_allergy_allergen_idx` ON `patient_allergy`(`allergen`);

-- CreateIndex
CREATE INDEX `patient_medical_history_condition_idx` ON `patient_medical_history`(`condition`);

-- CreateIndex
CREATE INDEX `patient_document_file_name_idx` ON `patient_document`(`file_name`);