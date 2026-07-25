-- Remove org Branch entity. Multi-site scoping remains on Facility.

-- Backfill facility_id from branch before dropping FKs.
UPDATE department d
INNER JOIN branch b ON b.id = d.branch_id
SET d.facility_id = COALESCE(d.facility_id, b.facility_id)
WHERE d.branch_id IS NOT NULL
  AND d.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE address a
INNER JOIN branch b ON b.id = a.branch_id
SET a.facility_id = COALESCE(a.facility_id, b.facility_id)
WHERE a.branch_id IS NOT NULL
  AND a.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE contact c
INNER JOIN branch b ON b.id = c.branch_id
SET c.facility_id = COALESCE(c.facility_id, b.facility_id)
WHERE c.branch_id IS NOT NULL
  AND c.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE abac_policy p
INNER JOIN branch b ON b.id = p.branch_id
SET p.facility_id = COALESCE(p.facility_id, b.facility_id)
WHERE p.branch_id IS NOT NULL
  AND p.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE break_glass_access g
INNER JOIN branch b ON b.id = g.branch_id
SET g.facility_id = COALESCE(g.facility_id, b.facility_id)
WHERE g.branch_id IS NOT NULL
  AND g.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE office_context o
INNER JOIN branch b ON b.id = o.branch_id
SET o.facility_id = COALESCE(o.facility_id, b.facility_id)
WHERE o.branch_id IS NOT NULL
  AND o.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE shift_close s
INNER JOIN branch b ON b.id = s.branch_id
SET s.facility_id = COALESCE(s.facility_id, b.facility_id)
WHERE s.branch_id IS NOT NULL
  AND s.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE day_close d
INNER JOIN branch b ON b.id = d.branch_id
SET d.facility_id = COALESCE(d.facility_id, b.facility_id)
WHERE d.branch_id IS NOT NULL
  AND d.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE handover h
INNER JOIN branch b ON b.id = h.branch_id
SET h.facility_id = COALESCE(h.facility_id, b.facility_id)
WHERE h.branch_id IS NOT NULL
  AND h.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE custody_snapshot c
INNER JOIN branch b ON b.id = c.branch_id
SET c.facility_id = COALESCE(c.facility_id, b.facility_id)
WHERE c.branch_id IS NOT NULL
  AND c.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE closeout_pack p
INNER JOIN branch b ON b.id = p.branch_id
SET p.facility_id = COALESCE(p.facility_id, b.facility_id)
WHERE p.branch_id IS NOT NULL
  AND p.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE analytics_event a
INNER JOIN branch b ON b.id = a.branch_id
SET a.facility_id = COALESCE(a.facility_id, b.facility_id)
WHERE a.branch_id IS NOT NULL
  AND a.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

UPDATE kpi_snapshot k
INNER JOIN branch b ON b.id = k.branch_id
SET k.facility_id = COALESCE(k.facility_id, b.facility_id)
WHERE k.branch_id IS NOT NULL
  AND k.facility_id IS NULL
  AND b.facility_id IS NOT NULL;

-- Drop FKs that reference branch.
ALTER TABLE `department` DROP FOREIGN KEY `department_branch_id_fkey`;
ALTER TABLE `address` DROP FOREIGN KEY `address_branch_id_fkey`;
ALTER TABLE `contact` DROP FOREIGN KEY `contact_branch_id_fkey`;
ALTER TABLE `abac_policy` DROP FOREIGN KEY `abac_policy_branch_id_fkey`;
ALTER TABLE `break_glass_access` DROP FOREIGN KEY `break_glass_access_branch_id_fkey`;
ALTER TABLE `office_context` DROP FOREIGN KEY `office_context_branch_id_fkey`;
ALTER TABLE `shift_close` DROP FOREIGN KEY `shift_close_branch_id_fkey`;
ALTER TABLE `day_close` DROP FOREIGN KEY `day_close_branch_id_fkey`;
ALTER TABLE `handover` DROP FOREIGN KEY `handover_branch_id_fkey`;
ALTER TABLE `custody_snapshot` DROP FOREIGN KEY `custody_snapshot_branch_id_fkey`;
ALTER TABLE `closeout_pack` DROP FOREIGN KEY `closeout_pack_branch_id_fkey`;
ALTER TABLE `analytics_event` DROP FOREIGN KEY `analytics_event_branch_id_fkey`;
ALTER TABLE `kpi_snapshot` DROP FOREIGN KEY `kpi_snapshot_branch_id_fkey`;

-- Drop indexes on branch_id.
DROP INDEX `department_branch_id_idx` ON `department`;
DROP INDEX `address_branch_id_idx` ON `address`;
DROP INDEX `contact_branch_id_idx` ON `contact`;
DROP INDEX `abac_policy_branch_id_idx` ON `abac_policy`;
DROP INDEX `break_glass_access_branch_id_idx` ON `break_glass_access`;
DROP INDEX `office_context_branch_id_idx` ON `office_context`;
DROP INDEX `shift_close_branch_id_idx` ON `shift_close`;
DROP INDEX `day_close_branch_id_idx` ON `day_close`;
DROP INDEX `handover_branch_id_idx` ON `handover`;
DROP INDEX `custody_snapshot_branch_id_idx` ON `custody_snapshot`;
DROP INDEX `closeout_pack_branch_id_idx` ON `closeout_pack`;
DROP INDEX `analytics_event_branch_id_idx` ON `analytics_event`;
DROP INDEX `kpi_snapshot_branch_id_idx` ON `kpi_snapshot`;

-- Drop branch_id columns.
ALTER TABLE `department` DROP COLUMN `branch_id`;
ALTER TABLE `address` DROP COLUMN `branch_id`;
ALTER TABLE `contact` DROP COLUMN `branch_id`;
ALTER TABLE `abac_policy` DROP COLUMN `branch_id`;
ALTER TABLE `break_glass_access` DROP COLUMN `branch_id`;
ALTER TABLE `office_context` DROP COLUMN `branch_id`;
ALTER TABLE `shift_close` DROP COLUMN `branch_id`;
ALTER TABLE `day_close` DROP COLUMN `branch_id`;
ALTER TABLE `handover` DROP COLUMN `branch_id`;
ALTER TABLE `custody_snapshot` DROP COLUMN `branch_id`;
ALTER TABLE `closeout_pack` DROP COLUMN `branch_id`;
ALTER TABLE `analytics_event` DROP COLUMN `branch_id`;
ALTER TABLE `kpi_snapshot` DROP COLUMN `branch_id`;

-- Drop branch table FKs then table.
ALTER TABLE `branch` DROP FOREIGN KEY `branch_tenant_id_fkey`;
ALTER TABLE `branch` DROP FOREIGN KEY `branch_facility_id_fkey`;
DROP TABLE `branch`;
