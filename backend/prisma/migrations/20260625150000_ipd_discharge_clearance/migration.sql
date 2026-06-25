-- IPD multi-step discharge clearance snapshot on discharge summaries.
ALTER TABLE `discharge_summary`
  ADD COLUMN `clearance_snapshot` JSON NULL;
