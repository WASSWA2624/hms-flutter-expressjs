const { resolvePublicIdentifier, resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const schedulingWorkspaceRepository = require('@repositories/scheduling-workspace/scheduling-workspace.repository');

const TERMINAL_OPD_STAGES = new Set(['ADMITTED', 'DISCHARGED']);

const normalizeText = (value) => String(value || '').trim();

const toDateAtStartOfDay = (value) => {
  const parsed = value ? new Date(value) : new Date();
  if (Number.isNaN(parsed.getTime())) {
    const fallback = new Date();
    return new Date(fallback.getFullYear(), fallback.getMonth(), fallback.getDate());
  }
  return new Date(parsed.getFullYear(), parsed.getMonth(), parsed.getDate());
};

const addDays = (date, days) => {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
};

const toIso = (value) => (value instanceof Date && !Number.isNaN(value.getTime()) ? value.toISOString() : null);

const formatPersonName = (person = {}) => {
  const directName = [person?.first_name, person?.last_name]
    .map(normalizeText)
    .filter(Boolean)
    .join(' ');
  if (directName) return directName;

  const profileName = [person?.profile?.first_name, person?.profile?.middle_name, person?.profile?.last_name]
    .map(normalizeText)
    .filter(Boolean)
    .join(' ');
  if (profileName) return profileName;

  return normalizeText(person?.email) || resolvePublicIdentifier(person?.human_friendly_id, person?.id) || null;
};

const mapStatusTone = (value) => {
  const normalized = normalizeText(value).toUpperCase();
  if (['CRITICAL', 'OVERDUE', 'CANCELLED'].includes(normalized)) return 'danger';
  if (['WAITING', 'IN_PROGRESS', 'CONFIRMED', 'SCHEDULED'].includes(normalized)) return 'warning';
  if (['COMPLETED', 'AVAILABLE', 'OPEN'].includes(normalized)) return 'success';
  return 'neutral';
};

const buildQueryPath = (pathname, params = {}) => {
  const searchParams = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    const normalized = normalizeText(value);
    if (normalized) searchParams.set(key, normalized);
  });
  const query = searchParams.toString();
  return query ? `${pathname}?${query}` : pathname;
};

const buildScope = async (filters = {}) => {
  const tenantId = await resolveIdentifierForFilter({
    value: filters.tenant_id,
    model: 'tenant',
  });
  const facilityId = await resolveIdentifierForFilter({
    value: filters.facility_id,
    model: 'facility',
    where: tenantId ? { tenant_id: tenantId } : {},
  });
  const patientId = await resolveIdentifierForFilter({
    value: filters.patient_id,
    model: 'patient',
    where: tenantId ? { tenant_id: tenantId } : {},
  });
  const providerUserId = await resolveIdentifierForFilter({
    value: filters.provider_user_id,
    model: 'user',
    where: {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
  });

  return {
    tenantId: tenantId || null,
    facilityId: facilityId || null,
    patientId: patientId || null,
    providerUserId: providerUserId || null,
  };
};

const readFlowStage = (record) => {
  const extension = record?.extension_json;
  if (!extension || typeof extension !== 'object' || Array.isArray(extension)) return null;
  return normalizeText(extension?.opd_flow?.stage || extension?.opdFlow?.stage).toUpperCase() || null;
};

const readFlowNextStep = (record) => {
  const extension = record?.extension_json;
  if (!extension || typeof extension !== 'object' || Array.isArray(extension)) return null;
  return normalizeText(extension?.opd_flow?.next_step || extension?.opdFlow?.nextStep).toUpperCase() || null;
};

const mapAppointmentItem = (record) => {
  const appointmentId = resolvePublicIdentifier(record?.human_friendly_id, record?.id);
  const patientId = resolvePublicIdentifier(record?.patient?.human_friendly_id, record?.patient?.id);
  const providerId = resolvePublicIdentifier(record?.provider?.human_friendly_id, record?.provider?.id);
  const patientLabel = formatPersonName(record?.patient);
  const providerLabel = formatPersonName(record?.provider);
  const reason = normalizeText(record?.reason);

  return {
    id: appointmentId || `appointment-${toIso(record?.scheduled_start) || 'pending'}`,
    human_friendly_id: appointmentId,
    title: reason || patientLabel || 'Scheduled appointment',
    subtitle: [providerLabel, normalizeText(record?.facility?.name)].filter(Boolean).join(' | '),
    patient_id: patientId,
    patient_label: patientLabel,
    provider_user_id: providerId,
    provider_label: providerLabel,
    status: record?.status || null,
    tone: mapStatusTone(record?.status),
    scheduled_start: toIso(record?.scheduled_start),
    scheduled_end: toIso(record?.scheduled_end),
    target_path: appointmentId
      ? buildQueryPath(`/scheduling/appointments/${appointmentId}`, {
          patientId,
          providerUserId: providerId,
          appointmentId,
        })
      : '/scheduling/appointments',
  };
};

const mapQueueItem = (record) => {
  const queueId = resolvePublicIdentifier(record?.human_friendly_id, record?.id);
  const patientId = resolvePublicIdentifier(record?.patient?.human_friendly_id, record?.patient?.id);
  const providerId = resolvePublicIdentifier(record?.provider?.human_friendly_id, record?.provider?.id);
  const appointmentId = resolvePublicIdentifier(record?.appointment?.human_friendly_id, record?.appointment?.id);

  return {
    id: queueId || `queue-${toIso(record?.queued_at) || 'pending'}`,
    human_friendly_id: queueId,
    title: formatPersonName(record?.patient) || 'Queued patient',
    subtitle: [
      formatPersonName(record?.provider),
      appointmentId ? `Appt ${appointmentId}` : null,
    ].filter(Boolean).join(' | '),
    patient_id: patientId,
    provider_user_id: providerId,
    appointment_id: appointmentId,
    status: record?.status || null,
    tone: mapStatusTone(record?.status),
    queued_at: toIso(record?.queued_at),
    target_path: queueId
      ? buildQueryPath(`/scheduling/visit-queues/${queueId}`, {
          patientId,
          providerUserId: providerId,
          appointmentId,
        })
      : '/scheduling/visit-queues',
  };
};

const mapReminderItem = (record) => {
  const reminderId = resolvePublicIdentifier(record?.human_friendly_id, record?.id);
  const appointmentId = resolvePublicIdentifier(
    record?.appointment?.human_friendly_id,
    record?.appointment?.id
  );
  const patientId = resolvePublicIdentifier(
    record?.appointment?.patient?.human_friendly_id,
    record?.appointment?.patient?.id
  );

  return {
    id: reminderId || `reminder-${toIso(record?.scheduled_at) || 'pending'}`,
    human_friendly_id: reminderId,
    title: formatPersonName(record?.appointment?.patient) || 'Pending reminder',
    subtitle: [record?.channel, normalizeText(record?.appointment?.reason)].filter(Boolean).join(' | '),
    appointment_id: appointmentId,
    patient_id: patientId,
    channel: record?.channel || null,
    status: 'DUE',
    tone: 'warning',
    scheduled_at: toIso(record?.scheduled_at),
    target_path: reminderId
      ? buildQueryPath(`/scheduling/appointment-reminders/${reminderId}`, {
          appointmentId,
          patientId,
        })
      : '/scheduling/appointment-reminders',
  };
};

const mapFollowUpItem = (record) => {
  const followUpId = resolvePublicIdentifier(record?.human_friendly_id, record?.id);
  const encounterId = resolvePublicIdentifier(record?.encounter?.human_friendly_id, record?.encounter?.id);
  const patientId = resolvePublicIdentifier(
    record?.encounter?.patient?.human_friendly_id,
    record?.encounter?.patient?.id
  );

  return {
    id: followUpId || `followup-${toIso(record?.scheduled_at) || 'pending'}`,
    human_friendly_id: followUpId,
    title: formatPersonName(record?.encounter?.patient) || 'Scheduled follow-up',
    subtitle: [formatPersonName(record?.encounter?.provider), normalizeText(record?.notes)].filter(Boolean).join(' | '),
    patient_id: patientId,
    encounter_id: encounterId,
    status: record?.status || null,
    tone: mapStatusTone(record?.status),
    scheduled_at: toIso(record?.scheduled_at),
    target_path: followUpId
      ? buildQueryPath(`/clinical/follow-ups/${followUpId}`, {
          patientId,
          encounterId,
        })
      : '/clinical/follow-ups',
  };
};

const mapCapacityItem = (record, appointmentCounts = new Map()) => {
  const scheduleId = resolvePublicIdentifier(record?.human_friendly_id, record?.id);
  const providerId = resolvePublicIdentifier(record?.provider?.human_friendly_id, record?.provider?.id);
  const availableSlots = Array.isArray(record?.slots)
    ? record.slots.filter((slot) => slot?.is_available).length
    : 0;
  const providerKey = normalizeText(providerId || record?.provider?.id);
  const bookedAppointments = Number(appointmentCounts.get(providerKey) || 0);

  return {
    id: scheduleId || `schedule-${providerKey || 'unassigned'}`,
    human_friendly_id: scheduleId,
    title: formatPersonName(record?.provider) || 'Provider schedule',
    subtitle: normalizeText(record?.facility?.name) || normalizeText(record?.timezone) || null,
    provider_user_id: providerId,
    provider_label: formatPersonName(record?.provider),
    status: availableSlots > 0 ? 'AVAILABLE' : 'FULL',
    tone: availableSlots > 0 ? 'success' : 'warning',
    available_slots: availableSlots,
    booked_appointments: bookedAppointments,
    start_time: toIso(record?.start_time),
    end_time: toIso(record?.end_time),
    target_path: scheduleId
      ? buildQueryPath(`/scheduling/provider-schedules/${scheduleId}`, {
          providerUserId: providerId,
          scheduleId,
        })
      : '/scheduling/provider-schedules',
  };
};

const mapOpdItem = (record) => {
  const encounterId = resolvePublicIdentifier(record?.human_friendly_id, record?.id);
  const patientId = resolvePublicIdentifier(record?.patient?.human_friendly_id, record?.patient?.id);
  const providerId = resolvePublicIdentifier(record?.provider?.human_friendly_id, record?.provider?.id);
  const stage = readFlowStage(record);
  const nextStep = readFlowNextStep(record);

  return {
    id: encounterId || `opd-${toIso(record?.updated_at) || 'pending'}`,
    human_friendly_id: encounterId,
    title: formatPersonName(record?.patient) || 'Active OPD flow',
    subtitle: [formatPersonName(record?.provider), normalizeText(record?.encounter_type)].filter(Boolean).join(' | '),
    patient_id: patientId,
    provider_user_id: providerId,
    stage,
    next_step: nextStep,
    tone: mapStatusTone(stage || record?.status),
    updated_at: toIso(record?.updated_at),
    target_path: encounterId ? `/scheduling/opd-flows/${encounterId}` : '/scheduling/opd-flows',
  };
};

const buildSummaryCards = ({
  appointmentCount,
  queueCount,
  activeOpdCount,
  reminderCount,
  followUpCount,
  providerCount,
} = {}) => [
  { id: 'today_appointments', label_key: 'scheduling.workspace.summary.todayAppointments', value: Number(appointmentCount || 0), tone: 'primary' },
  { id: 'waiting_queue', label_key: 'scheduling.workspace.summary.waitingQueue', value: Number(queueCount || 0), tone: 'warning' },
  { id: 'active_opd', label_key: 'scheduling.workspace.summary.activeOpd', value: Number(activeOpdCount || 0), tone: 'warning' },
  { id: 'due_reminders', label_key: 'scheduling.workspace.summary.dueReminders', value: Number(reminderCount || 0), tone: 'danger' },
  { id: 'follow_ups_due', label_key: 'scheduling.workspace.summary.followUpsDue', value: Number(followUpCount || 0), tone: 'primary' },
  { id: 'providers_on_duty', label_key: 'scheduling.workspace.summary.providersOnDuty', value: Number(providerCount || 0), tone: 'success' },
];

const buildPanelSummaries = ({
  appointmentCount,
  queueCount,
  activeOpdCount,
  reminderCount,
  followUpCount,
  providerCount,
} = {}) => [
  { id: 'overview', label_key: 'scheduling.workspace.panels.overview', count: Number(appointmentCount || 0) + Number(queueCount || 0), target_path: '/scheduling' },
  { id: 'arrivals', label_key: 'scheduling.workspace.panels.arrivals', count: Number(appointmentCount || 0), target_path: '/scheduling/appointments' },
  { id: 'queue', label_key: 'scheduling.workspace.panels.queue', count: Number(queueCount || 0), target_path: '/scheduling/visit-queues' },
  { id: 'opd', label_key: 'scheduling.workspace.panels.opd', count: Number(activeOpdCount || 0), target_path: '/scheduling/opd-flows' },
  { id: 'reminders', label_key: 'scheduling.workspace.panels.reminders', count: Number(reminderCount || 0), target_path: '/scheduling/appointment-reminders?reminderBoard=DUE' },
  { id: 'capacity', label_key: 'scheduling.workspace.panels.capacity', count: Number(providerCount || 0), target_path: '/scheduling/provider-schedules' },
  { id: 'followups', label_key: 'scheduling.workspace.panels.followups', count: Number(followUpCount || 0), target_path: '/clinical/follow-ups' },
];

const buildQueueSummaries = ({
  appointmentCount,
  queueCount,
  activeOpdCount,
  reminderCount,
  followUpCount,
} = {}) => [
  { queue: 'ARRIVING_TODAY', label_key: 'scheduling.workspace.queues.ARRIVING_TODAY', count: Number(appointmentCount || 0), target_path: '/scheduling/appointments' },
  { queue: 'WAITING_QUEUE', label_key: 'scheduling.workspace.queues.WAITING_QUEUE', count: Number(queueCount || 0), target_path: '/scheduling/visit-queues?status=IN_PROGRESS' },
  { queue: 'ACTIVE_OPD', label_key: 'scheduling.workspace.queues.ACTIVE_OPD', count: Number(activeOpdCount || 0), target_path: '/scheduling/opd-flows' },
  { queue: 'OVERDUE_REMINDERS', label_key: 'scheduling.workspace.queues.OVERDUE_REMINDERS', count: Number(reminderCount || 0), target_path: '/scheduling/appointment-reminders?reminderBoard=DUE' },
  { queue: 'FOLLOW_UPS_DUE', label_key: 'scheduling.workspace.queues.FOLLOW_UPS_DUE', count: Number(followUpCount || 0), target_path: '/clinical/follow-ups' },
];

const buildQuickActions = () => ([
  { id: 'new_appointment', label_key: 'scheduling.workspace.quickActions.newAppointment', target_path: '/scheduling/appointments/create', icon: 'calendar' },
  { id: 'start_walk_in', label_key: 'scheduling.workspace.quickActions.startWalkIn', target_path: '/scheduling/opd-flows', icon: 'plus' },
  { id: 'manage_schedule', label_key: 'scheduling.workspace.quickActions.manageSchedule', target_path: '/scheduling/provider-schedules', icon: 'clock' },
  { id: 'due_reminders', label_key: 'scheduling.workspace.quickActions.dueReminders', target_path: '/scheduling/appointment-reminders?reminderBoard=DUE', icon: 'bell' },
]);

const buildSpotlight = ({ appointments = [], queue = [], opd = [], reminders = [], followUps = [] } = {}) =>
  [
    ...queue.slice(0, 2).map((item) => ({ id: `${item.id}-queue`, label_key: 'scheduling.workspace.spotlight.waitingPatient', tone: item.tone, title: item.title, subtitle: item.subtitle, target_path: item.target_path })),
    ...opd.slice(0, 2).map((item) => ({ id: `${item.id}-opd`, label_key: 'scheduling.workspace.spotlight.activeConsultation', tone: item.tone, title: item.title, subtitle: item.stage, target_path: item.target_path })),
    ...reminders.slice(0, 2).map((item) => ({ id: `${item.id}-reminder`, label_key: 'scheduling.workspace.spotlight.overdueReminder', tone: item.tone, title: item.title, subtitle: item.channel, target_path: item.target_path })),
    ...followUps.slice(0, 1).map((item) => ({ id: `${item.id}-followup`, label_key: 'scheduling.workspace.spotlight.followUpDue', tone: item.tone, title: item.title, subtitle: item.subtitle, target_path: item.target_path })),
    ...appointments.slice(0, 1).map((item) => ({ id: `${item.id}-arrival`, label_key: 'scheduling.workspace.spotlight.arrivingPatient', tone: item.tone, title: item.title, subtitle: item.subtitle, target_path: item.target_path })),
  ];

const getWorkspace = async (filters = {}, page = 1, limit = 12) => {
  const scope = await buildScope(filters);
  const targetDate = toDateAtStartOfDay(filters.date);
  const dayStart = targetDate;
  const dayEnd = addDays(targetDate, 1);
  const search = normalizeText(filters.search) || null;

  const appointmentWhere = schedulingWorkspaceRepository.buildAppointmentWhere({
    ...scope,
    search,
    dayStart,
    dayEnd,
  });
  const queueWhere = schedulingWorkspaceRepository.buildQueueWhere({
    ...scope,
    search,
  });
  const reminderWhere = schedulingWorkspaceRepository.buildReminderWhere({
    ...scope,
    search,
    dueAt: dayEnd,
  });
  const followUpWhere = schedulingWorkspaceRepository.buildFollowUpWhere({
    ...scope,
    search,
    dueStart: dayStart,
    dueEnd: dayEnd,
  });
  const scheduleWhere = schedulingWorkspaceRepository.buildScheduleWhere({
    ...scope,
    search,
    dayOfWeek: dayStart.getDay(),
    dayEnd,
  });
  const openEncounterWhere = schedulingWorkspaceRepository.buildOpenEncounterWhere({
    ...scope,
    search,
  });

  const [
    appointmentsRaw,
    appointmentCount,
    queueRaw,
    queueCount,
    remindersRaw,
    reminderCount,
    followUpsRaw,
    followUpCount,
    schedulesRaw,
    providerCount,
    openEncountersRaw,
    openEncounterCount,
  ] = await Promise.all([
    schedulingWorkspaceRepository.findAppointments({ where: appointmentWhere, take: limit }),
    schedulingWorkspaceRepository.countAppointments(appointmentWhere),
    schedulingWorkspaceRepository.findQueueEntries({ where: queueWhere, take: limit }),
    schedulingWorkspaceRepository.countQueueEntries(queueWhere),
    schedulingWorkspaceRepository.findReminders({ where: reminderWhere, take: limit }),
    schedulingWorkspaceRepository.countReminders(reminderWhere),
    schedulingWorkspaceRepository.findFollowUps({ where: followUpWhere, take: limit }),
    schedulingWorkspaceRepository.countFollowUps(followUpWhere),
    schedulingWorkspaceRepository.findSchedules({ where: scheduleWhere, take: limit, dayStart, dayEnd }),
    schedulingWorkspaceRepository.countSchedules(scheduleWhere),
    schedulingWorkspaceRepository.findOpenEncounters({ where: openEncounterWhere, take: limit * 2 }),
    schedulingWorkspaceRepository.countOpenEncounters(openEncounterWhere),
  ]);

  const appointmentCountsByProvider = appointmentsRaw.reduce((accumulator, appointment) => {
    const providerId = normalizeText(
      resolvePublicIdentifier(appointment?.provider?.human_friendly_id, appointment?.provider?.id)
    );
    if (!providerId) return accumulator;
    accumulator.set(providerId, Number(accumulator.get(providerId) || 0) + 1);
    return accumulator;
  }, new Map());

  const appointments = appointmentsRaw.map(mapAppointmentItem);
  const queue = queueRaw.map(mapQueueItem);
  const reminders = remindersRaw.map(mapReminderItem);
  const followUps = followUpsRaw.map(mapFollowUpItem);
  const capacity = schedulesRaw.map((record) => mapCapacityItem(record, appointmentCountsByProvider));
  const opd = openEncountersRaw
    .map(mapOpdItem)
    .filter((item) => item.stage && !TERMINAL_OPD_STAGES.has(item.stage));

  const activeOpdCount = opd.length > 0 ? opd.length : openEncounterCount;

  return {
    generated_at: new Date().toISOString(),
    scope: {
      tenant_id: scope.tenantId || null,
      facility_id: scope.facilityId || null,
      patient_id: scope.patientId || null,
      provider_user_id: scope.providerUserId || null,
      target_date: targetDate.toISOString().slice(0, 10),
    },
    filters: {
      panel: normalizeText(filters.panel || 'overview').toLowerCase(),
      queue: normalizeText(filters.queue).toUpperCase() || null,
      search,
      status: normalizeText(filters.status).toUpperCase() || null,
    },
    summary_cards: buildSummaryCards({
      appointmentCount,
      queueCount,
      activeOpdCount,
      reminderCount,
      followUpCount,
      providerCount,
    }),
    panel_summaries: buildPanelSummaries({
      appointmentCount,
      queueCount,
      activeOpdCount,
      reminderCount,
      followUpCount,
      providerCount,
    }),
    queue_summaries: buildQueueSummaries({
      appointmentCount,
      queueCount,
      activeOpdCount,
      reminderCount,
      followUpCount,
    }),
    quick_actions: buildQuickActions(),
    spotlight: buildSpotlight({ appointments, queue, opd, reminders, followUps }),
    boards: {
      arrivals: {
        items: appointments,
        total_count: appointmentCount,
        target_path: '/scheduling/appointments',
      },
      queue: {
        items: queue,
        total_count: queueCount,
        target_path: '/scheduling/visit-queues?status=IN_PROGRESS',
      },
      opd: {
        items: opd,
        total_count: activeOpdCount,
        target_path: '/scheduling/opd-flows',
      },
      reminders: {
        items: reminders,
        total_count: reminderCount,
        target_path: '/scheduling/appointment-reminders?reminderBoard=DUE',
      },
      capacity: {
        items: capacity,
        total_count: providerCount,
        target_path: '/scheduling/provider-schedules',
      },
      followups: {
        items: followUps,
        total_count: followUpCount,
        target_path: '/clinical/follow-ups',
      },
    },
    schedule_day: {
      date: targetDate.toISOString().slice(0, 10),
      appointments,
      capacity,
    },
    pagination: {
      page,
      limit,
    },
  };
};

const getReferenceData = async (filters = {}) => {
  const scope = await buildScope(filters);
  const [facilities, providers] = await Promise.all([
    schedulingWorkspaceRepository.findFacilities({
      tenantId: scope.tenantId,
      search: filters.search,
    }),
    schedulingWorkspaceRepository.findProviders({
      tenantId: scope.tenantId,
      facilityId: scope.facilityId,
      search: filters.search,
    }),
  ]);

  return {
    facilities: facilities.map((facility) => ({
      value: resolvePublicIdentifier(facility?.human_friendly_id, facility?.id),
      label: facility?.name || resolvePublicIdentifier(facility?.human_friendly_id, facility?.id),
    })).filter((entry) => entry.value),
    providers: providers.map((provider) => ({
      value: resolvePublicIdentifier(provider?.human_friendly_id, provider?.id),
      label: formatPersonName(provider),
      subtitle: normalizeText(provider?.email) || null,
    })).filter((entry) => entry.value),
  };
};

const resolveLegacyRouteIdentifier = async (resource, id) => {
  const record = await schedulingWorkspaceRepository.resolveLegacyRecord({ resource, id });
  const publicId = resolvePublicIdentifier(record?.human_friendly_id, record?.id);

  const routeMap = {
    appointments: publicId ? `/scheduling/appointments/${publicId}` : '/scheduling/appointments',
    'appointment-reminders': publicId ? `/scheduling/appointment-reminders/${publicId}` : '/scheduling/appointment-reminders',
    'provider-schedules': publicId ? `/scheduling/provider-schedules/${publicId}` : '/scheduling/provider-schedules',
    'availability-slots': publicId ? `/scheduling/availability-slots/${publicId}` : '/scheduling/availability-slots',
    'visit-queues': publicId ? `/scheduling/visit-queues/${publicId}` : '/scheduling/visit-queues',
    'opd-flows': publicId ? `/scheduling/opd-flows/${publicId}` : '/scheduling/opd-flows',
    'follow-ups': publicId ? `/clinical/follow-ups/${publicId}` : '/clinical/follow-ups',
  };

  return {
    resource,
    id: publicId,
    target_path: routeMap[resource] || '/scheduling',
  };
};

module.exports = {
  getWorkspace,
  getReferenceData,
  resolveLegacyRouteIdentifier,
};
