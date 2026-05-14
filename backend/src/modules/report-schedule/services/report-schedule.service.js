const reportScheduleRepository = require('@repositories/report-schedule/report-schedule.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { getNextScheduledTime } = require('@lib/reports/runtime');
const {
  buildPagination,
  buildSearchWhere,
  buildSinceFilter,
  buildSort,
  createAuditDiff,
  ensureVersionMatch,
  normalizeString,
  resolvePayloadIdentifier,
  resolveScopeIdsForList,
  resolveScopedContext,
  safeUpper,
} = require('@lib/reports/api');
const {
  REPORT_DEFAULT_RETENTION_DAYS,
  REPORT_FORMATS,
  REPORT_SCHEDULE_FREQUENCIES,
  REPORT_SCHEDULE_STATUSES,
} = require('@lib/reports/constants');
const { serializeReportSchedule } = require('@lib/reports/serializers');

const SORT_FIELDS = ['next_run_at', 'created_at', 'updated_at', 'name', 'status', 'frequency'];

const normalizeScheduleInput = (input = {}, current = {}) => {
  const frequency = safeUpper(input.frequency) || current.frequency || REPORT_SCHEDULE_FREQUENCIES[0];
  const time_of_day = normalizeString(input.time_of_day) || current.time_of_day || '08:00';

  const schedule = {
    ...current,
    ...input,
    frequency,
    time_of_day,
    timezone: normalizeString(input.timezone) || current.timezone || 'UTC',
    day_of_week:
      input.day_of_week !== undefined
        ? input.day_of_week === null
          ? null
          : Number(input.day_of_week)
        : current.day_of_week ?? null,
    day_of_month:
      input.day_of_month !== undefined
        ? input.day_of_month === null
          ? null
          : Number(input.day_of_month)
        : current.day_of_month ?? null,
  };

  if (frequency === 'WEEKLY' && (schedule.day_of_week === null || schedule.day_of_week === undefined)) {
    schedule.day_of_week = 1;
  }
  if (frequency === 'MONTHLY' && (schedule.day_of_month === null || schedule.day_of_month === undefined)) {
    schedule.day_of_month = 1;
  }

  return schedule;
};

const assertScopedSchedule = async (id, user = {}) => {
  const scoped = await resolveScopedContext({}, user);
  const record = await reportScheduleRepository.findById(id);
  if (!record || record.tenant_id !== scoped.tenant_id) {
    throw new HttpError('errors.report_schedule.not_found', 404);
  }
  return record;
};

const listReportSchedules = async (filters = {}, page = 1, limit = 20, sortBy, order, user = {}) => {
  const scoped = await resolveScopeIdsForList({ filters, user });
  const where = {
    tenant_id: scoped.tenant_id,
    ...buildSinceFilter(filters.since),
    ...buildSearchWhere(filters.search, ['name']),
  };

  if (scoped.facility_id) where.facility_id = scoped.facility_id;
  if (normalizeString(filters.facility_id) && !scoped.facility_id) where.facility_id = '__none__';
  if (scoped.report_definition_id) where.report_definition_id = scoped.report_definition_id;
  if (normalizeString(filters.report_definition_id) && !scoped.report_definition_id) where.report_definition_id = '__none__';
  if (normalizeString(filters.status)) where.status = safeUpper(filters.status);
  if (normalizeString(filters.frequency)) where.frequency = safeUpper(filters.frequency);

  const skip = (page - 1) * limit;
  const orderBy = buildSort(sortBy, order, 'next_run_at', SORT_FIELDS);
  const [records, total] = await Promise.all([
    reportScheduleRepository.findMany({ where, skip, take: limit, orderBy }),
    reportScheduleRepository.count(where),
  ]);

  return {
    reportSchedules: records.map(serializeReportSchedule),
    pagination: buildPagination(page, limit, total),
  };
};

const getReportScheduleById = async (id, user = {}) => serializeReportSchedule(await assertScopedSchedule(id, user));

const createReportSchedule = async (data, context = {}) => {
  const scoped = await resolveScopedContext(data, context.user || {});
  const scheduleInput = normalizeScheduleInput(data);

  const payload = {
    tenant_id: scoped.tenant_id,
    facility_id: await resolvePayloadIdentifier({
      value: data.facility_id ?? scoped.facility_id,
      model: 'facility',
      field: 'facility_id',
      tenant_id: scoped.tenant_id,
      nullable: true,
    }),
    report_definition_id: await resolvePayloadIdentifier({
      value: data.report_definition_id,
      model: 'report_definition',
      field: 'report_definition_id',
      tenant_id: scoped.tenant_id,
    }),
    created_by: context.user_id || null,
    name: normalizeString(data.name),
    status: safeUpper(data.status) || REPORT_SCHEDULE_STATUSES[0],
    frequency: scheduleInput.frequency,
    time_of_day: scheduleInput.time_of_day,
    day_of_week: scheduleInput.day_of_week,
    day_of_month: scheduleInput.day_of_month,
    timezone: scheduleInput.timezone,
    format: safeUpper(data.format) || REPORT_FORMATS[0],
    parameter_overrides_json: data.parameter_overrides_json || null,
    retention_days: data.retention_days || REPORT_DEFAULT_RETENTION_DAYS,
  };
  payload.next_run_at = getNextScheduledTime(payload, new Date());

  const record = await reportScheduleRepository.create(payload);
  await createAuditLog({
    tenant_id: payload.tenant_id,
    facility_id: payload.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'report_schedule',
    entity_id: record.id,
    diff: { after: serializeReportSchedule(record) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeReportSchedule(record);
};

const updateReportSchedule = async (id, data, context = {}) => {
  const current = await assertScopedSchedule(id, context.user || {});
  ensureVersionMatch({
    current,
    expectedVersion: data.version,
    serializer: serializeReportSchedule,
  });

  const scheduleInput = normalizeScheduleInput(data, current);
  const updateData = {
    version: Number(current.version || 1) + 1,
  };

  if (data.facility_id !== undefined) {
    updateData.facility_id = await resolvePayloadIdentifier({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      tenant_id: current.tenant_id,
      nullable: true,
    });
  }
  if (data.report_definition_id !== undefined) {
    updateData.report_definition_id = await resolvePayloadIdentifier({
      value: data.report_definition_id,
      model: 'report_definition',
      field: 'report_definition_id',
      tenant_id: current.tenant_id,
    });
  }
  if (data.name !== undefined) updateData.name = normalizeString(data.name);
  if (data.status !== undefined) updateData.status = safeUpper(data.status);
  if (data.frequency !== undefined) updateData.frequency = scheduleInput.frequency;
  if (data.time_of_day !== undefined) updateData.time_of_day = scheduleInput.time_of_day;
  if (data.day_of_week !== undefined) updateData.day_of_week = scheduleInput.day_of_week;
  if (data.day_of_month !== undefined) updateData.day_of_month = scheduleInput.day_of_month;
  if (data.timezone !== undefined) updateData.timezone = scheduleInput.timezone;
  if (data.format !== undefined) updateData.format = safeUpper(data.format);
  if (data.parameter_overrides_json !== undefined) updateData.parameter_overrides_json = data.parameter_overrides_json || null;
  if (data.retention_days !== undefined) updateData.retention_days = Number(data.retention_days || REPORT_DEFAULT_RETENTION_DAYS);
  updateData.next_run_at = getNextScheduledTime(
    {
      ...current,
      ...updateData,
      ...scheduleInput,
    },
    new Date()
  );

  const record = await reportScheduleRepository.update(id, updateData);
  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'report_schedule',
    entity_id: current.id,
    diff: createAuditDiff(current, record, [
      'facility_id',
      'report_definition_id',
      'name',
      'status',
      'frequency',
      'time_of_day',
      'day_of_week',
      'day_of_month',
      'timezone',
      'format',
      'retention_days',
      'next_run_at',
      'version',
    ]),
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeReportSchedule(record);
};

const setScheduleStatus = async (id, status, context = {}) => {
  const current = await assertScopedSchedule(id, context.user || {});
  const record = await reportScheduleRepository.update(id, {
    status,
    version: Number(current.version || 1) + 1,
    next_run_at:
      status === REPORT_SCHEDULE_STATUSES[0]
        ? getNextScheduledTime(current, new Date())
        : current.next_run_at,
  });

  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: current.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'report_schedule',
    entity_id: current.id,
    diff: createAuditDiff(current, record, ['status', 'next_run_at', 'version']),
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeReportSchedule(record);
};

const pauseReportSchedule = async (id, context = {}) =>
  setScheduleStatus(id, REPORT_SCHEDULE_STATUSES[1], context);

const resumeReportSchedule = async (id, context = {}) =>
  setScheduleStatus(id, REPORT_SCHEDULE_STATUSES[0], context);

const deleteReportSchedule = async (id, context = {}) => {
  const current = await assertScopedSchedule(id, context.user || {});
  await reportScheduleRepository.softDelete(id);
  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: current.facility_id,
    user_id: context.user_id,
    action: 'DELETE',
    entity: 'report_schedule',
    entity_id: current.id,
    diff: { before: serializeReportSchedule(current) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });
};

module.exports = {
  createReportSchedule,
  deleteReportSchedule,
  getReportScheduleById,
  listReportSchedules,
  pauseReportSchedule,
  resumeReportSchedule,
  updateReportSchedule,
};
