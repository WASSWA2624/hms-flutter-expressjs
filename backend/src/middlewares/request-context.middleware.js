/**
 * Request Context Middleware
 *
 * Builds a request-scoped context object for observability and audit/event
 * correlation. Context includes:
 * - request_id
 * - actor identity (when authenticated)
 * - locale metadata
 * - tenant/facility/branch scope
 */

const crypto = require('crypto');
const { DEFAULT_LOCALE } = require('@config/constants');
const {
  runWithRequestContext,
  getRequestContext
} = require('@lib/context/request-context-store');

const DEFAULT_DIRECTION = 'ltr';

/**
 * Generate request id in a runtime-safe way.
 *
 * @returns {string} Request id
 */
const generateRequestId = () => {
  if (typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return crypto.randomBytes(16).toString('hex');
};

/**
 * Pick the first non-empty value from a list.
 *
 * @param {...any} values - Candidate values
 * @returns {string|null} Selected value
 */
const pickString = (...values) => {
  for (const value of values) {
    if (value === undefined || value === null) {
      continue;
    }
    const normalized = String(value).trim();
    if (normalized) {
      return normalized;
    }
  }
  return null;
};

/**
 * Build actor identity context from authenticated user.
 *
 * @param {Object} user - Authenticated user payload
 * @returns {Object|null} Actor context
 */
const buildActorContext = (user) => {
  if (!user || typeof user !== 'object') {
    return null;
  }

  const actorId = pickString(user.id, user.user_id, user.userId);
  const actorRole = pickString(user.role);
  const actorRoles = Array.isArray(user.roles)
    ? user.roles.map((role) => String(role || '').trim()).filter(Boolean)
    : actorRole
      ? [actorRole]
      : [];

  if (!actorId && actorRoles.length === 0) {
    return null;
  }

  return {
    id: actorId,
    role: actorRole,
    roles: actorRoles
  };
};

/**
 * Build tenancy scope context.
 *
 * @param {Object} req - Express request
 * @returns {{tenant_id: string|null, facility_id: string|null, branch_id: string|null}} Scope context
 */
const buildScopeContext = (req) => {
  const tenantId = pickString(req?.tenant?.id, req?.user?.tenant_id, req?.user?.tenantId);
  const facilityId = pickString(req?.facility?.id, req?.user?.facility_id, req?.user?.facilityId);
  const branchId = pickString(req?.branch?.id, req?.user?.branch_id, req?.user?.branchId);

  return {
    tenant_id: tenantId,
    facility_id: facilityId,
    branch_id: branchId
  };
};

/**
 * Resolve locale metadata from request/response.
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {{locale: string, direction: string}} Locale metadata
 */
const resolveLocaleMetadata = (req, res) => {
  const locale = pickString(req?.locale, res?.locals?.locale, DEFAULT_LOCALE) || DEFAULT_LOCALE;
  const direction = pickString(req?.localeDirection, res?.locals?.direction, DEFAULT_DIRECTION) || DEFAULT_DIRECTION;
  return { locale, direction };
};

/**
 * Ensure request context object exists and sync baseline fields.
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Object} Request context
 */
const ensureRequestContext = (req, res) => {
  const existingContext =
    req.requestContext && typeof req.requestContext === 'object'
      ? req.requestContext
      : req.context && typeof req.context === 'object'
        ? req.context
        : getRequestContext() && typeof getRequestContext() === 'object'
          ? getRequestContext()
          : {};

  const requestId = pickString(
    req.request_id,
    req.requestId,
    req.headers?.['x-request-id'],
    existingContext.request_id
  ) || generateRequestId();

  const localeMeta = resolveLocaleMetadata(req, res);

  const context = {
    request_id: requestId,
    locale: localeMeta.locale,
    direction: localeMeta.direction,
    actor: existingContext.actor || null,
    scope: existingContext.scope || buildScopeContext(req),
    started_at: existingContext.started_at || new Date().toISOString()
  };

  req.request_id = requestId;
  req.requestId = requestId;
  req.requestContext = context;
  req.context = context;

  res.locals.requestContext = context;
  res.locals.request_id = requestId;
  if (!res.getHeader('X-Request-Id')) {
    res.setHeader('X-Request-Id', requestId);
  }

  return context;
};

const dispatchWithRequestContext = (context, next) => {
  if (getRequestContext() === context) {
    next();
    return;
  }

  runWithRequestContext(context, next);
};

/**
 * Initialize request context at app entry (before auth).
 *
 * @returns {Function} Express middleware
 */
const initializeRequestContext = () => {
  return (req, res, next) => {
    const context = ensureRequestContext(req, res);
    const localeMeta = resolveLocaleMetadata(req, res);
    context.locale = localeMeta.locale;
    context.direction = localeMeta.direction;
    context.scope = buildScopeContext(req);
    context.actor = buildActorContext(req.user);
    dispatchWithRequestContext(context, next);
  };
};

/**
 * Hydrate actor/scope context after auth and tenancy middlewares.
 *
 * @returns {Function} Express middleware
 */
const hydrateRequestContext = () => {
  return (req, res, next) => {
    const context = ensureRequestContext(req, res);
    const localeMeta = resolveLocaleMetadata(req, res);
    context.locale = localeMeta.locale;
    context.direction = localeMeta.direction;
    context.actor = buildActorContext(req.user);
    context.scope = buildScopeContext(req);
    dispatchWithRequestContext(context, next);
  };
};

module.exports = {
  initializeRequestContext,
  hydrateRequestContext,
  ensureRequestContext
};
