const crypto = require('crypto');
const prisma = require('@prisma/client');
const patientReportRepository = require('@repositories/patient-report/patient-report.repository');
const { createAuditLog } = require('@lib/audit');
const { PERMISSIONS } = require('@config/permissions');
const { HttpError } = require('@lib/errors');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { createPublicId } = require('@lib/last-office/shared');
const { generateReportFile } = require('@lib/reports/files');
const { createStorageService } = require('@lib/storage');
const { getUserPermissions } = require('@middlewares/auth.middleware');
const { recordBackgroundJob } = require('@lib/telemetry/metrics');
const { logger } = require('@lib/logging');
const {
  REPORT_ACTIONS,
  REPORT_TYPES,
  filterAuthorizedSections,
  isSectionAuthorized,
  listAuthorizedSectionDefs,
  SECTION_BY_ID,
} = require('@lib/patient-reports/sections');

const JOB_TTL_MS = 24 * 60 * 60 * 1000;
const LARGE_REPORT_ROW_THRESHOLD = 200;

const buildContext = (req = {}) => ({
  tenant_id: req.user?.tenant_id || req.tenant_id || null,
  facility_id: req.user?.facility_id || req.facility_id || null,
  user_id: req.user?.id || req.user_id || null,
  user: req.user || null,
  ip_address: req.ip || req.ip_address || null,
  user_agent: req.get?.('user-agent') || req.user_agent || null,
  permissions: getUserPermissions(req.user || req),
});

const resolvePatientId = async (identifier, tenantId) => {
  const resolved = await resolveModelIdByIdentifier({
    model: 'patient',
    identifier,
    where: tenantId ? { tenant_id: tenantId } : undefined,
  });
  return resolved || null;
};

const resolveEncounterId = async (identifier, tenantId, patientId) => {
  if (!identifier) return null;
  const resolved = await resolveModelIdByIdentifier({
    model: 'encounter',
    identifier,
    where: {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(patientId ? { patient_id: patientId } : {}),
    },
  });
  return resolved || null;
};

const resolveJobId = async (identifier) => {
  const resolved = await resolveModelIdByIdentifier({
    model: 'patient_report_job',
    identifier,
  });
  return resolved || identifier;
};

const ensureScopedJob = (record, context = {}) => {
  if (!record || record.deleted_at) {
    throw new HttpError('errors.patient_report.not_found', 404);
  }
  if (context.tenant_id && record.tenant_id !== context.tenant_id) {
    throw new HttpError('errors.patient_report.not_found', 404);
  }
  if (
    context.facility_id &&
    record.facility_id &&
    record.facility_id !== context.facility_id
  ) {
    throw new HttpError('errors.patient_report.not_found', 404);
  }
  return record;
};

const assertPatientAccess = async (patientId, context = {}) => {
  const patient = await prisma.patient.findFirst({
    where: {
      id: patientId,
      deleted_at: null,
      ...(context.tenant_id ? { tenant_id: context.tenant_id } : {}),
      ...(context.facility_id ? { facility_id: context.facility_id } : {}),
    },
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
      facility_id: true,
      first_name: true,
      last_name: true,
    },
  });
  if (!patient) {
    throw new HttpError('errors.patient.not_found', 404);
  }
  return patient;
};

const assertStillAuthorized = (context = {}) => {
  const permissions = context.permissions || getUserPermissions(context.user || context);
  if (!permissions.includes(PERMISSIONS.PATIENT_READ)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }
  return permissions;
};

const parsePeriod = (period = {}) => {
  const mode = String(period.mode || 'all_dates').trim().toLowerCase();
  const singleDate = period.single_date ? new Date(period.single_date) : null;
  const startDate = period.start_date ? new Date(period.start_date) : null;
  const endDate = period.end_date ? new Date(period.end_date) : null;

  if (mode === 'single_date' && singleDate && !Number.isNaN(singleDate.getTime())) {
    const start = new Date(singleDate);
    start.setUTCHours(0, 0, 0, 0);
    const end = new Date(singleDate);
    end.setUTCHours(23, 59, 59, 999);
    return { mode, start, end };
  }

  if (mode === 'date_range' && startDate && endDate) {
    if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'period' }]);
    }
    if (startDate > endDate) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'period' }]);
    }
    const start = new Date(startDate);
    start.setUTCHours(0, 0, 0, 0);
    const end = new Date(endDate);
    end.setUTCHours(23, 59, 59, 999);
    return { mode, start, end };
  }

  return { mode: 'all_dates', start: null, end: null };
};

const withPeriod = (where, field, period) => {
  if (!period?.start || !period?.end) return where;
  return {
    ...where,
    [field]: { gte: period.start, lte: period.end },
  };
};

const encounterScopedWhere = (patientId, encounterId) => ({
  patient_id: patientId,
  deleted_at: null,
  ...(encounterId ? { id: encounterId } : {}),
});

const countSectionData = async ({
  sectionId,
  patientId,
  encounterId,
  period,
}) => {
  const patientBase = {
    deleted_at: null,
    patient_id: patientId,
    ...(encounterId ? { encounter_id: encounterId } : {}),
  };

  switch (sectionId) {
    case 'patient_information':
      return 1;
    case 'encounter_details':
      return prisma.encounter.count({
        where: withPeriod(
          encounterScopedWhere(patientId, encounterId),
          'started_at',
          period
        ),
      });
    case 'vitals':
      return prisma.vital_sign.count({
        where: withPeriod(
          {
            deleted_at: null,
            encounter: encounterScopedWhere(patientId, encounterId),
          },
          'recorded_at',
          period
        ),
      });
    case 'clinical_notes':
    case 'doctors_notes':
    case 'findings':
      return prisma.clinical_note.count({
        where: withPeriod(
          {
            deleted_at: null,
            encounter: encounterScopedWhere(patientId, encounterId),
          },
          'created_at',
          period
        ),
      });
    case 'diagnoses':
      return prisma.diagnosis.count({
        where: withPeriod(
          {
            deleted_at: null,
            encounter: encounterScopedWhere(patientId, encounterId),
          },
          'created_at',
          period
        ),
      });
    case 'laboratory_results':
      return prisma.lab_result.count({
        where: withPeriod(
          {
            deleted_at: null,
            lab_order_item: {
              deleted_at: null,
              lab_order: patientBase,
            },
          },
          'created_at',
          period
        ),
      });
    case 'radiology_reports':
      return prisma.radiology_result.count({
        where: withPeriod(
          {
            deleted_at: null,
            radiology_order: patientBase,
          },
          'created_at',
          period
        ),
      });
    case 'procedures':
      return prisma.procedure.count({
        where: withPeriod(
          {
            deleted_at: null,
            encounter: encounterScopedWhere(patientId, encounterId),
          },
          'created_at',
          period
        ),
      });
    case 'prescriptions':
    case 'medications':
      return prisma.pharmacy_order.count({
        where: withPeriod(patientBase, 'ordered_at', period),
      });
    case 'billing_information':
      return prisma.invoice.count({
        where: withPeriod(
          { deleted_at: null, patient_id: patientId },
          'issued_at',
          period
        ),
      });
    case 'appointments':
      return prisma.appointment.count({
        where: withPeriod(
          { deleted_at: null, patient_id: patientId },
          'scheduled_start',
          period
        ),
      });
    case 'admissions':
      return prisma.admission.count({
        where: withPeriod(patientBase, 'admitted_at', period),
      });
    case 'allergies':
      return prisma.patient_allergy.count({
        where: { deleted_at: null, patient_id: patientId },
      });
    case 'medical_history':
      return prisma.patient_medical_history.count({
        where: { deleted_at: null, patient_id: patientId },
      });
    case 'identifiers':
      return prisma.patient_identifier.count({
        where: { deleted_at: null, patient_id: patientId },
      });
    case 'contacts':
      return prisma.patient_contact.count({
        where: { deleted_at: null, patient_id: patientId },
      });
    case 'guardians':
      return prisma.patient_guardian.count({
        where: { deleted_at: null, patient_id: patientId },
      });
    case 'documents':
      return prisma.patient_document.count({
        where: { deleted_at: null, patient_id: patientId },
      });
    case 'consents':
      return prisma.consent.count({
        where: { deleted_at: null, patient_id: patientId },
      });
    default:
      return 0;
  }
};

const recordPhiReportAccess = async ({
  patient,
  context,
  reportType,
  action,
  sections = [],
}) => {
  const userId = context.user_id;
  if (!userId || !patient?.id) return;

  const reason = `report:${reportType}:${action}`.slice(0, 255);

  try {
    const created = await prisma.phi_access_log.create({
      data: {
        tenant_id: patient.tenant_id,
        user_id: userId,
        patient_id: patient.id,
        access_scope: 'PATIENT',
        reason,
      },
    });

    await createAuditLog({
      tenant_id: patient.tenant_id,
      facility_id: patient.facility_id,
      user_id: userId,
      action: 'ACCESS',
      entity: 'phi_access_log',
      entity_id: created.id,
      diff: {
        after: {
          patient_id: resolvePublicIdentifier(patient.human_friendly_id, patient.id),
          report_type: reportType,
          action,
          sections,
          accessed_at: created.accessed_at,
        },
      },
      ip_address: context.ip_address,
      user_agent: context.user_agent,
    });
  } catch (error) {
    logger.warn('Patient report PHI access log skipped', {
      patient_id: patient.id,
      report_type: reportType,
      action,
      error: error?.message || 'Unknown error',
    });
  }
};

const serializeJob = (record) => {
  const downloadAvailable =
    record?.status === 'READY' && Boolean(record?.output_storage_path);

  return {
    id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
    human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
    tenant_id: resolvePublicIdentifier(record?.tenant?.human_friendly_id, record?.tenant_id),
    facility_id: resolvePublicIdentifier(
      record?.facility?.human_friendly_id,
      record?.facility_id
    ),
    patient_id: resolvePublicIdentifier(
      record?.patient?.human_friendly_id,
      record?.patient_id
    ),
    encounter_id: resolvePublicIdentifier(
      record?.encounter?.human_friendly_id,
      record?.encounter_id
    ),
    requested_by_user_id: resolvePublicIdentifier(
      record?.requested_by?.human_friendly_id,
      record?.requested_by_user_id
    ),
    report_type: record?.report_type || null,
    action: record?.action || null,
    status: record?.status || null,
    format: record?.format || 'PDF',
    sections: Array.isArray(record?.sections_json) ? record.sections_json : [],
    period: record?.period_json || null,
    output_file_name: record?.output_file_name || null,
    output_mime_type: record?.output_mime_type || null,
    output_size_bytes: record?.output_size_bytes ?? null,
    download_available: downloadAvailable,
    error_message: record?.error_message || null,
    queued_at: record?.queued_at || null,
    started_at: record?.started_at || null,
    completed_at: record?.completed_at || null,
    expires_at: record?.expires_at || null,
    created_at: record?.created_at || null,
    updated_at: record?.updated_at || null,
    version: Number(record?.version || 1),
  };
};

const buildStoragePath = (tenantId, fileName, createdAt = new Date()) => {
  const year = String(createdAt.getUTCFullYear());
  const month = String(createdAt.getUTCMonth() + 1).padStart(2, '0');
  return `patient-reports/${tenantId}/${year}/${month}/${fileName}`;
};

const buildReportRows = async ({
  patient,
  encounterId,
  sections,
  period,
  permissions,
}) => {
  const rows = [];
  const authorized = filterAuthorizedSections(sections, permissions);

  rows.push({
    section: 'patient_information',
    field: 'patient_id',
    value: resolvePublicIdentifier(patient.human_friendly_id, patient.id),
    occurred_at: null,
  });
  rows.push({
    section: 'patient_information',
    field: 'patient_name',
    value: [patient.first_name, patient.last_name].filter(Boolean).join(' '),
    occurred_at: null,
  });

  for (const sectionId of authorized) {
    if (sectionId === 'patient_information') continue;
    if (!isSectionAuthorized(sectionId, permissions)) continue;

    const count = await countSectionData({
      sectionId,
      patientId: patient.id,
      encounterId,
      period,
    });

    rows.push({
      section: sectionId,
      field: 'record_count',
      value: String(count),
      occurred_at: null,
    });

    if (count <= 0) continue;

    // Authoritative module summaries only — no unauthorized nested PHI fields.
    if (sectionId === 'encounter_details') {
      const encounters = await prisma.encounter.findMany({
        where: withPeriod(
          {
            deleted_at: null,
            patient_id: patient.id,
            ...(encounterId ? { id: encounterId } : {}),
          },
          'started_at',
          period
        ),
        select: {
          human_friendly_id: true,
          encounter_type: true,
          status: true,
          started_at: true,
          ended_at: true,
        },
        orderBy: { started_at: 'asc' },
        take: 100,
      });
      encounters.forEach((entry) => {
        rows.push({
          section: sectionId,
          field: 'encounter',
          value: [
            resolvePublicIdentifier(entry.human_friendly_id, null),
            entry.encounter_type,
            entry.status,
            entry.started_at?.toISOString?.() || '',
          ]
            .filter(Boolean)
            .join(' | '),
          occurred_at: entry.started_at,
        });
      });
    }

    if (sectionId === 'vitals') {
      const vitals = await prisma.vital_sign.findMany({
        where: withPeriod(
          {
            deleted_at: null,
            encounter: encounterScopedWhere(patient.id, encounterId),
          },
          'recorded_at',
          period
        ),
        select: {
          human_friendly_id: true,
          recorded_at: true,
          vital_type: true,
          value: true,
          unit: true,
        },
        orderBy: { recorded_at: 'asc' },
        take: 100,
      });
      vitals.forEach((entry) => {
        rows.push({
          section: sectionId,
          field: 'vital_sign',
          value: [
            resolvePublicIdentifier(entry.human_friendly_id, null),
            entry.vital_type,
            entry.value,
            entry.unit,
          ]
            .filter(Boolean)
            .join(' | '),
          occurred_at: entry.recorded_at,
        });
      });
    }

    if (sectionId === 'laboratory_results') {
      const results = await prisma.lab_result.findMany({
        where: withPeriod(
          {
            deleted_at: null,
            lab_order_item: {
              deleted_at: null,
              lab_order: {
                deleted_at: null,
                patient_id: patient.id,
                ...(encounterId ? { encounter_id: encounterId } : {}),
              },
            },
          },
          'created_at',
          period
        ),
        select: {
          human_friendly_id: true,
          status: true,
          created_at: true,
        },
        orderBy: { created_at: 'asc' },
        take: 100,
      });
      results.forEach((entry) => {
        rows.push({
          section: sectionId,
          field: 'lab_result',
          value: [
            resolvePublicIdentifier(entry.human_friendly_id, null),
            entry.status,
          ]
            .filter(Boolean)
            .join(' | '),
          occurred_at: entry.created_at,
        });
      });
    }

    if (sectionId === 'radiology_reports') {
      const results = await prisma.radiology_result.findMany({
        where: withPeriod(
          {
            deleted_at: null,
            radiology_order: {
              patient_id: patient.id,
              deleted_at: null,
              ...(encounterId ? { encounter_id: encounterId } : {}),
            },
          },
          'created_at',
          period
        ),
        select: {
          human_friendly_id: true,
          status: true,
          created_at: true,
        },
        orderBy: { created_at: 'asc' },
        take: 100,
      });
      results.forEach((entry) => {
        rows.push({
          section: sectionId,
          field: 'radiology_result',
          value: [
            resolvePublicIdentifier(entry.human_friendly_id, null),
            entry.status,
          ]
            .filter(Boolean)
            .join(' | '),
          occurred_at: entry.created_at,
        });
      });
    }

    if (sectionId === 'billing_information') {
      const invoices = await prisma.invoice.findMany({
        where: withPeriod(
          {
            deleted_at: null,
            patient_id: patient.id,
          },
          'issued_at',
          period
        ),
        select: {
          human_friendly_id: true,
          status: true,
          total_amount: true,
          currency: true,
          issued_at: true,
        },
        orderBy: { issued_at: 'asc' },
        take: 100,
      });
      invoices.forEach((entry) => {
        rows.push({
          section: sectionId,
          field: 'invoice',
          value: [
            resolvePublicIdentifier(entry.human_friendly_id, null),
            entry.status,
            entry.total_amount != null ? String(entry.total_amount) : null,
            entry.currency,
          ]
            .filter(Boolean)
            .join(' | '),
          occurred_at: entry.issued_at,
        });
      });
    }
  }

  rows.sort((left, right) => {
    const leftTime = left.occurred_at ? new Date(left.occurred_at).getTime() : 0;
    const rightTime = right.occurred_at ? new Date(right.occurred_at).getTime() : 0;
    if (leftTime !== rightTime) return leftTime - rightTime;
    return String(left.section).localeCompare(String(right.section));
  });

  return rows.map(({ section, field, value }) => ({ section, field, value }));
};

const processJob = async (jobId, context = {}) => {
  const record = await patientReportRepository.findById(jobId);
  if (!record || record.deleted_at) return null;

  try {
    const permissions = assertStillAuthorized(context);
    const patient = await assertPatientAccess(record.patient_id, context);
    const period = parsePeriod(record.period_json || {});
    const sections = Array.isArray(record.sections_json) ? record.sections_json : [];
    const authorizedSections = filterAuthorizedSections(sections, permissions);

    if (authorizedSections.length === 0) {
      throw new HttpError('errors.patient_report.unauthorized_sections', 403);
    }

    await patientReportRepository.update(jobId, {
      status: 'PROCESSING',
      started_at: new Date(),
      version: Number(record.version || 1) + 1,
    });

    const rows = await buildReportRows({
      patient,
      encounterId: record.encounter_id,
      sections: authorizedSections,
      period,
      permissions,
    });

    const rendered = await generateReportFile({
      title: `Patient Report ${resolvePublicIdentifier(patient.human_friendly_id, patient.id)}`,
      subtitle: `${record.report_type} · ${authorizedSections.join(', ')}`,
      columns: ['section', 'field', 'value'],
      rows,
      format: record.format || 'PDF',
    });

    const checksum = crypto.createHash('sha256').update(rendered.buffer).digest('hex');
    const storage = createStorageService();
    const storagePath = buildStoragePath(
      record.tenant_id,
      rendered.file_name,
      new Date()
    );
    const uploaded = await storage.upload(rendered.buffer, storagePath, {
      mimeType: rendered.mime_type,
      encrypt: true,
      metadata: {
        patient_report_job_id: record.id,
        patient_id: patient.id,
        report_type: record.report_type,
      },
    });

    const updated = await patientReportRepository.update(jobId, {
      status: 'READY',
      sections_json: authorizedSections,
      output_storage_path: uploaded?.path || storagePath,
      output_file_name: rendered.file_name,
      output_mime_type: rendered.mime_type,
      output_size_bytes: rendered.size_bytes,
      checksum,
      error_message: null,
      completed_at: new Date(),
      expires_at: new Date(Date.now() + JOB_TTL_MS),
      version: Number(record.version || 1) + 2,
    });

    await createAuditLog({
      tenant_id: updated.tenant_id,
      facility_id: updated.facility_id,
      user_id: context.user_id,
      action: 'UPDATE',
      entity: 'patient_report_job',
      entity_id: updated.id,
      diff: { after: serializeJob(updated) },
      ip_address: context.ip_address,
      user_agent: context.user_agent,
    });

    recordBackgroundJob('patient_report_job.completed', {
      'hms.patient_report_job.id':
        updated.human_friendly_id || updated.id,
      'hms.patient_report_job.status': updated.status,
    });

    return serializeJob(updated);
  } catch (error) {
    const failed = await patientReportRepository.update(jobId, {
      status: 'FAILED',
      error_message: error?.message || 'Report generation failed',
      completed_at: new Date(),
      version: Number(record.version || 1) + 1,
    });

    await createAuditLog({
      tenant_id: failed.tenant_id,
      facility_id: failed.facility_id,
      user_id: context.user_id,
      action: 'UPDATE',
      entity: 'patient_report_job',
      entity_id: failed.id,
      diff: { after: serializeJob(failed) },
      ip_address: context.ip_address,
      user_agent: context.user_agent,
    });

    recordBackgroundJob('patient_report_job.failed', {
      'hms.patient_report_job.id': failed.human_friendly_id || failed.id,
    });

    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.patient_report.generation_failed', 500);
  }
};

const listSections = async (query = {}, context = {}) => {
  const permissions = assertStillAuthorized(context);
  const patientId = await resolvePatientId(query.patient_id, context.tenant_id);
  if (!patientId) {
    throw new HttpError('errors.patient.not_found', 404);
  }

  const patient = await assertPatientAccess(patientId, context);
  const encounterId = await resolveEncounterId(
    query.encounter_id,
    context.tenant_id,
    patient.id
  );
  const period = parsePeriod(query.period || {
    mode: query.period_mode,
    single_date: query.single_date,
    start_date: query.start_date,
    end_date: query.end_date,
  });

  const defs = listAuthorizedSectionDefs(permissions);
  const sections = [];

  for (const def of defs) {
    const count = await countSectionData({
      sectionId: def.id,
      patientId: patient.id,
      encounterId,
      period,
    });
    const hasData = count > 0 || Boolean(def.always_available);
    sections.push({
      id: def.id,
      sort_order: def.sort_order,
      authorized: true,
      has_data: hasData,
      count,
      enabled: hasData,
      selected_by_default: hasData,
    });
  }

  await recordPhiReportAccess({
    patient,
    context,
    reportType: encounterId
      ? REPORT_TYPES.ENCOUNTER_CLINICAL
      : REPORT_TYPES.PATIENT_CLINICAL,
    action: REPORT_ACTIONS.ACCESS,
    sections: sections.map((entry) => entry.id),
  });

  return {
    patient_id: resolvePublicIdentifier(patient.human_friendly_id, patient.id),
    encounter_id: encounterId
      ? resolvePublicIdentifier(null, encounterId)
      : null,
    report_type: encounterId
      ? REPORT_TYPES.ENCOUNTER_CLINICAL
      : REPORT_TYPES.PATIENT_CLINICAL,
    sections: sections.sort((a, b) => a.sort_order - b.sort_order),
  };
};

const createJob = async (payload = {}, context = {}) => {
  const permissions = assertStillAuthorized(context);
  const patientId = await resolvePatientId(payload.patient_id, context.tenant_id);
  if (!patientId) {
    throw new HttpError('errors.patient.not_found', 404);
  }

  const patient = await assertPatientAccess(patientId, context);
  const encounterId = await resolveEncounterId(
    payload.encounter_id,
    context.tenant_id,
    patient.id
  );
  const period = parsePeriod(payload.period || {});
  const requestedSections = Array.isArray(payload.sections)
    ? payload.sections.map((value) => String(value || '').trim()).filter(Boolean)
    : [];

  const unauthorized = requestedSections.filter(
    (sectionId) => !SECTION_BY_ID[sectionId] || !isSectionAuthorized(sectionId, permissions)
  );
  if (unauthorized.length > 0) {
    throw new HttpError('errors.patient_report.unauthorized_sections', 403, [
      { field: 'sections', sections: unauthorized },
    ]);
  }

  const authorizedSections = filterAuthorizedSections(requestedSections, permissions);
  if (authorizedSections.length === 0) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'sections' }]);
  }

  // Drop empty non-always sections from generation payload.
  const effectiveSections = [];
  for (const sectionId of authorizedSections) {
    const def = SECTION_BY_ID[sectionId];
    const count = await countSectionData({
      sectionId,
      patientId: patient.id,
      encounterId,
      period,
    });
    if (count > 0 || def?.always_available) {
      effectiveSections.push(sectionId);
    }
  }

  if (effectiveSections.length === 0) {
    throw new HttpError('errors.patient_report.no_printable_sections', 422);
  }

  const reportType =
    payload.report_type ||
    (encounterId ? REPORT_TYPES.ENCOUNTER_CLINICAL : REPORT_TYPES.PATIENT_CLINICAL);
  const action = String(payload.action || REPORT_ACTIONS.GENERATE).toLowerCase();
  const format = String(payload.format || 'PDF').toUpperCase();
  const publicId = createPublicId('PRJ');

  const job = await patientReportRepository.create({
    human_friendly_id: publicId,
    tenant_id: patient.tenant_id,
    facility_id: patient.facility_id,
    patient_id: patient.id,
    encounter_id: encounterId,
    requested_by_user_id: context.user_id,
    report_type: reportType,
    action,
    status: 'QUEUED',
    format,
    sections_json: effectiveSections,
    period_json: payload.period || {
      mode: period.mode,
      start_date: period.start,
      end_date: period.end,
    },
    queued_at: new Date(),
    expires_at: new Date(Date.now() + JOB_TTL_MS),
  });

  await createAuditLog({
    tenant_id: job.tenant_id,
    facility_id: job.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'patient_report_job',
    entity_id: job.id,
    diff: { after: serializeJob(job) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  await recordPhiReportAccess({
    patient,
    context,
    reportType,
    action,
    sections: effectiveSections,
  });

  recordBackgroundJob('patient_report_job.queued', {
    'hms.patient_report_job.id': publicId,
    'hms.patient_report_job.report_type': reportType,
  });

  // Estimate size; large reports stay async via setImmediate.
  let estimatedRows = 0;
  for (const sectionId of effectiveSections) {
    estimatedRows += await countSectionData({
      sectionId,
      patientId: patient.id,
      encounterId,
      period,
    });
  }

  if (estimatedRows >= LARGE_REPORT_ROW_THRESHOLD || payload.async === true) {
    setImmediate(() => {
      processJob(job.id, context).catch((error) => {
        logger.warn('Async patient report job failed', {
          job_id: job.id,
          error: error?.message || 'Unknown error',
        });
      });
    });
    return serializeJob(job);
  }

  return processJob(job.id, context);
};

const getJobById = async (id, context = {}) => {
  assertStillAuthorized(context);
  const resolvedId = await resolveJobId(id);
  const record = ensureScopedJob(
    await patientReportRepository.findById(resolvedId),
    context
  );

  // Re-check access; revoked mid-job must not return READY payload details.
  await assertPatientAccess(record.patient_id, context);

  if (record.status === 'READY' && record.expires_at && record.expires_at < new Date()) {
    const expired = await patientReportRepository.update(record.id, {
      status: 'CANCELLED',
      error_message: 'Report expired',
      version: Number(record.version || 1) + 1,
    });
    return serializeJob(expired);
  }

  return serializeJob(record);
};

const downloadJob = async (id, context = {}) => {
  assertStillAuthorized(context);
  const resolvedId = await resolveJobId(id);
  const record = ensureScopedJob(
    await patientReportRepository.findById(resolvedId),
    context
  );
  const patient = await assertPatientAccess(record.patient_id, context);

  if (record.status !== 'READY' || !record.output_storage_path) {
    throw new HttpError('errors.patient_report.not_ready', 409);
  }

  if (record.expires_at && record.expires_at < new Date()) {
    throw new HttpError('errors.patient_report.expired', 410);
  }

  const storage = createStorageService();
  const buffer = await storage.download(record.output_storage_path);

  await recordPhiReportAccess({
    patient,
    context,
    reportType: record.report_type,
    action: REPORT_ACTIONS.DOWNLOAD,
    sections: Array.isArray(record.sections_json) ? record.sections_json : [],
  });

  return {
    buffer,
    file_name: record.output_file_name || 'patient-report.pdf',
    mime_type: record.output_mime_type || 'application/pdf',
  };
};

const recordPrintEvent = async (payload = {}, context = {}) => {
  const permissions = assertStillAuthorized(context);
  const patientId = await resolvePatientId(payload.patient_id, context.tenant_id);
  if (!patientId) {
    throw new HttpError('errors.patient.not_found', 404);
  }

  const patient = await assertPatientAccess(patientId, context);
  const sections = filterAuthorizedSections(
    Array.isArray(payload.sections) ? payload.sections : [],
    permissions
  );
  const reportType = payload.report_type || REPORT_TYPES.PATIENT_CLINICAL;
  const action = String(payload.action || REPORT_ACTIONS.PRINT).toLowerCase();

  await recordPhiReportAccess({
    patient,
    context,
    reportType,
    action,
    sections,
  });

  await createAuditLog({
    tenant_id: patient.tenant_id,
    facility_id: patient.facility_id,
    user_id: context.user_id,
    action: 'ACCESS',
    entity: 'patient_report_print',
    entity_id: patient.id,
    diff: {
      after: {
        patient_id: resolvePublicIdentifier(patient.human_friendly_id, patient.id),
        encounter_id: payload.encounter_id || null,
        report_type: reportType,
        action,
        sections,
        timestamp: new Date().toISOString(),
      },
    },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return {
    recorded: true,
    report_type: reportType,
    action,
    sections,
  };
};

module.exports = {
  buildContext,
  createJob,
  downloadJob,
  getJobById,
  listSections,
  processJob,
  recordPrintEvent,
  serializeJob,
};
