/**
 * Notification service
 *
 * @module modules/notification/services
 * @description Business logic layer for notification operations.
 */

const notificationRepository = require('@repositories/notification/notification.repository');
const notificationDeliveryRepository = require('@repositories/notification-delivery/notification-delivery.repository');
const { createAuditLog } = require('@lib/audit');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { HttpError } = require('@lib/errors');
const { emitToUser, NOTIFICATION_EVENTS } = require('@lib/websocket');
const { normalizeRoleName, ROLES } = require('@config/roles');

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const HUB_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'read_at',
  'priority',
  'notification_type',
]);

const ADMIN_NOTIFICATION_ROLES = new Set([
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
]);
const DEFAULT_DELIVERY_CHANNELS = ['IN_APP'];
const DELIVERY_CHANNEL_LIMIT = 5;
const SUPPORTED_DELIVERY_CHANNELS = new Set(['EMAIL', 'IN_APP']);

const normalizeIdentifier = (value) => (typeof value === 'string' ? value.trim() : '');
const isUuid = (value) => UUID_REGEX.test(normalizeIdentifier(value));
const normalizeOrder = (value) => (String(value || '').toLowerCase() === 'asc' ? 'asc' : 'desc');
const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;
const normalizeDeliveryChannels = (channels = []) => {
  const rawChannels = Array.isArray(channels) && channels.length > 0
    ? channels
    : DEFAULT_DELIVERY_CHANNELS;

  return Array.from(
    new Set(
      rawChannels
        .map((entry) => normalizeIdentifier(entry).toUpperCase())
        .filter(Boolean)
    )
  ).slice(0, DELIVERY_CHANNEL_LIMIT);
};

const assertSupportedDeliveryChannels = (channels = []) => {
  channels.forEach((channel) => {
    if (!SUPPORTED_DELIVERY_CHANNELS.has(channel)) {
      throw new HttpError('errors.validation.invalid', 400, [
        {
          field: 'delivery_channels',
          message: 'errors.notification_delivery.channel_not_supported',
        },
      ]);
    }
  });
};

const resolveDeliveryTarget = (notification = {}, channel) => {
  const email = normalizeIdentifier(notification?.user?.email);
  const phone = normalizeIdentifier(notification?.user?.phone);

  if (channel === 'EMAIL') return email || null;
  if (['SMS', 'WHATSAPP', 'CALL'].includes(channel)) return phone || null;
  if (channel === 'IN_APP') return email || phone || null;
  return email || phone || null;
};

const assertDeliveryTargets = (notification = {}, channels = []) => {
  assertSupportedDeliveryChannels(channels);

  channels.forEach((channel) => {
    if (channel === 'IN_APP') return;

    if (!resolveDeliveryTarget(notification, channel)) {
      throw new HttpError('errors.validation.invalid', 400, [
        {
          field: 'delivery_channels',
          message: 'errors.notification_delivery.target_missing',
        },
      ]);
    }
  });
};

const parseDateStart = (value) => {
  const normalized = normalizeIdentifier(value);
  if (!normalized) return null;
  const parsed = new Date(`${normalized}T00:00:00.000Z`);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const parseDateEnd = (value) => {
  const normalized = normalizeIdentifier(value);
  if (!normalized) return null;
  const parsed = new Date(`${normalized}T23:59:59.999Z`);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const resolveActorRoles = (actor = {}) =>
  (Array.isArray(actor.roles) ? actor.roles : actor.role ? [actor.role] : [])
    .map((entry) => normalizeRoleName(entry) || String(entry || '').trim().toUpperCase())
    .filter(Boolean);

const isGlobalAdmin = (actor = {}) => resolveActorRoles(actor).includes(ROLES.SUPER_ADMIN);
const hasAdminNotificationAccess = (actor = {}) =>
  resolveActorRoles(actor).some((role) => ADMIN_NOTIFICATION_ROLES.has(role));

const actorUserId = (actor = {}) => normalizeIdentifier(actor.id || actor.user_id || actor.userId);
const actorTenantId = (actor = {}) =>
  normalizeIdentifier(actor.tenant_id || actor.tenantId || actor.tenant?.id);

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

const buildEmptyListResult = (page, limit) => ({
  notifications: [],
  pagination: buildPagination(page, limit, 0),
});

const resolveHubSortField = (value) => {
  const normalized = normalizeIdentifier(value);
  return HUB_SORT_FIELDS.has(normalized) ? normalized : 'created_at';
};

const includeNotificationRelations = (includeDeliveries = true) => ({
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
  ...(includeDeliveries
    ? {
        deliveries: {
          where: { deleted_at: null },
          select: {
            id: true,
            human_friendly_id: true,
            channel: true,
            status: true,
            recipient_target: true,
            provider_name: true,
            attempt_count: true,
            sent_at: true,
            delivered_at: true,
            failed_at: true,
            retryable: true,
            error_message: true,
            updated_at: true,
          },
          orderBy: [{ updated_at: 'desc' }, { created_at: 'desc' }],
        },
      }
    : {}),
});

const resolveTenantIdentifierForFilter = async (identifier) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return { matched: true, id: null };
  if (isUuid(normalized)) return { matched: true, id: normalized };

  const tenant = await notificationRepository.findTenantByIdentifier(normalized);
  if (!tenant) return { matched: false, id: null };
  return { matched: true, id: tenant.id };
};

const resolveUserIdentifierForFilter = async (identifier, tenantId = null) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return { matched: true, id: null };
  if (isUuid(normalized)) return { matched: true, id: normalized };

  const user = await notificationRepository.findUserByIdentifier(normalized, tenantId);
  if (!user) return { matched: false, id: null };
  return { matched: true, id: user.id };
};

const resolveTemplateIdentifierForPayload = async (identifier, tenantId = null) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  if (isUuid(normalized)) return normalized;

  const template = await notificationRepository.findTemplateByIdentifier(normalized, tenantId);
  if (!template) throw new HttpError('errors.template.not_found', 404, [{ field: 'template_id' }]);
  return template.id;
};

const resolveTenantIdentifierOrThrow = async (identifier) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }
  if (isUuid(normalized)) return normalized;

  const tenant = await notificationRepository.findTenantByIdentifier(normalized);
  if (!tenant) {
    throw new HttpError('errors.tenant.not_found', 404, [{ field: 'tenant_id' }]);
  }
  return tenant.id;
};

const resolveUserIdentifierOrThrow = async (identifier, tenantId = null) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'user_id' }]);
  }
  if (isUuid(normalized)) return normalized;

  const user = await notificationRepository.findUserByIdentifier(normalized, tenantId);
  if (!user) {
    throw new HttpError('errors.user.not_found', 404, [{ field: 'user_id' }]);
  }
  return user.id;
};

const resolveNotificationSortOrder = (sortBy, order) => ({
  [resolveHubSortField(sortBy)]: normalizeOrder(order),
});

const ensureNotificationPublicIds = async (notifications = []) => {
  const missing = (Array.isArray(notifications) ? notifications : [])
    .filter((entry) => !safePublicId(entry?.human_friendly_id))
    .map((entry) => ({
      id: entry.id,
      generated: notificationRepository.createPublicId('NTF'),
    }));

  await Promise.all(
    missing.map((entry) =>
      notificationRepository.assignHumanFriendlyId(entry.id, entry.generated)
    )
  );

  const generatedMap = new Map(missing.map((entry) => [entry.id, entry.generated]));
  notifications.forEach((entry) => {
    if (!entry) return;
    if (!safePublicId(entry.human_friendly_id) && generatedMap.has(entry.id)) {
      entry.human_friendly_id = generatedMap.get(entry.id);
    }
  });
};

const mergeDeliveryFilter = (where = {}, extraFilter = {}) => {
  const existingSome = where?.deliveries?.some || {};
  return {
    ...where,
    deliveries: {
      some: {
        ...existingSome,
        deleted_at: null,
        ...extraFilter,
      },
    },
  };
};

const mapNotificationDelivery = (delivery = {}) => ({
  id: safePublicId(delivery.human_friendly_id),
  channel: delivery.channel || null,
  status: delivery.status || null,
  recipient_target: delivery.recipient_target || null,
  provider_name: delivery.provider_name || null,
  attempt_count: Number(delivery.attempt_count || 0),
  retryable: Boolean(delivery.retryable),
  sent_at: delivery.sent_at || null,
  delivered_at: delivery.delivered_at || null,
  failed_at: delivery.failed_at || null,
  error_message: delivery.error_message || null,
  updated_at: delivery.updated_at || null,
});

const buildDeliverySummary = (deliveries = []) => {
  const rows = Array.isArray(deliveries) ? deliveries : [];
  const summary = {
    total: rows.length,
    delivered: 0,
    failed: 0,
    queued: 0,
    sending: 0,
    sent: 0,
    read: 0,
    retryable: 0,
    last_status: null,
    last_updated_at: null,
    channels: [],
  };

  const channelMap = new Map();
  rows.forEach((delivery, index) => {
    const status = String(delivery?.status || '').toUpperCase();
    if (status === 'DELIVERED') summary.delivered += 1;
    if (status === 'FAILED') summary.failed += 1;
    if (status === 'QUEUED') summary.queued += 1;
    if (status === 'SENDING') summary.sending += 1;
    if (status === 'SENT') summary.sent += 1;
    if (status === 'READ') summary.read += 1;
    if (delivery?.retryable) summary.retryable += 1;

    const channel = String(delivery?.channel || '').toUpperCase() || 'UNKNOWN';
    const key = `${channel}:${status}`;
    const current = channelMap.get(key) || { channel, status, count: 0 };
    current.count += 1;
    channelMap.set(key, current);

    if (index === 0) {
      summary.last_status = status || null;
      summary.last_updated_at = delivery?.updated_at || delivery?.sent_at || null;
    }
  });

  summary.channels = Array.from(channelMap.values());
  return summary;
};

const mapNotificationRecord = (record = {}, { includeDeliveries = true } = {}) => {
  const deliveryRows = includeDeliveries ? record.deliveries || [] : [];
  const unread = !record.read_at;
  return {
    id: safePublicId(record.human_friendly_id),
    human_friendly_id: safePublicId(record.human_friendly_id),
    display_id: safePublicId(record.human_friendly_id),
    tenant_id: safePublicId(record?.tenant?.human_friendly_id, record?.tenant?.slug),
    tenant_label: normalizeIdentifier(record?.tenant?.name) || null,
    user_id: safePublicId(record?.user?.human_friendly_id),
    recipient_label: normalizeIdentifier(record?.user?.email || record?.user?.phone) || null,
    notification_type: record.notification_type || null,
    priority: record.priority || null,
    title: record.title || null,
    message: record.message || null,
    target_path: record.target_path || null,
    context_type: record.context_type || null,
    context_public_id: safePublicId(record.context_public_id),
    read_at: record.read_at || null,
    is_read: !unread,
    unread,
    requires_attention:
      unread && ['HIGH', 'URGENT'].includes(String(record.priority || '').toUpperCase()),
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    delivery_summary: buildDeliverySummary(deliveryRows),
    deliveries: includeDeliveries ? deliveryRows.map(mapNotificationDelivery) : [],
  };
};

const createNotificationDeliveries = async (notification = {}, requestedChannels = []) => {
  const channels = normalizeDeliveryChannels(requestedChannels);
  assertDeliveryTargets(notification, channels);

  await Promise.all(
    channels.map(async (channel) => {
      const now = new Date();
      const recipientTarget = resolveDeliveryTarget(notification, channel);

      await notificationDeliveryRepository.create({
        human_friendly_id: notificationDeliveryRepository.createPublicId('NDL'),
        notification_id: notification.id,
        channel,
        status: channel === 'IN_APP' ? 'DELIVERED' : 'QUEUED',
        recipient_target: recipientTarget,
        provider_name: channel === 'IN_APP' ? 'IN_APP' : null,
        attempt_count: channel === 'IN_APP' ? 1 : 0,
        last_attempt_at: channel === 'IN_APP' ? now : null,
        sent_at: channel === 'IN_APP' ? now : null,
        delivered_at: channel === 'IN_APP' ? now : null,
        retryable: channel !== 'IN_APP',
        error_message: null,
      });
    })
  );
};

const buildScopeWhere = async (filters = {}, actor = {}) => {
  const userId = actorUserId(actor);
  const tenantId = actorTenantId(actor);
  const adminAccess = hasAdminNotificationAccess(actor);
  const globalAdmin = isGlobalAdmin(actor);

  if (!globalAdmin && !tenantId) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }
  if (!adminAccess && !userId) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  const where = {};
  if (!globalAdmin && tenantId) {
    where.tenant_id = tenantId;
  }

  const tenantFilter = await resolveTenantIdentifierForFilter(filters.tenant_id);
  if (!tenantFilter.matched) return null;
  if (tenantFilter.id) {
    if (!globalAdmin && tenantId && tenantFilter.id !== tenantId) return null;
    where.tenant_id = tenantFilter.id;
  }

  const resolvedTenantId = where.tenant_id || tenantId || null;
  const userFilter = await resolveUserIdentifierForFilter(filters.user_id, resolvedTenantId);
  if (!userFilter.matched) return null;

  if (userFilter.id) {
    if (!adminAccess && userFilter.id !== userId) return null;
    where.user_id = userFilter.id;
  } else if (!adminAccess) {
    where.OR = [{ user_id: userId }, { user_id: null }];
  }

  if (filters.notification_type) where.notification_type = filters.notification_type;
  if (filters.priority) where.priority = filters.priority;
  if (filters.is_read === true) where.read_at = { not: null };
  if (filters.is_read === false) where.read_at = null;

  const fromDate = parseDateStart(filters.from_date);
  const toDate = parseDateEnd(filters.to_date);
  if (fromDate || toDate) {
    where.created_at = {};
    if (fromDate) where.created_at.gte = fromDate;
    if (toDate) where.created_at.lte = toDate;
  }

  if (filters.search) {
    const search = normalizeIdentifier(filters.search);
    if (search) {
      const searchUpper = search.toUpperCase();
      where.AND = [
        ...(Array.isArray(where.AND) ? where.AND : []),
        {
          OR: [
            { title: { contains: search } },
            { message: { contains: search } },
            { human_friendly_id: { contains: searchUpper } },
            { context_public_id: { contains: searchUpper } },
          ],
        },
      ];
    }
  }

  if (filters.channel || filters.delivery_status) {
    where.deliveries = {
      some: {
        deleted_at: null,
        ...(filters.channel ? { channel: filters.channel } : {}),
        ...(filters.delivery_status ? { status: filters.delivery_status } : {}),
      },
    };
  }

  return where;
};

const assertReadAccess = (notification, actor = {}) => {
  const userId = actorUserId(actor);
  const tenantId = actorTenantId(actor);
  const adminAccess = hasAdminNotificationAccess(actor);
  const globalAdmin = isGlobalAdmin(actor);

  if (!globalAdmin && tenantId && notification.tenant_id !== tenantId) {
    throw new HttpError('errors.notification.not_found', 404);
  }
  if (!adminAccess && notification.user_id && notification.user_id !== userId) {
    throw new HttpError('errors.notification.not_found', 404);
  }
};

const assertMutationAccess = (notification, actor = {}) => {
  const userId = actorUserId(actor);
  const tenantId = actorTenantId(actor);
  const adminAccess = hasAdminNotificationAccess(actor);
  const globalAdmin = isGlobalAdmin(actor);

  if (!globalAdmin && tenantId && notification.tenant_id !== tenantId) {
    throw new HttpError('errors.notification.not_found', 404);
  }
  if (!adminAccess && notification.user_id !== userId) {
    throw new HttpError('errors.notification.not_found', 404);
  }
};

const findNotificationByIdentifier = async (identifier, includeDeliveries = true) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  const include = includeNotificationRelations(includeDeliveries);
  if (isUuid(normalized)) return notificationRepository.findById(normalized, include);
  return notificationRepository.findByIdentifier(normalized, include);
};

const listNotifications = async (filters, page, limit, sortBy, order, actor) => {
  try {
    const numericPage = Number(page) > 0 ? Number(page) : 1;
    const numericLimit = Number(limit) > 0 ? Number(limit) : 20;
    const where = await buildScopeWhere(filters, actor);
    if (where === null) return buildEmptyListResult(numericPage, numericLimit);

    const skip = (numericPage - 1) * numericLimit;
    const orderBy = resolveNotificationSortOrder(sortBy, order);
    const includeDeliveries = filters?.include_deliveries !== false;

    const [rows, total] = await Promise.all([
      notificationRepository.findMany(
        where,
        skip,
        numericLimit,
        orderBy,
        includeNotificationRelations(includeDeliveries)
      ),
      notificationRepository.count(where),
    ]);

    await ensureNotificationPublicIds(rows);

    return {
      notifications: rows.map((entry) =>
        mapNotificationRecord(entry, { includeDeliveries })
      ),
      pagination: buildPagination(numericPage, numericLimit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getNotificationById = async (id, actor) => {
  try {
    const notification = await findNotificationByIdentifier(id, true);
    if (!notification) throw new HttpError('errors.notification.not_found', 404);
    assertReadAccess(notification, actor);
    await ensureNotificationPublicIds([notification]);
    return mapNotificationRecord(notification, { includeDeliveries: true });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createNotification = async (data, actor = {}, ipAddress) => {
  try {
    const payload = { ...data };
    const adminAccess = hasAdminNotificationAccess(actor);
    const globalAdmin = isGlobalAdmin(actor);
    const actorTenant = actorTenantId(actor);
    const actorId = actorUserId(actor);

    if (!adminAccess && !actorId) {
      throw new HttpError('errors.auth.insufficient_permissions', 403);
    }

    if (globalAdmin) {
      payload.tenant_id = await resolveTenantIdentifierOrThrow(payload.tenant_id);
    } else {
      if (!actorTenant) throw new HttpError('errors.auth.insufficient_permissions', 403);
      payload.tenant_id = actorTenant;
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'user_id')) {
      if (payload.user_id === null) {
        if (!adminAccess) throw new HttpError('errors.auth.insufficient_permissions', 403);
        payload.user_id = null;
      } else if (payload.user_id !== undefined) {
        const resolvedUserId = await resolveUserIdentifierOrThrow(payload.user_id, payload.tenant_id);
        if (!adminAccess && resolvedUserId !== actorId) {
          throw new HttpError('errors.auth.insufficient_permissions', 403);
        }
        payload.user_id = resolvedUserId;
      }
    } else if (!adminAccess) {
      payload.user_id = actorId;
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'template_id')) {
      if (payload.template_id === null) {
        payload.template_id = null;
      } else if (payload.template_id !== undefined) {
        payload.template_id = await resolveTemplateIdentifierForPayload(
          payload.template_id,
          payload.tenant_id
        );
      }
    }

    const requestedChannels = normalizeDeliveryChannels(payload.delivery_channels);
    const requiresDirectRecipient = requestedChannels.some((channel) => channel !== 'IN_APP');
    assertSupportedDeliveryChannels(requestedChannels);
    delete payload.delivery_channels;

    if (!safePublicId(payload.human_friendly_id)) {
      payload.human_friendly_id = notificationRepository.createPublicId('NTF');
    }

    let recipientUser = null;
    if (requiresDirectRecipient) {
      recipientUser = payload.user_id
        ? await notificationRepository.findUserByIdentifier(payload.user_id, payload.tenant_id)
        : null;
      assertDeliveryTargets({ user: recipientUser }, requestedChannels);
    }

    const notification = await notificationRepository.create(payload);
    const createdRecord = await notificationRepository.findById(
      notification.id,
      includeNotificationRelations(true)
    );
    await createNotificationDeliveries(createdRecord || notification, requestedChannels);
    const hydrated = await notificationRepository.findById(
      notification.id,
      includeNotificationRelations(true)
    );
    await ensureNotificationPublicIds([hydrated]);
    const mapped = mapNotificationRecord(hydrated, { includeDeliveries: true });

    createAuditLog({
      tenant_id: payload.tenant_id,
      user_id: actorId || null,
      action: 'CREATE',
      entity: 'notification',
      entity_id: notification.id,
      diff: { after: hydrated },
      ip_address: ipAddress,
    }).catch(() => {});

    if (notification.user_id) {
      emitToUser(notification.user_id, NOTIFICATION_EVENTS.NOTIFICATION_CREATED, {
        notification: mapped,
      });
    }

    return mapped;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateNotification = async (id, data, actor = {}, ipAddress) => {
  try {
    const before = await findNotificationByIdentifier(id, true);
    if (!before) throw new HttpError('errors.notification.not_found', 404);
    assertMutationAccess(before, actor);

    const payload = { ...data };
    const adminAccess = hasAdminNotificationAccess(actor);
    const actorId = actorUserId(actor);

    if (Object.prototype.hasOwnProperty.call(payload, 'tenant_id')) {
      if (!isGlobalAdmin(actor)) throw new HttpError('errors.auth.insufficient_permissions', 403);
      payload.tenant_id = await resolveTenantIdentifierOrThrow(payload.tenant_id);
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'user_id')) {
      if (payload.user_id === null) {
        if (!adminAccess) throw new HttpError('errors.auth.insufficient_permissions', 403);
        payload.user_id = null;
      } else if (payload.user_id !== undefined) {
        const resolvedUserId = await resolveUserIdentifierOrThrow(payload.user_id, before.tenant_id);
        if (!adminAccess && resolvedUserId !== actorId) {
          throw new HttpError('errors.auth.insufficient_permissions', 403);
        }
        payload.user_id = resolvedUserId;
      }
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'template_id')) {
      if (payload.template_id === null) {
        payload.template_id = null;
      } else if (payload.template_id !== undefined) {
        payload.template_id = await resolveTemplateIdentifierForPayload(
          payload.template_id,
          before.tenant_id
        );
      }
    }

    const notification = await notificationRepository.update(before.id, payload);
    const after = await notificationRepository.findById(
      notification.id,
      includeNotificationRelations(true)
    );
    await ensureNotificationPublicIds([after]);
    const mapped = mapNotificationRecord(after, { includeDeliveries: true });

    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: actorId || null,
      action: 'UPDATE',
      entity: 'notification',
      entity_id: before.id,
      diff: { before, after },
      ip_address: ipAddress,
    }).catch(() => {});

    const targetUserId = after?.user_id || before.user_id;
    if (targetUserId) {
      emitToUser(targetUserId, NOTIFICATION_EVENTS.NOTIFICATION_DELIVERY_UPDATED, {
        notification: mapped,
        read_state_updated: true,
      });
    }

    return mapped;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteNotification = async (id, actor = {}, ipAddress) => {
  try {
    const before = await findNotificationByIdentifier(id, true);
    if (!before) throw new HttpError('errors.notification.not_found', 404);
    assertMutationAccess(before, actor);

    await notificationRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: actorUserId(actor) || null,
      action: 'DELETE',
      entity: 'notification',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const setNotificationReadState = async (id, isRead, actor = {}, ipAddress) => {
  const before = await findNotificationByIdentifier(id, true);
  if (!before) throw new HttpError('errors.notification.not_found', 404);
  assertMutationAccess(before, actor);

  const currentRead = Boolean(before.read_at);
  if (currentRead === Boolean(isRead)) {
    await ensureNotificationPublicIds([before]);
    return mapNotificationRecord(before, { includeDeliveries: true });
  }

  const updated = await notificationRepository.update(before.id, {
    read_at: isRead ? new Date() : null,
  });
  const after = await notificationRepository.findById(
    updated.id,
    includeNotificationRelations(true)
  );
  await ensureNotificationPublicIds([after]);
  const mapped = mapNotificationRecord(after, { includeDeliveries: true });

  createAuditLog({
    tenant_id: before.tenant_id,
    user_id: actorUserId(actor) || null,
    action: 'UPDATE',
    entity: 'notification',
    entity_id: before.id,
    diff: { before, after },
    ip_address: ipAddress,
  }).catch(() => {});

  if (after.user_id) {
    emitToUser(after.user_id, NOTIFICATION_EVENTS.NOTIFICATION_DELIVERY_UPDATED, {
      notification: mapped,
      read_state_updated: true,
    });
  }

  return mapped;
};

const bulkUpdateReadState = async (ids = [], isRead = true, actor = {}, ipAddress) => {
  const where = await buildScopeWhere(
    hasAdminNotificationAccess(actor) ? {} : { user_id: actorUserId(actor) },
    actor
  );
  if (where === null) {
    return { processed_count: 0, affected_count: 0, notifications: [] };
  }

  const scopedRecords = await notificationRepository.findManyByIdentifiers(
    ids,
    where,
    includeNotificationRelations(false)
  );
  if (!scopedRecords.length) {
    return { processed_count: 0, affected_count: 0, notifications: [] };
  }

  const targetIds = scopedRecords.map((entry) => entry.id);
  const readWhere = {
    id: { in: targetIds },
    ...(isRead ? { read_at: null } : { read_at: { not: null } }),
  };
  const readUpdate = { read_at: isRead ? new Date() : null };
  const updateResult = await notificationRepository.updateMany(readWhere, readUpdate);

  const afterRows = await notificationRepository.findManyByIdentifiers(
    targetIds,
    where,
    includeNotificationRelations(true)
  );
  await ensureNotificationPublicIds(afterRows);
  const mappedRows = afterRows.map((entry) =>
    mapNotificationRecord(entry, { includeDeliveries: true })
  );

  scopedRecords.forEach((entry) => {
    createAuditLog({
      tenant_id: entry.tenant_id,
      user_id: actorUserId(actor) || null,
      action: 'UPDATE',
      entity: 'notification',
      entity_id: entry.id,
      diff: {
        before: { read_at: entry.read_at },
        after: { read_at: readUpdate.read_at },
      },
      ip_address: ipAddress,
    }).catch(() => {});
  });

  afterRows.forEach((entry) => {
    if (!entry?.user_id) return;
    const mapped = mappedRows.find((row) => row.id === safePublicId(entry.human_friendly_id));
    emitToUser(entry.user_id, NOTIFICATION_EVENTS.NOTIFICATION_DELIVERY_UPDATED, {
      notification: mapped || null,
      read_state_updated: true,
      bulk: true,
    });
  });

  return {
    processed_count: scopedRecords.length,
    affected_count: Number(updateResult?.count || 0),
    notifications: mappedRows,
  };
};

const bulkArchiveNotifications = async (ids = [], actor = {}, ipAddress) => {
  const where = await buildScopeWhere(
    hasAdminNotificationAccess(actor) ? {} : { user_id: actorUserId(actor) },
    actor
  );
  if (where === null) {
    return { processed_count: 0, archived_count: 0 };
  }

  const scopedRecords = await notificationRepository.findManyByIdentifiers(
    ids,
    where,
    includeNotificationRelations(false)
  );
  if (!scopedRecords.length) {
    return { processed_count: 0, archived_count: 0 };
  }

  const targetIds = scopedRecords.map((entry) => entry.id);
  const deletedAt = new Date();
  const archiveResult = await notificationRepository.updateMany(
    { id: { in: targetIds } },
    { deleted_at: deletedAt }
  );

  scopedRecords.forEach((entry) => {
    createAuditLog({
      tenant_id: entry.tenant_id,
      user_id: actorUserId(actor) || null,
      action: 'DELETE',
      entity: 'notification',
      entity_id: entry.id,
      diff: {
        before: entry,
        after: { deleted_at: deletedAt },
      },
      ip_address: ipAddress,
    }).catch(() => {});
  });

  return {
    processed_count: scopedRecords.length,
    archived_count: Number(archiveResult?.count || 0),
  };
};

const getNotificationMetrics = async (filters = {}, actor = {}) => {
  const where = await buildScopeWhere(filters, actor);
  if (where === null) {
    return {
      total: 0,
      unread: 0,
      read: 0,
      attention_required: 0,
      failed_deliveries: 0,
      retryable_deliveries: 0,
      last_received_at: null,
    };
  }

  const [total, unread, attentionRequired, failedDeliveries, retryableDeliveries, lastNotification] =
    await Promise.all([
      notificationRepository.count(where),
      notificationRepository.count({ ...where, read_at: null }),
      notificationRepository.count({
        ...where,
        read_at: null,
        priority: { in: ['HIGH', 'URGENT'] },
      }),
      notificationRepository.count(mergeDeliveryFilter(where, { status: 'FAILED' })),
      notificationRepository.count(
        mergeDeliveryFilter(where, { status: 'FAILED', retryable: true })
      ),
      notificationRepository.findMany(where, 0, 1, { created_at: 'desc' }),
    ]);

  return {
    total,
    unread,
    read: Math.max(0, total - unread),
    attention_required: attentionRequired,
    failed_deliveries: failedDeliveries,
    retryable_deliveries: retryableDeliveries,
    last_received_at: Array.isArray(lastNotification) ? lastNotification[0]?.created_at || null : null,
  };
};

const getNotificationHub = async (filters = {}, page = 1, limit = 20, sortBy, order, actor = {}) => {
  const listResult = await listNotifications(filters, page, limit, sortBy, order, actor);
  const metrics = await getNotificationMetrics(filters, actor);

  return {
    summary: metrics,
    timeline: listResult.notifications,
    pagination: listResult.pagination,
  };
};

module.exports = {
  listNotifications,
  getNotificationById,
  createNotification,
  updateNotification,
  deleteNotification,
  setNotificationReadState,
  bulkUpdateReadState,
  bulkArchiveNotifications,
  getNotificationMetrics,
  getNotificationHub,
};
