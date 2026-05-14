const DEFAULT_TEST_IDS = Object.freeze({
  tenant_id: '11111111-1111-4111-8111-111111111111',
  facility_id: '22222222-2222-4222-8222-222222222222',
  branch_id: '33333333-3333-4333-8333-333333333333',
  actor_id: '44444444-4444-4444-8444-444444444444',
  role_id: '55555555-5555-4555-8555-555555555555',
});

const nowIso = () => '2026-05-04T00:00:00.000Z';

const createTestTenant = (overrides = {}) => ({
  id: DEFAULT_TEST_IDS.tenant_id,
  tenant_name: 'HMS Test Tenant',
  tenant_code: 'HMS-TEST',
  status: 'ACTIVE',
  created_at: nowIso(),
  updated_at: nowIso(),
  ...overrides,
});

const createTestFacility = (overrides = {}) => ({
  id: DEFAULT_TEST_IDS.facility_id,
  tenant_id: DEFAULT_TEST_IDS.tenant_id,
  facility_name: 'HMS Test Facility',
  facility_type: 'HOSPITAL',
  status: 'ACTIVE',
  created_at: nowIso(),
  updated_at: nowIso(),
  ...overrides,
});

const createTestRoleAssignment = (overrides = {}) => ({
  id: DEFAULT_TEST_IDS.role_id,
  tenant_id: DEFAULT_TEST_IDS.tenant_id,
  facility_id: DEFAULT_TEST_IDS.facility_id,
  role: {
    name: 'TENANT_ADMIN',
  },
  ...overrides,
});

const createTestActor = (overrides = {}) => {
  const roleAssignments = overrides.role_assignments || [createTestRoleAssignment()];
  return {
    id: DEFAULT_TEST_IDS.actor_id,
    tenant_id: DEFAULT_TEST_IDS.tenant_id,
    facility_id: DEFAULT_TEST_IDS.facility_id,
    email: 'hms.test.user@example.test',
    status: 'ACTIVE',
    roles: roleAssignments,
    permissions: ['tenant:read', 'facility:read'],
    entitlements: ['core.hms'],
    created_at: nowIso(),
    updated_at: nowIso(),
    ...overrides,
    role_assignments: roleAssignments,
  };
};

const createTestRequestContext = (overrides = {}) => ({
  request_id: 'req_hms_test_0001',
  actor: createTestActor(overrides.actor || {}),
  scope: {
    tenant_id: DEFAULT_TEST_IDS.tenant_id,
    facility_id: DEFAULT_TEST_IDS.facility_id,
    branch_id: DEFAULT_TEST_IDS.branch_id,
    ...(overrides.scope || {}),
  },
  permissions: ['tenant:read', 'facility:read', ...(overrides.permissions || [])],
  entitlements: ['core.hms', ...(overrides.entitlements || [])],
});

const createPaginatedResponse = (items = [], overrides = {}) => ({
  items,
  pagination: {
    page: 1,
    page_size: items.length,
    total: items.length,
    total_pages: items.length > 0 ? 1 : 0,
    ...overrides.pagination,
  },
  meta: {
    request_id: 'req_hms_test_0001',
    ...overrides.meta,
  },
});

module.exports = {
  DEFAULT_TEST_IDS,
  createPaginatedResponse,
  createTestActor,
  createTestFacility,
  createTestRequestContext,
  createTestRoleAssignment,
  createTestTenant,
};
