/**
 * Clinical term service
 *
 * @module modules/clinical-term/services
 * @description Suggestions and favorites for diagnosis/procedure coding assistance.
 */

const clinicalTermRepository = require('@repositories/clinical-term/clinical-term.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { ROLES } = require('@config/roles');

const SHARED_FAVORITE_ROLES = new Set([
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
]);

const normalizeText = (value) => String(value || '').trim();
const normalizeUpper = (value, fallback = '') => {
  const normalized = normalizeText(value).toUpperCase();
  return normalized || fallback;
};
const normalizeTermType = (value) => normalizeUpper(value, 'DIAGNOSIS');
const normalizeScope = (value) => normalizeUpper(value, 'PERSONAL');

const resolveUserRoles = (context = {}) =>
  (Array.isArray(context.roles) ? context.roles : context.role ? [context.role] : [])
    .map((role) => normalizeUpper(role))
    .filter(Boolean);

const canManageSharedFavorite = (context = {}) => {
  const roles = resolveUserRoles(context);
  return roles.some((role) => SHARED_FAVORITE_ROLES.has(role));
};

const buildSuggestionKey = (code, description) =>
  `${normalizeUpper(code)}::${normalizeUpper(description)}`;

const scoreSuggestion = ({ q, source, createdAt, usageCount }) => {
  const search = normalizeUpper(q);
  const description = normalizeUpper(source.description);
  const code = normalizeUpper(source.code);
  let score = 0;

  if (source.origin === 'PERSONAL_FAVORITE') score += 120;
  if (source.origin === 'SHARED_FAVORITE') score += 90;
  if (source.origin === 'RECENT_HISTORY') score += 60;

  if (!search) score += 5;
  if (search) {
    if (description.startsWith(search)) score += 25;
    if (code.startsWith(search)) score += 25;
    if (description.includes(search)) score += 10;
    if (code.includes(search)) score += 10;
  }

  score += Math.min(Number(usageCount || 0), 25);

  if (createdAt) {
    const ageMs = Date.now() - new Date(createdAt).getTime();
    const ageDays = Math.max(0, ageMs / (24 * 60 * 60 * 1000));
    score += Math.max(0, 30 - ageDays);
  }

  return score;
};

const listClinicalTermFavorites = async (filters = {}, context = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id || null;
  if (!tenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }
  const userId = context.user_id || null;
  if (!userId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'user_id' }]);
  }

  const scope = filters.scope ? normalizeScope(filters.scope) : null;
  const termType = filters.term_type ? normalizeTermType(filters.term_type) : null;
  const q = normalizeText(filters.q);
  const facilityId =
    filters.facility_id !== undefined
      ? filters.facility_id || null
      : context.facility_id || null;

  const where = {
    tenant_id: tenantId,
    deleted_at: null,
    ...(termType ? { term_type: termType } : {}),
  };

  if (scope === 'PERSONAL') {
    where.scope = 'PERSONAL';
    where.owner_user_id = userId;
  } else if (scope === 'SHARED') {
    where.scope = 'SHARED';
    if (facilityId) {
      where.OR = [{ facility_id: facilityId }, { facility_id: null }];
    }
  } else {
    where.OR = [
      { scope: 'PERSONAL', owner_user_id: userId },
      {
        scope: 'SHARED',
        ...(facilityId ? { OR: [{ facility_id: facilityId }, { facility_id: null }] } : {}),
      },
    ];
  }

  if (q) {
    const queryValue = normalizeUpper(q);
    where.AND = [
      ...(where.AND || []),
      {
        OR: [
          { code: { contains: queryValue } },
          { description: { contains: q } },
        ],
      },
    ];
  }

  return clinicalTermRepository.findFavorites(where);
};

const createClinicalTermFavorite = async (payload = {}, context = {}) => {
  const tenantId = context.tenant_id || payload.tenant_id || null;
  const userId = context.user_id || null;
  if (!tenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }
  if (!userId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'user_id' }]);
  }

  const termType = normalizeTermType(payload.term_type);
  const scope = normalizeScope(payload.scope || 'PERSONAL');
  const code = normalizeText(payload.code) || null;
  const description = normalizeText(payload.description);
  const facilityId = payload.facility_id || context.facility_id || null;
  const ownerUserId = scope === 'PERSONAL' ? userId : null;

  if (!description) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'description' }]);
  }

  if (scope === 'SHARED' && !canManageSharedFavorite(context)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  const existing = await clinicalTermRepository.findFavorite({
    tenant_id: tenantId,
    facility_id: facilityId,
    owner_user_id: ownerUserId,
    scope,
    term_type: termType,
    code,
    description,
    deleted_at: null,
  });

  const favorite =
    existing ||
    (await clinicalTermRepository.createFavorite({
      tenant_id: tenantId,
      facility_id: facilityId,
      owner_user_id: ownerUserId,
      term_type: termType,
      scope,
      code,
      description,
    }));

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: existing ? 'READ' : 'CREATE',
    entity: 'clinical_term_favorite',
    entity_id: favorite.id,
    diff: { after: favorite },
    ip_address: context.ip_address,
  }).catch(() => {});

  return favorite;
};

const deleteClinicalTermFavorite = async (id, context = {}) => {
  const tenantId = context.tenant_id || null;
  const userId = context.user_id || null;
  if (!tenantId || !userId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const favorite = await clinicalTermRepository.findFavorite({ id, tenant_id: tenantId, deleted_at: null });
  if (!favorite) {
    throw new HttpError('errors.clinical_term_favorite.not_found', 404);
  }

  const isOwner = favorite.owner_user_id && favorite.owner_user_id === userId;
  const canManageShared = canManageSharedFavorite(context);
  if (!isOwner && !(favorite.scope === 'SHARED' && canManageShared)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  await clinicalTermRepository.updateFavorite(favorite.id, { deleted_at: new Date() });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'DELETE',
    entity: 'clinical_term_favorite',
    entity_id: favorite.id,
    diff: { before: favorite },
    ip_address: context.ip_address,
  }).catch(() => {});
};

const loadRecentHistory = async ({ termType, tenantId, facilityId, q, limit }) => {
  const whereEncounter = {
    deleted_at: null,
    tenant_id: tenantId,
    ...(facilityId ? { facility_id: facilityId } : {}),
  };

  if (termType === 'PROCEDURE') {
    const procedures = await clinicalTermRepository.findRecentProcedures({
        deleted_at: null,
        encounter: whereEncounter,
        ...(q
          ? {
              OR: [
                { code: { contains: q } },
                { description: { contains: q } },
              ],
            }
          : {}),
      }, limit);

    return procedures.map((row) => ({
      code: row.code || null,
      description: row.description,
      created_at: row.created_at,
      origin: 'RECENT_HISTORY',
      usage_count: 0,
    }));
  }

  const diagnoses = await clinicalTermRepository.findRecentDiagnoses({
      deleted_at: null,
      encounter: whereEncounter,
      ...(q
        ? {
            OR: [
              { code: { contains: q } },
              { description: { contains: q } },
            ],
          }
        : {}),
    }, limit);

  return diagnoses.map((row) => ({
    code: row.code || null,
    description: row.description,
    created_at: row.created_at,
    origin: 'RECENT_HISTORY',
    usage_count: 0,
  }));
};

const listClinicalTermSuggestions = async (filters = {}, context = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id || null;
  const userId = context.user_id || null;
  if (!tenantId || !userId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const termType = normalizeTermType(filters.term_type || 'DIAGNOSIS');
  const q = normalizeText(filters.q);
  const limit = Number(filters.limit || 12);
  const safeLimit = Number.isFinite(limit) ? Math.max(1, Math.min(50, limit)) : 12;
  const facilityId =
    filters.facility_id !== undefined
      ? filters.facility_id || null
      : context.facility_id || null;

  const [favorites, recent] = await Promise.all([
    listClinicalTermFavorites(
      {
        term_type: termType,
        facility_id: facilityId,
        q,
      },
      context
    ),
    loadRecentHistory({
      termType,
      tenantId,
      facilityId,
      q,
      limit: safeLimit * 3,
    }),
  ]);

  const personalFavoriteIds = new Set(
    favorites
      .filter((favorite) => favorite.scope === 'PERSONAL')
      .map((favorite) => favorite.id)
  );

  const favoriteRows = favorites.map((favorite) => ({
    id: favorite.id,
    code: favorite.code || null,
    description: favorite.description,
    created_at: favorite.updated_at || favorite.created_at,
    origin: personalFavoriteIds.has(favorite.id) ? 'PERSONAL_FAVORITE' : 'SHARED_FAVORITE',
    usage_count: favorite.usage_count || 0,
  }));

  const merged = new Map();
  [...favoriteRows, ...recent].forEach((item) => {
    const key = buildSuggestionKey(item.code, item.description);
    const previous = merged.get(key);
    const nextScore = scoreSuggestion({
      q,
      source: item,
      createdAt: item.created_at,
      usageCount: item.usage_count,
    });

    if (!previous || nextScore > previous.score) {
      merged.set(key, {
        code: item.code || null,
        description: item.description,
        origin: item.origin,
        score: nextScore,
        term_type: termType,
      });
      return;
    }

    if (nextScore === previous.score && item.origin === 'PERSONAL_FAVORITE') {
      previous.origin = item.origin;
    }
  });

  return Array.from(merged.values())
    .sort((a, b) => b.score - a.score)
    .slice(0, safeLimit)
    .map((item) => ({
      term_type: item.term_type,
      code: item.code,
      description: item.description,
      origin: item.origin,
      score: item.score,
    }));
};

module.exports = {
  listClinicalTermSuggestions,
  listClinicalTermFavorites,
  createClinicalTermFavorite,
  deleteClinicalTermFavorite,
};
