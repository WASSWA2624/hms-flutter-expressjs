const prisma = require('@prisma/client');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');

const normalizeIdentifier = (value) => (typeof value === 'string' ? value.trim() : '');

const isMissingIdentifier = (value) => normalizeIdentifier(value).length === 0;

const resolveModelRecordByIdentifier = async ({
  model,
  identifier,
  where = {},
  select = { id: true },
  include,
  includeDeleted = false,
  additionalFriendlyMatchers = [],
}) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;

  const delegate = prisma?.[model];
  if (!delegate || typeof delegate.findFirst !== 'function') {
    return null;
  }

  const baseWhere = { ...(where || {}) };
  if (!includeDeleted && baseWhere.deleted_at === undefined) {
    baseWhere.deleted_at = null;
  }

  const queryShape = include ? { include } : { select };

  if (isUuidLike(normalized)) {
    const uuidRecord = await delegate.findFirst({
      where: {
        ...baseWhere,
        id: normalized,
      },
      ...queryShape,
    });
    if (uuidRecord) return uuidRecord;
  }

  const upperIdentifier = normalized.toUpperCase();
  const friendlyMatchers = [{ human_friendly_id: upperIdentifier }];
  for (const matcher of additionalFriendlyMatchers || []) {
    if (typeof matcher === 'function') {
      const clause = matcher(normalized, upperIdentifier);
      if (clause && typeof clause === 'object') {
        friendlyMatchers.push(clause);
      }
    }
  }

  const whereClause =
    friendlyMatchers.length === 1
      ? {
          ...baseWhere,
          human_friendly_id: upperIdentifier,
        }
      : {
          ...baseWhere,
          OR: friendlyMatchers,
        };

  return delegate.findFirst({
    where: whereClause,
    ...queryShape,
  });
};

const resolveModelIdByIdentifier = async (options) => {
  const record = await resolveModelRecordByIdentifier(options);
  return record?.id || null;
};

module.exports = {
  normalizeIdentifier,
  isMissingIdentifier,
  resolveModelRecordByIdentifier,
  resolveModelIdByIdentifier,
};
