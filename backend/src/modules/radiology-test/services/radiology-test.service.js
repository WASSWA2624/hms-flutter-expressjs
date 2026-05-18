/**
 * Radiology test service
 *
 * @module modules/radiology-test/services
 * @description Business logic layer for radiology test operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const radiologyTestRepository = require('@repositories/radiology-test/radiology-test.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  normalizeIdentifier,
  resolveModelIdByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

const buildPagination = (page, limit, total) => {
  const totalPages = Math.max(1, Math.ceil(total / limit));
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

const buildEmptyListResult = (page, limit) => ({
  radiologyTests: [],
  pagination: buildPagination(page, limit, 0),
});

const resolveResourceId = async (model, identifier) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return normalized;

  const resolved = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where: { deleted_at: null },
  });

  return resolved || normalized;
};

const STANDARD_RADIOLOGY_CATALOG_TARGET_SIZE = 6500;
const STANDARD_RADIOLOGY_TEST_ID_PREFIX = 'STD_RAD_TEST_';
const standardRadiologyTestId = (code) =>
  `${STANDARD_RADIOLOGY_TEST_ID_PREFIX}${code}`;
const normalizeText = (value) => String(value || '').trim();
const includesIgnoreCase = (value, query) =>
  normalizeText(value).toLowerCase().includes(query);

const RADIOLOGY_BODY_REGIONS = Object.freeze([
  'Abdomen',
  'Abdomen and pelvis',
  'Acetabulum',
  'Adrenal glands',
  'Ankle',
  'Aorta',
  'Appendix',
  'Arm',
  'Axilla',
  'Biliary tree',
  'Bladder',
  'Brachial plexus',
  'Brain',
  'Breast',
  'Calcaneus',
  'Carotid arteries',
  'Cervical spine',
  'Chest',
  'Clavicle',
  'Coccyx',
  'Colon',
  'Elbow',
  'Esophagus',
  'Face',
  'Femur',
  'Fetal anatomy',
  'Finger',
  'Foot',
  'Forearm',
  'Gallbladder',
  'Hand',
  'Head',
  'Heart',
  'Hepatobiliary system',
  'Hip',
  'Humerus',
  'Internal auditory canals',
  'Kidneys',
  'Knee',
  'Larynx',
  'Leg',
  'Liver',
  'Lumbar spine',
  'Lung',
  'Mandible',
  'Mastoid',
  'Maxillofacial region',
  'Mediastinum',
  'Neck',
  'Orbit',
  'Ovary',
  'Pancreas',
  'Paranasal sinuses',
  'Pelvis',
  'Peripheral arteries',
  'Peripheral veins',
  'Prostate',
  'Renal arteries',
  'Ribs',
  'Sacrum',
  'Scapula',
  'Scrotum',
  'Shoulder',
  'Small bowel',
  'Soft tissue',
  'Spleen',
  'Sternum',
  'Temporomandibular joint',
  'Thoracic spine',
  'Thyroid',
  'Tibia and fibula',
  'Toe',
  'Uterus',
  'Wrist'
]);

const PAIRED_BODY_REGIONS = new Set([
  'Acetabulum',
  'Adrenal glands',
  'Ankle',
  'Arm',
  'Axilla',
  'Brachial plexus',
  'Breast',
  'Calcaneus',
  'Carotid arteries',
  'Clavicle',
  'Elbow',
  'Femur',
  'Finger',
  'Foot',
  'Forearm',
  'Gallbladder',
  'Hand',
  'Hip',
  'Humerus',
  'Internal auditory canals',
  'Kidneys',
  'Knee',
  'Leg',
  'Lung',
  'Mastoid',
  'Orbit',
  'Ovary',
  'Peripheral arteries',
  'Peripheral veins',
  'Renal arteries',
  'Ribs',
  'Scapula',
  'Scrotum',
  'Shoulder',
  'Soft tissue',
  'Temporomandibular joint',
  'Thyroid',
  'Tibia and fibula',
  'Toe',
  'Wrist'
]);

const RADIOLOGY_MODALITY_DEFINITIONS = Object.freeze([
  {
    modality: 'XRAY',
    equipment: 'Digital radiography system',
    protocols: [
      'X-Ray AP view',
      'X-Ray PA view',
      'X-Ray lateral view',
      'X-Ray oblique view',
      'X-Ray two views',
      'Portable X-Ray'
    ]
  },
  {
    modality: 'CT',
    equipment: 'Multidetector CT scanner',
    protocols: [
      'CT without contrast',
      'CT with IV contrast',
      'CT with and without contrast',
      'CT angiography',
      'CT venography',
      'CT perfusion',
      'Low dose CT',
      'CT 3D reconstruction'
    ]
  },
  {
    modality: 'MRI',
    equipment: 'MRI scanner',
    protocols: [
      'MRI without contrast',
      'MRI with contrast',
      'MRI with and without contrast',
      'MR angiography',
      'MR venography',
      'MRI diffusion protocol',
      'MRI functional protocol'
    ]
  },
  {
    modality: 'ULTRASOUND',
    equipment: 'Ultrasound machine',
    protocols: [
      'Ultrasound',
      'Doppler ultrasound',
      'Duplex ultrasound',
      'Point-of-care ultrasound',
      'Elastography ultrasound',
      'Ultrasound guided assessment'
    ]
  },
  {
    modality: 'FLUOROSCOPY',
    equipment: 'Fluoroscopy unit',
    protocols: [
      'Fluoroscopy',
      'Contrast fluoroscopy',
      'Dynamic fluoroscopy',
      'Fluoroscopic guided assessment',
      'Fluoroscopic guided injection'
    ]
  },
  {
    modality: 'MAMMOGRAPHY',
    equipment: 'Digital mammography unit',
    protocols: [
      'Screening mammography',
      'Diagnostic mammography',
      'Tomosynthesis mammography',
      'Magnification mammography',
      'Stereotactic breast procedure'
    ]
  },
  {
    modality: 'PET',
    equipment: 'PET CT scanner',
    protocols: [
      'PET CT',
      'FDG PET CT',
      'PSMA PET CT',
      'Dotatate PET CT',
      'PET metabolic assessment'
    ]
  },
  {
    modality: 'NUCLEAR_MEDICINE',
    equipment: 'Gamma camera',
    protocols: [
      'Nuclear medicine scan',
      'SPECT CT',
      'Bone scan',
      'Perfusion scan',
      'Radionuclide functional study'
    ]
  },
  {
    modality: 'INTERVENTIONAL_RADIOLOGY',
    equipment: 'Interventional radiology suite',
    protocols: [
      'Image-guided biopsy',
      'Image-guided aspiration',
      'Image-guided drain placement',
      'Image-guided catheter exchange',
      'Image-guided injection',
      'Image-guided ablation',
      'Image-guided embolization',
      'Image-guided stent placement'
    ]
  },
  {
    modality: 'ECG',
    equipment: 'Electrocardiograph',
    protocols: [
      'Resting ECG',
      'Stress ECG',
      'Holter ECG',
      'Event monitor ECG'
    ]
  },
  {
    modality: 'ECHO',
    equipment: 'Echocardiography machine',
    protocols: [
      'Transthoracic echocardiogram',
      'Transesophageal echocardiogram',
      'Stress echocardiogram',
      'Focused cardiac ultrasound'
    ]
  },
  {
    modality: 'ENDO',
    equipment: 'Endoscopy suite',
    protocols: [
      'Diagnostic endoscopy',
      'Therapeutic endoscopy',
      'Endoscopic biopsy',
      'Endoscopic guided procedure'
    ]
  },
  {
    modality: 'GASTRO',
    equipment: 'Gastroenterology procedure suite',
    protocols: [
      'Colonoscopy',
      'Flexible sigmoidoscopy',
      'Upper GI endoscopy',
      'Capsule endoscopy'
    ]
  }
]);

const codeFragment = (value) =>
  normalizeText(value)
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 18);

const buildStandardRadiologyTests = () => {
  const records = {};
  let sequence = 1;

  for (const definition of RADIOLOGY_MODALITY_DEFINITIONS) {
    for (const region of RADIOLOGY_BODY_REGIONS) {
      const lateralityOptions = PAIRED_BODY_REGIONS.has(region)
        ? ['', 'Left', 'Right', 'Bilateral']
        : [''];

      for (const protocol of definition.protocols) {
        for (const laterality of lateralityOptions) {
          if (sequence > STANDARD_RADIOLOGY_CATALOG_TARGET_SIZE) {
            return Object.freeze(records);
          }

          const sequenceCode = String(sequence).padStart(5, '0');
          const code = `RAD-${sequenceCode}`;
          const bodyRegion = laterality
            ? `${laterality} ${region}`
            : region;
          const name = `${bodyRegion} ${protocol}`;
          const key = code;
          records[key] = Object.freeze({
            name,
            code,
            modality: definition.modality,
            equipment: definition.equipment,
            body_region: region,
            laterality: laterality || null,
            procedure_type: protocol,
            search_terms: [
              name,
              protocol,
              definition.modality,
              definition.equipment,
              region,
              laterality,
              codeFragment(region),
              codeFragment(protocol),
            ].filter(Boolean),
          });
          sequence += 1;
        }
      }
    }
  }

  return Object.freeze(records);
};

const STANDARD_RADIOLOGY_TESTS = buildStandardRadiologyTests();

const standardRadiologyTestMatchesFilters = (key, definition, filters = {}) => {
  const normalizedCode = normalizeText(definition.code).toLowerCase();
  const normalizedName = normalizeText(definition.name).toLowerCase();
  const normalizedEquipment = normalizeText(definition.equipment).toLowerCase();
  const normalizedRegion = normalizeText(definition.body_region).toLowerCase();
  const normalizedProcedureType = normalizeText(definition.procedure_type).toLowerCase();

  if (filters.code && !normalizedCode.includes(normalizeText(filters.code).toLowerCase())) return false;
  if (filters.name && !normalizedName.includes(normalizeText(filters.name).toLowerCase())) return false;
  if (filters.modality && definition.modality !== filters.modality) return false;
  if (filters.equipment && !normalizedEquipment.includes(normalizeText(filters.equipment).toLowerCase())) return false;
  if (filters.body_region && !normalizedRegion.includes(normalizeText(filters.body_region).toLowerCase())) return false;
  if (filters.procedure_type && !normalizedProcedureType.includes(normalizeText(filters.procedure_type).toLowerCase())) return false;

  const search = normalizeText(filters.search).toLowerCase();
  if (!search) return true;

  return [
    standardRadiologyTestId(key),
    definition.name,
    definition.code,
    definition.modality,
    definition.equipment,
    definition.body_region,
    definition.laterality,
    definition.procedure_type,
    ...(definition.search_terms || []),
  ].some((value) => includesIgnoreCase(value, search));
};

const standardRadiologyTestRecord = ([key, definition]) => ({
  id: standardRadiologyTestId(key),
  display_id: standardRadiologyTestId(key),
  human_friendly_id: standardRadiologyTestId(key),
  name: definition.name,
  code: definition.code,
  modality: definition.modality,
  equipment: definition.equipment,
  body_region: definition.body_region,
  laterality: definition.laterality,
  procedure_type: definition.procedure_type,
  status: 'STANDARD',
  source: 'STANDARD_RADIOLOGY_CATALOG',
  search_text: [
    definition.name,
    definition.code,
    definition.modality,
    definition.equipment,
    definition.body_region,
    definition.laterality,
    definition.procedure_type,
    ...(definition.search_terms || []),
  ].filter(Boolean).join(' '),
});

const mergeStandardRadiologyTests = ({
  mappedRecords,
  dbRecords,
  dbTotal,
  filters,
  limit,
  sortBy,
  order,
}) => {
  if (String(filters.include_standard_catalog || '').toLowerCase() !== 'true') {
    return { records: mappedRecords, total: null };
  }

  const existingCodes = new Set(
    dbRecords
      .map((record) => normalizeText(record?.code).toUpperCase())
      .filter(Boolean)
  );
  const standardRecords = Object.entries(STANDARD_RADIOLOGY_TESTS)
    .filter(([key, definition]) => (
      !existingCodes.has(normalizeText(definition.code).toUpperCase())
      && standardRadiologyTestMatchesFilters(key, definition, filters)
    ))
    .map(standardRadiologyTestRecord);

  const direction = String(order || 'asc').toLowerCase() === 'desc' ? -1 : 1;
  const sortableField = sortBy || 'name';
  const records = [...mappedRecords, ...standardRecords]
    .sort((left, right) => (
      normalizeText(left?.[sortableField] || left?.name)
        .localeCompare(normalizeText(right?.[sortableField] || right?.name)) * direction
    ))
    .slice(0, limit);

  return {
    records,
    total: Math.max(records.length, Number(dbTotal || 0) + standardRecords.length),
  };
};

const resolveOrCreateStandardRadiologyTest = async ({
  code,
  tenantId,
  userId,
  ipAddress,
}) => {
  const definition = STANDARD_RADIOLOGY_TESTS[normalizeText(code).toUpperCase()];
  if (!definition) return null;

  const existing = await radiologyTestRepository.findMany(
    {
      tenant_id: tenantId,
      code: definition.code,
    },
    0,
    1,
    { created_at: 'desc' }
  );
  if (existing[0]) return { id: existing[0].id };

  const radiologyTest = await radiologyTestRepository.create({
    tenant_id: tenantId,
    name: definition.name,
    code: definition.code,
    modality: definition.modality,
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'CREATE',
    entity: 'radiology_test',
    entity_id: radiologyTest.id,
    diff: {
      after: {
        ...definition,
        id: radiologyTest.id,
        source: 'STANDARD_RADIOLOGY_CATALOG',
      },
    },
    ip_address: ipAddress,
  }).catch(() => {});

  return { id: radiologyTest.id };
};

/**
 * List radiology tests with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Radiology tests and pagination data
 */
const listRadiologyTests = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id !== undefined) {
      const tenantId = await resolveIdentifierForFilter({
        value: filters.tenant_id,
        model: 'tenant',
        where: { deleted_at: null },
      });
      if (tenantId === null) return buildEmptyListResult(page, limit);
      if (tenantId !== undefined) whereClause.tenant_id = tenantId;
    }
    if (filters.modality) whereClause.modality = filters.modality;
    if (filters.code) whereClause.code = { contains: filters.code };
    if (filters.name) whereClause.name = { contains: filters.name };
    
    // Search filter (searches in name, code)
    if (filters.search) {
      whereClause.OR = [
        { name: { contains: filters.search } },
        { code: { contains: filters.search } }
      ];
    }

    const [radiologyTests, total] = await Promise.all([
      radiologyTestRepository.findMany(whereClause, skip, limit, orderBy),
      radiologyTestRepository.count(whereClause)
    ]);
    const merged = mergeStandardRadiologyTests({
      mappedRecords: radiologyTests,
      dbRecords: radiologyTests,
      dbTotal: total,
      filters,
      limit,
      sortBy,
      order,
    });

    return {
      radiologyTests: merged.records,
      pagination: buildPagination(page, limit, merged.total ?? total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get radiology test by ID
 *
 * @param {string} id - Radiology test ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Radiology test data
 */
const getRadiologyTestById = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_test', id);
    const radiologyTest = await radiologyTestRepository.findById(resolvedId);

    if (!radiologyTest) {
      throw new HttpError('errors.radiology_test.not_found', 404);
    }

    return radiologyTest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new radiology test
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Radiology test data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created radiology test
 */
const createRadiologyTest = async (data, userId, ipAddress) => {
  try {
    const normalizedData = {
      ...data,
      tenant_id: await resolveIdentifierForPayload({
        value: data.tenant_id,
        field: 'tenant_id',
        model: 'tenant',
        where: { deleted_at: null },
      }),
    };
    const radiologyTest = await radiologyTestRepository.create(normalizedData);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'radiology_test',
      entity_id: radiologyTest.id,
      diff: { after: radiologyTest },
      ip_address: ipAddress
    }).catch(() => {});

    return radiologyTest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update radiology test
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Radiology test ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated radiology test
 */
const updateRadiologyTest = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_test', id);

    // Get current state for audit
    const before = await radiologyTestRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.radiology_test.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'tenant_id')) {
      payload.tenant_id = await resolveIdentifierForPayload({
        value: payload.tenant_id,
        field: 'tenant_id',
        model: 'tenant',
        where: { deleted_at: null },
      });
    }

    const radiologyTest = await radiologyTestRepository.update(resolvedId, payload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'radiology_test',
      entity_id: radiologyTest.id,
      diff: { before, after: radiologyTest },
      ip_address: ipAddress
    }).catch(() => {});

    return radiologyTest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete radiology test (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Radiology test ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteRadiologyTest = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_test', id);

    // Get current state for audit
    const before = await radiologyTestRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.radiology_test.not_found', 404);
    }

    await radiologyTestRepository.softDelete(resolvedId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'radiology_test',
      entity_id: resolvedId,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  STANDARD_RADIOLOGY_TESTS,
  resolveOrCreateStandardRadiologyTest,
  listRadiologyTests,
  getRadiologyTestById,
  createRadiologyTest,
  updateRadiologyTest,
  deleteRadiologyTest
};
