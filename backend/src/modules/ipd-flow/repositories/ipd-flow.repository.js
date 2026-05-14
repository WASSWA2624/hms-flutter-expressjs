/**
 * IPD flow repository
 *
 * @module modules/ipd-flow/repositories
 * @description Data access layer for IPD flow orchestration rooted on admission records.
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
  tenant_id: true,
  facility_id: true,
};

const ENCOUNTER_SELECT = {
  id: true,
  human_friendly_id: true,
  encounter_type: true,
  status: true,
  started_at: true,
  ended_at: true,
  provider_user_id: true,
};

const BED_SELECT = {
  id: true,
  human_friendly_id: true,
  label: true,
  status: true,
  ward_id: true,
  room_id: true,
  ward: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      ward_type: true,
    },
  },
  room: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      floor: true,
    },
  },
};

const BASE_INCLUDE = {
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      facility_type: true,
    },
  },
  patient: {
    select: PATIENT_SELECT,
  },
  encounter: {
    select: ENCOUNTER_SELECT,
  },
  bed_assignments: {
    where: {
      deleted_at: null,
    },
    orderBy: {
      assigned_at: 'desc',
    },
    include: {
      bed: {
        select: BED_SELECT,
      },
    },
  },
  transfer_requests: {
    where: {
      deleted_at: null,
    },
    orderBy: {
      requested_at: 'desc',
    },
    include: {
      from_ward: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
          ward_type: true,
        },
      },
      to_ward: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
          ward_type: true,
        },
      },
    },
  },
  discharge_summaries: {
    where: {
      deleted_at: null,
    },
    orderBy: {
      updated_at: 'desc',
    },
  },
  ward_rounds: {
    where: {
      deleted_at: null,
    },
    orderBy: {
      round_at: 'desc',
    },
    take: 15,
  },
  nursing_notes: {
    where: {
      deleted_at: null,
    },
    orderBy: {
      created_at: 'desc',
    },
    take: 20,
    include: {
      nurse: {
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
        },
      },
    },
  },
  medication_administrations: {
    where: {
      deleted_at: null,
    },
    orderBy: {
      administered_at: 'desc',
    },
    take: 20,
  },
  icu_stays: {
    where: {
      deleted_at: null,
    },
    orderBy: {
      started_at: 'desc',
    },
    take: 15,
    include: {
      observations: {
        where: {
          deleted_at: null,
        },
        orderBy: {
          observed_at: 'desc',
        },
        take: 40,
      },
      alerts: {
        where: {
          deleted_at: null,
        },
        orderBy: {
          created_at: 'desc',
        },
        take: 40,
      },
    },
  },
};

const findById = async (id, include = {}) => {
  try {
    return await prisma.admission.findFirst({
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
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { admitted_at: 'desc' },
  include = {}
) => {
  try {
    return await prisma.admission.findMany({
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
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const count = async (filters = {}) => {
  try {
    return await prisma.admission.count({
      where: {
        deleted_at: null,
        ...filters,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  BASE_INCLUDE,
  findById,
  findMany,
  count,
};
