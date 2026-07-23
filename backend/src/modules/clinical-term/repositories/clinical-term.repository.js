const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');


const findCatalogTerms = async (where = {}, take = 100) => {
  try {
    return await prisma.clinical_term_catalog.findMany({
      where,
      orderBy: [
        { sort_order: 'asc' },
        { usage_rank: 'asc' },
        { description: 'asc' },
      ],
      take,
      select: {
        id: true,
        code: true,
        description: true,
        category: true,
        source: true,
        sort_order: true,
        usage_rank: true,
        created_at: true,
        updated_at: true,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findFavorites = async (where = {}, orderBy = [{ usage_count: 'desc' }, { last_used_at: 'desc' }, { created_at: 'desc' }]) => {
  try {
    return await prisma.clinical_term_favorite.findMany({
      where,
      orderBy,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findFavorite = async (where = {}) => {
  try {
    return await prisma.clinical_term_favorite.findFirst({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createFavorite = async (data = {}) => {
  try {
    return await prisma.clinical_term_favorite.create({ data });
  } catch (error) {
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateFavorite = async (id, data = {}) => {
  try {
    return await prisma.clinical_term_favorite.update({
      where: { id },
      data,
    });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.clinical_term_favorite.not_found', 404);
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findRecentProcedures = async (where = {}, take = 12) => {
  try {
    return await prisma.procedure.findMany({
      where,
      orderBy: { created_at: 'desc' },
      take,
      select: {
        code: true,
        description: true,
        created_at: true,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findRecentDiagnoses = async (where = {}, take = 12) => {
  try {
    return await prisma.diagnosis.findMany({
      where,
      orderBy: { created_at: 'desc' },
      take,
      select: {
        code: true,
        description: true,
        created_at: true,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findFacilityOfferings = async (where = {}, take = 500) => {
  try {
    return await prisma.facility_catalog_offering.findMany({
      where,
      orderBy: [{ sort_order: 'asc' }, { created_at: 'asc' }],
      take,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findFacilityOffering = async (where = {}) => {
  try {
    return await prisma.facility_catalog_offering.findFirst({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createFacilityOffering = async (data = {}) => {
  try {
    return await prisma.facility_catalog_offering.create({ data });
  } catch (error) {
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateFacilityOffering = async (id, data = {}) => {
  try {
    return await prisma.facility_catalog_offering.update({
      where: { id },
      data,
    });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.facility_catalog_offering.not_found', 404);
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findCatalogTerm = async (where = {}) => {
  try {
    return await prisma.clinical_term_catalog.findFirst({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createCatalogTerm = async (data = {}) => {
  try {
    return await prisma.clinical_term_catalog.create({ data });
  } catch (error) {
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateCatalogTerm = async (id, data = {}) => {
  try {
    return await prisma.clinical_term_catalog.update({
      where: { id },
      data,
    });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.clinical_term_catalog.not_found', 404);
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findLabTests = async (where = {}, take = 500) => {
  try {
    return await prisma.lab_test.findMany({
      where,
      orderBy: [{ name: 'asc' }],
      take,
      select: {
        id: true,
        human_friendly_id: true,
        name: true,
        code: true,
        category: true,
        specimen_type: true,
        unit_price: true,
        currency: true,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findRadiologyTests = async (where = {}, take = 500) => {
  try {
    return await prisma.radiology_test.findMany({
      where,
      orderBy: [{ name: 'asc' }],
      take,
      select: {
        id: true,
        human_friendly_id: true,
        name: true,
        code: true,
        modality: true,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findDrugs = async (where = {}, take = 500) => {
  try {
    return await prisma.drug.findMany({
      where,
      orderBy: [{ name: 'asc' }],
      take,
      select: {
        id: true,
        human_friendly_id: true,
        name: true,
        code: true,
        form: true,
        strength: true,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  createCatalogTerm,
  createFavorite,
  createFacilityOffering,
  findCatalogTerm,
  findCatalogTerms,
  findDrugs,
  findFacilityOffering,
  findFacilityOfferings,
  findFavorite,
  findFavorites,
  findLabTests,
  findRadiologyTests,
  findRecentDiagnoses,
  findRecentProcedures,
  updateCatalogTerm,
  updateFacilityOffering,
  updateFavorite,
};
