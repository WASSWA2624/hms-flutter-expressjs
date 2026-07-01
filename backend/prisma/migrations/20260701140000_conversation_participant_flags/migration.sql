-- Add per-participant inbox flags for favorites and follow-up.
ALTER TABLE `conversation_participant`
  ADD COLUMN `is_favorite` BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN `is_flagged` BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX `conversation_participant_is_favorite_idx` ON `conversation_participant`(`is_favorite`);
CREATE INDEX `conversation_participant_is_flagged_idx` ON `conversation_participant`(`is_flagged`);
