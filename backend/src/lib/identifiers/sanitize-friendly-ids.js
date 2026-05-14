/**
 * Friendly-ID sanitizer.
 *
 * Compatibility contract:
 * - Keep machine identifiers unchanged (`id`, `*_id`, and other UUID-like values).
 * - Preserve payload shape and special values (Date, Buffer, etc.).
 *
 * This keeps frontend/backend request contracts stable while friendly-id
 * rollout continues incrementally per endpoint.
 */

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const isUuidLike = (value) => {
  if (typeof value !== 'string') return false;
  return UUID_REGEX.test(value.trim());
};

const sanitizeFriendlyIds = (payload) => payload;

module.exports = {
  sanitizeFriendlyIds,
  isUuidLike,
};
