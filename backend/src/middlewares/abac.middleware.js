const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { createAuditLog } = require('@lib/audit');
const { normalizeRoleName, ELEVATED_ROLES } = require('@config/roles');
const { PERMISSIONS } = require('@config/permissions');
const { getUserPermissions } = require('@middlewares/auth.middleware');
const { evaluatePolicies } = require('@lib/authorization/policy-evaluator');
const {
  findActiveBreakGlassAccess,
  findApplicablePolicies,
  findUserScopeContext,
  resolveAdmissionBackedContext,
  resolveClinicalNoteContext,
  resolveEncounterContext,
  resolveEquipmentWorkOrderContext,
  resolveOfficeScopedContext,
  resolvePatientContext,
  resolvePaymentContext,
  resolveRefundContext,
} = require('@lib/authorization/access.repository');
const { recordSecurityEvent, recordWorkflowEvent } = require('@lib/telemetry/metrics');

const ELEVATED_ROLE_SET = new Set(ELEVATED_ROLES);
const WORK_ORDER_MANAGER_ROLES = new Set(['TENANT_ADMIN', 'FACILITY_ADMIN', 'OPERATIONS']);

const getPathSegment = (req) =>
  String(req.path || req.originalUrl || '')
    .replace(/^\/+/, '')
    .split('/')[0]
    .toLowerCase();

const setScopeIfMissing = (source, field, value) => {
  if (!source || typeof source !== 'object' || !value) return;
  if (source[field] !== undefined && source[field] !== null && source[field] !== '') return;

  const camelField = field.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
  if (source[camelField] !== undefined && source[camelField] !== null && source[camelField] !== '') return;

  source[field] = value;
};

const toAction = (req) => {
  const method = String(req.method || 'GET').toUpperCase();
  const parts = String(req.path || '').split('/').filter(Boolean);
  const tail = parts[parts.length - 1] || '';

  if (method === 'GET' || method === 'HEAD') return 'read';
  if (method === 'DELETE') return 'delete';
  if (method === 'PUT' || method === 'PATCH') return 'update';

  if (method === 'POST' && ['approve', 'reject', 'revoke', 'submit', 'accept', 'finalize', 'close'].includes(tail)) {
    return tail;
  }

  return 'create';
};

const hasElevatedRole = (roles = []) =>
  roles.some((role) => ELEVATED_ROLE_SET.has(normalizeRoleName(role) || String(role || '').toUpperCase()));

const buildSubject = async (req, classifier) => {
  const user = req.user || {};
  const roles = (Array.isArray(user.roles) ? user.roles : [user.role])
    .map((role) => normalizeRoleName(role) || String(role || '').toUpperCase())
    .filter(Boolean);
  const permissions = getUserPermissions(user);
  const scope = await findUserScopeContext({
    user_id: user.id || user.user_id || user.userId,
    facility_id: user.facility_id || user.facilityId || null,
  });

  return {
    user_id: user.id || user.user_id || user.userId || null,
    tenant_id: user.tenant_id || user.tenantId || null,
    facility_id: user.facility_id || user.facilityId || null,
    branch_id: user.branch_id || user.branchId || null,
    roles,
    permissions,
    department_id: scope?.department_id || null,
    has_active_shift: scope?.has_active_shift || false,
    active_shift_id: scope?.active_shift_id || null,
    resource_type: classifier.resource_type,
  };
};

const resolveContextFromBody = async (classifier, req) => {
  if (!req.body || typeof req.body !== 'object') return null;

  if (classifier.resource_type === 'patient' && req.body.patient_id) {
    return resolvePatientContext(req.body.patient_id);
  }
  if (classifier.resource_type === 'encounter' && req.body.patient_id) {
    return resolvePatientContext(req.body.patient_id);
  }
  if (classifier.resource_type === 'clinical_note' && req.body.encounter_id) {
    return resolveEncounterContext(req.body.encounter_id);
  }
  if (classifier.resource_type === 'nursing_note' && req.body.admission_id) {
    return resolveByAdmissionId(req.body.admission_id);
  }
  if (classifier.resource_type === 'medication_administration' && req.body.admission_id) {
    return resolveByAdmissionId(req.body.admission_id);
  }
  if (classifier.resource_type === 'refund' && req.body.payment_id) {
    return resolvePaymentContext(req.body.payment_id);
  }
  return null;
};

const resolveByAdmissionId = async (admissionId) => {
  const admission = await prisma.admission.findFirst({
    where: {
      id: admissionId,
      deleted_at: null,
    },
    select: {
      id: true,
      tenant_id: true,
      facility_id: true,
      patient_id: true,
    },
  });

  if (!admission) return null;
  return {
    id: admission.id,
    tenant_id: admission.tenant_id,
    facility_id: admission.facility_id || null,
    patient_id: admission.patient_id,
  };
};

const RESOURCE_CLASSIFIERS = Object.freeze({
  patients: {
    resource_type: 'patient',
    patient_linked: true,
    resolveById: resolvePatientContext,
    enforce_scope: true,
  },
  encounters: {
    resource_type: 'encounter',
    patient_linked: true,
    resolveById: resolveEncounterContext,
    enforce_scope: true,
  },
  'clinical-notes': {
    resource_type: 'clinical_note',
    patient_linked: true,
    resolveById: resolveClinicalNoteContext,
    enforce_scope: true,
  },
  'nursing-notes': {
    resource_type: 'nursing_note',
    patient_linked: true,
    resolveById: (identifier) => resolveAdmissionBackedContext('nursing_note', identifier),
    enforce_scope: true,
  },
  'medication-administrations': {
    resource_type: 'medication_administration',
    patient_linked: true,
    resolveById: (identifier) => resolveAdmissionBackedContext('medication_administration', identifier),
    enforce_scope: true,
  },
  refunds: {
    resource_type: 'refund',
    patient_linked: true,
    billing_sensitive: true,
    resolveById: resolveRefundContext,
    enforce_scope: true,
  },
  'equipment-work-orders': {
    resource_type: 'equipment_work_order',
    assigned_work: true,
    resolveById: resolveEquipmentWorkOrderContext,
    enforce_scope: true,
  },
  'audit-logs': {
    resource_type: 'audit_log',
    compliance: true,
  },
  'phi-access-logs': {
    resource_type: 'phi_access_log',
    compliance: true,
  },
  'data-processing-logs': {
    resource_type: 'data_processing_log',
    compliance: true,
  },
  'breach-notifications': {
    resource_type: 'breach_notification',
    compliance: true,
  },
  'system-change-logs': {
    resource_type: 'system_change_log',
    compliance: true,
  },
  'office-contexts': {
    resource_type: 'office_context',
    office_scoped: true,
    resolveById: (identifier) => resolveOfficeScopedContext('office_context', identifier),
    enforce_scope: true,
  },
  'shift-closes': {
    resource_type: 'shift_close',
    office_scoped: true,
    resolveById: (identifier) => resolveOfficeScopedContext('shift_close', identifier),
    enforce_scope: true,
  },
  'day-closes': {
    resource_type: 'day_close',
    office_scoped: true,
    resolveById: (identifier) => resolveOfficeScopedContext('day_close', identifier),
    enforce_scope: true,
  },
  handovers: {
    resource_type: 'handover',
    office_scoped: true,
    resolveById: (identifier) => resolveOfficeScopedContext('handover', identifier),
    enforce_scope: true,
  },
  'custody-snapshots': {
    resource_type: 'custody_snapshot',
    office_scoped: true,
    resolveById: (identifier) => resolveOfficeScopedContext('custody_snapshot', identifier),
    enforce_scope: true,
  },
  'closeout-packs': {
    resource_type: 'closeout_pack',
    office_scoped: true,
    resolveById: (identifier) => resolveOfficeScopedContext('closeout_pack', identifier),
    enforce_scope: true,
  },
});

const resolveObjectContext = async (classifier, req) => {
  if (!classifier) return null;

  if (req.params?.id && classifier.resolveById) {
    const byId = await classifier.resolveById(req.params.id);
    if (byId) return byId;
  }

  return resolveContextFromBody(classifier, req);
};

const canManageWorkOrder = (subject, object, action) => {
  if (!object || !['update', 'delete', 'start', 'return-to-service', 'approve'].includes(action)) {
    return true;
  }

  if (!object.assigned_engineer_user_id) {
    return true;
  }

  if (subject.user_id && object.assigned_engineer_user_id === subject.user_id) {
    return true;
  }

  return subject.roles.some((role) => WORK_ORDER_MANAGER_ROLES.has(role));
};

const checkImplicitDenial = ({ classifier, subject, object, action }) => {
  if (classifier.compliance) {
    const requiredPermission = action === 'read' ? PERMISSIONS.COMPLIANCE_READ : PERMISSIONS.COMPLIANCE_REVIEW;
    if (!subject.permissions.includes(requiredPermission) && !hasElevatedRole(subject.roles)) {
      return 'compliance_permission_required';
    }
  }

  if (classifier.billing_sensitive && action !== 'read') {
    if (!subject.permissions.includes(PERMISSIONS.FINANCIAL_APPROVE) && !hasElevatedRole(subject.roles)) {
      return 'financial_approval_required';
    }
  }

  if (classifier.assigned_work && !canManageWorkOrder(subject, object, action)) {
    return 'work_order_assignment_required';
  }

  if (!object) {
    return null;
  }

  if (object.tenant_id && subject.tenant_id && object.tenant_id !== subject.tenant_id) {
    return 'tenant_scope_mismatch';
  }

  if (object.facility_id && subject.facility_id && object.facility_id !== subject.facility_id) {
    return 'facility_scope_mismatch';
  }

  if (classifier.office_scoped && object.branch_id && subject.branch_id && object.branch_id !== subject.branch_id) {
    return 'branch_scope_mismatch';
  }

  if (classifier.patient_linked && subject.roles.includes('NURSE') && !subject.has_active_shift) {
    return 'active_shift_required';
  }

  return null;
};

const recordPhiAccess = ({ subject, object, breakGlass }) => {
  if (!object?.patient_id || !subject?.user_id || !subject?.tenant_id) {
    return;
  }

  prisma.phi_access_log.create({
    data: {
      tenant_id: subject.tenant_id,
      user_id: subject.user_id,
      patient_id: object.patient_id,
      access_scope: 'PATIENT',
      reason: breakGlass ? 'Emergency break-glass access' : 'Scoped patient-linked access',
    },
  }).catch(() => {});
};

const auditDecision = ({ req, classifier, object, decision, reason, breakGlass }) => {
  createAuditLog({
    tenant_id: req.user?.tenant_id || req.user?.tenantId || object?.tenant_id || null,
    user_id: req.user?.id || req.user?.user_id || req.user?.userId || null,
    action: 'ACCESS',
    entity: classifier.resource_type,
    entity_id: object?.id || req.params?.id || req.path,
    diff: {
      after: {
        decision,
        reason,
        break_glass: Boolean(breakGlass),
        patient_id: object?.patient_id || null,
      },
    },
    ip_address: req.ip,
  }).catch(() => {});
};

const enforceAbacAccess = () => async (req, res, next) => {
  try {
    const classifier = RESOURCE_CLASSIFIERS[getPathSegment(req)];
    if (!classifier || !req.user) {
      return next();
    }

    if (classifier.enforce_scope && !hasElevatedRole(req.user.roles || [])) {
      setScopeIfMissing(req.query, 'facility_id', req.user.facility_id || req.user.facilityId || null);
      setScopeIfMissing(req.query, 'branch_id', req.user.branch_id || req.user.branchId || null);
      setScopeIfMissing(req.body, 'facility_id', req.user.facility_id || req.user.facilityId || null);
      setScopeIfMissing(req.body, 'branch_id', req.user.branch_id || req.user.branchId || null);
    }

    const action = toAction(req);
    const subject = await buildSubject(req, classifier);
    const object = await resolveObjectContext(classifier, req);
    const policies = await findApplicablePolicies({
      tenant_id: subject.tenant_id,
      facility_id: subject.facility_id,
      branch_id: subject.branch_id,
      department_id: subject.department_id,
      resource_type: classifier.resource_type,
      action,
    });

    const evaluation = evaluatePolicies({
      policies,
      subject,
      object,
      environment: {
        method: req.method,
        path: req.path,
        action,
      },
    });

    let denialReason = evaluation.winner && evaluation.allowed === false
      ? `policy:${evaluation.winner.id}`
      : checkImplicitDenial({ classifier, subject, object, action });

    let breakGlass = null;
    if (denialReason && classifier.patient_linked && evaluation.allowed !== false) {
      breakGlass = await findActiveBreakGlassAccess({
        tenant_id: subject.tenant_id,
        user_id: subject.user_id,
        patient_id: object?.patient_id || null,
        target_resource_type: classifier.resource_type,
        target_resource_id: object?.id || null,
      });

      if (breakGlass) {
        denialReason = null;
      }
    }

    if (evaluation.allowed === false || denialReason) {
      auditDecision({
        req,
        classifier,
        object,
        decision: 'DENY',
        reason: denialReason || 'policy_denied',
        breakGlass,
      });
      recordSecurityEvent('abac.denied', {
        'hms.resource.type': classifier.resource_type,
        'hms.action': action,
      });
      return next(new HttpError('errors.auth.insufficient_permissions', 403));
    }

    if (breakGlass) {
      recordWorkflowEvent('break_glass.override_granted', {
        'hms.resource.type': classifier.resource_type,
        'hms.action': action,
      });
      auditDecision({
        req,
        classifier,
        object,
        decision: 'ALLOW',
        reason: 'break_glass',
        breakGlass,
      });
    }

    if (classifier.patient_linked && object?.patient_id) {
      recordPhiAccess({ subject, object, breakGlass });
    }

    req.authorizationContext = {
      resource_type: classifier.resource_type,
      action,
      object,
      matched_policy_id: evaluation.winner?.id || null,
      break_glass_access_id: breakGlass?.id || null,
    };

    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  enforceAbacAccess,
};
