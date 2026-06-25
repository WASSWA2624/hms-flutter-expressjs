-- Request-time billing snapshots for IPD ward rounds, theatre cases, and clinical procedures
ALTER TABLE `ward_round`
  ADD COLUMN `billing_snapshot` JSON NULL AFTER `notes`;

ALTER TABLE `procedure`
  ADD COLUMN `billing_snapshot` JSON NULL AFTER `performed_at`;

ALTER TABLE `theatre_case`
  ADD COLUMN `billing_snapshot` JSON NULL AFTER `stage_notes`;
