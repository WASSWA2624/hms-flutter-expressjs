const prisma = require('@prisma/client');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');

const ACTIVE_BREAK_GLASS_STATUSES = Object.freeze({
  access: 'ACTIVE',
  review: 'APPROVED',
});

const findApplicablePolicies = async ({
  tenant_id,
  facility_id,
  branch_id,
  department_id,
  resource_type,
  action,
} = {}) => {
  if (!tenant_id || !resource_type || !action) {
    return [];
  }

  return prisma.abac_policy.findMany({
    where: {
      tenant_id,
      deleted_at: null,
      is_active: true,
      resource_type: { in: [resource_type, '*'] },
      action: { in: [action, '*'] },
      OR: [
        { facility_id: null },
        { facility_id },
      ],
      AND: [
        {
          OR: [
            { branch_id: null },
            { branch_id },
          ],
        },
        {
          OR: [
            { department_id: null },
            { department_id },
          ],
        },
      ],
    },
    orderBy: [{ priority: 'asc' }, { created_at: 'asc' }],
  });
};

const findActiveBreakGlassAccess = async ({
  tenant_id,
  user_id,
  patient_id,
  target_resource_type,
  target_resource_id,
} = {}) => {
  if (!tenant_id || !user_id) {
    return null;
  }

  const now = new Date();
  const clauses = [];

  if (patient_id) {
    clauses.push({ patient_id });
  }

  if (target_resource_type && target_resource_id) {
    clauses.push({
      target_resource_type,
      target_resource_id,
    });
  }

  if (target_resource_type && !target_resource_id) {
    clauses.push({
      target_resource_type,
      target_resource_id: null,
    });
  }

  if (clauses.length === 0) {
    return null;
  }

  return prisma.break_glass_access.findFirst({
    where: {
      tenant_id,
      requested_by_user_id: user_id,
      deleted_at: null,
      status: ACTIVE_BREAK_GLASS_STATUSES.access,
      review_status: ACTIVE_BREAK_GLASS_STATUSES.review,
      OR: clauses,
      AND: [
        {
          OR: [
            { starts_at: null },
            { starts_at: { lte: now } },
          ],
        },
        {
          OR: [
            { expires_at: null },
            { expires_at: { gte: now } },
          ],
        },
      ],
    },
    orderBy: [{ approved_at: 'desc' }, { requested_at: 'desc' }],
  });
};

const findUserScopeContext = async ({ user_id, facility_id } = {}) => {
  if (!user_id) {
    return null;
  }

  const user = await prisma.user.findFirst({
    where: {
      id: user_id,
      deleted_at: null,
    },
    include: {
      staff_profile: {
        select: {
          id: true,
          department_id: true,
        },
      },
    },
  });

  if (!user) {
    return null;
  }

  const now = new Date();
  const activeShiftAssignment = await prisma.shift_assignment.findFirst({
    where: {
      deleted_at: null,
      staff_profile: {
        deleted_at: null,
        user_id,
      },
      shift: {
        deleted_at: null,
        status: 'SCHEDULED',
        start_time: { lte: now },
        end_time: { gte: now },
        ...(facility_id ? { facility_id } : {}),
      },
    },
    include: {
      shift: {
        select: {
          id: true,
          facility_id: true,
          start_time: true,
          end_time: true,
        },
      },
    },
  });

  return {
    department_id: user.staff_profile?.department_id || null,
    has_active_shift: Boolean(activeShiftAssignment?.shift?.id),
    active_shift_id: activeShiftAssignment?.shift?.id || null,
  };
};

const resolveByIdentifier = (model, identifier, include) =>
  resolveModelRecordByIdentifier({
    model,
    identifier,
    include,
  });

const resolvePatientContext = async (identifier) => {
  const patient = await resolveByIdentifier('patient', identifier, {
    facility: { select: { id: true, human_friendly_id: true } },
  });
  if (!patient) return null;

  return {
    id: patient.id,
    tenant_id: patient.tenant_id,
    facility_id: patient.facility_id || null,
    patient_id: patient.id,
  };
};

const resolveEncounterContext = async (identifier) => {
  const encounter = await resolveByIdentifier('encounter', identifier, {
    patient: { select: { id: true, human_friendly_id: true } },
  });
  if (!encounter) return null;

  return {
    id: encounter.id,
    tenant_id: encounter.tenant_id,
    facility_id: encounter.facility_id || null,
    patient_id: encounter.patient_id,
  };
};

const resolveClinicalNoteContext = async (identifier) => {
  const note = await resolveByIdentifier('clinical_note', identifier, {
    encounter: {
      select: {
        id: true,
        tenant_id: true,
        facility_id: true,
        patient_id: true,
      },
    },
  });
  if (!note?.encounter) return null;

  return {
    id: note.id,
    tenant_id: note.encounter.tenant_id,
    facility_id: note.encounter.facility_id || null,
    patient_id: note.encounter.patient_id,
  };
};

const resolveAdmissionBackedContext = async (model, identifier) => {
  const record = await resolveByIdentifier(model, identifier, {
    admission: {
      select: {
        id: true,
        tenant_id: true,
        facility_id: true,
        patient_id: true,
      },
    },
  });
  if (!record?.admission) return null;

  return {
    id: record.id,
    tenant_id: record.admission.tenant_id,
    facility_id: record.admission.facility_id || null,
    patient_id: record.admission.patient_id,
  };
};

const resolveRefundContext = async (identifier) => {
  const refund = await resolveByIdentifier('refund', identifier, {
    payment: {
      select: {
        id: true,
        tenant_id: true,
        facility_id: true,
        patient_id: true,
      },
    },
  });
  if (!refund?.payment) return null;

  return {
    id: refund.id,
    tenant_id: refund.payment.tenant_id,
    facility_id: refund.payment.facility_id || null,
    patient_id: refund.payment.patient_id || null,
  };
};

const resolvePaymentContext = async (identifier) => {
  const payment = await resolveByIdentifier('payment', identifier, {});
  if (!payment) return null;

  return {
    id: payment.id,
    tenant_id: payment.tenant_id,
    facility_id: payment.facility_id || null,
    patient_id: payment.patient_id || null,
  };
};

const resolveEquipmentWorkOrderContext = async (identifier) => {
  const workOrder = await resolveByIdentifier('equipment_work_order', identifier, {
    equipment_registry: {
      select: {
        id: true,
        tenant_id: true,
        facility_id: true,
      },
    },
  });
  if (!workOrder?.equipment_registry) return null;

  return {
    id: workOrder.id,
    tenant_id: workOrder.equipment_registry.tenant_id,
    facility_id: workOrder.equipment_registry.facility_id || null,
    assigned_engineer_user_id: workOrder.assigned_engineer_user_id || null,
    status: workOrder.status || null,
  };
};

const resolveOfficeScopedContext = async (model, identifier) => {
  const record = await resolveByIdentifier(model, identifier, {});
  if (!record) return null;

  return {
    id: record.id,
    tenant_id: record.tenant_id,
    facility_id: record.facility_id || null,
    branch_id: record.branch_id || null,
  };
};

module.exports = {
  findActiveBreakGlassAccess,
  findApplicablePolicies,
  findUserScopeContext,
  resolveAdmissionBackedContext,
  resolveClinicalNoteContext,
  resolveEncounterContext,
  resolveEquipmentWorkOrderContext,
  resolveOfficeScopedContext,
  resolvePaymentContext,
  resolvePatientContext,
  resolveRefundContext,
};
