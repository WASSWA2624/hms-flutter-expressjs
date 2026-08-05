-- AlterTable
ALTER TABLE `encounter` MODIFY `encounter_type` ENUM('OPD', 'IPD', 'ICU', 'THEATRE', 'EMERGENCY', 'TELEMEDICINE', 'LAB') NOT NULL;
