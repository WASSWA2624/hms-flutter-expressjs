/**
 * Facility pharmacy catalog repository
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const FACILITY_PHARMACY_OFFERING_INCLUDE = {
  drug: true,
};

const findDrugOffering = async (
  where = {},
  include = FACILITY_PHARMACY_OFFERING_INCLUDE
) => {
  try {
    return await prisma.facility_pharmacy_offering.findFirst({
      where: { deleted_at: null, ...where },
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findDrugOfferings = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { sort_order: 'asc' },
  include = FACILITY_PHARMACY_OFFERING_INCLUDE
) => {
  try {
    return await prisma.facility_pharmacy_offering.findMany({
      where: { deleted_at: null, ...filters },
      skip,
      take,
      orderBy,
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const countDrugOfferings = async (filters = {}) => {
  try {
    return await prisma.facility_pharmacy_offering.count({
      where: { deleted_at: null, ...filters },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createDrugOffering = async (data) => {
  try {
    return await prisma.facility_pharmacy_offering.create({
      data,
      include: FACILITY_PHARMACY_OFFERING_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2002') {
      throw new HttpError('errors.database.unique_field', 409, [{ field: error.meta?.target?.[0] || 'field' }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateDrugOffering = async (id, data) => {
  try {
    return await prisma.facility_pharmacy_offering.update({
      where: { id },
      data,
      include: FACILITY_PHARMACY_OFFERING_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.facility_pharmacy_offering.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  FACILITY_PHARMACY_OFFERING_INCLUDE,
  findDrugOffering,
  findDrugOfferings,
  countDrugOfferings,
  createDrugOffering,
  updateDrugOffering,
};
