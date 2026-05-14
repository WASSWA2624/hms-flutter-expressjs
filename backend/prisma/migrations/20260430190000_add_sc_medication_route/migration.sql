-- Add subcutaneous (SC) medication route.

ALTER TABLE `pharmacy_order_item`
  MODIFY COLUMN `route` ENUM('ORAL', 'IV', 'IM', 'SC', 'TOPICAL', 'INHALATION', 'OTHER') NULL;