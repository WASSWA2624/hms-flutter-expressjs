/**
 * Therapy flow service
 */

const prisma = require('@prisma/client');
const therapyFlowRepository = require('@repositories/therapy-flow/therapy-flow.repository');
const { HttpError } = require('@lib/errors');
const { createAuditLog } = require('@lib/audit');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const { emitBroadcast } = require('@lib/websocket');
const {
  applyClinicalRequestBilling,
  extractStoredClinicalBilling,
  mapClinicalOrderBillingFields,
} = require('@lib/billing/clinical-request-billing');

const THERAPY_EVENTS = Object.freeze({
  THERAPY_FLOW_UPDATED: 'therapy.flow.updated',
});

const TERMINAL_STATUSES = new Set(['COMPLETED', 'CLOSED']);

const NEXT_STEP_BY_STATUS = Object.freeze({
  REFERRAL: 'Accept referral and schedule initial assessment.',
  ACCEPTED: 'Record initial assessment and treatment plan.',
  ASSESSMENT: 'Finalize plan and schedule sessions.',
  ACTIVE_PLAN: 'Schedule or deliver treatment sessions.',
  SESSION_SCHEDULED: 'Deliver session and record attendance.',
  FOLLOW_UP_DUE: 'Complete follow-up review.',
  MISSED: 'Reschedule missed session or update plan.',
  COMPLETED: 'Therapy episode completed.',
  CLOSED: 'Therapy episode closed.',
});

const sanitize = (value) => String(value || '').trim();
const toUpper = (value) => sanitize(value).toUpperCase();
const toDate = (value, fallback = new Date()) => {
  if (!value) return fallback;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? fallback : parsed;
};

const startOfDay = (date) => {
  const value = new Date(date);
  value.setHours(0, 0, 0, 0);
  return value;
};

const endOfDay = (date) => {
  const value = new Date(date);
  value.setHours(23, 59, 59, 999);
  return value;
};

const toPublicScalarIdentifier = (value) => {
  const normalized = sanitize(value);
  if (!normalized || isUuidLike(normalized)) return null;
  return normalized;
};

const resolvePublicIdentifier = (record) => {
  if (!record) return null;
  if (typeof record === 'string') return toPublicScalarIdentifier(record);
  return (
    toPublicScalarIdentifier(record.human_friendly_id) ||
    toPublicScalarIdentifier(record.id) ||
    null
  );
};

const resolveUserDisplayName = (user) => {
  const profile = user?.profile || null;
  const fullName = [
    sanitize(profile?.first_name),
    sanitize(profile?.middle_name),
    sanitize(profile?.last_name),
  ]
    .filter(Boolean)
    .join(' ')
    .trim();
  return fullName || sanitize(user?.email) || null;
};

const resolvePatientDisplayName = (patient) => {
  const fullName = [sanitize(patient?.first_name), sanitize(patient?.last_name)]
    .filter(Boolean)
    .join(' ')
    .trim();
  return fullName || null;
};

const resolvePatientPhone = (patient) => {
  const contact = Array.isArray(patient?.contacts) ? patient.contacts[0] : null;
  return sanitize(contact?.value) || null;
};

const resolveByIdentifier = async (
  delegate,
  identifier,
  where = {},
  queryOptions = { select: { id: true } }
) => {
  const normalized = sanitize(identifier);
  if (!normalized || !delegate?.findFirst) return null;

  const baseWhere = { deleted_at: null, ...where };
  if (isUuidLike(normalized)) {
    const byUuid = await delegate.findFirst({
      where: { ...baseWhere, id: normalized.toLowerCase() },
      ...queryOptions,
    });
    if (byUuid) return byUuid;
  }

  return delegate.findFirst({
    where: { ...baseWhere, human_friendly_id: normalized.toUpperCase() },
    ...queryOptions,
  });
};

const resolveEpisodeByIdentifier = (tx, identifier) =>
  resolveByIdentifier(tx.therapy_episode, identifier, {}, { id: true, therapy_status: true });

const resolveEncounterByIdentifier = (tx, identifier) =>
  resolveByIdentifier(
    tx.encounter,
    identifier,
    {},
    {
      id: true,
      tenant_id: true,
      facility_id: true,
      patient_id: true,
      encounter_type: true,
      human_friendly_id: true,
      admissions: {
        where: { deleted_at: null, status: 'ADMITTED' },
        orderBy: { admitted_at: 'desc' },
        take: 1,
        select: { id: true, human_friendly_id: true },
      },
    }
  );

const resolveUserByIdentifier = (tx, identifier, tenantId = null) =>
  resolveByIdentifier(
    tx.user,
    identifier,
    tenantId ? { tenant_id: tenantId } : {},
    { id: true }
  );

const buildEmptyListResult = (page, limit) => ({
  items: [],
  pagination: { page, limit, total: 0, total_pages: 0 },
});

const getTimeline = (episode) => {
  const extension = episode?.extension_json || {};
  return Array.isArray(extension.timeline) ? extension.timeline : [];
};

const appendTimelineEvent = (episode, action, context = {}, details = {}) => {
  const extension = { ...(episode.extension_json || {}) };
  const timeline = Array.isArray(extension.timeline) ? [...extension.timeline] : [];
  timeline.unshift({
    action,
    occurred_at: new Date().toISOString(),
    user_id: context.user_id || null,
    details,
  });
  extension.timeline = timeline.slice(0, 200);
  return extension;
};

const resolveLatestSession = (episode) => {
  const sessions = Array.isArray(episode?.sessions) ? episode.sessions : [];
  return sessions.find((session) => !session.deleted_at) || sessions[0] || null;
};

const resolveNextSession = (episode, now = new Date()) => {
  const sessions = (episode?.sessions || []).filter((session) => !session.deleted_at);
  const upcoming = sessions
    .filter(
      (session) =>
        ['SCHEDULED', 'RESCHEDULED'].includes(toUpper(session.attendance_status)) &&
        new Date(session.scheduled_start_at) >= startOfDay(now)
    )
    .sort((a, b) => new Date(a.scheduled_start_at) - new Date(b.scheduled_start_at));
  return upcoming[0] || resolveLatestSession(episode);
};

const deriveBillingStatus = (episode) => {
  const stored = sanitize(episode?.billing_status);
  if (stored) return stored;
  const billing = extractStoredClinicalBilling(episode?.billing_snapshot);
  if (billing?.payment_status) return toUpper(billing.payment_status);
  return 'NOT_BILLED';
};

const mapSessionPublic = (session) => {
  if (!session) return null;
  return {
    id: resolvePublicIdentifier(session),
    session_id: session.id,
    therapist_user_id: resolvePublicIdentifier(session.therapist),
    therapist_name: resolveUserDisplayName(session.therapist),
    scheduled_start_at: session.scheduled_start_at,
    scheduled_end_at: session.scheduled_end_at,
    location: session.location,
    attendance_status: session.attendance_status,
    session_note: session.session_note,
    attended_at: session.attended_at,
    billing: extractStoredClinicalBilling(session.billing_snapshot),
  };
};

const mapTherapyWorkItem = (episode) => {
  const encounter = episode.encounter || {};
  const patient = encounter.patient || {};
  const nextSession = resolveNextSession(episode);
  const latestSession = resolveLatestSession(episode);
  const sessionRef = nextSession || latestSession;
  const admission = episode.admission || null;
  const bedAssignment = admission?.bed_assignments?.[0] || null;
  const wardName = bedAssignment?.bed?.ward?.name || null;
  const bedLabel = bedAssignment?.bed?.label || null;

  return {
    id: resolvePublicIdentifier(episode),
    episode_id: episode.id,
    encounter_id: resolvePublicIdentifier(encounter) || encounter.id,
    encounter_public_id: resolvePublicIdentifier(encounter),
    patient_id: resolvePublicIdentifier(patient) || patient.id,
    patient_public_id: resolvePublicIdentifier(patient),
    patient_display_name: resolvePatientDisplayName(patient),
    patient_phone: resolvePatientPhone(patient),
    patient_gender: patient.gender || null,
    encounter_type: encounter.encounter_type || null,
    source: episode.source_kind || 'REFERRAL',
    source_id: resolvePublicIdentifier(episode.source_id) || episode.source_id || null,
    source_title:
      episode.source_title ||
      (wardName ? `${wardName}${bedLabel ? ` / ${bedLabel}` : ''}` : null),
    referral_reason: episode.referral_reason || episode.referral?.reason || null,
    therapy_status: episode.therapy_status,
    status: episode.therapy_status,
    next_step: episode.next_step || NEXT_STEP_BY_STATUS[episode.therapy_status] || null,
    attendance_status: sessionRef?.attendance_status || null,
    billing_status: deriveBillingStatus(episode),
    therapist_user_id: resolvePublicIdentifier(episode.therapist),
    therapist_name: resolveUserDisplayName(episode.therapist),
    appointment_id: resolvePublicIdentifier(sessionRef),
    appointment_api_id: sessionRef?.id || null,
    session_at: sessionRef?.scheduled_start_at || null,
    last_activity_at: episode.updated_at,
    plan: episode.plan_summary,
    goals: episode.goals,
    instructions: episode.instructions,
    admission_id: resolvePublicIdentifier(admission),
  };
};

const mapTherapyDetail = (episode, options = {}) => {
  const workItem = mapTherapyWorkItem(episode);
  const extension = episode.extension_json || {};
  const progressNotes = Array.isArray(extension.progress_notes)
    ? extension.progress_notes
    : [];
  const followUps = Array.isArray(extension.follow_ups) ? extension.follow_ups : [];

  return {
    ...workItem,
    contraindications: episode.contraindications,
    session_frequency: episode.session_frequency,
    plan_started_at: episode.plan_started_at,
    plan_ends_at: episode.plan_ends_at,
    outcome_summary: episode.outcome_summary,
    accepted_at: episode.accepted_at,
    assessed_at: episode.assessed_at,
    closed_at: episode.closed_at,
    billing: extractStoredClinicalBilling(episode.billing_snapshot),
    sessions: (episode.sessions || []).map(mapSessionPublic).filter(Boolean),
    progress_notes: progressNotes,
    follow_ups: followUps,
    timeline: options.include_timeline ? getTimeline(episode) : undefined,
    source_context: {
      encounter_id: workItem.encounter_id,
      admission_id: workItem.admission_id,
      referral_id: resolvePublicIdentifier(episode.referral),
    },
  };
};

const applyQueueScopeFilter = (where, queueScope, now = new Date()) => {
  const scope = toUpper(queueScope) || 'ALL';
  switch (scope) {
    case 'REFERRAL':
      where.therapy_status = { in: ['REFERRAL', 'ACCEPTED', 'ASSESSMENT'] };
      break;
    case 'TODAY': {
      const dayStart = startOfDay(now);
      const dayEnd = endOfDay(now);
      where.sessions = {
        some: {
          deleted_at: null,
          scheduled_start_at: { gte: dayStart, lte: dayEnd },
        },
      };
      where.therapy_status = { notIn: ['COMPLETED', 'CLOSED'] };
      break;
    }
    case 'MISSED':
      where.OR = [
        { therapy_status: 'MISSED' },
        {
          sessions: {
            some: {
              deleted_at: null,
              attendance_status: 'NO_SHOW',
            },
          },
        },
        {
          sessions: {
            some: {
              deleted_at: null,
              attendance_status: 'SCHEDULED',
              scheduled_start_at: { lt: startOfDay(now) },
            },
          },
        },
      ];
      break;
    case 'ACTIVE_PLAN':
      where.therapy_status = {
        in: ['ACTIVE_PLAN', 'SESSION_SCHEDULED'],
      };
      break;
    case 'FOLLOW_UP_DUE':
      where.therapy_status = 'FOLLOW_UP_DUE';
      break;
    case 'COMPLETED':
      where.therapy_status = { in: ['COMPLETED', 'CLOSED'] };
      break;
    default:
      break;
  }
  return where;
};

const ensureEpisodeMutable = (episode) => {
  if (!episode) throw new HttpError('errors.therapy_flow.not_found', 404);
  if (TERMINAL_STATUSES.has(episode.therapy_status)) {
    throw new HttpError('errors.therapy_flow.episode_terminal', 400);
  }
};

const publishTherapyRefresh = async (episode, context = {}) => {
  const tenantId = episode?.encounter?.tenant_id;
  if (!tenantId) return;
  emitBroadcast(THERAPY_EVENTS.THERAPY_FLOW_UPDATED, {
    tenant_id: tenantId,
    facility_id: episode?.encounter?.facility_id || null,
    episode_id: episode.id,
    encounter_id: episode.encounter_id,
    therapy_status: episode.therapy_status,
    updated_by: context.user_id || null,
  });
};

const applySessionBilling = async (tx, { billing, episode, sessionId, existingSnapshot, context }) => {
  if (!billing) return { billingSnapshot: null, billingStatus: null };
  const snapshot = await applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    tenantId: episode.encounter?.tenant_id,
    facilityId: episode.encounter?.facility_id,
    patientId: episode.encounter?.patient_id,
    encounterId: episode.encounter_id,
    actorUserId: context.user_id,
    sourceModule: 'THERAPY',
    sourceId: sessionId,
    mutableUpdate: Boolean(existingSnapshot),
    description: 'Physiotherapy session',
  });
  if (sessionId && snapshot) {
    await tx.therapy_session.update({
      where: { id: sessionId },
      data: { billing_snapshot: snapshot },
    });
  }
  const billingFields = mapClinicalOrderBillingFields({ billing_snapshot: snapshot });
  return {
    billingSnapshot: snapshot,
    billingStatus: billingFields?.billing_status || null,
  };
};

const reloadEpisode = async (episodeId) =>
  therapyFlowRepository.findById(episodeId);

const createTherapyReferralInternal = async (tx, data, context = {}) => {
  const encounter = await resolveEncounterByIdentifier(tx, data.encounter_id);
  if (!encounter) throw new HttpError('errors.therapy_flow.encounter_not_found', 404);

  const existing = await tx.therapy_episode.findFirst({
    where: {
      encounter_id: encounter.id,
      deleted_at: null,
      therapy_status: { notIn: ['COMPLETED', 'CLOSED'] },
    },
    orderBy: { created_at: 'desc' },
  });
  if (existing) return existing;

  let admissionId = null;
  if (data.admission_id) {
    const admission = await resolveByIdentifier(
      tx.admission,
      data.admission_id,
      { encounter_id: encounter.id },
      { id: true }
    );
    admissionId = admission?.id || null;
  } else if (encounter.admissions?.[0]?.id) {
    admissionId = encounter.admissions[0].id;
  }

  let referralId = null;
  if (data.referral_id) {
    const referral = await resolveByIdentifier(
      tx.referral,
      data.referral_id,
      { encounter_id: encounter.id },
      { id: true }
    );
    referralId = referral?.id || null;
  }

  let therapistUserId = null;
  if (data.therapist_user_id) {
    const therapist = await resolveUserByIdentifier(
      tx,
      data.therapist_user_id,
      encounter.tenant_id
    );
    therapistUserId = therapist?.id || null;
  }

  const sourceKind =
    toUpper(data.source_kind) ||
    (admissionId ? 'IPD' : encounter.encounter_type === 'EMERGENCY' ? 'EMERGENCY' : 'OPD');

  const extension = appendTimelineEvent(
    { extension_json: {} },
    'REFERRAL_CREATED',
    context,
    {
      source_kind: sourceKind,
      referral_reason: sanitize(data.referral_reason) || sanitize(data.clinical_indication),
    }
  );

  return tx.therapy_episode.create({
    data: {
      encounter_id: encounter.id,
      admission_id: admissionId,
      referral_id: referralId,
      source_kind: sourceKind,
      source_id: data.source_id || admissionId || encounter.id,
      source_title:
        sanitize(data.source_title) ||
        (sourceKind === 'IPD' ? 'Inpatient admission' : 'Outpatient visit'),
      referral_reason:
        sanitize(data.referral_reason) ||
        sanitize(data.clinical_indication) ||
        sanitize(data.notes) ||
        null,
      therapist_user_id: therapistUserId,
      therapy_status: 'REFERRAL',
      next_step: NEXT_STEP_BY_STATUS.REFERRAL,
      extension_json: extension,
    },
  });
};

const listTherapyFlows = async (
  filters = {},
  page = 1,
  limit = 20,
  sortBy = 'updated_at',
  order = 'desc'
) => {
  const skip = (page - 1) * limit;
  const orderBy = sortBy ? { [sortBy]: order } : { updated_at: 'desc' };
  const where = {};

  applyQueueScopeFilter(where, filters.queue_scope);

  if (filters.therapy_status) where.therapy_status = toUpper(filters.therapy_status);
  if (filters.source_kind) where.source_kind = toUpper(filters.source_kind);

  const tenant = filters.tenant_id
    ? await resolveByIdentifier(prisma.tenant, filters.tenant_id, {}, { id: true })
    : null;
  if (filters.tenant_id && !tenant) return buildEmptyListResult(page, limit);

  const facility = filters.facility_id
    ? await resolveByIdentifier(
        prisma.facility,
        filters.facility_id,
        tenant ? { tenant_id: tenant.id } : {},
        { id: true }
      )
    : null;
  if (filters.facility_id && !facility) return buildEmptyListResult(page, limit);

  const encounterFilter = {};
  if (tenant?.id) encounterFilter.tenant_id = tenant.id;
  if (facility?.id) encounterFilter.facility_id = facility.id;

  if (filters.patient_id) {
    const patient = await resolveByIdentifier(
      prisma.patient,
      filters.patient_id,
      tenant ? { tenant_id: tenant.id } : {},
      { id: true }
    );
    if (!patient) return buildEmptyListResult(page, limit);
    encounterFilter.patient_id = patient.id;
  }

  if (filters.encounter_id) {
    const encounter = await resolveEncounterByIdentifier(prisma, filters.encounter_id);
    if (!encounter) return buildEmptyListResult(page, limit);
    where.encounter_id = encounter.id;
  }

  if (Object.keys(encounterFilter).length > 0) {
    where.encounter = encounterFilter;
  }

  if (filters.therapist_id) {
    const therapist = await resolveUserByIdentifier(
      prisma,
      filters.therapist_id,
      tenant?.id || null
    );
    if (!therapist) return buildEmptyListResult(page, limit);
    where.therapist_user_id = therapist.id;
  }

  if (filters.scheduled_from || filters.scheduled_to) {
    where.sessions = {
      some: {
        deleted_at: null,
        scheduled_start_at: {
          ...(filters.scheduled_from ? { gte: toDate(filters.scheduled_from) } : {}),
          ...(filters.scheduled_to ? { lte: toDate(filters.scheduled_to) } : {}),
        },
      },
    };
  }

  if (filters.search) {
    const upperSearch = sanitize(filters.search).toUpperCase();
    where.OR = [
      { human_friendly_id: { contains: upperSearch } },
      { referral_reason: { contains: filters.search } },
      { plan_summary: { contains: filters.search } },
      {
        encounter: {
          ...encounterFilter,
          OR: [
            { human_friendly_id: { contains: upperSearch } },
            {
              patient: {
                OR: [
                  { human_friendly_id: { contains: upperSearch } },
                  { first_name: { contains: filters.search } },
                  { last_name: { contains: filters.search } },
                ],
              },
            },
          ],
        },
      },
    ];
  }

  const [items, total] = await Promise.all([
    therapyFlowRepository.findMany(where, skip, limit, orderBy),
    therapyFlowRepository.count(where),
  ]);

  return {
    items: items.map(mapTherapyWorkItem),
    pagination: {
      page,
      limit,
      total,
      total_pages: Math.ceil(total / limit) || 0,
    },
  };
};

const getTherapyFlowById = async (id, options = {}) => {
  const resolved = await resolveByIdentifier(prisma.therapy_episode, id, {}, { id: true });
  if (!resolved) throw new HttpError('errors.therapy_flow.not_found', 404);
  const full = await therapyFlowRepository.findById(resolved.id);
  return mapTherapyDetail(full, {
    include_timeline: ['true', '1', true].includes(options.include_timeline),
  });
};

const createTherapyReferral = async (data, context = {}) => {
  const episode = await prisma.$transaction((tx) =>
    createTherapyReferralInternal(tx, data, context)
  );

  createAuditLog({
    tenant_id: context.tenant_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'therapy_episode',
    entity_id: episode.id,
    diff: { after: episode },
    ip_address: context.ip_address,
  }).catch(() => {});

  const snapshot = await reloadEpisode(episode.id);
  await publishTherapyRefresh(snapshot, context);
  return mapTherapyDetail(snapshot, { include_timeline: true });
};

const acceptReferral = async (id, data, context = {}) => {
  const updated = await prisma.$transaction(async (tx) => {
    const resolved = await resolveEpisodeByIdentifier(tx, id);
    if (!resolved) throw new HttpError('errors.therapy_flow.not_found', 404);
    ensureEpisodeMutable(resolved);
    if (resolved.therapy_status !== 'REFERRAL') {
      throw new HttpError('errors.therapy_flow.invalid_status_transition', 400);
    }

    let therapistUserId = resolved.therapist_user_id;
    if (data.therapist_user_id) {
      const therapist = await resolveUserByIdentifier(
        tx,
        data.therapist_user_id,
        context.tenant_id
      );
      therapistUserId = therapist?.id || therapistUserId;
    }

    const extension = appendTimelineEvent(resolved, 'REFERRAL_ACCEPTED', context, {
      note: sanitize(data.note),
    });

    return tx.therapy_episode.update({
      where: { id: resolved.id },
      data: {
        therapy_status: 'ACCEPTED',
        next_step: NEXT_STEP_BY_STATUS.ACCEPTED,
        therapist_user_id: therapistUserId,
        accepted_at: new Date(),
        extension_json: extension,
      },
    });
  });

  const snapshot = await reloadEpisode(updated.id);
  await publishTherapyRefresh(snapshot, context);
  return mapTherapyDetail(snapshot, { include_timeline: true });
};

const recordAssessment = async (id, data, context = {}) => {
  const updated = await prisma.$transaction(async (tx) => {
    const resolved = await resolveEpisodeByIdentifier(tx, id);
    if (!resolved) throw new HttpError('errors.therapy_flow.not_found', 404);
    ensureEpisodeMutable(resolved);

    const extension = appendTimelineEvent(resolved, 'ASSESSMENT_RECORDED', context, {
      assessment: sanitize(data.assessment),
    });
    extension.assessment_text = sanitize(data.assessment);

    return tx.therapy_episode.update({
      where: { id: resolved.id },
      data: {
        therapy_status: data.plan ? 'ACTIVE_PLAN' : 'ASSESSMENT',
        next_step: data.plan
          ? NEXT_STEP_BY_STATUS.ACTIVE_PLAN
          : NEXT_STEP_BY_STATUS.ASSESSMENT,
        plan_summary: sanitize(data.plan) || null,
        goals: sanitize(data.goals) || null,
        instructions: sanitize(data.instructions) || null,
        contraindications: sanitize(data.contraindications) || null,
        session_frequency: sanitize(data.session_frequency) || null,
        assessed_at: new Date(),
        extension_json: extension,
      },
    });
  });

  const snapshot = await reloadEpisode(updated.id);
  await publishTherapyRefresh(snapshot, context);
  return mapTherapyDetail(snapshot, { include_timeline: true });
};

const scheduleSession = async (id, data, context = {}) => {
  const updated = await prisma.$transaction(async (tx) => {
    const episode = await therapyFlowRepository.findById(
      (await resolveEpisodeByIdentifier(tx, id))?.id
    );
    if (!episode) throw new HttpError('errors.therapy_flow.not_found', 404);
    ensureEpisodeMutable(episode);

    let therapistUserId = episode.therapist_user_id;
    if (data.therapist_user_id) {
      const therapist = await resolveUserByIdentifier(
        tx,
        data.therapist_user_id,
        context.tenant_id
      );
      therapistUserId = therapist?.id || therapistUserId;
    }

    let billingSnapshot = null;
    let billingStatus = episode.billing_status;
    if (data.billing) {
      const billingResult = await applySessionBilling(tx, {
        billing: data.billing,
        episode,
        sessionId: null,
        existingSnapshot: episode.billing_snapshot,
        context,
      });
      billingSnapshot = billingResult.billingSnapshot;
      billingStatus = billingResult.billingStatus || billingStatus;
    }

    const session = await tx.therapy_session.create({
      data: {
        therapy_episode_id: episode.id,
        therapist_user_id: therapistUserId,
        scheduled_start_at: toDate(data.scheduled_start_at),
        scheduled_end_at: data.scheduled_end_at ? toDate(data.scheduled_end_at) : null,
        location: sanitize(data.location) || null,
        attendance_status: 'SCHEDULED',
        session_note: sanitize(data.reason) || null,
        billing_snapshot: billingSnapshot,
      },
    });

    const extension = appendTimelineEvent(episode, 'SESSION_SCHEDULED', context, {
      session_id: session.id,
    });

    return tx.therapy_episode.update({
      where: { id: episode.id },
      data: {
        therapy_status: 'SESSION_SCHEDULED',
        next_step: NEXT_STEP_BY_STATUS.SESSION_SCHEDULED,
        therapist_user_id: therapistUserId,
        billing_status: billingStatus,
        billing_snapshot: billingSnapshot || episode.billing_snapshot,
        extension_json: extension,
      },
    });
  });

  const snapshot = await reloadEpisode(updated.id);
  await publishTherapyRefresh(snapshot, context);
  return mapTherapyDetail(snapshot, { include_timeline: true });
};

const recordSession = async (id, data, context = {}) => {
  const updated = await prisma.$transaction(async (tx) => {
    const episode = await therapyFlowRepository.findById(
      (await resolveEpisodeByIdentifier(tx, id))?.id
    );
    if (!episode) throw new HttpError('errors.therapy_flow.not_found', 404);
    ensureEpisodeMutable(episode);

    let session = null;
    if (data.session_id) {
      session = await resolveByIdentifier(
        tx.therapy_session,
        data.session_id,
        { therapy_episode_id: episode.id },
        { id: true }
      );
    }
    if (!session) {
      session = resolveLatestSession(episode);
    }
    if (!session) throw new HttpError('errors.therapy_flow.session_not_found', 404);

    let billingSnapshot = null;
    if (data.billing) {
      const billingResult = await applySessionBilling(tx, {
        billing: data.billing,
        episode,
        sessionId: session.id,
        existingSnapshot: session.billing_snapshot,
        context,
      });
      billingSnapshot = billingResult.billingSnapshot;
    }

    const attendance = toUpper(data.attendance_status) || 'ATTENDED';
    await tx.therapy_session.update({
      where: { id: session.id },
      data: {
        session_note: sanitize(data.note),
        attendance_status: attendance,
        attended_at: attendance === 'ATTENDED' ? new Date() : null,
        ...(billingSnapshot ? { billing_snapshot: billingSnapshot } : {}),
      },
    });

    const extension = appendTimelineEvent(episode, 'SESSION_RECORDED', context, {
      session_id: session.id,
      attendance_status: attendance,
    });

    return tx.therapy_episode.update({
      where: { id: episode.id },
      data: {
        therapy_status: 'ACTIVE_PLAN',
        next_step: NEXT_STEP_BY_STATUS.ACTIVE_PLAN,
        extension_json: extension,
      },
    });
  });

  const snapshot = await reloadEpisode(updated.id);
  await publishTherapyRefresh(snapshot, context);
  return mapTherapyDetail(snapshot, { include_timeline: true });
};

const markAttendance = async (id, data, context = {}) => {
  const updated = await prisma.$transaction(async (tx) => {
    const episode = await therapyFlowRepository.findById(
      (await resolveEpisodeByIdentifier(tx, id))?.id
    );
    if (!episode) throw new HttpError('errors.therapy_flow.not_found', 404);

    const session = await resolveByIdentifier(
      tx.therapy_session,
      data.session_id,
      { therapy_episode_id: episode.id },
      { id: true }
    );
    if (!session) throw new HttpError('errors.therapy_flow.session_not_found', 404);

    const attendance = toUpper(data.attendance_status);
    await tx.therapy_session.update({
      where: { id: session.id },
      data: {
        attendance_status: attendance,
        session_note: sanitize(data.note) || undefined,
        attended_at: attendance === 'ATTENDED' ? new Date() : null,
      },
    });

    const nextStatus =
      attendance === 'NO_SHOW'
        ? 'MISSED'
        : TERMINAL_STATUSES.has(episode.therapy_status)
          ? episode.therapy_status
          : 'ACTIVE_PLAN';

    const extension = appendTimelineEvent(episode, 'ATTENDANCE_MARKED', context, {
      session_id: session.id,
      attendance_status: attendance,
    });

    return tx.therapy_episode.update({
      where: { id: episode.id },
      data: {
        therapy_status: nextStatus,
        next_step: NEXT_STEP_BY_STATUS[nextStatus],
        extension_json: extension,
      },
    });
  });

  const snapshot = await reloadEpisode(updated.id);
  await publishTherapyRefresh(snapshot, context);
  return mapTherapyDetail(snapshot, { include_timeline: true });
};

const updatePlan = async (id, data, context = {}) => {
  const updated = await prisma.$transaction(async (tx) => {
    const resolved = await resolveEpisodeByIdentifier(tx, id);
    if (!resolved) throw new HttpError('errors.therapy_flow.not_found', 404);
    ensureEpisodeMutable(resolved);
    const episode = await therapyFlowRepository.findById(resolved.id);

    const extension = appendTimelineEvent(episode, 'PLAN_UPDATED', context, {});

    return tx.therapy_episode.update({
      where: { id: episode.id },
      data: {
        therapy_status: 'ACTIVE_PLAN',
        next_step: NEXT_STEP_BY_STATUS.ACTIVE_PLAN,
        plan_summary: sanitize(data.plan),
        goals: sanitize(data.goals) || episode.goals,
        instructions: sanitize(data.instructions) || episode.instructions,
        contraindications: sanitize(data.contraindications) || episode.contraindications,
        session_frequency: sanitize(data.session_frequency) || episode.session_frequency,
        plan_started_at: data.plan_started_at
          ? toDate(data.plan_started_at)
          : episode.plan_started_at || new Date(),
        plan_ends_at: data.plan_ends_at ? toDate(data.plan_ends_at) : episode.plan_ends_at,
        extension_json: extension,
      },
    });
  });

  const snapshot = await reloadEpisode(updated.id);
  await publishTherapyRefresh(snapshot, context);
  return mapTherapyDetail(snapshot, { include_timeline: true });
};

const addProgressNote = async (id, data, context = {}) => {
  const updated = await prisma.$transaction(async (tx) => {
    const episode = await therapyFlowRepository.findById(
      (await resolveEpisodeByIdentifier(tx, id))?.id
    );
    if (!episode) throw new HttpError('errors.therapy_flow.not_found', 404);
    ensureEpisodeMutable(episode);

    const noteRecord = await tx.clinical_note.create({
      data: {
        encounter_id: episode.encounter_id,
        author_user_id: context.user_id,
        note: `Physiotherapy progress note: ${sanitize(data.note)}`,
      },
    });

    const extension = { ...(episode.extension_json || {}) };
    const progressNotes = Array.isArray(extension.progress_notes)
      ? [...extension.progress_notes]
      : [];
    progressNotes.unshift({
      id: noteRecord.id,
      note: sanitize(data.note),
      recorded_at: new Date().toISOString(),
      author_user_id: context.user_id,
    });
    extension.progress_notes = progressNotes.slice(0, 100);
    extension.timeline = appendTimelineEvent(episode, 'PROGRESS_NOTE_ADDED', context, {
      note_id: noteRecord.id,
    }).timeline;

    return tx.therapy_episode.update({
      where: { id: episode.id },
      data: { extension_json: extension },
    });
  });

  const snapshot = await reloadEpisode(updated.id);
  await publishTherapyRefresh(snapshot, context);
  return mapTherapyDetail(snapshot, { include_timeline: true });
};

const scheduleFollowUp = async (id, data, context = {}) => {
  const updated = await prisma.$transaction(async (tx) => {
    const episode = await therapyFlowRepository.findById(
      (await resolveEpisodeByIdentifier(tx, id))?.id
    );
    if (!episode) throw new HttpError('errors.therapy_flow.not_found', 404);
    ensureEpisodeMutable(episode);

    const followUp = await tx.follow_up.create({
      data: {
        encounter_id: episode.encounter_id,
        scheduled_at: toDate(data.scheduled_at),
        status: 'SCHEDULED',
        notes: sanitize(data.notes) || null,
      },
    });

    const extension = { ...(episode.extension_json || {}) };
    const followUps = Array.isArray(extension.follow_ups) ? [...extension.follow_ups] : [];
    followUps.unshift({
      id: followUp.id,
      scheduled_at: followUp.scheduled_at,
      notes: followUp.notes,
      status: followUp.status,
    });
    extension.follow_ups = followUps.slice(0, 50);
    extension.timeline = appendTimelineEvent(episode, 'FOLLOW_UP_SCHEDULED', context, {
      follow_up_id: followUp.id,
    }).timeline;

    return tx.therapy_episode.update({
      where: { id: episode.id },
      data: {
        therapy_status: 'FOLLOW_UP_DUE',
        next_step: NEXT_STEP_BY_STATUS.FOLLOW_UP_DUE,
        extension_json: extension,
      },
    });
  });

  const snapshot = await reloadEpisode(updated.id);
  await publishTherapyRefresh(snapshot, context);
  return mapTherapyDetail(snapshot, { include_timeline: true });
};

const closeEpisode = async (id, data, context = {}) => {
  const updated = await prisma.$transaction(async (tx) => {
    const resolved = await resolveEpisodeByIdentifier(tx, id);
    if (!resolved) throw new HttpError('errors.therapy_flow.not_found', 404);

    const episode = await therapyFlowRepository.findById(resolved.id);
    const extension = appendTimelineEvent(episode, 'EPISODE_CLOSED', context, {
      outcome_summary: sanitize(data.outcome_summary),
    });

    return tx.therapy_episode.update({
      where: { id: episode.id },
      data: {
        therapy_status: 'CLOSED',
        next_step: NEXT_STEP_BY_STATUS.CLOSED,
        outcome_summary: sanitize(data.outcome_summary),
        closed_at: new Date(),
        extension_json: extension,
      },
    });
  });

  const snapshot = await reloadEpisode(updated.id);
  await publishTherapyRefresh(snapshot, context);
  return mapTherapyDetail(snapshot, { include_timeline: true });
};

const requestTherapyFromAdmission = async (admissionId, data, context = {}) => {
  const admission = await resolveByIdentifier(
    prisma.admission,
    admissionId,
    {},
    { id: true, encounter_id: true, human_friendly_id: true }
  );
  if (!admission?.encounter_id) {
    throw new HttpError('errors.therapy_flow.admission_not_found', 404);
  }

  return createTherapyReferral(
    {
      encounter_id: admission.encounter_id,
      admission_id: admission.id,
      source_kind: 'IPD',
      source_id: admission.id,
      source_title: `Admission ${resolvePublicIdentifier(admission) || admission.id}`,
      referral_reason: sanitize(data.clinical_indication),
      clinical_indication: sanitize(data.clinical_indication),
      therapist_user_id: data.therapist_user_id,
      notes: sanitize(data.notes),
    },
    context
  );
};

module.exports = {
  THERAPY_EVENTS,
  listTherapyFlows,
  getTherapyFlowById,
  createTherapyReferral,
  createTherapyReferralInternal,
  acceptReferral,
  recordAssessment,
  scheduleSession,
  recordSession,
  markAttendance,
  updatePlan,
  addProgressNote,
  scheduleFollowUp,
  closeEpisode,
  requestTherapyFromAdmission,
  mapTherapyWorkItem,
  mapTherapyDetail,
};
