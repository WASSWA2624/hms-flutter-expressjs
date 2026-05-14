/**
 * Adaptability Guard Utilities
 *
 * Shared guard helpers for configuration-driven adaptability controls:
 * - policy checks
 * - workflow state checks
 * - dynamic form validation hooks
 * - feature flag checks
 */

/**
 * Resolve policy result into a consistent guard response.
 *
 * @param {boolean} allowed - Whether guard passed
 * @param {string} reason - Guard reason key
 * @param {Object} [extra] - Additional metadata
 * @returns {{allowed: boolean, reason: string}} Guard result
 */
const buildGuardResult = (allowed, reason, extra = {}) => ({
  allowed: Boolean(allowed),
  reason: String(reason || 'unknown'),
  ...extra
});

/**
 * Check a named policy from policy configuration.
 *
 * @param {string} policyKey - Policy key
 * @param {Object<string, any>} policyConfig - Policy configuration map
 * @param {Object} [context={}] - Evaluation context
 * @returns {{allowed: boolean, reason: string, policy: string}} Guard result
 */
const checkPolicyGuard = (policyKey, policyConfig = {}, context = {}) => {
  const policy = policyConfig?.[policyKey];
  if (policy === undefined) {
    return buildGuardResult(false, 'policy_not_defined', { policy: policyKey });
  }

  if (typeof policy === 'boolean') {
    return buildGuardResult(policy, policy ? 'policy_allowed' : 'policy_denied', { policy: policyKey });
  }

  if (typeof policy === 'function') {
    const allowed = Boolean(policy(context));
    return buildGuardResult(allowed, allowed ? 'policy_allowed' : 'policy_denied', { policy: policyKey });
  }

  if (policy && typeof policy === 'object') {
    const enabled = policy.enabled !== false;
    if (!enabled) {
      return buildGuardResult(false, 'policy_disabled', { policy: policyKey });
    }

    if (typeof policy.evaluate === 'function') {
      const allowed = Boolean(policy.evaluate(context));
      return buildGuardResult(allowed, allowed ? 'policy_allowed' : 'policy_denied', { policy: policyKey });
    }

    return buildGuardResult(true, 'policy_allowed', { policy: policyKey });
  }

  return buildGuardResult(false, 'policy_invalid', { policy: policyKey });
};

/**
 * Validate workflow transition based on allowed transition map.
 *
 * @param {string} currentState - Current workflow state
 * @param {string} nextState - Requested next state
 * @param {Object<string, string[]>} transitionMap - Allowed transitions map
 * @returns {{allowed: boolean, reason: string, current_state: string, next_state: string}} Guard result
 */
const checkWorkflowStateGuard = (currentState, nextState, transitionMap = {}) => {
  const current = String(currentState || '').trim();
  const next = String(nextState || '').trim();

  if (!current || !next) {
    return buildGuardResult(false, 'workflow_state_missing', {
      current_state: current || null,
      next_state: next || null
    });
  }

  const allowedTransitions = Array.isArray(transitionMap[current])
    ? transitionMap[current].map((state) => String(state || '').trim()).filter(Boolean)
    : [];

  const allowed = allowedTransitions.includes(next);
  return buildGuardResult(allowed, allowed ? 'workflow_transition_allowed' : 'workflow_transition_denied', {
    current_state: current,
    next_state: next
  });
};

/**
 * Run dynamic form validation hooks.
 *
 * Each hook receives `(payload, context)` and may return:
 * - `null`/`undefined` for pass
 * - string reason
 * - object `{ field, message }`
 *
 * @param {Object} payload - Dynamic form payload
 * @param {Function[]} hooks - Validation hook functions
 * @param {Object} [context={}] - Validation context
 * @returns {{allowed: boolean, reason: string, errors: Object[]}} Guard result
 */
const runDynamicFormValidationHooks = (payload, hooks = [], context = {}) => {
  const errors = [];
  const hookList = Array.isArray(hooks) ? hooks : [];

  hookList.forEach((hook, index) => {
    if (typeof hook !== 'function') {
      errors.push({
        field: null,
        message: 'dynamic_form_hook_invalid',
        hook_index: index
      });
      return;
    }

    const result = hook(payload, context);
    if (!result) {
      return;
    }

    if (typeof result === 'string') {
      errors.push({
        field: null,
        message: result,
        hook_index: index
      });
      return;
    }

    if (result && typeof result === 'object') {
      errors.push({
        field: result.field || null,
        message: result.message || 'dynamic_form_validation_failed',
        hook_index: index
      });
      return;
    }

    errors.push({
      field: null,
      message: 'dynamic_form_validation_failed',
      hook_index: index
    });
  });

  return buildGuardResult(errors.length === 0, errors.length === 0 ? 'dynamic_form_valid' : 'dynamic_form_invalid', {
    errors
  });
};

/**
 * Evaluate feature flag enablement.
 *
 * Supported flag values:
 * - boolean
 * - function `(context) => boolean`
 * - object with optional keys:
 *   - `enabled` (boolean)
 *   - `allowed_roles` (string[])
 *   - `blocked_tenants` (string[])
 *
 * @param {string} flagKey - Feature flag key
 * @param {Object<string, any>} flagConfig - Feature flag config map
 * @param {Object} [context={}] - Evaluation context
 * @returns {{enabled: boolean, reason: string, flag: string}} Flag evaluation result
 */
const checkFeatureFlagGuard = (flagKey, flagConfig = {}, context = {}) => {
  const flag = flagConfig?.[flagKey];
  if (flag === undefined) {
    return {
      enabled: false,
      reason: 'feature_flag_not_defined',
      flag: flagKey
    };
  }

  if (typeof flag === 'boolean') {
    return {
      enabled: flag,
      reason: flag ? 'feature_flag_enabled' : 'feature_flag_disabled',
      flag: flagKey
    };
  }

  if (typeof flag === 'function') {
    const enabled = Boolean(flag(context));
    return {
      enabled,
      reason: enabled ? 'feature_flag_enabled' : 'feature_flag_disabled',
      flag: flagKey
    };
  }

  if (flag && typeof flag === 'object') {
    const baseEnabled = flag.enabled !== false;
    if (!baseEnabled) {
      return {
        enabled: false,
        reason: 'feature_flag_disabled',
        flag: flagKey
      };
    }

    const roles = Array.isArray(context.roles)
      ? context.roles
      : context.role
        ? [context.role]
        : [];
    const allowedRoles = Array.isArray(flag.allowed_roles) ? flag.allowed_roles : null;
    if (allowedRoles && allowedRoles.length > 0) {
      const roleAllowed = roles.some((role) => allowedRoles.includes(role));
      if (!roleAllowed) {
        return {
          enabled: false,
          reason: 'feature_flag_role_blocked',
          flag: flagKey
        };
      }
    }

    const blockedTenants = Array.isArray(flag.blocked_tenants) ? flag.blocked_tenants : [];
    const tenantId = context.tenant_id || context.tenantId || null;
    if (tenantId && blockedTenants.includes(tenantId)) {
      return {
        enabled: false,
        reason: 'feature_flag_tenant_blocked',
        flag: flagKey
      };
    }

    return {
      enabled: true,
      reason: 'feature_flag_enabled',
      flag: flagKey
    };
  }

  return {
    enabled: false,
    reason: 'feature_flag_invalid',
    flag: flagKey
  };
};

/**
 * Boolean convenience wrapper for feature flag checks.
 *
 * @param {string} flagKey - Feature flag key
 * @param {Object<string, any>} flagConfig - Feature flag config map
 * @param {Object} [context={}] - Evaluation context
 * @returns {boolean} True when feature is enabled
 */
const isFeatureFlagEnabled = (flagKey, flagConfig = {}, context = {}) => {
  return checkFeatureFlagGuard(flagKey, flagConfig, context).enabled;
};

module.exports = {
  buildGuardResult,
  checkPolicyGuard,
  checkWorkflowStateGuard,
  runDynamicFormValidationHooks,
  checkFeatureFlagGuard,
  isFeatureFlagEnabled
};
