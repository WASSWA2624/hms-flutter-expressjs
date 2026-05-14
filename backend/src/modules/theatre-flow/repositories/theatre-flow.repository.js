/**
 * Theatre flow repository
 *
 * @module modules/theatre-flow/repositories
 * @description Data access layer for theatre flow orchestration rooted on theatre_case records.
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const PATIENT_SELECT = {
  id: true,
  human_friendly_id: true,
  first_name: true,
  last_name: true,
  date_of_birth: true,
  gender: true,
};

const ENCOUNTER_SELECT = {
  id: true,
  human_friendly_id: true,
  tenant_id: true,
  facility_id: true,
  patient_id: true,
  encounter_type: true,
  status: true,
  started_at: true,
  ended_at: true,
};

const BASE_INCLUDE = {
  encounter: {
    select: {
      ...ENCOUNTER_SELECT,
      patient: {
        select: PATIENT_SELECT,
      },
    },
  },
  anesthesia_records: {
    where: {
      deleted_at: null,
    },
    orderBy: {
      updated_at: 'desc',
    },
    include: {
      anesthetist: {
        select: {
          id: true,
          human_friendly_id: true,
          email: true,
          profile: {
            select: {
              first_name: true,
              middle_name: true,
              last_name: true,
            },
          },
          staff_profile: {
            select: {
              id: true,
              human_friendly_id: true,
            },
          },
        },
      },
    },
  },
  post_op_notes: {
    where: {
      deleted_at: null,
    },
    orderBy: {
      updated_at: 'desc',
    },
  },
  resource_allocations: {
    where: {
      deleted_at: null,
    },
    orderBy: {
      assigned_at: 'desc',
    },
  },
  checklist_items: {
    where: {
      deleted_at: null,
    },
    orderBy: [{ phase: 'asc' }, { item_code: 'asc' }],
  },
  anesthesia_observations: {
    where: {
      deleted_at: null,
    },
    orderBy: {
      observed_at: 'desc',
    },
    take: 120,
  },
};

const findById = async (id, include = {}) => {
  try {
    return await prisma.theatre_case.findFirst({
      where: {
        id,
        deleted_at: null,
      },
      include: {
        ...BASE_INCLUDE,
        ...include,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { scheduled_at: 'desc' },
  include = {}
) => {
  try {
    return await prisma.theatre_case.findMany({
      where: {
        deleted_at: null,
        ...filters,
      },
      skip,
      take,
      orderBy,
      include: {
        ...BASE_INCLUDE,
        ...include,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const count = async (filters = {}) => {
  try {
    return await prisma.theatre_case.count({
      where: {
        deleted_at: null,
        ...filters,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

module.exports = {
  BASE_INCLUDE,
  findById,
  findMany,
  count,
};

