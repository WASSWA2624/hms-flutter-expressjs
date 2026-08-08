/**
 * Resolve tenant contact details from extension_json and primary admin fallbacks.
 *
 * Registration and setup UIs treat contact as tenant metadata. When
 * extension_json.contact is missing (legacy registrations), fall back to the
 * primary TENANT_ADMIN user profile field-by-field.
 */

const PRIMARY_TENANT_ADMIN_INCLUDE = Object.freeze({
  user_roles: {
    where: {
      deleted_at: null,
      role: {
        deleted_at: null,
        name: 'TENANT_ADMIN',
      },
      user: {
        deleted_at: null,
      },
    },
    orderBy: [{ created_at: 'asc' }, { id: 'asc' }],
    take: 1,
    include: {
      role: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
        },
      },
      user: {
        select: {
          id: true,
          human_friendly_id: true,
          email: true,
          phone: true,
          status: true,
          facility_id: true,
          profile: {
            select: {
              first_name: true,
              middle_name: true,
              last_name: true,
            },
          },
          facility: {
            select: {
              id: true,
              human_friendly_id: true,
              name: true,
            },
          },
        },
      },
    },
  },
});

const normalizeText = (value) => {
  if (value == null) return null;
  const normalized = String(value).trim();
  return normalized || null;
};

const buildFullName = (...parts) => {
  const tokens = parts.map(normalizeText).filter(Boolean);
  return tokens.length > 0 ? tokens.join(' ') : null;
};

const emptyContact = () => ({
  name: null,
  email: null,
  phone: null,
});

const contactFromExtension = (extensionJson) => {
  const extension =
    extensionJson && typeof extensionJson === 'object' ? extensionJson : null;
  const contact =
    extension?.contact && typeof extension.contact === 'object'
      ? extension.contact
      : null;
  if (!contact) {
    return emptyContact();
  }
  return {
    name: normalizeText(contact.name),
    email: normalizeText(contact.email),
    phone: normalizeText(contact.phone),
  };
};

const contactFromPrimaryTenantAdmin = (primary) => {
  if (!primary || typeof primary !== 'object') {
    return emptyContact();
  }
  return {
    name:
      normalizeText(primary.full_name) ||
      buildFullName(primary.first_name, primary.middle_name, primary.last_name),
    email: normalizeText(primary.email),
    phone: normalizeText(primary.phone),
  };
};

const contactFromUserRole = (userRole) => {
  const user = userRole?.user;
  if (!user || typeof user !== 'object') {
    return emptyContact();
  }
  const profile = user.profile && typeof user.profile === 'object' ? user.profile : {};
  return {
    name: buildFullName(profile.first_name, profile.middle_name, profile.last_name),
    email: normalizeText(user.email),
    phone: normalizeText(user.phone),
  };
};

/**
 * @param {Object|null|undefined} tenant
 * @returns {{ name: string|null, email: string|null, phone: string|null }}
 */
const resolveTenantContact = (tenant) => {
  const fromExtension = contactFromExtension(tenant?.extension_json);
  const fromPrimary = contactFromPrimaryTenantAdmin(tenant?.primary_tenant_admin);
  const fromUserRole = Array.isArray(tenant?.user_roles)
    ? contactFromUserRole(tenant.user_roles[0] || null)
    : emptyContact();

  return {
    name: fromExtension.name || fromPrimary.name || fromUserRole.name || null,
    email: fromExtension.email || fromPrimary.email || fromUserRole.email || null,
    phone: fromExtension.phone || fromPrimary.phone || fromUserRole.phone || null,
  };
};

/** App default ISO currency for new tenants (matches frontend appDefaultCurrencyCode). */
const DEFAULT_TENANT_CURRENCY = 'UGX';

/** Default standard consultation fee for new tenants (UGX). */
const DEFAULT_TENANT_CONSULTATION_FEE = 25000;

const resolveDefaultConsultationFee = (value) => {
  if (value === null || value === undefined || value === '') {
    return DEFAULT_TENANT_CONSULTATION_FEE;
  }
  const parsed = typeof value === 'number' ? value : Number(String(value).replace(/,/g, '').trim());
  if (!Number.isFinite(parsed) || parsed < 0) {
    return DEFAULT_TENANT_CONSULTATION_FEE;
  }
  return parsed;
};

/**
 * Build extension_json payload for facility-owner registration.
 *
 * @param {Object} params
 * @param {string} [params.admin_name]
 * @param {string} [params.email]
 * @param {string} [params.phone]
 * @param {string} [params.currency]
 * @param {number|string} [params.standard_consultation_fee]
 * @returns {{ currency: string, billing: { standard_consultation_fee: number }, contact: { name: string|null, email: string|null, phone: string|null } }}
 */
const buildRegistrationContactExtension = ({
  admin_name,
  email,
  phone,
  currency,
  standard_consultation_fee,
} = {}) => {
  const normalizedCurrency = normalizeText(currency)?.toUpperCase();
  return {
    currency:
      normalizedCurrency && /^[A-Z]{3}$/.test(normalizedCurrency)
        ? normalizedCurrency
        : DEFAULT_TENANT_CURRENCY,
    billing: {
      standard_consultation_fee: resolveDefaultConsultationFee(
        standard_consultation_fee,
      ),
    },
    contact: {
      name: normalizeText(admin_name),
      email: normalizeText(email),
      phone: normalizeText(phone),
    },
  };
};

const hasResolvedContact = (contact) =>
  Boolean(contact?.name || contact?.email || contact?.phone);

module.exports = {
  DEFAULT_TENANT_CURRENCY,
  DEFAULT_TENANT_CONSULTATION_FEE,
  PRIMARY_TENANT_ADMIN_INCLUDE,
  resolveTenantContact,
  resolveDefaultConsultationFee,
  buildRegistrationContactExtension,
  hasResolvedContact,
  buildFullName,
  normalizeText,
};
