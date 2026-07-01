-- AlterTable shift_template: add weekly_schedule_json for multi-day patterns
ALTER TABLE `shift_template` ADD COLUMN `weekly_schedule_json` JSON NULL;

-- Backfill Mon–Fri from legacy default_start_time / default_end_time
UPDATE `shift_template`
SET `weekly_schedule_json` = JSON_ARRAY(
  JSON_OBJECT('day_of_week', 1, 'time_slots', JSON_ARRAY(JSON_OBJECT('start_time', `default_start_time`, 'end_time', `default_end_time`))),
  JSON_OBJECT('day_of_week', 2, 'time_slots', JSON_ARRAY(JSON_OBJECT('start_time', `default_start_time`, 'end_time', `default_end_time`))),
  JSON_OBJECT('day_of_week', 3, 'time_slots', JSON_ARRAY(JSON_OBJECT('start_time', `default_start_time`, 'end_time', `default_end_time`))),
  JSON_OBJECT('day_of_week', 4, 'time_slots', JSON_ARRAY(JSON_OBJECT('start_time', `default_start_time`, 'end_time', `default_end_time`))),
  JSON_OBJECT('day_of_week', 5, 'time_slots', JSON_ARRAY(JSON_OBJECT('start_time', `default_start_time`, 'end_time', `default_end_time`)))
)
WHERE `weekly_schedule_json` IS NULL
  AND `default_start_time` IS NOT NULL
  AND `default_end_time` IS NOT NULL;
