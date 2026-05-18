const prisma = require('@prisma/client');

const ACTIVE_APPOINTMENT_STATUSES = ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS'];

const resolvePublicIdSearch = (value) => String(value || '').trim().toUpperCase();
const resolveTextSearch = (value) => String(value || '').trim();

const appendSearchClause = (where, clause) => {
  if (!clause) return where;
  return {
    ...where,
    AND: [...(Array.isArray(where.AND) ? where.AND : []), clause],
  };
};

const withScope = ({ tenantId = null, facilityId = null } = {}) => ({
  deleted_at: null,
  ...(tenantId ? { tenant_id: tenantId } : {}),
  ...(facilityId ? { facility_id: facilityId } : {}),
});

const buildAppointmentWhere = ({
  tenantId,
  facilityId,
  patientId = null,
  providerUserId = null,
  status = null,
  search = null,
  dayStart = null,
  dayEnd = null,
} = {}) => {
  let where = {
    ...withScope({ tenantId, facilityId }),
    ...(patientId ? { patient_id: patientId } : {}),
    ...(providerUserId ? { provider_user_id: providerUserId } : {}),
    ...(status ? { status } : {}),
    patient: { deleted_at: null },
  };

  if (dayStart || dayEnd) {
    where.scheduled_start = {
      ...(dayStart ? { gte: dayStart } : {}),
      ...(dayEnd ? { lte: dayEnd } : {}),
    };
  }

  const rawSearch = resolveTextSearch(search);
  if (rawSearch) {
    const upperSearch = resolvePublicIdSearch(rawSearch);
    where = appendSearchClause(where, {
      OR: [
        { human_friendly_id: { contains: upperSearch } },
        { reason: { contains: rawSearch } },
        { patient: { human_friendly_id: { contains: upperSearch } } },
        { patient: { first_name: { contains: rawSearch } } },
        { patient: { last_name: { contains: rawSearch } } },
        { provider: { human_friendly_id: { contains: upperSearch } } },
        { provider: { email: { contains: rawSearch } } },
        { provider: { profile: { first_name: { contains: rawSearch } } } },
        { provider: { profile: { last_name: { contains: rawSearch } } } },
      ],
    });
  }

  return where;
};

const buildQueueWhere = ({
  tenantId,
  facilityId,
  patientId = null,
  providerUserId = null,
  search = null,
} = {}) => {
  let where = {
    ...withScope({ tenantId, facilityId }),
    ...(patientId ? { patient_id: patientId } : {}),
    ...(providerUserId ? { provider_user_id: providerUserId } : {}),
    patient: { deleted_at: null },
    status: { in: ACTIVE_APPOINTMENT_STATUSES },
  };

  const rawSearch = resolveTextSearch(search);
  if (rawSearch) {
    const upperSearch = resolvePublicIdSearch(rawSearch);
    where = appendSearchClause(where, {
      OR: [
        { human_friendly_id: { contains: upperSearch } },
        { patient: { human_friendly_id: { contains: upperSearch } } },
        { patient: { first_name: { contains: rawSearch } } },
        { patient: { last_name: { contains: rawSearch } } },
        { appointment: { human_friendly_id: { contains: upperSearch } } },
        { provider: { human_friendly_id: { contains: upperSearch } } },
        { provider: { profile: { first_name: { contains: rawSearch } } } },
        { provider: { profile: { last_name: { contains: rawSearch } } } },
      ],
    });
  }

  return where;
};

const buildReminderWhere = ({
  tenantId,
  facilityId,
  patientId = null,
  providerUserId = null,
  search = null,
  dueAt = null,
} = {}) => {
  let where = {
    deleted_at: null,
    sent_at: null,
    appointment: {
      ...withScope({ tenantId, facilityId }),
      ...(patientId ? { patient_id: patientId } : {}),
      ...(providerUserId ? { provider_user_id: providerUserId } : {}),
      patient: { deleted_at: null },
    },
    ...(dueAt ? { scheduled_at: { lte: dueAt } } : {}),
  };

  const rawSearch = resolveTextSearch(search);
  if (rawSearch) {
    const upperSearch = resolvePublicIdSearch(rawSearch);
    where = appendSearchClause(where, {
      OR: [
        { human_friendly_id: { contains: upperSearch } },
        { appointment: { human_friendly_id: { contains: upperSearch } } },
        { appointment: { reason: { contains: rawSearch } } },
        { appointment: { patient: { human_friendly_id: { contains: upperSearch } } } },
        { appointment: { patient: { first_name: { contains: rawSearch } } } },
        { appointment: { patient: { last_name: { contains: rawSearch } } } },
      ],
    });
  }

  return where;
};

const buildFollowUpWhere = ({
  tenantId,
  facilityId,
  patientId = null,
  providerUserId = null,
  search = null,
  dueStart = null,
  dueEnd = null,
} = {}) => {
  let where = {
    deleted_at: null,
    status: 'SCHEDULED',
    encounter: {
      ...withScope({ tenantId, facilityId }),
      ...(patientId ? { patient_id: patientId } : {}),
      ...(providerUserId ? { provider_user_id: providerUserId } : {}),
      patient: { deleted_at: null },
    },
  };

  if (dueStart || dueEnd) {
    where.scheduled_at = {
      ...(dueStart ? { gte: dueStart } : {}),
      ...(dueEnd ? { lte: dueEnd } : {}),
    };
  }

  const rawSearch = resolveTextSearch(search);
  if (rawSearch) {
    const upperSearch = resolvePublicIdSearch(rawSearch);
    where = appendSearchClause(where, {
      OR: [
        { human_friendly_id: { contains: upperSearch } },
        { notes: { contains: rawSearch } },
        { encounter: { human_friendly_id: { contains: upperSearch } } },
        { encounter: { patient: { human_friendly_id: { contains: upperSearch } } } },
        { encounter: { patient: { first_name: { contains: rawSearch } } } },
        { encounter: { patient: { last_name: { contains: rawSearch } } } },
        { encounter: { provider: { profile: { first_name: { contains: rawSearch } } } } },
        { encounter: { provider: { profile: { last_name: { contains: rawSearch } } } } },
      ],
    });
  }

  return where;
};

const buildScheduleWhere = ({
  tenantId,
  facilityId,
  providerUserId = null,
  search = null,
  dayOfWeek = null,
  dayEnd = null,
} = {}) => {
  let where = {
    ...withScope({ tenantId, facilityId }),
    ...(providerUserId ? { provider_user_id: providerUserId } : {}),
    ...(Number.isInteger(dayOfWeek) ? { day_of_week: dayOfWeek } : {}),
  };

  if (dayEnd) {
    where.AND = [
      { OR: [{ effective_from: null }, { effective_from: { lte: dayEnd } }] },
      { OR: [{ effective_to: null }, { effective_to: { gte: dayEnd } }] },
    ];
  }

  const rawSearch = resolveTextSearch(search);
  if (rawSearch) {
    const upperSearch = resolvePublicIdSearch(rawSearch);
    where = appendSearchClause(where, {
      OR: [
        { human_friendly_id: { contains: upperSearch } },
        { provider: { human_friendly_id: { contains: upperSearch } } },
        { provider: { email: { contains: rawSearch } } },
        { provider: { profile: { first_name: { contains: rawSearch } } } },
        { provider: { profile: { last_name: { contains: rawSearch } } } },
      ],
    });
  }

  return where;
};

const buildOpenEncounterWhere = ({
  tenantId,
  facilityId,
  patientId = null,
  providerUserId = null,
  search = null,
} = {}) => {
  let where = {
    ...withScope({ tenantId, facilityId }),
    encounter_type: { in: ['OPD', 'EMERGENCY'] },
    status: 'OPEN',
    ...(patientId ? { patient_id: patientId } : {}),
    ...(providerUserId ? { provider_user_id: providerUserId } : {}),
    patient: { deleted_at: null },
  };

  const rawSearch = resolveTextSearch(search);
  if (rawSearch) {
    const upperSearch = resolvePublicIdSearch(rawSearch);
    where = appendSearchClause(where, {
      OR: [
        { human_friendly_id: { contains: upperSearch } },
        { patient: { human_friendly_id: { contains: upperSearch } } },
        { patient: { first_name: { contains: rawSearch } } },
        { patient: { last_name: { contains: rawSearch } } },
        { provider: { human_friendly_id: { contains: upperSearch } } },
        { provider: { profile: { first_name: { contains: rawSearch } } } },
        { provider: { profile: { last_name: { contains: rawSearch } } } },
      ],
    });
  }

  return where;
};

const PATIENT_SELECT = {
  id: true,
  human_friendly_id: true,
  first_name: true,
  last_name: true,
};

const USER_SELECT = {
  id: true,
  human_friendly_id: true,
  email: true,
  profile: {
    select: {
      first_name: true,
      middle_name: true,
      last_name: true,
    },
  },
};

const FACILITY_SELECT = {
  id: true,
  human_friendly_id: true,
  name: true,
};

const findAppointments = async ({ where, take = 8 } = {}) =>
  prisma.appointment.findMany({
    where,
    orderBy: [{ scheduled_start: 'asc' }, { created_at: 'desc' }],
    take,
    include: {
      facility: { select: FACILITY_SELECT },
      patient: { select: PATIENT_SELECT },
      provider: { select: USER_SELECT },
    },
  });

const countAppointments = async (where) => prisma.appointment.count({ where });

const findQueueEntries = async ({ where, take = 8 } = {}) =>
  prisma.visit_queue.findMany({
    where,
    orderBy: [{ queued_at: 'asc' }, { created_at: 'asc' }],
    take,
    include: {
      facility: { select: FACILITY_SELECT },
      patient: { select: PATIENT_SELECT },
      provider: { select: USER_SELECT },
      appointment: {
        select: {
          id: true,
          human_friendly_id: true,
          scheduled_start: true,
          status: true,
        },
      },
    },
  });

const countQueueEntries = async (where) => prisma.visit_queue.count({ where });

const findReminders = async ({ where, take = 8 } = {}) =>
  prisma.appointment_reminder.findMany({
    where,
    orderBy: [{ scheduled_at: 'asc' }, { created_at: 'asc' }],
    take,
    include: {
      appointment: {
        include: {
          facility: { select: FACILITY_SELECT },
          patient: { select: PATIENT_SELECT },
          provider: { select: USER_SELECT },
        },
      },
    },
  });

const countReminders = async (where) => prisma.appointment_reminder.count({ where });

const findFollowUps = async ({ where, take = 8 } = {}) =>
  prisma.follow_up.findMany({
    where,
    orderBy: [{ scheduled_at: 'asc' }, { created_at: 'asc' }],
    take,
    include: {
      encounter: {
        include: {
          facility: { select: FACILITY_SELECT },
          patient: { select: PATIENT_SELECT },
          provider: { select: USER_SELECT },
        },
      },
    },
  });

const countFollowUps = async (where) => prisma.follow_up.count({ where });

const findSchedules = async ({ where, take = 8, dayStart = null, dayEnd = null } = {}) =>
  prisma.provider_schedule.findMany({
    where,
    orderBy: [{ start_time: 'asc' }, { created_at: 'asc' }],
    take,
    include: {
      facility: { select: FACILITY_SELECT },
      provider: { select: USER_SELECT },
      slots: {
        where: {
          deleted_at: null,
          ...(dayStart || dayEnd
            ? {
                OR: [
                  {
                    override_date: {
                      ...(dayStart ? { gte: dayStart } : {}),
                      ...(dayEnd ? { lte: dayEnd } : {}),
                    },
                  },
                  { override_date: null },
                ],
              }
            : {}),
        },
        select: {
          id: true,
          human_friendly_id: true,
          override_date: true,
          start_time: true,
          end_time: true,
          is_available: true,
        },
      },
    },
  });

const countSchedules = async (where) => prisma.provider_schedule.count({ where });

const findOpenEncounters = async ({ where, take = 12 } = {}) =>
  prisma.encounter.findMany({
    where,
    orderBy: [{ updated_at: 'desc' }, { started_at: 'desc' }],
    take,
    include: {
      facility: { select: FACILITY_SELECT },
      patient: { select: PATIENT_SELECT },
      provider: { select: USER_SELECT },
    },
  });

const countOpenEncounters = async (where) => prisma.encounter.count({ where });

const findFacilities = async ({ tenantId = null, search = null } = {}) => {
  const where = {
    deleted_at: null,
    ...(tenantId ? { tenant_id: tenantId } : {}),
    ...(resolveTextSearch(search)
      ? {
          OR: [
            { name: { contains: resolveTextSearch(search) } },
            { human_friendly_id: { contains: resolvePublicIdSearch(search) } },
          ],
        }
      : {}),
  };

  return prisma.facility.findMany({
    where,
    orderBy: { name: 'asc' },
    take: 30,
    select: FACILITY_SELECT,
  });
};

const findProviders = async ({ tenantId = null, facilityId = null, search = null } = {}) => {
  const rawSearch = resolveTextSearch(search);
  const upperSearch = resolvePublicIdSearch(search);
  return prisma.user.findMany({
    where: {
      deleted_at: null,
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
      AND: [
        {
          OR: [
            { provider_schedules: { some: { deleted_at: null } } },
            { appointments: { some: { deleted_at: null } } },
            { encounters: { some: { deleted_at: null, encounter_type: { in: ['OPD', 'EMERGENCY'] } } } },
          ],
        },
        ...(rawSearch
          ? [
              {
                OR: [
                  { human_friendly_id: { contains: upperSearch } },
                  { email: { contains: rawSearch } },
                  { profile: { first_name: { contains: rawSearch } } },
                  { profile: { middle_name: { contains: rawSearch } } },
                  { profile: { last_name: { contains: rawSearch } } },
                ],
              },
            ]
          : []),
      ],
    },
    orderBy: [{ email: 'asc' }, { created_at: 'asc' }],
    take: 40,
    select: USER_SELECT,
  });
};

const LEGACY_MODEL_MAP = Object.freeze({
  appointments: 'appointment',
  'appointment-reminders': 'appointment_reminder',
  'provider-schedules': 'provider_schedule',
  'availability-slots': 'availability_slot',
  'visit-queues': 'visit_queue',
  'opd-flows': 'encounter',
  'follow-ups': 'follow_up',
});

const resolveLegacyRecord = async ({ resource, id } = {}) => {
  const model = LEGACY_MODEL_MAP[resource];
  if (!model || !prisma?.[model]?.findFirst) return null;

  return prisma[model].findFirst({
    where: {
      deleted_at: null,
      OR: [{ id }, { human_friendly_id: String(id || '').trim().toUpperCase() }],
    },
    select: {
      id: true,
      human_friendly_id: true,
    },
  });
};

module.exports = {
  ACTIVE_APPOINTMENT_STATUSES,
  buildAppointmentWhere,
  buildQueueWhere,
  buildReminderWhere,
  buildFollowUpWhere,
  buildScheduleWhere,
  buildOpenEncounterWhere,
  PATIENT_SELECT,
  USER_SELECT,
  FACILITY_SELECT,
  findAppointments,
  countAppointments,
  findQueueEntries,
  countQueueEntries,
  findReminders,
  countReminders,
  findFollowUps,
  countFollowUps,
  findSchedules,
  countSchedules,
  findOpenEncounters,
  countOpenEncounters,
  findFacilities,
  findProviders,
  resolveLegacyRecord,
};
