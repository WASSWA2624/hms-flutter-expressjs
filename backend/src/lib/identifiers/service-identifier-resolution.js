const { HttpError } = require('@lib/errors');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');

const FRIENDLY_IDENTIFIER_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;

const sanitizeIdentifier = (value) => (typeof value === 'string' ? value.trim() : '');

const isFriendlyIdentifierLike = (value) => FRIENDLY_IDENTIFIER_REGEX.test(sanitizeIdentifier(value));

const shouldPassThroughUnresolvedIdentifier = (value) => {
  const normalized = sanitizeIdentifier(value);
  if (!normalized) return false;
  if (isUuidLike(normalized)) return true;
  if (normalized !== normalized.toUpperCase()) return true;
  return !isFriendlyIdentifierLike(normalized);
};

const resolveIdentifierForFilter = async ({ value, model, where = {} }) => {
  if (value === undefined) return undefined;
  if (value === null) return null;

  const normalized = sanitizeIdentifier(value);
  if (!normalized) return undefined;

  const resolved = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where,
  });
  if (resolved) return resolved;
  if (shouldPassThroughUnresolvedIdentifier(normalized)) return normalized;
  return null;
};

const resolveIdentifierForPayload = async ({
  value,
  field,
  model,
  where = {},
  nullable = false,
}) => {
  if (value === undefined) return undefined;
  if (value === null) {
    if (nullable) return null;
    throw new HttpError('errors.validation.field.required', 400, [{ field }]);
  }

  const normalized = sanitizeIdentifier(value);
  if (!normalized) {
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }

  const resolved = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where,
  });
  if (resolved) return resolved;
  if (shouldPassThroughUnresolvedIdentifier(normalized)) return normalized;

  throw new HttpError('errors.validation.invalid', 400, [{ field }]);
};

module.exports = {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
};
