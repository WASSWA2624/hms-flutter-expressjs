/**
 * Clinical catalog layered search and facility offering service
 *
 * @module modules/clinical-term/services
 * @description Unified favorites, facility-specific, and global catalog search.
 */

const clinicalTermRepository = require('@repositories/clinical-term/clinical-term.repository');
const clinicalTermService = require('@services/clinical-term/clinical-term.service');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { mapCatalogUnitPriceFields } = require('@lib/billing/clinical-request-billing');
const { buildRadiologyCatalogMetadata } = require('@lib/radiology/radiology-catalog-metadata');
const { COMMON_PROCEDURE_TERMS } = require('../data/common-procedure-terms');
const facilityLabCatalogRepository = require('@repositories/facility-lab-catalog/facility-lab-catalog.repository');
const {
  mapClinicalCatalogLabPanelRow,
  mapClinicalCatalogLabTestRow,
} = require('@services/lab-workspace/facility-lab-catalog.merge');
const {
  searchFacilityLabCatalog,
} = require('@services/facility-lab-catalog/facility-lab-catalog.service');
const facilityRadiologyCatalogRepository = require('@repositories/facility-radiology-catalog/facility-radiology-catalog.repository');
const {
  mapClinicalCatalogRadiologyTestRow,
} = require('@services/radiology-workspace/facility-radiology-catalog.merge');
const {
  searchFacilityRadiologyCatalog,
} = require('@services/facility-radiology-catalog/facility-radiology-catalog.service');
const { resolveOperationalFacilityId } = require('@lib/facility-context');
const {
  buildRadiologyProcedureSearchFilter,
} = require('@lib/radiology/radiology-procedure-search');

const CATALOG_SOURCES = new Set(['FAVORITES', 'FACILITY', 'GLOBAL', 'ALL']);

const normalizeText = (value) => String(value || '').trim();
const normalizeUpper = (value, fallback = '') => {
  const normalized = normalizeText(value).toUpperCase();
  return normalized || fallback;
};
const normalizeTermType = (value) => normalizeUpper(value, 'DIAGNOSIS');
const normalizeCatalogSource = (value) => {
  const normalized = normalizeUpper(value, 'ALL');
  return CATALOG_SOURCES.has(normalized) ? normalized : 'ALL';
};

const buildItemKey = (termType, itemId, code, description) =>
  `${termType}::${normalizeUpper(itemId)}::${normalizeUpper(code)}::${normalizeUpper(description)}`;

const matchesQuery = (query, values = []) => {
  const search = normalizeText(query).toLowerCase();
  if (!search) return true;
  const tokens = search.split(/\s+/).filter(Boolean);
  const haystack = values
    .map((value) => normalizeText(value).toLowerCase())
    .filter(Boolean)
    .join(' ');
  return tokens.every((token) => haystack.includes(token));
};

const mapFavoriteRow = (favorite, personalFavoriteIds) => ({
  id: favorite.id,
  item_id: favorite.item_id || favorite.id,
  term_type: favorite.term_type,
  code: favorite.code || null,
  description: favorite.description,
  name: favorite.description,
  category: null,
  source: 'FAVORITES',
  origin: personalFavoriteIds.has(favorite.id) ? 'PERSONAL_FAVORITE' : 'SHARED_FAVORITE',
  usage_count: favorite.usage_count || 0,
});

const mapCatalogTermRow = (row) => ({
  id: row.id,
  item_id: row.id,
  term_type: row.term_type,
  code: row.code || null,
  description: row.description,
  name: row.description,
  category: row.category || null,
  source: row.facility_id ? 'FACILITY' : 'GLOBAL',
  origin: row.source || 'UGANDA_CATALOG',
});

const mapLabTestRow = (row, source = 'GLOBAL') => ({
  id: row.human_friendly_id || row.id,
  item_id: row.id,
  term_type: 'LAB_TEST',
  code: row.code || null,
  description: row.name,
  name: row.name,
  category: row.category || null,
  source,
  origin: source === 'FACILITY' ? 'FACILITY_LAB_CATALOG' : 'GLOBAL_LAB_CATALOG',
  ...mapCatalogUnitPriceFields(row),
  metadata: {
    specimen_type: row.specimen_type || null,
  },
});

const mapRadiologyTestRow = (row, source = 'GLOBAL') => ({
  id: row.human_friendly_id || row.id,
  item_id: row.id,
  term_type: 'RADIOLOGY_TEST',
  code: row.code || null,
  description: row.name,
  name: row.name,
  category: row.modality || null,
  source,
  origin: source === 'FACILITY' ? 'FACILITY_RADIOLOGY_CATALOG' : 'GLOBAL_RADIOLOGY_CATALOG',
  ...mapCatalogUnitPriceFields(row),
  metadata: buildRadiologyCatalogMetadata(row),
});

const mapDrugRow = (row, source = 'GLOBAL') => ({
  id: row.human_friendly_id || row.id,
  item_id: row.id,
  term_type: 'PRESCRIPTION',
  code: row.code || null,
  description: row.name,
  name: row.name,
  category: [row.form, row.strength].filter(Boolean).join(' ') || null,
  source,
  origin: source === 'FACILITY' ? 'FACILITY_FORMULARY' : 'GLOBAL_DRUG_CATALOG',
});

const mapProcedureCatalogRow = (term) => ({
  id: term.id || buildItemKey('PROCEDURE', null, term.code, term.description),
  item_id: term.id || null,
  term_type: 'PROCEDURE',
  code: term.code || null,
  description: term.description,
  name: term.description,
  category: term.category || null,
  source: 'GLOBAL',
  origin: 'PROCEDURE_CATALOG',
});

const loadFavoriteItems = async ({ termType, tenantId, facilityId, q, limit, context }) => {
  const favorites = await clinicalTermService.listClinicalTermFavorites(
    {
      term_type: termType,
      facility_id: facilityId,
      q,
    },
    context
  );
  const personalFavoriteIds = new Set(
    favorites.filter((favorite) => favorite.scope === 'PERSONAL').map((favorite) => favorite.id)
  );
  return favorites
    .map((favorite) => mapFavoriteRow(favorite, personalFavoriteIds))
    .slice(0, limit);
};

const loadFacilityCatalogItems = async ({ termType, tenantId, facilityId, q, limit }) => {
  if (!facilityId) {
    return [];
  }

  const offerings = await clinicalTermRepository.findFacilityOfferings(
    {
      tenant_id: tenantId,
      facility_id: facilityId,
      term_type: termType,
      is_active: true,
      deleted_at: null,
    },
    limit * 4
  );

  const offeringItemIds = offerings.map((offering) => offering.item_id).filter(Boolean);
  if (offeringItemIds.length === 0 && termType !== 'DIAGNOSIS' && termType !== 'PROCEDURE') {
    return [];
  }

  if (termType === 'DIAGNOSIS' || termType === 'PROCEDURE') {
    const catalogRows = await clinicalTermRepository.findCatalogTerms(
      {
        tenant_id: tenantId,
        term_type: termType,
        is_active: true,
        deleted_at: null,
        OR: [{ facility_id: facilityId }, ...(offeringItemIds.length ? [{ id: { in: offeringItemIds } }] : [])],
        ...(q
          ? {
              AND: [
                {
                  OR: [
                    { code: { contains: q } },
                    { description: { contains: q } },
                    { category: { contains: q } },
                  ],
                },
              ],
            }
          : {}),
      },
      limit
    );
    return catalogRows.map((row) => mapCatalogTermRow(row));
  }

  if (termType === 'LAB_TEST') {
    const offerings = await facilityLabCatalogRepository.findTestOfferings(
      {
        tenant_id: tenantId,
        facility_id: facilityId,
        is_active: true,
        ...(q
          ? {
              lab_test: {
                deleted_at: null,
                OR: [
                  { name: { contains: q } },
                  { code: { contains: q } },
                  { category: { contains: q } },
                ],
              },
            }
          : {}),
      },
      0,
      limit
    );
    return offerings
      .map((offering) => mapClinicalCatalogLabTestRow(offering.lab_test, offering))
      .filter(Boolean);
  }

  if (termType === 'LAB_PANEL') {
    const offerings = await facilityLabCatalogRepository.findPanelOfferings(
      {
        tenant_id: tenantId,
        facility_id: facilityId,
        is_active: true,
        ...(q
          ? {
              lab_panel: {
                deleted_at: null,
                OR: [
                  { name: { contains: q } },
                  { code: { contains: q } },
                  { category: { contains: q } },
                ],
              },
            }
          : {}),
      },
      0,
      limit
    );
    return offerings
      .map((offering) => mapClinicalCatalogLabPanelRow(offering.lab_panel, offering))
      .filter(Boolean);
  }

  if (termType === 'RADIOLOGY_TEST') {
    const offerings = await facilityRadiologyCatalogRepository.findTestOfferings(
      {
        tenant_id: tenantId,
        facility_id: facilityId,
        is_active: true,
        ...(q
          ? {
              radiology_procedure: buildRadiologyProcedureSearchFilter(q),
            }
          : {}),
      },
      0,
      limit
    );
    return offerings
      .map((offering) => mapClinicalCatalogRadiologyTestRow(offering.radiology_procedure, offering))
      .filter(Boolean);
  }

  if (termType === 'PRESCRIPTION') {
    const rows = await clinicalTermRepository.findDrugs(
      {
        tenant_id: tenantId,
        deleted_at: null,
        id: { in: offeringItemIds },
        ...(q
          ? {
              OR: [
                { name: { contains: q } },
                { code: { contains: q } },
                { form: { contains: q } },
                { strength: { contains: q } },
              ],
            }
          : {}),
      },
      limit
    );
    return rows.map((row) => mapDrugRow(row, 'FACILITY'));
  }

  return [];
};

const loadGlobalCatalogItems = async ({ termType, tenantId, facilityId, q, limit }) => {
  if (termType === 'DIAGNOSIS') {
    const catalogRows = await clinicalTermRepository.findCatalogTerms(
      {
        tenant_id: tenantId,
        term_type: 'DIAGNOSIS',
        is_active: true,
        deleted_at: null,
        facility_id: null,
        ...(q
          ? {
              AND: [
                {
                  OR: [
                    { code: { contains: q } },
                    { description: { contains: q } },
                    { category: { contains: q } },
                  ],
                },
              ],
            }
          : {}),
      },
      limit
    );
    return catalogRows.map((row) => mapCatalogTermRow({ ...row, facility_id: null }));
  }

  if (termType === 'PROCEDURE') {
    const catalogRows = await clinicalTermRepository.findCatalogTerms(
      {
        tenant_id: tenantId,
        term_type: 'PROCEDURE',
        is_active: true,
        deleted_at: null,
        facility_id: null,
        ...(q
          ? {
              AND: [
                {
                  OR: [
                    { code: { contains: q } },
                    { description: { contains: q } },
                    { category: { contains: q } },
                  ],
                },
              ],
            }
          : {}),
      },
      Math.max(0, limit - COMMON_PROCEDURE_TERMS.length)
    );

    const procedureCatalog = COMMON_PROCEDURE_TERMS.filter((term) =>
      matchesQuery(q, [term.description, term.code, term.category, term.search_text])
    ).map(mapProcedureCatalogRow);

    return [...catalogRows.map((row) => mapCatalogTermRow({ ...row, facility_id: null })), ...procedureCatalog]
      .slice(0, limit);
  }

  if (termType === 'LAB_TEST') {
    const rows = await clinicalTermRepository.findLabTests(
      {
        tenant_id: tenantId,
        deleted_at: null,
        ...(q
          ? {
              OR: [
                { name: { contains: q } },
                { code: { contains: q } },
                { category: { contains: q } },
              ],
            }
          : {}),
      },
      limit
    );
    return rows.map((row) => mapLabTestRow(row, 'GLOBAL'));
  }

  if (termType === 'RADIOLOGY_TEST') {
    const rows = await clinicalTermRepository.findRadiologyTests(
      {
        tenant_id: tenantId,
        deleted_at: null,
        ...(q
          ? {
              OR: [
                { name: { contains: q } },
                { code: { contains: q } },
              ],
            }
          : {}),
      },
      limit
    );
    return rows.map((row) => mapRadiologyTestRow(row, 'GLOBAL'));
  }

  if (termType === 'PRESCRIPTION') {
    const rows = await clinicalTermRepository.findDrugs(
      {
        tenant_id: tenantId,
        deleted_at: null,
        ...(q
          ? {
              OR: [
                { name: { contains: q } },
                { code: { contains: q } },
                { form: { contains: q } },
                { strength: { contains: q } },
              ],
            }
          : {}),
      },
      limit
    );
    return rows.map((row) => mapDrugRow(row, 'GLOBAL'));
  }

  return [];
};

const mergeCatalogItems = (items, limit) => {
  const merged = new Map();
  items.forEach((item) => {
    const key = buildItemKey(item.term_type, item.item_id, item.code, item.description);
    const existing = merged.get(key);
    if (!existing) {
      merged.set(key, item);
      return;
    }
    const sourcePriority = {
      FAVORITES: 3,
      FACILITY: 2,
      GLOBAL: 1,
    };
    if ((sourcePriority[item.source] || 0) > (sourcePriority[existing.source] || 0)) {
      merged.set(key, item);
    }
  });
  return Array.from(merged.values()).slice(0, limit);
};

const listClinicalCatalogSearch = async (filters = {}, context = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id || null;
  const userId = context.user_id || null;
  if (!tenantId || !userId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const termType = normalizeTermType(filters.term_type);
  const source = normalizeCatalogSource(filters.source);
  const q = normalizeText(filters.q);
  const limit = Number(filters.limit || 80);
  const safeLimit = Number.isFinite(limit) ? Math.max(1, Math.min(1000, limit)) : 80;
  let facilityId =
    filters.facility_id !== undefined
      ? filters.facility_id || null
      : context.facility_id || null;
  if (!facilityId) {
    facilityId = await resolveOperationalFacilityId({
      userId,
      tenantId,
    });
  }

  if (termType === 'DIAGNOSIS' || termType === 'PROCEDURE') {
    if (source === 'ALL') {
      return clinicalTermService.listClinicalTermSuggestions(
        {
          ...filters,
          term_type: termType,
          q,
          limit: safeLimit,
          facility_id: facilityId,
        },
        context
      );
    }
  }

  const offeredOnly = String(filters.offered_only || '').toLowerCase() === 'true';
  if (offeredOnly && (termType === 'LAB_TEST' || termType === 'LAB_PANEL')) {
    return searchFacilityLabCatalog(
      {
        ...filters,
        term_type: termType,
        q,
        limit: safeLimit,
        offered_only: 'true',
        facility_id: facilityId,
      },
      context
    );
  }
  if (offeredOnly && termType === 'RADIOLOGY_TEST') {
    return searchFacilityRadiologyCatalog(
      {
        ...filters,
        term_type: termType,
        q,
        limit: safeLimit,
        offered_only: 'true',
        facility_id: facilityId,
      },
      context
    );
  }

  const loaders = [];
  if (source === 'ALL' || source === 'FAVORITES') {
    loaders.push(
      loadFavoriteItems({
        termType,
        tenantId,
        facilityId,
        q,
        limit: safeLimit,
        context,
      })
    );
  }
  if (source === 'ALL' || source === 'FACILITY') {
    loaders.push(
      loadFacilityCatalogItems({
        termType,
        tenantId,
        facilityId,
        q,
        limit: safeLimit,
      })
    );
  }
  if (source === 'ALL' || source === 'GLOBAL') {
    loaders.push(
      loadGlobalCatalogItems({
        termType,
        tenantId,
        facilityId,
        q,
        limit: safeLimit,
      })
    );
  }

  const groups = await Promise.all(loaders);
  return mergeCatalogItems(groups.flat(), safeLimit);
};

const listFacilityCatalogOfferings = async (filters = {}, context = {}) => {
  const tenantId = context.tenant_id || filters.tenant_id || null;
  if (!tenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }

  const facilityId = filters.facility_id || context.facility_id || null;
  if (!facilityId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'facility_id' }]);
  }

  const termType = filters.term_type ? normalizeTermType(filters.term_type) : null;
  const q = normalizeText(filters.q);

  const offerings = await clinicalTermRepository.findFacilityOfferings(
    {
      tenant_id: tenantId,
      facility_id: facilityId,
      deleted_at: null,
      ...(termType ? { term_type: termType } : {}),
    },
    2000
  );

  if (!q) {
    return offerings;
  }

  const hydrated = await listClinicalCatalogSearch(
    {
      term_type: termType || 'DIAGNOSIS',
      source: 'FACILITY',
      facility_id: facilityId,
      q,
      limit: 2000,
    },
    context
  );
  const allowedIds = new Set(hydrated.map((item) => item.item_id));
  return offerings.filter((offering) => allowedIds.has(offering.item_id));
};

const upsertFacilityCatalogOffering = async (payload = {}, context = {}) => {
  const tenantId = context.tenant_id || payload.tenant_id || null;
  const userId = context.user_id || null;
  if (!tenantId || !userId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const facilityId = payload.facility_id || context.facility_id || null;
  if (!facilityId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'facility_id' }]);
  }

  const termType = normalizeTermType(payload.term_type);
  const itemId = normalizeText(payload.item_id);
  if (!itemId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'item_id' }]);
  }

  const existing = await clinicalTermRepository.findFacilityOffering({
    tenant_id: tenantId,
    facility_id: facilityId,
    term_type: termType,
    item_id: itemId,
    deleted_at: null,
  });

  const data = {
    tenant_id: tenantId,
    facility_id: facilityId,
    term_type: termType,
    item_id: itemId,
    is_active: payload.is_active !== false,
    sort_order: Number(payload.sort_order || 0),
  };

  const offering = existing
    ? await clinicalTermRepository.updateFacilityOffering(existing.id, data)
    : await clinicalTermRepository.createFacilityOffering(data);

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: existing ? 'UPDATE' : 'CREATE',
    entity: 'facility_catalog_offering',
    entity_id: offering.id,
    diff: { after: offering },
    ip_address: context.ip_address,
  }).catch(() => {});

  return offering;
};

const deleteFacilityCatalogOffering = async (id, context = {}) => {
  const tenantId = context.tenant_id || null;
  const userId = context.user_id || null;
  if (!tenantId || !userId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const offering = await clinicalTermRepository.findFacilityOffering({
    id,
    tenant_id: tenantId,
    deleted_at: null,
  });
  if (!offering) {
    throw new HttpError('errors.facility_catalog_offering.not_found', 404);
  }

  await clinicalTermRepository.updateFacilityOffering(offering.id, { deleted_at: new Date() });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'DELETE',
    entity: 'facility_catalog_offering',
    entity_id: offering.id,
    diff: { before: offering },
    ip_address: context.ip_address,
  }).catch(() => {});
};

const slugify = (value) =>
  String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 100) || `term_${Date.now()}`;

const mapCatalogTermWriteRow = (row) => ({
  id: row.id,
  item_id: row.id,
  term_type: row.term_type,
  code: row.code || null,
  description: row.description,
  name: row.description,
  category: row.category || null,
  source: 'GLOBAL',
  origin: row.source || 'CUSTOM',
});

const createCatalogTerm = async (payload = {}, context = {}) => {
  const tenantId = context.tenant_id || payload.tenant_id || null;
  const userId = context.user_id || null;
  if (!tenantId || !userId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const termType = normalizeUpper(payload.term_type, 'DIAGNOSIS');
  const description = normalizeText(payload.description);
  if (!description) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'description' }]);
  }

  const code = payload.code ? normalizeText(payload.code) : null;
  const rawKey = normalizeText(payload.catalog_key) || null;
  let catalogKey = rawKey || (code ? slugify(code) : slugify(description));
  if (!catalogKey.startsWith('custom_')) {
    catalogKey = `custom_${catalogKey}`;
  }

  const data = {
    tenant_id: tenantId,
    facility_id: null,
    term_type: termType,
    code: code || null,
    description,
    category: payload.category ? normalizeText(payload.category) : null,
    catalog_key: catalogKey,
    source: normalizeText(payload.source) || 'CUSTOM',
    sort_order: Number(payload.sort_order ?? 0),
    usage_rank: Number(payload.usage_rank ?? 0),
    is_active: true,
    deleted_at: null,
  };

  let term;
  try {
    term = await clinicalTermRepository.createCatalogTerm(data);
  } catch (err) {
    if (err.message === 'errors.database.unique_field') {
      const suffixedKey = `${catalogKey}_${Date.now().toString(36)}`;
      term = await clinicalTermRepository.createCatalogTerm({ ...data, catalog_key: suffixedKey });
    } else {
      throw err;
    }
  }

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'CREATE',
    entity: 'clinical_term_catalog',
    entity_id: term.id,
    diff: { after: term },
    ip_address: context.ip_address,
  }).catch(() => {});

  return mapCatalogTermWriteRow(term);
};

const updateCatalogTerm = async (id, payload = {}, context = {}) => {
  const tenantId = context.tenant_id || null;
  const userId = context.user_id || null;
  if (!tenantId || !userId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const existing = await clinicalTermRepository.findCatalogTerm({
    id,
    tenant_id: tenantId,
    deleted_at: null,
  });
  if (!existing) {
    throw new HttpError('errors.clinical_term_catalog.not_found', 404);
  }

  const data = {};
  if (payload.code !== undefined) data.code = payload.code ? normalizeText(payload.code) : null;
  if (payload.description !== undefined) data.description = normalizeText(payload.description);
  if (payload.category !== undefined) data.category = payload.category ? normalizeText(payload.category) : null;
  if (payload.source !== undefined) data.source = normalizeText(payload.source);
  if (payload.sort_order !== undefined) data.sort_order = Number(payload.sort_order);
  if (payload.usage_rank !== undefined) data.usage_rank = Number(payload.usage_rank);
  if (payload.is_active !== undefined) data.is_active = Boolean(payload.is_active);

  const term = await clinicalTermRepository.updateCatalogTerm(id, data);

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'UPDATE',
    entity: 'clinical_term_catalog',
    entity_id: term.id,
    diff: { before: existing, after: term },
    ip_address: context.ip_address,
  }).catch(() => {});

  return mapCatalogTermWriteRow(term);
};

const deleteCatalogTerm = async (id, context = {}) => {
  const tenantId = context.tenant_id || null;
  const userId = context.user_id || null;
  if (!tenantId || !userId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const existing = await clinicalTermRepository.findCatalogTerm({
    id,
    tenant_id: tenantId,
    deleted_at: null,
  });
  if (!existing) {
    throw new HttpError('errors.clinical_term_catalog.not_found', 404);
  }

  await clinicalTermRepository.updateCatalogTerm(id, { deleted_at: new Date() });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'DELETE',
    entity: 'clinical_term_catalog',
    entity_id: existing.id,
    diff: { before: existing },
    ip_address: context.ip_address,
  }).catch(() => {});
};

module.exports = {
  listClinicalCatalogSearch,
  listFacilityCatalogOfferings,
  upsertFacilityCatalogOffering,
  deleteFacilityCatalogOffering,
  createCatalogTerm,
  updateCatalogTerm,
  deleteCatalogTerm,
};
