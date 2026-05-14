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
  DOCTOR: 'doctor',
  NURSE: 'nurse',
  LAB_TECH: 'lab_tech',
  PHARMACIST: 'pharmacist',
  RECEPTIONIST: 'receptionist',
  BILLING: 'billing',
  OPERATIONS: 'operations',
  HR: 'hr',
  BIOMED: 'biomed',
  HOUSE_KEEPER: 'house_keeper',
  AMBULANCE_OPERATOR: 'ambulance_operator'
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

const resolveBranchFacilityScope = async (tenantId, branchId) => {
  try {
    if (!tenantId || !branchId) return null;
    const branch = await prisma.branch.findFirst({
      where: {
        id: branchId,
        tenant_id: tenantId,
        deleted_at: null
      },
      select: {
        facility_id: true
      }
    });
    if (!branch) {
      throw new HttpError('errors.validation.invalid', 422, [{ field: 'branch_id' }]);
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

const getDashboardSummaryByPack = async ({ packId, scope, days = 7, userId = null }) => {
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

    if (packId === ROLE_PACKS.DOCTOR) {
      const providerWhere = { ...appointmentWhere, provider_user_id: userId || '' };
      const [assigned, inProgress, completed, criticalLabs, activeAdmissions] = await Promise.all([
        prisma.appointment.count({ where: providerWhere }),
        prisma.appointment.count({ where: { ...providerWhere, status: 'IN_PROGRESS' } }),
        prisma.appointment.count({ where: { ...providerWhere, status: 'COMPLETED' } }),
        prisma.lab_result.count({ where: { ...labResultWhere, status: 'CRITICAL' } }),
        prisma.admission.count({ where: { ...admissionWhere, status: 'ADMITTED' } })
      ]);
      return {
        metrics: {
          assigned,
          inProgress,
          completed,
          criticalLabs,
          activeAdmissions
        },
        trendDates: await selectDateSeries(prisma.appointment, { ...providerWhere, scheduled_start: { gte: trendStart } }, 'scheduled_start'),
        statusCounts: await countByStatuses(prisma.appointment, providerWhere, ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'NO_SHOW', 'CANCELLED']),
        activity: {
          consultations: await prisma.appointment.count({ where: { ...providerWhere, updated_at: { gte: window24h } } }),
          labs: await prisma.lab_result.count({ where: { ...labResultWhere, updated_at: { gte: window24h } } }),
          admissions: await prisma.admission.count({ where: { ...admissionWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.NURSE) {
      const [activeAdmissions, medAdminToday, transferQueue, criticalLabs] = await Promise.all([
        prisma.admission.count({ where: { ...admissionWhere, status: 'ADMITTED' } }),
        prisma.medication_administration.count({ where: { deleted_at: null, admission: admissionWhere, administered_at: { gte: todayStart } } }),
        prisma.transfer_request.count({ where: { deleted_at: null, admission: admissionWhere, status: { in: ['REQUESTED', 'IN_PROGRESS'] } } }),
        prisma.lab_result.count({ where: { ...labResultWhere, status: 'CRITICAL' } })
      ]);
      return {
        metrics: { activeAdmissions, medAdminToday, transferQueue, criticalLabs },
        trendDates: await selectDateSeries(prisma.medication_administration, { deleted_at: null, admission: admissionWhere, administered_at: { gte: trendStart } }, 'administered_at'),
        statusCounts: await countByStatuses(prisma.transfer_request, { deleted_at: null, admission: admissionWhere }, ['REQUESTED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']),
        activity: {
          meds: await prisma.medication_administration.count({ where: { deleted_at: null, admission: admissionWhere, updated_at: { gte: window24h } } }),
          transfers: await prisma.transfer_request.count({ where: { deleted_at: null, admission: admissionWhere, updated_at: { gte: window24h } } }),
          admissions: await prisma.admission.count({ where: { ...admissionWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.LAB_TECH) {
      const [ordersToday, inProcess, pending, critical, completed] = await Promise.all([
        prisma.lab_order.count({ where: { ...labOrderWhere, ordered_at: { gte: todayStart } } }),
        prisma.lab_order.count({ where: { ...labOrderWhere, status: 'IN_PROCESS' } }),
        prisma.lab_result.count({ where: { ...labResultWhere, status: 'PENDING' } }),
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
      const [registrationsToday, appointmentDeskQueue, noShowPressure, frontBillingQueue, appointmentsToday] = await Promise.all([
        prisma.patient.count({ where: { ...patientWhere, created_at: { gte: todayStart } } }),
        prisma.appointment.count({ where: { ...appointmentWhere, status: { in: ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS'] } } }),
        prisma.appointment.count({ where: { ...appointmentWhere, status: 'NO_SHOW' } }),
        prisma.invoice.count({ where: { ...invoiceWhere, OR: [{ status: { in: ['SENT', 'OVERDUE'] } }, { billing_status: { in: ['DRAFT', 'ISSUED', 'PARTIAL'] } }] } }),
        prisma.appointment.count({ where: { ...appointmentWhere, scheduled_start: { gte: todayStart } } })
      ]);
      return {
        metrics: { registrationsToday, appointmentDeskQueue, noShowPressure, frontBillingQueue, appointmentsToday },
        trendDates: await selectDateSeries(prisma.patient, { ...patientWhere, created_at: { gte: trendStart } }, 'created_at'),
        statusCounts: await countByStatuses(prisma.appointment, appointmentWhere, ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'NO_SHOW', 'CANCELLED']),
        activity: {
          registrations: await prisma.patient.count({ where: { ...patientWhere, updated_at: { gte: window24h } } }),
          appointments: await prisma.appointment.count({ where: { ...appointmentWhere, updated_at: { gte: window24h } } }),
          invoices: await prisma.invoice.count({ where: { ...invoiceWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.BILLING) {
      const [invoicesToday, overdueInvoices, openBalances, collectionsToday, refundsToday] = await Promise.all([
        prisma.invoice.count({ where: { ...invoiceWhere, issued_at: { gte: todayStart } } }),
        prisma.invoice.count({ where: { ...invoiceWhere, status: 'OVERDUE' } }),
        prisma.invoice.count({ where: { ...invoiceWhere, OR: [{ status: { in: ['SENT', 'OVERDUE'] } }, { billing_status: { in: ['DRAFT', 'ISSUED', 'PARTIAL'] } }] } }),
        sumField(prisma.payment, { ...paymentWhere, status: 'COMPLETED', paid_at: { gte: todayStart } }, 'amount'),
        sumField(prisma.refund, { deleted_at: null, refunded_at: { gte: todayStart }, payment: paymentWhere }, 'amount')
      ]);
      return {
        metrics: { invoicesToday, overdueInvoices, openBalances, collectionsToday, refundsToday },
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
      return {
        metrics: { occupiedBeds, totalBeds, openMaintenance, lowStockPressure, housekeepingBacklog },
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
      const [activeStaff, shiftsToday, pendingLeaves, staffingBacklog, unassignedShifts] = await Promise.all([
        prisma.staff_profile.count({ where: staffProfileWhere }),
        prisma.shift.count({ where: { ...directScope(scope, { includeTenant: true, includeFacility: true }), start_time: { gte: todayStart } } }),
        prisma.staff_leave.count({ where: { ...leaveWhere, status: 'REQUESTED' } }),
        prisma.staff_position.count({ where: { ...staffPositionScope(scope), is_active: true } }),
        prisma.shift.count({ where: { ...directScope(scope, { includeTenant: true, includeFacility: true }), start_time: { gte: todayStart }, assignments: { none: { deleted_at: null } } } })
      ]);
      return {
        metrics: { activeStaff, shiftsToday, pendingLeaves, staffingBacklog, unassignedShifts },
        trendDates: await selectDateSeries(prisma.staff_leave, { ...leaveWhere, created_at: { gte: trendStart } }, 'created_at'),
        statusCounts: await countByStatuses(prisma.staff_leave, leaveWhere, ['REQUESTED', 'APPROVED', 'REJECTED', 'CANCELLED']),
        activity: {
          staff: await prisma.staff_profile.count({ where: { ...staffProfileWhere, updated_at: { gte: window24h } } }),
          shifts: await prisma.shift.count({ where: { ...directScope(scope, { includeTenant: true, includeFacility: true }), updated_at: { gte: window24h } } }),
          leaves: await prisma.staff_leave.count({ where: { ...leaveWhere, updated_at: { gte: window24h } } })
        }
      };
    }

    if (packId === ROLE_PACKS.BIOMED) {
      const workOrderWhere = { deleted_at: null, ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}) };
      const incidentWhere = { deleted_at: null, ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}) };
      const downtimeWhere = { deleted_at: null, ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}) };
      const [openWorkOrders, openIncidents, activeDowntime, criticalServiceRisk, highPriority] = await Promise.all([
        prisma.equipment_work_order.count({ where: { ...workOrderWhere, status: { in: ['OPEN', 'IN_PROGRESS', 'ACKNOWLEDGED'] } } }),
        prisma.equipment_incident_report.count({ where: { ...incidentWhere, status: { in: ['OPEN', 'IN_PROGRESS', 'REPORTED'] } } }),
        prisma.equipment_downtime_log.count({ where: { ...downtimeWhere, ended_at: null } }),
        prisma.equipment_downtime_log.count({ where: { ...downtimeWhere, ended_at: null, is_clinically_critical: true } }),
        prisma.equipment_work_order.count({ where: { ...workOrderWhere, status: { in: ['OPEN', 'IN_PROGRESS', 'ACKNOWLEDGED'] }, priority: { in: ['HIGH', 'CRITICAL', 'URGENT'] } } })
      ]);
      return {
        metrics: { openWorkOrders, openIncidents, activeDowntime, criticalServiceRisk, highPriority },
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

    const [patientsToday, appointmentsToday, activeAdmissions, openInvoices, paymentsToday] = await Promise.all([
      prisma.patient.count({ where: { ...patientWhere, created_at: { gte: todayStart } } }),
      prisma.appointment.count({ where: { ...appointmentWhere, scheduled_start: { gte: todayStart } } }),
      prisma.admission.count({ where: { ...admissionWhere, status: 'ADMITTED' } }),
      prisma.invoice.count({ where: { ...invoiceWhere, OR: [{ status: { in: ['SENT', 'OVERDUE'] } }, { billing_status: { in: ['DRAFT', 'ISSUED', 'PARTIAL'] } }] } }),
      sumField(prisma.payment, { ...paymentWhere, status: 'COMPLETED', paid_at: { gte: todayStart } }, 'amount')
    ]);
    return {
      metrics: { patientsToday, appointmentsToday, activeAdmissions, openInvoices, paymentsToday },
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
  __private__: {
    ROLE_PACKS,
    buildLabOrderScopeWhere,
    buildLabResultScopeWhere,
    buildPharmacyOrderScopeWhere,
    buildDispenseLogScopeWhere,
    buildInventoryStockScopeWhere,
    buildAmbulanceDispatchScopeWhere,
    buildAmbulanceTripScopeWhere
  }
};
