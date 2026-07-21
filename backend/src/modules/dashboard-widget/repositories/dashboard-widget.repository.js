/**
 * Dashboard widget repository
 *
 * @module modules/dashboard-widget/repositories
 * @description Data access layer for dashboard widget operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DAY_MS = 24 * 60 * 60 * 1000;

const ROLE_PACKS = Object.freeze({
  ADMIN: 'admin',
  SUPER_ADMIN: 'super_admin',
  TENANT_ADMIN: 'tenant_admin',
  FACILITY_ADMIN: 'facility_admin',
  DOCTOR: 'doctor',
  NURSE: 'nurse',
  LAB_TECH: 'lab_tech',
  RADIOLOGY_TECH: 'radiology_tech',
  PHARMACIST: 'pharmacist',
  RECEPTIONIST: 'receptionist',
  BILLING: 'billing',
  OPERATIONS: 'operations',
  HR: 'hr',
  BIOMED: 'biomed',
  HOUSE_KEEPER: 'house_keeper',
  AMBULANCE_OPERATOR: 'ambulance_operator',
  UNIT_MANAGER: 'unit_manager',
  WARD_MANAGER: 'ward_manager',
  ICU_MANAGER: 'icu_manager',
  THEATRE_MANAGER: 'theatre_manager',
  HOUSEKEEPING_MANAGER: 'housekeeping_manager',
  BIOMED_MANAGER: 'biomed_manager',
  MORTUARY_STAFF: 'mortuary_staff',
  MORTUARY_MANAGER: 'mortuary_manager',
  PATIENT_SAFE: 'patient_safe',
  LIMITED: 'limited'
});

const toNumber = (value) => {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  if (value && typeof value.toString === 'function') {
    const parsed = Number(value.toString());
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
};

const percentOf = (value, total) => {
  const safeTotal = toNumber(total);
  if (safeTotal <= 0) return 0;
  return Math.max(0, Math.min(100, Math.round((toNumber(value) / safeTotal) * 100)));
};

const startOfDay = (value = new Date()) => {
  const date = new Date(value);
  date.setHours(0, 0, 0, 0);
  return date;
};

const shiftDays = (value, dayOffset) => {
  const date = new Date(value);
  date.setDate(date.getDate() + dayOffset);
  return date;
};

const directScope = (scope = {}, options = {}) => {
  const { includeTenant = true, includeFacility = true } = options;
  const where = { deleted_at: null };
  if (includeTenant && scope.tenant_id) where.tenant_id = scope.tenant_id;
  if (includeFacility && scope.facility_id) where.facility_id = scope.facility_id;
  return where;
};

const staffPositionScope = (scope = {}) => {
  const where = {
    deleted_at: null,
  };
  if (scope.tenant_id) where.tenant_id = scope.tenant_id;
  if (scope.facility_id) where.facility_id = scope.facility_id;
  return where;
};

const patientRelationScope = (scope = {}) => {
  const where = { deleted_at: null };
  if (scope.tenant_id) where.tenant_id = scope.tenant_id;
  if (scope.facility_id) where.facility_id = scope.facility_id;
  return where;
};

const buildLabOrderScopeWhere = (scope = {}) => ({
  deleted_at: null,
  patient: patientRelationScope(scope)
});

const buildLabResultScopeWhere = (scope = {}) => ({
  deleted_at: null,
  lab_order_item: {
    deleted_at: null,
    lab_order: {
      deleted_at: null,
      patient: patientRelationScope(scope)
    }
  }
});

const buildRadiologyOrderScopeWhere = (scope = {}) => ({
  deleted_at: null,
  patient: patientRelationScope(scope)
});

const buildRadiologyResultScopeWhere = (scope = {}) => ({
  deleted_at: null,
  radiology_order: buildRadiologyOrderScopeWhere(scope)
});

const buildPharmacyOrderScopeWhere = (scope = {}) => ({
  deleted_at: null,
  patient: patientRelationScope(scope)
});

const buildDispenseLogScopeWhere = (scope = {}) => ({
  deleted_at: null,
  pharmacy_order_item: {
    deleted_at: null,
    pharmacy_order: {
      deleted_at: null,
      patient: patientRelationScope(scope)
    }
  }
});

const buildInventoryStockScopeWhere = (scope = {}) => {
  const where = {
    deleted_at: null,
    inventory_item: {
      deleted_at: null
    }
  };
  if (scope.tenant_id) where.inventory_item.tenant_id = scope.tenant_id;
  if (scope.facility_id) where.facility_id = scope.facility_id;
  return where;
};

const buildAmbulanceDispatchScopeWhere = (scope = {}) => ({
  deleted_at: null,
  emergency_case: directScope(scope, { includeTenant: true, includeFacility: true })
});

const buildAmbulanceTripScopeWhere = (scope = {}) => ({
  deleted_at: null,
  emergency_case: directScope(scope, { includeTenant: true, includeFacility: true })
});

const widgetInclude = {
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  report_definition: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
};

const countByStatuses = async (model, where, statuses = [], field = 'status') => {
  const counts = await Promise.all(
    statuses.map((status) => model.count({ where: { ...where, [field]: status } }))
  );
  return statuses.reduce((acc, status, index) => {
    acc[status] = counts[index];
    return acc;
  }, {});
};

const selectDateSeries = async (model, where, field) => {
  const rows = await model.findMany({
    where,
    select: { [field]: true }
  });
  return rows.map((row) => row[field]).filter(Boolean);
};

const sumField = async (model, where, field) => {
  const result = await model.aggregate({
    where,
    _sum: {
      [field]: true
    }
  });
  return toNumber(result?._sum?.[field]);
};

const countLowStock = async (where, factor = 1) => {
  const rows = await prisma.inventory_stock.findMany({
    where,
    select: {
      quantity: true,
      reorder_level: true
    }
  });
  return rows.filter((row) => {
    const reorderLevel = toNumber(row.reorder_level);
    const quantity = toNumber(row.quantity);
    if (reorderLevel <= 0) return false;
    return quantity <= Math.ceil(reorderLevel * factor);
  }).length;
};


const patientPortalZeroSummary = () => ({
  metrics: {
    myUpcomingAppointments: 0,
    myOpenBills: 0,
    myPrescriptions: 0,
    myReleasedResults: 0,
    myMessages: 0,
    myProfileStatus: 0
  },
  trendDates: [],
  statusCounts: {},
  activity: {}
});

const normalizeContactValue = (value) => String(value || '').trim();

const resolvePatientPortalPatient = async ({ scope = {}, userId = null, user = {} }) => {
  const userEmail = normalizeContactValue(user.email || user.user_email || user.email_address).toLowerCase();
  const userPhone = normalizeContactValue(user.phone || user.phone_number || user.msisdn);
  let resolvedEmail = userEmail;
  let resolvedPhone = userPhone;

  if ((!resolvedEmail && !resolvedPhone) && userId) {
    const userRecord = await prisma.user.findFirst({
      where: {
        id: userId,
        deleted_at: null,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {})
      },
      select: { email: true, phone: true }
    });
    resolvedEmail = normalizeContactValue(userRecord?.email).toLowerCase();
    resolvedPhone = normalizeContactValue(userRecord?.phone);
  }

  const contactFilters = [];
  if (resolvedEmail) {
    contactFilters.push({ contact_type: 'EMAIL', value: resolvedEmail });
  }
  if (resolvedPhone) {
    contactFilters.push({ contact_type: { in: ['PHONE', 'WHATSAPP'] }, value: resolvedPhone });
  }

  if (!contactFilters.length || !scope.tenant_id) {
    return null;
  }

  return prisma.patient.findFirst({
    where: {
      deleted_at: null,
      tenant_id: scope.tenant_id,
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      contacts: {
        some: {
          deleted_at: null,
          tenant_id: scope.tenant_id,
          OR: contactFilters
        }
      }
    },
    select: {
      id: true,
      tenant_id: true,
      facility_id: true,
      human_friendly_id: true,
      updated_at: true
    }
  });
};

  try {
      where: {
        tenant_id: tenantId,
        deleted_at: null
      },
      select: {
        facility_id: true
      }
    });
    if (!branch) {
    }
    return branch.facility_id || null;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find dashboard widget by ID
 *
 * @param {string} id - Dashboard widget ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Dashboard widget object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.dashboard_widget.findFirst({
      where: {
        id,
        deleted_at: null
      },
      include: {
        ...widgetInclude,
        ...include,
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many dashboard widgets with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of dashboard widgets
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.dashboard_widget.findMany({
      where,
      skip,
      take,
      orderBy,
      include: {
        ...widgetInclude,
        ...include,
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count dashboard widgets with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of dashboard widgets
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.dashboard_widget.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new dashboard widget
 *
 * @param {Object} data - Dashboard widget data
 * @returns {Promise<Object>} Created dashboard widget
 */
const create = async (data) => {
  try {
    return await prisma.dashboard_widget.create({
      data,
      include: widgetInclude
    });
  } catch (error) {
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key constraint violation
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update dashboard widget
 *
 * @param {string} id - Dashboard widget ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated dashboard widget
 */
const update = async (id, data) => {
  try {
    return await prisma.dashboard_widget.update({
      where: { id },
      data,
      include: widgetInclude
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.dashboard_widget.not_found', 404);
    }
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key constraint violation
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete dashboard widget
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Dashboard widget ID
 * @returns {Promise<Object>} Deleted dashboard widget
 */
const softDelete = async (id) => {
  try {
    return await prisma.dashboard_widget.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.dashboard_widget.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const countUnreadOpdNotifications = async ({ scope = {}, userId = null } = {}) => {
  try {
    const opdContextWhere = {
      AND: [
        { notification_type: 'SYSTEM' },
        {
          OR: [
            { title: { contains: 'OPD flow update' } },
            { title: { contains: 'OPD' } },
            { message: { contains: 'OPD flow update' } },
            { message: { contains: 'triage' } },
            { message: { contains: 'vitals' } },
            { message: { contains: 'doctor review' } },
            { message: { contains: 'disposition' } },
          ],
        },
      ],
    };

    const where = {
      deleted_at: null,
      read_at: null,
      AND: [opdContextWhere],
      ...(scope?.tenant_id ? { tenant_id: scope.tenant_id } : {}),
      ...(userId ? { user_id: userId } : {})
    };

    return await prisma.notification.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getDashboardSummaryByPack = async ({ packId, scope, days = 7, userId = null, user = {} }) => {
  try {
    const now = new Date();
    const todayStart = startOfDay(now);
    const trendStart = shiftDays(todayStart, -(days - 1));
    const window24h = new Date(now.getTime() - DAY_MS);

    const patientWhere = directScope(scope, { includeTenant: true, includeFacility: true });
    const appointmentWhere = directScope(scope, { includeTenant: true, includeFacility: true });
    const admissionWhere = directScope(scope, { includeTenant: true, includeFacility: true });
    const invoiceWhere = directScope(scope, { includeTenant: true, includeFacility: true });
    const paymentWhere = directScope(scope, { includeTenant: true, includeFacility: true });
    const labOrderWhere = buildLabOrderScopeWhere(scope);
    const labResultWhere = buildLabResultScopeWhere(scope);
    const radiologyOrderWhere = buildRadiologyOrderScopeWhere(scope);
    const radiologyResultWhere = buildRadiologyResultScopeWhere(scope);
    const pharmacyOrderWhere = buildPharmacyOrderScopeWhere(scope);
    const dispenseLogWhere = buildDispenseLogScopeWhere(scope);
    const inventoryStockWhere = buildInventoryStockScopeWhere(scope);
    const maintenanceWhere = {
      deleted_at: null,
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      ...(scope.tenant_id ? { facility: { is: { deleted_at: null, tenant_id: scope.tenant_id } } } : {})
    };
    const housekeepingWhere = {
      deleted_at: null,
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      ...(scope.tenant_id ? { facility: { is: { deleted_at: null, tenant_id: scope.tenant_id } } } : {})
    };
    const ambulanceDispatchWhere = buildAmbulanceDispatchScopeWhere(scope);
    const ambulanceTripWhere = buildAmbulanceTripScopeWhere(scope);
    const emergencyCaseWhere = directScope(scope, { includeTenant: true, includeFacility: true });
    const shiftWhere = directScope(scope, { includeTenant: true, includeFacility: true });
    const theatreCaseWhere = {
      deleted_at: null,
      encounter: directScope(scope, { includeTenant: true, includeFacility: true })
    };
    const mortuaryWhere = directScope(scope, { includeTenant: true, includeFacility: true });

    if (packId === ROLE_PACKS.SUPER_ADMIN) {
      const [
        tenantsTotal,
        tenantsActive,
        facilitiesTotal,
        facilitiesActive,
        subscriptionsTotal,
        subscriptionsActive,
        subscriptionsExpiring,
        moduleEntitlementIssues,
        tenantsWithoutSubscription,
        trendDates,
        subscriptionStatusCounts,
      ] = await Promise.all([
        prisma.tenant.count({ where: { deleted_at: null } }),
        prisma.tenant.count({ where: { deleted_at: null, is_active: true } }),
        prisma.facility.count({ where: { deleted_at: null } }),
        prisma.facility.count({ where: { deleted_at: null, is_active: true } }),
        prisma.subscription.count({ where: { deleted_at: null } }),
        prisma.subscription.count({
          where: { deleted_at: null, status: { in: ['ACTIVE', 'TRIAL'] } },
        }),
        prisma.subscription.count({
          where: {
            deleted_at: null,
            OR: [
              { status: 'PAST_DUE' },
              {
                status: { in: ['ACTIVE', 'TRIAL'] },
                end_date: { lte: shiftDays(todayStart, 30) },
              },
            ],
          },
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
        selectDateSeries(
          prisma.tenant,
          { deleted_at: null, created_at: { gte: trendStart } },
          'created_at'
        ),
        countByStatuses(
          prisma.subscription,
          { deleted_at: null },
          ['ACTIVE', 'TRIAL', 'PAST_DUE', 'CANCELLED']
        ),
      ]);

      const statusCounts = {
        ...subscriptionStatusCounts,
      };
      if (tenantsWithoutSubscription > 0) {
        statusCounts.NONE = tenantsWithoutSubscription;
      }

      return {
        metrics: {
          tenantsTotal,
          tenantsActive,
          tenantsWithoutSubscription,
          tenantsWithSubscription: Math.max(0, tenantsTotal - tenantsWithoutSubscription),
          facilitiesTotal,
          facilitiesActive,
          subscriptionsTotal,
          subscriptionsActive,
          subscriptionsExpiring,
          moduleEntitlementIssues,
        },
        trendDates,
        statusCounts,
        activity: {
          tenants: await prisma.tenant.count({
            where: { deleted_at: null, updated_at: { gte: window24h } },
          }),
          subscriptions: await prisma.subscription.count({
            where: { deleted_at: null, updated_at: { gte: window24h } },
          }),
        },
      };
    }

    if (packId === ROLE_PACKS.TENANT_ADMIN) {
      const tenantId = scope.tenant_id;
      if (!tenantId) {
        return {
          metrics: {
            facilitiesTotal: 0,
            facilitiesActive: 0,
            activeUsers: 0,
            usersTotal: 0,
            moduleAdoption: 0,
            subscriptionHealth: 0,
          },
          trendDates: [],
          statusCounts: { ACTIVE: 0, INACTIVE: 0, DENIED: 0 },
          activity: { facilities: 0 },
        };
      }

      const facilityWhere = { deleted_at: null, tenant_id: tenantId };
      const userWhere = { deleted_at: null, tenant_id: tenantId };

      const [
        facilitiesTotal,
        facilitiesActive,
        activeUsers,
        subscription,
        trendDates,
        facilitiesUpdated24h,
      ] = await Promise.all([
        prisma.facility.count({ where: facilityWhere }),
        prisma.facility.count({ where: { ...facilityWhere, is_active: true } }),
        prisma.user.count({ where: userWhere }),
        prisma.subscription.findFirst({
          where: {
            tenant_id: tenantId,
            deleted_at: null,
            status: { in: ['ACTIVE', 'TRIAL', 'PAST_DUE'] },
          },
          include: {
            plan: {
              select: {
                max_modules: true,
              },
            },
            module_subscriptions: {
              where: { deleted_at: null },
              select: {
                is_active: true,
                entitlement_denied: true,
              },
            },
          },
          orderBy: { updated_at: 'desc' },
        }),
        selectDateSeries(
          prisma.facility,
          { ...facilityWhere, created_at: { gte: trendStart } },
          'created_at'
        ),
        prisma.facility.count({
          where: { ...facilityWhere, updated_at: { gte: window24h } },
        }),
      ]);

      const moduleSubscriptions = subscription?.module_subscriptions || [];
      const activeModules = moduleSubscriptions.filter(
        (entry) => entry.is_active && !entry.entitlement_denied
      ).length;
      const inactiveModules = moduleSubscriptions.filter((entry) => !entry.is_active).length;
      const deniedModules = moduleSubscriptions.filter((entry) => entry.entitlement_denied).length;
      const entitledModules = toNumber(subscription?.plan?.max_modules);
      const moduleDenominator =
        entitledModules > 0 ? entitledModules : Math.max(moduleSubscriptions.length, 1);
      const moduleAdoption = percentOf(activeModules, moduleDenominator);

      const subscriptionStatus = String(subscription?.status || '').toUpperCase();
      const planFitStatus = String(subscription?.plan_fit_status || '').toUpperCase();
      let subscriptionHealth = 0;
      if (subscription) {
        if (planFitStatus === 'EXCEEDED') subscriptionHealth = 20;
        else if (planFitStatus === 'APPROACHING_LIMIT') subscriptionHealth = 55;
        else if (subscriptionStatus === 'ACTIVE') subscriptionHealth = 100;
        else if (subscriptionStatus === 'TRIAL') subscriptionHealth = 85;
        else if (subscriptionStatus === 'PAST_DUE') subscriptionHealth = 35;
        else subscriptionHealth = 50;
      }

      return {
        metrics: {
          facilitiesTotal,
          facilitiesActive,
          activeUsers,
          usersTotal: activeUsers,
          moduleAdoption,
          subscriptionHealth,
        },
        trendDates,
        statusCounts: {
          ACTIVE: activeModules,
          INACTIVE: inactiveModules,
          DENIED: deniedModules,
        },
        activity: {
          facilities: facilitiesUpdated24h,
        },
      };
    }

    if (packId === ROLE_PACKS.PATIENT_SAFE) {
      const portalPatient = await resolvePatientPortalPatient({ scope, userId, user });
      if (!portalPatient) return patientPortalZeroSummary();

      const patientId = portalPatient.id;
      const patientAppointmentWhere = {
        deleted_at: null,
        patient_id: patientId,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {})
      };
      const patientInvoiceWhere = {
        deleted_at: null,
        patient_id: patientId,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {})
      };
      const patientLabResultWhere = {
        deleted_at: null,
        lab_order_item: {
          deleted_at: null,
          lab_order: {
            deleted_at: null,
            patient_id: patientId
          }
        }
      };
      const patientPharmacyOrderWhere = {
        deleted_at: null,
        patient_id: patientId
      };
      const patientMessageWhere = userId
        ? { deleted_at: null, user_id: userId }
        : { deleted_at: null, user_id: '__no_user__' };

      const [
        myUpcomingAppointments,
        myOpenBills,
        myPrescriptions,
        myReleasedResults,
        myMessages
      ] = await Promise.all([
        prisma.appointment.count({
          where: {
            ...patientAppointmentWhere,
            scheduled_start: { gte: now },
            status: { in: ['SCHEDULED', 'CONFIRMED'] }
          }
        }),
        prisma.invoice.count({
          where: {
            ...patientInvoiceWhere,
            OR: [
              { status: { in: ['SENT', 'OVERDUE'] } },
              { billing_status: { in: ['DRAFT', 'ISSUED', 'PARTIAL'] } }
            ]
          }
        }),
        prisma.pharmacy_order.count({
          where: {
            ...patientPharmacyOrderWhere,
            status: { in: ['ORDERED', 'PARTIALLY_DISPENSED'] }
          }
        }),
        prisma.lab_result.count({
          where: {
            ...patientLabResultWhere,
            reported_at: { not: null },
            status: { in: ['NORMAL', 'ABNORMAL', 'CRITICAL'] }
          }
        }),
        prisma.conversation_participant.count({ where: patientMessageWhere })
      ]);

      return {
        metrics: {
          myUpcomingAppointments,
          myOpenBills,
          myPrescriptions,
          myReleasedResults,
          myMessages,
          myProfileStatus: 100
        },
        trendDates: await selectDateSeries(
          prisma.appointment,
          { ...patientAppointmentWhere, scheduled_start: { gte: trendStart } },
          'scheduled_start'
        ),
        statusCounts: await countByStatuses(
          prisma.appointment,
          patientAppointmentWhere,
          ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'NO_SHOW', 'CANCELLED']
        ),
        activity: {
          appointments: await prisma.appointment.count({ where: { ...patientAppointmentWhere, updated_at: { gte: window24h } } }),
          results: await prisma.lab_result.count({ where: { ...patientLabResultWhere, updated_at: { gte: window24h } } }),
          prescriptions: await prisma.pharmacy_order.count({ where: { ...patientPharmacyOrderWhere, updated_at: { gte: window24h } } }),
          bills: await prisma.invoice.count({ where: { ...patientInvoiceWhere, updated_at: { gte: window24h } } }),
          messages: await prisma.conversation_participant.count({ where: { ...patientMessageWhere, last_read_at: { gte: window24h } } })
        }
      };
    }

  if (packId === ROLE_PACKS.DOCTOR) {
    const providerUserId = userId || '';
    const endOfToday = shiftDays(todayStart, 1);
    const providerWhere = { ...appointmentWhere, provider_user_id: providerUserId };
    const providerTodayWhere = {
      ...providerWhere,
      scheduled_start: { gte: todayStart, lt: endOfToday },
      status: { in: ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS'] },
    };
    const providerLabAuthorship = providerUserId
      ? {
          OR: [
            {
              lab_order_item: {
                is: {
                  lab_order: {
                    is: { ordered_by_user_id: providerUserId, deleted_at: null },
                  },
                },
              },
            },
            {
              lab_order_item: {
                is: {
                  lab_order: {
                    is: {
                      encounter: {
                        is: { provider_user_id: providerUserId, deleted_at: null },
                      },
                    },
                  },
                },
              },
            },
          ],
        }
      : {};
    const providerRadiologyAuthorship = providerUserId
      ? {
          radiology_order: {
            is: {
              deleted_at: null,
              encounter: {
                is: { provider_user_id: providerUserId, deleted_at: null },
              },
            },
          },
        }
      : {};
    const providerReleasedLabWhere = {
      ...labResultWhere,
      status: { in: ['NORMAL', 'ABNORMAL', 'CRITICAL'] },
      ...providerLabAuthorship,
    };
    const providerRadiologyReadyWhere = {
      ...radiologyResultWhere,
      status: { in: ['FINAL', 'AMENDED'] },
      ...providerRadiologyAuthorship,
    };
    const followUpWhere = {
      deleted_at: null,
      status: 'SCHEDULED',
      scheduled_at: { lte: endOfToday },
      encounter: {
        deleted_at: null,
        provider_user_id: providerUserId,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
    };

    const [
      assigned,
      inProgress,
      completed,
      resultsPendingReview,
      followUpsDue,
    ] = await Promise.all([
      prisma.appointment.count({ where: providerTodayWhere }),
      prisma.appointment.count({ where: { ...providerWhere, status: 'IN_PROGRESS' } }),
      prisma.appointment.count({
        where: {
          ...providerWhere,
          status: 'COMPLETED',
          scheduled_start: { gte: todayStart, lt: endOfToday },
        },
      }),
      Promise.all([
        prisma.lab_result.count({ where: providerReleasedLabWhere }),
        prisma.radiology_result.count({ where: providerRadiologyReadyWhere }),
      ]).then(([labCount, radiologyCount]) => labCount + radiologyCount),
      prisma.follow_up.count({ where: followUpWhere }),
    ]);

    return {
      metrics: {
        assigned,
        inProgress,
        completed,
        resultsPendingReview,
        followUpsDue,
      },
      trendDates: await selectDateSeries(
        prisma.appointment,
        { ...providerWhere, scheduled_start: { gte: trendStart } },
        'scheduled_start'
      ),
      statusCounts: await countByStatuses(
        prisma.appointment,
        providerWhere,
        ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'NO_SHOW', 'CANCELLED']
      ),
      activity: {
        consultations: await prisma.appointment.count({
          where: { ...providerWhere, updated_at: { gte: window24h } },
        }),
        labs: await prisma.lab_result.count({
          where: { ...providerReleasedLabWhere, updated_at: { gte: window24h } },
        }),
        followUps: await prisma.follow_up.count({
          where: { ...followUpWhere, updated_at: { gte: window24h } },
        }),
      },
    };
  }

    if (packId === ROLE_PACKS.NURSE) {
      const [
        activeAdmissions,
        medAdminToday,
        transferQueue,
        criticalLabs,
        appointmentsToday,
        emergencyCasesToday,
        theatreCasesToday,
        radiologyPending,
      ] = await Promise.all([
        prisma.admission.count({ where: { ...admissionWhere, status: 'ADMITTED' } }),
        prisma.medication_administration.count({
          where: {
            deleted_at: null,
            admission: admissionWhere,
            administered_at: { gte: todayStart },
          },
        }),
        prisma.transfer_request.count({
          where: {
            deleted_at: null,
            admission: admissionWhere,
            status: { in: ['REQUESTED', 'IN_PROGRESS'] },
          },
        }),
        prisma.lab_result.count({ where: { ...labResultWhere, status: 'CRITICAL' } }),
        prisma.appointment.count({
          where: {
            ...appointmentWhere,
            status: { in: ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS'] },
          },
        }),
        prisma.emergency_case.count({
          where: { ...emergencyCaseWhere, created_at: { gte: todayStart } },
        }),
        prisma.theatre_case.count({
          where: {
            ...theatreCaseWhere,
            status: { in: ['SCHEDULED', 'IN_PROGRESS'] },
          },
        }),
        prisma.radiology_result.count({
          where: { ...radiologyResultWhere, status: 'DRAFT' },
        }),
      ]);
      return {
        metrics: {
          activeAdmissions,
          medAdminToday,
          transferQueue,
          criticalLabs,
          appointmentsToday,
          emergencyCasesToday,
          theatreCasesToday,
          radiologyPending,
        },
        trendDates: await selectDateSeries(
          prisma.medication_administration,
          { deleted_at: null, admission: admissionWhere, administered_at: { gte: trendStart } },
          'administered_at'
        ),
        statusCounts: await countByStatuses(
          prisma.transfer_request,
          { deleted_at: null, admission: admissionWhere },
          ['REQUESTED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']
        ),
        activity: {
          meds: await prisma.medication_administration.count({
            where: { deleted_at: null, admission: admissionWhere, updated_at: { gte: window24h } },
          }),
          transfers: await prisma.transfer_request.count({
            where: { deleted_at: null, admission: admissionWhere, updated_at: { gte: window24h } },
          }),
          admissions: await prisma.admission.count({
            where: { ...admissionWhere, updated_at: { gte: window24h } },
          }),
        },
      };
    }

    if (packId === ROLE_PACKS.LAB_TECH) {
      const [ordersToday, inProcess, pending, critical, completed] = await Promise.all([
        prisma.lab_order.count({ where: { ...labOrderWhere, ordered_at: { gte: todayStart } } }),
        prisma.lab_order.count({ where: { ...labOrderWhere, status: 'IN_PROCESS' } }),
        prisma.lab_result.count({
          where: {
            ...labResultWhere,
            status: { in: ['PENDING', 'ABNORMAL', 'CRITICAL'] }
          }
        }),
        prisma.lab_result.count({ where: { ...labResultWhere, status: 'CRITICAL' } }),
        prisma.lab_order.count({ where: { ...labOrderWhere, status: 'COMPLETED' } })
      ]);
      return {
        metrics: { ordersToday, inProcess, pending, critical, completed },
        trendDates: await selectDateSeries(prisma.lab_order, { ...labOrderWhere, ordered_at: { gte: trendStart } }, 'ordered_at'),
        statusCounts: await countByStatuses(prisma.lab_result, labResultWhere, ['PENDING', 'NORMAL', 'ABNORMAL', 'CRITICAL']),
        activity: {
          orders: await prisma.lab_order.count({ where: { ...labOrderWhere, updated_at: { gte: window24h } } }),
          results: await prisma.lab_result.count({ where: { ...labResultWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.RADIOLOGY_TECH) {
      const [ordersToday, inProcess, pending, final, completed] = await Promise.all([
        prisma.radiology_order.count({ where: { ...radiologyOrderWhere, ordered_at: { gte: todayStart } } }),
        prisma.radiology_order.count({ where: { ...radiologyOrderWhere, status: 'IN_PROCESS' } }),
        prisma.radiology_result.count({ where: { ...radiologyResultWhere, status: 'DRAFT' } }),
        prisma.radiology_result.count({ where: { ...radiologyResultWhere, status: 'FINAL' } }),
        prisma.radiology_order.count({ where: { ...radiologyOrderWhere, status: 'COMPLETED' } })
      ]);
      return {
        metrics: { ordersToday, inProcess, pending, final, completed },
        trendDates: await selectDateSeries(prisma.radiology_order, { ...radiologyOrderWhere, ordered_at: { gte: trendStart } }, 'ordered_at'),
        statusCounts: await countByStatuses(prisma.radiology_result, radiologyResultWhere, ['DRAFT', 'FINAL', 'AMENDED']),
        activity: {
          orders: await prisma.radiology_order.count({ where: { ...radiologyOrderWhere, updated_at: { gte: window24h } } }),
          results: await prisma.radiology_result.count({ where: { ...radiologyResultWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.PHARMACIST) {
      const [ordersToday, pendingDispense, dispensedToday, lowStock, criticalStock] = await Promise.all([
        prisma.pharmacy_order.count({ where: { ...pharmacyOrderWhere, ordered_at: { gte: todayStart } } }),
        prisma.pharmacy_order.count({ where: { ...pharmacyOrderWhere, status: { in: ['ORDERED', 'PARTIALLY_DISPENSED'] } } }),
        prisma.dispense_log.count({ where: { ...dispenseLogWhere, status: 'DISPENSED', dispensed_at: { gte: todayStart } } }),
        countLowStock(inventoryStockWhere, 1),
        countLowStock(inventoryStockWhere, 0.5)
      ]);
      return {
        metrics: { ordersToday, pendingDispense, dispensedToday, lowStock, criticalStock },
        trendDates: await selectDateSeries(prisma.dispense_log, { ...dispenseLogWhere, dispensed_at: { gte: trendStart } }, 'dispensed_at'),
        statusCounts: await countByStatuses(prisma.pharmacy_order, pharmacyOrderWhere, ['ORDERED', 'PARTIALLY_DISPENSED', 'DISPENSED', 'CANCELLED']),
        activity: {
          orders: await prisma.pharmacy_order.count({ where: { ...pharmacyOrderWhere, updated_at: { gte: window24h } } }),
          dispense: await prisma.dispense_log.count({ where: { ...dispenseLogWhere, updated_at: { gte: window24h } } }),
          stock: await prisma.inventory_stock.count({ where: { ...inventoryStockWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.RECEPTIONIST) {
      const [
        registrationsToday,
        appointmentDeskQueue,
        turnaroundPressure,
        noShowPressure,
        appointmentsToday,
        emergencyCasesToday
      ] = await Promise.all([
        prisma.patient.count({ where: { ...patientWhere, created_at: { gte: todayStart } } }),
        prisma.appointment.count({ where: { ...appointmentWhere, status: { in: ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS'] } } }),
        prisma.appointment.count({ where: { ...appointmentWhere, status: 'IN_PROGRESS' } }),
        prisma.appointment.count({ where: { ...appointmentWhere, status: 'NO_SHOW' } }),
        prisma.appointment.count({ where: { ...appointmentWhere, scheduled_start: { gte: todayStart } } }),
        prisma.emergency_case.count({ where: { ...emergencyCaseWhere, created_at: { gte: todayStart } } })
      ]);
      return {
        metrics: {
          registrationsToday,
          appointmentDeskQueue,
          turnaroundPressure,
          noShowPressure,
          appointmentsToday,
          emergencyCasesToday
        },
        trendDates: await selectDateSeries(prisma.patient, { ...patientWhere, created_at: { gte: trendStart } }, 'created_at'),
        statusCounts: await countByStatuses(prisma.appointment, appointmentWhere, ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'NO_SHOW', 'CANCELLED']),
        activity: {
          registrations: await prisma.patient.count({ where: { ...patientWhere, updated_at: { gte: window24h } } }),
          appointments: await prisma.appointment.count({ where: { ...appointmentWhere, updated_at: { gte: window24h } } }),
          emergencies: await prisma.emergency_case.count({ where: { ...emergencyCaseWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.BILLING) {
      const openBalanceWhere = {
        ...invoiceWhere,
        OR: [
          { status: { in: ['SENT', 'OVERDUE'] } },
          { billing_status: { in: ['DRAFT', 'ISSUED', 'PARTIAL'] } }
        ]
      };
      const [
        invoicesToday,
        overdueInvoices,
        openBalances,
        collectionsToday,
        refundsToday,
        overdueBalanceAmount,
        pendingBalanceAmount
      ] = await Promise.all([
        prisma.invoice.count({ where: { ...invoiceWhere, issued_at: { gte: todayStart } } }),
        prisma.invoice.count({ where: { ...invoiceWhere, status: 'OVERDUE' } }),
        prisma.invoice.count({ where: openBalanceWhere }),
        sumField(prisma.payment, { ...paymentWhere, status: 'COMPLETED', paid_at: { gte: todayStart } }, 'amount'),
        sumField(prisma.refund, { deleted_at: null, refunded_at: { gte: todayStart }, payment: paymentWhere }, 'amount'),
        sumField(prisma.invoice, { ...invoiceWhere, status: 'OVERDUE' }, 'total_amount'),
        sumField(prisma.invoice, openBalanceWhere, 'total_amount')
      ]);
      return {
        metrics: {
          invoicesToday,
          overdueInvoices,
          openBalances,
          collectionsToday,
          refundsToday,
          overdueBalanceAmount,
          pendingBalanceAmount
        },
        trendDates: await selectDateSeries(prisma.payment, { ...paymentWhere, status: 'COMPLETED', paid_at: { gte: trendStart } }, 'paid_at'),
        statusCounts: await countByStatuses(prisma.invoice, invoiceWhere, ['DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED']),
        activity: {
          invoices: await prisma.invoice.count({ where: { ...invoiceWhere, updated_at: { gte: window24h } } }),
          payments: await prisma.payment.count({ where: { ...paymentWhere, updated_at: { gte: window24h } } }),
          refunds: await prisma.refund.count({ where: { deleted_at: null, payment: paymentWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.OPERATIONS) {
      const [occupiedBeds, totalBeds, openMaintenance, lowStockPressure, housekeepingBacklog] = await Promise.all([
        prisma.bed.count({ where: { ...directScope(scope, { includeTenant: true, includeFacility: true }), status: 'OCCUPIED' } }),
        prisma.bed.count({ where: directScope(scope, { includeTenant: true, includeFacility: true }) }),
        prisma.maintenance_request.count({ where: { ...maintenanceWhere, status: { in: ['OPEN', 'IN_PROGRESS'] } } }),
        countLowStock(inventoryStockWhere, 1),
        prisma.housekeeping_task.count({ where: { ...housekeepingWhere, status: { in: ['PENDING', 'IN_PROGRESS'] } } })
      ]);
      const operationalPressure = openMaintenance + lowStockPressure + housekeepingBacklog;
      const facilityReadiness = totalBeds + operationalPressure > 0
        ? Math.max(0, 100 - percentOf(operationalPressure, totalBeds + operationalPressure))
        : 0;
      return {
        metrics: { occupiedBeds, totalBeds, openMaintenance, lowStockPressure, housekeepingBacklog, facilityReadiness },
        trendDates: await selectDateSeries(prisma.maintenance_request, { ...maintenanceWhere, reported_at: { gte: trendStart } }, 'reported_at'),
        statusCounts: await countByStatuses(prisma.bed, directScope(scope, { includeTenant: true, includeFacility: true }), ['AVAILABLE', 'OCCUPIED', 'RESERVED', 'OUT_OF_SERVICE']),
        activity: {
          maintenance: await prisma.maintenance_request.count({ where: { ...maintenanceWhere, updated_at: { gte: window24h } } }),
          stock: await prisma.inventory_stock.count({ where: { ...inventoryStockWhere, updated_at: { gte: window24h } } }),
          housekeeping: await prisma.housekeeping_task.count({ where: { ...housekeepingWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.HR) {
      const staffProfileWhere = {
        deleted_at: null,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {})
      };
      const leaveWhere = {
        deleted_at: null,
        staff_profile: staffProfileWhere
      };
      const shiftScope = directScope(scope, { includeTenant: true, includeFacility: true });
      const todayEnd = shiftDays(todayStart, 1);
      const shiftWhereToday = {
        ...shiftScope,
        start_time: { gte: todayStart, lt: todayEnd }
      };
      const payrollWhere = {
        deleted_at: null,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {})
      };
      const [
        activeStaff,
        shiftsToday,
        pendingLeaves,
        staffingBacklog,
        unassignedShifts,
        onLeaveToday,
        attendedToday,
        missedShiftsToday,
        payrollPending,
        payrollProcessed
      ] = await Promise.all([
        prisma.staff_profile.count({ where: staffProfileWhere }),
        prisma.shift.count({ where: shiftWhereToday }),
        prisma.staff_leave.count({ where: { ...leaveWhere, status: 'REQUESTED' } }),
        prisma.staff_position.count({ where: { ...staffPositionScope(scope), is_active: true } }),
        prisma.shift.count({
          where: {
            ...shiftScope,
            status: 'SCHEDULED',
            assignments: { none: { deleted_at: null } }
          }
        }),
        prisma.staff_leave.count({
          where: {
            ...leaveWhere,
            status: 'APPROVED',
            start_date: { lte: todayEnd },
            end_date: { gte: todayStart }
          }
        }),
        prisma.shift.count({
          where: {
            ...shiftWhereToday,
            assignments: { some: { deleted_at: null } }
          }
        }),
        prisma.shift.count({
          where: {
            ...shiftWhereToday,
            start_time: { lt: now },
            status: 'SCHEDULED',
            assignments: { some: { deleted_at: null } }
          }
        }),
        prisma.payroll_run.count({ where: { ...payrollWhere, status: 'DRAFT' } }),
        prisma.payroll_run.count({
          where: {
            ...payrollWhere,
            status: { in: ['PROCESSED', 'PAID'] },
            period_start: { lte: todayEnd },
            period_end: { gte: todayStart }
          }
        })
      ]);
      const availableStaff = Math.max(0, activeStaff - onLeaveToday);
      const filledShiftsToday = attendedToday;
      const attendanceRate = shiftsToday > 0
        ? percentOf(filledShiftsToday, shiftsToday)
        : 0;
      return {
        metrics: {
          activeStaff,
          shiftsToday,
          pendingLeaves,
          staffingBacklog,
          unassignedShifts,
          attendanceRate,
          onLeaveToday,
          attendedToday,
          missedShiftsToday,
          payrollPending,
          payrollProcessed
        },
        trendDates: await selectDateSeries(
          prisma.shift,
          { ...shiftScope, start_time: { gte: trendStart } },
          'start_time'
        ),
        statusCounts: {
          ACTIVE: availableStaff,
          ON_LEAVE: onLeaveToday
        },
        activity: {
          staff: await prisma.staff_profile.count({ where: { ...staffProfileWhere, updated_at: { gte: window24h } } }),
          shifts: await prisma.shift.count({ where: { ...shiftScope, updated_at: { gte: window24h } } }),
          leaves: await prisma.staff_leave.count({ where: { ...leaveWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.BIOMED) {
      const equipmentRegistryWhere = {
        deleted_at: null,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {})
      };
      const equipmentRegistryScope = scope.facility_id
        ? { equipment_registry: { is: equipmentRegistryWhere } }
        : {};
      const workOrderWhere = { deleted_at: null, ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}), ...equipmentRegistryScope };
      const incidentWhere = { deleted_at: null, ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}), ...equipmentRegistryScope };
      const downtimeWhere = { deleted_at: null, ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}), ...equipmentRegistryScope };
      const [openWorkOrders, openIncidents, activeDowntime, criticalServiceRisk, highPriority, totalAssets, operationalAssets] = await Promise.all([
        prisma.equipment_work_order.count({ where: { ...workOrderWhere, status: { in: ['OPEN', 'IN_PROGRESS', 'ACKNOWLEDGED'] } } }),
        prisma.equipment_incident_report.count({ where: { ...incidentWhere, status: { in: ['OPEN', 'IN_PROGRESS', 'REPORTED'] } } }),
        prisma.equipment_downtime_log.count({ where: { ...downtimeWhere, ended_at: null } }),
        prisma.equipment_downtime_log.count({ where: { ...downtimeWhere, ended_at: null, is_clinically_critical: true } }),
        prisma.equipment_work_order.count({ where: { ...workOrderWhere, status: { in: ['OPEN', 'IN_PROGRESS', 'ACKNOWLEDGED'] }, priority: { in: ['HIGH', 'CRITICAL', 'URGENT'] } } }),
        prisma.equipment_registry.count({ where: equipmentRegistryWhere }),
        prisma.equipment_registry.count({ where: { ...equipmentRegistryWhere, status: { in: ['OPERATIONAL', 'IN_SERVICE', 'AVAILABLE', 'ACTIVE'] } } })
      ]);
      const assetsOperational = percentOf(operationalAssets, totalAssets);
      return {
        metrics: { openWorkOrders, openIncidents, activeDowntime, criticalServiceRisk, highPriority, assetsOperational },
        trendDates: await selectDateSeries(prisma.equipment_work_order, { ...workOrderWhere, opened_at: { gte: trendStart } }, 'opened_at'),
        statusCounts: await countByStatuses(prisma.equipment_work_order, workOrderWhere, ['OPEN', 'IN_PROGRESS', 'ACKNOWLEDGED', 'COMPLETED', 'CLOSED']),
        activity: {
          workOrders: await prisma.equipment_work_order.count({ where: { ...workOrderWhere, updated_at: { gte: window24h } } }),
          incidents: await prisma.equipment_incident_report.count({ where: { ...incidentWhere, updated_at: { gte: window24h } } }),
          downtime: await prisma.equipment_downtime_log.count({ where: { ...downtimeWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.HOUSE_KEEPER) {
      const [pendingTasks, inProgressTasks, overdueTasks, completedToday, throughput] = await Promise.all([
        prisma.housekeeping_task.count({ where: { ...housekeepingWhere, status: 'PENDING' } }),
        prisma.housekeeping_task.count({ where: { ...housekeepingWhere, status: 'IN_PROGRESS' } }),
        prisma.housekeeping_task.count({ where: { ...housekeepingWhere, status: { in: ['PENDING', 'IN_PROGRESS'] }, scheduled_at: { lt: now } } }),
        prisma.housekeeping_task.count({ where: { ...housekeepingWhere, status: 'COMPLETED', completed_at: { gte: todayStart } } }),
        prisma.housekeeping_task.count({ where: { ...housekeepingWhere, status: 'COMPLETED', completed_at: { gte: trendStart } } })
      ]);
      return {
        metrics: { pendingTasks, inProgressTasks, overdueTasks, completedToday, throughput },
        trendDates: await selectDateSeries(prisma.housekeeping_task, { ...housekeepingWhere, completed_at: { gte: trendStart } }, 'completed_at'),
        statusCounts: await countByStatuses(prisma.housekeeping_task, housekeepingWhere, ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']),
        activity: {
          tasks: await prisma.housekeeping_task.count({ where: { ...housekeepingWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.AMBULANCE_OPERATOR) {
      const [dispatchesToday, activeTrips, criticalCases, fleetAvailable, fleetOut] = await Promise.all([
        prisma.ambulance_dispatch.count({ where: { ...ambulanceDispatchWhere, dispatched_at: { gte: todayStart } } }),
        prisma.ambulance_trip.count({ where: { ...ambulanceTripWhere, started_at: { not: null }, ended_at: null } }),
        prisma.emergency_case.count({ where: { ...emergencyCaseWhere, severity: { in: ['HIGH', 'CRITICAL'] }, status: 'OPEN' } }),
        prisma.ambulance.count({ where: { ...directScope(scope, { includeTenant: true, includeFacility: true }), status: 'AVAILABLE' } }),
        prisma.ambulance.count({ where: { ...directScope(scope, { includeTenant: true, includeFacility: true }), status: 'OUT_OF_SERVICE' } })
      ]);
      return {
        metrics: { dispatchesToday, activeTrips, criticalCases, fleetAvailable, fleetOut },
        trendDates: await selectDateSeries(prisma.ambulance_dispatch, { ...ambulanceDispatchWhere, dispatched_at: { gte: trendStart } }, 'dispatched_at'),
        statusCounts: await countByStatuses(prisma.ambulance_dispatch, ambulanceDispatchWhere, ['AVAILABLE', 'DISPATCHED', 'EN_ROUTE', 'ON_SCENE', 'TRANSPORTING', 'OUT_OF_SERVICE']),
        activity: {
          dispatches: await prisma.ambulance_dispatch.count({ where: { ...ambulanceDispatchWhere, updated_at: { gte: window24h } } }),
          trips: await prisma.ambulance_trip.count({ where: { ...ambulanceTripWhere, updated_at: { gte: window24h } } }),
          emergencies: await prisma.emergency_case.count({ where: { ...emergencyCaseWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.UNIT_MANAGER) {
      const [unitCensus, staffOnShift, openRosterGaps, pendingLeaves] = await Promise.all([
        prisma.admission.count({ where: { ...admissionWhere, status: 'ADMITTED' } }),
        prisma.shift.count({ where: { ...shiftWhere, status: 'SCHEDULED', start_time: { gte: todayStart } } }),
        prisma.shift.count({ where: { ...shiftWhere, status: 'SCHEDULED', start_time: { gte: todayStart }, assignments: { none: { deleted_at: null } } } }),
        prisma.staff_leave.count({
          where: {
            deleted_at: null,
            staff_profile: {
              deleted_at: null,
              ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {})
            },
            status: 'REQUESTED'
          }
        })
      ]);
      return {
        metrics: { unitCensus, staffOnShift, openRosterGaps, pendingLeaves },
        trendDates: await selectDateSeries(prisma.shift, { ...shiftWhere, start_time: { gte: trendStart } }, 'start_time'),
        statusCounts: await countByStatuses(prisma.shift, shiftWhere, ['SCHEDULED', 'COMPLETED', 'CANCELLED']),
        activity: {
          shifts: await prisma.shift.count({ where: { ...shiftWhere, updated_at: { gte: window24h } } }),
          leaves: await prisma.staff_leave.count({
            where: {
              deleted_at: null,
              staff_profile: {
                deleted_at: null,
                ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {})
              },
              updated_at: { gte: window24h }
            }
          }),
          admissions: await prisma.admission.count({ where: { ...admissionWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.WARD_MANAGER || packId === ROLE_PACKS.ICU_MANAGER) {
      const [activeAdmissions, occupiedBeds, transferQueue, criticalLabs, staffOnShift] = await Promise.all([
        prisma.admission.count({ where: { ...admissionWhere, status: 'ADMITTED' } }),
        prisma.bed.count({ where: { ...directScope(scope, { includeTenant: true, includeFacility: true }), status: 'OCCUPIED' } }),
        prisma.transfer_request.count({ where: { deleted_at: null, admission: admissionWhere, status: { in: ['REQUESTED', 'IN_PROGRESS'] } } }),
        prisma.lab_result.count({ where: { ...labResultWhere, status: 'CRITICAL' } }),
        prisma.shift.count({ where: { ...shiftWhere, status: 'SCHEDULED', start_time: { gte: todayStart } } })
      ]);
      return {
        metrics: {
          wardCensus: activeAdmissions,
          icuCensus: activeAdmissions,
          activeAdmissions,
          occupiedBeds,
          icuBedsOccupied: occupiedBeds,
          pendingNursingTasks: transferQueue,
          transferQueue,
          criticalLabs,
          criticalPatientAlerts: criticalLabs,
          staffOnShift,
          staffCoverage: staffOnShift
        },
        trendDates: await selectDateSeries(prisma.admission, { ...admissionWhere, updated_at: { gte: trendStart } }, 'updated_at'),
        statusCounts: await countByStatuses(prisma.admission, admissionWhere, ['ADMITTED', 'DISCHARGED', 'TRANSFERRED', 'CANCELLED']),
        activity: {
          admissions: await prisma.admission.count({ where: { ...admissionWhere, updated_at: { gte: window24h } } }),
          transfers: await prisma.transfer_request.count({ where: { deleted_at: null, admission: admissionWhere, updated_at: { gte: window24h } } }),
          labs: await prisma.lab_result.count({ where: { ...labResultWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.THEATRE_MANAGER) {
      const [proceduresToday, readyForTheatre, inTheatre, cancellationsOrDelays, theatreStaffCoverage] = await Promise.all([
        prisma.theatre_case.count({ where: { ...theatreCaseWhere, scheduled_at: { gte: todayStart } } }),
        prisma.theatre_case.count({ where: { ...theatreCaseWhere, status: 'SCHEDULED' } }),
        prisma.theatre_case.count({ where: { ...theatreCaseWhere, status: 'IN_PROGRESS' } }),
        prisma.theatre_case.count({ where: { ...theatreCaseWhere, status: 'CANCELLED' } }),
        prisma.shift.count({ where: { ...shiftWhere, status: 'SCHEDULED', start_time: { gte: todayStart } } })
      ]);
      return {
        metrics: { proceduresToday, readyForTheatre, inTheatre, cancellationsOrDelays, theatreStaffCoverage },
        trendDates: await selectDateSeries(prisma.theatre_case, { ...theatreCaseWhere, scheduled_at: { gte: trendStart } }, 'scheduled_at'),
        statusCounts: await countByStatuses(prisma.theatre_case, theatreCaseWhere, ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']),
        activity: {
          theatreCases: await prisma.theatre_case.count({ where: { ...theatreCaseWhere, updated_at: { gte: window24h } } }),
          shifts: await prisma.shift.count({ where: { ...shiftWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.HOUSEKEEPING_MANAGER) {
      const [pendingTasks, unassignedCleaningTasks, inProgressTasks, overdueTasks, roomsReady, housekeepingStaffOnShift] = await Promise.all([
        prisma.housekeeping_task.count({ where: { ...housekeepingWhere, status: 'PENDING' } }),
        prisma.housekeeping_task.count({ where: { ...housekeepingWhere, status: 'PENDING', assigned_to_staff_id: null } }),
        prisma.housekeeping_task.count({ where: { ...housekeepingWhere, status: 'IN_PROGRESS' } }),
        prisma.housekeeping_task.count({ where: { ...housekeepingWhere, status: { in: ['PENDING', 'IN_PROGRESS'] }, scheduled_at: { lt: now } } }),
        prisma.bed.count({ where: { ...directScope(scope, { includeTenant: true, includeFacility: true }), status: 'AVAILABLE' } }),
        prisma.shift.count({ where: { ...shiftWhere, status: 'SCHEDULED', start_time: { gte: todayStart } } })
      ]);
      return {
        metrics: {
          pendingCleaningTasks: pendingTasks,
          pendingTasks,
          unassignedCleaningTasks,
          inProgressCleaningTasks: inProgressTasks,
          inProgressTasks,
          overdueCleaningTasks: overdueTasks,
          overdueTasks,
          roomsReady,
          housekeepingStaffOnShift
        },
        trendDates: await selectDateSeries(prisma.housekeeping_task, { ...housekeepingWhere, scheduled_at: { gte: trendStart } }, 'scheduled_at'),
        statusCounts: await countByStatuses(prisma.housekeeping_task, housekeepingWhere, ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']),
        activity: {
          tasks: await prisma.housekeeping_task.count({ where: { ...housekeepingWhere, updated_at: { gte: window24h } } }),
          rooms: await prisma.bed.count({ where: { ...directScope(scope, { includeTenant: true, includeFacility: true }), updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.BIOMED_MANAGER) {
      const workOrderWhere = { deleted_at: null, ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}) };
      const incidentWhere = { deleted_at: null, ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}) };
      const downtimeWhere = { deleted_at: null, ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}) };
      const maintenancePlanWhere = { deleted_at: null, ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}) };
      const [openWorkOrders, highPriorityWorkOrders, activeDowntime, openIncidents, overdueMaintenance, technicianLoad] = await Promise.all([
        prisma.equipment_work_order.count({ where: { ...workOrderWhere, status: { in: ['OPEN', 'IN_PROGRESS', 'ACKNOWLEDGED'] } } }),
        prisma.equipment_work_order.count({ where: { ...workOrderWhere, status: { in: ['OPEN', 'IN_PROGRESS', 'ACKNOWLEDGED'] }, priority: { in: ['HIGH', 'CRITICAL', 'URGENT'] } } }),
        prisma.equipment_downtime_log.count({ where: { ...downtimeWhere, ended_at: null } }),
        prisma.equipment_incident_report.count({ where: { ...incidentWhere, status: { in: ['OPEN', 'IN_PROGRESS', 'REPORTED'] } } }),
        prisma.equipment_maintenance_plan.count({ where: { ...maintenancePlanWhere, next_due_at: { lt: now }, is_active: true } }),
        prisma.equipment_work_order.count({ where: { ...workOrderWhere, assigned_engineer_user_id: { not: null }, status: { in: ['OPEN', 'IN_PROGRESS', 'ACKNOWLEDGED'] } } })
      ]);
      return {
        metrics: { openWorkOrders, highPriorityWorkOrders, activeDowntime, openIncidents, overdueMaintenance, technicianLoad },
        trendDates: await selectDateSeries(prisma.equipment_work_order, { ...workOrderWhere, opened_at: { gte: trendStart } }, 'opened_at'),
        statusCounts: await countByStatuses(prisma.equipment_work_order, workOrderWhere, ['OPEN', 'IN_PROGRESS', 'ACKNOWLEDGED', 'COMPLETED', 'CLOSED']),
        activity: {
          workOrders: await prisma.equipment_work_order.count({ where: { ...workOrderWhere, updated_at: { gte: window24h } } }),
          incidents: await prisma.equipment_incident_report.count({ where: { ...incidentWhere, updated_at: { gte: window24h } } }),
          downtime: await prisma.equipment_downtime_log.count({ where: { ...downtimeWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.MORTUARY_STAFF || packId === ROLE_PACKS.MORTUARY_MANAGER) {
      const activeMortuaryCaseWhere = {
        ...mortuaryWhere,
        status: { in: ['RECEIVED', 'IDENTIFICATION_PENDING', 'IN_STORAGE', 'POST_MORTEM_PENDING', 'READY_FOR_RELEASE'] }
      };
      const [activeMortuaryCases, storageAssignments, occupiedSlots, totalSlots, custodyEventsDue, viewingsToday, postMortemRequests, billableEventsToCapture, releasesAwaitingApproval, custodyExceptions] = await Promise.all([
        prisma.mortuary_case.count({ where: activeMortuaryCaseWhere }),
        prisma.mortuary_storage_assignment.count({ where: { ...mortuaryWhere, assignment_status: 'ACTIVE', ended_at: null } }),
        prisma.mortuary_storage_slot.count({ where: { ...mortuaryWhere, status: 'OCCUPIED' } }),
        prisma.mortuary_storage_slot.count({ where: mortuaryWhere }),
        prisma.mortuary_case.count({ where: { ...mortuaryWhere, status: 'RECEIVED', storage_assignments: { none: { deleted_at: null, assignment_status: 'ACTIVE' } } } }),
        prisma.mortuary_viewing.count({ where: { ...mortuaryWhere, scheduled_at: { gte: todayStart } } }),
        prisma.mortuary_post_mortem_request.count({ where: { ...mortuaryWhere, status: { in: ['REQUESTED', 'APPROVED', 'SCHEDULED', 'IN_PROGRESS'] } } }),
        prisma.mortuary_billable_event.count({ where: { ...mortuaryWhere, status: 'PENDING' } }),
        prisma.mortuary_release_authorisation.count({ where: { ...mortuaryWhere, status: 'DRAFT' } }),
        prisma.mortuary_case.count({ where: { ...mortuaryWhere, identification_status: { in: ['UNVERIFIED', 'PARTIAL'] } } })
      ]);
      const storageOccupancy = totalSlots > 0
        ? Math.round((Number(occupiedSlots || 0) / Number(totalSlots || 0)) * 100)
        : 0;
      return {
        metrics: {
          activeMortuaryCases,
          storageAssignments,
          custodyEventsDue,
          viewingsToday,
          postMortemRequests,
          billableEventsToCapture,
          storageOccupancy,
          releasesAwaitingApproval,
          custodyExceptions,
          pendingPostMortemRequests: postMortemRequests
        },
        trendDates: await selectDateSeries(prisma.mortuary_case, { ...mortuaryWhere, received_at: { gte: trendStart } }, 'received_at'),
        statusCounts: await countByStatuses(prisma.mortuary_case, mortuaryWhere, ['RECEIVED', 'IDENTIFICATION_PENDING', 'IN_STORAGE', 'POST_MORTEM_PENDING', 'READY_FOR_RELEASE', 'RELEASED', 'CLOSED']),
        activity: {
          cases: await prisma.mortuary_case.count({ where: { ...mortuaryWhere, updated_at: { gte: window24h } } }),
          custody: await prisma.mortuary_custody_event.count({ where: { ...mortuaryWhere, updated_at: { gte: window24h } } }),
          releases: await prisma.mortuary_release_authorisation.count({ where: { ...mortuaryWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    const [patientsToday, appointmentsToday, activeAdmissions, openInvoices, paymentsToday, activeUsers, openMaintenance, pendingLeaves, occupiedBeds] = await Promise.all([
      prisma.patient.count({ where: { ...patientWhere, created_at: { gte: todayStart } } }),
      prisma.appointment.count({ where: { ...appointmentWhere, scheduled_start: { gte: todayStart } } }),
      prisma.admission.count({ where: { ...admissionWhere, status: 'ADMITTED' } }),
      prisma.invoice.count({ where: { ...invoiceWhere, OR: [{ status: { in: ['SENT', 'OVERDUE'] } }, { billing_status: { in: ['DRAFT', 'ISSUED', 'PARTIAL'] } }] } }),
      sumField(prisma.payment, { ...paymentWhere, status: 'COMPLETED', paid_at: { gte: todayStart } }, 'amount'),
      prisma.user.count({ where: { deleted_at: null, ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}), ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) } }),
      prisma.maintenance_request.count({ where: { ...maintenanceWhere, status: { in: ['OPEN', 'IN_PROGRESS'] } } }),
      prisma.staff_leave.count({
        where: {
          deleted_at: null,
          staff_profile: {
            deleted_at: null,
            ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {})
          },
          status: 'REQUESTED'
        }
      }),
      prisma.bed.count({ where: { ...directScope(scope, { includeTenant: true, includeFacility: true }), status: 'OCCUPIED' } })
    ]);
    return {
      metrics: {
        patientsToday,
        appointmentsToday,
        activeAdmissions,
        openInvoices,
        paymentsToday,
        activeUsers,
        usersTotal: activeUsers,
        patientFlow: appointmentsToday,
        revenueSummary: paymentsToday,
        staffingExceptions: pendingLeaves,
        openMaintenance,
        occupiedBeds
      },
      trendDates: await selectDateSeries(prisma.appointment, { ...appointmentWhere, scheduled_start: { gte: trendStart } }, 'scheduled_start'),
      statusCounts: await countByStatuses(prisma.invoice, invoiceWhere, ['DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED']),
      activity: {
        appointments: await prisma.appointment.count({ where: { ...appointmentWhere, updated_at: { gte: window24h } } }),
        admissions: await prisma.admission.count({ where: { ...admissionWhere, updated_at: { gte: window24h } } }),
        invoices: await prisma.invoice.count({ where: { ...invoiceWhere, updated_at: { gte: window24h } } })
      }
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const inferNurseContext = (combined = '') => {
  const value = String(combined || '').toLowerCase();
  if (/theatre|theater|surg/.test(value)) return 'theatre';
  if (/radiology|imaging|x-ray|xray/.test(value)) return 'radiology';
  if (/opd|outpatient|clinic/.test(value)) return 'opd';
  if (/icu|intensive/.test(value)) return 'icu';
  if (/ward|inpatient|ipd/.test(value)) return 'ward';
  return 'general';
};

const findNurseStaffContext = async (userId, scope = {}) => {
  if (!userId) return null;

  try {
    const profile = await prisma.staff_profile.findFirst({
      where: {
        deleted_at: null,
        user_id: userId,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
      },
      select: {
        department_id: true,
        position: true,
        practitioner_type: true,
        department: {
          select: {
            name: true,
            short_name: true,
          },
        },
        assignments: {
          where: {
            deleted_at: null,
            OR: [{ end_date: null }, { end_date: { gte: new Date() } }],
          },
          orderBy: { start_date: 'desc' },
          take: 1,
          select: {
            department_id: true,
            unit_id: true,
            department: {
              select: {
                name: true,
                short_name: true,
              },
            },
            unit: {
              select: {
                name: true,
              },
            },
          },
        },
      },
    });

    if (!profile) return null;

    const assignment = profile.assignments?.[0] || null;
    const departmentName =
      assignment?.department?.name ||
      profile.department?.name ||
      null;
    const unitName = assignment?.unit?.name || '';
    const combined = [
      departmentName,
      assignment?.department?.short_name,
      profile.department?.short_name,
      unitName,
      profile.position,
      profile.practitioner_type,
    ]
      .filter(Boolean)
      .join(' ');

    return {
      nurse_context: inferNurseContext(combined),
      department_id: assignment?.department_id || profile.department_id || null,
      unit_id: assignment?.unit_id || null,
      department_name: departmentName,
    };
  } catch (error) {
    return null;
  }
};

module.exports = {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete,
  getDashboardSummaryByPack,
  countUnreadOpdNotifications,
  resolveBranchFacilityScope,
  findNurseStaffContext,
  __private__: {
    ROLE_PACKS,
    buildLabOrderScopeWhere,
    buildLabResultScopeWhere,
    buildRadiologyOrderScopeWhere,
    buildRadiologyResultScopeWhere,
    buildPharmacyOrderScopeWhere,
    buildDispenseLogScopeWhere,
    buildInventoryStockScopeWhere,
    buildAmbulanceDispatchScopeWhere,
    buildAmbulanceTripScopeWhere
  }
};
