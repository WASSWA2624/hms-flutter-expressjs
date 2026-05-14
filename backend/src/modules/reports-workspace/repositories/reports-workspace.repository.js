const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const facilitySelect = {
  id: true,
  human_friendly_id: true,
  name: true,
};

const branchSelect = {
  id: true,
  human_friendly_id: true,
  name: true,
  facility_id: true,
};

const userSelect = {
  id: true,
  human_friendly_id: true,
  email: true,
  profile: {
    select: {
      first_name: true,
      last_name: true,
    },
  },
};

const mapError = (error) => {
  throw new HttpError('errors.database.unexpected', 500, [{ originalError: error?.message }]);
};

const baseScope = (scope = {}, { includeFacility = true, includeBranch = true } = {}) => ({
  deleted_at: null,
  ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
  ...(includeFacility && scope.facility_id ? { facility_id: scope.facility_id } : {}),
  ...(includeBranch && scope.branch_id ? { branch_id: scope.branch_id } : {}),
});

const findSummary = async (scope = {}) => {
  try {
    const now = new Date();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const staleThreshold = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const common = baseScope(scope, { includeBranch: false });

    const [
      totalDefinitions,
      activeDefinitions,
      queuedRuns,
      failedRuns,
      completedToday,
      totalSchedules,
      dueSchedules,
      pinnedWidgets,
      staleWidgets,
      criticalKpis,
      warningKpis,
      recentActivity,
    ] = await Promise.all([
      prisma.report_definition.count({ where: common }),
      prisma.report_definition.count({ where: { ...common, status: 'ACTIVE' } }),
      prisma.report_run.count({ where: { ...common, status: 'QUEUED' } }),
      prisma.report_run.count({ where: { ...common, status: 'FAILED' } }),
      prisma.report_run.count({ where: { ...common, status: 'COMPLETED', completed_at: { gte: today } } }),
      prisma.report_schedule.count({ where: common }),
      prisma.report_schedule.count({ where: { ...common, status: 'ACTIVE', next_run_at: { lte: now } } }),
      prisma.dashboard_widget.count({ where: { ...common, is_pinned: true } }),
      prisma.dashboard_widget.count({ where: { ...common, updated_at: { lt: staleThreshold } } }),
      prisma.kpi_snapshot.count({ where: { ...baseScope(scope), threshold_state: 'CRITICAL' } }),
      prisma.kpi_snapshot.count({ where: { ...baseScope(scope), threshold_state: 'WARNING' } }),
      prisma.analytics_event.count({
        where: {
          ...baseScope(scope),
          occurred_at: { gte: new Date(now.getTime() - 24 * 60 * 60 * 1000) },
        },
      }),
    ]);

    return {
      total_definitions: totalDefinitions,
      active_definitions: activeDefinitions,
      queued_runs: queuedRuns,
      failed_runs: failedRuns,
      completed_today: completedToday,
      total_schedules: totalSchedules,
      due_schedules: dueSchedules,
      pinned_widgets: pinnedWidgets,
      stale_widgets: staleWidgets,
      critical_kpis: criticalKpis,
      warning_kpis: warningKpis,
      recent_activity: recentActivity,
    };
  } catch (error) {
    mapError(error);
  }
};

const findLookups = async (scope = {}) => {
  try {
    const [facilities, branches, users] = await Promise.all([
      prisma.facility.findMany({
        where: {
          tenant_id: scope.tenant_id,
          deleted_at: null,
        },
        orderBy: { name: 'asc' },
        select: facilitySelect,
      }),
      prisma.branch.findMany({
        where: {
          tenant_id: scope.tenant_id,
          deleted_at: null,
          ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
        },
        orderBy: { name: 'asc' },
        select: branchSelect,
      }),
      prisma.user.findMany({
        where: {
          tenant_id: scope.tenant_id,
          deleted_at: null,
        },
        take: 100,
        orderBy: { email: 'asc' },
        select: userSelect,
      }),
    ]);

    return { facilities, branches, users };
  } catch (error) {
    mapError(error);
  }
};

const findItems = async ({ resource, where = {}, skip = 0, take = 20, orderBy = { updated_at: 'desc' } } = {}) => {
  try {
    if (resource === 'report-definitions') {
      const [items, total] = await Promise.all([
        prisma.report_definition.findMany({
          where: { deleted_at: null, ...where },
          skip,
          take,
          orderBy,
          include: {
            tenant: { select: { id: true, human_friendly_id: true, name: true } },
            creator: { select: userSelect },
            facility: { select: facilitySelect },
            schedules: { where: { deleted_at: null }, select: { id: true, human_friendly_id: true, name: true, status: true } },
            runs: {
              where: { deleted_at: null },
              take: 1,
              orderBy: [{ queued_at: 'desc' }],
              include: {
                report_definition: { select: { id: true, human_friendly_id: true, name: true } },
                requested_by: { select: userSelect },
                facility: { select: facilitySelect },
                schedule: { select: { id: true, human_friendly_id: true, name: true, retention_days: true } },
              },
            },
            _count: { select: { schedules: { where: { deleted_at: null } } } },
          },
        }),
        prisma.report_definition.count({ where: { deleted_at: null, ...where } }),
      ]);
      return { items, total };
    }

    if (resource === 'report-runs') {
      const [items, total] = await Promise.all([
        prisma.report_run.findMany({
          where: { deleted_at: null, ...where },
          skip,
          take,
          orderBy,
          include: {
            report_definition: { select: { id: true, human_friendly_id: true, name: true, default_format: true } },
            requested_by: { select: userSelect },
            facility: { select: facilitySelect },
            schedule: { select: { id: true, human_friendly_id: true, name: true, retention_days: true, status: true } },
          },
        }),
        prisma.report_run.count({ where: { deleted_at: null, ...where } }),
      ]);
      return { items, total };
    }

    if (resource === 'dashboard-widgets') {
      const [items, total] = await Promise.all([
        prisma.dashboard_widget.findMany({
          where: { deleted_at: null, ...where },
          skip,
          take,
          orderBy,
          include: {
            tenant: { select: { id: true, human_friendly_id: true, name: true } },
            report_definition: { select: { id: true, human_friendly_id: true, name: true } },
          },
        }),
        prisma.dashboard_widget.count({ where: { deleted_at: null, ...where } }),
      ]);
      return { items, total };
    }

    if (resource === 'kpi-snapshots') {
      const [items, total] = await Promise.all([
        prisma.kpi_snapshot.findMany({
          where: { deleted_at: null, ...where },
          skip,
          take,
          orderBy,
          include: {
            tenant: { select: { id: true, human_friendly_id: true, name: true } },
            facility: { select: facilitySelect },
            branch: { select: branchSelect },
          },
        }),
        prisma.kpi_snapshot.count({ where: { deleted_at: null, ...where } }),
      ]);
      return { items, total };
    }

    const [items, total] = await Promise.all([
      prisma.analytics_event.findMany({
        where: { deleted_at: null, ...where },
        skip,
        take,
        orderBy,
        include: {
          tenant: { select: { id: true, human_friendly_id: true, name: true } },
          user: { select: userSelect },
          facility: { select: facilitySelect },
          branch: { select: branchSelect },
        },
      }),
      prisma.analytics_event.count({ where: { deleted_at: null, ...where } }),
    ]);
    return { items, total };
  } catch (error) {
    mapError(error);
  }
};

const findTimeline = async (scope = {}, take = 20) => {
  try {
    const common = baseScope(scope, { includeBranch: false });
    const [runs, schedules, kpis, events] = await Promise.all([
      prisma.report_run.findMany({
        where: common,
        take,
        orderBy: [{ queued_at: 'desc' }],
        include: {
          report_definition: { select: { id: true, human_friendly_id: true, name: true } },
          requested_by: { select: userSelect },
          facility: { select: facilitySelect },
          schedule: { select: { id: true, human_friendly_id: true, name: true } },
        },
      }),
      prisma.report_schedule.findMany({
        where: common,
        take,
        orderBy: [{ updated_at: 'desc' }],
        include: {
          report_definition: { select: { id: true, human_friendly_id: true, name: true } },
          facility: { select: facilitySelect },
          creator: { select: userSelect },
        },
      }),
      prisma.kpi_snapshot.findMany({
        where: {
          ...baseScope(scope),
          threshold_state: { in: ['WARNING', 'CRITICAL'] },
        },
        take,
        orderBy: [{ recorded_at: 'desc' }],
        include: {
          facility: { select: facilitySelect },
          branch: { select: branchSelect },
        },
      }),
      prisma.analytics_event.findMany({
        where: baseScope(scope),
        take,
        orderBy: [{ occurred_at: 'desc' }],
        include: {
          user: { select: userSelect },
          facility: { select: facilitySelect },
          branch: { select: branchSelect },
        },
      }),
    ]);

    return { runs, schedules, kpis, events };
  } catch (error) {
    mapError(error);
  }
};

module.exports = {
  findItems,
  findLookups,
  findSummary,
  findTimeline,
};
