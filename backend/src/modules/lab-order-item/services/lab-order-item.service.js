const labOrderItemRepository = require('@repositories/lab-order-item/lab-order-item.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  LAB_ORDER_ITEM_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/lab-workspace/lab.shared');
const { mapLabOrderItemRecord } = require('@services/lab-workspace/lab.serializer');

const listLabOrderItems = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};

    if (filters.lab_order_id) {
      whereClause.lab_order_id = await resolveModelIdOrThrow({
        identifier: filters.lab_order_id,
        model: 'lab_order',
        where: { deleted_at: null },
        errorKey: 'errors.lab_order.not_found',
      });
    }

    if (filters.lab_test_id) {
      whereClause.lab_test_id = await resolveModelIdOrThrow({
        identifier: filters.lab_test_id,
        model: 'lab_test',
        where: { deleted_at: null },
        errorKey: 'errors.lab_test.not_found',
      });
    }

    if (filters.status) whereClause.status = filters.status;

    const searchTerm = normalizeSearchTerm(filters.search);
    if (searchTerm) {
      whereClause.OR = [
        { human_friendly_id: { contains: searchTerm.upper } },
        { lab_order: { human_friendly_id: { contains: searchTerm.upper } } },
        { lab_order: { patient: { human_friendly_id: { contains: searchTerm.upper } } } },
        { lab_order: { patient: { first_name: { contains: searchTerm.raw } } } },
        { lab_order: { patient: { last_name: { contains: searchTerm.raw } } } },
        { lab_test: { human_friendly_id: { contains: searchTerm.upper } } },
        { lab_test: { name: { contains: searchTerm.raw } } },
        { lab_test: { code: { contains: searchTerm.raw } } },
      ];
    }

    const [labOrderItems, total] = await Promise.all([
      labOrderItemRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        LAB_ORDER_ITEM_WITH_RELATIONS_INCLUDE
      ),
      labOrderItemRepository.count(whereClause),
    ]);

    return {
      labOrderItems: labOrderItems.map((record) => mapLabOrderItemRecord(record)).filter(Boolean),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getLabOrderItemById = async (id, userId, ipAddress) => {
  try {
    const labOrderItem = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_order_item',
      where: { deleted_at: null },
      include: LAB_ORDER_ITEM_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_order_item.not_found',
    });

    return mapLabOrderItemRecord(labOrderItem);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createLabOrderItem = async (data, userId, ipAddress) => {
  try {
    const payload = { ...data };
    payload.lab_order_id = await resolveModelIdOrThrow({
      identifier: payload.lab_order_id,
      model: 'lab_order',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order.not_found',
    });
    payload.lab_test_id = await resolveModelIdOrThrow({
      identifier: payload.lab_test_id,
      model: 'lab_test',
      where: { deleted_at: null },
      errorKey: 'errors.lab_test.not_found',
    });

    const labOrderItem = await labOrderItemRepository.create(payload);
    const createdItem = await labOrderItemRepository.findById(
      labOrderItem.id,
      LAB_ORDER_ITEM_WITH_RELATIONS_INCLUDE
    );

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'lab_order_item',
      entity_id: labOrderItem.id,
      diff: { after: createdItem || labOrderItem },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabOrderItemRecord(createdItem || labOrderItem);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateLabOrderItem = async (id, data, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_order_item',
      where: { deleted_at: null },
      include: LAB_ORDER_ITEM_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_order_item.not_found',
    });

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'lab_order_id') && payload.lab_order_id) {
      payload.lab_order_id = await resolveModelIdOrThrow({
        identifier: payload.lab_order_id,
        model: 'lab_order',
        where: { deleted_at: null },
        errorKey: 'errors.lab_order.not_found',
      });
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'lab_test_id') && payload.lab_test_id) {
      payload.lab_test_id = await resolveModelIdOrThrow({
        identifier: payload.lab_test_id,
        model: 'lab_test',
        where: { deleted_at: null },
        errorKey: 'errors.lab_test.not_found',
      });
    }

    const updated = await labOrderItemRepository.update(before.id, payload);
    const labOrderItem = await labOrderItemRepository.findById(
      updated.id,
      LAB_ORDER_ITEM_WITH_RELATIONS_INCLUDE
    );

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'lab_order_item',
      entity_id: updated.id,
      diff: { before, after: labOrderItem },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabOrderItemRecord(labOrderItem || updated);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteLabOrderItem = async (id, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_order_item',
      where: { deleted_at: null },
      include: LAB_ORDER_ITEM_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_order_item.not_found',
    });

    const labOrderItem = await labOrderItemRepository.softDelete(before.id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'lab_order_item',
      entity_id: labOrderItem.id,
      diff: { before, after: labOrderItem },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabOrderItemRecord(before);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listLabOrderItems,
  getLabOrderItemById,
  createLabOrderItem,
  updateLabOrderItem,
  deleteLabOrderItem
};
