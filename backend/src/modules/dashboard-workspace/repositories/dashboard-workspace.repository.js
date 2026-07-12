const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForFilter, resolvePublicIdentifier } = require('@lib/billing/identifiers');

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

const resolveWorkspaceScope = async ({ filters = {}, user = {}, effectiveRole = null }) => {
  try {
    const requestedTenantId = filters.tenant_id || filters.tenantId;
    const requestedFacilityId = filters.facility_id || filters.facilityId;
    const requestedBranchId = filters.branch_id || filters.branchId;
    const userTenantId = user.tenant_id || user.tenantId || null;
    const userFacilityId = user.facility_id || user.facilityId || null;
    const userBranchId = user.branch_id || user.branchId || null;

    if (effectiveRole === 'SUPER_ADMIN') {
      const tenantId = await resolveIdentifierForFilter({
        value: requestedTenantId || userTenantId,
        model: 'tenant',
      });

      if (!tenantId) {
        return { state: 'platform_ready', scope: null };
      }

      const facilityId = await resolveIdentifierForFilter({
        value: requestedFacilityId || userFacilityId,
        model: 'facility',
        where: { tenant_id: tenantId },
      });

      const branchId = await resolveIdentifierForFilter({
        value: requestedBranchId || userBranchId,
        model: 'branch',
        where: { tenant_id: tenantId },
      });

      let resolvedFacilityId = facilityId || null;
      if (branchId) {
        const branch = await prisma.branch.findFirst({
          where: {
            id: branchId,
            tenant_id: tenantId,
            deleted_at: null,
          },
          select: { facility_id: true },
        });
        if (!branch) {
          throw new HttpError('errors.validation.invalid', 400, [{ field: 'branch_id' }]);
        }
        if (!resolvedFacilityId) {
          resolvedFacilityId = branch.facility_id || null;
        }
      }

      return {
        state: 'ready',
        scope: {
          tenant_id: tenantId,
          facility_id: resolvedFacilityId,
          branch_id: branchId || null,
        },
      };
    }

    if (!userTenantId) {
      throw new HttpError('errors.auth.scope_mismatch', 403);
    }

    const facilityId = await resolveIdentifierForFilter({
      value: requestedFacilityId || userFacilityId,
      model: 'facility',
      where: { tenant_id: userTenantId },
    });

    const branchId = await resolveIdentifierForFilter({
      value: requestedBranchId || userBranchId,
      model: 'branch',
      where: { tenant_id: userTenantId },
    });

    return {
      state: 'ready',
      scope: {
        tenant_id: userTenantId,
        facility_id: facilityId || userFacilityId || null,
        branch_id: branchId || userBranchId || null,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findLookups = async ({ scope = null, includeTenants = false }) => {
  try {
    const [tenants, facilities, branches] = await Promise.all([
      includeTenants
        ? prisma.tenant.findMany({
            where: { deleted_at: null },
            select: { id: true, human_friendly_id: true, name: true },
            orderBy: { name: 'asc' },
            take: 200,
          })
        : Promise.resolve([]),
      scope?.tenant_id
        ? prisma.facility.findMany({
            where: { tenant_id: scope.tenant_id, deleted_at: null },
            select: { id: true, human_friendly_id: true, name: true, facility_type: true },
            orderBy: { name: 'asc' },
          })
        : Promise.resolve([]),
      scope?.tenant_id
        ? prisma.branch.findMany({
            where: {
              tenant_id: scope.tenant_id,
              ...(scope?.facility_id ? { facility_id: scope.facility_id } : {}),
              deleted_at: null,
            },
            select: { id: true, human_friendly_id: true, name: true, facility_id: true },
            orderBy: { name: 'asc' },
          })
        : Promise.resolve([]),
    ]);

    return { tenants, facilities, branches };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findFacilityContext = async (scope = {}) => {
  try {
    if (!scope?.tenant_id) return null;

    if (scope.facility_id) {
      return await prisma.facility.findFirst({
        where: {
          id: scope.facility_id,
          tenant_id: scope.tenant_id,
          deleted_at: null,
        },
        select: { id: true, human_friendly_id: true, name: true, facility_type: true },
      });
    }

    return await prisma.facility.findFirst({
      where: { tenant_id: scope.tenant_id, deleted_at: null },
      select: { id: true, human_friendly_id: true, name: true, facility_type: true },
      orderBy: { created_at: 'asc' },
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findCurrentSubscription = async (scope = {}) => {
  try {
    if (!scope?.tenant_id) return null;

    return await prisma.subscription.findFirst({
      where: {
        tenant_id: scope.tenant_id,
        deleted_at: null,
        status: { in: ['ACTIVE', 'TRIAL', 'PAST_DUE'] },
      },
      include: {
        plan: {
          select: {
            id: true,
            human_friendly_id: true,
            name: true,
            tier_code: true,
            billing_cycle: true,
            max_users: true,
            max_facilities: true,
            max_storage_mb: true,
            max_modules: true,
            plan_fit_warning_percent: true,
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
                is_add_on: true,
              },
            },
          },
        },
      },
      orderBy: { updated_at: 'desc' },
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const countRows = async ({ model, where = {} }) => {
  try {
    return await prisma[model].count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const sumRows = async ({ model, where = {}, field }) => {
  try {
    const result = await prisma[model].aggregate({
      where,
      _sum: {
        [field]: true,
      },
    });
    return Number(result?._sum?.[field] || 0);
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findRows = async ({ model, where = {}, select = undefined, orderBy = undefined, take = 20, skip = 0 }) => {
  try {
    return await prisma[model].findMany({
      where,
      select,
      orderBy,
      take,
      skip,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const normalizeContact = (value) => {
  const normalized = String(value || '').trim();
  return normalized || null;
};

const buildFollowUpSubtitle = (email, phone) => {
  const parts = [email, phone].filter(Boolean);
  return parts.join(' · ');
};

const findPlatformFollowUps = async ({ limit = 5 } = {}) => {
  try {
    const now = new Date();
    const expiringWindow = new Date(now);
    expiringWindow.setDate(expiringWindow.getDate() + 30);

    const subscriptions = await prisma.subscription.findMany({
      where: {
        deleted_at: null,
        OR: [
          { status: { in: ['PAST_DUE', 'CANCELLED'] } },
          {
            status: { in: ['ACTIVE', 'TRIAL'] },
            end_date: { lte: expiringWindow },
          },
        ],
      },
      select: {
        id: true,
        human_friendly_id: true,
        status: true,
        end_date: true,
        tenant: {
          select: {
            id: true,
            human_friendly_id: true,
            name: true,
          },
        },
      },
      orderBy: [{ end_date: 'asc' }, { updated_at: 'desc' }],
      take: Math.max(1, Number(limit || 5)),
    });

    const tenantIds = Array.from(
      new Set(subscriptions.map((entry) => entry.tenant?.id).filter(Boolean))
    );

    const adminContacts = tenantIds.length
      ? await prisma.user_role.findMany({
          where: {
            deleted_at: null,
            tenant_id: { in: tenantIds },
            role: {
              deleted_at: null,
              name: 'TENANT_ADMIN',
            },
          },
          select: {
            tenant_id: true,
            user: {
              select: {
                email: true,
                phone: true,
              },
            },
          },
          orderBy: { created_at: 'asc' },
        })
      : [];

    const contactByTenantId = new Map();
    for (const entry of adminContacts) {
      if (!entry.tenant_id || contactByTenantId.has(entry.tenant_id)) continue;
      contactByTenantId.set(entry.tenant_id, {
        email: normalizeContact(entry.user?.email),
        phone: normalizeContact(entry.user?.phone),
      });
    }

    return subscriptions
      .map((subscription) => {
        const tenant = subscription.tenant || {};
        const publicId = safePublicId(subscription.human_friendly_id, subscription.id);
        const tenantPublicId = safePublicId(tenant.human_friendly_id, tenant.id);
        if (!publicId || !tenantPublicId) return null;

        const contact = contactByTenantId.get(tenant.id) || {};
        const email = contact.email;
        const phone = contact.phone;
        const status = String(subscription.status || '').toUpperCase();
        const severity = ['PAST_DUE', 'CANCELLED'].includes(status) ? 'high' : 'medium';

        return {
          id: `subscription_follow_up:${publicId}`,
          kind: 'subscription_follow_up',
          queue: 'subscription_follow_ups',
          module_slug: 'subscriptions',
          human_friendly_id: publicId,
          title: tenant.name || tenantPublicId,
          subtitle: buildFollowUpSubtitle(email, phone),
          status,
          severity,
          occurred_at: subscription.end_date || null,
          target: {
            module_slug: 'subscriptions',
            resource: 'subscriptions',
            public_id: publicId,
            action: 'view',
          },
          meta: {
            tenant_id: tenantPublicId,
            tenant_name: tenant.name || null,
            email,
            phone,
            expires_at: subscription.end_date || null,
          },
        };
      })
      .filter(Boolean);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findPlatformAlerts = async ({ limit = 3 } = {}) => {
  try {
    const now = new Date();
    const expiringWindow = new Date(now);
    expiringWindow.setDate(expiringWindow.getDate() + 30);

    const [
      pastDueSubscriptions,
      entitlementIssues,
      tenantsWithoutSubscription,
      integrationErrors,
    ] = await Promise.all([
      prisma.subscription.count({
        where: { deleted_at: null, status: 'PAST_DUE' },
      }),
      prisma.subscription.count({
        where: {
          deleted_at: null,
          plan_fit_status: { in: ['APPROACHING_LIMIT', 'EXCEEDED'] },
        },
      }),
      prisma.tenant.count({
        where: {
          deleted_at: null,
          subscriptions: {
            none: {
              deleted_at: null,
              status: { in: ['ACTIVE', 'TRIAL', 'PAST_DUE'] },
            },
          },
        },
      }),
      prisma.integration.count({
        where: {
          deleted_at: null,
          status: { in: ['ERROR', 'INACTIVE'] },
        },
      }),
    ]);

    const alerts = [
      {
        id: 'subscription_past_due',
        kind: 'subscription_past_due',
        severity: pastDueSubscriptions > 0 ? 'high' : 'info',
        count: pastDueSubscriptions,
        target: {
          module_slug: 'subscriptions',
          resource: 'subscriptions',
          public_id: null,
          action: 'list',
          query: { queue: 'PAST_DUE' },
        },
      },
      {
        id: 'entitlement_issues',
        kind: 'entitlement_issues',
        severity: entitlementIssues > 0 ? 'warning' : 'info',
        count: entitlementIssues,
        target: {
          module_slug: 'subscriptions',
          resource: 'modules',
          public_id: null,
          action: 'list',
        },
      },
      {
        id: 'tenants_without_subscription',
        kind: 'tenants_without_subscription',
        severity: tenantsWithoutSubscription > 0 ? 'warning' : 'info',
        count: tenantsWithoutSubscription,
        target: {
          module_slug: 'settings',
          resource: 'tenants',
          public_id: null,
          action: 'list',
        },
      },
      {
        id: 'integration_errors',
        kind: 'integration_errors',
        severity: integrationErrors > 0 ? 'high' : 'info',
        count: integrationErrors,
        target: {
          module_slug: 'settings',
          resource: 'integrations',
          public_id: null,
          action: 'list',
        },
      },
    ];

    return alerts
      .filter((entry) => Number(entry.count || 0) > 0)
      .slice(0, Math.max(1, Number(limit || 3)));
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findTenantFollowUps = async ({ tenantId, limit = 5 } = {}) => {
  try {
    if (!tenantId) return [];

    const now = new Date();
    const expiringWindow = new Date(now);
    expiringWindow.setDate(expiringWindow.getDate() + 30);
    const safeLimit = Math.max(1, Number(limit || 5));

    const [facilities, subscription] = await Promise.all([
      prisma.facility.findMany({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          OR: [
            { is_active: false },
            {
              is_active: true,
              users: { none: { deleted_at: null } },
            },
          ],
        },
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
          is_active: true,
          facility_type: true,
          updated_at: true,
          created_at: true,
        },
        orderBy: [{ is_active: 'asc' }, { updated_at: 'desc' }],
        take: safeLimit,
      }),
      prisma.subscription.findFirst({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          OR: [
            { status: { in: ['PAST_DUE', 'CANCELLED'] } },
            {
              status: { in: ['ACTIVE', 'TRIAL'] },
              end_date: { lte: expiringWindow },
            },
          ],
        },
        select: {
          id: true,
          human_friendly_id: true,
          status: true,
          end_date: true,
        },
        orderBy: [{ end_date: 'asc' }, { updated_at: 'desc' }],
      }),
    ]);

    const items = facilities
      .map((facility) => {
        const publicId = safePublicId(facility.human_friendly_id, facility.id);
        if (!publicId) return null;

        const isInactive = !facility.is_active;
        return {
          id: `facility_follow_up:${publicId}`,
          kind: isInactive ? 'inactive_facility' : 'facility_setup_pending',
          queue: 'facility_governance',
          module_slug: 'settings',
          human_friendly_id: publicId,
          title: facility.name || publicId,
          subtitle: isInactive ? 'Inactive facility' : 'No users assigned yet',
          status: isInactive ? 'INACTIVE' : 'SETUP_PENDING',
          severity: isInactive ? 'high' : 'medium',
          occurred_at: facility.updated_at || facility.created_at || null,
          target: {
            module_slug: 'settings',
            resource: 'facilities',
            public_id: publicId,
            action: 'view',
          },
        };
      })
      .filter(Boolean);

    if (subscription) {
      const publicId = safePublicId(subscription.human_friendly_id, subscription.id);
      if (publicId) {
        const status = String(subscription.status || '').toUpperCase();
        items.unshift({
          id: `subscription_follow_up:${publicId}`,
          kind: 'subscription_follow_up',
          queue: 'subscription_follow_ups',
          module_slug: 'subscriptions',
          human_friendly_id: publicId,
          title: 'Subscription renewal',
          subtitle: status === 'PAST_DUE' ? 'Payment overdue' : 'Renewal approaching',
          status,
          severity: status === 'PAST_DUE' ? 'high' : 'medium',
          occurred_at: subscription.end_date || null,
          target: {
            module_slug: 'subscriptions',
            resource: 'subscriptions',
            public_id: publicId,
            action: 'view',
          },
        });
      }
    }

    return items.slice(0, safeLimit);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findTenantAlerts = async ({ tenantId, limit = 3 } = {}) => {
  try {
    if (!tenantId) return [];

    const facilityWhere = { tenant_id: tenantId, deleted_at: null };
    const [
      facilitiesTotal,
      inactiveFacilities,
      facilitiesWithoutUsers,
      subscription,
      entitlementDeniedModules,
    ] = await Promise.all([
      prisma.facility.count({ where: facilityWhere }),
      prisma.facility.count({ where: { ...facilityWhere, is_active: false } }),
      prisma.facility.count({
        where: {
          ...facilityWhere,
          is_active: true,
          users: { none: { deleted_at: null } },
        },
      }),
      prisma.subscription.findFirst({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          status: { in: ['ACTIVE', 'TRIAL', 'PAST_DUE'] },
        },
        select: {
          id: true,
          human_friendly_id: true,
          status: true,
          plan_fit_status: true,
          plan: {
            select: {
              max_facilities: true,
            },
          },
        },
        orderBy: { updated_at: 'desc' },
      }),
      prisma.module_subscription.count({
        where: {
          deleted_at: null,
          entitlement_denied: true,
          subscription: {
            tenant_id: tenantId,
            deleted_at: null,
          },
        },
      }),
    ]);

    const alerts = [
      {
        id: 'no_facilities',
        kind: 'no_facilities',
        module_slug: 'settings',
        severity: 'critical',
        count: facilitiesTotal === 0 ? 1 : 0,
        target: {
          module_slug: 'settings',
          resource: 'facilities',
          public_id: null,
          action: 'create',
        },
      },
      {
        id: 'inactive_facilities',
        kind: 'inactive_facilities',
        module_slug: 'settings',
        severity: 'warning',
        count: inactiveFacilities,
        target: {
          module_slug: 'settings',
          resource: 'facilities',
          public_id: null,
          action: 'list',
          query: { status: 'INACTIVE' },
        },
      },
      {
        id: 'facility_setup_pending',
        kind: 'facility_setup_pending',
        module_slug: 'settings',
        severity: 'medium',
        count: facilitiesWithoutUsers,
        target: {
          module_slug: 'settings',
          resource: 'facilities',
          public_id: null,
          action: 'list',
        },
      },
      {
        id: 'subscription_past_due',
        kind: 'subscription_past_due',
        module_slug: 'subscriptions',
        severity: 'high',
        count: subscription?.status === 'PAST_DUE' ? 1 : 0,
        target: {
          module_slug: 'subscriptions',
          resource: 'subscriptions',
          public_id: safePublicId(subscription?.human_friendly_id, subscription?.id),
          action: 'view',
        },
      },
      {
        id: 'plan_limit_pressure',
        kind: 'plan_limit_pressure',
        module_slug: 'subscriptions',
        severity: 'high',
        count: ['APPROACHING_LIMIT', 'EXCEEDED'].includes(
          String(subscription?.plan_fit_status || '').toUpperCase()
        )
          ? 1
          : 0,
        target: {
          module_slug: 'subscriptions',
          resource: 'subscriptions',
          public_id: safePublicId(subscription?.human_friendly_id, subscription?.id),
          action: 'view',
        },
      },
      {
        id: 'entitlement_denied_modules',
        kind: 'entitlement_denied_modules',
        module_slug: 'subscriptions',
        severity: 'warning',
        count: entitlementDeniedModules,
        target: {
          module_slug: 'subscriptions',
          resource: 'modules',
          public_id: null,
          action: 'list',
        },
      },
    ];

    return alerts
      .filter((entry) => Number(entry.count || 0) > 0)
      .slice(0, Math.max(1, Number(limit || 3)));
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  countRows,
  findCurrentSubscription,
  findFacilityContext,
  findLookups,
  findPlatformAlerts,
  findPlatformFollowUps,
  findTenantAlerts,
  findTenantFollowUps,
  findRows,
  resolveWorkspaceScope,
  safePublicId,
  sumRows,
};
