/**
 * Facility lab catalog repository
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const FACILITY_TEST_OFFERING_INCLUDE = {
  lab_test: {
    include: {
      reference_ranges: { orderBy: { sort_order: 'asc' } },
      unit_options: { orderBy: { sort_order: 'asc' } },
      result_options: { orderBy: { sort_order: 'asc' } }}},
  reference_ranges: { orderBy: { sort_order: 'asc' } },
  unit_options: { orderBy: { sort_order: 'asc' } },
  result_options: { orderBy: { sort_order: 'asc' } }};

const FACILITY_PANEL_OFFERING_INCLUDE = {
  lab_panel: {
    include: {
      panel_items: {
        orderBy: { sort_order: 'asc' },
        include: {
          lab_test: {
            select: {
              id: true,
              human_friendly_id: true,
              name: true,
              code: true,
              unit: true}}}}}}};

const findTestOffering = async (where = {}, include = FACILITY_TEST_OFFERING_INCLUDE) => {
  try {
    return await prisma.facility_lab_test_offering.findFirst({
      where: { deleted_at: null, ...where },
      include});
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findTestOfferings = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { sort_order: 'asc' },
  include = FACILITY_TEST_OFFERING_INCLUDE
) => {
  try {
    return await prisma.facility_lab_test_offering.findMany({
      where: { deleted_at: null, ...filters },
      skip,
      take,
      orderBy,
      include});
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const countTestOfferings = async (filters = {}) => {
  try {
    return await prisma.facility_lab_test_offering.count({
      where: { deleted_at: null, ...filters }});
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createTestOffering = async (data) => {
  try {
    return await prisma.facility_lab_test_offering.create({ data, include: FACILITY_TEST_OFFERING_INCLUDE });
  } catch (error) {
    if (error.code === 'P2002') {
      throw new HttpError('errors.database.unique_field', 409, [{ field: error.meta?.target?.[0] || 'field' }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateTestOffering = async (id, data) => {
  try {
    return await prisma.facility_lab_test_offering.update({
      where: { id },
      data,
      include: FACILITY_TEST_OFFERING_INCLUDE});
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.facility_lab_test_offering.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findPanelOffering = async (where = {}, include = FACILITY_PANEL_OFFERING_INCLUDE) => {
  try {
    return await prisma.facility_lab_panel_offering.findFirst({
      where: { deleted_at: null, ...where },
      include});
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findPanelOfferings = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { sort_order: 'asc' },
  include = FACILITY_PANEL_OFFERING_INCLUDE
) => {
  try {
    return await prisma.facility_lab_panel_offering.findMany({
      where: { deleted_at: null, ...filters },
      skip,
      take,
      orderBy,
      include});
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const countPanelOfferings = async (filters = {}) => {
  try {
    return await prisma.facility_lab_panel_offering.count({
      where: { deleted_at: null, ...filters }});
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createPanelOffering = async (data) => {
  try {
    return await prisma.facility_lab_panel_offering.create({ data, include: FACILITY_PANEL_OFFERING_INCLUDE });
  } catch (error) {
    if (error.code === 'P2002') {
      throw new HttpError('errors.database.unique_field', 409, [{ field: error.meta?.target?.[0] || 'field' }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updatePanelOffering = async (id, data) => {
  try {
    return await prisma.facility_lab_panel_offering.update({
      where: { id },
      data,
      include: FACILITY_PANEL_OFFERING_INCLUDE});
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.facility_lab_panel_offering.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  FACILITY_TEST_OFFERING_INCLUDE,
  FACILITY_PANEL_OFFERING_INCLUDE,
  findTestOffering,
  findTestOfferings,
  countTestOfferings,
  createTestOffering,
  updateTestOffering,
  findPanelOffering,
  findPanelOfferings,
  countPanelOfferings,
  createPanelOffering,
  updatePanelOffering};
