const settingsWorkspaceRepository = require('@repositories/settings-workspace/settings-workspace.repository');
const { ROLES } = require('@config/roles');

const text = (value) => String(value || '').trim();

const GROUPS = Object.freeze([
  { id: 'organization', label_key: 'settings.sidebar.groups.organization' },
  { id: 'usersAndAccess', label_key: 'settings.sidebar.groups.usersAndAccess' },
  { id: 'security', label_key: 'settings.sidebar.groups.security' },
]);

const MODULE_CATALOG = Object.freeze([
  {
    id: 'tenant',
    group_id: 'organization',
    label_key: 'settings.tabs.tenant',
    icon: 'layers-outline',
    route: '/settings/tenants',
    create_route: '/settings/tenants/create',
    dependencies: [],
    mandatory: true,
  },
  {
    id: 'facility',
    group_id: 'organization',
    label_key: 'settings.tabs.facility',
    icon: 'business-outline',
    route: '/settings/facilities',
    create_route: '/settings/facilities/create',
    dependencies: ['tenant'],
    mandatory: true,
  },
  {
    id: 'branch',
    group_id: 'organization',
    label_key: 'settings.tabs.branch',
    icon: 'git-branch-outline',
    route: '/settings/branches',
    create_route: '/settings/branches/create',
    dependencies: ['facility'],
    mandatory: false,
  },
  {
    id: 'department',
    group_id: 'organization',
    label_key: 'settings.tabs.department',
    icon: 'folder-outline',
    route: '/settings/departments',
    create_route: '/settings/departments/create',
    dependencies: ['facility'],
    mandatory: true,
  },
  {
    id: 'unit',
    group_id: 'organization',
    label_key: 'settings.tabs.unit',
    icon: 'grid-outline',
    route: '/settings/units',
    create_route: '/settings/units/create',
    dependencies: ['department'],
    mandatory: false,
  },
  {
    id: 'room',
    group_id: 'organization',
    label_key: 'settings.tabs.room',
    icon: 'home-outline',
    route: '/settings/rooms',
    create_route: '/settings/rooms/create',
    dependencies: ['ward'],
    mandatory: false,
  },
  {
    id: 'ward',
    group_id: 'organization',
    label_key: 'settings.tabs.ward',
    icon: 'medkit-outline',
    route: '/settings/wards',
    create_route: '/settings/wards/create',
    dependencies: ['department'],
    mandatory: true,
  },
  {
    id: 'bed',
    group_id: 'organization',
    label_key: 'settings.tabs.bed',
    icon: 'bed-outline',
    route: '/settings/beds',
    create_route: '/settings/beds/create',
    dependencies: ['ward'],
    mandatory: false,
  },
  {
    id: 'address',
    group_id: 'organization',
    label_key: 'settings.tabs.address',
    icon: 'map-outline',
    route: '/settings/addresses',
    create_route: '/settings/addresses/create',
    dependencies: ['facility'],
    mandatory: false,
  },
  {
    id: 'contact',
    group_id: 'organization',
    label_key: 'settings.tabs.contact',
    icon: 'people-outline',
    route: '/settings/contacts',
    create_route: '/settings/contacts/create',
    dependencies: ['facility'],
    mandatory: false,
  },
  {
    id: 'user',
    group_id: 'usersAndAccess',
    label_key: 'settings.tabs.user',
    icon: 'people-outline',
    route: '/settings/users',
    create_route: '/settings/users/create',
    dependencies: ['facility'],
    mandatory: true,
  },
  {
    id: 'user-profile',
    group_id: 'usersAndAccess',
    label_key: 'settings.tabs.user-profile',
    icon: 'person-outline',
    route: '/settings/user-profiles',
    create_route: '/settings/user-profiles/create',
    dependencies: ['user'],
    mandatory: false,
  },
  {
    id: 'role',
    group_id: 'usersAndAccess',
    label_key: 'settings.tabs.role',
    icon: 'people-outline',
    route: '/settings/roles',
    create_route: '/settings/roles/create',
    dependencies: ['tenant'],
    mandatory: true,
  },
  {
    id: 'permission',
    group_id: 'usersAndAccess',
    label_key: 'settings.tabs.permission',
    icon: 'shield-outline',
    route: '/settings/permissions',
    create_route: '/settings/permissions/create',
    dependencies: ['tenant'],
    mandatory: true,
  },
  {
    id: 'role-permission',
    group_id: 'usersAndAccess',
    label_key: 'settings.tabs.role-permission',
    icon: 'shield-checkmark-outline',
    route: '/settings/role-permissions',
    create_route: '/settings/role-permissions/create',
    dependencies: ['role', 'permission'],
    mandatory: false,
  },
  {
    id: 'user-role',
    group_id: 'usersAndAccess',
    label_key: 'settings.tabs.user-role',
    icon: 'people-outline',
    route: '/settings/user-roles',
    create_route: '/settings/user-roles/create',
    dependencies: ['user', 'role'],
    mandatory: false,
  },
  {
    id: 'user-session',
    group_id: 'usersAndAccess',
    label_key: 'settings.tabs.user-session',
    icon: 'time-outline',
    route: '/settings/user-sessions',
    create_route: null,
    dependencies: ['user'],
    mandatory: false,
  },
  {
    id: 'api-key',
    group_id: 'security',
    label_key: 'settings.tabs.api-key',
    icon: 'key-outline',
    route: '/settings/api-keys',
    create_route: null,
    dependencies: ['user'],
    mandatory: false,
  },
  {
    id: 'api-key-permission',
    group_id: 'security',
    label_key: 'settings.tabs.api-key-permission',
    icon: 'shield-outline',
    route: '/settings/api-key-permissions',
    create_route: '/settings/api-key-permissions/create',
    dependencies: ['api-key', 'permission'],
    mandatory: false,
  },
  {
    id: 'user-mfa',
    group_id: 'security',
    label_key: 'settings.tabs.user-mfa',
    icon: 'lock-closed-outline',
    route: '/settings/user-mfas',
    create_route: '/settings/user-mfas/create',
    dependencies: ['user'],
    mandatory: false,
  },
  {
    id: 'oauth-account',
    group_id: 'security',
    label_key: 'settings.tabs.oauth-account',
    icon: 'lock-open-outline',
    route: '/settings/oauth-accounts',
    create_route: '/settings/oauth-accounts/create',
    dependencies: ['user'],
    mandatory: false,
  },
]);

const CHECKLIST_ORDER = Object.freeze([
  'tenant',
  'facility',
  'department',
  'ward',
  'bed',
  'user',
  'role',
  'permission',
]);

const WRITE_ROLES = new Set([
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
]);

const lower = (value) => text(value).toLowerCase();

const roleList = (user = {}) => {
  const roles = Array.isArray(user.roles) ? user.roles : [user.role];
  return roles
    .map((entry) => text(entry).toUpperCase())
    .filter(Boolean);
};

const canWriteSettings = (user = {}) => roleList(user).some((entry) => WRITE_ROLES.has(entry));

const normalizeMetric = (value = {}) => ({
  count: Number(value.count || 0),
  last_updated_at: value.last_updated_at || null,
});

const buildModuleState = ({ module, metricsMap = {}, canWrite = false }) => {
  const metric = normalizeMetric(metricsMap[module.id]);

  const dependencyStatuses = module.dependencies.map((dependencyId) => {
    const dependencyMetric = normalizeMetric(metricsMap[dependencyId]);
    return {
      module_id: dependencyId,
      is_ready: dependencyMetric.count > 0,
    };
  });

  const hasMissingDependency = dependencyStatuses.some((entry) => !entry.is_ready);
  const isEmpty = metric.count <= 0;

  let state = isEmpty ? 'empty' : 'configured';
  let reasonKey = null;

  if (hasMissingDependency) {
    state = 'attention';
    reasonKey = 'settings.workspace.reasons.dependencies';
  } else if (module.mandatory && isEmpty) {
    state = 'attention';
    reasonKey = 'settings.workspace.reasons.required';
  }

  const canCreate = Boolean(canWrite && module.create_route && !hasMissingDependency);

  return {
    module_id: module.id,
    label_key: module.label_key,
    icon: module.icon,
    route: module.route,
    create_route: module.create_route,
    group_id: module.group_id,
    count: metric.count,
    last_updated_at: metric.last_updated_at,
    state,
    attention_reason_key: reasonKey,
    dependencies: dependencyStatuses,
    can_read: true,
    can_write: canWrite,
    can_create: canCreate,
    entitlement_state: 'core',
  };
};

const buildSummaryCards = (moduleStates = []) =>
  GROUPS.map((group) => {
    const groupModules = moduleStates.filter((entry) => entry.group_id === group.id);

    const configuredModules = groupModules.filter((entry) => entry.count > 0).length;
    const attentionModules = groupModules.filter((entry) => entry.state === 'attention').length;

    return {
      id: group.id,
      label_key: `settings.workspace.summary.${group.id}`,
      total_modules: groupModules.length,
      configured_modules: configuredModules,
      attention_modules: attentionModules,
      total_records: groupModules.reduce((sum, entry) => sum + Number(entry.count || 0), 0),
      state:
        attentionModules > 0
          ? 'attention'
          : configuredModules === groupModules.length
            ? 'ready'
            : 'in_progress',
    };
  });

const buildChecklist = (moduleStates = []) => {
  const items = CHECKLIST_ORDER
    .map((moduleId, index) => {
      const moduleState = moduleStates.find((entry) => entry.module_id === moduleId);
      if (!moduleState) return null;

      return {
        id: moduleId,
        label_key: `settings.workspace.checklist.${moduleId}`,
        completed: moduleState.count > 0,
        route: moduleState.route,
        create_route: moduleState.create_route,
        priority: index + 1,
      };
    })
    .filter(Boolean);

  return {
    completed_count: items.filter((entry) => entry.completed).length,
    total_count: items.length,
    items,
  };
};

const buildQuickActions = (moduleStates = []) =>
  moduleStates
    .filter((entry) => entry.can_create)
    .sort((left, right) => {
      const leftPriority = CHECKLIST_ORDER.indexOf(left.module_id);
      const rightPriority = CHECKLIST_ORDER.indexOf(right.module_id);
      const leftScore = leftPriority === -1 ? 999 : leftPriority;
      const rightScore = rightPriority === -1 ? 999 : rightPriority;
      return leftScore - rightScore;
    })
    .slice(0, 8)
    .map((entry) => ({
      id: `create-${entry.module_id}`,
      module_id: entry.module_id,
      module_label_key: entry.label_key,
      icon: entry.icon,
      label_key: 'settings.workspace.quickActions.createModule',
      route: entry.create_route,
      can_execute: true,
    }));

const applyModuleFilters = (modules = [], filters = {}) => {
  const search = lower(filters.search);
  const group = text(filters.group);
  const state = text(filters.state);
  const actionableOnly = String(filters.actionable_only || '').toLowerCase() === 'true';

  return modules.filter((entry) => {
    if (group && entry.group_id !== group) return false;
    if (state && entry.state !== state) return false;
    if (actionableOnly && !entry.can_create) return false;

    if (!search) return true;
    const searchableFields = [
      entry.module_id,
      entry.group_id,
      entry.route,
      entry.create_route || '',
      entry.label_key,
    ];

    return searchableFields.some((value) => lower(value).includes(search));
  });
};

const buildGroupPayload = (modules = []) =>
  GROUPS
    .map((group) => ({
      id: group.id,
      label_key: group.label_key,
      modules: modules.filter((entry) => entry.group_id === group.id),
    }))
    .filter((group) => group.modules.length > 0);

const buildContext = ({ user = {}, scope = {}, tenant = null, facility = null, state = 'ready' }) => ({
  state,
  role_keys: roleList(user),
  tenant_id: settingsWorkspaceRepository.safePublicId(tenant?.human_friendly_id, tenant?.id, scope?.tenant_id),
  tenant_name: tenant?.name || null,
  facility_id: settingsWorkspaceRepository.safePublicId(
    facility?.human_friendly_id,
    facility?.id,
    scope?.facility_id
  ),
  facility_name: facility?.name || null,
  facility_type: facility?.facility_type || null,
});

const buildReferenceOptions = ({ tenants = [], facilities = [] }) => ({
  tenants: tenants
    .map((entry) => ({
      id: settingsWorkspaceRepository.safePublicId(entry.human_friendly_id, entry.id),
      label: entry.name,
    }))
    .filter((entry) => entry.id),
  facilities: facilities
    .map((entry) => ({
      id: settingsWorkspaceRepository.safePublicId(entry.human_friendly_id, entry.id),
      label: entry.name,
      meta: {
        facility_type: entry.facility_type || null,
      },
    }))
    .filter((entry) => entry.id),
});

const getWorkspace = async (filters = {}, user = {}) => {
  const scopeResult = await settingsWorkspaceRepository.resolveWorkspaceScope({ filters, user });
  const writeAllowed = canWriteSettings(user);

  if (scopeResult.state === 'tenant_context_required') {
    const referenceData = await settingsWorkspaceRepository.findReferenceData({
      scope: null,
      includeTenants: true,
    });

    return {
      state: 'tenant_context_required',
      generated_at: new Date().toISOString(),
      context: buildContext({ user, scope: null, state: 'tenant_context_required' }),
      summary_cards: buildSummaryCards([]),
      checklist: buildChecklist([]),
      quick_actions: [],
      module_groups: [],
      filters: {
        group: text(filters.group) || null,
        search: text(filters.search) || '',
        state: text(filters.state) || null,
        actionable_only: String(filters.actionable_only || '').toLowerCase() === 'true',
      },
      lookups: buildReferenceOptions(referenceData),
      stats: {
        total_modules: MODULE_CATALOG.length,
        configured_modules: 0,
        attention_modules: 0,
        total_records: 0,
      },
      permissions: {
        can_write: writeAllowed,
      },
    };
  }

  const scope = scopeResult.scope;

  const [tenantContext, facilityContext, metrics, referenceData] = await Promise.all([
    settingsWorkspaceRepository.findTenantContext(scope),
    settingsWorkspaceRepository.findFacilityContext(scope),
    settingsWorkspaceRepository.findModuleMetrics(scope),
    settingsWorkspaceRepository.findReferenceData({
      scope,
      includeTenants: roleList(user).includes(ROLES.SUPER_ADMIN),
    }),
  ]);

  const moduleStates = MODULE_CATALOG.map((module) =>
    buildModuleState({ module, metricsMap: metrics, canWrite: writeAllowed })
  );

  const filteredModules = applyModuleFilters(moduleStates, filters);
  const summaryCards = buildSummaryCards(moduleStates);
  const checklist = buildChecklist(moduleStates);

  return {
    state: 'ready',
    generated_at: new Date().toISOString(),
    context: buildContext({
      user,
      scope,
      tenant: tenantContext,
      facility: facilityContext,
      state: 'ready',
    }),
    summary_cards: summaryCards,
    checklist,
    quick_actions: buildQuickActions(moduleStates),
    module_groups: buildGroupPayload(filteredModules),
    filters: {
      group: text(filters.group) || null,
      search: text(filters.search) || '',
      state: text(filters.state) || null,
      actionable_only: String(filters.actionable_only || '').toLowerCase() === 'true',
    },
    lookups: buildReferenceOptions(referenceData),
    stats: {
      total_modules: MODULE_CATALOG.length,
      configured_modules: moduleStates.filter((entry) => entry.count > 0).length,
      attention_modules: moduleStates.filter((entry) => entry.state === 'attention').length,
      total_records: moduleStates.reduce((sum, entry) => sum + Number(entry.count || 0), 0),
    },
    permissions: {
      can_write: writeAllowed,
    },
  };
};

const getReferenceData = async (filters = {}, user = {}) => {
  const scopeResult = await settingsWorkspaceRepository.resolveWorkspaceScope({ filters, user });

  if (scopeResult.state === 'tenant_context_required') {
    const referenceData = await settingsWorkspaceRepository.findReferenceData({
      scope: null,
      includeTenants: true,
    });

    return {
      state: 'tenant_context_required',
      ...buildReferenceOptions(referenceData),
    };
  }

  const scope = scopeResult.scope;
  const referenceData = await settingsWorkspaceRepository.findReferenceData({
    scope,
    includeTenants: roleList(user).includes(ROLES.SUPER_ADMIN),
  });

  return {
    state: 'ready',
    ...buildReferenceOptions(referenceData),
  };
};

module.exports = {
  getReferenceData,
  getWorkspace,
};
