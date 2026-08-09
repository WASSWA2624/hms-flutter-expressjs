-- AlterTable nurse_roster: named rosters + recurrence flag for HR Rosters CRUD
ALTER TABLE `nurse_roster` ADD COLUMN `name` VARCHAR(255) NULL;
ALTER TABLE `nurse_roster` ADD COLUMN `is_recurring` BOOLEAN NOT NULL DEFAULT false;
