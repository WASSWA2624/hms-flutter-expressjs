/**
 * Resolve tenant / facility administrator contacts for staff escalation.
 *
 * Exposed on auth payloads so non-billing users can report subscription
 * expiry / renewal needs to the right administrators.
 */

const prisma = require('@prisma/client');
const { ROLES } = require('@config/roles');

const normalizeString = (value) => {
  if (value == null) {
    return null;
  }
  const text = String(value).trim();
  return text.length > 0 ? text : null;
};

const buildFullName = (...parts) => {
  const tokens = parts.map(normalizeString).filter(Boolean);
  return tokens.length > 0 ? tokens.join(' ') : null;
};

const serializeAdminContact = (userRole = null) => {
  const user = userRole?.user;
  if (!user || typeof user !== 'object') {
    return null;
  }

  const profile = user.profile || {};
  const role = userRole?.role || {};
  const fullName = buildFullName(
    profile.first_name,
    profile.middle_name,
    profile.last_name
  );
  const email = normalizeString(user.email);
  const phone = normalizeString(user.phone);
  const roleName = normalizeString(role.name);

  if (!fullName && !email && !phone) {
    return null;
  }

  return {
    id: normalizeString(user.id),
    full_name: fullName,
    email,
    phone,
    role_name: roleName,
  };
};

const findAdminUserRoles = async ({
  tenantId,
  roleName,
  facilityId = null,
  take = 3,
}) => {
  if (!tenantId || !roleName) {
    return [];
  }

  const baseWhere = {
    deleted_at: null,
    tenant_id: tenantId,
    role: {
      deleted_at: null,
      name: roleName,
    },
    user: {
      deleted_at: null,
      status: 'ACTIVE',
    },
  };

  const include = {
    role: {
      select: {
        id: true,
        name: true,
      },
    },
    user: {
      select: {
        id: true,
        email: true,
        phone: true,
        status: true,
        profile: {
          select: {
            first_name: true,
            middle_name: true,
            last_name: true,
          },
        },
      },
    },
  };

  const orderBy = [
    { created_at: 'asc' },
    { id: 'asc' },
  ];

  if (!facilityId) {
    const rows = await prisma.user_role.findMany({
      where: baseWhere,
      orderBy,
      take,
      include,
    });
    return rows.map(serializeAdminContact).filter(Boolean);
  }

  const [facilityScoped, tenantWide] = await Promise.all([
    prisma.user_role.findMany({
      where: {
        ...baseWhere,
        facility_id: facilityId,
      },
      orderBy,
      take,
      include,
    }),
    prisma.user_role.findMany({
      where: {
        ...baseWhere,
        facility_id: null,
      },
      orderBy,
      take,
      include,
    }),
  ]);

  const merged = [];
  const seen = new Set();
  for (const row of [...facilityScoped, ...tenantWide]) {
    const contact = serializeAdminContact(row);
    if (!contact?.id || seen.has(contact.id)) {
      continue;
    }
    seen.add(contact.id);
    merged.push(contact);
    if (merged.length >= take) {
      break;
    }
  }
  return merged;
};

/**
 * @param {Object} params
 * @param {string} params.tenantId
 * @param {string|null} [params.facilityId]
 * @returns {Promise<{ tenant_admins: Object[], facility_admins: Object[] }>}
 */
const resolveOrgAdminContacts = async ({
  tenantId,
  facilityId = null,
} = {}) => {
  if (!tenantId) {
    return {
      tenant_admins: [],
      facility_admins: [],
    };
  }

  const [tenant_admins, facility_admins] = await Promise.all([
    findAdminUserRoles({
      tenantId,
      roleName: ROLES.TENANT_ADMIN,
      take: 3,
    }),
    findAdminUserRoles({
      tenantId,
      roleName: ROLES.FACILITY_ADMIN,
      facilityId: facilityId || null,
      take: 3,
    }),
  ]);

  return {
    tenant_admins,
    facility_admins,
  };
};

module.exports = {
  resolveOrgAdminContacts,
  serializeAdminContact,
};
