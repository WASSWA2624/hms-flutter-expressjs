/**
 * Resolve tenant / facility / platform administrator contacts for staff
 * escalation (subscription renewals, soft-delete recovery, etc.).
 *
 * Exposed on auth payloads so non-billing users can contact every admin in
 * their hierarchy — not a capped sample.
 */

const prisma = require('@prisma/client');
const { ROLES } = require('@config/roles');
const env = require('@config/env');

const ADMIN_CONTACT_INCLUDE = Object.freeze({
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
});

const ADMIN_CONTACT_ORDER = Object.freeze([
  { created_at: 'asc' },
  { id: 'asc' },
]);

const normalizeString = (value) => {
  if (value == null) {
    return null;
  }
  const text = String(value).trim();
  return text.length > 0 ? text : null;
};

const normalizeEmail = (value) => {
  const email = normalizeString(value);
  return email ? email.toLowerCase() : null;
};

const buildFullName = (...parts) => {
  const tokens = parts.map(normalizeString).filter(Boolean);
  return tokens.length > 0 ? tokens.join(' ') : null;
};

const resolveEnvPlatformSupportContact = () => ({
  email: String(env.PLATFORM_ADMIN_EMAIL || '').trim() || null,
  phone: String(env.PLATFORM_ADMIN_PHONE || '').trim() || null,
});

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

const dedupeContacts = (contacts = []) => {
  const merged = [];
  const seenIds = new Set();
  const seenEmails = new Set();

  for (const contact of contacts) {
    if (!contact || typeof contact !== 'object') {
      continue;
    }
    const id = normalizeString(contact.id);
    const email = normalizeEmail(contact.email);
    if (id && seenIds.has(id)) {
      continue;
    }
    if (!id && email && seenEmails.has(email)) {
      continue;
    }
    if (id) {
      seenIds.add(id);
    }
    if (email) {
      seenEmails.add(email);
    }
    merged.push(contact);
  }

  return merged;
};

const findAdminUserRoles = async ({
  tenantId,
  roleName,
  facilityId = null,
} = {}) => {
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

  if (!facilityId) {
    const rows = await prisma.user_role.findMany({
      where: baseWhere,
      orderBy: ADMIN_CONTACT_ORDER,
      include: ADMIN_CONTACT_INCLUDE,
    });
    return dedupeContacts(rows.map(serializeAdminContact));
  }

  const [facilityScoped, tenantWide] = await Promise.all([
    prisma.user_role.findMany({
      where: {
        ...baseWhere,
        facility_id: facilityId,
      },
      orderBy: ADMIN_CONTACT_ORDER,
      include: ADMIN_CONTACT_INCLUDE,
    }),
    prisma.user_role.findMany({
      where: {
        ...baseWhere,
        facility_id: null,
      },
      orderBy: ADMIN_CONTACT_ORDER,
      include: ADMIN_CONTACT_INCLUDE,
    }),
  ]);

  return dedupeContacts(
    [...facilityScoped, ...tenantWide].map(serializeAdminContact)
  );
};

const findPlatformAdminContacts = async () => {
  const rows = await prisma.user_role.findMany({
    where: {
      deleted_at: null,
      role: {
        deleted_at: null,
        name: { in: [ROLES.PLATFORM_OWNER, ROLES.SUPER_ADMIN] },
      },
      user: {
        deleted_at: null,
        status: 'ACTIVE',
      },
    },
    orderBy: ADMIN_CONTACT_ORDER,
    include: ADMIN_CONTACT_INCLUDE,
  });

  return dedupeContacts(rows.map(serializeAdminContact));
};

const appendEnvPlatformSupportContact = (contacts = []) => {
  const envContact = resolveEnvPlatformSupportContact();
  const email = normalizeString(envContact?.email);
  const phone = normalizeString(envContact?.phone);
  if (!email && !phone) {
    return contacts;
  }

  const emailKey = normalizeEmail(email);
  const alreadyListed = contacts.some((contact) => {
    const contactEmail = normalizeEmail(contact.email);
    const contactPhone = normalizeString(contact.phone);
    return (
      (emailKey && contactEmail === emailKey) ||
      (phone && contactPhone === phone)
    );
  });
  if (alreadyListed) {
    return contacts;
  }

  return [
    ...contacts,
    {
      id: null,
      full_name: null,
      email,
      phone,
      role_name: 'PLATFORM_SUPPORT',
      is_support_channel: true,
    },
  ];
};

/**
 * @param {Object} params
 * @param {string} params.tenantId
 * @param {string|null} [params.facilityId]
 * @returns {Promise<{
 *   tenant_admins: Object[],
 *   facility_admins: Object[],
 *   platform_admins: Object[],
 * }>}
 */
const resolveOrgAdminContacts = async ({
  tenantId,
  facilityId = null,
} = {}) => {
  const [tenant_admins, facility_admins, platformUserAdmins] = await Promise.all(
    [
      tenantId
        ? findAdminUserRoles({
            tenantId,
            roleName: ROLES.TENANT_ADMIN,
          })
        : Promise.resolve([]),
      tenantId
        ? findAdminUserRoles({
            tenantId,
            roleName: ROLES.FACILITY_ADMIN,
            facilityId: facilityId || null,
          })
        : Promise.resolve([]),
      findPlatformAdminContacts(),
    ]
  );

  return {
    tenant_admins,
    facility_admins,
    platform_admins: appendEnvPlatformSupportContact(platformUserAdmins),
  };
};

module.exports = {
  resolveOrgAdminContacts,
  serializeAdminContact,
  findAdminUserRoles,
  findPlatformAdminContacts,
  appendEnvPlatformSupportContact,
};
