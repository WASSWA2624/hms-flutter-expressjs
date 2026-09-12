-- Close a cross-tenant leak on clinical records.
--
-- The Prisma tenant guard scopes a query only when the model carries a
-- `tenant_id` column; `tenant-guard.js` returns the query untouched otherwise.
-- Twenty-two tables holding patient data reach their tenant only through
-- `patient`, `encounter` or `admission`, so the guard skipped them entirely and
-- isolation depended on every service remembering a join filter. Several did
-- not: the radiology worklist, for one, builds its where-clause from `{}`.
--
-- Measured on production before this migration, reading as a tenant that owns
-- zero patients:
--
--     radiology_order  1001 visible   (1001 exist in total)
--     theatre_case     1000 visible   (1000 exist in total)
--     lab_order        1002 visible   (1002 exist in total)
--     follow_up        1000 visible   (1000 exist in total)
--
-- Every tenant could read every other tenant's clinical records.
--
-- Giving these tables their own `tenant_id` puts them inside the guard, which
-- then scopes reads and stamps the acting tenant on writes automatically - the
-- same protection the rest of the schema already has, rather than a second
-- mechanism that has to be remembered.
--
-- The column is added and backfilled in the same migration on purpose. The
-- guard starts enforcing the moment the regenerated client sees the column, so
-- a gap between the two would make existing rows invisible to their own tenant.
-- Backfill order is patient, then encounter, then admission: the most direct
-- parent wins, and later statements only touch rows still NULL.
--
-- Left nullable rather than NOT NULL. A row whose parent is missing would
-- otherwise block the migration, and a NULL tenant_id fails closed under the
-- guard - invisible rather than leaked.
--
-- Idempotent throughout: guarded with information_schema so re-running is safe,
-- and every UPDATE is qualified with `tenant_id IS NULL`.

-- adverse_event: tenant via patient_id -> patient
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'adverse_event' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `adverse_event` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `adverse_event` c
  JOIN `patient` p ON p.id = c.`patient_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`patient_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'adverse_event' AND INDEX_NAME = 'adverse_event_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `adverse_event_tenant_id_idx` ON `adverse_event`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- bed_assignment: tenant via admission_id -> admission
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bed_assignment' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `bed_assignment` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `bed_assignment` c
  JOIN `admission` p ON p.id = c.`admission_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`admission_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bed_assignment' AND INDEX_NAME = 'bed_assignment_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `bed_assignment_tenant_id_idx` ON `bed_assignment`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- care_plan: tenant via encounter_id -> encounter
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'care_plan' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `care_plan` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `care_plan` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'care_plan' AND INDEX_NAME = 'care_plan_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `care_plan_tenant_id_idx` ON `care_plan`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- clinical_alert: tenant via encounter_id -> encounter
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'clinical_alert' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `clinical_alert` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `clinical_alert` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'clinical_alert' AND INDEX_NAME = 'clinical_alert_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `clinical_alert_tenant_id_idx` ON `clinical_alert`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- clinical_note: tenant via encounter_id -> encounter
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'clinical_note' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `clinical_note` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `clinical_note` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'clinical_note' AND INDEX_NAME = 'clinical_note_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `clinical_note_tenant_id_idx` ON `clinical_note`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- diagnosis: tenant via encounter_id -> encounter
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'diagnosis' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `diagnosis` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `diagnosis` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'diagnosis' AND INDEX_NAME = 'diagnosis_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `diagnosis_tenant_id_idx` ON `diagnosis`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- discharge_summary: tenant via admission_id -> admission
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'discharge_summary' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `discharge_summary` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `discharge_summary` c
  JOIN `admission` p ON p.id = c.`admission_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`admission_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'discharge_summary' AND INDEX_NAME = 'discharge_summary_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `discharge_summary_tenant_id_idx` ON `discharge_summary`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- follow_up: tenant via encounter_id -> encounter
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'follow_up' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `follow_up` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `follow_up` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'follow_up' AND INDEX_NAME = 'follow_up_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `follow_up_tenant_id_idx` ON `follow_up`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- icu_stay: tenant via admission_id -> admission
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'icu_stay' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `icu_stay` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `icu_stay` c
  JOIN `admission` p ON p.id = c.`admission_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`admission_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'icu_stay' AND INDEX_NAME = 'icu_stay_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `icu_stay_tenant_id_idx` ON `icu_stay`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- lab_order: tenant via patient_id -> patient, encounter_id -> encounter
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lab_order' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `lab_order` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `lab_order` c
  JOIN `patient` p ON p.id = c.`patient_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`patient_id` IS NOT NULL;
UPDATE `lab_order` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lab_order' AND INDEX_NAME = 'lab_order_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `lab_order_tenant_id_idx` ON `lab_order`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- medication_administration: tenant via admission_id -> admission
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'medication_administration' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `medication_administration` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `medication_administration` c
  JOIN `admission` p ON p.id = c.`admission_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`admission_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'medication_administration' AND INDEX_NAME = 'medication_administration_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `medication_administration_tenant_id_idx` ON `medication_administration`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- nursing_note: tenant via admission_id -> admission
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'nursing_note' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `nursing_note` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `nursing_note` c
  JOIN `admission` p ON p.id = c.`admission_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`admission_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'nursing_note' AND INDEX_NAME = 'nursing_note_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `nursing_note_tenant_id_idx` ON `nursing_note`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- pharmacy_order: tenant via patient_id -> patient, encounter_id -> encounter
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pharmacy_order' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `pharmacy_order` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `pharmacy_order` c
  JOIN `patient` p ON p.id = c.`patient_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`patient_id` IS NOT NULL;
UPDATE `pharmacy_order` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pharmacy_order' AND INDEX_NAME = 'pharmacy_order_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `pharmacy_order_tenant_id_idx` ON `pharmacy_order`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- pre_authorization: tenant via patient_id -> patient, encounter_id -> encounter, admission_id -> admission
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pre_authorization' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `pre_authorization` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `pre_authorization` c
  JOIN `patient` p ON p.id = c.`patient_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`patient_id` IS NOT NULL;
UPDATE `pre_authorization` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
UPDATE `pre_authorization` c
  JOIN `admission` p ON p.id = c.`admission_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`admission_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pre_authorization' AND INDEX_NAME = 'pre_authorization_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `pre_authorization_tenant_id_idx` ON `pre_authorization`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- procedure: tenant via encounter_id -> encounter
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'procedure' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `procedure` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `procedure` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'procedure' AND INDEX_NAME = 'procedure_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `procedure_tenant_id_idx` ON `procedure`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- radiology_order: tenant via patient_id -> patient, encounter_id -> encounter
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'radiology_order' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `radiology_order` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `radiology_order` c
  JOIN `patient` p ON p.id = c.`patient_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`patient_id` IS NOT NULL;
UPDATE `radiology_order` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'radiology_order' AND INDEX_NAME = 'radiology_order_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `radiology_order_tenant_id_idx` ON `radiology_order`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- referral: tenant via encounter_id -> encounter
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'referral' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `referral` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `referral` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'referral' AND INDEX_NAME = 'referral_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `referral_tenant_id_idx` ON `referral`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- theatre_case: tenant via encounter_id -> encounter, admission_id -> admission
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'theatre_case' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `theatre_case` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `theatre_case` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
UPDATE `theatre_case` c
  JOIN `admission` p ON p.id = c.`admission_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`admission_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'theatre_case' AND INDEX_NAME = 'theatre_case_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `theatre_case_tenant_id_idx` ON `theatre_case`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- therapy_episode: tenant via encounter_id -> encounter, admission_id -> admission
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'therapy_episode' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `therapy_episode` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `therapy_episode` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
UPDATE `therapy_episode` c
  JOIN `admission` p ON p.id = c.`admission_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`admission_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'therapy_episode' AND INDEX_NAME = 'therapy_episode_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `therapy_episode_tenant_id_idx` ON `therapy_episode`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- transfer_request: tenant via admission_id -> admission
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'transfer_request' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `transfer_request` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `transfer_request` c
  JOIN `admission` p ON p.id = c.`admission_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`admission_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'transfer_request' AND INDEX_NAME = 'transfer_request_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `transfer_request_tenant_id_idx` ON `transfer_request`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- vital_sign: tenant via encounter_id -> encounter
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vital_sign' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `vital_sign` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `vital_sign` c
  JOIN `encounter` p ON p.id = c.`encounter_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`encounter_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vital_sign' AND INDEX_NAME = 'vital_sign_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `vital_sign_tenant_id_idx` ON `vital_sign`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- ward_round: tenant via admission_id -> admission
SET @c := (SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ward_round' AND COLUMN_NAME = 'tenant_id');
SET @s := IF(@c = 0,
  'ALTER TABLE `ward_round` ADD COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
UPDATE `ward_round` c
  JOIN `admission` p ON p.id = c.`admission_id`
   SET c.tenant_id = p.tenant_id
 WHERE c.tenant_id IS NULL AND c.`admission_id` IS NOT NULL;
SET @i := (SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ward_round' AND INDEX_NAME = 'ward_round_tenant_id_idx');
SET @s := IF(@i = 0,
  'CREATE INDEX `ward_round_tenant_id_idx` ON `ward_round`(`tenant_id`)',
  'SELECT 1');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

