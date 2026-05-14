/**
 * Tenant and facility scope middleware
 *
 * Ensures authenticated request context uses canonical scope values and prevents
 * cross-tenant/facility/branch access via crafted query/body values.
 */

const { normalizeUserContext } = require('@middlewares/auth.middleware');
const { ELEVATED_ROLES, normalizeRoleName } = require('@config/roles');

const SCOPE_FIELDS = ['tenant_id', 'facility_id', 'branch_id'];
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

const normalizeFieldToScope = (req, sourceObject, field) => {
  const expected = getFromObject(req.user, field);
  if (!expected) return;

  const provided = getFromObject(sourceObject, field);
  if (provided && provided !== expected) {
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
    const branchId = req.user.branch_id || null;

    req.tenant = tenantId ? { id: tenantId } : null;
    req.facility = facilityId ? { id: facilityId } : null;
    req.branch = branchId ? { id: branchId } : null;

    return next();
  } catch (error) {
    return next(error);
  }
};

/**
 * Enforce tenant/facility/branch scope consistency for query/body payloads.
 */
const enforceTenantScope = () => (req, res, next) => {
  try {
    if (!req.user) return next();
    if (hasElevatedRole(req.user.roles)) return next();

    for (const field of SCOPE_FIELDS) {
      normalizeFieldToScope(req, req.query, field);
      normalizeFieldToScope(req, req.body, field);
    }

    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  hydrateRequestScope,
  enforceTenantScope
};
