const repository = require('@repositories/tenant-facility-workspace/tenant-facility-workspace.repository');
const { ROLES } = require('@config/roles');
const { PERMISSIONS } = require('@config/permissions');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { serializeSubscription } = require('@lib/subscriptions/serializers');

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

const WRITE_ROLES = new Set([
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
]);

const TENANT_WRITE_ROLES = new Set([ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN]);

const roleList = (user = {}) => {
  const roles = Array.isArray(user.roles) ? user.roles : [user.role];
  return roles
    .map((entry) => String(entry || '').trim().toUpperCase())
    .filter(Boolean);
};

const permissionList = (user = {}) => {
  const permissions = Array.isArray(user.permissions) ? user.permissions : [];
  return permissions
    .map((entry) => String(entry || '').trim().toLowerCase())
    .filter(Boolean);
};

const hasAnyPermission = (user = {}, required = []) => {
  const granted = new Set(permissionList(user));
  return required.some((entry) => granted.has(String(entry).toLowerCase()));
};

const canManageTenant = (user = {}) =>
  roleList(user).some((entry) => TENANT_WRITE_ROLES.has(entry)) ||
  hasAnyPermission(user, [
    PERMISSIONS.TENANT_ADMIN,
    PERMISSIONS.SYSTEM_ADMIN,
  ]);

const canManageFacility = (user = {}) =>
  roleList(user).some((entry) => WRITE_ROLES.has(entry)) ||
  hasAnyPermission(user, [
    PERMISSIONS.FACILITY_ADMIN,
    PERMISSIONS.TENANT_ADMIN,
    PERMISSIONS.SYSTEM_ADMIN,
  ]);

const canViewSubscriptions = (user = {}) =>
  hasAnyPermission(user, [
    PERMISSIONS.SUBSCRIPTIONS_READ,
    PERMISSIONS.SUBSCRIPTIONS_WRITE,
    PERMISSIONS.TENANT_ADMIN,
    PERMISSIONS.SYSTEM_ADMIN,
  ]);

const serializeTenant = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    name: record.name,
    slug: record.slug || null,
    is_active: Boolean(record.is_active),
  };
};

const serializeFacility = (record) => {
  if (!record) return null;

  const extensionJson =
    record.extension_json && typeof record.extension_json === 'object'
      ? record.extension_json
      : {};

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    tenant_id: safePublicId(record.tenant_id),
    name: record.name,
    facility_type: record.facility_type,
    is_active: Boolean(record.is_active),
    extension_json: {
      logo_url: extensionJson.logo_url || null,
    },
  };
};

const serializeBranch = (record) => ({
  id: safePublicId(record.human_friendly_id, record.id),
  tenant_id: safePublicId(record.tenant_id),
  facility_id: safePublicId(record.facility_id),
  name: record.name,
  is_active: Boolean(record.is_active),
});

const serializeDepartment = (record) => ({
  id: safePublicId(record.human_friendly_id, record.id),
  tenant_id: safePublicId(record.tenant_id),
  facility_id: safePublicId(record.facility_id),
  branch_id: safePublicId(record.branch_id),
  name: record.name,
  short_name: record.short_name || null,
  department_type: record.department_type,
  is_active: Boolean(record.is_active),
});

const serializeUnit = (record) => ({
  id: safePublicId(record.human_friendly_id, record.id),
  tenant_id: safePublicId(record.tenant_id),
  facility_id: safePublicId(record.facility_id),
  department_id: safePublicId(record.department_id),
  name: record.name,
  is_active: Boolean(record.is_active),
});

const serializeWard = (record) => ({
  id: safePublicId(record.human_friendly_id, record.id),
  tenant_id: safePublicId(record.tenant_id),
  facility_id: safePublicId(record.facility_id),
  department_id: safePublicId(record.department_id),
  name: record.name,
  ward_type: record.ward_type,
  is_active: Boolean(record.is_active),
});

const serializeRoom = (record) => ({
  id: safePublicId(record.human_friendly_id, record.id),
  tenant_id: safePublicId(record.tenant_id),
  facility_id: safePublicId(record.facility_id),
  ward_id: safePublicId(record.ward_id),
  name: record.name,
  floor: record.floor || null,
});

const serializeBed = (record) => ({
  id: safePublicId(record.human_friendly_id, record.id),
  tenant_id: safePublicId(record.tenant_id),
  facility_id: safePublicId(record.facility_id),
  ward_id: safePublicId(record.ward_id),
  room_id: safePublicId(record.room_id),
  label: record.label,
  status: record.status,
});

const buildContactAddress = (contacts = [], addresses = []) => {
  const phone = contacts.find((entry) => entry.contact_type === 'PHONE');
  const email = contacts.find((entry) => entry.contact_type === 'EMAIL');
  const address = addresses[0] || null;

  return {
    phone: phone?.value || null,
    email: email?.value || null,
    address_line1: address?.line1 || null,
    city: address?.city || null,
    country: address?.country || null,
  };
};

const buildChecklist = ({
  tenant,
  facility,
  contactAddress,
  departments = [],
  units = [],
  wards = [],
  rooms = [],
  beds = [],
}) => {
  const hasTenant = Boolean(tenant);
  const hasFacilityIdentity =
    Boolean(facility?.name?.trim()) && Boolean(contactAddress?.phone?.trim());
  const hasDepartmentsAndUnits = departments.length > 0 && units.length > 0;
  const hasCareSpaces = wards.length > 0 || rooms.length > 0 || beds.length > 0;

  const items = [
  {
    id: 'tenant',
    label_key: 'tenant_facility.checklist.tenant',
    completed: hasTenant,
    priority: 1,
  },
  {
    id: 'facility_identity',
    label_key: 'tenant_facility.checklist.identity',
    completed: hasFacilityIdentity,
    priority: 2,
  },
  {
    id: 'organization',
    label_key: 'tenant_facility.checklist.departments',
    completed: hasDepartmentsAndUnits,
    priority: 3,
  },
  {
    id: 'care_spaces',
    label_key: 'tenant_facility.checklist.locations',
    completed: hasCareSpaces,
    priority: 4,
  },
  ];

  return {
    completed_count: items.filter((entry) => entry.completed).length,
    total_count: items.length,
    items,
  };
};

const buildSubscriptionSummary = (summaryRecord) => {
  if (!summaryRecord?.subscription) return null;

  const serialized = serializeSubscription(summaryRecord.subscription);

  return {
    plan_label: serialized?.plan_label || summaryRecord.subscription?.plan?.name || null,
    status: serialized?.status || summaryRecord.subscription?.status || null,
    active_modules_count: summaryRecord.active_modules_count || 0,
    subscription_id: serialized?.id || null,
  };
};

const selectFacility = (facilities = [], facilityId = null) => {
  if (!facilities.length) return null;
  if (!facilityId) return facilities[0];

  return facilities.find((entry) => safePublicId(entry.human_friendly_id, entry.id) === facilityId) ||
    facilities[0];
};

const getSetup = async (filters = {}, user = {}) => {
  const scopeResult = await repository.resolveWorkspaceScope({ filters, user });
  const includeAllTenants = roleList(user).includes(ROLES.SUPER_ADMIN);

  if (scopeResult.state === 'tenant_context_required') {
    const tenants = await repository.findTenants(null, includeAllTenants);

    return {
      state: 'tenant_context_required',
      generated_at: new Date().toISOString(),
      tenant: null,
      facility: null,
      facilities: [],
      contact_address: buildContactAddress(),
      branches: [],
      departments: [],
      units: [],
      wards: [],
      rooms: [],
      beds: [],
      checklist: buildChecklist({}),
      subscription_summary: null,
      permissions: {
        can_manage_tenant: canManageTenant(user),
        can_manage_facility: canManageFacility(user),
        can_view_subscriptions: canViewSubscriptions(user),
      },
      lookups: {
        tenants: tenants.map((entry) => ({
          id: safePublicId(entry.human_friendly_id, entry.id),
          label: entry.name,
        })),
        facilities: [],
      },
    };
  }

  const scope = scopeResult.scope;
  const requestedFacilityId = filters.facility_id || filters.facilityId || scope.facility_id;

  const [tenants, facilities, facilityRecords, subscriptionSummary] = await Promise.all([
    repository.findTenants(scope, includeAllTenants),
    repository.findFacilities(scope.tenant_id),
    repository.findFacilityRecords(scope),
    canViewSubscriptions(user)
      ? repository.findSubscriptionSummary(scope.tenant_id)
      : Promise.resolve(null),
  ]);

  const tenant = tenants[0] || null;
  const selectedFacility = selectFacility(facilities, requestedFacilityId);
  const contactAddress = buildContactAddress(
    facilityRecords.contacts,
    facilityRecords.addresses
  );

  const payload = {
    state: 'ready',
    generated_at: new Date().toISOString(),
    tenant: serializeTenant(tenant),
    facility: serializeFacility(selectedFacility),
    facilities: facilities.map(serializeFacility),
    contact_address: contactAddress,
    branches: facilityRecords.branches.map(serializeBranch),
    departments: facilityRecords.departments.map(serializeDepartment),
    units: facilityRecords.units.map(serializeUnit),
    wards: facilityRecords.wards.map(serializeWard),
    rooms: facilityRecords.rooms.map(serializeRoom),
    beds: facilityRecords.beds.map(serializeBed),
    checklist: buildChecklist({
      tenant,
      facility: selectedFacility,
      contactAddress,
      departments: facilityRecords.departments,
      units: facilityRecords.units,
      wards: facilityRecords.wards,
      rooms: facilityRecords.rooms,
      beds: facilityRecords.beds,
    }),
    subscription_summary: buildSubscriptionSummary(subscriptionSummary),
    permissions: {
      can_manage_tenant: canManageTenant(user),
      can_manage_facility: canManageFacility(user),
      can_view_subscriptions: canViewSubscriptions(user),
    },
    lookups: {
      tenants: tenants.map((entry) => ({
        id: safePublicId(entry.human_friendly_id, entry.id),
        label: entry.name,
      })),
      facilities: facilities.map((entry) => ({
        id: safePublicId(entry.human_friendly_id, entry.id),
        label: entry.name,
        facility_type: entry.facility_type,
      })),
    },
  };

  return payload;
};

module.exports = {
  getSetup,
};
