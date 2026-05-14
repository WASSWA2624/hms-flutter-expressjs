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
    prisma.lab_order.findMany({
      where: { deleted_at: null, ...(where || {}) },
      skip,
      take,
      orderBy,
      include,
    })
  );

const countOrders = async (where) =>
  withDbErrorHandling(() =>
    prisma.lab_order.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const countOrderItems = async (where) =>
  withDbErrorHandling(() =>
    prisma.lab_order_item.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const countSamples = async (where) =>
  withDbErrorHandling(() =>
    prisma.lab_sample.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const countResults = async (where) =>
  withDbErrorHandling(() =>
    prisma.lab_result.count({
      where: { deleted_at: null, ...(where || {}) },
    })
  );

const findOrderById = async (id, include) =>
  withDbErrorHandling(() =>
    prisma.lab_order.findFirst({
      where: { id, deleted_at: null },
      include,
    })
  );

const withTransaction = async (callback) =>
  withDbErrorHandling(() => prisma.$transaction((tx) => callback(tx)));

const txFindOrderById = async (tx, id, include) =>
  tx.lab_order.findFirst({
    where: { id, deleted_at: null },
    include,
  });

const txFindSampleById = async (tx, id, include) =>
  tx.lab_sample.findFirst({
    where: { id, deleted_at: null },
    include,
  });

const txFindOrderItemById = async (tx, id, include) =>
  tx.lab_order_item.findFirst({
    where: { id, deleted_at: null },
    include,
  });

const txFindResultById = async (tx, id, include) =>
  tx.lab_result.findFirst({
    where: { id, deleted_at: null },
    include,
  });

const txFindFirstSample = async (tx, where, orderBy = { created_at: 'asc' }) =>
  tx.lab_sample.findFirst({
    where: { deleted_at: null, ...(where || {}) },
    orderBy,
  });

const txCreateSample = async (tx, data) =>
  tx.lab_sample.create({
    data,
  });

const txUpdateSample = async (tx, id, data) =>
  tx.lab_sample.update({
    where: { id },
    data,
  });

const txUpdateOrder = async (tx, id, data) =>
  tx.lab_order.update({
    where: { id },
    data,
  });

const txUpdateOrderItemsMany = async (tx, where, data) =>
  tx.lab_order_item.updateMany({
    where: { deleted_at: null, ...(where || {}) },
    data,
  });

const txUpdateOrderItem = async (tx, id, data) =>
  tx.lab_order_item.update({
    where: { id },
    data,
  });

const txCountOrderItems = async (tx, where) =>
  tx.lab_order_item.count({
    where: { deleted_at: null, ...(where || {}) },
  });

const txCountSamples = async (tx, where) =>
  tx.lab_sample.count({
    where: { deleted_at: null, ...(where || {}) },
  });

const txFindFirstResult = async (tx, where, orderBy = { created_at: 'asc' }, include = undefined) =>
  tx.lab_result.findFirst({
    where: { deleted_at: null, ...(where || {}) },
    orderBy,
    include,
  });

const txCreateResult = async (tx, data) =>
  tx.lab_result.create({
    data,
  });

const txUpdateResult = async (tx, id, data) =>
  tx.lab_result.update({
    where: { id },
    data,
  });

module.exports = {
  findManyOrders,
  countOrders,
  countOrderItems,
  countSamples,
  countResults,
  findOrderById,
  withTransaction,
  txFindOrderById,
  txFindSampleById,
  txFindOrderItemById,
  txFindResultById,
  txFindFirstSample,
  txCreateSample,
  txUpdateSample,
  txUpdateOrder,
  txUpdateOrderItemsMany,
  txUpdateOrderItem,
  txCountOrderItems,
  txCountSamples,
  txFindFirstResult,
  txCreateResult,
  txUpdateResult,
};
