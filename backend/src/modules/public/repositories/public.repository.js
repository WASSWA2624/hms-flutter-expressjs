/**
 * Public repository
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const buildSearchFilter = (search) => {
  if (!search) {
    return undefined;
  }

  return {
    contains: search
  };
};

const listPublicServices = async (search, skip, take, orderBy) => {
  try {
    const where = {
      deleted_at: null,
      is_active: true
    };

    if (search) {
      where.OR = [
        { name: buildSearchFilter(search) },
        { short_name: buildSearchFilter(search) }
      ];
    }

    const [items, total] = await Promise.all([
      prisma.department.findMany({
        where,
        skip,
        take,
        orderBy,
        select: {
          id: true,
          name: true,
          short_name: true,
          department_type: true,
          facility_id: true,
          branch_id: true
        }
      }),
      prisma.department.count({ where })
    ]);

    return { items, total };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const listPublicProviders = async (search, skip, take, orderBy) => {
  try {
    const where = {
      deleted_at: null
    };

    if (search) {
      const searchUpper = String(search).trim().toUpperCase();
      where.OR = [
        { human_friendly_id: buildSearchFilter(searchUpper) },
        { staff_number: buildSearchFilter(search) },
        { practitioner_type: buildSearchFilter(searchUpper) },
        { position: buildSearchFilter(search) },
        {
          user: {
            OR: [
              { human_friendly_id: buildSearchFilter(searchUpper) },
              { email: buildSearchFilter(search) },
              { phone: buildSearchFilter(search) },
              { position_title: buildSearchFilter(search) },
              { profile: { first_name: buildSearchFilter(search) } },
              { profile: { middle_name: buildSearchFilter(search) } },
              { profile: { last_name: buildSearchFilter(search) } }
            ]
          }
        }
      ];
    }

    const [items, total] = await Promise.all([
      prisma.staff_profile.findMany({
        where,
        skip,
        take,
        orderBy,
        select: {
          id: true,
          human_friendly_id: true,
          staff_number: true,
          position: true,
          practitioner_type: true,
          consultation_fee: true,
          consultation_currency: true,
          is_fee_overridden: true,
          user: {
            select: {
              id: true,
              human_friendly_id: true,
              email: true,
              phone: true,
              position_title: true,
              profile: {
                select: {
                  first_name: true,
                  middle_name: true,
                  last_name: true,
                }
              }
            }
          }
        }
      }),
      prisma.staff_profile.count({ where })
    ]);

    return { items, total };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const listPublicBranches = async (search, skip, take, orderBy) => {
  try {
    const where = {
      deleted_at: null,
      is_active: true
    };

    if (search) {
      where.name = buildSearchFilter(search);
    }

    const [items, total] = await Promise.all([
      prisma.branch.findMany({
        where,
        skip,
        take,
        orderBy,
        select: {
          id: true,
          tenant_id: true,
          facility_id: true,
          name: true,
          facility: {
            select: {
              id: true,
              name: true,
              facility_type: true
            }
          }
        }
      }),
      prisma.branch.count({ where })
    ]);

    return { items, total };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listPublicServices,
  listPublicProviders,
  listPublicBranches
};
