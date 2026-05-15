const crypto = require('crypto');
const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { logger } = require('@lib/logging');
const { createStorageService, sanitizeFilename } = require('@lib/storage');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolvePublicIdentifier,
} = require('@lib/billing/identifiers');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');

const WORKSPACE_PAGE_LIMIT = 25;
const DUPLICATE_PATIENT_SCAN_LIMIT = 250;
const DUPLICATE_MIN_SCORE = 45;
const DUPLICATE_REVIEW_SCORE = 55;
const PHI_ACCESS_WINDOW_MS = 15 * 60 * 1000;
const MAX_DOCUMENT_FILES = 5;
const MAX_DOCUMENT_SIZE_BYTES = 10 * 1024 * 1024;
const ACCEPTED_DOCUMENT_MIME_TYPES = new Set([
  'application/pdf',
  'image/jpeg',
  'image/jpg',
  'image/png',
]);
const DOCUMENT_TYPE_OPTIONS = Object.freeze([
  'IDENTITY',
  'INSURANCE',
  'REFERRAL',
  'LAB_RESULT',
  'RADIOLOGY',
  'PRESCRIPTION',
  'CONSENT',
  'DISCHARGE',
  'OTHER',
]);
const CONSENT_TYPE_OPTIONS = Object.freeze([
  'TREATMENT',
  'DATA_SHARING',
  'RESEARCH',
  'BILLING',
  'OTHER',
]);
const CONSENT_STATUS_OPTIONS = Object.freeze(['GRANTED', 'REVOKED', 'PENDING']);
const APPOINTMENT_STATUS_OPTIONS = Object.freeze([
  'SCHEDULED',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'NO_SHOW',
]);

const normalizeText = (value) => String(value || '').trim();
const normalizeLower = (value) => normalizeText(value).toLowerCase();
const normalizeUpper = (value) => normalizeText(value).toUpperCase();
const normalizePhone = (value) => normalizeText(value).replace(/[^\d+]/g, '');
const normalizeDateOnly = (value) => {
  const normalized = normalizeText(value);
  if (!normalized) return '';
  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) return '';
  return parsed.toISOString().slice(0, 10);
};
const toInteger = (value, fallback) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.trunc(parsed));
};
const toNumber = (value) => {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  if (typeof value === 'object' && typeof value.toNumber === 'function') {
    try {
      return value.toNumber();
    } catch {
      return Number(value) || 0;
    }
  }
  return Number(value) || 0;
};
const buildPagination = (page, limit, total) => {
  const totalPages = total > 0 ? Math.ceil(total / limit) : 0;
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};
const buildName = (entity = {}) =>
  `${normalizeText(entity?.first_name || entity?.profile?.first_name)} ${normalizeText(entity?.last_name || entity?.profile?.last_name)}`.trim();
const getPairKey = (leftId, rightId) => {
  const values = [normalizeText(leftId), normalizeText(rightId)].filter(Boolean).sort();
  return values.join(':');
};
const readExtensionJson = (record) =>
  record && typeof record.extension_json === 'object' && record.extension_json
    ? record.extension_json
    : {};

const resolveScopeWhere = async (scope = {}) => {
  const where = {};

  const tenantId = await resolveIdentifierForFilter({
    value: scope.tenant_id,
    model: 'tenant',
  });
  if (scope.tenant_id !== undefined && tenantId === null) {
    return { where: { id: '__none__' }, tenantId: null, facilityId: null };
  }
  if (tenantId) where.tenant_id = tenantId;

  const facilityId = await resolveIdentifierForFilter({
    value: scope.facility_id,
    model: 'facility',
    where: tenantId ? { tenant_id: tenantId } : {},
  });
  if (scope.facility_id !== undefined && facilityId === null) {
    return { where: { id: '__none__' }, tenantId, facilityId: null };
  }
  if (facilityId) where.facility_id = facilityId;

  return { where, tenantId, facilityId };
};

const basePatientInclude = {
  tenant: { select: { id: true, human_friendly_id: true, name: true } },
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  contacts: {
    where: { deleted_at: null },
    orderBy: [{ is_primary: 'desc' }, { updated_at: 'desc' }],
    take: 5,
    select: {
      id: true,
      human_friendly_id: true,
      contact_type: true,
      value: true,
      is_primary: true,
      updated_at: true,
    },
  },
  identifiers: {
    where: { deleted_at: null },
    orderBy: [{ is_primary: 'desc' }, { updated_at: 'desc' }],
    take: 5,
    select: {
      id: true,
      human_friendly_id: true,
      identifier_type: true,
      identifier_value: true,
      is_primary: true,
      updated_at: true,
    },
  },
  guardians: {
    where: { deleted_at: null },
    orderBy: { updated_at: 'desc' },
    take: 5,
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      relationship: true,
      phone: true,
      updated_at: true,
    },
  },
};

const userDisplaySelect = {
  email: true,
  profile: {
    select: {
      first_name: true,
      last_name: true,
    },
  },
};

const resolvePatientRecord = async (patientIdentifier, scope = {}, include = {}) => {
  const { where } = await resolveScopeWhere(scope);
  const patient = await resolveModelRecordByIdentifier({
    model: 'patient',
    identifier: patientIdentifier,
    where: {
      ...where,
      deleted_at: null,
    },
    include: {
      ...basePatientInclude,
      ...(include || {}),
    },
  });

  if (!patient) {
    throw new HttpError('errors.patient.not_found', 404);
  }

  return patient;
};

const resolveDocumentRecord = async (documentIdentifier, patientId) => {
  const record = await resolveModelRecordByIdentifier({
    model: 'patient_document',
    identifier: documentIdentifier,
    where: {
      patient_id: patientId,
      deleted_at: null,
    },
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
      patient_id: true,
      document_type: true,
      storage_key: true,
      file_name: true,
      content_type: true,
      created_at: true,
      updated_at: true,
    },
  });

  if (!record) {
    throw new HttpError('errors.patient_document.not_found', 404);
  }

  return record;
};

const resolvePrimaryContact = (patient) => {
  const contacts = Array.isArray(patient?.contacts) ? patient.contacts : [];
  return contacts.find((entry) => entry?.is_primary) || contacts[0] || null;
};

const serializePatientSummary = (patient) => {
  const primaryContact = resolvePrimaryContact(patient);
  const extension = readExtensionJson(patient);

  return {
    id: patient?.id || null,
    human_friendly_id: resolvePublicIdentifier(patient?.human_friendly_id, patient?.id),
    display_name: buildName(patient) || resolvePublicIdentifier(patient?.human_friendly_id, patient?.id),
    first_name: normalizeText(patient?.first_name) || null,
    last_name: normalizeText(patient?.last_name) || null,
    date_of_birth: patient?.date_of_birth || null,
    gender: patient?.gender || null,
    is_active: patient?.is_active !== false,
    contact_value: normalizeText(primaryContact?.value) || null,
    tenant: patient?.tenant
      ? {
          human_friendly_id: resolvePublicIdentifier(
            patient.tenant?.human_friendly_id,
            patient.tenant?.id
          ),
          label: normalizeText(patient.tenant?.name) || null,
        }
      : null,
    facility: patient?.facility
      ? {
          human_friendly_id: resolvePublicIdentifier(
            patient.facility?.human_friendly_id,
            patient.facility?.id
          ),
          label: normalizeText(patient.facility?.name) || null,
        }
      : null,
    primary_contact: primaryContact
      ? {
          human_friendly_id: resolvePublicIdentifier(
            primaryContact?.human_friendly_id,
            primaryContact?.id
          ),
          contact_type: primaryContact?.contact_type || null,
          value: normalizeText(primaryContact?.value) || null,
        }
      : null,
    flags: {
      merged: Boolean(extension?.merge?.merged_into_patient_id),
    },
    created_at: patient?.created_at || null,
    updated_at: patient?.updated_at || null,
  };
};

const serializeDocument = (record) => ({
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  document_type: normalizeText(record?.document_type) || 'OTHER',
  file_name: normalizeText(record?.file_name) || null,
  content_type: normalizeText(record?.content_type) || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializeConsent = (record) => ({
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  consent_type: record?.consent_type || null,
  status: record?.status || null,
  granted_at: record?.granted_at || null,
  revoked_at: record?.revoked_at || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializeAppointment = (record) => ({
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  status: record?.status || null,
  scheduled_start: record?.scheduled_start || null,
  scheduled_end: record?.scheduled_end || null,
  reason: normalizeText(record?.reason) || null,
  provider_name: buildName(record?.provider) || normalizeText(record?.provider?.email) || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializeVisitQueue = (record) => ({
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  status: record?.status || null,
  queued_at: record?.queued_at || null,
  appointment_id: resolvePublicIdentifier(
    record?.appointment?.human_friendly_id,
    record?.appointment_id
  ),
  provider_name: buildName(record?.provider) || normalizeText(record?.provider?.email) || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializeEncounter = (record) => ({
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  encounter_type: record?.encounter_type || null,
  status: record?.status || null,
  provider_name: buildName(record?.provider) || normalizeText(record?.provider?.email) || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializeAdmission = (record) => ({
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  status: record?.status || null,
  admitted_at: record?.admitted_at || null,
  discharged_at: record?.discharged_at || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializeFollowUp = (record) => ({
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  encounter_id: resolvePublicIdentifier(record?.encounter?.human_friendly_id, record?.encounter_id),
  status: record?.status || null,
  scheduled_at: record?.scheduled_at || null,
  completed_at: record?.completed_at || null,
  notes: normalizeText(record?.notes) || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializeReferral = (record) => ({
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  encounter_id: resolvePublicIdentifier(record?.encounter?.human_friendly_id, record?.encounter_id),
  status: record?.status || null,
  reason: normalizeText(record?.reason) || null,
  from_department: normalizeText(record?.from_department?.name) || null,
  to_department: normalizeText(record?.to_department?.name) || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializeInvoice = (record) => ({
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  status: record?.status || null,
  billing_status: record?.billing_status || null,
  total_amount: toNumber(record?.total_amount),
  currency: normalizeText(record?.currency) || null,
  issued_at: record?.issued_at || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializePayment = (record) => ({
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  invoice_id: resolvePublicIdentifier(record?.invoice?.human_friendly_id, record?.invoice_id),
  status: record?.status || null,
  method: record?.method || null,
  amount: toNumber(record?.amount),
  paid_at: record?.paid_at || null,
  transaction_ref: normalizeText(record?.transaction_ref) || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializePhiAccessLog = (record) => ({
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  accessed_at: record?.accessed_at || null,
  access_scope: record?.access_scope || null,
  reason: normalizeText(record?.reason) || null,
  user_name: buildName(record?.user) || normalizeText(record?.user?.email) || null,
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const buildTimelineItem = (resource, record, dateField, serializer) => ({
  id: `${resource}:${resolvePublicIdentifier(record?.human_friendly_id, record?.id) || crypto.randomUUID()}`,
  resource,
  occurred_at: record?.[dateField] || record?.updated_at || record?.created_at || null,
  created_at: record?.created_at || null,
  summary: serializer(record),
});

const listModelPage = async ({
  delegate,
  where,
  page = 1,
  limit = WORKSPACE_PAGE_LIMIT,
  orderBy = { updated_at: 'desc' },
  include,
  serializer,
}) => {
  const safePage = toInteger(page, 1);
  const safeLimit = toInteger(limit, WORKSPACE_PAGE_LIMIT);
  const skip = (safePage - 1) * safeLimit;
  const [rows, total] = await Promise.all([
    delegate.findMany({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
      skip,
      take: safeLimit,
      orderBy,
      ...(include ? { include } : {}),
    }),
    delegate.count({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
    }),
  ]);

  return {
    items: rows.map((row) => serializer(row)),
    pagination: buildPagination(safePage, safeLimit, total),
  };
};

const cloneOverviewFallback = (fallbackValue) => {
  if (typeof fallbackValue === 'function') return fallbackValue();
  if (Array.isArray(fallbackValue)) return [...fallbackValue];
  if (fallbackValue && typeof fallbackValue === 'object') {
    return { ...fallbackValue };
  }
  return fallbackValue;
};

const runSafeOverviewSection = async (section, scope = {}, fallbackValue, operation) => {
  try {
    return await operation();
  } catch (error) {
    logger.error('Patient workspace overview section failed', {
      section,
      tenant_id: normalizeText(scope?.tenant_id) || null,
      facility_id: normalizeText(scope?.facility_id) || null,
      error: error?.message || 'Unknown error',
    });
    return cloneOverviewFallback(fallbackValue);
  }
};

const runSafePatientWorkspaceSection = async (section, scope = {}, fallbackValue, operation) =>
  runSafeOverviewSection(section, scope, fallbackValue, operation);

const getDismissedPairSet = (patient) => {
  const extension = readExtensionJson(patient);
  const values = Array.isArray(extension?.duplicate_review?.dismissed_pair_keys)
    ? extension.duplicate_review.dismissed_pair_keys
    : [];
  return new Set(values.map((value) => normalizeText(value)).filter(Boolean));
};

const computeDuplicateScore = (target, candidate) => {
  let score = 0;
  const reasons = [];

  const targetDob = normalizeDateOnly(target?.date_of_birth);
  const candidateDob = normalizeDateOnly(candidate?.date_of_birth);
  const targetName = `${normalizeLower(target?.first_name)} ${normalizeLower(target?.last_name)}`.trim();
  const candidateName = `${normalizeLower(candidate?.first_name)} ${normalizeLower(candidate?.last_name)}`.trim();

  const targetIdentifierValues = new Set(
    (target?.identifiers || [])
      .map((entry) => normalizeLower(entry?.identifier_value))
      .filter(Boolean)
  );
  const candidateIdentifierValues = new Set(
    (candidate?.identifiers || [])
      .map((entry) => normalizeLower(entry?.identifier_value))
      .filter(Boolean)
  );
  for (const value of targetIdentifierValues) {
    if (!candidateIdentifierValues.has(value)) continue;
    score += 100;
    reasons.push({ code: 'IDENTIFIER_MATCH', label: value, weight: 100 });
  }

  const targetPhones = new Set(
    (target?.contacts || [])
      .map((entry) => normalizePhone(entry?.value))
      .filter(Boolean)
  );
  const candidatePhones = new Set(
    (candidate?.contacts || [])
      .map((entry) => normalizePhone(entry?.value))
      .filter(Boolean)
  );
  for (const value of targetPhones) {
    if (!candidatePhones.has(value)) continue;
    score += 35;
    reasons.push({ code: 'PHONE_MATCH', label: value, weight: 35 });
  }

  if (targetName && candidateName && targetName === candidateName) {
    score += 30;
    reasons.push({ code: 'NAME_MATCH', label: targetName, weight: 30 });
  }

  if (targetDob && candidateDob && targetDob === candidateDob) {
    score += 25;
    reasons.push({ code: 'DOB_MATCH', label: targetDob, weight: 25 });
  }

  if (normalizeUpper(target?.gender) && normalizeUpper(target?.gender) === normalizeUpper(candidate?.gender)) {
    score += 10;
    reasons.push({ code: 'GENDER_MATCH', label: normalizeUpper(target?.gender), weight: 10 });
  }

  return {
    score,
    reasons,
    classification:
      score >= 100 ? 'STRONG' : score >= DUPLICATE_REVIEW_SCORE ? 'MEDIUM' : score >= DUPLICATE_MIN_SCORE ? 'REVIEW' : 'LOW',
  };
};

const buildDuplicateCandidateEntry = (target, candidate, duplicateState) => {
  const pairKey = getPairKey(target?.id, candidate?.id);
  return {
    review_id: pairKey,
    confidence_score: duplicateState.score,
    classification: duplicateState.classification,
    match_reasons: duplicateState.reasons,
    primary_patient: serializePatientSummary(target),
    secondary_patient: serializePatientSummary(candidate),
  };
};

const findDuplicateCandidatesForTarget = async (target, scope = {}, explicitCandidateLimit = 20) => {
  const { where } = await resolveScopeWhere(scope);
  const dismissedPairSet = getDismissedPairSet(target);
  const candidates = await prisma.patient.findMany({
    where: {
      ...where,
      deleted_at: null,
      id: { not: target.id },
      is_active: true,
    },
    include: basePatientInclude,
    take: Math.max(explicitCandidateLimit * 3, 60),
    orderBy: { updated_at: 'desc' },
  });

  return candidates
    .map((candidate) => ({
      candidate,
      duplicateState: computeDuplicateScore(target, candidate),
    }))
    .filter(({ candidate, duplicateState }) => {
      if (duplicateState.score < DUPLICATE_MIN_SCORE) return false;
      const pairKey = getPairKey(target.id, candidate.id);
      if (dismissedPairSet.has(pairKey)) return false;
      const candidateExtension = readExtensionJson(candidate);
      if (candidateExtension?.merge?.merged_into_patient_id) return false;
      return true;
    })
    .sort((left, right) => right.duplicateState.score - left.duplicateState.score)
    .slice(0, explicitCandidateLimit)
    .map(({ candidate, duplicateState }) =>
      buildDuplicateCandidateEntry(target, candidate, duplicateState)
    );
};

const listGlobalDuplicateCandidates = async (scope = {}, page = 1, limit = WORKSPACE_PAGE_LIMIT) => {
  const { where } = await resolveScopeWhere(scope);
  const safePage = toInteger(page, 1);
  const safeLimit = toInteger(limit, WORKSPACE_PAGE_LIMIT);
  const rows = await prisma.patient.findMany({
    where: {
      ...where,
      deleted_at: null,
      is_active: true,
    },
    include: basePatientInclude,
    take: DUPLICATE_PATIENT_SCAN_LIMIT,
    orderBy: { updated_at: 'desc' },
  });

  const pairs = [];
  for (let index = 0; index < rows.length; index += 1) {
    const target = rows[index];
    const dismissedPairs = getDismissedPairSet(target);
    for (let candidateIndex = index + 1; candidateIndex < rows.length; candidateIndex += 1) {
      const candidate = rows[candidateIndex];
      const pairKey = getPairKey(target.id, candidate.id);
      if (dismissedPairs.has(pairKey) || getDismissedPairSet(candidate).has(pairKey)) continue;
      if (readExtensionJson(target)?.merge?.merged_into_patient_id) continue;
      if (readExtensionJson(candidate)?.merge?.merged_into_patient_id) continue;
      const duplicateState = computeDuplicateScore(target, candidate);
      if (duplicateState.score < DUPLICATE_REVIEW_SCORE) continue;
      pairs.push(buildDuplicateCandidateEntry(target, candidate, duplicateState));
    }
  }

  pairs.sort((left, right) => right.confidence_score - left.confidence_score);
  const start = (safePage - 1) * safeLimit;
  const items = pairs.slice(start, start + safeLimit);

  return {
    items,
    pagination: buildPagination(safePage, safeLimit, pairs.length),
  };
};

const recordPatientPhiAccess = async ({
  userId,
  patient,
  routeFamily,
  ipAddress,
}) => {
  const normalizedUserId = normalizeText(userId);
  if (!normalizedUserId || !patient?.id || !patient?.tenant_id) return;

  try {
    const resolvedUserId = await resolveIdentifierForFilter({
      value: normalizedUserId,
      model: 'user',
      where: {
        tenant_id: patient.tenant_id,
      },
    });
    if (!resolvedUserId) return;

    const dedupeBoundary = new Date(Date.now() - PHI_ACCESS_WINDOW_MS);
    const existing = await prisma.phi_access_log.findFirst({
      where: {
        tenant_id: patient.tenant_id,
        user_id: resolvedUserId,
        patient_id: patient.id,
        access_scope: 'PATIENT',
        deleted_at: null,
        accessed_at: { gte: dedupeBoundary },
        reason: routeFamily,
      },
      select: { id: true },
      orderBy: { accessed_at: 'desc' },
    });

    if (existing?.id) return;

    const created = await prisma.phi_access_log.create({
      data: {
        tenant_id: patient.tenant_id,
        user_id: resolvedUserId,
        patient_id: patient.id,
        access_scope: 'PATIENT',
        reason: routeFamily,
      },
    });

    await createAuditLog({
      tenant_id: patient.tenant_id,
      user_id: resolvedUserId,
      action: 'ACCESS',
      entity: 'phi_access_log',
      entity_id: created.id,
      diff: {
        after: {
          patient_id: patient.id,
          route_family: routeFamily,
        },
      },
      ip_address: ipAddress,
    });
  } catch (error) {
    logger.warn('Patient PHI access log skipped', {
      patient_id: patient.id,
      tenant_id: patient.tenant_id,
      user_id: normalizedUserId,
      route_family: normalizeText(routeFamily) || null,
      error: error?.message || 'Unknown error',
    });
  }
};

const getPatientWorkspaceOverview = async (scope = {}, userContext = {}) => {
  const { where, tenantId, facilityId } = await resolveScopeWhere(scope);
  const now = new Date();
  const emptyOverviewList = () => [];
  const emptyOverviewQueue = () => ({
    items: [],
    pagination: buildPagination(1, 6, 0),
  });

  const [
    totalPatients,
    activePatients,
    waitingQueueCount,
    activeAdmissionsCount,
    unpaidInvoiceCount,
    dueFollowUpCount,
    recentPatients,
    recentQueue,
    recentAdmissions,
    recentInvoices,
  ] = await Promise.all([
    runSafeOverviewSection(
      'metrics.total_patients',
      scope,
      0,
      () => prisma.patient.count({ where: { ...where, deleted_at: null } })
    ),
    runSafeOverviewSection(
      'metrics.active_patients',
      scope,
      0,
      () => prisma.patient.count({ where: { ...where, deleted_at: null, is_active: true } })
    ),
    runSafeOverviewSection(
      'metrics.waiting_queue',
      scope,
      0,
      () =>
        prisma.visit_queue.count({
          where: {
            ...where,
            deleted_at: null,
            patient: { deleted_at: null },
            status: { in: ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS'] },
          },
        })
    ),
    runSafeOverviewSection(
      'metrics.active_admissions',
      scope,
      0,
      () =>
        prisma.admission.count({
          where: {
            ...where,
            deleted_at: null,
            patient: { deleted_at: null },
            status: 'ADMITTED',
          },
        })
    ),
    runSafeOverviewSection(
      'metrics.unpaid_invoices',
      scope,
      0,
      () =>
        prisma.invoice.count({
          where: {
            ...where,
            deleted_at: null,
            patient: { deleted_at: null },
            status: { notIn: ['PAID', 'CANCELLED'] },
          },
        })
    ),
    runSafeOverviewSection(
      'metrics.due_follow_ups',
      scope,
      0,
      () =>
        prisma.follow_up.count({
          where: {
            deleted_at: null,
            status: 'SCHEDULED',
            scheduled_at: { lte: now },
            encounter: {
              patient: {
                ...where,
                deleted_at: null,
              },
            },
          },
        })
    ),
    runSafeOverviewSection(
      'recent_patients',
      scope,
      emptyOverviewList,
      () =>
        prisma.patient.findMany({
          where: { ...where, deleted_at: null },
          include: basePatientInclude,
          orderBy: { updated_at: 'desc' },
          take: 6,
        })
    ),
    runSafeOverviewSection(
      'waiting_queue',
      scope,
      emptyOverviewList,
      () =>
        prisma.visit_queue.findMany({
          where: {
            ...where,
            deleted_at: null,
            patient: { deleted_at: null },
            status: { in: ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS'] },
          },
          include: {
            patient: { include: basePatientInclude },
            provider: { select: userDisplaySelect },
            appointment: { select: { human_friendly_id: true } },
          },
          orderBy: { queued_at: 'asc' },
          take: 6,
        })
    ),
    runSafeOverviewSection(
      'active_admissions',
      scope,
      emptyOverviewList,
      () =>
        prisma.admission.findMany({
          where: {
            ...where,
            deleted_at: null,
            patient: { deleted_at: null },
            status: 'ADMITTED',
          },
          include: {
            patient: { include: basePatientInclude },
          },
          orderBy: { admitted_at: 'desc' },
          take: 6,
        })
    ),
    runSafeOverviewSection(
      'unpaid_invoices',
      scope,
      emptyOverviewList,
      () =>
        prisma.invoice.findMany({
          where: {
            ...where,
            deleted_at: null,
            patient: { deleted_at: null },
            status: { notIn: ['PAID', 'CANCELLED'] },
          },
          include: {
            patient: { include: basePatientInclude },
          },
          orderBy: { issued_at: 'desc' },
          take: 6,
        })
    ),
  ]);

  const [
    duplicateQueue,
    patientsMissingDocuments,
    consentExceptions,
    dueFollowUps,
  ] = await Promise.all([
    runSafeOverviewSection(
      'duplicate_queue',
      scope,
      emptyOverviewQueue,
      () => listGlobalDuplicateCandidates(scope, 1, 6)
    ),
    runSafeOverviewSection(
      'missing_documents',
      scope,
      emptyOverviewList,
      () =>
        prisma.patient.findMany({
          where: {
            ...where,
            deleted_at: null,
            documents: {
              none: { deleted_at: null },
            },
          },
          include: basePatientInclude,
          orderBy: { updated_at: 'desc' },
          take: 6,
        })
    ),
    runSafeOverviewSection(
      'consent_exceptions',
      scope,
      emptyOverviewList,
      () =>
        prisma.consent.findMany({
          where: {
            deleted_at: null,
            status: { in: ['PENDING', 'REVOKED'] },
            patient: {
              ...where,
              deleted_at: null,
            },
          },
          include: {
            patient: { include: basePatientInclude },
          },
          orderBy: { updated_at: 'desc' },
          take: 6,
        })
    ),
    runSafeOverviewSection(
      'due_follow_ups',
      scope,
      emptyOverviewList,
      () =>
        prisma.follow_up.findMany({
          where: {
            deleted_at: null,
            status: 'SCHEDULED',
            scheduled_at: { lte: now },
            encounter: {
              patient: {
                ...where,
                deleted_at: null,
              },
            },
          },
          include: {
            encounter: {
              include: {
                patient: { include: basePatientInclude },
              },
            },
          },
          orderBy: { scheduled_at: 'asc' },
          take: 6,
        })
    ),
  ]);

  return {
    scope: {
      tenant_id: resolvePublicIdentifier(undefined, tenantId),
      facility_id: resolvePublicIdentifier(undefined, facilityId),
    },
    metrics: {
      total_patients: totalPatients,
      active_patients: activePatients,
      waiting_queue: waitingQueueCount,
      active_admissions: activeAdmissionsCount,
      unpaid_invoices: unpaidInvoiceCount,
      due_follow_ups: dueFollowUpCount,
    },
    recent_patients: recentPatients.map(serializePatientSummary),
    waiting_queue: recentQueue.map((entry) => ({
      queue: serializeVisitQueue(entry),
      patient: serializePatientSummary(entry.patient),
    })),
    active_admissions: recentAdmissions.map((entry) => ({
      admission: serializeAdmission(entry),
      patient: serializePatientSummary(entry.patient),
    })),
    unpaid_invoices: recentInvoices.map((entry) => ({
      invoice: serializeInvoice(entry),
      patient: serializePatientSummary(entry.patient),
    })),
    duplicate_queue: duplicateQueue.items,
    consent_exceptions: consentExceptions.map((entry) => ({
      consent: serializeConsent(entry),
      patient: serializePatientSummary(entry.patient),
    })),
    missing_documents: patientsMissingDocuments.map(serializePatientSummary),
    due_follow_ups: dueFollowUps.map((entry) => ({
      follow_up: serializeFollowUp(entry),
      patient: serializePatientSummary(entry.encounter?.patient),
    })),
  };
};

const getPatientWorkspaceReferenceData = async (scope = {}) => {
  const { where } = await resolveScopeWhere(scope);
  const facilities = await prisma.facility.findMany({
    where: {
      ...('tenant_id' in where ? { tenant_id: where.tenant_id } : {}),
      deleted_at: null,
    },
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
    orderBy: { name: 'asc' },
  });

  return {
    facilities: facilities.map((entry) => ({
      human_friendly_id: resolvePublicIdentifier(entry?.human_friendly_id, entry?.id),
      label: normalizeText(entry?.name) || resolvePublicIdentifier(entry?.human_friendly_id, entry?.id),
    })),
    document_types: DOCUMENT_TYPE_OPTIONS.map((value) => ({ value })),
    consent_types: CONSENT_TYPE_OPTIONS.map((value) => ({ value })),
    consent_statuses: CONSENT_STATUS_OPTIONS.map((value) => ({ value })),
    appointment_statuses: APPOINTMENT_STATUS_OPTIONS.map((value) => ({ value })),
  };
};

const listPatientTimeline = async (patientIdentifier, page = 1, limit = WORKSPACE_PAGE_LIMIT, scope = {}, userContext = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  await recordPatientPhiAccess({
    userId: userContext?.user_id,
    patient,
    routeFamily: 'timeline',
    ipAddress: userContext?.ip_address,
  });

  const [
    appointments,
    queueEntries,
    encounters,
    admissions,
    documents,
    consents,
    followUps,
    referrals,
    invoices,
    payments,
  ] = await Promise.all([
    prisma.appointment.findMany({
      where: { patient_id: patient.id, deleted_at: null },
      include: { provider: { select: userDisplaySelect } },
      orderBy: { scheduled_start: 'desc' },
      take: 20,
    }),
    prisma.visit_queue.findMany({
      where: { patient_id: patient.id, deleted_at: null },
      include: {
        provider: { select: userDisplaySelect },
        appointment: { select: { human_friendly_id: true } },
      },
      orderBy: { queued_at: 'desc' },
      take: 20,
    }),
    prisma.encounter.findMany({
      where: { patient_id: patient.id, deleted_at: null },
      include: { provider: { select: userDisplaySelect } },
      orderBy: { updated_at: 'desc' },
      take: 20,
    }),
    prisma.admission.findMany({
      where: { patient_id: patient.id, deleted_at: null },
      orderBy: { admitted_at: 'desc' },
      take: 20,
    }),
    prisma.patient_document.findMany({
      where: { patient_id: patient.id, deleted_at: null },
      orderBy: { updated_at: 'desc' },
      take: 20,
    }),
    prisma.consent.findMany({
      where: { patient_id: patient.id, deleted_at: null },
      orderBy: { updated_at: 'desc' },
      take: 20,
    }),
    prisma.follow_up.findMany({
      where: { deleted_at: null, encounter: { patient_id: patient.id } },
      include: { encounter: { select: { human_friendly_id: true } } },
      orderBy: { scheduled_at: 'desc' },
      take: 20,
    }),
    prisma.referral.findMany({
      where: { deleted_at: null, encounter: { patient_id: patient.id } },
      include: {
        encounter: { select: { human_friendly_id: true } },
        from_department: { select: { name: true } },
        to_department: { select: { name: true } },
      },
      orderBy: { updated_at: 'desc' },
      take: 20,
    }),
    prisma.invoice.findMany({
      where: { patient_id: patient.id, deleted_at: null },
      orderBy: { issued_at: 'desc' },
      take: 20,
    }),
    prisma.payment.findMany({
      where: { patient_id: patient.id, deleted_at: null },
      include: { invoice: { select: { human_friendly_id: true } } },
      orderBy: { paid_at: 'desc' },
      take: 20,
    }),
  ]);

  const timelineItems = [
    buildTimelineItem('patient_registered', patient, 'created_at', serializePatientSummary),
    ...appointments.map((entry) => buildTimelineItem('appointment', entry, 'scheduled_start', serializeAppointment)),
    ...queueEntries.map((entry) => buildTimelineItem('visit_queue', entry, 'queued_at', serializeVisitQueue)),
    ...encounters.map((entry) => buildTimelineItem('encounter', entry, 'updated_at', serializeEncounter)),
    ...admissions.map((entry) => buildTimelineItem('admission', entry, 'admitted_at', serializeAdmission)),
    ...documents.map((entry) => buildTimelineItem('document', entry, 'updated_at', serializeDocument)),
    ...consents.map((entry) => buildTimelineItem('consent', entry, 'updated_at', serializeConsent)),
    ...followUps.map((entry) => buildTimelineItem('follow_up', entry, 'scheduled_at', serializeFollowUp)),
    ...referrals.map((entry) => buildTimelineItem('referral', entry, 'updated_at', serializeReferral)),
    ...invoices.map((entry) => buildTimelineItem('invoice', entry, 'issued_at', serializeInvoice)),
    ...payments.map((entry) => buildTimelineItem('payment', entry, 'paid_at', serializePayment)),
  ].sort((left, right) => new Date(right.occurred_at || 0).getTime() - new Date(left.occurred_at || 0).getTime());

  const safePage = toInteger(page, 1);
  const safeLimit = toInteger(limit, WORKSPACE_PAGE_LIMIT);
  const start = (safePage - 1) * safeLimit;
  const items = timelineItems.slice(start, start + safeLimit);

  return {
    items,
    pagination: buildPagination(safePage, safeLimit, timelineItems.length),
  };
};

const buildPatientWorkspacePayload = async (patient, scope = {}, userContext = {}) => {
  await recordPatientPhiAccess({
    userId: userContext?.user_id,
    patient,
    routeFamily: 'workspace',
    ipAddress: userContext?.ip_address,
  });

  const [
    latestAppointments,
    latestQueueEntries,
    latestEncounters,
    latestAdmissions,
    latestDocuments,
    latestConsents,
    latestFollowUps,
    latestReferrals,
    latestInvoices,
    latestPayments,
    latestPhiLogs,
    duplicateCandidates,
    timeline,
  ] = await Promise.all([
    runSafePatientWorkspaceSection(
      'workspace.appointments',
      scope,
      [],
      () =>
        prisma.appointment.findMany({
          where: { patient_id: patient.id, deleted_at: null },
          include: { provider: { select: userDisplaySelect } },
          orderBy: { scheduled_start: 'desc' },
          take: 5,
        })
    ),
    runSafePatientWorkspaceSection(
      'workspace.queue_entries',
      scope,
      [],
      () =>
        prisma.visit_queue.findMany({
          where: { patient_id: patient.id, deleted_at: null },
          include: {
            provider: { select: userDisplaySelect },
            appointment: { select: { human_friendly_id: true } },
          },
          orderBy: { queued_at: 'desc' },
          take: 5,
        })
    ),
    runSafePatientWorkspaceSection(
      'workspace.encounters',
      scope,
      [],
      () =>
        prisma.encounter.findMany({
          where: { patient_id: patient.id, deleted_at: null },
          include: { provider: { select: userDisplaySelect } },
          orderBy: { updated_at: 'desc' },
          take: 5,
        })
    ),
    runSafePatientWorkspaceSection(
      'workspace.admissions',
      scope,
      [],
      () =>
        prisma.admission.findMany({
          where: { patient_id: patient.id, deleted_at: null },
          orderBy: { admitted_at: 'desc' },
          take: 5,
        })
    ),
    runSafePatientWorkspaceSection(
      'workspace.documents',
      scope,
      [],
      () =>
        prisma.patient_document.findMany({
          where: { patient_id: patient.id, deleted_at: null },
          orderBy: { updated_at: 'desc' },
          take: 5,
        })
    ),
    runSafePatientWorkspaceSection(
      'workspace.consents',
      scope,
      [],
      () =>
        prisma.consent.findMany({
          where: { patient_id: patient.id, deleted_at: null },
          orderBy: { updated_at: 'desc' },
          take: 5,
        })
    ),
    runSafePatientWorkspaceSection(
      'workspace.follow_ups',
      scope,
      [],
      () =>
        prisma.follow_up.findMany({
          where: { deleted_at: null, encounter: { patient_id: patient.id } },
          include: { encounter: { select: { human_friendly_id: true } } },
          orderBy: { scheduled_at: 'desc' },
          take: 5,
        })
    ),
    runSafePatientWorkspaceSection(
      'workspace.referrals',
      scope,
      [],
      () =>
        prisma.referral.findMany({
          where: { deleted_at: null, encounter: { patient_id: patient.id } },
          include: {
            encounter: { select: { human_friendly_id: true } },
            from_department: { select: { name: true } },
            to_department: { select: { name: true } },
          },
          orderBy: { updated_at: 'desc' },
          take: 5,
        })
    ),
    runSafePatientWorkspaceSection(
      'workspace.invoices',
      scope,
      [],
      () =>
        prisma.invoice.findMany({
          where: { patient_id: patient.id, deleted_at: null },
          orderBy: { issued_at: 'desc' },
          take: 5,
        })
    ),
    runSafePatientWorkspaceSection(
      'workspace.payments',
      scope,
      [],
      () =>
        prisma.payment.findMany({
          where: { patient_id: patient.id, deleted_at: null },
          include: { invoice: { select: { human_friendly_id: true } } },
          orderBy: { paid_at: 'desc' },
          take: 5,
        })
    ),
    runSafePatientWorkspaceSection(
      'workspace.phi_access_logs',
      scope,
      [],
      () =>
        prisma.phi_access_log.findMany({
          where: { patient_id: patient.id, deleted_at: null },
          include: { user: { select: userDisplaySelect } },
          orderBy: { accessed_at: 'desc' },
          take: 5,
        })
    ),
    runSafePatientWorkspaceSection(
      'workspace.duplicate_candidates',
      scope,
      [],
      () => findDuplicateCandidatesForTarget(patient, scope, 5)
    ),
    runSafePatientWorkspaceSection(
      'workspace.timeline',
      scope,
      { items: [], pagination: buildPagination(1, 12, 0) },
      () => listPatientTimeline(patient.human_friendly_id || patient.id, 1, 12, scope, userContext)
    ),
  ]);

  return {
    patient: serializePatientSummary(patient),
    snapshot: {
      appointments: latestAppointments.map(serializeAppointment),
      queue_entries: latestQueueEntries.map(serializeVisitQueue),
      encounters: latestEncounters.map(serializeEncounter),
      admissions: latestAdmissions.map(serializeAdmission),
      documents: latestDocuments.map(serializeDocument),
      consents: latestConsents.map(serializeConsent),
      follow_ups: latestFollowUps.map(serializeFollowUp),
      referrals: latestReferrals.map(serializeReferral),
      invoices: latestInvoices.map(serializeInvoice),
      payments: latestPayments.map(serializePayment),
      phi_access_logs: latestPhiLogs.map(serializePhiAccessLog),
      duplicate_candidates: duplicateCandidates,
      summary_counts: {
        appointments: latestAppointments.length,
        queue_entries: latestQueueEntries.length,
        encounters: latestEncounters.length,
        admissions: latestAdmissions.length,
        documents: latestDocuments.length,
        consents: latestConsents.length,
        follow_ups: latestFollowUps.length,
        referrals: latestReferrals.length,
        invoices: latestInvoices.length,
        payments: latestPayments.length,
      },
    },
    timeline: timeline.items,
  };
};

const getPatientWorkspace = async (patientIdentifier, scope = {}, userContext = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  return buildPatientWorkspacePayload(patient, scope, userContext);
};

const listPatientConsents = async (patientIdentifier, page = 1, limit = WORKSPACE_PAGE_LIMIT, scope = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  return listModelPage({
    delegate: prisma.consent,
    where: { patient_id: patient.id },
    page,
    limit,
    orderBy: { updated_at: 'desc' },
    serializer: serializeConsent,
  });
};

const listPatientAppointments = async (patientIdentifier, page = 1, limit = WORKSPACE_PAGE_LIMIT, scope = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  return listModelPage({
    delegate: prisma.appointment,
    where: { patient_id: patient.id },
    page,
    limit,
    orderBy: { scheduled_start: 'desc' },
    include: { provider: { select: userDisplaySelect } },
    serializer: serializeAppointment,
  });
};

const listPatientVisitQueueEntries = async (patientIdentifier, page = 1, limit = WORKSPACE_PAGE_LIMIT, scope = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  return listModelPage({
    delegate: prisma.visit_queue,
    where: { patient_id: patient.id },
    page,
    limit,
    orderBy: { queued_at: 'desc' },
    include: {
      provider: { select: userDisplaySelect },
      appointment: { select: { human_friendly_id: true } },
    },
    serializer: serializeVisitQueue,
  });
};

const listPatientEncounters = async (patientIdentifier, page = 1, limit = WORKSPACE_PAGE_LIMIT, scope = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  return listModelPage({
    delegate: prisma.encounter,
    where: { patient_id: patient.id },
    page,
    limit,
    orderBy: { updated_at: 'desc' },
    include: { provider: { select: userDisplaySelect } },
    serializer: serializeEncounter,
  });
};

const listPatientAdmissions = async (patientIdentifier, page = 1, limit = WORKSPACE_PAGE_LIMIT, scope = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  return listModelPage({
    delegate: prisma.admission,
    where: { patient_id: patient.id },
    page,
    limit,
    orderBy: { admitted_at: 'desc' },
    serializer: serializeAdmission,
  });
};

const listPatientFollowUps = async (patientIdentifier, page = 1, limit = WORKSPACE_PAGE_LIMIT, scope = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  return listModelPage({
    delegate: prisma.follow_up,
    where: { encounter: { patient_id: patient.id } },
    page,
    limit,
    orderBy: { scheduled_at: 'desc' },
    include: { encounter: { select: { human_friendly_id: true } } },
    serializer: serializeFollowUp,
  });
};

const listPatientReferrals = async (patientIdentifier, page = 1, limit = WORKSPACE_PAGE_LIMIT, scope = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  return listModelPage({
    delegate: prisma.referral,
    where: { encounter: { patient_id: patient.id } },
    page,
    limit,
    orderBy: { updated_at: 'desc' },
    include: {
      encounter: { select: { human_friendly_id: true } },
      from_department: { select: { name: true } },
      to_department: { select: { name: true } },
    },
    serializer: serializeReferral,
  });
};

const listPatientInvoices = async (patientIdentifier, page = 1, limit = WORKSPACE_PAGE_LIMIT, scope = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  return listModelPage({
    delegate: prisma.invoice,
    where: { patient_id: patient.id },
    page,
    limit,
    orderBy: { issued_at: 'desc' },
    serializer: serializeInvoice,
  });
};

const listPatientPayments = async (patientIdentifier, page = 1, limit = WORKSPACE_PAGE_LIMIT, scope = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  return listModelPage({
    delegate: prisma.payment,
    where: { patient_id: patient.id },
    page,
    limit,
    orderBy: { paid_at: 'desc' },
    include: { invoice: { select: { human_friendly_id: true } } },
    serializer: serializePayment,
  });
};

const listPatientPhiAccessLogs = async (patientIdentifier, page = 1, limit = WORKSPACE_PAGE_LIMIT, scope = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  return listModelPage({
    delegate: prisma.phi_access_log,
    where: { patient_id: patient.id },
    page,
    limit,
    orderBy: { accessed_at: 'desc' },
    include: { user: { select: userDisplaySelect } },
    serializer: serializePhiAccessLog,
  });
};

const listDuplicateCandidates = async (filters = {}, scope = {}, page = 1, limit = WORKSPACE_PAGE_LIMIT) => {
  const patientIdentifier = normalizeText(filters?.patient_id);
  if (patientIdentifier) {
    const patient = await resolvePatientRecord(patientIdentifier, scope);
    const items = await findDuplicateCandidatesForTarget(patient, scope, toInteger(limit, WORKSPACE_PAGE_LIMIT));
    return {
      items,
      pagination: buildPagination(1, items.length || toInteger(limit, WORKSPACE_PAGE_LIMIT), items.length),
    };
  }

  const firstName = normalizeText(filters?.first_name);
  const lastName = normalizeText(filters?.last_name);
  const dateOfBirth = normalizeText(filters?.date_of_birth);
  const phone = normalizeText(filters?.phone || filters?.contact);
  const identifierValue = normalizeText(filters?.identifier_value);
  if (firstName || lastName || dateOfBirth || phone || identifierValue) {
    const syntheticPatient = {
      id: 'synthetic-patient',
      first_name: firstName,
      last_name: lastName,
      date_of_birth: dateOfBirth || null,
      contacts: phone ? [{ value: phone, is_primary: true }] : [],
      identifiers: identifierValue ? [{ identifier_value: identifierValue, is_primary: true }] : [],
      extension_json: {},
    };
    const { where } = await resolveScopeWhere(scope);
    const rows = await prisma.patient.findMany({
      where: {
        ...where,
        deleted_at: null,
        is_active: true,
      },
      include: basePatientInclude,
      take: 50,
      orderBy: { updated_at: 'desc' },
    });
    const items = rows
      .map((candidate) => ({
        candidate,
        duplicateState: computeDuplicateScore(syntheticPatient, candidate),
      }))
      .filter(({ duplicateState }) => duplicateState.score >= DUPLICATE_MIN_SCORE)
      .sort((left, right) => right.duplicateState.score - left.duplicateState.score)
      .slice(0, toInteger(limit, WORKSPACE_PAGE_LIMIT))
      .map(({ candidate, duplicateState }) => ({
        review_id: getPairKey('synthetic-patient', candidate.id),
        confidence_score: duplicateState.score,
        classification: duplicateState.classification,
        match_reasons: duplicateState.reasons,
        candidate_patient: serializePatientSummary(candidate),
      }));

    return {
      items,
      pagination: buildPagination(1, items.length || toInteger(limit, WORKSPACE_PAGE_LIMIT), items.length),
    };
  }

  return listGlobalDuplicateCandidates(scope, page, limit);
};

const buildMergePreview = async (primaryPatientIdentifier, secondaryPatientIdentifier, scope = {}) => {
  const primary = await resolvePatientRecord(primaryPatientIdentifier, scope);
  const secondary = await resolvePatientRecord(secondaryPatientIdentifier, scope);
  if (primary.id === secondary.id) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'secondary_patient_id' }]);
  }

  const duplicateState = computeDuplicateScore(primary, secondary);
  const counts = await Promise.all([
    prisma.patient_identifier.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.patient_contact.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.patient_guardian.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.patient_allergy.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.patient_medical_history.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.address.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.patient_document.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.consent.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.appointment.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.visit_queue.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.encounter.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.admission.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.invoice.count({ where: { patient_id: secondary.id, deleted_at: null } }),
    prisma.payment.count({ where: { patient_id: secondary.id, deleted_at: null } }),
  ]);

  return {
    primary_patient: serializePatientSummary(primary),
    secondary_patient: serializePatientSummary(secondary),
    confidence_score: duplicateState.score,
    classification: duplicateState.classification,
    match_reasons: duplicateState.reasons,
    transfer_counts: {
      identifiers: counts[0],
      contacts: counts[1],
      guardians: counts[2],
      allergies: counts[3],
      medical_histories: counts[4],
      addresses: counts[5],
      documents: counts[6],
      consents: counts[7],
      appointments: counts[8],
      queue_entries: counts[9],
      encounters: counts[10],
      admissions: counts[11],
      invoices: counts[12],
      payments: counts[13],
    },
  };
};

const previewPatientMerge = async (payload = {}, scope = {}) =>
  buildMergePreview(payload?.primary_patient_id, payload?.secondary_patient_id, scope);

const addDismissedPair = async (patientId, pairKey, tx = prisma) => {
  const record = await tx.patient.findUnique({
    where: { id: patientId },
    select: { id: true, extension_json: true },
  });
  if (!record?.id) return;
  const extension = readExtensionJson(record);
  const current = Array.isArray(extension?.duplicate_review?.dismissed_pair_keys)
    ? extension.duplicate_review.dismissed_pair_keys.map((value) => normalizeText(value)).filter(Boolean)
    : [];
  if (!current.includes(pairKey)) {
    current.push(pairKey);
  }
  await tx.patient.update({
    where: { id: patientId },
    data: {
      extension_json: {
        ...extension,
        duplicate_review: {
          ...(extension.duplicate_review || {}),
          dismissed_pair_keys: current,
        },
      },
    },
  });
};

const dedupeAndMoveBySignature = async ({
  tx,
  modelName,
  primaryPatientId,
  secondaryPatientId,
  signature,
}) => {
  const delegate = tx[modelName];
  if (!delegate || typeof delegate.findMany !== 'function') return;
  const primaryRows = await delegate.findMany({
    where: { patient_id: primaryPatientId, deleted_at: null },
  });
  const existingKeys = new Set(primaryRows.map((entry) => signature(entry)).filter(Boolean));
  const secondaryRows = await delegate.findMany({
    where: { patient_id: secondaryPatientId, deleted_at: null },
  });

  for (const row of secondaryRows) {
    const key = signature(row);
    if (key && existingKeys.has(key)) {
      await delegate.update({
        where: { id: row.id },
        data: { deleted_at: new Date() },
      });
      continue;
    }
    if (key) existingKeys.add(key);
    await delegate.update({
      where: { id: row.id },
      data: { patient_id: primaryPatientId },
    });
  }
};

const mergePatients = async (payload = {}, scope = {}, userContext = {}) => {
  const primary = await resolvePatientRecord(payload?.primary_patient_id, scope);
  const secondary = await resolvePatientRecord(payload?.secondary_patient_id, scope);
  if (primary.id === secondary.id) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'secondary_patient_id' }]);
  }

  await prisma.$transaction(async (tx) => {
    await dedupeAndMoveBySignature({
      tx,
      modelName: 'patient_identifier',
      primaryPatientId: primary.id,
      secondaryPatientId: secondary.id,
      signature: (row) => `${normalizeUpper(row?.identifier_type)}:${normalizeLower(row?.identifier_value)}`,
    });
    await dedupeAndMoveBySignature({
      tx,
      modelName: 'patient_contact',
      primaryPatientId: primary.id,
      secondaryPatientId: secondary.id,
      signature: (row) => `${normalizeUpper(row?.contact_type)}:${normalizePhone(row?.value) || normalizeLower(row?.value)}`,
    });
    await dedupeAndMoveBySignature({
      tx,
      modelName: 'patient_guardian',
      primaryPatientId: primary.id,
      secondaryPatientId: secondary.id,
      signature: (row) => [
        normalizeLower(row?.name),
        normalizeLower(row?.relationship),
        normalizePhone(row?.phone),
      ].join(':'),
    });
    await dedupeAndMoveBySignature({
      tx,
      modelName: 'patient_allergy',
      primaryPatientId: primary.id,
      secondaryPatientId: secondary.id,
      signature: (row) => [
        normalizeLower(row?.allergen),
        normalizeLower(row?.reaction),
        normalizeUpper(row?.severity),
      ].join(':'),
    });
    await dedupeAndMoveBySignature({
      tx,
      modelName: 'patient_medical_history',
      primaryPatientId: primary.id,
      secondaryPatientId: secondary.id,
      signature: (row) => [
        normalizeLower(row?.condition),
        normalizeDateOnly(row?.diagnosis_date),
      ].join(':'),
    });
    await dedupeAndMoveBySignature({
      tx,
      modelName: 'address',
      primaryPatientId: primary.id,
      secondaryPatientId: secondary.id,
      signature: (row) => [
        normalizeLower(row?.address_type),
        normalizeLower(row?.line1),
        normalizeLower(row?.line2),
        normalizeLower(row?.city),
        normalizeLower(row?.state),
        normalizeLower(row?.postal_code),
        normalizeLower(row?.country),
      ].join(':'),
    });
    await dedupeAndMoveBySignature({
      tx,
      modelName: 'patient_document',
      primaryPatientId: primary.id,
      secondaryPatientId: secondary.id,
      signature: (row) => `${normalizeLower(row?.storage_key)}:${normalizeLower(row?.file_name)}`,
    });

    await tx.consent.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.appointment.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.appointment_participant.updateMany({ where: { participant_patient_id: secondary.id, deleted_at: null }, data: { participant_patient_id: primary.id } });
    await tx.visit_queue.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.encounter.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.admission.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.lab_order.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.radiology_order.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.pharmacy_order.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.emergency_case.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.invoice.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.payment.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.message.updateMany({ where: { sender_patient_id: secondary.id, deleted_at: null }, data: { sender_patient_id: primary.id } });
    await tx.phi_access_log.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.contact.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.address.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });
    await tx.adverse_event.updateMany({ where: { patient_id: secondary.id, deleted_at: null }, data: { patient_id: primary.id } });

    const primaryUpdate = {};
    if (payload?.summary && typeof payload.summary === 'object') {
      if (payload.summary.first_name !== undefined) primaryUpdate.first_name = normalizeText(payload.summary.first_name) || primary.first_name;
      if (payload.summary.last_name !== undefined) primaryUpdate.last_name = normalizeText(payload.summary.last_name) || primary.last_name;
      if (payload.summary.date_of_birth !== undefined) primaryUpdate.date_of_birth = payload.summary.date_of_birth || null;
      if (payload.summary.gender !== undefined) primaryUpdate.gender = normalizeText(payload.summary.gender) || null;
      if (payload.summary.facility_id !== undefined) {
        primaryUpdate.facility_id = await resolveIdentifierForPayload({
          value: payload.summary.facility_id,
          model: 'facility',
          field: 'facility_id',
          where: { tenant_id: primary.tenant_id },
          nullable: true,
        });
      }
    }

    const primaryExtension = readExtensionJson(primary);
    await tx.patient.update({
      where: { id: primary.id },
      data: {
        ...primaryUpdate,
        extension_json: {
          ...primaryExtension,
          merge_history: [
            ...(Array.isArray(primaryExtension?.merge_history) ? primaryExtension.merge_history : []),
            {
              merged_patient_id: secondary.id,
              merged_patient_human_friendly_id: secondary.human_friendly_id || null,
              merged_at: new Date().toISOString(),
              merged_by_user_id: userContext?.user_id || null,
            },
          ],
        },
      },
    });

    const secondaryExtension = readExtensionJson(secondary);
    await tx.patient.update({
      where: { id: secondary.id },
      data: {
        is_active: false,
        extension_json: {
          ...secondaryExtension,
          merge: {
            merged_into_patient_id: primary.id,
            merged_into_patient_human_friendly_id: primary.human_friendly_id || null,
            merged_at: new Date().toISOString(),
            merged_by_user_id: userContext?.user_id || null,
          },
        },
      },
    });

    const pairKey = getPairKey(primary.id, secondary.id);
    await addDismissedPair(primary.id, pairKey, tx);
    await addDismissedPair(secondary.id, pairKey, tx);
  });

  await createAuditLog({
    tenant_id: primary.tenant_id,
    user_id: userContext?.user_id,
    action: 'UPDATE',
    entity: 'patient_merge',
    entity_id: primary.id,
    diff: {
      before: {
        primary_patient_id: primary.id,
        secondary_patient_id: secondary.id,
      },
      after: {
        primary_patient_id: primary.id,
        secondary_patient_id: secondary.id,
        merged: true,
      },
    },
    ip_address: userContext?.ip_address,
  });

  return getPatientWorkspace(primary.human_friendly_id || primary.id, scope, userContext);
};

const dismissDuplicateCandidate = async (reviewId, payload = {}, scope = {}, userContext = {}) => {
  const primary = await resolvePatientRecord(payload?.primary_patient_id, scope);
  const secondary = await resolvePatientRecord(payload?.secondary_patient_id, scope);
  const pairKey = normalizeText(reviewId) || getPairKey(primary.id, secondary.id);

  await addDismissedPair(primary.id, pairKey);
  await addDismissedPair(secondary.id, pairKey);

  await createAuditLog({
    tenant_id: primary.tenant_id,
    user_id: userContext?.user_id,
    action: 'UPDATE',
    entity: 'patient_duplicate_review',
    entity_id: pairKey,
    diff: {
      after: {
        pair_key: pairKey,
        primary_patient_id: primary.id,
        secondary_patient_id: secondary.id,
        dismissed_reason: normalizeText(payload?.dismissed_reason) || null,
      },
    },
    ip_address: userContext?.ip_address,
  });

  return {
    review_id: pairKey,
    dismissed: true,
  };
};

const buildUploadPath = (patient, originalFileName) => {
  const safeName = sanitizeFilename(normalizeText(originalFileName) || 'document');
  const date = new Date();
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  return [
    'patients',
    normalizeText(patient?.tenant?.human_friendly_id || patient?.tenant_id || 'tenant'),
    normalizeText(patient?.human_friendly_id || patient?.id || 'patient'),
    'documents',
    String(year),
    month,
    `${Date.now()}-${safeName}`,
  ]
    .map((value) => sanitizeFilename(value))
    .join('/');
};

const normalizeUploadedFile = (file = {}) => ({
  originalname: normalizeText(file?.originalname || file?.name || file?.fileName),
  mimetype: normalizeLower(file?.mimetype || file?.type || file?.mimeType),
  size: Number(file?.size || file?.fileSize || 0),
  buffer: file?.buffer,
});

const uploadPatientDocuments = async (patientIdentifier, files = [], body = {}, scope = {}, userContext = {}) => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  const normalizedFiles = (Array.isArray(files) ? files : [])
    .map(normalizeUploadedFile)
    .filter((file) => Boolean(file.originalname) && Buffer.isBuffer(file.buffer));

  if (normalizedFiles.length === 0) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'files' }]);
  }
  if (normalizedFiles.length > MAX_DOCUMENT_FILES) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'files' }]);
  }

  const documentType = normalizeUpper(body?.document_type) || 'OTHER';
  const storage = createStorageService();
  const uploadedRecords = [];

  for (const file of normalizedFiles) {
    if (!ACCEPTED_DOCUMENT_MIME_TYPES.has(file.mimetype)) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'content_type' }]);
    }
    if (file.size > MAX_DOCUMENT_SIZE_BYTES) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'size' }]);
    }

    const storageKey = buildUploadPath(patient, file.originalname);
    const uploaded = await storage.upload(file.buffer, storageKey, {
      mimeType: file.mimetype,
      encrypt: true,
    });
    const created = await prisma.patient_document.create({
      data: {
        tenant_id: patient.tenant_id,
        patient_id: patient.id,
        document_type: documentType,
        storage_key: uploaded?.path || storageKey,
        file_name: file.originalname,
        content_type: file.mimetype || null,
      },
    });

    uploadedRecords.push(created);
    await createAuditLog({
      tenant_id: patient.tenant_id,
      user_id: userContext?.user_id,
      action: 'CREATE',
      entity: 'patient_document',
      entity_id: created.id,
      diff: {
        after: {
          patient_id: patient.id,
          document_type: documentType,
          storage_key: uploaded?.path || storageKey,
        },
      },
      ip_address: userContext?.ip_address,
    });
  }

  return {
    items: uploadedRecords.map(serializeDocument),
  };
};

const getPatientDocumentAsset = async (patientIdentifier, documentIdentifier, scope = {}, userContext = {}, disposition = 'inline') => {
  const patient = await resolvePatientRecord(patientIdentifier, scope);
  const document = await resolveDocumentRecord(documentIdentifier, patient.id);
  const storage = createStorageService();
  const buffer = await storage.download(document.storage_key);

  await recordPatientPhiAccess({
    userId: userContext?.user_id,
    patient,
    routeFamily: disposition === 'attachment' ? 'document_download' : 'document_preview',
    ipAddress: userContext?.ip_address,
  });

  return {
    buffer,
    contentType: normalizeText(document.content_type) || 'application/octet-stream',
    fileName: normalizeText(document.file_name) || `${document.document_type || 'document'}`,
  };
};

module.exports = {
  getPatientWorkspaceOverview,
  getPatientWorkspaceReferenceData,
  getPatientWorkspace,
  listPatientTimeline,
  listPatientConsents,
  listPatientAppointments,
  listPatientVisitQueueEntries,
  listPatientEncounters,
  listPatientAdmissions,
  listPatientFollowUps,
  listPatientReferrals,
  listPatientInvoices,
  listPatientPayments,
  listPatientPhiAccessLogs,
  listDuplicateCandidates,
  previewPatientMerge,
  mergePatients,
  dismissDuplicateCandidate,
  uploadPatientDocuments,
  getPatientDocumentAsset,
};
