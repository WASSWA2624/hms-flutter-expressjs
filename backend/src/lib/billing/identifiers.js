const { HttpError } = require('@lib/errors');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');

const sanitizeIdentifier = (value) => (typeof value === 'string' ? value.trim() : '');

const resolvePublicIdentifier = (...values) => {
  for (const value of values) {
    const normalized = sanitizeIdentifier(value);
    if (!normalized) continue;
    if (!isUuidLike(normalized)) return normalized;
  }
  return null;
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
  if (isUuidLike(normalized)) return normalized;
  return null;
};

const resolveIdentifierForPayload = async ({
  value,
  model,
  field,
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
  if (isUuidLike(normalized)) return normalized;
  throw new HttpError('errors.validation.invalid', 400, [{ field }]);
};

const resolveEntityId = async ({ model, identifier, where = {} }) => {
  const normalized = sanitizeIdentifier(identifier);
  if (!normalized) return normalized;

  const resolved = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where,
  });

  return resolved || normalized;
};

module.exports = {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
};
