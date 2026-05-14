const crypto = require('crypto');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { normalizeIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const prisma = require('@prisma/client');
const radiologyWorkspaceRepository = require('@repositories/radiology-workspace/radiology-workspace.repository');
const { emitToUsers, DIAGNOSTIC_EVENTS } = require('@lib/websocket');
const { ROLES } = require('@config/roles');
const { STORAGE_PROVIDER, RADIOLOGY_ATTESTATION_V2 } = require('@config/env');
const dicomWebClient = require('@lib/dicomweb/client');
const {
  RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE,
  RADIOLOGY_STUDY_WITH_RELATIONS_INCLUDE,
  RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  toDateOrNull,
  applyDateRangeFilter,
} = require('@services/radiology-workspace/radiology.shared');
const {
  toPublicIdentifier,
  mapRadiologyOrderRecord,
  mapRadiologyOrderWorkflowRecord,
  mapRadiologyResultRecord,
  mapImagingStudyRecord,
  mapPacsLinkRecord,
} = require('@services/radiology-workspace/radiology.serializer');

const ORDER_COMPLETION_STATES = new Set(['COMPLETED', 'CANCELLED']);
const DEFAULT_REFERENCE_LIMIT = 20;
const MAX_REFERENCE_LIMIT = 50;
const RADIOLOGY_RECIPIENT_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
];

const LEGACY_ROUTE_CONFIG = Object.freeze({
  'radiology-orders': {
    model: 'radiology_order',
    resource: 'orders',
    route: '/radiology/orders',
  },
  'radiology-results': {
    model: 'radiology_result',
    resource: 'results',
    route: '/radiology/results',
  },
  'radiology-tests': {
    model: 'radiology_test',
    resource: 'tests',
    route: '/radiology/tests',
  },
  'imaging-studies': {
    model: 'imaging_study',
    resource: 'studies',
    route: '/radiology/studies',
  },
  'imaging-assets': {
    model: 'imaging_asset',
    resource: 'assets',
    route: '/radiology/assets',
  },
  'pacs-links': {
    model: 'pacs_link',
    resource: 'pacs-links',
    route: '/radiology/pacs-links',
  },
});

const appendAnd = (where, clause) => {
  if (!clause || typeof clause !== 'object') return;
  if (!Array.isArray(where.AND)) where.AND = [];
  where.AND.push(clause);
};

const normalizeEnumFilter = (value, fallback) => {
  const normalized = String(value || '').trim().toUpperCase();
  if (!normalized) return fallback;
  return normalized;
};

const assertTransition = (condition, details = {}) => {
  if (condition) return;
  throw new HttpError('errors.radiology_workflow.invalid_transition', 400, [details]);
};

const sanitizeForPath = (value) =>
  String(value || '')
    .trim()
    .replace(/[^A-Za-z0-9._-]+/g, '_')
    .slice(0, 120);

const buildUploadStorageKey = (studyId, fileName) => {
  const safeName = sanitizeForPath(fileName || 'asset.bin') || 'asset.bin';
  const timestamp = new Date().toISOString().replace(/[:.]/g, '');
  return `radiology/${sanitizeForPath(studyId)}/${timestamp}-${safeName}`;
};

const composeReportText = ({ reportText, findings, impression }) => {
  const normalizedReport = String(reportText || '').trim();
  if (normalizedReport) return normalizedReport;

  const parts = [];
  const normalizedFindings = String(findings || '').trim();
  const normalizedImpression = String(impression || '').trim();
  if (normalizedFindings) parts.push(`Findings:\n${normalizedFindings}`);
  if (normalizedImpression) parts.push(`Impression:\n${normalizedImpression}`);
  return parts.join('\n\n').trim() || null;
};

const composeAddendumText = (existingText, addendumText) => {
  const base = String(existingText || '').trim();
  const addendum = String(addendumText || '').trim();
  if (!addendum) return base || null;
  if (!base) return `Addendum:\n${addendum}`;
  return `${base}\n\nAddendum:\n${addendum}`;
};

const createResultAttestation = async ({
  tx,
  resultId,
  phase,
  userId,
  userRole,
  statement = null,
  reason = null,
  ipAddress = null,
  attestedAt = null,
}) =>
  radiologyWorkspaceRepository.txCreateResultAttestation(tx, {
    radiology_result_id: resultId,
    phase,
    attested_by_user_id: userId,
    attested_role: userRole || null,
    statement: statement || null,
    reason: reason || null,
    ip_address: ipAddress || null,
    attested_at: toDateOrNull(attestedAt, new Date()),
  });

const normalizeText = (value) => String(value || '').trim();

const normalizeReferenceLimit = (value) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return DEFAULT_REFERENCE_LIMIT;
  return Math.min(MAX_REFERENCE_LIMIT, Math.max(1, Math.floor(parsed)));
};

const toPersonDisplayName = (...parts) => parts.map(normalizeText).filter(Boolean).join(' ').trim();

const buildScopedWhere = (scope = {}) => ({
  ...(scope.tenantId ? { tenant_id: scope.tenantId } : {}),
  ...(scope.facilityId ? { facility_id: scope.facilityId } : {}),
});

const mapPatientReferenceOption = (record) => {
  const value = toPublicIdentifier(record?.human_friendly_id, record?.id);
  if (!value) return null;
  const name = toPersonDisplayName(record?.first_name, record?.last_name);
  const contact = normalizeText(record?.contacts?.[0]?.value) || null;
  return {
    value,
    label: name || value,
    subtitle: [value, contact].filter(Boolean).join(' | ') || null,
  };
};

const mapEncounterReferenceOption = (record) => {
  const value = toPublicIdentifier(record?.human_friendly_id, record?.id);
  if (!value) return null;

  const patientName = toPersonDisplayName(
    record?.patient?.first_name,
    record?.patient?.last_name
  );
  const patientId = toPublicIdentifier(record?.patient?.human_friendly_id, record?.patient?.id);
  const startedAt = record?.started_at ? new Date(record.started_at).toISOString() : null;

  return {
    value,
    label: patientName ? `${value} | ${patientName}` : value,
    subtitle: [patientId, normalizeText(record?.status), startedAt].filter(Boolean).join(' | ') || null,
    patient_id: patientId,
  };
};

const mapTestReferenceOption = (record) => {
  const value = toPublicIdentifier(record?.human_friendly_id, record?.id);
  if (!value) return null;
  const name = normalizeText(record?.name);
  const code = normalizeText(record?.code);
  const modality = normalizeText(record?.modality).toUpperCase() || null;
  return {
    value,
    label: name || code || value,
    subtitle: [value, code, modality].filter(Boolean).join(' | ') || null,
  };
};

const mapUserReferenceOption = (record) => {
  const value = toPublicIdentifier(record?.human_friendly_id, record?.id);
  if (!value) return null;
  const name = toPersonDisplayName(
    record?.profile?.first_name,
    record?.profile?.middle_name,
    record?.profile?.last_name
  );
  const email = normalizeText(record?.email);
  return {
    value,
    label: name || email || value,
    subtitle: [value, email].filter(Boolean).join(' | ') || null,
  };
};

const buildWorkbenchOrderWhere = async (filters = {}, options = {}) => {
  const includeSearch = options.includeSearch !== false;
  const where = {};

  if (filters.patient_id) {
    where.patient_id = await resolveModelIdOrThrow({
      identifier: filters.patient_id,
      model: 'patient',
      where: { deleted_at: null },
      errorKey: 'errors.patient.not_found',
    });
  }

  if (filters.encounter_id) {
    where.encounter_id = await resolveModelIdOrThrow({
      identifier: filters.encounter_id,
      model: 'encounter',
      where: { deleted_at: null },
      errorKey: 'errors.encounter.not_found',
    });
  }

  if (filters.status) {
    where.status = filters.status;
  }

  if (filters.modality) {
    appendAnd(where, {
      OR: [
        { radiology_test: { modality: filters.modality } },
        { imaging_studies: { some: { deleted_at: null, modality: filters.modality } } },
      ],
    });
  }

  applyDateRangeFilter(where, 'ordered_at', filters.from, filters.to);

  const stage = normalizeEnumFilter(filters.stage, 'ALL');
  if (stage === 'ORDERED') {
    appendAnd(where, { status: 'ORDERED' });
  } else if (stage === 'PROCESSING') {
    appendAnd(where, { status: 'IN_PROCESS' });
  } else if (stage === 'REPORTING') {
    appendAnd(where, {
      status: { in: ['IN_PROCESS', 'COMPLETED'] },
      OR: [
        { results: { some: { deleted_at: null, status: 'DRAFT' } } },
        { results: { none: { deleted_at: null, status: 'FINAL' } } },
      ],
    });
  } else if (stage === 'COMPLETED') {
    appendAnd(where, { status: 'COMPLETED' });
  } else if (stage === 'CANCELLED') {
    appendAnd(where, { status: 'CANCELLED' });
  }

  const searchTerm = normalizeSearchTerm(filters.search);
  if (includeSearch && searchTerm) {
    appendAnd(where, {
      OR: [
        { human_friendly_id: { contains: searchTerm.upper } },
        { patient: { human_friendly_id: { contains: searchTerm.upper } } },
        { patient: { first_name: { contains: searchTerm.raw } } },
        { patient: { last_name: { contains: searchTerm.raw } } },
        { encounter: { human_friendly_id: { contains: searchTerm.upper } } },
        { radiology_test: { human_friendly_id: { contains: searchTerm.upper } } },
        { radiology_test: { name: { contains: searchTerm.raw } } },
        { radiology_test: { code: { contains: searchTerm.raw } } },
        { results: { some: { human_friendly_id: { contains: searchTerm.upper } } } },
        { imaging_studies: { some: { human_friendly_id: { contains: searchTerm.upper } } } },
        { imaging_studies: { some: { assets: { some: { file_name: { contains: searchTerm.raw } } } } } },
      ],
    });
  }

  return where;
};

const resolveRoleRecipients = async ({ tenantId, facilityId = null }) => {
  if (!tenantId || !prisma?.user_role?.findMany) return [];

  const rows = await prisma.user_role.findMany({
    where: {
      deleted_at: null,
      tenant_id: tenantId,
      role: {
        name: { in: RADIOLOGY_RECIPIENT_ROLES },
        deleted_at: null,
      },
      ...(facilityId ? { OR: [{ facility_id: null }, { facility_id: facilityId }] } : {}),
    },
    select: {
      user_id: true,
    },
  });

  return rows.map((item) => item.user_id).filter(Boolean);
};

const buildRadiologyRealtimePayload = ({
  workflow,
  action,
  resourceType = null,
  resourceId = null,
}) => {
  const order = workflow?.order || null;
  const orderId = String(order?.id || '').trim() || null;
  const patientId = String(order?.patient_id || '').trim() || null;
  const nowIso = new Date().toISOString();

  return {
    order_id: orderId,
    order_public_id: orderId,
    patient_id: patientId,
    patient_public_id: patientId,
    patient_display_name: order?.patient_display_name || null,
    status: order?.status || null,
    action: String(action || 'UPDATED').trim().toUpperCase(),
    resource_type: resourceType,
    resource_id: resourceId,
    occurred_at: nowIso,
    target_path: orderId ? `/radiology?id=${encodeURIComponent(orderId)}` : '/radiology',
    workflow,
  };
};

const publishRadiologyRealtimeUpdates = async ({
  workflow,
  orderRecord,
  actorUserId = null,
  action,
  resourceType = null,
  resourceId = null,
  resultRecord = null,
}) => {
  try {
    const tenantId = orderRecord?.patient?.tenant_id || null;
    if (!tenantId) return;

    const facilityId = orderRecord?.patient?.facility_id || null;
    const recipientUserIds = await resolveRoleRecipients({ tenantId, facilityId });
    const recipients = recipientUserIds.filter((userId) => userId && userId !== actorUserId);
    if (!recipients.length) return;

    const workflowPayload = buildRadiologyRealtimePayload({
      workflow,
      action,
      resourceType,
      resourceId,
    });

    emitToUsers(
      recipients,
      DIAGNOSTIC_EVENTS.RADIOLOGY_WORKFLOW_UPDATED,
      workflowPayload
    );

    if (!resultRecord) return;

    const resultStatus = String(resultRecord.status || '').trim().toUpperCase() || null;
    const resultPayload = {
      order_id: workflowPayload.order_id,
      order_public_id: workflowPayload.order_public_id,
      patient_id: workflowPayload.patient_id,
      patient_public_id: workflowPayload.patient_public_id,
      result_id: resultRecord.id || null,
      result_public_id: resultRecord.id || null,
      result_status: resultStatus,
      finalization_requested: Boolean(resultRecord.finalization?.requested),
      finalization_attested: Boolean(resultRecord.finalization?.attested),
      finalization_pending_attestation: Boolean(resultRecord.finalization?.pending_attestation),
      action: workflowPayload.action,
      occurred_at: workflowPayload.occurred_at,
      target_path: resultRecord.id
        ? `/radiology/results/${encodeURIComponent(resultRecord.id)}`
        : workflowPayload.target_path,
    };

    emitToUsers(
      recipients,
      DIAGNOSTIC_EVENTS.RADIOLOGY_RESULT_UPDATED,
      resultPayload
    );

    if (['FINAL', 'AMENDED'].includes(resultStatus || '')) {
      emitToUsers(
        recipients,
        DIAGNOSTIC_EVENTS.RADIOLOGY_RESULT_READY,
        resultPayload
      );
    }
  } catch (_error) {
    // realtime events must never block workflow updates
  }
};

const getRadiologyWorkbench = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { ordered_at: 'desc' };

    const [where, summaryWhere] = await Promise.all([
      buildWorkbenchOrderWhere(filters, { includeSearch: true }),
      buildWorkbenchOrderWhere(filters, { includeSearch: false }),
    ]);

    const [
      worklistRecords,
      total,
      totalOrders,
      orderedQueue,
      processingQueue,
      completedOrders,
      cancelledOrders,
      draftReports,
      finalizedReports,
      amendedReports,
      studiesTotal,
      unsyncedStudies,
    ] = await Promise.all([
      radiologyWorkspaceRepository.findManyOrders(
        where,
        skip,
        limit,
        orderBy,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      ),
      radiologyWorkspaceRepository.countOrders(where),
      radiologyWorkspaceRepository.countOrders(summaryWhere),
      radiologyWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: 'ORDERED',
      }),
      radiologyWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: 'IN_PROCESS',
      }),
      radiologyWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: 'COMPLETED',
      }),
      radiologyWorkspaceRepository.countOrders({
        ...summaryWhere,
        status: 'CANCELLED',
      }),
      radiologyWorkspaceRepository.countResults({
        status: 'DRAFT',
        radiology_order: {
          deleted_at: null,
          ...summaryWhere,
        },
      }),
      radiologyWorkspaceRepository.countResults({
        status: 'FINAL',
        radiology_order: {
          deleted_at: null,
          ...summaryWhere,
        },
      }),
      radiologyWorkspaceRepository.countResults({
        status: 'AMENDED',
        radiology_order: {
          deleted_at: null,
          ...summaryWhere,
        },
      }),
      radiologyWorkspaceRepository.countStudies({
        radiology_order: {
          deleted_at: null,
          ...summaryWhere,
        },
      }),
      radiologyWorkspaceRepository.countStudies({
        radiology_order: {
          deleted_at: null,
          ...summaryWhere,
        },
        pacs_links: {
          none: {
            deleted_at: null,
          },
        },
      }),
    ]);

    return {
      summary: {
        total_orders: totalOrders,
        ordered_queue: orderedQueue,
        processing_queue: processingQueue,
        draft_reports: draftReports,
        finalized_reports: finalizedReports,
        amended_reports: amendedReports,
        completed_orders: completedOrders,
        cancelled_orders: cancelledOrders,
        studies_total: studiesTotal,
        unsynced_studies: unsyncedStudies,
      },
      worklist: worklistRecords.map((record) => mapRadiologyOrderRecord(record)).filter(Boolean),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getRadiologyReferenceData = async (filters = {}, actorScope = {}) => {
  try {
    const limit = normalizeReferenceLimit(filters.limit);
    const searchTerm = normalizeSearchTerm(filters.search);
    const patientFilterId = await resolveModelIdOrThrow({
      identifier: filters.patient_id,
      model: 'patient',
      where: { deleted_at: null },
      errorKey: 'errors.patient.not_found',
      allowNull: true,
    });
    const scope = {
      tenantId: normalizeIdentifier(actorScope.tenant_id) || null,
      facilityId: normalizeIdentifier(actorScope.facility_id) || null,
    };

    const patientWhere = {
      ...buildScopedWhere(scope),
      ...(searchTerm
        ? {
            OR: [
              { human_friendly_id: { contains: searchTerm.upper } },
              { first_name: { contains: searchTerm.raw } },
              { last_name: { contains: searchTerm.raw } },
              { contacts: { some: { deleted_at: null, value: { contains: searchTerm.raw } } } },
            ],
          }
        : {}),
    };

    const encounterWhere = {
      ...(scope.tenantId ? { tenant_id: scope.tenantId } : {}),
      ...(scope.facilityId ? { facility_id: scope.facilityId } : {}),
      ...(patientFilterId ? { patient_id: patientFilterId } : {}),
      ...(searchTerm
        ? {
            OR: [
              { human_friendly_id: { contains: searchTerm.upper } },
              { patient: { human_friendly_id: { contains: searchTerm.upper } } },
              { patient: { first_name: { contains: searchTerm.raw } } },
              { patient: { last_name: { contains: searchTerm.raw } } },
            ],
          }
        : {}),
    };

    const testWhere = {
      ...(scope.tenantId ? { tenant_id: scope.tenantId } : {}),
      ...(searchTerm
        ? {
            OR: [
              { human_friendly_id: { contains: searchTerm.upper } },
              { name: { contains: searchTerm.raw } },
              { code: { contains: searchTerm.raw } },
              { modality: searchTerm.upper },
            ],
          }
        : {}),
    };

    const userWhere = {
      ...buildScopedWhere(scope),
      ...(searchTerm
        ? {
            OR: [
              { human_friendly_id: { contains: searchTerm.upper } },
              { email: { contains: searchTerm.raw } },
              { profile: { first_name: { contains: searchTerm.raw } } },
              { profile: { middle_name: { contains: searchTerm.raw } } },
              { profile: { last_name: { contains: searchTerm.raw } } },
            ],
          }
        : {}),
    };

    const [patients, encounters, tests, users] = await Promise.all([
      radiologyWorkspaceRepository.findReferencePatients({
        where: patientWhere,
        take: limit,
      }),
      radiologyWorkspaceRepository.findReferenceEncounters({
        where: encounterWhere,
        take: limit,
      }),
      radiologyWorkspaceRepository.findReferenceRadiologyTests({
        where: testWhere,
        take: limit,
      }),
      radiologyWorkspaceRepository.findReferenceUsers({
        where: userWhere,
        take: limit,
      }),
    ]);

    return {
      patients: patients.map(mapPatientReferenceOption).filter(Boolean),
      encounters: encounters.map(mapEncounterReferenceOption).filter(Boolean),
      radiology_tests: tests.map(mapTestReferenceOption).filter(Boolean),
      assignees: users.map(mapUserReferenceOption).filter(Boolean),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createRadiologyOrder = async (payload = {}, userId, ipAddress, actorScope = {}) => {
  try {
    const scope = {
      tenantId: normalizeIdentifier(actorScope.tenant_id) || null,
      facilityId: normalizeIdentifier(actorScope.facility_id) || null,
    };

    const patient = await resolveModelRecordOrThrow({
      identifier: payload.patient_id,
      model: 'patient',
      where: {
        deleted_at: null,
        ...buildScopedWhere(scope),
      },
      select: {
        id: true,
        tenant_id: true,
      },
      errorKey: 'errors.patient.not_found',
    });

    const encounterId = await resolveModelIdOrThrow({
      identifier: payload.encounter_id,
      model: 'encounter',
      where: {
        deleted_at: null,
        patient_id: patient.id,
      },
      errorKey: 'errors.encounter.not_found',
      allowNull: true,
    });

    const radiologyTestId = await resolveModelIdOrThrow({
      identifier: payload.radiology_test_id,
      model: 'radiology_test',
      where: {
        deleted_at: null,
        ...(patient?.tenant_id ? { tenant_id: patient.tenant_id } : {}),
      },
      errorKey: 'errors.radiology_test.not_found',
      allowNull: true,
    });

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txCreateOrder(tx, {
        patient_id: patient.id,
        encounter_id: encounterId || null,
        radiology_test_id: radiologyTestId || null,
        status: 'ORDERED',
        ordered_at: toDateOrNull(payload.ordered_at, new Date()),
      });

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        order: refreshedOrder,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'CREATE_ORDER',
      entity: 'radiology_order',
      entity_id: mutation.order?.id,
      diff: {
        metadata: {
          patient_id: mutation.order?.patient_id || patient.id,
          encounter_id: mutation.order?.encounter_id || null,
          radiology_test_id: mutation.order?.radiology_test_id || null,
          ordered_at: mutation.order?.ordered_at
            ? new Date(mutation.order.ordered_at).toISOString()
            : null,
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'CREATE_ORDER',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null,
    }).catch(() => {});

    return {
      workflow,
      order: mapRadiologyOrderRecord(mutation.order),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getRadiologyOrderWorkflow = async (identifier) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found',
    });

    const orderRecord = await radiologyWorkspaceRepository.findOrderById(
      orderId,
      RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
    );
    if (!orderRecord) {
      throw new HttpError('errors.radiology_order.not_found', 404);
    }

    return mapRadiologyOrderWorkflowRecord(orderRecord);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const assignRadiologyOrder = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found',
    });

    const orderRecord = await radiologyWorkspaceRepository.findOrderById(
      orderId,
      RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
    );
    if (!orderRecord) {
      throw new HttpError('errors.radiology_order.not_found', 404);
    }

    assertTransition(orderRecord.status !== 'CANCELLED', {
      from: orderRecord.status,
      to: 'ASSIGNED',
    });

    createAuditLog({
      user_id: userId,
      action: 'ASSIGN',
      entity: 'radiology_order',
      entity_id: orderId,
      diff: {
        metadata: {
          assignee_user_id: payload.assignee_user_id || null,
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(orderRecord);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord,
      actorUserId: userId || null,
      action: 'ASSIGN',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null,
    }).catch(() => {});

    return {
      workflow,
      assignment: {
        assignee_user_id: payload.assignee_user_id || null,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const startRadiologyOrder = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found',
    });

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      if (order.status === 'IN_PROCESS') {
        return {
          beforeStatus: order.status,
          order,
        };
      }

      assertTransition(order.status === 'ORDERED', {
        from: order.status,
        to: 'IN_PROCESS',
      });

      await radiologyWorkspaceRepository.txUpdateOrder(tx, order.id, {
        status: 'IN_PROCESS',
      });

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeStatus: order.status,
        order: refreshedOrder,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'START',
      entity: 'radiology_order',
      entity_id: orderId,
      diff: {
        metadata: {
          before_status: mutation.beforeStatus,
          after_status: mutation.order?.status,
          started_at: payload.started_at || new Date().toISOString(),
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'START',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null,
    }).catch(() => {});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const completeRadiologyOrder = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found',
    });

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      if (order.status === 'COMPLETED') {
        return {
          beforeStatus: order.status,
          order,
        };
      }

      assertTransition(order.status === 'IN_PROCESS', {
        from: order.status,
        to: 'COMPLETED',
      });

      const hasFinalResult = (order.results || []).some((entry) => entry.status === 'FINAL');
      assertTransition(hasFinalResult, {
        reason: 'FINAL_RESULT_REQUIRED',
      });

      await radiologyWorkspaceRepository.txUpdateOrder(tx, order.id, {
        status: 'COMPLETED',
      });

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeStatus: order.status,
        order: refreshedOrder,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'COMPLETE',
      entity: 'radiology_order',
      entity_id: orderId,
      diff: {
        metadata: {
          before_status: mutation.beforeStatus,
          after_status: mutation.order?.status,
          completed_at: payload.completed_at || new Date().toISOString(),
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'COMPLETE',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null,
    }).catch(() => {});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const cancelRadiologyOrder = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found',
    });

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      if (order.status === 'CANCELLED') {
        return {
          beforeStatus: order.status,
          order,
        };
      }

      assertTransition(order.status !== 'COMPLETED', {
        from: order.status,
        to: 'CANCELLED',
      });

      await radiologyWorkspaceRepository.txUpdateOrder(tx, order.id, {
        status: 'CANCELLED',
      });

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        beforeStatus: order.status,
        order: refreshedOrder,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'CANCEL',
      entity: 'radiology_order',
      entity_id: orderId,
      diff: {
        metadata: {
          reason: payload.reason || null,
          before_status: mutation.beforeStatus,
          after_status: mutation.order?.status,
          cancelled_at: payload.cancelled_at || new Date().toISOString(),
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'CANCEL',
      resourceType: 'order',
      resourceId: workflow?.order?.id || null,
    }).catch(() => {});

    return { workflow };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createRadiologyStudy = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found',
    });

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      assertTransition(order.status !== 'CANCELLED', {
        from: order.status,
        to: 'CREATE_STUDY',
      });

      const modality =
        String(payload.modality || '').trim().toUpperCase() ||
        String(order?.radiology_test?.modality || '').trim().toUpperCase() ||
        'XRAY';

      const study = await radiologyWorkspaceRepository.txCreateStudy(tx, {
        radiology_order_id: order.id,
        modality,
        performed_at: toDateOrNull(payload.performed_at, null),
      });

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        order: refreshedOrder,
        study,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'CREATE_STUDY',
      entity: 'imaging_study',
      entity_id: mutation.study?.id,
      diff: {
        metadata: {
          order_id: orderId,
          modality: mutation.study?.modality,
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const study = mapImagingStudyRecord(mutation.study);
    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'CREATE_STUDY',
      resourceType: 'study',
      resourceId: study?.id || null,
    }).catch(() => {});

    return {
      workflow,
      study,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const initStudyAssetUpload = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const studyId = await resolveModelIdOrThrow({
      identifier,
      model: 'imaging_study',
      where: { deleted_at: null },
      errorKey: 'errors.imaging_study.not_found',
    });

    const study = await radiologyWorkspaceRepository.findStudyById(
      studyId,
      RADIOLOGY_STUDY_WITH_RELATIONS_INCLUDE
    );
    if (!study) {
      throw new HttpError('errors.imaging_study.not_found', 404);
    }

    const storageKey = buildUploadStorageKey(study.id, payload.file_name);
    const uploadToken = crypto.randomUUID();

    createAuditLog({
      user_id: userId,
      action: 'INIT_UPLOAD',
      entity: 'imaging_asset',
      entity_id: study.id,
      diff: {
        metadata: {
          imaging_study_id: study.id,
          file_name: payload.file_name,
          content_type: payload.content_type || null,
          size_bytes: payload.size_bytes || null,
          storage_key: storageKey,
          storage_provider: STORAGE_PROVIDER,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return {
      imaging_study_id: toPublicIdentifier(study.human_friendly_id, study.id),
      upload_token: uploadToken,
      storage_key: storageKey,
      storage_provider: STORAGE_PROVIDER,
      upload_url: null,
      headers: {},
      expires_in_seconds: 900,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const commitStudyAssetUpload = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const studyId = await resolveModelIdOrThrow({
      identifier,
      model: 'imaging_study',
      where: { deleted_at: null },
      errorKey: 'errors.imaging_study.not_found',
    });

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const study = await radiologyWorkspaceRepository.txFindStudyById(
        tx,
        studyId,
        RADIOLOGY_STUDY_WITH_RELATIONS_INCLUDE
      );
      if (!study) {
        throw new HttpError('errors.imaging_study.not_found', 404);
      }

      const existingAsset = await radiologyWorkspaceRepository.txFindFirstAsset(tx, {
        imaging_study_id: study.id,
        storage_key: payload.storage_key,
      });

      const asset = existingAsset
        ? existingAsset
        : await radiologyWorkspaceRepository.txCreateAsset(tx, {
            imaging_study_id: study.id,
            storage_key: payload.storage_key,
            file_name: payload.file_name || null,
            content_type: payload.content_type || null,
          });

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        study.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        order,
        study,
        asset,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'COMMIT_UPLOAD',
      entity: 'imaging_asset',
      entity_id: mutation.asset?.id,
      diff: {
        metadata: {
          imaging_study_id: mutation.study?.id,
          storage_key: mutation.asset?.storage_key,
          file_name: mutation.asset?.file_name || null,
          content_type: mutation.asset?.content_type || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const assetId = toPublicIdentifier(mutation.asset?.human_friendly_id, mutation.asset?.id);

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'COMMIT_UPLOAD',
      resourceType: 'asset',
      resourceId: assetId,
    }).catch(() => {});

    return {
      workflow,
      asset: {
        id: assetId,
        display_id: assetId,
        storage_key: mutation.asset?.storage_key || null,
        file_name: mutation.asset?.file_name || null,
        content_type: mutation.asset?.content_type || null,
        created_at: mutation.asset?.created_at ? new Date(mutation.asset.created_at).toISOString() : null,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const syncStudyToPacs = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const studyId = await resolveModelIdOrThrow({
      identifier,
      model: 'imaging_study',
      where: { deleted_at: null },
      errorKey: 'errors.imaging_study.not_found',
    });

    const study = await radiologyWorkspaceRepository.findStudyById(
      studyId,
      RADIOLOGY_STUDY_WITH_RELATIONS_INCLUDE
    );
    if (!study) {
      throw new HttpError('errors.imaging_study.not_found', 404);
    }

    const orderRecord = await radiologyWorkspaceRepository.findOrderById(
      study.radiology_order_id,
      RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
    );
    if (!orderRecord) {
      throw new HttpError('errors.radiology_order.not_found', 404);
    }
    let workflowOrderRecord = orderRecord;

    let syncStatus = 'PENDING';
    let syncError = null;
    let pacsLinkRecord = null;
    let pacsResponse = null;

    try {
      if (!dicomWebClient.isConfigured()) {
        throw new Error('PACS_DICOMWEB_BASE_URL is not configured');
      }

      pacsResponse = await dicomWebClient.stowStudy({
        studyUid: payload.study_uid || null,
        metadata: Array.isArray(payload.metadata) ? payload.metadata : [],
        instances: Array.isArray(payload.instances) ? payload.instances : [],
      });

      const resolvedStudyUid =
        pacsResponse?.studyUid ||
        payload.study_uid ||
        toPublicIdentifier(study.human_friendly_id, study.id);
      const studyUrl = dicomWebClient.buildStudyUrl(resolvedStudyUid);

      const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
        const link = await radiologyWorkspaceRepository.txCreatePacsLink(tx, {
          imaging_study_id: study.id,
          url: studyUrl,
          expires_at: null,
        });

        const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
          tx,
          study.radiology_order_id,
          RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
        );

        return {
          link,
          order: refreshedOrder,
        };
      });

      pacsLinkRecord = mutation.link;
      syncStatus = 'SUCCESS';
      workflowOrderRecord = mutation.order;

      const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
      publishRadiologyRealtimeUpdates({
        workflow,
        orderRecord: mutation.order,
        actorUserId: userId || null,
        action: 'PACS_SYNC',
        resourceType: 'study',
        resourceId: toPublicIdentifier(study.human_friendly_id, study.id),
      }).catch(() => {});
    } catch (error) {
      syncStatus = 'FAILED';
      syncError = error.message;
    }

    createAuditLog({
      user_id: userId,
      action: 'PACS_SYNC',
      entity: 'imaging_study',
      entity_id: study.id,
      diff: {
        metadata: {
          imaging_study_id: study.id,
          status: syncStatus,
          study_uid: payload.study_uid || pacsResponse?.studyUid || null,
          error: syncError,
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(workflowOrderRecord);
    return {
      workflow,
      sync_status: syncStatus,
      pacs_link: pacsLinkRecord ? mapPacsLinkRecord(pacsLinkRecord) : null,
      error: syncError,
      response: pacsResponse,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const draftRadiologyResult = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const orderId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_order',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_order.not_found',
    });

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        orderId,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );
      if (!order) {
        throw new HttpError('errors.radiology_order.not_found', 404);
      }

      assertTransition(order.status !== 'CANCELLED', {
        from: order.status,
        to: 'DRAFT_RESULT',
      });

      const existingDraft = await radiologyWorkspaceRepository.txFindFirstResult(tx, {
        radiology_order_id: order.id,
        status: 'DRAFT',
      });
      const reportText = composeReportText({
        reportText: payload.report_text,
        findings: payload.findings,
        impression: payload.impression,
      });

      const result = existingDraft
        ? await radiologyWorkspaceRepository.txUpdateResult(tx, existingDraft.id, {
            report_text: reportText ?? existingDraft.report_text,
            reported_at: toDateOrNull(payload.reported_at, existingDraft.reported_at || null),
          })
        : await radiologyWorkspaceRepository.txCreateResult(tx, {
            radiology_order_id: order.id,
            status: 'DRAFT',
            report_text: reportText,
            reported_at: toDateOrNull(payload.reported_at, null),
          });

      if (order.status === 'ORDERED') {
        await radiologyWorkspaceRepository.txUpdateOrder(tx, order.id, {
          status: 'IN_PROCESS',
        });
      }

      const refreshedOrder = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        order.id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        order: refreshedOrder,
        result,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'DRAFT_RESULT',
      entity: 'radiology_result',
      entity_id: mutation.result?.id,
      diff: {
        metadata: {
          order_id: orderId,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const result = mapRadiologyResultRecord({
      ...mutation.result,
      radiology_order: mutation.order,
    });

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'DRAFT_RESULT',
      resourceType: 'result',
      resourceId: result?.id || null,
      resultRecord: result,
    }).catch(() => {});

    return {
      workflow,
      result,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const finalizeRadiologyResult = async (identifier, payload = {}, userId, ipAddress) => {
  if (RADIOLOGY_ATTESTATION_V2) {
    return attestRadiologyResultFinalization(
      identifier,
      {
        report_text: payload.report_text,
        reported_at: payload.reported_at,
        notes: payload.notes,
      },
      userId,
      null,
      ipAddress
    );
  }

  try {
    const resultId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_result',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_result.not_found',
    });

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const result = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        resultId,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );
      if (!result) {
        throw new HttpError('errors.radiology_result.not_found', 404);
      }

      if (result.status === 'FINAL') {
        const order = await radiologyWorkspaceRepository.txFindOrderById(
          tx,
          result.radiology_order_id,
          RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
        );
        return {
          result,
          order,
        };
      }

      assertTransition(result.status === 'DRAFT', {
        from: result.status,
        to: 'FINAL',
      });

      const updatedResult = await radiologyWorkspaceRepository.txUpdateResult(tx, result.id, {
        status: 'FINAL',
        report_text: payload.report_text || result.report_text || null,
        reported_at: toDateOrNull(payload.reported_at, new Date()),
      });

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        result.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        result: updatedResult,
        order,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'FINALIZE_RESULT',
      entity: 'radiology_result',
      entity_id: mutation.result?.id,
      diff: {
        metadata: {
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const result = mapRadiologyResultRecord({
      ...mutation.result,
      radiology_order: mutation.order,
    });

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'FINALIZE_RESULT',
      resourceType: 'result',
      resourceId: result?.id || null,
      resultRecord: result,
    }).catch(() => {});

    return {
      workflow,
      result,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const requestRadiologyResultFinalization = async (
  identifier,
  payload = {},
  userId,
  userRole,
  ipAddress
) => {
  try {
    const resultId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_result',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_result.not_found',
    });

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const result = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        resultId,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );
      if (!result) {
        throw new HttpError('errors.radiology_result.not_found', 404);
      }

      assertTransition(result.status === 'DRAFT', {
        from: result.status,
        to: 'REQUEST_FINALIZATION',
      });

      const existingRequest = await radiologyWorkspaceRepository.txFindResultAttestation(
        tx,
        result.id,
        'REQUEST'
      );

      if (!existingRequest) {
        await createResultAttestation({
          tx,
          resultId: result.id,
          phase: 'REQUEST',
          userId,
          userRole,
          statement: payload.statement,
          reason: payload.reason,
          ipAddress,
          attestedAt: payload.requested_at,
        });
      }

      const refreshedResult = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        result.id,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        result.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        result: refreshedResult,
        order,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'REQUEST_FINALIZE_RESULT',
      entity: 'radiology_result',
      entity_id: mutation.result?.id,
      diff: {
        metadata: {
          reason: payload.reason || null,
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const result = mapRadiologyResultRecord({
      ...mutation.result,
      radiology_order: mutation.order,
    });

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'REQUEST_FINALIZATION',
      resourceType: 'result',
      resourceId: result?.id || null,
      resultRecord: result,
    }).catch(() => {});

    return {
      workflow,
      result,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const attestRadiologyResultFinalization = async (
  identifier,
  payload = {},
  userId,
  userRole,
  ipAddress
) => {
  try {
    const resultId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_result',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_result.not_found',
    });

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const result = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        resultId,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );
      if (!result) {
        throw new HttpError('errors.radiology_result.not_found', 404);
      }

      assertTransition(['DRAFT', 'FINAL'].includes(result.status), {
        from: result.status,
        to: 'ATTEST_FINALIZATION',
      });

      const requestAttestation = await radiologyWorkspaceRepository.txFindResultAttestation(
        tx,
        result.id,
        'REQUEST'
      );
      assertTransition(Boolean(requestAttestation), {
        reason: 'request_finalization_required',
        result_id: result.id,
      });

      if (String(requestAttestation.attested_by_user_id || '') === String(userId || '')) {
        throw new HttpError('errors.radiology_workspace.attestation.same_user', 400);
      }

      const existingAttestation = await radiologyWorkspaceRepository.txFindResultAttestation(
        tx,
        result.id,
        'ATTEST'
      );

      let updatedResult = result;
      if (!existingAttestation && result.status !== 'FINAL') {
        updatedResult = await radiologyWorkspaceRepository.txUpdateResult(tx, result.id, {
          status: 'FINAL',
          report_text: payload.report_text || result.report_text || null,
          reported_at: toDateOrNull(payload.reported_at, new Date()),
        });
      }

      if (!existingAttestation) {
        await createResultAttestation({
          tx,
          resultId: result.id,
          phase: 'ATTEST',
          userId,
          userRole,
          statement: payload.statement,
          reason: payload.reason,
          ipAddress,
          attestedAt: payload.attested_at,
        });
      }

      const refreshedResult = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        result.id,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        updatedResult.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        result: refreshedResult,
        order,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'ATTEST_FINALIZE_RESULT',
      entity: 'radiology_result',
      entity_id: mutation.result?.id,
      diff: {
        metadata: {
          reason: payload.reason || null,
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const result = mapRadiologyResultRecord({
      ...mutation.result,
      radiology_order: mutation.order,
    });

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'ATTEST_FINALIZATION',
      resourceType: 'result',
      resourceId: result?.id || null,
      resultRecord: result,
    }).catch(() => {});

    return {
      workflow,
      result,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const addendumRadiologyResult = async (identifier, payload = {}, userId, ipAddress) => {
  try {
    const resultId = await resolveModelIdOrThrow({
      identifier,
      model: 'radiology_result',
      where: { deleted_at: null },
      errorKey: 'errors.radiology_result.not_found',
    });

    const mutation = await radiologyWorkspaceRepository.withTransaction(async (tx) => {
      const baseResult = await radiologyWorkspaceRepository.txFindResultById(
        tx,
        resultId,
        RADIOLOGY_RESULT_WITH_RELATIONS_INCLUDE
      );
      if (!baseResult) {
        throw new HttpError('errors.radiology_result.not_found', 404);
      }

      assertTransition(baseResult.status === 'FINAL', {
        from: baseResult.status,
        to: 'AMENDED',
      });

      const amendedResult = await radiologyWorkspaceRepository.txCreateResult(tx, {
        radiology_order_id: baseResult.radiology_order_id,
        status: 'AMENDED',
        report_text: composeAddendumText(baseResult.report_text, payload.addendum_text),
        reported_at: toDateOrNull(payload.reported_at, new Date()),
      });

      const order = await radiologyWorkspaceRepository.txFindOrderById(
        tx,
        baseResult.radiology_order_id,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      );

      return {
        result: amendedResult,
        order,
      };
    });

    createAuditLog({
      user_id: userId,
      action: 'ADDENDUM_RESULT',
      entity: 'radiology_result',
      entity_id: mutation.result?.id,
      diff: {
        metadata: {
          base_result_id: resultId,
          notes: payload.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    const workflow = mapRadiologyOrderWorkflowRecord(mutation.order);
    const result = mapRadiologyResultRecord({
      ...mutation.result,
      radiology_order: mutation.order,
    });

    publishRadiologyRealtimeUpdates({
      workflow,
      orderRecord: mutation.order,
      actorUserId: userId || null,
      action: 'ADDENDUM_RESULT',
      resourceType: 'result',
      resourceId: result?.id || null,
      resultRecord: result,
    }).catch(() => {});

    return {
      workflow,
      result,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const resolveLegacyRouteIdentifier = async (resource, identifier) => {
  try {
    const normalizedResource = String(resource || '').trim().toLowerCase();
    const normalizedIdentifier = normalizeIdentifier(identifier);
    if (!normalizedIdentifier) {
      throw new HttpError('errors.resource.not_found', 404);
    }

    const config = LEGACY_ROUTE_CONFIG[normalizedResource];
    if (!config) {
      throw new HttpError('errors.resource.not_found', 404);
    }

    const record = await resolveModelRecordOrThrow({
      identifier: normalizedIdentifier,
      model: config.model,
      where: { deleted_at: null },
      select: {
        id: true,
        human_friendly_id: true,
      },
      errorKey: 'errors.resource.not_found',
    });

    const publicIdentifier = toPublicIdentifier(record?.human_friendly_id, normalizedIdentifier);
    const safeIdentifier =
      publicIdentifier ||
      (isUuidLike(normalizedIdentifier)
        ? null
        : String(normalizedIdentifier).trim().toUpperCase());

    if (!safeIdentifier) {
      throw new HttpError('errors.resource.not_found', 404);
    }

    return {
      id: safeIdentifier,
      resource: config.resource,
      identifier: safeIdentifier,
      route: `${config.route}/${encodeURIComponent(safeIdentifier)}`,
      matched_by: isUuidLike(normalizedIdentifier) ? 'uuid' : 'human_friendly_id',
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  getRadiologyWorkbench,
  getRadiologyReferenceData,
  createRadiologyOrder,
  getRadiologyOrderWorkflow,
  assignRadiologyOrder,
  startRadiologyOrder,
  completeRadiologyOrder,
  cancelRadiologyOrder,
  createRadiologyStudy,
  initStudyAssetUpload,
  commitStudyAssetUpload,
  syncStudyToPacs,
  draftRadiologyResult,
  finalizeRadiologyResult,
  requestRadiologyResultFinalization,
  attestRadiologyResultFinalization,
  addendumRadiologyResult,
  resolveLegacyRouteIdentifier,
};
