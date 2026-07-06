/**
 * Facility radiology catalog repository
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const FACILITY_RADIOLOGY_TEST_OFFERING_INCLUDE = {
  radiology_test: true,
};

const findTestOffering = async (
  where = {},
  include = FACILITY_RADIOLOGY_TEST_OFFERING_INCLUDE
) => {
  try {
    return await prisma.facility_radiology_test_offering.findFirst({
      where: { deleted_at: null, ...where },
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findTestOfferings = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { sort_order: 'asc' },
  include = FACILITY_RADIOLOGY_TEST_OFFERING_INCLUDE
) => {
  try {
    return await prisma.facility_radiology_test_offering.findMany({
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

const countTestOfferings = async (filters = {}) => {
  try {
    return await prisma.facility_radiology_test_offering.count({
      where: { deleted_at: null, ...filters },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createTestOffering = async (data) => {
  try {
    return await prisma.facility_radiology_test_offering.create({
      data,
      include: FACILITY_RADIOLOGY_TEST_OFFERING_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2002') {
      throw new HttpError('errors.database.unique_field', 409, [{ field: error.meta?.target?.[0] || 'field' }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateTestOffering = async (id, data) => {
  try {
    return await prisma.facility_radiology_test_offering.update({
      where: { id },
      data,
      include: FACILITY_RADIOLOGY_TEST_OFFERING_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.facility_radiology_test_offering.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  FACILITY_RADIOLOGY_TEST_OFFERING_INCLUDE,
  findTestOffering,
  findTestOfferings,
  countTestOfferings,
  createTestOffering,
  updateTestOffering,
};
