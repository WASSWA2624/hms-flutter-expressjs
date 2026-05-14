/**
 * Notification delivery service
 *
 * @module modules/notification-delivery/services
 * @description Business logic layer for notification-delivery operations.
 */

const notificationDeliveryRepository = require('@repositories/notification-delivery/notification-delivery.repository');
const { createAuditLog } = require('@lib/audit');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { HttpError } = require('@lib/errors');
const { emitToUser, NOTIFICATION_EVENTS } = require('@lib/websocket');
const { normalizeRoleName, ROLES } = require('@config/roles');

const DELIVERY_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'sent_at',
  'delivered_at',
  'status',
  'channel',
]);

const ADMIN_NOTIFICATION_ROLES = new Set([
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
]);

const normalizeIdentifier = (value) => (typeof value === 'string' ? value.trim() : '');
const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;
const normalizeOrder = (value) => (String(value || '').toLowerCase() === 'asc' ? 'asc' : 'desc');
const normalizeSortField = (value) => {
  const normalized = normalizeIdentifier(value);
  return DELIVERY_SORT_FIELDS.has(normalized) ? normalized : 'created_at';
};

const actorUserId = (actor = {}) => normalizeIdentifier(actor.id || actor.user_id || actor.userId);
const actorTenantId = (actor = {}) =>
  normalizeIdentifier(actor.tenant_id || actor.tenantId || actor.tenant?.id);
const actorRoles = (actor = {}) =>
  (Array.isArray(actor.roles) ? actor.roles : actor.role ? [actor.role] : [])
    .map((entry) => normalizeRoleName(entry) || String(entry || '').trim().toUpperCase())
    .filter(Boolean);
const isGlobalAdmin = (actor = {}) => actorRoles(actor).includes(ROLES.SUPER_ADMIN);
const hasAdminNotificationAccess = (actor = {}) =>
  actorRoles(actor).some((entry) => ADMIN_NOTIFICATION_ROLES.has(entry));

const includeDeliveryRelations = {
  notification: {
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
      user_id: true,
      title: true,
      target_path: true,
      tenant: {
        select: {
          id: true,
          human_friendly_id: true,
          slug: true,
          name: true,
        },
      },
      user: {
        select: {
          id: true,
          human_friendly_id: true,
          email: true,
          phone: true,
        },
      },
    },
  },
};

const buildPagination = (page, limit, total) => {
  const totalPages = Math.ceil(total / limit);
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

const mapDeliveryRecord = (record = {}) => ({
  id: safePublicId(record.human_friendly_id),
  human_friendly_id: safePublicId(record.human_friendly_id),
  display_id: safePublicId(record.human_friendly_id),
  notification_id: safePublicId(record?.notification?.human_friendly_id),
  tenant_id: safePublicId(
    record?.notification?.tenant?.human_friendly_id,
    record?.notification?.tenant?.slug
  ),
  tenant_label: normalizeIdentifier(record?.notification?.tenant?.name) || null,
  notification_title: record?.notification?.title || null,
  target_path: record?.notification?.target_path || null,
  recipient_user_id: safePublicId(record?.notification?.user?.human_friendly_id),
  recipient_label:
    normalizeIdentifier(
      record?.notification?.user?.email || record?.notification?.user?.phone
    ) || null,
  channel: record.channel || null,
  status: record.status || null,
  recipient_target: record.recipient_target || null,
  provider_name: record.provider_name || null,
  attempt_count: Number(record.attempt_count || 0),
  last_attempt_at: record.last_attempt_at || null,
  sent_at: record.sent_at || null,
  delivered_at: record.delivered_at || null,
  failed_at: record.failed_at || null,
  retryable: Boolean(record.retryable),
  error_message: record.error_message || null,
  created_at: record.created_at || null,
  updated_at: record.updated_at || null,
});

const ensureDeliveryPublicIds = async (rows = []) => {
  const missing = (Array.isArray(rows) ? rows : [])
    .filter((entry) => !safePublicId(entry?.human_friendly_id))
    .map((entry) => ({
      id: entry.id,
      generated: notificationDeliveryRepository.createPublicId('NDL'),
    }));

  await Promise.all(
    missing.map((entry) =>
      notificationDeliveryRepository.assignHumanFriendlyId(entry.id, entry.generated)
    )
  );

  const generatedMap = new Map(missing.map((entry) => [entry.id, entry.generated]));
  rows.forEach((entry) => {
    if (!entry) return;
    if (!safePublicId(entry.human_friendly_id) && generatedMap.has(entry.id)) {
      entry.human_friendly_id = generatedMap.get(entry.id);
    }
  });
};

const assertDeliveryAccess = (delivery, actor = {}) => {
  const tenantId = actorTenantId(actor);
  const userId = actorUserId(actor);
  const adminAccess = hasAdminNotificationAccess(actor);
  const globalAdmin = isGlobalAdmin(actor);
  const deliveryTenantId = normalizeIdentifier(delivery?.notification?.tenant_id);
  const deliveryUserId = normalizeIdentifier(delivery?.notification?.user_id);

  if (!globalAdmin && tenantId && tenantId !== deliveryTenantId) {
    throw new HttpError('errors.notification_delivery.not_found', 404);
  }
  if (!adminAccess && deliveryUserId && userId !== deliveryUserId) {
    throw new HttpError('errors.notification_delivery.not_found', 404);
  }
};

const resolveDeliveryWhere = async (filters = {}, actor = {}) => {
  const where = {};
  const tenantId = actorTenantId(actor);
  const userId = actorUserId(actor);
  const adminAccess = hasAdminNotificationAccess(actor);
  const globalAdmin = isGlobalAdmin(actor);

  if (!globalAdmin && !tenantId) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  const notificationWhere = {
    deleted_at: null,
    ...(globalAdmin ? {} : { tenant_id: tenantId }),
    ...(adminAccess ? {} : { user_id: userId }),
  };

  if (filters.notification_id) {
    const notification = await notificationDeliveryRepository.findNotificationByIdentifier(
      filters.notification_id
    );
    if (!notification) return null;
    if (!globalAdmin && tenantId && notification.tenant_id !== tenantId) return null;
    if (!adminAccess && notification.user_id !== userId) return null;
    where.notification_id = notification.id;
  }

  if (filters.channel) where.channel = filters.channel;
  if (filters.status) where.status = filters.status;
  if (typeof filters.retryable === 'boolean') where.retryable = filters.retryable;

  const search = normalizeIdentifier(filters.search);
  if (search) {
    const searchUpper = search.toUpperCase();
    where.OR = [
      { human_friendly_id: { contains: searchUpper } },
      { recipient_target: { contains: search } },
      { provider_name: { contains: search } },
      {
        notification: {
          OR: [
            { title: { contains: search } },
            { message: { contains: search } },
            { human_friendly_id: { contains: searchUpper } },
          ],
        },
      },
    ];
  }

  where.notification = notificationWhere;
  return where;
};

const findDeliveryRecord = async (identifier) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  return notificationDeliveryRepository.findByIdentifier(normalized, includeDeliveryRelations);
};

const listNotificationDeliveries = async (filters, page, limit, sortBy, order, actor) => {
  try {
    const numericPage = Number(page) > 0 ? Number(page) : 1;
    const numericLimit = Number(limit) > 0 ? Number(limit) : 20;
    const where = await resolveDeliveryWhere(filters, actor);
    if (where === null) {
      return {
        notificationDeliveries: [],
        pagination: buildPagination(numericPage, numericLimit, 0),
      };
    }

    const skip = (numericPage - 1) * numericLimit;
    const orderBy = { [normalizeSortField(sortBy)]: normalizeOrder(order) };

    const [rows, total] = await Promise.all([
      notificationDeliveryRepository.findMany(
        where,
        skip,
        numericLimit,
        orderBy,
        includeDeliveryRelations
      ),
      notificationDeliveryRepository.count(where),
    ]);

    await ensureDeliveryPublicIds(rows);
    return {
      notificationDeliveries: rows.map(mapDeliveryRecord),
      pagination: buildPagination(numericPage, numericLimit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getNotificationDeliveryById = async (id, actor) => {
  try {
    const delivery = await findDeliveryRecord(id);
    if (!delivery) {
      throw new HttpError('errors.notification_delivery.not_found', 404);
    }
    assertDeliveryAccess(delivery, actor);
    await ensureDeliveryPublicIds([delivery]);
    return mapDeliveryRecord(delivery);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createNotificationDelivery = async (data, actor = {}, ipAddress) => {
  try {
    const payload = { ...data };
    const actorId = actorUserId(actor);
    const notification = await notificationDeliveryRepository.findNotificationByIdentifier(
      payload.notification_id
    );
    if (!notification) {
      throw new HttpError('errors.notification.not_found', 404, [{ field: 'notification_id' }]);
    }

    const tenantId = actorTenantId(actor);
    const globalAdmin = isGlobalAdmin(actor);
    const adminAccess = hasAdminNotificationAccess(actor);

    if (!globalAdmin && tenantId && notification.tenant_id !== tenantId) {
      throw new HttpError('errors.auth.insufficient_permissions', 403);
    }
    if (!adminAccess && notification.user_id !== actorId) {
      throw new HttpError('errors.auth.insufficient_permissions', 403);
    }

    payload.notification_id = notification.id;
    if (!safePublicId(payload.human_friendly_id)) {
      payload.human_friendly_id = notificationDeliveryRepository.createPublicId('NDL');
    }

    const created = await notificationDeliveryRepository.create(payload);
    const hydrated = await notificationDeliveryRepository.findById(
      created.id,
      includeDeliveryRelations
    );
    await ensureDeliveryPublicIds([hydrated]);
    const mapped = mapDeliveryRecord(hydrated);

    createAuditLog({
      tenant_id: notification.tenant_id,
      user_id: actorId || null,
      action: 'CREATE',
      entity: 'notification_delivery',
      entity_id: created.id,
      diff: { after: hydrated },
      ip_address: ipAddress,
    }).catch(() => {});

    if (notification.user_id) {
      emitToUser(notification.user_id, NOTIFICATION_EVENTS.NOTIFICATION_DELIVERY_UPDATED, {
        delivery: mapped,
      });
    }

    return mapped;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateNotificationDelivery = async (id, data, actor = {}, ipAddress) => {
  try {
    const before = await findDeliveryRecord(id);
    if (!before) {
      throw new HttpError('errors.notification_delivery.not_found', 404);
    }
    assertDeliveryAccess(before, actor);

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'notification_id')) {
      const notification = await notificationDeliveryRepository.findNotificationByIdentifier(
        payload.notification_id
      );
      if (!notification) {
        throw new HttpError('errors.notification.not_found', 404, [{ field: 'notification_id' }]);
      }
      payload.notification_id = notification.id;
    }

    const updated = await notificationDeliveryRepository.update(before.id, payload);
    const after = await notificationDeliveryRepository.findById(
      updated.id,
      includeDeliveryRelations
    );
    await ensureDeliveryPublicIds([after]);
    const mapped = mapDeliveryRecord(after);

    createAuditLog({
      tenant_id: before.notification.tenant_id,
      user_id: actorUserId(actor) || null,
      action: 'UPDATE',
      entity: 'notification_delivery',
      entity_id: before.id,
      diff: { before, after },
      ip_address: ipAddress,
    }).catch(() => {});

    if (after?.notification?.user_id) {
      emitToUser(after.notification.user_id, NOTIFICATION_EVENTS.NOTIFICATION_DELIVERY_UPDATED, {
        delivery: mapped,
      });
    }

    return mapped;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteNotificationDelivery = async (id, actor = {}, ipAddress) => {
  try {
    const before = await findDeliveryRecord(id);
    if (!before) {
      throw new HttpError('errors.notification_delivery.not_found', 404);
    }
    assertDeliveryAccess(before, actor);

    await notificationDeliveryRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: before.notification.tenant_id,
      user_id: actorUserId(actor) || null,
      action: 'DELETE',
      entity: 'notification_delivery',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listNotificationDeliveries,
  getNotificationDeliveryById,
  createNotificationDelivery,
  updateNotificationDelivery,
  deleteNotificationDelivery,
};
