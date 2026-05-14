const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const withDbErrorHandling = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    if (error?.code === 'P2025') {
      throw new HttpError('errors.resource.not_found', 404);
    }
    if (error?.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error?.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findManyOrders = async (where, skip, take, orderBy, include) =>
  withDbErrorHandling(() =>
    prisma.radiology_order.findMany({
      where: { deleted_at: null, ...(where || {}) },
      skip,
      take,
      orderBy,
      include,
    })
  );

const countOrders = async (where) =>
  withDbErrorHandling(() =>
    prisma.radiology_order.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const countStudies = async (where) =>
  withDbErrorHandling(() =>
    prisma.imaging_study.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const countResults = async (where) =>
  withDbErrorHandling(() =>
    prisma.radiology_result.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const countAssets = async (where) =>
  withDbErrorHandling(() =>
    prisma.imaging_asset.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const findOrderById = async (id, include) =>
  withDbErrorHandling(() =>
    prisma.radiology_order.findFirst({
      where: { id, deleted_at: null },
      include,
    })
  );

const findReferencePatients = async ({ where = {}, take = 20 } = {}) =>
  withDbErrorHandling(() =>
    prisma.patient.findMany({
      where: { deleted_at: null, ...(where || {}) },
      take,
      orderBy: [{ updated_at: 'desc' }, { created_at: 'desc' }],
      select: {
        id: true,
        human_friendly_id: true,
        first_name: true,
        last_name: true,
        contacts: {
          where: { deleted_at: null },
          select: {
            value: true,
          },
          take: 2,
        },
      },
    })
  );

const findReferenceEncounters = async ({ where = {}, take = 20 } = {}) =>
  withDbErrorHandling(() =>
    prisma.encounter.findMany({
      where: { deleted_at: null, ...(where || {}) },
      take,
      orderBy: [{ started_at: 'desc' }, { created_at: 'desc' }],
      select: {
        id: true,
        human_friendly_id: true,
        status: true,
        started_at: true,
        patient: {
          select: {
            id: true,
            human_friendly_id: true,
            first_name: true,
            last_name: true,
          },
        },
      },
    })
  );

const findReferenceRadiologyTests = async ({ where = {}, take = 20 } = {}) =>
  withDbErrorHandling(() =>
    prisma.radiology_test.findMany({
      where: { deleted_at: null, ...(where || {}) },
      take,
      orderBy: [{ name: 'asc' }, { code: 'asc' }],
      select: {
        id: true,
        human_friendly_id: true,
        name: true,
        code: true,
        modality: true,
      },
    })
  );

const findReferenceUsers = async ({ where = {}, take = 20 } = {}) =>
  withDbErrorHandling(() =>
    prisma.user.findMany({
      where: { deleted_at: null, ...(where || {}) },
      take,
      orderBy: [{ updated_at: 'desc' }, { created_at: 'desc' }],
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
    })
  );

const findStudyById = async (id, include) =>
  withDbErrorHandling(() =>
    prisma.imaging_study.findFirst({
      where: { id, deleted_at: null },
      include,
    })
  );

const findResultById = async (id, include) =>
  withDbErrorHandling(() =>
    prisma.radiology_result.findFirst({
      where: { id, deleted_at: null },
      include,
    })
  );

const withTransaction = async (callback) =>
  withDbErrorHandling(() => prisma.$transaction((tx) => callback(tx)));

const txFindOrderById = async (tx, id, include) =>
  tx.radiology_order.findFirst({
    where: { id, deleted_at: null },
    include,
  });

const txCreateOrder = async (tx, data) =>
  tx.radiology_order.create({
    data,
  });

const txUpdateOrder = async (tx, id, data) =>
  tx.radiology_order.update({
    where: { id },
    data,
  });

const txFindStudyById = async (tx, id, include) =>
  tx.imaging_study.findFirst({
    where: { id, deleted_at: null },
    include,
  });

const txCreateStudy = async (tx, data) =>
  tx.imaging_study.create({
    data,
  });

const txFindFirstStudy = async (tx, where, orderBy = { created_at: 'desc' }, include = undefined) =>
  tx.imaging_study.findFirst({
    where: { deleted_at: null, ...(where || {}) },
    orderBy,
    include,
  });

const txCreateAsset = async (tx, data) =>
  tx.imaging_asset.create({
    data,
  });

const txFindFirstAsset = async (tx, where, orderBy = { created_at: 'desc' }, include = undefined) =>
  tx.imaging_asset.findFirst({
    where: { deleted_at: null, ...(where || {}) },
    orderBy,
    include,
  });

const txFindResultById = async (tx, id, include) =>
  tx.radiology_result.findFirst({
    where: { id, deleted_at: null },
    include,
  });

const txFindFirstResult = async (tx, where, orderBy = { created_at: 'desc' }, include = undefined) =>
  tx.radiology_result.findFirst({
    where: { deleted_at: null, ...(where || {}) },
    orderBy,
    include,
  });

const txCreateResult = async (tx, data) =>
  tx.radiology_result.create({
    data,
  });

const txUpdateResult = async (tx, id, data) =>
  tx.radiology_result.update({
    where: { id },
    data,
  });

const txCreateResultAttestation = async (tx, data) =>
  tx.radiology_result_attestation.create({
    data,
  });

const txFindResultAttestation = async (tx, radiologyResultId, phase) =>
  tx.radiology_result_attestation.findFirst({
    where: {
      deleted_at: null,
      radiology_result_id: radiologyResultId,
      phase,
    },
    orderBy: { created_at: 'desc' },
  });

const txCreatePacsLink = async (tx, data) =>
  tx.pacs_link.create({
    data,
  });

const txCountStudies = async (tx, where) =>
  tx.imaging_study.count({
    where: { deleted_at: null, ...(where || {}) },
  });

module.exports = {
  findManyOrders,
  countOrders,
  countStudies,
  countResults,
  countAssets,
  findOrderById,
  findReferencePatients,
  findReferenceEncounters,
  findReferenceRadiologyTests,
  findReferenceUsers,
  findStudyById,
  findResultById,
  withTransaction,
  txFindOrderById,
  txCreateOrder,
  txUpdateOrder,
  txFindStudyById,
  txCreateStudy,
  txFindFirstStudy,
  txCreateAsset,
  txFindFirstAsset,
  txFindResultById,
  txFindFirstResult,
  txCreateResult,
  txUpdateResult,
  txCreateResultAttestation,
  txFindResultAttestation,
  txCreatePacsLink,
  txCountStudies,
};
