/**
 * Patient controller
 *
 * @module modules/patient/controllers
 * @description Request handlers for patient endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const patientService = require('@services/patient/patient.service');
const patientWorkspaceService = require('@services/patient/patient-workspace.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const GLOBAL_SCOPE_ROLES = new Set(['SUPER_ADMIN', 'APP_ADMIN', 'SYSTEM_ADMIN', 'PLATFORM_ADMIN']);

const normalizeScopeValue = (value) => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const hasGlobalScopeAccess = (user = {}) => {
  const roles = [
    ...(Array.isArray(user.roles) ? user.roles : []),
    user.role
  ]
    .map((role) => String(role || '').trim().toUpperCase())
    .filter(Boolean);

  return roles.some((role) => GLOBAL_SCOPE_ROLES.has(role));
};

const buildPatientScope = (req = {}) => {
  const queryTenantId = normalizeScopeValue(req.query?.tenant_id);
  const queryFacilityId = normalizeScopeValue(req.query?.facility_id);
  const userTenantId = normalizeScopeValue(req.user?.tenant_id);
  const userFacilityId = normalizeScopeValue(req.user?.facility_id);

  const isGlobalUser = hasGlobalScopeAccess(req.user);
  const tenantId = isGlobalUser ? queryTenantId : (userTenantId || queryTenantId);
  const facilityId = isGlobalUser ? queryFacilityId : (userFacilityId || queryFacilityId);

  return {
    ...(tenantId ? { tenant_id: tenantId } : {}),
    ...(facilityId ? { facility_id: facilityId } : {})
  };
};

const buildUserContext = (req = {}) => ({
  user_id: req.user?.id || null,
  ip_address: req.ip,
});

/**
 * List patients with pagination
 * GET /api/v1/patients
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPatients = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    first_name,
    last_name,
    date_of_birth,
    date_of_birth_from,
    date_of_birth_to,
    gender,
    contact,
    appointment_status,
    created_at,
    created_from,
    created_to,
    appointment_from,
    appointment_to,
    is_active,
    consent_state,
    has_active_admission,
    has_outstanding_balance,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    patient_id,
    first_name,
    last_name,
    date_of_birth,
    date_of_birth_from,
    date_of_birth_to,
    gender,
    contact,
    appointment_status,
    created_at,
    created_from,
    created_to,
    appointment_from,
    appointment_to,
    is_active,
    consent_state,
    has_active_admission,
    has_outstanding_balance,
    search
  };
  const scopedFilters = {
    ...filters,
    ...buildPatientScope(req)
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await patientService.listPatients(
    scopedFilters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.patient.list.success', result.patients, result.pagination);
});

/**
 * Get patient by ID
 * GET /api/v1/patients/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPatientById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const patient = await patientService.getPatientById(id, userId, ipAddress, buildPatientScope(req));

  sendSuccess(res, 200, 'messages.patient.get.success', patient);
});

/**
 * Create new patient
 * POST /api/v1/patients
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPatient = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;
  const scope = buildPatientScope(req);
  const payload = {
    ...req.body,
    tenant_id: scope.tenant_id ?? req.body?.tenant_id ?? null,
    facility_id: scope.facility_id ?? req.body?.facility_id ?? null,
  };
  const patient = await patientService.createPatient(payload, userId, ipAddress, scope);

  sendSuccess(res, 201, 'messages.patient.create.success', patient);
});

/**
 * Update patient
 * PUT /api/v1/patients/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePatient = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;
  const scope = buildPatientScope(req);
  const payload = {
    ...req.body,
  };

  if (
    scope.facility_id &&
    Object.prototype.hasOwnProperty.call(req.body || {}, 'facility_id')
  ) {
    payload.facility_id = scope.facility_id;
  }

  const patient = await patientService.updatePatient(
    id,
    payload,
    userId,
    ipAddress,
    scope
  );

  sendSuccess(res, 200, 'messages.patient.update.success', patient);
});

/**
 * Delete patient (soft delete)
 * DELETE /api/v1/patients/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePatient = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await patientService.deletePatient(id, userId, ipAddress, buildPatientScope(req));

  sendNoContent(res);
});

/**
 * Get patient identifiers (nested resource)
 * GET /api/v1/patients/:id/identifiers
 */
const getPatientIdentifiers = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const result = await patientService.getPatientIdentifiers(
    id,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user?.id,
    req.ip,
    buildPatientScope(req)
  );

  sendPaginated(res, 'messages.patient.identifiers.list.success', result.patientIdentifiers, result.pagination);
});

/**
 * Get patient contacts (nested resource)
 * GET /api/v1/patients/:id/contacts
 */
const getPatientContacts = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const result = await patientService.getPatientContacts(
    id,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user?.id,
    req.ip,
    buildPatientScope(req)
  );

  sendPaginated(res, 'messages.patient.contacts.list.success', result.patientContacts, result.pagination);
});

/**
 * Get patient guardians (nested resource)
 * GET /api/v1/patients/:id/guardians
 */
const getPatientGuardians = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const result = await patientService.getPatientGuardians(
    id,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user?.id,
    req.ip,
    buildPatientScope(req)
  );

  sendPaginated(res, 'messages.patient.guardians.list.success', result.patientGuardians, result.pagination);
});

/**
 * Get patient allergies (nested resource)
 * GET /api/v1/patients/:id/allergies
 */
const getPatientAllergies = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const result = await patientService.getPatientAllergies(
    id,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    buildPatientScope(req)
  );

  sendPaginated(res, 'messages.patient.allergies.list.success', result.patientAllergies, result.pagination);
});

/**
 * Get patient medical histories (nested resource)
 * GET /api/v1/patients/:id/medical-histories
 */
const getPatientMedicalHistories = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const result = await patientService.getPatientMedicalHistories(
    id,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    buildPatientScope(req)
  );

  sendPaginated(
    res,
    'messages.patient.medical_histories.list.success',
    result.patientMedicalHistories,
    result.pagination
  );
});

/**
 * Get patient documents (nested resource)
 * GET /api/v1/patients/:id/documents
 */
const getPatientDocuments = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const result = await patientService.getPatientDocuments(
    id,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    buildPatientScope(req)
  );

  sendPaginated(res, 'messages.patient.documents.list.success', result.patientDocuments, result.pagination);
});

const getPatientWorkspaceOverview = asyncHandler(async (req, res) => {
  const result = await patientWorkspaceService.getPatientWorkspaceOverview(
    buildPatientScope(req),
    buildUserContext(req)
  );
  sendSuccess(res, 200, 'messages.patient.workspace.overview.success', result);
});

const getPatientWorkspaceReferenceData = asyncHandler(async (req, res) => {
  const result = await patientWorkspaceService.getPatientWorkspaceReferenceData(
    buildPatientScope(req),
    buildUserContext(req)
  );
  sendSuccess(res, 200, 'messages.patient.workspace.reference_data.success', result);
});

const getPatientWorkspace = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const result = await patientWorkspaceService.getPatientWorkspace(
    patientId,
    buildPatientScope(req),
    buildUserContext(req)
  );
  sendSuccess(res, 200, 'messages.patient.workspace.get.success', result);
});

const listPatientTimeline = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listPatientTimeline(
    patientId,
    parseInt(page, 10),
    parseInt(limit, 10),
    buildPatientScope(req),
    buildUserContext(req)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.timeline.list.success',
    result.items,
    result.pagination
  );
});

const listPatientConsents = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listPatientConsents(
    patientId,
    parseInt(page, 10),
    parseInt(limit, 10),
    buildPatientScope(req)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.consents.list.success',
    result.items,
    result.pagination
  );
});

const listPatientAppointments = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listPatientAppointments(
    patientId,
    parseInt(page, 10),
    parseInt(limit, 10),
    buildPatientScope(req)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.appointments.list.success',
    result.items,
    result.pagination
  );
});

const listPatientVisitQueueEntries = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listPatientVisitQueueEntries(
    patientId,
    parseInt(page, 10),
    parseInt(limit, 10),
    buildPatientScope(req)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.visit_queue.list.success',
    result.items,
    result.pagination
  );
});

const listPatientEncounters = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listPatientEncounters(
    patientId,
    parseInt(page, 10),
    parseInt(limit, 10),
    buildPatientScope(req)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.encounters.list.success',
    result.items,
    result.pagination
  );
});

const listPatientAdmissions = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listPatientAdmissions(
    patientId,
    parseInt(page, 10),
    parseInt(limit, 10),
    buildPatientScope(req)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.admissions.list.success',
    result.items,
    result.pagination
  );
});

const listPatientFollowUps = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listPatientFollowUps(
    patientId,
    parseInt(page, 10),
    parseInt(limit, 10),
    buildPatientScope(req)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.follow_ups.list.success',
    result.items,
    result.pagination
  );
});

const listPatientReferrals = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listPatientReferrals(
    patientId,
    parseInt(page, 10),
    parseInt(limit, 10),
    buildPatientScope(req)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.referrals.list.success',
    result.items,
    result.pagination
  );
});

const listPatientInvoices = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listPatientInvoices(
    patientId,
    parseInt(page, 10),
    parseInt(limit, 10),
    buildPatientScope(req)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.invoices.list.success',
    result.items,
    result.pagination
  );
});

const listPatientPayments = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listPatientPayments(
    patientId,
    parseInt(page, 10),
    parseInt(limit, 10),
    buildPatientScope(req)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.payments.list.success',
    result.items,
    result.pagination
  );
});

const listPatientPhiAccessLogs = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listPatientPhiAccessLogs(
    patientId,
    parseInt(page, 10),
    parseInt(limit, 10),
    buildPatientScope(req)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.phi_access_logs.list.success',
    result.items,
    result.pagination
  );
});

const listDuplicateCandidates = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT } = req.query;
  const result = await patientWorkspaceService.listDuplicateCandidates(
    req.query,
    buildPatientScope(req),
    parseInt(page, 10),
    parseInt(limit, 10)
  );
  sendPaginated(
    res,
    'messages.patient.workspace.duplicates.list.success',
    result.items,
    result.pagination
  );
});

const previewPatientMerge = asyncHandler(async (req, res) => {
  const result = await patientWorkspaceService.previewPatientMerge(
    req.body,
    buildPatientScope(req),
    buildUserContext(req)
  );
  sendSuccess(res, 200, 'messages.patient.workspace.merge.preview.success', result);
});

const mergePatients = asyncHandler(async (req, res) => {
  const result = await patientWorkspaceService.mergePatients(
    req.body,
    buildPatientScope(req),
    buildUserContext(req)
  );
  sendSuccess(res, 200, 'messages.patient.workspace.merge.success', result);
});

const dismissDuplicateCandidate = asyncHandler(async (req, res) => {
  const result = await patientWorkspaceService.dismissDuplicateCandidate(
    req.params.reviewId,
    req.body,
    buildPatientScope(req),
    buildUserContext(req)
  );
  sendSuccess(res, 200, 'messages.patient.workspace.duplicates.dismiss.success', result);
});

const uploadPatientDocuments = asyncHandler(async (req, res) => {
  const { patientId } = req.params;
  const result = await patientWorkspaceService.uploadPatientDocuments(
    patientId,
    req.files || [],
    req.body || {},
    buildPatientScope(req),
    buildUserContext(req)
  );
  sendSuccess(res, 201, 'messages.patient.workspace.documents.upload.success', result);
});

const sendPatientDocumentAsset = async (res, result, disposition) => {
  const safeFileName = String(result.fileName || 'document').replace(/"/g, '');
  res.setHeader('Content-Type', result.contentType || 'application/octet-stream');
  res.setHeader('Content-Disposition', `${disposition}; filename="${safeFileName}"`);
  res.status(200).send(result.buffer);
};

const previewPatientDocument = asyncHandler(async (req, res) => {
  const { patientId, documentId } = req.params;
  const result = await patientWorkspaceService.getPatientDocumentAsset(
    patientId,
    documentId,
    buildPatientScope(req),
    buildUserContext(req),
    'inline'
  );
  await sendPatientDocumentAsset(res, result, 'inline');
});

const downloadPatientDocument = asyncHandler(async (req, res) => {
  const { patientId, documentId } = req.params;
  const result = await patientWorkspaceService.getPatientDocumentAsset(
    patientId,
    documentId,
    buildPatientScope(req),
    buildUserContext(req),
    'attachment'
  );
  await sendPatientDocumentAsset(res, result, 'attachment');
});

module.exports = {
  listPatients,
  getPatientById,
  createPatient,
  updatePatient,
  deletePatient,
  getPatientIdentifiers,
  getPatientContacts,
  getPatientGuardians,
  getPatientAllergies,
  getPatientMedicalHistories,
  getPatientDocuments,
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
  previewPatientDocument,
  downloadPatientDocument,
};
