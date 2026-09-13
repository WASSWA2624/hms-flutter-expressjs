/**
 * Tenant and facility scope middleware
 *
 * Ensures authenticated request context uses canonical scope values and prevents
 * cross-tenant/facility access via crafted query/body values.
 */

const { normalizeUserContext } = require('@middlewares/auth.middleware');
const { ELEVATED_ROLES, normalizeRoleName } = require('@config/roles');

const SCOPE_FIELDS = ['tenant_id', 'facility_id'];
const ELEVATED_ROLE_SET = new Set(ELEVATED_ROLES);

const hasElevatedRole = (roles = []) =>
  Array.isArray(roles) &&
  roles.some((role) => {
    const normalized = normalizeRoleName(role) || String(role || '').toUpperCase();
    return ELEVATED_ROLE_SET.has(normalized);
  });

const toCamelCase = (snakeCase) =>
  String(snakeCase).replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());

const getFromObject = (obj, field) => {
  if (!obj || typeof obj !== 'object') return null;

  const camelField = toCamelCase(field);
  const value = obj[field] ?? obj[camelField];
  if (value === undefined || value === null || value === '') return null;
  return String(value);
};

const setOnObject = (obj, field, value) => {
  if (!obj || typeof obj !== 'object') return;

  const camelField = toCamelCase(field);
  obj[field] = value;

  if (Object.prototype.hasOwnProperty.call(obj, camelField)) {
    obj[camelField] = value;
  }
};

const setOnObjectIfMissing = (obj, field, value) => {
  if (!obj || typeof obj !== 'object') return;
  if (obj[field] !== undefined && obj[field] !== null && obj[field] !== '') return;

  const camelField = toCamelCase(field);
  if (obj[camelField] !== undefined && obj[camelField] !== null && obj[camelField] !== '') return;

  setOnObject(obj, field, value);
};

const hasOwn = (obj, key) => Object.prototype.hasOwnProperty.call(obj, key);

/**
 * Remember what the caller sent for a scope field before it is rewritten, so a
 * route that validates scope itself can act on the caller's real intent.
 */
const recordScopeAdjustment = (req, location, field, sourceObject) => {
  if (!req.scopeAdjustments) {
    req.scopeAdjustments = { query: {}, body: {} };
  }
  const bucket = req.scopeAdjustments[location];
  if (!bucket || hasOwn(bucket, field)) return;

  const camelField = toCamelCase(field);
  if (hasOwn(sourceObject, field)) {
    bucket[field] = { provided: true, value: sourceObject[field] };
  } else if (hasOwn(sourceObject, camelField)) {
    bucket[field] = { provided: true, value: sourceObject[camelField] };
  } else {
    bucket[field] = { provided: false, value: undefined };
  }
};

const normalizeFieldToScope = (req, sourceObject, field, location) => {
  const expected = getFromObject(req.user, field);
  if (!expected) return;
  if (!sourceObject || typeof sourceObject !== 'object') return;

  const provided = getFromObject(sourceObject, field);
  if (provided === expected) return;

  recordScopeAdjustment(req, location, field, sourceObject);

  if (provided) {
    setOnObject(sourceObject, field, expected);
    return;
  }

  setOnObjectIfMissing(sourceObject, field, expected);
};

/**
 * Hydrate request-level scope helpers from authenticated user context.
 */
const hydrateRequestScope = () => (req, res, next) => {
  try {
    if (!req.user) return next();

    req.user = normalizeUserContext(req.user);

    const tenantId = req.user.tenant_id || null;
    const facilityId = req.user.facility_id || null;

    req.tenant = tenantId ? { id: tenantId } : null;
    req.facility = facilityId ? { id: facilityId } : null;

    return next();
  } catch (error) {
    return next(error);
  }
};

/**
 * Enforce tenant/facility scope consistency for query/body payloads.
 */
const enforceTenantScope = () => (req, res, next) => {
  try {
    if (!req.user) return next();
    if (hasElevatedRole(req.user.roles)) return next();

    for (const field of SCOPE_FIELDS) {
      normalizeFieldToScope(req, req.query, field, 'query');
      normalizeFieldToScope(req, req.body, field, 'body');
    }

    return next();
  } catch (error) {
    return next(error);
  }
};

/**
 * Undo the scope rewrite for the listed fields so the route sees what the
 * caller actually requested.
 *
 * Only for routes whose service enforces tenant/facility scope itself (user and
 * user-role mutations). Without it, a tenant admin working in facility A who
 * edits a user in facility B silently moves that user into facility A, because
 * the rewrite injects the actor's facility into every body. Tenant scope is
 * never restored here.
 *
 * @param {string[]} fields - Scope fields to restore (e.g. ['facility_id'])
 * @param {'body'|'query'} [location='body']
 * @returns {Function} Express middleware
 */
const restoreRequestedScope = (fields = [], location = 'body') => (req, res, next) => {
  const bucket = req.scopeAdjustments?.[location];
  const target = req[location];
  if (bucket && target && typeof target === 'object') {
    for (const field of fields) {
      if (field === 'tenant_id' || !hasOwn(bucket, field)) continue;

      const { provided, value } = bucket[field];
      const camelField = toCamelCase(field);
      if (provided) {
        target[field] = value;
        if (hasOwn(target, camelField)) {
          target[camelField] = value;
        }
      } else {
        delete target[field];
        delete target[camelField];
      }
    }
  }
  return next();
};

module.exports = {
  hydrateRequestScope,
  enforceTenantScope,
  restoreRequestedScope
};
