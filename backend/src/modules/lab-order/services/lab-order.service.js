const labOrderRepository = require('@repositories/lab-order/lab-order.repository');
const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { emitToUsers, DIAGNOSTIC_EVENTS } = require('@lib/websocket');
const { ROLES } = require('@config/roles');
const {
  LAB_ORDER_WITH_RELATIONS_INCLUDE,
  LAB_PANEL_WITH_RELATIONS_INCLUDE,
  applyDateRangeFilter,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  toDateOrNull
} = require('@services/lab-workspace/lab.shared');
const { mapLabOrderRecord } = require('@services/lab-workspace/lab.serializer');

const sanitizeString = (value) => (typeof value === 'string' ? value.trim() : '');
const LAB_RECIPIENT_ROLES = [ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN, ROLES.DOCTOR, ROLES.NURSE, ROLES.LAB_TECH];

const STANDARD_LAB_TESTS = Object.freeze({
  CBC: {
    name: 'Complete Blood Count',
    code: 'CBC',
    category: 'HEMATOLOGY',
    specimen_type: 'WHOLE_BLOOD',
    result_kind: 'TEXT',
    unit: null,
    description: 'Standard complete blood count profile.'
  },
  BMP: {
    name: 'Basic Metabolic Panel',
    code: 'BMP',
    category: 'CHEMISTRY',
    specimen_type: 'SERUM',
    result_kind: 'TEXT',
    unit: null,
    description: 'Basic metabolic chemistry profile.'
  },
  CMP: {
    name: 'Comprehensive Metabolic Panel',
    code: 'CMP',
    category: 'CHEMISTRY',
    specimen_type: 'SERUM',
    result_kind: 'TEXT',
    unit: null,
    description: 'Comprehensive metabolic chemistry profile.'
  },
  LFT: {
    name: 'Liver Function Tests',
    code: 'LFT',
    category: 'CHEMISTRY',
    specimen_type: 'SERUM',
    result_kind: 'TEXT',
    unit: null,
    description: 'Liver enzymes and function screen.'
  },
  LIPID: {
    name: 'Lipid Profile',
    code: 'LIPID',
    category: 'CHEMISTRY',
    specimen_type: 'SERUM',
    result_kind: 'TEXT',
    unit: null,
    description: 'Lipid and cardiovascular risk profile.'
  },
  HBA1C: {
    name: 'Hemoglobin A1c',
    code: 'HBA1C',
    category: 'CHEMISTRY',
    specimen_type: 'WHOLE_BLOOD',
    result_kind: 'NUMERIC',
    unit: '%',
    description: 'Average glycemic control marker.'
  },
  TSH: {
    name: 'Thyroid Stimulating Hormone',
    code: 'TSH',
    category: 'ENDOCRINOLOGY',
    specimen_type: 'SERUM',
    result_kind: 'NUMERIC',
    unit: 'mIU/L',
    description: 'Thyroid function screening test.'
  },
  CRP: {
    name: 'C-Reactive Protein',
    code: 'CRP',
    category: 'IMMUNOLOGY',
    specimen_type: 'SERUM',
    result_kind: 'NUMERIC',
    unit: 'mg/L',
    description: 'Inflammation marker.'
  },
  ESR: {
    name: 'Erythrocyte Sedimentation Rate',
    code: 'ESR',
    category: 'HEMATOLOGY',
    specimen_type: 'WHOLE_BLOOD',
    result_kind: 'NUMERIC',
    unit: 'mm/hr',
    description: 'Inflammation marker.'
  },
  PT_INR: {
    name: 'Prothrombin Time / INR',
    code: 'PT_INR',
    category: 'COAGULATION',
    specimen_type: 'PLASMA',
    result_kind: 'TEXT',
    unit: null,
    description: 'Coagulation screening test.'
  },
  URINALYSIS: {
    name: 'Urinalysis',
    code: 'URINALYSIS',
    category: 'URINALYSIS',
    specimen_type: 'URINE',
    result_kind: 'TEXT',
    unit: null,
    description: 'Routine urine examination.'
  },
  MALARIA_RDT: {
    name: 'Malaria Rapid Diagnostic Test',
    code: 'MALARIA_RDT',
    category: 'IMMUNOLOGY',
    specimen_type: 'BLOOD',
    result_kind: 'QUALITATIVE',
    unit: 'Positive/Negative',
    description: 'Rapid malaria antigen screen.'
  },
  HIV_SCREEN: {
    name: 'HIV Screening',
    code: 'HIV_SCREEN',
    category: 'IMMUNOLOGY',
    specimen_type: 'BLOOD',
    result_kind: 'QUALITATIVE',
    unit: 'Reactive/Non-reactive',
    description: 'HIV screening test.'
  },
  PREGNANCY_TEST: {
    name: 'Pregnancy Test',
    code: 'PREGNANCY_TEST',
    category: 'ENDOCRINOLOGY',
    specimen_type: 'URINE',
    result_kind: 'QUALITATIVE',
    unit: 'Positive/Negative',
    description: 'hCG pregnancy screen.'
  },
  BLOOD_CULTURE: {
    name: 'Blood Culture',
    code: 'BLOOD_CULTURE',
    category: 'MICROBIOLOGY',
    specimen_type: 'BLOOD',
    result_kind: 'TEXT',
    unit: null,
    description: 'Blood culture and sensitivity.'
  }
});

const STANDARD_LAB_PANELS = Object.freeze({
  CBC_PANEL: ['CBC'],
  CHEMISTRY_BASIC: ['BMP', 'CMP'],
  DIABETES_MONITORING: ['HBA1C', 'BMP'],
  FEVER_SCREEN: ['CBC', 'MALARIA_RDT', 'CRP', 'BLOOD_CULTURE'],
  PRE_OP: ['CBC', 'CMP', 'PT_INR', 'HIV_SCREEN'],
  ANTENATAL_BASIC: ['CBC', 'HIV_SCREEN', 'URINALYSIS', 'PREGNANCY_TEST']
});

const resolveLabOrderRealtimeRecipients = async (orderRecord, actorUserId = null) => {
  const tenantId = orderRecord?.patient?.tenant_id || null;
  if (!tenantId || !prisma?.user_role?.findMany) return [];

  const facilityId = orderRecord?.patient?.facility_id || null;
  const rows = await prisma.user_role.findMany({
    where: {
      deleted_at: null,
      tenant_id: tenantId,
      role: {
        deleted_at: null,
        name: { in: LAB_RECIPIENT_ROLES }
      },
      ...(facilityId ? { OR: [{ facility_id: null }, { facility_id: facilityId }] } : {})
    },
    select: { user_id: true }
  });

  return [...new Set(rows.map((row) => row.user_id).filter(Boolean))].filter((userId) => userId !== actorUserId);
};

const publishLabOrderRealtimeUpdate = async ({ orderRecord, actorUserId = null, action }) => {
  try {
    if (!orderRecord) return;
    const recipientUserIds = await resolveLabOrderRealtimeRecipients(orderRecord, actorUserId);
    if (!recipientUserIds.length) return;

    const order = mapLabOrderRecord(orderRecord);
    if (!order) return;

    emitToUsers(recipientUserIds, DIAGNOSTIC_EVENTS.LAB_WORKFLOW_UPDATED, {
      order_id: order.id,
      order_public_id: order.id,
      patient_id: order.patient_id || null,
      patient_public_id: order.patient_id || null,
      patient_display_name: order.patient_display_name || null,
      status: order.status || null,
      action: String(action || 'UPDATED')
        .trim()
        .toUpperCase(),
      resource_type: 'lab_order',
      resource_id: order.id,
      occurred_at: new Date().toISOString(),
      target_path: order.id ? `/lab?id=${encodeURIComponent(order.id)}` : '/lab',
      workflow: { order }
    });
  } catch (_error) {
    // Realtime updates should not block lab order persistence.
  }
};

const resolveOrCreateStandardLabTest = async ({ code, tenantId, userId, ipAddress }) => {
  const definition = STANDARD_LAB_TESTS[sanitizeString(code).toUpperCase()];
  if (!definition) return null;
  const existing = await prisma.lab_test.findFirst({
    where: { tenant_id: tenantId, deleted_at: null, code: definition.code },
    select: { id: true }
  });
  if (existing) return existing;
  const labTest = await prisma.lab_test.create({
    data: {
      tenant_id: tenantId,
      name: definition.name,
      code: definition.code,
      category: definition.category,
      specimen_type: definition.specimen_type,
      result_kind: definition.result_kind,
      unit: definition.unit,
      description: definition.description,
      ...(definition.unit
        ? {
            unit_options: {
              create: [
                {
                  label: null,
                  unit: definition.unit,
                  ucum_code: null,
                  is_default: true,
                  sort_order: 0
                }
              ]
            }
          }
        : {})
    },
    select: { id: true }
  });
  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'CREATE',
    entity: 'lab_test',
    entity_id: labTest.id,
    diff: {
      after: { ...definition, id: labTest.id, source: 'STANDARD_LAB_CATALOG' }
    },
    ip_address: ipAddress
  }).catch(() => {});
  return labTest;
};

const resolveOrCreateRequestedLabTest = async ({ request, tenantId, userId, ipAddress }) => {
  if (request?.lab_test_id) {
    const requestedLabTestId = sanitizeString(request.lab_test_id);
    if (requestedLabTestId.startsWith('STD_LAB_TEST:')) {
      const standardCode = requestedLabTestId.split(':')[1];
      const standardLabTest = await resolveOrCreateStandardLabTest({
        code: standardCode,
        tenantId,
        userId,
        ipAddress
      });
      if (standardLabTest) return standardLabTest;
    }
    return resolveModelRecordOrThrow({
      identifier: request.lab_test_id,
      model: 'lab_test',
      where: { deleted_at: null, tenant_id: tenantId },
      select: { id: true },
      errorKey: 'errors.lab_test.not_found'
    });
  }

  const newTest = request?.new_test || {};
  const name = sanitizeString(newTest.name);
  if (!name) {
    throw new HttpError('errors.validation.required', 400, [{ field: 'requested_tests.new_test.name' }]);
  }

  const code = sanitizeString(newTest.code);
  const existing = await prisma.lab_test.findFirst({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      ...(code
        ? { code }
        : {
            name
          })
    },
    select: { id: true }
  });
  if (existing) return existing;

  const unit = sanitizeString(newTest.unit);
  const description = sanitizeString(newTest.description);
  const pendingReviewDescription = ['PENDING LAB CATALOG REVIEW', description].filter(Boolean).join(' - ');

  const labTest = await prisma.lab_test.create({
    data: {
      tenant_id: tenantId,
      name,
      code: code || null,
      category: sanitizeString(newTest.category) || null,
      specimen_type: sanitizeString(newTest.specimen_type) || null,
      result_kind: sanitizeString(newTest.result_kind) || 'NUMERIC',
      unit: unit || null,
      description: pendingReviewDescription,
      ...(unit
        ? {
            unit_options: {
              create: [
                {
                  label: null,
                  unit,
                  ucum_code: null,
                  is_default: true,
                  sort_order: 0
                }
              ]
            }
          }
        : {})
    },
    select: { id: true }
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'CREATE',
    entity: 'lab_test',
    entity_id: labTest.id,
    diff: { after: { ...newTest, id: labTest.id } },
    ip_address: ipAddress
  }).catch(() => {});

  return labTest;
};

const listLabOrders = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};

    if (filters.encounter_id) {
      whereClause.encounter_id = await resolveModelIdOrThrow({
        identifier: filters.encounter_id,
        model: 'encounter',
        where: { deleted_at: null },
        errorKey: 'errors.encounter.not_found'
      });
    }

    if (filters.patient_id) {
      whereClause.patient_id = await resolveModelIdOrThrow({
        identifier: filters.patient_id,
        model: 'patient',
        where: { deleted_at: null },
        errorKey: 'errors.patient.not_found'
      });
    }

    if (filters.status) whereClause.status = filters.status;
    applyDateRangeFilter(whereClause, 'ordered_at', filters.ordered_at_from, filters.ordered_at_to);

    const searchTerm = normalizeSearchTerm(filters.search);
    if (searchTerm) {
      whereClause.OR = [
        { human_friendly_id: { contains: searchTerm.upper } },
        { patient: { human_friendly_id: { contains: searchTerm.upper } } },
        { patient: { first_name: { contains: searchTerm.raw } } },
        { patient: { last_name: { contains: searchTerm.raw } } },
        { encounter: { human_friendly_id: { contains: searchTerm.upper } } },
        {
          items: {
            some: { human_friendly_id: { contains: searchTerm.upper } }
          }
        },
        {
          items: {
            some: {
              lab_test: { human_friendly_id: { contains: searchTerm.upper } }
            }
          }
        },
        {
          items: { some: { lab_test: { name: { contains: searchTerm.raw } } } }
        },
        {
          items: { some: { lab_test: { code: { contains: searchTerm.raw } } } }
        }
      ];
    }

    const [labOrders, total] = await Promise.all([
      labOrderRepository.findMany(whereClause, skip, limit, orderBy, LAB_ORDER_WITH_RELATIONS_INCLUDE),
      labOrderRepository.count(whereClause)
    ]);

    return {
      labOrders: labOrders.map((record) => mapLabOrderRecord(record)).filter(Boolean),
      pagination: buildPagination(page, limit, total)
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getLabOrderById = async (id, userId, ipAddress) => {
  try {
    const labOrder = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_order',
      where: { deleted_at: null },
      include: LAB_ORDER_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_order.not_found'
    });

    return mapLabOrderRecord(labOrder);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const resolveRequestedLabOrderItems = async ({ requestedTests, requestedPanels, tenantId, userId, ipAddress }) => {
  const items = [];
  const seenTestIds = new Set();

  for (const request of requestedTests) {
    const labTest = await resolveOrCreateRequestedLabTest({
      request,
      tenantId,
      userId,
      ipAddress
    });

    if (seenTestIds.has(labTest.id)) continue;
    seenTestIds.add(labTest.id);
    items.push({
      lab_test_id: labTest.id,
      status: 'ORDERED'
    });
  }

  for (const request of requestedPanels) {
    const requestedPanelId = sanitizeString(request.lab_panel_id);
    if (requestedPanelId.startsWith('STD_LAB_PANEL:')) {
      const panelCode = requestedPanelId.split(':')[1];
      const standardCodes = STANDARD_LAB_PANELS[sanitizeString(panelCode).toUpperCase()] || [];
      for (const standardCode of standardCodes) {
        const labTest = await resolveOrCreateStandardLabTest({
          code: standardCode,
          tenantId,
          userId,
          ipAddress
        });
        if (!labTest?.id || seenTestIds.has(labTest.id)) continue;
        seenTestIds.add(labTest.id);
        items.push({ lab_test_id: labTest.id, status: 'ORDERED' });
      }
      continue;
    }

    const labPanel = await resolveModelRecordOrThrow({
      identifier: request.lab_panel_id,
      model: 'lab_panel',
      where: { deleted_at: null, tenant_id: tenantId },
      include: LAB_PANEL_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_panel.not_found'
    });

    const panelItems = Array.isArray(labPanel?.panel_items) ? labPanel.panel_items : [];
    panelItems.forEach((panelItem) => {
      const labTestId = panelItem?.lab_test_id || panelItem?.lab_test?.id;
      if (!labTestId || seenTestIds.has(labTestId)) return;
      seenTestIds.add(labTestId);
      items.push({
        lab_test_id: labTestId,
        status: 'ORDERED'
      });
    });
  }

  return items;
};

const createLabOrder = async (data, userId, ipAddress) => {
  try {
    const payload = { ...data };
    const requestedTests = Array.isArray(payload.requested_tests) ? payload.requested_tests : [];
    const requestedPanels = Array.isArray(payload.requested_panels) ? payload.requested_panels : [];
    delete payload.requested_tests;
    delete payload.requested_panels;

    const patientRecord = await resolveModelRecordOrThrow({
      identifier: payload.patient_id,
      model: 'patient',
      where: { deleted_at: null },
      select: {
        id: true,
        tenant_id: true
      },
      errorKey: 'errors.patient.not_found'
    });
    payload.patient_id = patientRecord.id;

    if (payload.encounter_id) {
      payload.encounter_id = await resolveModelIdOrThrow({
        identifier: payload.encounter_id,
        model: 'encounter',
        where: { deleted_at: null },
        errorKey: 'errors.encounter.not_found'
      });
    } else {
      payload.encounter_id = null;
    }

    payload.status = payload.status || 'ORDERED';
    payload.ordered_at = toDateOrNull(payload.ordered_at, new Date());
    const requestedItems = await resolveRequestedLabOrderItems({
      requestedTests,
      requestedPanels,
      tenantId: patientRecord.tenant_id,
      userId,
      ipAddress
    });
    if (!requestedItems.length) {
      throw new HttpError('errors.validation.required', 400, [{ field: 'requested_tests' }]);
    }
    if (requestedItems.length > 0) {
      payload.items = {
        create: requestedItems
      };
    }

    const labOrder = await labOrderRepository.create(payload);
    const createdOrder = await labOrderRepository.findById(labOrder.id, LAB_ORDER_WITH_RELATIONS_INCLUDE);

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'lab_order',
      entity_id: labOrder.id,
      diff: { after: createdOrder || labOrder },
      ip_address: ipAddress
    }).catch(() => {});
    publishLabOrderRealtimeUpdate({
      orderRecord: createdOrder || labOrder,
      actorUserId: userId,
      action: 'CREATED'
    });

    return mapLabOrderRecord(createdOrder || labOrder);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateLabOrder = async (id, data, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_order',
      where: { deleted_at: null },
      include: LAB_ORDER_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_order.not_found'
    });

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'patient_id') && payload.patient_id) {
      payload.patient_id = await resolveModelIdOrThrow({
        identifier: payload.patient_id,
        model: 'patient',
        where: { deleted_at: null },
        errorKey: 'errors.patient.not_found'
      });
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'encounter_id')) {
      payload.encounter_id = payload.encounter_id
        ? await resolveModelIdOrThrow({
            identifier: payload.encounter_id,
            model: 'encounter',
            where: { deleted_at: null },
            errorKey: 'errors.encounter.not_found'
          })
        : null;
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'ordered_at')) {
      payload.ordered_at = toDateOrNull(payload.ordered_at, before.ordered_at);
    }

    const updated = await labOrderRepository.update(before.id, payload);
    const labOrder = await labOrderRepository.findById(updated.id, LAB_ORDER_WITH_RELATIONS_INCLUDE);

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'lab_order',
      entity_id: updated.id,
      diff: { before, after: labOrder },
      ip_address: ipAddress
    }).catch(() => {});
    publishLabOrderRealtimeUpdate({
      orderRecord: labOrder || updated,
      actorUserId: userId,
      action: 'UPDATED'
    });

    return mapLabOrderRecord(labOrder || updated);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteLabOrder = async (id, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_order',
      where: { deleted_at: null },
      include: LAB_ORDER_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_order.not_found'
    });

    const labOrder = await labOrderRepository.softDelete(before.id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'lab_order',
      entity_id: labOrder.id,
      diff: { before, after: labOrder },
      ip_address: ipAddress
    }).catch(() => {});
    publishLabOrderRealtimeUpdate({
      orderRecord: before,
      actorUserId: userId,
      action: 'DELETED'
    });

    return mapLabOrderRecord(before);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listLabOrders,
  getLabOrderById,
  createLabOrder,
  updateLabOrder,
  deleteLabOrder
};
