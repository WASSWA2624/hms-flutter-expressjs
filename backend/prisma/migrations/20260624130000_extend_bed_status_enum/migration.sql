-- Extend bed operational statuses for IPD bed board (cleaning, maintenance, blocked).
ALTER TABLE `bed`
  MODIFY COLUMN `status` ENUM(
    'AVAILABLE',
    'OCCUPIED',
    'RESERVED',
    'CLEANING',
    'MAINTENANCE',
    'BLOCKED',
    'OUT_OF_SERVICE'
  ) NOT NULL;
