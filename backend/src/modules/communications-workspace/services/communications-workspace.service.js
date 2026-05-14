const path = require('path');
const repository = require('@repositories/communications-workspace/communications-workspace.repository');
const { HttpError } = require('@lib/errors');
const { createAuditLog } = require('@lib/audit');
const { resolvePublicIdentifier, sanitizeIdentifier } = require('@lib/billing/identifiers');
const { emitToUsers, NOTIFICATION_EVENTS } = require('@lib/websocket');
const { createStorageService } = require('@lib/storage');
const { ROLES } = require('@config/roles');
const {
  buildConversationPath,
  personName,
  serializeConversation,
  serializeDelivery,
  serializeMessage,
  serializeNotification,
  serializeTemplate,
} = require('@services/communications-workspace/communications-workspace.serializers');

const DEFAULT_PANEL = 'inbox';
const MAX_ATTACHMENTS = 5;
const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;
const ADMIN_ROLES = new Set([ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN]);
const IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.heic']);
const DOCUMENT_EXTENSIONS = new Set(['.pdf', '.doc', '.docx']);
const IMAGE_TYPES = new Set(['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/heic']);
const DOCUMENT_TYPES = new Set([
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
]);

const text = (value) => String(value || '').trim();
const currentTenantId = (user = {}) => text(user.tenant_id || user.tenantId);
const currentUserId = (user = {}) => text(user.id || user.user_id || user.userId);
const currentRoles = (user = {}) =>
  (Array.isArray(user.roles) ? user.roles : [user.role]).map((entry) => text(entry).toUpperCase()).filter(Boolean);
const isAdminUser = (user = {}) => currentRoles(user).some((entry) => ADMIN_ROLES.has(entry));

const requireTenant = (user = {}) => {
  const tenantId = currentTenantId(user);
  if (!tenantId) throw new HttpError('errors.auth.insufficient_permissions', 403);
  return tenantId;
};

const requireUserId = (user = {}) => {
  const userId = currentUserId(user);
  if (!userId) throw new HttpError('errors.auth.unauthorized', 401);
  return userId;
};

const requireConversationAccess = (conversation, userId) => {
  const participant = (conversation?.participants || []).find(
    (entry) => entry.user_id === userId && entry.deleted_at == null
  );
  if (!participant) throw new HttpError('errors.auth.insufficient_permissions', 403);
  return participant;
};

const requireSensitiveManageAccess = (conversation, user) => {
  if (!conversation?.is_sensitive) return;
  if (text(conversation.created_by_user_id) === requireUserId(user)) return;
  if (isAdminUser(user)) return;
  throw new HttpError('errors.auth.insufficient_permissions', 403);
};

const buildSummary = ({ conversationStats, notifications, deliveries, templates }) => [
  { id: 'unread', label: 'Unread threads', value: Number(conversationStats.unread || 0) },
  { id: 'archived', label: 'Archived threads', value: Number(conversationStats.archived || 0) },
  { id: 'notifications', label: 'Notifications', value: Number(notifications || 0) },
  { id: 'failed_deliveries', label: 'Failed deliveries', value: Number(deliveries || 0) },
  { id: 'templates', label: 'Templates', value: Number(templates || 0) },
];

const validateAttachments = (files = []) => {
  if (!Array.isArray(files)) return [];
  if (files.length > MAX_ATTACHMENTS) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'attachments' }]);
  }
  return files.map((file) => {
    const contentType = text(file?.mimetype).toLowerCase();
    const originalName = text(file?.originalname);
    const extension = path.extname(originalName).toLowerCase();
    const isImage = IMAGE_TYPES.has(contentType) || IMAGE_EXTENSIONS.has(extension);
    const isDocument = DOCUMENT_TYPES.has(contentType) || DOCUMENT_EXTENSIONS.has(extension);
    if (!Buffer.isBuffer(file?.buffer) || (!isImage && !isDocument)) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'attachments' }]);
    }
    const size = Number(file.size || file.buffer.length || 0);
    if (size > MAX_ATTACHMENT_BYTES) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'attachments' }]);
    }
    return {
      attachment_kind: isImage ? 'IMAGE' : 'DOCUMENT',
      content_type: contentType || 'application/octet-stream',
      file_name: originalName || `attachment-${Date.now()}`,
      size_bytes: size,
      buffer: file.buffer,
    };
  });
};

const uploadAttachments = async ({ attachments, tenantId, conversationId, userId }) => {
  const storage = createStorageService();
  const providerName = text(process.env.STORAGE_PROVIDER || 'local');
  const uploads = [];
  for (const attachment of attachments) {
    const upload = await storage.upload(
      attachment.buffer,
      `${tenantId}_${conversationId}_${Date.now()}_${attachment.file_name}`,
      { mimeType: attachment.content_type }
    );
    uploads.push({
      ...attachment,
      public_url: await storage.getUrl(upload.path),
      storage_key: upload.path,
      storage_provider: providerName,
      uploaded_by_user_id: userId,
    });
  }
  return uploads;
};

const getWorkspace = async (filters = {}, page = 1, limit = 30, _sortBy, _order, user = {}) => {
  const tenantId = requireTenant(user);
  const userId = requireUserId(user);
  const panel = text(filters.panel).toLowerCase() || DEFAULT_PANEL;

  const [conversationRows, notificationRows, deliveryRows, templateRows, conversationStats, notificationCount, deliveryCount, templateCount] =
    await Promise.all([
      repository.listConversations({ tenantId, userId, search: filters.search, sensitive: filters.sensitive, filter: filters.filter, page, limit }),
      repository.listNotifications({ tenantId, userId, search: panel === 'notifications' ? filters.search : '', page, limit: 40 }),
      repository.listDeliveries({ tenantId, search: panel === 'deliveries' ? filters.search : '', page, limit: 40 }),
      repository.listTemplates({ tenantId, search: panel === 'templates' ? filters.search : '', page, limit: 40 }),
      repository.findConversationUnreadStats({ tenantId, userId }),
      repository.countNotifications({ tenantId, userId }),
      repository.countDeliveries({ tenantId }),
      repository.countTemplates({ tenantId }),
    ]);

  let conversations = conversationRows.map((entry) => serializeConversation(entry, userId));
  if (filters.unreadOnly) conversations = conversations.filter((entry) => entry.unread);

  let activeConversation = null;
  if (filters.conversationId) {
    const conversation = await repository.getConversation({ tenantId, identifier: filters.conversationId });
    if (conversation) {
      requireConversationAccess(conversation, userId);
      activeConversation = serializeConversation(conversation, userId);
      activeConversation.messages = (conversation.messages || []).map(serializeMessage);
    }
  }

  const deliveries = deliveryRows.map(serializeDelivery);
  const failedDeliveries = deliveries.filter((entry) => entry.status === 'FAILED').length;

  return {
    panels: [
      { id: 'inbox', label_key: 'communications.workbench.panels.inbox', count: conversations.length },
      { id: 'notifications', label_key: 'communications.workbench.panels.notifications', count: notificationRows.length },
      { id: 'deliveries', label_key: 'communications.workbench.panels.deliveries', count: deliveryRows.length },
      { id: 'templates', label_key: 'communications.workbench.panels.templates', count: templateRows.length },
    ],
    summary: buildSummary({
      conversationStats,
      notifications: notificationCount,
      deliveries: failedDeliveries,
      templates: templateCount,
    }),
    queue_summaries: [
      { id: 'UNREAD', label: 'Unread', count: Number(conversationStats.unread || 0), panel: 'inbox', filter: 'UNREAD' },
      { id: 'SENSITIVE', label: 'Sensitive', count: Number(conversationStats.sensitive || 0), panel: 'inbox', filter: 'SENSITIVE' },
      { id: 'ARCHIVED', label: 'Archived', count: Number(conversationStats.archived || 0), panel: 'inbox', filter: 'ARCHIVED' },
      { id: 'FAILED', label: 'Failed deliveries', count: failedDeliveries, panel: 'deliveries', filter: 'FAILED' },
    ],
    filters: {
      panel,
      conversationId: text(filters.conversationId) || null,
      messageId: text(filters.messageId) || null,
      templateId: text(filters.templateId) || null,
      notificationId: text(filters.notificationId) || null,
      action: text(filters.action) || null,
      filter: text(filters.filter) || null,
      search: text(filters.search),
      sensitive: Boolean(filters.sensitive),
      unreadOnly: Boolean(filters.unreadOnly),
    },
    conversations,
    active_conversation: activeConversation,
    notifications: notificationRows.map(serializeNotification),
    deliveries,
    templates: templateRows.map(serializeTemplate),
    pagination: {
      page,
      limit,
      totals: {
        conversations: conversations.length,
        notifications: notificationCount,
        deliveries: deliveryCount,
        templates: templateCount,
      },
    },
  };
};

const getReferenceData = async (query = {}, user = {}) => {
  const tenantId = requireTenant(user);
  const users = await repository.listReferenceUsers({ tenantId, search: query.search });
  return {
    users: users.map((entry) => ({
      id: resolvePublicIdentifier(entry.human_friendly_id, entry.id),
      label: personName(entry),
      email: text(entry.email) || null,
      position_title: text(entry.position_title) || null,
      roles: (entry.roles || []).map((row) => text(row?.role?.name)).filter(Boolean),
    })),
    channels: ['IN_APP', 'EMAIL', 'SMS', 'WHATSAPP'],
    filters: ['UNREAD', 'SENSITIVE', 'ARCHIVED', 'FAILED'],
  };
};

const resolveLegacyRoute = async (resource, identifier, user = {}) => {
  const tenantId = requireTenant(user);
  const resourceKey = text(resource).toLowerCase();
  if (resourceKey === 'conversations') return { panel: 'inbox', conversationId: text(identifier), action: 'view' };
  if (resourceKey === 'messages') {
    const message = await repository.getMessage({ tenantId, identifier });
    if (!message?.conversation) throw new HttpError('errors.message.not_found', 404);
    return {
      panel: 'inbox',
      conversationId: resolvePublicIdentifier(message.conversation.human_friendly_id, message.conversation.id),
      messageId: resolvePublicIdentifier(message.human_friendly_id, message.id),
      action: 'view',
    };
  }
  if (resourceKey === 'notifications') return { panel: 'notifications', notificationId: text(identifier), action: 'view' };
  if (resourceKey === 'notification-deliveries') return { panel: 'deliveries', notificationId: text(identifier), action: 'view' };
  if (resourceKey === 'templates') return { panel: 'templates', templateId: text(identifier), action: 'edit' };
  if (resourceKey === 'template-variables') {
    const variable = await repository.prisma.template_variable.findFirst({
      where: {
        deleted_at: null,
        template: { tenant_id: tenantId, deleted_at: null },
        OR: [{ id: sanitizeIdentifier(identifier) }, { human_friendly_id: sanitizeIdentifier(identifier).toUpperCase() }],
      },
      include: { template: { select: { id: true, human_friendly_id: true } } },
    });
    if (!variable?.template) throw new HttpError('errors.template_variable.not_found', 404);
    return {
      panel: 'templates',
      templateId: resolvePublicIdentifier(variable.template.human_friendly_id, variable.template.id),
      action: 'edit',
    };
  }
  throw new HttpError('errors.not_found', 404);
};

const listConversations = async (filters = {}, page = 1, limit = 30, _sortBy, _order, user = {}) => {
  const userId = requireUserId(user);
  const tenantId = requireTenant(user);
  const rows = await repository.listConversations({ tenantId, userId, search: filters.search, sensitive: filters.sensitive, filter: filters.filter, page, limit });
  return rows.map((entry) => serializeConversation(entry, userId)).filter((entry) => (filters.unreadOnly ? entry.unread : true));
};

const getConversation = async (identifier, user = {}) => {
  const tenantId = requireTenant(user);
  const userId = requireUserId(user);
  const conversation = await repository.getConversation({ tenantId, identifier });
  if (!conversation) throw new HttpError('errors.conversation.not_found', 404);
  requireConversationAccess(conversation, userId);
  const serialized = serializeConversation(conversation, userId);
  serialized.messages = (conversation.messages || []).map(serializeMessage);
  return serialized;
};

const createConversation = async (payload = {}, user = {}) => {
  const tenantId = requireTenant(user);
  const userId = requireUserId(user);
  const resolvedParticipants = await Promise.all(
    (payload.participant_ids || []).map((entry) => repository.resolveUserId(entry, tenantId))
  );
  const participantIds = Array.from(
    new Set([userId, ...resolvedParticipants].filter(Boolean))
  );
  if (participantIds.length < 2) throw new HttpError('errors.validation.invalid', 400, [{ field: 'participant_ids' }]);
  const subject = text(payload.subject) || null;
  const conversationType = text(payload.conversation_type).toUpperCase() || (participantIds.length > 2 || subject ? 'GROUP' : 'DIRECT');
  if (conversationType === 'DIRECT' && participantIds.length !== 2) throw new HttpError('errors.validation.invalid', 400, [{ field: 'participant_ids' }]);
  if (conversationType === 'DIRECT') {
    const existing = await repository.findExistingDirectConversation({ tenantId, participantIds });
    if (existing) return getConversation(resolvePublicIdentifier(existing.human_friendly_id, existing.id), user);
  }

  const created = await repository.prisma.$transaction(async (tx) => {
    const conversation = await tx.conversation.create({
      data: {
        human_friendly_id: repository.createPublicId('COM'),
        tenant_id: tenantId,
        subject,
        created_by_user_id: userId,
        conversation_type: conversationType,
        is_sensitive: Boolean(payload.is_sensitive),
      },
    });
    for (const participantId of participantIds) {
      await tx.conversation_participant.create({
        data: {
          human_friendly_id: repository.createPublicId('CP'),
          conversation_id: conversation.id,
          user_id: participantId,
          role_snapshot: participantId === userId ? currentRoles(user)[0] || null : null,
        },
      });
    }
    for (const roleCode of payload.visibility_roles || []) {
      await tx.conversation_visibility_role.create({
        data: {
          human_friendly_id: repository.createPublicId('CVR'),
          tenant_id: tenantId,
          conversation_id: conversation.id,
          role_code: text(roleCode).toUpperCase(),
        },
      });
    }
    return conversation;
  });

  await createAuditLog({ tenant_id: tenantId, user_id: userId, action: 'CREATE', entity: 'communications_workspace_conversation', entity_id: created.id, diff: { after: { participant_count: participantIds.length } } });
  return getConversation(resolvePublicIdentifier(created.human_friendly_id, created.id), user);
};

const markConversationRead = async (identifier, user = {}) => {
  const tenantId = requireTenant(user);
  const userId = requireUserId(user);
  const conversation = await repository.getConversation({ tenantId, identifier });
  if (!conversation) throw new HttpError('errors.conversation.not_found', 404);
  const participant = requireConversationAccess(conversation, userId);
  const latestMessage = (conversation.messages || [])[conversation.messages.length - 1] || null;
  await repository.prisma.$transaction(async (tx) => {
    await tx.conversation_participant.update({
      where: { id: participant.id },
      data: { last_read_message_id: latestMessage?.id || null, last_read_at: latestMessage ? new Date() : participant.last_read_at || null },
    });
    await tx.notification.updateMany({
      where: {
        tenant_id: tenantId,
        user_id: userId,
        deleted_at: null,
        context_type: 'conversation',
        context_public_id: resolvePublicIdentifier(conversation.human_friendly_id, conversation.id),
        read_at: null,
      },
      data: { read_at: new Date() },
    });
  });
  emitToUsers([userId], NOTIFICATION_EVENTS.CONVERSATION_READ_STATE_UPDATED, { conversation_id: resolvePublicIdentifier(conversation.human_friendly_id, conversation.id) });
  return getConversation(resolvePublicIdentifier(conversation.human_friendly_id, conversation.id), user);
};

const archiveConversation = async (identifier, user = {}, archived = true) => {
  const tenantId = requireTenant(user);
  const userId = requireUserId(user);
  const conversation = await repository.getConversation({ tenantId, identifier });
  if (!conversation) throw new HttpError('errors.conversation.not_found', 404);
  const participant = requireConversationAccess(conversation, userId);
  await repository.prisma.conversation_participant.update({ where: { id: participant.id }, data: { archived_at: archived ? new Date() : null } });
  return getConversation(resolvePublicIdentifier(conversation.human_friendly_id, conversation.id), user);
};

const addConversationParticipant = async (identifier, payload = {}, user = {}) => {
  const tenantId = requireTenant(user);
  const userId = requireUserId(user);
  const conversation = await repository.getConversation({ tenantId, identifier });
  if (!conversation) throw new HttpError('errors.conversation.not_found', 404);
  requireConversationAccess(conversation, userId);
  requireSensitiveManageAccess(conversation, user);
  const targetUserId = await repository.resolveUserId(payload.user_id, tenantId);
  if (!targetUserId) throw new HttpError('errors.user.not_found', 404);
  const exists = (conversation.participants || []).some((entry) => entry.user_id === targetUserId && entry.deleted_at == null);
  if (!exists) {
    await repository.prisma.conversation_participant.create({
      data: {
        human_friendly_id: repository.createPublicId('CP'),
        conversation_id: conversation.id,
        user_id: targetUserId,
        role_snapshot: text(payload.role_snapshot) || null,
      },
    });
  }
  return getConversation(resolvePublicIdentifier(conversation.human_friendly_id, conversation.id), user);
};

const removeConversationParticipant = async (conversationIdentifier, participantIdentifier, user = {}) => {
  const tenantId = requireTenant(user);
  const userId = requireUserId(user);
  const conversation = await repository.getConversation({ tenantId, identifier: conversationIdentifier });
  if (!conversation) throw new HttpError('errors.conversation.not_found', 404);
  requireConversationAccess(conversation, userId);
  requireSensitiveManageAccess(conversation, user);
  const participant = await repository.resolveParticipantRecord(participantIdentifier, conversation.id);
  if (!participant) throw new HttpError('errors.not_found', 404);
  await repository.prisma.conversation_participant.update({ where: { id: participant.id }, data: { deleted_at: new Date() } });
  return getConversation(resolvePublicIdentifier(conversation.human_friendly_id, conversation.id), user);
};

const listConversationMessages = async (identifier, filters = {}, page = 1, limit = 100, _sortBy, _order, user = {}) => {
  const tenantId = requireTenant(user);
  const userId = requireUserId(user);
  const conversation = await repository.getConversation({ tenantId, identifier });
  if (!conversation) throw new HttpError('errors.conversation.not_found', 404);
  requireConversationAccess(conversation, userId);
  const rows = await repository.listMessages({ tenantId, conversationId: conversation.id, search: filters.search, page, limit });
  return rows.map(serializeMessage);
};

const createConversationMessage = async (identifier, payload = {}, files = [], user = {}) => {
  const tenantId = requireTenant(user);
  const userId = requireUserId(user);
  const conversation = await repository.getConversation({ tenantId, identifier });
  if (!conversation) throw new HttpError('errors.conversation.not_found', 404);
  requireConversationAccess(conversation, userId);

  const content = text(payload.content);
  const attachments = validateAttachments(files);
  if (!content && attachments.length === 0) throw new HttpError('errors.validation.invalid', 400, [{ field: 'content' }]);

  let replyTo = null;
  if (payload.reply_to_message_id) {
    replyTo = await repository.getMessage({ tenantId, identifier: payload.reply_to_message_id });
    if (!replyTo || replyTo.conversation?.id !== conversation.id) throw new HttpError('errors.validation.invalid', 400, [{ field: 'reply_to_message_id' }]);
  }

  const publicConversationId = resolvePublicIdentifier(conversation.human_friendly_id, conversation.id);
  const uploaded = await uploadAttachments({ attachments, tenantId, conversationId: publicConversationId, userId });
  const senderParticipant = (conversation.participants || []).find((entry) => entry.user_id === userId);
  const recipientParticipants = (conversation.participants || []).filter((entry) => entry.user_id !== userId);

  const message = await repository.prisma.$transaction(async (tx) => {
    const createdMessage = await tx.message.create({
      data: {
        human_friendly_id: repository.createPublicId('MSG'),
        conversation_id: conversation.id,
        sender_user_id: userId,
        reply_to_message_id: replyTo?.id || null,
        content: content || ' ',
        message_type: 'TEXT',
      },
    });

    for (const attachment of uploaded) {
      await tx.message_attachment.create({
        data: {
          human_friendly_id: repository.createPublicId('ATT'),
          message_id: createdMessage.id,
          tenant_id: tenantId,
          uploaded_by_user_id: userId,
          storage_key: attachment.storage_key,
          storage_provider: attachment.storage_provider,
          file_name: attachment.file_name,
          content_type: attachment.content_type,
          size_bytes: attachment.size_bytes,
          attachment_kind: attachment.attachment_kind,
          public_url: attachment.public_url,
        },
      });
    }

    await tx.conversation.update({ where: { id: conversation.id }, data: { last_message_at: new Date(), status: 'OPEN', archived_at: null } });
    if (senderParticipant) {
      await tx.conversation_participant.update({
        where: { id: senderParticipant.id },
        data: { last_read_message_id: createdMessage.id, last_read_at: new Date(), archived_at: null },
      });
    }
    for (const participant of recipientParticipants) {
      const notification = await tx.notification.create({
        data: {
          human_friendly_id: repository.createPublicId('NTF'),
          tenant_id: tenantId,
          user_id: participant.user_id,
          notification_type: 'SYSTEM',
          priority: conversation.is_sensitive ? 'HIGH' : 'MEDIUM',
          title: text(conversation.subject) || personName(participant.user),
          message: content || 'Sent an attachment',
          target_path: buildConversationPath(publicConversationId),
          context_type: 'conversation',
          context_public_id: publicConversationId,
        },
      });
      await tx.notification_delivery.create({
        data: {
          human_friendly_id: repository.createPublicId('NDL'),
          notification_id: notification.id,
          channel: 'IN_APP',
          status: 'DELIVERED',
          recipient_target: participant.user?.email || participant.user_id,
          provider_name: 'IN_APP',
          attempt_count: 1,
          last_attempt_at: new Date(),
          sent_at: new Date(),
          delivered_at: new Date(),
        },
      });
    }
    return createdMessage;
  });

  const freshConversation = await repository.getConversation({ tenantId, identifier: publicConversationId });
  const serializedConversation = serializeConversation(freshConversation, userId);
  const recipientUserIds = (freshConversation?.participants || []).map((entry) => entry.user_id).filter(Boolean);

  emitToUsers(recipientUserIds, NOTIFICATION_EVENTS.CONVERSATION_THREAD_UPDATED, { conversation: serializedConversation });
  emitToUsers(recipientUserIds, NOTIFICATION_EVENTS.CONVERSATION_MESSAGE_CREATED, { conversation_id: serializedConversation.id });
  await createAuditLog({ tenant_id: tenantId, user_id: userId, action: 'CREATE', entity: 'communications_workspace_message', entity_id: message.id, diff: { after: { attachment_count: uploaded.length } } });
  return getConversation(publicConversationId, user);
};

module.exports = {
  getWorkspace,
  getReferenceData,
  resolveLegacyRoute,
  listConversations,
  getConversation,
  createConversation,
  markConversationRead,
  archiveConversation,
  addConversationParticipant,
  removeConversationParticipant,
  listConversationMessages,
  createConversationMessage,
};
