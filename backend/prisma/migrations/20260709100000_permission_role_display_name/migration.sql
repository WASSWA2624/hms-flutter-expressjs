-- Add human-readable display names for canonical permissions and roles.
ALTER TABLE `permission`
  ADD COLUMN `display_name` VARCHAR(160) NULL AFTER `name`;

ALTER TABLE `role`
  ADD COLUMN `display_name` VARCHAR(160) NULL AFTER `name`;
