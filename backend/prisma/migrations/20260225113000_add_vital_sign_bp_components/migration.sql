-- AlterTable
ALTER TABLE `vital_sign`
  ADD COLUMN `systolic_value` DECIMAL(6, 2) NULL,
  ADD COLUMN `diastolic_value` DECIMAL(6, 2) NULL,
  ADD COLUMN `map_value` DECIMAL(6, 2) NULL;
