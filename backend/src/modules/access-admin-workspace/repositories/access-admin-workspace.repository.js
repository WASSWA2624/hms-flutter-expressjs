const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const { ROLES } = require('@config/roles');
const tenantFacilityRepository = require('@repositories/tenant-facility-workspace/tenant-facility-workspace.repository');

const DEMO_EMAIL_SUFFIX = '@hosspi.com';

const mapError = (error) => {
  if (error instanceof HttpError) throw error;
  throw new HttpError('errors.database.unexpected', 500, [{ originalError: error?.message }]);
};

const scopedWhere = (scope = {}, options = {}) => {
  const { includeFacility = false } = options;
  const where = { deleted_at: null };

  if (scope.tenant_id) {
    where.tenant_id = scope.tenant_id;
  }

  if (includeFacility && scope.facility_id) {
    where.facility_id = scope.facility_id;
  }

  return where;
};

const buildSearchFilter = (search = '') => {
  const term = String(search || '').trim();
  if (!term) return null;
  // MySQL/MariaDB Prisma provider does not support `mode: 'insensitive'`.
  // Demo data uses lowercase emails and the default collation is case-insensitive.
  return {
    OR: [
      { email: { contains: term } },
      { position_title: { contains: term } },
      { human_friendly_id: { contains: term } },
      { name: { contains: term } },
      { description: { contains: term } },
    ],
  };
};

const countUsers = async (scope = {}, filters = {}) => {
  try {
    const where = {
      ...scopedWhere(scope, { includeFacility: true }),
      ...(filters.status ? { status: filters.status } : {}),
    };
    const searchFilter = buildSearchFilter(filters.search);
    if (searchFilter) {
      where.OR = searchFilter.OR.filter((entry) => !entry.name && !entry.description);
    }
    return prisma.user.count({ where });
  } catch (error) {
    mapError(error);
  }
};

const countRoles = async (scope = {}, filters = {}) => {
  try {
    const where = {
      ...scopedWhere(scope, { includeFacility: true }),
    };
    const searchFilter = buildSearchFilter(filters.search);
    if (searchFilter) {
      where.OR = searchFilter.OR.filter((entry) => !entry.email && !entry.position_title);
    }
    return prisma.role.count({ where });
  } catch (error) {
    mapError(error);
  }
};

const countPermissions = async (scope = {}, filters = {}) => {
  try {
    const where = scopedWhere(scope);
    const searchFilter = buildSearchFilter(filters.search);
    if (searchFilter) {
      where.OR = searchFilter.OR.filter(
        (entry) => !entry.email && !entry.position_title && !entry.description?.contains
      );
    }
    return prisma.permission.count({ where });
  } catch (error) {
    mapError(error);
  }
};

const countUserRoles = async (scope = {}) => {
  try {
    return prisma.user_role.count({
      where: scopedWhere(scope, { includeFacility: true }),
    });
  } catch (error) {
    mapError(error);
  }
};

const countDemoUsers = async (scope = {}) => {
  try {
    return prisma.user.count({
      where: {
        ...scopedWhere(scope, { includeFacility: true }),
        email: { endsWith: DEMO_EMAIL_SUFFIX },
      },
    });
  } catch (error) {
    mapError(error);
  }
};

const findSummary = async (scope = {}) => {
  try {
    const [
      totalUsers,
      activeUsers,
      inactiveUsers,
      totalRoles,
      totalPermissions,
      totalAssignments,
      demoUsers,
    ] = await Promise.all([
      countUsers(scope),
      prisma.user.count({
        where: { ...scopedWhere(scope, { includeFacility: true }), status: 'ACTIVE' },
      }),
      prisma.user.count({
        where: {
          ...scopedWhere(scope, { includeFacility: true }),
          status: { in: ['INACTIVE', 'SUSPENDED'] },
        },
      }),
      countRoles(scope),
      countPermissions(scope),
      countUserRoles(scope),
      countDemoUsers(scope),
    ]);

    return {
      total_users: totalUsers,
      active_users: activeUsers,
      inactive_users: inactiveUsers,
      total_roles: totalRoles,
      total_permissions: totalPermissions,
      total_assignments: totalAssignments,
      demo_users: demoUsers,
    };
  } catch (error) {
    mapError(error);
  }
};

const findUsers = async ({ scope = {}, filters = {}, skip = 0, take = 20, orderBy = { updated_at: 'desc' } }) => {
  try {
    const where = {
      ...scopedWhere(scope, { includeFacility: true }),
      ...(filters.status ? { status: filters.status } : {}),
      ...(filters.is_demo
        ? { email: { endsWith: DEMO_EMAIL_SUFFIX } }
        : {}),
    };
    const searchFilter = buildSearchFilter(filters.search);
    if (searchFilter) {
      where.OR = searchFilter.OR.filter((entry) => !entry.name && !entry.description);
    }

    const [items, total] = await Promise.all([
      prisma.user.findMany({
        where,
        skip,
        take,
        orderBy,
        include: {
          profile: {
            where: { deleted_at: null },
            select: {
              id: true,
              human_friendly_id: true,
              first_name: true,
              last_name: true,
            },
          },
          roles: {
            where: { deleted_at: null },
            include: {
              role: {
                select: {
                  id: true,
                  human_friendly_id: true,
                  name: true,
                },
              },
            },
          },
          staff_profile: {
            where: { deleted_at: null },
            select: {
              id: true,
              human_friendly_id: true,
            },
          },
        },
      }),
      prisma.user.count({ where }),
    ]);

    return { items, total };
  } catch (error) {
    mapError(error);
  }
};

const findRoles = async ({ scope = {}, filters = {}, skip = 0, take = 20, orderBy = { name: 'asc' } }) => {
  try {
    const where = scopedWhere(scope, { includeFacility: true });
    const searchFilter = buildSearchFilter(filters.search);
    if (searchFilter) {
      where.OR = searchFilter.OR.filter((entry) => !entry.email && !entry.position_title);
    }

    const [items, total] = await Promise.all([
      prisma.role.findMany({
        where,
        skip,
        take,
        orderBy,
        include: {
          permissions: {
            where: { deleted_at: null },
            include: {
              permission: {
                select: {
                  id: true,
                  human_friendly_id: true,
                  name: true,
                },
              },
            },
          },
          _count: {
            select: {
              users: { where: { deleted_at: null } },
            },
          },
        },
      }),
      prisma.role.count({ where }),
    ]);

    return { items, total };
  } catch (error) {
    mapError(error);
  }
};

const findPermissions = async ({ scope = {}, filters = {}, skip = 0, take = 20, orderBy = { name: 'asc' } }) => {
  try {
    const where = scopedWhere(scope);
    const searchFilter = buildSearchFilter(filters.search);
    if (searchFilter) {
      where.OR = searchFilter.OR.filter(
        (entry) => !entry.email && !entry.position_title
      );
    }

    const [items, total] = await Promise.all([
      prisma.permission.findMany({
        where,
        skip,
        take,
        orderBy,
        include: {
          _count: {
            select: {
              roles: { where: { deleted_at: null } },
              users: { where: { deleted_at: null } },
            },
          },
        },
      }),
      prisma.permission.count({ where }),
    ]);

    return { items, total };
  } catch (error) {
    mapError(error);
  }
};

const findUserRoles = async ({ scope = {}, filters = {}, skip = 0, take = 20, orderBy = { updated_at: 'desc' } }) => {
  try {
    const where = scopedWhere(scope, { includeFacility: true });
    if (filters.user_id) where.user_id = filters.user_id;
    if (filters.role_id) where.role_id = filters.role_id;

    const [items, total] = await Promise.all([
      prisma.user_role.findMany({
        where,
        skip,
        take,
        orderBy,
        include: {
          user: {
            select: {
              id: true,
              human_friendly_id: true,
              email: true,
              position_title: true,
            },
          },
          role: {
            select: {
              id: true,
              human_friendly_id: true,
              name: true,
            },
          },
        },
      }),
      prisma.user_role.count({ where }),
    ]);

    return { items, total };
  } catch (error) {
    mapError(error);
  }
};

const findRolePermissions = async ({ scope = {}, filters = {}, skip = 0, take = 20, orderBy = { updated_at: 'desc' } }) => {
  try {
    const where = { deleted_at: null };
    if (filters.role_id) where.role_id = filters.role_id;
    if (filters.permission_id) where.permission_id = filters.permission_id;

    const roleWhere = scopedWhere(scope, { includeFacility: true });

    const [items, total] = await Promise.all([
      prisma.role_permission.findMany({
        where: {
          ...where,
          role: roleWhere,
        },
        skip,
        take,
        orderBy,
        include: {
          role: {
            select: {
              id: true,
              human_friendly_id: true,
              name: true,
              tenant_id: true,
              facility_id: true,
            },
          },
          permission: {
            select: {
              id: true,
              human_friendly_id: true,
              name: true,
              tenant_id: true,
            },
          },
        },
      }),
      prisma.role_permission.count({
        where: {
          ...where,
          role: roleWhere,
        },
      }),
    ]);

    return { items, total };
  } catch (error) {
    mapError(error);
  }
};

const findModuleEntitlements = async (scope = {}) => {
  try {
    if (!scope.tenant_id) return { items: [], total: 0 };

    const subscription = await prisma.subscription.findFirst({
      where: {
        tenant_id: scope.tenant_id,
        deleted_at: null,
        status: { in: ['ACTIVE', 'TRIAL', 'PAST_DUE'] },
      },
      orderBy: { updated_at: 'desc' },
      include: {
        plan: {
          select: {
            id: true,
            human_friendly_id: true,
            name: true,
            tier_code: true,
          },
        },
        module_subscriptions: {
          where: { deleted_at: null },
          include: {
            module: {
              select: {
                id: true,
                human_friendly_id: true,
                name: true,
                slug: true,
                module_group: true,
              },
            },
          },
          orderBy: [{ is_active: 'desc' }, { updated_at: 'desc' }],
        },
      },
    });

    if (!subscription) {
      return { items: [], total: 0, subscription: null };
    }

    const items = subscription.module_subscriptions || [];
    return { items, total: items.length, subscription };
  } catch (error) {
    mapError(error);
  }
};

const findUserByIdentifier = async (identifier, scope = {}) => {
  try {
    const userId = await resolveIdentifierForFilter({
      value: identifier,
      model: 'user',
      where: scopedWhere(scope, { includeFacility: true }),
    });
    if (!userId) return null;

    return prisma.user.findFirst({
      where: { id: userId, deleted_at: null },
      include: {
        profile: { where: { deleted_at: null } },
        roles: {
          where: { deleted_at: null },
          include: { role: true },
        },
        permissions: {
          where: { deleted_at: null },
          include: { permission: true },
        },
        staff_profile: { where: { deleted_at: null } },
      },
    });
  } catch (error) {
    mapError(error);
  }
};

const findLookups = async (scope = {}, includeAllTenants = false) => {
  try {
    const [tenants, facilities, roles, permissions] = await Promise.all([
      tenantFacilityRepository.findTenants(scope, includeAllTenants),
      tenantFacilityRepository.findFacilities(scope?.tenant_id),
      prisma.role.findMany({
        where: scopedWhere(scope, { includeFacility: true }),
        orderBy: { name: 'asc' },
        take: 200,
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
          facility_id: true,
        },
      }),
      prisma.permission.findMany({
        where: scopedWhere(scope),
        orderBy: { name: 'asc' },
        take: 500,
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
        },
      }),
    ]);

    return { tenants, facilities, roles, permissions };
  } catch (error) {
    mapError(error);
  }
};

const updateUserStatus = async (userId, status) => {
  try {
    return prisma.user.update({
      where: { id: userId },
      data: { status },
    });
  } catch (error) {
    mapError(error);
  }
};

const resetDemoUserPassword = async (userId, passwordHash) => {
  try {
    return prisma.user.update({
      where: { id: userId },
      data: { password_hash: passwordHash },
    });
  } catch (error) {
    mapError(error);
  }
};

const isDemoUser = (user = {}) => {
  const email = String(user.email || '').trim().toLowerCase();
  return email.endsWith(DEMO_EMAIL_SUFFIX);
};

module.exports = {
  DEMO_EMAIL_SUFFIX,
  countDemoUsers,
  countPermissions,
  countRoles,
  countUserRoles,
  countUsers,
  findLookups,
  findModuleEntitlements,
  findPermissions,
  findRolePermissions,
  findRoles,
  findSummary,
  findUserByIdentifier,
  findUserRoles,
  findUsers,
  isDemoUser,
  resetDemoUserPassword,
  resolveWorkspaceScope: tenantFacilityRepository.resolveWorkspaceScope,
  ROLES,
  updateUserStatus,
};
