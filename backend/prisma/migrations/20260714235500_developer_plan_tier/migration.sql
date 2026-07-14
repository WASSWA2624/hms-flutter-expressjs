ALTER TABLE `subscription_plan`
  MODIFY `tier_code`
    ENUM('FREE', 'BASIC', 'ADVANCED', 'PRO', 'CUSTOM', 'DEVELOPER') NULL;

ALTER TABLE `module`
  MODIFY `minimum_plan_tier_code`
    ENUM('FREE', 'BASIC', 'ADVANCED', 'PRO', 'CUSTOM', 'DEVELOPER') NULL;

ALTER TABLE `license`
  MODIFY `plan_tier_code`
    ENUM('FREE', 'BASIC', 'ADVANCED', 'PRO', 'CUSTOM', 'DEVELOPER') NULL;

-- Rollback requires first replacing any DEVELOPER values with CUSTOM, then:
-- ALTER TABLE `subscription_plan` MODIFY `tier_code`
--   ENUM('FREE', 'BASIC', 'PRO', 'ADVANCED', 'CUSTOM') NULL;
-- ALTER TABLE `module` MODIFY `minimum_plan_tier_code`
--   ENUM('FREE', 'BASIC', 'PRO', 'ADVANCED', 'CUSTOM') NULL;
-- ALTER TABLE `license` MODIFY `plan_tier_code`
--   ENUM('FREE', 'BASIC', 'PRO', 'ADVANCED', 'CUSTOM') NULL;
