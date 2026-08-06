-- Pharmacy buy (COGS) and pharmacy→facility transfer price on drug catalog.
ALTER TABLE `drug`
  ADD COLUMN `buy_unit_price` DECIMAL(12, 2) NULL AFTER `strength`,
  ADD COLUMN `transfer_unit_price` DECIMAL(12, 2) NULL AFTER `unit_price`;
