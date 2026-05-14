const PUBLIC_ID_PREFIXES = Object.freeze({
  subscription_plan: 'SPLAN',
  subscription: 'SUB',
  subscription_invoice: 'SINV',
  module: 'MOD',
  module_subscription: 'MSUB',
  license: 'LIC',
});

const SUBSCRIPTIONS_PANELS = Object.freeze([
  { id: 'overview', label_key: 'subscriptions.workbench.panels.overview' },
  { id: 'catalog', label_key: 'subscriptions.workbench.panels.catalog' },
  { id: 'operations', label_key: 'subscriptions.workbench.panels.operations' },
  { id: 'billing', label_key: 'subscriptions.workbench.panels.billing' },
  { id: 'governance', label_key: 'subscriptions.workbench.panels.governance' },
]);

const SUBSCRIPTIONS_RESOURCES = Object.freeze([
  'subscription-plans',
  'modules',
  'subscriptions',
  'module-subscriptions',
  'subscription-invoices',
  'licenses',
]);

const SUBSCRIPTIONS_PANEL_RESOURCE_MAP = Object.freeze({
  overview: 'subscriptions',
  catalog: 'subscription-plans',
  operations: 'subscriptions',
  billing: 'subscription-invoices',
  governance: 'licenses',
});

const SUBSCRIPTIONS_RESOURCE_PANEL_MAP = Object.freeze({
  'subscription-plans': 'catalog',
  modules: 'catalog',
  subscriptions: 'operations',
  'module-subscriptions': 'operations',
  'subscription-invoices': 'billing',
  licenses: 'governance',
});

const SUBSCRIPTIONS_PENDING_CHANGE_STATUSES = Object.freeze([
  'PENDING_UPGRADE',
  'PENDING_DOWNGRADE',
  'PRORATION_PENDING',
]);

const SUBSCRIPTIONS_WARNING_FIT_STATUSES = Object.freeze([
  'APPROACHING_LIMIT',
  'EXCEEDED',
]);

const SUBSCRIPTIONS_STATUS_VALUES = Object.freeze([
  'ACTIVE',
  'PAST_DUE',
  'CANCELLED',
  'TRIAL',
]);

const SUBSCRIPTIONS_CHANGE_STATUS_VALUES = Object.freeze([
  'NONE',
  'PENDING_UPGRADE',
  'PENDING_DOWNGRADE',
  'PRORATION_PENDING',
  'APPLIED',
  'CANCELLED',
]);

const SUBSCRIPTIONS_FIT_STATUS_VALUES = Object.freeze([
  'HEALTHY',
  'APPROACHING_LIMIT',
  'EXCEEDED',
]);

const SUBSCRIPTIONS_BILLING_CYCLES = Object.freeze([
  'MONTHLY',
  'QUARTERLY',
  'YEARLY',
]);

const SUBSCRIPTIONS_PLAN_TIERS = Object.freeze([
  'FREE',
  'BASIC',
  'PRO',
  'ADVANCED',
  'CUSTOM',
]);

const SUBSCRIPTIONS_LICENSE_TYPES = Object.freeze([
  'PER_USER',
  'PER_FACILITY',
  'ENTERPRISE',
]);

const createSubscriptionPublicId = (prefix = 'SUB') => {
  const normalizedPrefix = String(prefix || 'SUB')
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .slice(0, 6) || 'SUB';
  const timestamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `${normalizedPrefix}-${timestamp}${random}`.slice(0, 32);
};

module.exports = {
  PUBLIC_ID_PREFIXES,
  SUBSCRIPTIONS_BILLING_CYCLES,
  SUBSCRIPTIONS_CHANGE_STATUS_VALUES,
  SUBSCRIPTIONS_FIT_STATUS_VALUES,
  SUBSCRIPTIONS_LICENSE_TYPES,
  SUBSCRIPTIONS_PANEL_RESOURCE_MAP,
  SUBSCRIPTIONS_PANELS,
  SUBSCRIPTIONS_PENDING_CHANGE_STATUSES,
  SUBSCRIPTIONS_PLAN_TIERS,
  SUBSCRIPTIONS_RESOURCE_PANEL_MAP,
  SUBSCRIPTIONS_RESOURCES,
  SUBSCRIPTIONS_STATUS_VALUES,
  SUBSCRIPTIONS_WARNING_FIT_STATUSES,
  createSubscriptionPublicId,
};
