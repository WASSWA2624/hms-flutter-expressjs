const { resolvePublicIdentifier } = require('@lib/billing/identifiers');

const text = (value) => String(value || '').trim();

const buildConversationPath = (conversationIdentifier) =>
  `/communications?panel=inbox&conversationId=${encodeURIComponent(conversationIdentifier)}`;

const personName = (record = {}) => {
  const first = text(record?.profile?.first_name);
  const last = text(record?.profile?.last_name);
  const combined = [first, last].filter(Boolean).join(' ');
  return combined || text(record.email) || resolvePublicIdentifier(record.human_friendly_id, record.id) || 'Staff';
};

const serializeUser = (record = {}) => {
  const name = personName(record);
  return {
    id: resolvePublicIdentifier(record.human_friendly_id, record.id),
    name,
    email: text(record.email) || null,
    position_title: text(record.position_title) || null,
    initials: name
      .split(' ')
      .filter(Boolean)
      .slice(0, 2)
      .map((entry) => entry[0]?.toUpperCase() || '')
      .join(''),
  };
};

const serializeAttachment = (record = {}) => ({
  id: resolvePublicIdentifier(record.human_friendly_id, record.id),
  file_name: text(record.file_name),
  content_type: text(record.content_type),
  size_bytes: Number(record.size_bytes || 0),
  attachment_kind: text(record.attachment_kind).toUpperCase() || 'DOCUMENT',
  public_url: text(record.public_url) || null,
  created_at: record.created_at || null,
});

const serializeMessage = (record = {}) => ({
  id: resolvePublicIdentifier(record.human_friendly_id, record.id),
  conversation_id: resolvePublicIdentifier(record.conversation?.human_friendly_id, record.conversation_id),
  sender_user_id: resolvePublicIdentifier(record.sender_user?.human_friendly_id, record.sender_user_id),
  sender: record.sender_user ? serializeUser(record.sender_user) : null,
  content: text(record.content),
  message_type: text(record.message_type).toUpperCase() || 'TEXT',
  sent_at: record.sent_at || null,
  edited_at: record.edited_at || null,
  reply_to_message_id: resolvePublicIdentifier(record.reply_to_message?.human_friendly_id, record.reply_to_message_id),
  reply_to_message: record.reply_to_message
    ? {
        id: resolvePublicIdentifier(record.reply_to_message.human_friendly_id, record.reply_to_message.id),
        content: text(record.reply_to_message.content),
        sender: record.reply_to_message.sender_user ? serializeUser(record.reply_to_message.sender_user) : null,
      }
    : null,
  attachments: (record.attachments || []).map(serializeAttachment),
});

const conversationTitle = (record = {}, viewerUserId) => {
  if (text(record.subject)) return text(record.subject);
  const names = (record.participants || [])
    .filter((entry) => entry.user_id !== viewerUserId)
    .map((entry) => personName(entry.user))
    .filter(Boolean);
  if (names.length === 1) return names[0];
  if (names.length > 1) return names.join(', ');
  return resolvePublicIdentifier(record.human_friendly_id, record.id) || 'Conversation';
};

const isUnreadConversation = (record = {}, viewerUserId) => {
  const viewerParticipant = (record.participants || []).find((entry) => entry.user_id === viewerUserId);
  const lastMessageRecord = Array.isArray(record.messages)
    ? record.messages[record.messages.length - 1] || record.messages[0]
    : null;
  const lastMessageAt = record.last_message_at
    ? new Date(record.last_message_at).getTime()
    : lastMessageRecord?.sent_at
      ? new Date(lastMessageRecord.sent_at).getTime()
      : 0;
  const lastReadAt = viewerParticipant?.last_read_at
    ? new Date(viewerParticipant.last_read_at).getTime()
    : 0;
  return lastMessageAt > lastReadAt;
};

const serializeConversation = (record = {}, viewerUserId) => {
  const lastMessageRecord = Array.isArray(record.messages)
    ? record.messages[record.messages.length - 1] || record.messages[0]
    : null;
  const lastMessage = lastMessageRecord ? serializeMessage(lastMessageRecord) : null;
  const viewerParticipant = (record.participants || []).find((entry) => entry.user_id === viewerUserId);
  const id = resolvePublicIdentifier(record.human_friendly_id, record.id);

  return {
    id,
    subject: text(record.subject) || null,
    title: conversationTitle(record, viewerUserId),
    conversation_type: text(record.conversation_type).toUpperCase() || 'DIRECT',
    status: text(record.status).toUpperCase() || 'OPEN',
    is_sensitive: Boolean(record.is_sensitive),
    archived: Boolean(viewerParticipant?.archived_at || record.archived_at),
    unread: isUnreadConversation(record, viewerUserId),
    last_message_at: record.last_message_at || lastMessage?.sent_at || null,
    created_at: record.created_at || null,
    target_path: buildConversationPath(id),
    participants: (record.participants || []).map((entry) => ({
      id: resolvePublicIdentifier(entry.human_friendly_id, entry.id),
      user_id: resolvePublicIdentifier(entry.user?.human_friendly_id, entry.user_id),
      role_snapshot: text(entry.role_snapshot) || null,
      joined_at: entry.joined_at || null,
      archived_at: entry.archived_at || null,
      last_read_at: entry.last_read_at || null,
      user: entry.user ? serializeUser(entry.user) : null,
    })),
    visibility_roles: (record.visibility_roles || []).map((entry) => ({
      id: resolvePublicIdentifier(entry.human_friendly_id, entry.id),
      role_code: text(entry.role_code).toUpperCase(),
    })),
    last_message: lastMessage,
    attachment_count: lastMessage?.attachments?.length || 0,
  };
};

const serializeNotification = (record = {}) => ({
  id: resolvePublicIdentifier(record.human_friendly_id, record.id),
  notification_type: text(record.notification_type).toUpperCase() || 'SYSTEM',
  priority: text(record.priority).toUpperCase() || 'LOW',
  title: text(record.title),
  message: text(record.message),
  target_path: text(record.target_path) || null,
  context_type: text(record.context_type) || null,
  context_public_id: text(record.context_public_id) || null,
  read_at: record.read_at || null,
  created_at: record.created_at || null,
  template: record.template
    ? {
        id: resolvePublicIdentifier(record.template.human_friendly_id, record.template.id),
        name: text(record.template.name),
      }
    : null,
  deliveries: (record.deliveries || []).map((entry) => ({
    id: resolvePublicIdentifier(entry.human_friendly_id, entry.id),
    channel: text(entry.channel).toUpperCase(),
    status: text(entry.status).toUpperCase(),
    sent_at: entry.sent_at || null,
    delivered_at: entry.delivered_at || null,
    failed_at: entry.failed_at || null,
    attempt_count: Number(entry.attempt_count || 0),
    retryable: Boolean(entry.retryable),
    error_message: text(entry.error_message) || null,
  })),
});

const serializeDelivery = (record = {}) => ({
  id: resolvePublicIdentifier(record.human_friendly_id, record.id),
  notification_id: resolvePublicIdentifier(record.notification?.human_friendly_id, record.notification_id),
  channel: text(record.channel).toUpperCase() || 'IN_APP',
  status: text(record.status).toUpperCase() || 'QUEUED',
  recipient_target: text(record.recipient_target) || null,
  provider_name: text(record.provider_name) || null,
  attempt_count: Number(record.attempt_count || 0),
  sent_at: record.sent_at || null,
  delivered_at: record.delivered_at || null,
  failed_at: record.failed_at || null,
  retryable: Boolean(record.retryable),
  error_message: text(record.error_message) || null,
  target_path: text(record.notification?.target_path) || null,
  notification_title: text(record.notification?.title) || null,
  recipient: record.notification?.user ? serializeUser(record.notification.user) : null,
});

const templatePreview = (template = {}) => {
  const samples = (template.variables || []).reduce((acc, variable) => {
    acc[variable.key] = text(variable.sample_value) || `{{${variable.key}}}`;
    return acc;
  }, {});
  const apply = (value) =>
    text(value).replace(/\{\{\s*([A-Za-z0-9_.-]+)\s*\}\}/g, (_match, key) => samples[key] || `{{${key}}}`);
  return { subject: apply(template.subject), body: apply(template.body) };
};

const serializeTemplate = (record = {}) => ({
  id: resolvePublicIdentifier(record.human_friendly_id, record.id),
  name: text(record.name),
  channel: text(record.channel).toUpperCase() || 'IN_APP',
  subject: text(record.subject) || null,
  description: text(record.description) || null,
  body: text(record.body),
  is_active: record.is_active !== false,
  variable_count: (record.variables || []).length,
  preview: templatePreview(record),
  variables: (record.variables || []).map((entry) => ({
    id: resolvePublicIdentifier(entry.human_friendly_id, entry.id),
    key: text(entry.key),
    description: text(entry.description) || null,
    sample_value: text(entry.sample_value) || null,
  })),
});

module.exports = {
  buildConversationPath,
  personName,
  serializeUser,
  serializeAttachment,
  serializeMessage,
  serializeConversation,
  serializeNotification,
  serializeDelivery,
  serializeTemplate,
  isUnreadConversation,
};
