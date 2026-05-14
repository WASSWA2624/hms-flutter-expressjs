/**
 * Auth repository
 *
 * @module modules/auth/repositories
 * @description Data access layer for authentication operations.
 * Special repository that works with user and user_session models.
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const crypto = require('crypto');

const userInclude = {
  profile: true,
  permissions: {
    where: { deleted_at: null },
    include: {
      permission: true,
    },
  },
  roles: {
    where: { deleted_at: null },
    include: {
      role: {
        include: {
          permissions: {
            where: { deleted_at: null },
            include: {
              permission: true
            }
          }
        }
      }
    }
  }
};

const facilitySelect = {
  id: true,
  tenant_id: true,
  name: true,
  facility_type: true,
  is_active: true,
};

const tenantScopedUserInclude = {
  ...userInclude,
  tenant: true,
  facility: {
    select: facilitySelect
  }
};

const tenantScopedUserIncludeWithoutDirectPermissions = {
  profile: true,
  tenant: true,
  facility: {
    select: facilitySelect
  },
  roles: userInclude.roles
};

const minimalTenantScopedUserInclude = {
  profile: true,
  tenant: true,
  facility: {
    select: facilitySelect
  }
};

const sessionIncludeWithDirectPermissions = {
  user: {
    include: tenantScopedUserInclude
  }
};

const sessionIncludeWithoutDirectPermissions = {
  user: {
    include: tenantScopedUserIncludeWithoutDirectPermissions
  }
};

const minimalSessionInclude = {
  user: {
    include: minimalTenantScopedUserInclude
  }
};

const normalizeSlug = (value) =>
  String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-');

const buildTenantSlug = (facilityName) => {
  const base = normalizeSlug(facilityName) || 'hms-tenant';
  const suffix = crypto.randomBytes(3).toString('hex');
  const maxBaseLength = 191 - suffix.length - 1;
  return `${base.slice(0, maxBaseLength)}-${suffix}`;
};

const splitAdminName = (value) => {
  const normalized = String(value || '').trim();
  if (!normalized) {
    return { first_name: 'Admin', last_name: null };
  }
  const [firstName, ...rest] = normalized.split(/\s+/);
  return {
    first_name: firstName || 'Admin',
    last_name: rest.length > 0 ? rest.join(' ') : null,
  };
};

const isMissingSchemaArtifactError = (error) =>
  error?.code === 'P2021' || error?.code === 'P2022';

const sortUsersByCreatedAtDesc = (users = []) => {
  return [...users].sort((left, right) => {
    const leftTs = left?.created_at ? new Date(left.created_at).getTime() : 0;
    const rightTs = right?.created_at ? new Date(right.created_at).getTime() : 0;
    return rightTs - leftTs;
  });
};

const RETRYABLE_CONNECTION_ERROR_CODES = new Set(['P1001', 'P1002', 'P2010', 'P2024']);
const RETRYABLE_CONNECTION_ERROR_PATTERN =
  /pool timeout|failed to retrieve a connection from pool|can'?t reach database server|econnrefused|timed out|protocol_connection_lost/i;
const CONNECTION_RETRY_ATTEMPTS = 3;

const getErrorFingerprint = (error) => {
  return [
    error?.message,
    error?.meta?.cause,
    error?.meta?.driverAdapterError?.message,
    error?.meta?.driverAdapterError?.cause?.message,
  ]
    .filter(Boolean)
    .join(' | ');
};

const isRetryableConnectionError = (error) => {
  const fingerprint = getErrorFingerprint(error);
  if (!RETRYABLE_CONNECTION_ERROR_PATTERN.test(fingerprint)) {
    return false;
  }

  const code = error?.code ? String(error.code).toUpperCase() : null;
  if (!code) {
    return true;
  }

  return RETRYABLE_CONNECTION_ERROR_CODES.has(code);
};

const waitFor = (ms) =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

const withPrismaConnectionRetry = async (queryOperation) => {
  let latestError = null;

  for (let attempt = 1; attempt <= CONNECTION_RETRY_ATTEMPTS; attempt += 1) {
    try {
      return await queryOperation();
    } catch (error) {
      latestError = error;

      const shouldRetry =
        attempt < CONNECTION_RETRY_ATTEMPTS && isRetryableConnectionError(error);
      if (!shouldRetry) {
        throw error;
      }

      // Reset the pooled connection state before retrying a transient adapter timeout.
      try {
        await prisma.$disconnect();
      } catch {
        // Best-effort reset only.
      }
      try {
        await prisma.$connect();
      } catch {
        // The next operation attempt will surface the concrete error if it still fails.
      }

      await waitFor(200 * attempt);
    }
  }

  throw latestError;
};

const toRepositoryHttpError = (error, operation) => {
  throw new HttpError('errors.database.unexpected', 500, [{
    originalError: error?.message,
    errorCode: error?.code || null,
    errorName: error?.name || null,
    meta: error?.meta || null,
    operation,
  }]);
};

const findTenantScopedUserWithFallback = async (where, operation) => {
  const normalizedWhere = {
    ...where,
    deleted_at: null,
  };

  try {
    return await withPrismaConnectionRetry(() =>
      prisma.user.findFirst({
        where: normalizedWhere,
        include: tenantScopedUserInclude
      })
    );
  } catch (error) {
    if (!isMissingSchemaArtifactError(error)) {
      return toRepositoryHttpError(error, operation);
    }
  }

  try {
    return await withPrismaConnectionRetry(() =>
      prisma.user.findFirst({
        where: normalizedWhere,
        include: tenantScopedUserIncludeWithoutDirectPermissions
      })
    );
  } catch (fallbackError) {
    if (!isMissingSchemaArtifactError(fallbackError)) {
      return toRepositoryHttpError(fallbackError, operation);
    }
  }

  try {
    return await withPrismaConnectionRetry(() =>
      prisma.user.findFirst({
        where: normalizedWhere,
        include: minimalTenantScopedUserInclude
      })
    );
  } catch (minimalError) {
    return toRepositoryHttpError(minimalError, operation);
  }
};

/**
 * Find user by email and tenant
 *
 * @param {string} email - User email
 * @param {string} tenantId - Tenant ID
 * @returns {Promise<Object|null>} User object or null
 */
const findUserByEmailAndTenant = async (email, tenantId) => {
  return findTenantScopedUserWithFallback(
    {
      email,
      tenant_id: tenantId,
    },
    'findUserByEmailAndTenant'
  );
};

/**
 * Find user by phone and tenant
 *
 * @param {string} phone - User phone number
 * @param {string} tenantId - Tenant ID
 * @returns {Promise<Object|null>} User object or null
 */
const findUserByPhoneAndTenant = async (phone, tenantId) => {
  return findTenantScopedUserWithFallback(
    {
      phone,
      tenant_id: tenantId,
    },
    'findUserByPhoneAndTenant'
  );
};

/**
 * Find user by ID
 *
 * @param {string} id - User ID
 * @returns {Promise<Object|null>} User object or null
 */
const findUserById = async (id) => {
  return findTenantScopedUserWithFallback(
    { id },
    'findUserById'
  );
};

/**
 * Create new user
 *
 * @param {Object} data - User data
 * @returns {Promise<Object>} Created user
 */
const createUser = async (data) => {
  try {
    const normalizedPositionTitle =
      typeof data?.position_title === 'string' ? data.position_title.trim() : '';
    if (!normalizedPositionTitle) {
      throw new HttpError('errors.validation.field.required', 400, [{ field: 'position_title' }]);
    }

    return await prisma.user.create({
      data: {
        ...data,
        position_title: normalizedPositionTitle,
      },
      include: {
        profile: true
      }
    });
  } catch (error) {
    if (error.code === 'P2002') {
      throw new HttpError('errors.auth.user_exists', 409);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Self-register facility owner and bootstrap tenant workspace.
 *
 * @param {Object} data - Registration data
 * @returns {Promise<Object>} Created user with tenant/facility/profile/roles
 */
const registerFacilityOwner = async (data) => {
  const {
    email,
    phone,
    password_hash,
    facility_name,
    facility_type,
    admin_name,
    status = 'ACTIVE',
  } = data;
  const parsedName = splitAdminName(admin_name);

  try {
    return await prisma.$transaction(async (tx) => {
      const tenant = await tx.tenant.create({
        data: {
          name: facility_name,
          slug: buildTenantSlug(facility_name),
          is_active: true,
        },
      });

      const facility = await tx.facility.create({
        data: {
          tenant_id: tenant.id,
          name: facility_name,
          facility_type,
          is_active: true,
        },
      });

      const role = await tx.role.create({
        data: {
          tenant_id: tenant.id,
          facility_id: facility.id,
          name: 'TENANT_ADMIN',
          description: 'Tenant administrator',
        },
      });

      const user = await tx.user.create({
        data: {
          tenant_id: tenant.id,
          facility_id: facility.id,
          position_title: 'OWNER',
          email,
          phone,
          password_hash,
          status,
        },
      });

      await tx.user_profile.create({
        data: {
          user_id: user.id,
          facility_id: facility.id,
          first_name: parsedName.first_name,
          last_name: parsedName.last_name,
        },
      });

      await tx.user_role.create({
        data: {
          user_id: user.id,
          role_id: role.id,
          tenant_id: tenant.id,
          facility_id: facility.id,
        },
      });

      return tx.user.findFirst({
        where: {
          id: user.id,
          deleted_at: null,
        },
        include: {
          profile: true,
          tenant: true,
          facility: {
            select: facilitySelect
          },
          roles: {
            where: { deleted_at: null },
            include: { role: true },
          },
        },
      });
    });
  } catch (error) {
    if (error.code === 'P2002') {
      const target = Array.isArray(error.meta?.target) ? error.meta.target.join(',') : String(error.meta?.target || '');
      if (target.toLowerCase().includes('email')) {
        throw new HttpError('errors.auth.user_exists', 409);
      }
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update user password
 *
 * @param {string} userId - User ID
 * @param {string} passwordHash - New password hash
 * @returns {Promise<Object>} Updated user
 */
const updateUserPassword = async (userId, passwordHash) => {
  try {
    return await prisma.user.update({
      where: { id: userId },
      data: {
        password_hash: passwordHash,
        updated_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.auth.user_not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find enabled MFA configurations for a user.
 *
 * @param {string} userId - User ID
 * @returns {Promise<Array>} Enabled MFA rows
 */
const findEnabledUserMfas = async (userId) => {
  try {
    return await prisma.user_mfa.findMany({
      where: {
        user_id: userId,
        is_enabled: true,
        deleted_at: null,
      },
      orderBy: [{ last_used_at: 'desc' }, { created_at: 'desc' }],
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update the last-used timestamp for an MFA configuration.
 *
 * @param {string} mfaId - MFA configuration ID
 * @returns {Promise<Object>} Updated MFA row
 */
const touchUserMfaLastUsed = async (mfaId) => {
  try {
    return await prisma.user_mfa.update({
      where: { id: mfaId },
      data: {
        last_used_at: new Date(),
        updated_at: new Date(),
      },
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.user_mfa.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create user session
 *
 * @param {Object} data - Session data
 * @returns {Promise<Object>} Created session
 */
const createSession = async (data) => {
  try {
    return await withPrismaConnectionRetry(() =>
      prisma.user_session.create({
        data
      })
    );
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find session by refresh token hash
 *
 * @param {string} refreshTokenHash - Refresh token hash
 * @returns {Promise<Object|null>} Session object or null
 */
const findSessionByRefreshToken = async (refreshTokenHash) => {
  const where = {
    refresh_token_hash: refreshTokenHash,
    revoked_at: null,
    deleted_at: null,
    expires_at: {
      gt: new Date()
    }
  };

  try {
    return await withPrismaConnectionRetry(() =>
      prisma.user_session.findFirst({
        where,
        include: sessionIncludeWithDirectPermissions
      })
    );
  } catch (error) {
    if (!isMissingSchemaArtifactError(error)) {
      throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
    }
  }

  try {
    return await withPrismaConnectionRetry(() =>
      prisma.user_session.findFirst({
        where,
        include: sessionIncludeWithoutDirectPermissions
      })
    );
  } catch (fallbackError) {
    if (!isMissingSchemaArtifactError(fallbackError)) {
      throw new HttpError('errors.database.unexpected', 500, [{ originalError: fallbackError.message }]);
    }
  }

  try {
    return await withPrismaConnectionRetry(() =>
      prisma.user_session.findFirst({
        where,
        include: minimalSessionInclude
      })
    );
  } catch (minimalError) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: minimalError.message }]);
  }
};

/**
 * Revoke user session
 *
 * @param {string} sessionId - Session ID
 * @returns {Promise<Object>} Updated session
 */
const revokeSession = async (sessionId) => {
  try {
    return await prisma.user_session.update({
      where: { id: sessionId },
      data: {
        revoked_at: new Date(),
        updated_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.auth.session_not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Revoke all user sessions
 *
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Update result
 */
const revokeAllUserSessions = async (userId) => {
  try {
    return await prisma.user_session.updateMany({
      where: {
        user_id: userId,
        revoked_at: null,
        deleted_at: null
      },
      data: {
        revoked_at: new Date(),
        updated_at: new Date()
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create verification token
 *
 * @param {Object} data - Token data
 * @returns {Promise<Object>} Created token
 */
const createVerificationToken = async (data) => {
  try {
    return await prisma.verification_token.create({
      data
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find verification token by hash and type
 *
 * @param {string} tokenHash - Token hash
 * @param {string} type - Token type (EMAIL_VERIFICATION, PHONE_VERIFICATION, PASSWORD_RESET)
 * @returns {Promise<Object|null>} Token object or null
 */
const findVerificationToken = async (tokenHash, type) => {
  try {
    return await prisma.verification_token.findFirst({
      where: {
        token_hash: tokenHash,
        type,
        used_at: null,
        deleted_at: null,
        expires_at: {
          gt: new Date()
        }
      },
      include: {
        user: true
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Mark verification token as used
 *
 * @param {string} tokenId - Token ID
 * @returns {Promise<Object>} Updated token
 */
const markTokenAsUsed = async (tokenId) => {
  try {
    return await prisma.verification_token.update({
      where: { id: tokenId },
      data: {
        used_at: new Date(),
        updated_at: new Date()
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete expired verification tokens for user
 *
 * @param {string} userId - User ID
 * @param {string} type - Token type
 * @returns {Promise<Object>} Delete result
 */
const deleteExpiredTokens = async (userId, type) => {
  try {
    return await prisma.verification_token.updateMany({
      where: {
        user_id: userId,
        type,
        deleted_at: null
      },
      data: {
        deleted_at: new Date(),
        updated_at: new Date()
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create or update registration follow-up tracking profile.
 *
 * @param {Object} data - Tracking data
 * @returns {Promise<Object|null>} Upserted profile or null when model not available
 */
const upsertRegistrationFollowUp = async (data) => {
  const delegate = prisma?.registration_follow_up;
  if (!delegate || typeof delegate.upsert !== 'function') {
    return null;
  }

  const parsedIncrement = Number(data?.registration_attempt_increment);
  const attemptsIncrement = Number.isFinite(parsedIncrement) ? Math.trunc(parsedIncrement) : 1;
  const createAttempts = attemptsIncrement > 0 ? attemptsIncrement : 1;
  const shouldIncrementAttempts = attemptsIncrement > 0;
  const now = new Date();

  const payload = {
    tenant_id: data?.tenant_id || null,
    facility_id: data?.facility_id || null,
    email: data?.email,
    phone: data?.phone || null,
    admin_name: data?.admin_name || null,
    facility_name: data?.facility_name || null,
    facility_type: data?.facility_type || null,
    location: data?.location || null,
    interests: data?.interests || null,
    account_status: data?.account_status,
    locale: data?.locale || null,
    timezone: data?.timezone || null,
    ip_address: data?.ip_address || null,
    user_agent: data?.user_agent || null,
    device_platform: data?.device_platform || null,
    referral_source: data?.referral_source || null,
    campaign: data?.campaign || null,
    follow_up_metadata: data?.follow_up_metadata || null,
  };

  try {
    return await delegate.upsert({
      where: { user_id: data.user_id },
      create: {
        ...payload,
        user_id: data.user_id,
        registration_attempts: createAttempts,
        first_registered_at: now,
        last_registration_attempt_at: now,
      },
      update: {
        ...payload,
        last_registration_attempt_at: now,
        updated_at: now,
        ...(shouldIncrementAttempts
          ? {
              registration_attempts: {
                increment: attemptsIncrement,
              },
            }
          : {}),
      },
    });
  } catch (error) {
    if (error?.code === 'P2021' || error?.code === 'P2022') {
      // Table/column may be missing before migration is applied.
      return null;
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update registration follow-up account status without mutating other profile fields.
 *
 * @param {string} userId - User ID
 * @param {string} accountStatus - User status enum value
 * @returns {Promise<Object|null>} Update result or null when model not available
 */
const updateRegistrationFollowUpStatus = async (userId, accountStatus) => {
  const delegate = prisma?.registration_follow_up;
  if (!delegate || typeof delegate.updateMany !== 'function') {
    return null;
  }

  try {
    return await delegate.updateMany({
      where: {
        user_id: userId,
        deleted_at: null,
      },
      data: {
        account_status: accountStatus,
        updated_at: new Date(),
      },
    });
  } catch (error) {
    if (error?.code === 'P2021' || error?.code === 'P2022') {
      return null;
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update user status
 *
 * @param {string} userId - User ID
 * @param {string} status - New status
 * @returns {Promise<Object>} Updated user
 */
const updateUserStatus = async (userId, status) => {
  try {
    return await prisma.user.update({
      where: { id: userId },
      data: {
        status,
        updated_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.auth.user_not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find user by email
 *
 * @param {string} email - User email
 * @returns {Promise<Object|null>} User object or null
 */
const findUserByEmail = async (email) => {
  try {
    return await withPrismaConnectionRetry(() =>
      prisma.user.findFirst({
        where: {
          email,
          deleted_at: null
        },
        include: {
          profile: true,
          tenant: true,
          facility: {
            select: facilitySelect
          }
        }
      })
    );
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{
      originalError: error.message,
      errorCode: error?.code || null,
      errorName: error?.name || null,
      meta: error?.meta || null,
      operation: 'findUsersByIdentifier',
    }]);
  }
};

/**
 * Find user by phone
 *
 * @param {string} phone - User phone
 * @returns {Promise<Object|null>} User object or null
 */
const findUserByPhone = async (phone) => {
  try {
    return await withPrismaConnectionRetry(() =>
      prisma.user.findFirst({
        where: {
          phone,
          deleted_at: null
        },
        include: {
          profile: true,
          tenant: true,
          facility: {
            select: facilitySelect
          }
        }
      })
    );
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find all users by identifier (email or phone) across all tenants
 *
 * @param {string} identifier - User email or phone
 * @returns {Promise<Array>} Array of user objects with tenant info
 */
const findUsersByIdentifier = async (identifier) => {
  const normalizedIdentifier = String(identifier || '').trim();
  const isEmail = normalizedIdentifier.includes('@');
  const baseWhere = isEmail
    ? { email: normalizedIdentifier.toLowerCase() }
    : { phone: normalizedIdentifier };
  const findManyWithRetry = (args) =>
    withPrismaConnectionRetry(() => prisma.user.findMany(args));

  try {
    const users = await findManyWithRetry({
      where: {
        ...baseWhere,
        deleted_at: null
      },
      include: {
        tenant: {
          select: {
            id: true,
            name: true,
            slug: true
          }
        }
      },
      orderBy: {
        created_at: 'desc'
      }
    });

    return users;
  } catch (error) {
    if (isMissingSchemaArtifactError(error)) {
      try {
        const legacyUsers = await findManyWithRetry({
          where: baseWhere,
          include: {
            tenant: {
              select: {
                id: true,
                name: true,
              }
            }
          }
        });

        const filteredLegacyUsers = legacyUsers.filter((user) =>
          !Object.prototype.hasOwnProperty.call(user, 'deleted_at') || user.deleted_at === null
        );

        return sortUsersByCreatedAtDesc(filteredLegacyUsers);
      } catch (legacyError) {
        if (isMissingSchemaArtifactError(legacyError)) {
          try {
            const minimalUsers = await findManyWithRetry({
              where: baseWhere,
            });

            const filteredMinimalUsers = minimalUsers.filter((user) =>
              !Object.prototype.hasOwnProperty.call(user, 'deleted_at') || user.deleted_at === null
            );

            return sortUsersByCreatedAtDesc(filteredMinimalUsers);
          } catch (minimalError) {
            throw new HttpError('errors.database.unexpected', 500, [{ originalError: minimalError.message }]);
          }
        }
        throw new HttpError('errors.database.unexpected', 500, [{ originalError: legacyError.message }]);
      }
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get all facilities accessible to a user within a tenant
 *
 * @param {string} userId - User ID
 * @param {string} tenantId - Tenant ID
 * @returns {Promise<Array>} Array of facility objects
 */
const getUserFacilities = async (userId, tenantId) => {
  try {
    // Get user's direct facility
    const user = await prisma.user.findFirst({
      where: {
        id: userId,
        tenant_id: tenantId,
        deleted_at: null
      },
      select: {
        facility_id: true
      }
    });

    const facilityIds = new Set();

    // Add user's direct facility if exists
    if (user?.facility_id) {
      facilityIds.add(user.facility_id);
    }

    // Get facility IDs from user roles (both from role.facility_id and user_role.facility_id)
    const userRoles = await prisma.user_role.findMany({
      where: {
        user_id: userId,
        tenant_id: tenantId,
        deleted_at: null
      },
      include: {
        role: true
      }
    });

    // Collect facility IDs from roles and user_role entries
    userRoles.forEach(ur => {
      if (ur.facility_id) {
        facilityIds.add(ur.facility_id);
      }
      if (ur.role?.facility_id) {
        facilityIds.add(ur.role.facility_id);
      }
    });

    // If no facilities found, return empty array
    if (facilityIds.size === 0) {
      return [];
    }

    // Fetch all unique facilities
    const facilities = await prisma.facility.findMany({
      where: {
        id: { in: Array.from(facilityIds) },
        tenant_id: tenantId,
        deleted_at: null,
        is_active: true
      },
      select: facilitySelect
    });

    return facilities;
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findUserByEmailAndTenant,
  findUserByPhoneAndTenant,
  findUserById,
  findUserByEmail,
  findUserByPhone,
  findUsersByIdentifier,
  getUserFacilities,
  createUser,
  registerFacilityOwner,
  updateUserPassword,
  findEnabledUserMfas,
  touchUserMfaLastUsed,
  updateUserStatus,
  createSession,
  findSessionByRefreshToken,
  revokeSession,
  revokeAllUserSessions,
  createVerificationToken,
  findVerificationToken,
  markTokenAsUsed,
  deleteExpiredTokens,
  upsertRegistrationFollowUp,
  updateRegistrationFollowUpStatus,
};
