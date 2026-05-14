const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const {
  normalizeIdentifier,
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

const BASE_USER_SELECT = {
  id: true,
  human_friendly_id: true,
  email: true,
  position_title: true,
  profile: {
    select: {
      first_name: true,
      last_name: true,
    },
  },
};

const ATTACHMENT_SELECT = {
  id: true,
  human_friendly_id: true,
  storage_key: true,
  storage_provider: true,
  file_name: true,
  content_type: true,
  size_bytes: true,
  attachment_kind: true,
  public_url: true,
  created_at: true,
};

const MESSAGE_SELECT = {
  id: true,
  human_friendly_id: true,
  conversation_id: true,
  sender_user_id: true,
  sender_patient_id: true,
  reply_to_message_id: true,
  content: true,
  message_type: true,
  sent_at: true,
  edited_at: true,
  created_at: true,
  updated_at: true,
  sender_user: {
    select: BASE_USER_SELECT,
  },
  reply_to_message: {
    select: {
      id: true,
      human_friendly_id: true,
      content: true,
      sender_user: {
        select: BASE_USER_SELECT,
      },
    },
  },
  attachments: {
    where: { deleted_at: null },
    orderBy: { created_at: 'asc' },
    select: ATTACHMENT_SELECT,
  },
};

const PARTICIPANT_SELECT = {
  id: true,
  human_friendly_id: true,
  user_id: true,
  deleted_at: true,
  role_snapshot: true,
  joined_at: true,
  archived_at: true,
  muted_at: true,
  last_read_at: true,
  last_read_message: {
    select: {
      id: true,
      human_friendly_id: true,
      sent_at: true,
    },
  },
  user: {
    select: BASE_USER_SELECT,
  },
};

const CONVERSATION_LIST_INCLUDE = {
  participants: {
    where: { deleted_at: null },
    orderBy: { joined_at: 'asc' },
    select: PARTICIPANT_SELECT,
  },
  messages: {
    where: { deleted_at: null },
    orderBy: { sent_at: 'desc' },
    take: 1,
    select: MESSAGE_SELECT,
  },
  visibility_roles: {
    where: { deleted_at: null },
    select: {
      id: true,
      human_friendly_id: true,
      role_code: true,
    },
  },
};

const CONVERSATION_DETAIL_INCLUDE = {
  ...CONVERSATION_LIST_INCLUDE,
  messages: {
    where: { deleted_at: null },
    orderBy: { sent_at: 'asc' },
    take: 100,
    select: MESSAGE_SELECT,
  },
};

const normalizeSearch = (value) => normalizeIdentifier(value);
const normalizeRole = (value) => String(value || '').trim().toUpperCase();

const createPublicId = (prefix) => {
  const now = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `${prefix}-${now}${random}`.slice(0, 32);
};

const buildConversationWhere = ({
  tenantId,
  userId,
  search,
  sensitive,
  filter,
}) => {
  const normalizedSearch = normalizeSearch(search);
  const normalizedFilter = normalizeRole(filter);

  const where = {
    tenant_id: tenantId,
    deleted_at: null,
    participants: {
      some: {
        user_id: userId,
        deleted_at: null,
      },
    },
  };

  if (typeof sensitive === 'boolean') {
    where.is_sensitive = sensitive;
  }

  if (normalizedFilter === 'ARCHIVED') {
    where.OR = [
      { status: 'ARCHIVED' },
      {
        participants: {
          some: {
            user_id: userId,
            deleted_at: null,
            archived_at: { not: null },
          },
        },
      },
    ];
  }

  if (normalizedFilter === 'ACTIVE') {
    where.status = 'OPEN';
  }

  if (!normalizedSearch) return where;

  where.AND = [
    ...(Array.isArray(where.AND) ? where.AND : []),
    {
      OR: [
        { subject: { contains: normalizedSearch } },
        { human_friendly_id: { contains: normalizedSearch.toUpperCase() } },
        {
          messages: {
            some: {
              deleted_at: null,
              content: { contains: normalizedSearch },
            },
          },
        },
        {
          participants: {
            some: {
              deleted_at: null,
              user: {
                OR: [
                  { human_friendly_id: { contains: normalizedSearch.toUpperCase() } },
                  { email: { contains: normalizedSearch } },
                  {
                    profile: {
                      OR: [
                        { first_name: { contains: normalizedSearch } },
                        { last_name: { contains: normalizedSearch } },
                      ],
                    },
                  },
                ],
              },
            },
          },
        },
      ],
    },
  ];

  return where;
};

const resolveUserId = async (identifier, tenantId) =>
  resolveModelIdByIdentifier({
    model: 'user',
    identifier,
    where: {
      tenant_id: tenantId,
      deleted_at: null,
    },
  });

const resolveConversationRecord = async (identifier, tenantId, include = CONVERSATION_DETAIL_INCLUDE) =>
  resolveModelRecordByIdentifier({
    model: 'conversation',
    identifier,
    where: {
      tenant_id: tenantId,
      deleted_at: null,
    },
    include,
  });

const resolveMessageRecord = async (identifier, tenantId, include = {}) =>
  resolveModelRecordByIdentifier({
    model: 'message',
    identifier,
    where: {
      deleted_at: null,
      conversation: {
        tenant_id: tenantId,
        deleted_at: null,
      },
    },
    include,
  });

const resolveNotificationRecord = async (identifier, tenantId, include = {}) =>
  resolveModelRecordByIdentifier({
    model: 'notification',
    identifier,
    where: {
      tenant_id: tenantId,
      deleted_at: null,
    },
    include,
  });

const resolveTemplateRecord = async (identifier, tenantId, include = {}) =>
  resolveModelRecordByIdentifier({
    model: 'template',
    identifier,
    where: {
      tenant_id: tenantId,
      deleted_at: null,
    },
    include,
  });

const resolveParticipantRecord = async (identifier, conversationId) =>
  resolveModelRecordByIdentifier({
    model: 'conversation_participant',
    identifier,
    where: {
      conversation_id: conversationId,
      deleted_at: null,
    },
    include: {
      user: {
        select: BASE_USER_SELECT,
      },
    },
  });

const listConversations = async ({
  tenantId,
  userId,
  search,
  sensitive,
  filter,
  page = 1,
  limit = 30,
}) => {
  try {
    const where = buildConversationWhere({
      tenantId,
      userId,
      search,
      sensitive,
      filter,
    });
    return prisma.conversation.findMany({
      where,
      include: CONVERSATION_LIST_INCLUDE,
      orderBy: [{ last_message_at: 'desc' }, { updated_at: 'desc' }],
      skip: Math.max(0, (page - 1) * limit),
      take: limit,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const countConversations = async ({ tenantId, userId, search, sensitive, filter }) =>
  prisma.conversation.count({
    where: buildConversationWhere({ tenantId, userId, search, sensitive, filter }),
  });

const getConversation = async ({ tenantId, identifier }) => {
  try {
    return resolveConversationRecord(identifier, tenantId);
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const listMessages = async ({ tenantId, conversationId, search, page = 1, limit = 100 }) => {
  const normalizedSearch = normalizeSearch(search);
  const where = {
    deleted_at: null,
    conversation_id: conversationId,
    conversation: {
      tenant_id: tenantId,
      deleted_at: null,
    },
  };

  if (normalizedSearch) {
    where.content = { contains: normalizedSearch };
  }

  return prisma.message.findMany({
    where,
    orderBy: { sent_at: 'asc' },
    skip: Math.max(0, (page - 1) * limit),
    take: limit,
    select: MESSAGE_SELECT,
  });
};

const getMessage = async ({ tenantId, identifier }) => resolveMessageRecord(identifier, tenantId, {
  ...MESSAGE_SELECT,
  conversation: {
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
    },
  },
});

const listNotifications = async ({ tenantId, userId, search, page = 1, limit = 40 }) => {
  const normalizedSearch = normalizeSearch(search);
  return prisma.notification.findMany({
    where: {
      tenant_id: tenantId,
      user_id: userId,
      deleted_at: null,
      ...(normalizedSearch
        ? {
            OR: [
              { title: { contains: normalizedSearch } },
              { message: { contains: normalizedSearch } },
              { human_friendly_id: { contains: normalizedSearch.toUpperCase() } },
            ],
          }
        : {}),
    },
    include: {
      template: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
        },
      },
      deliveries: {
        where: { deleted_at: null },
        orderBy: { created_at: 'desc' },
        select: {
          id: true,
          human_friendly_id: true,
          channel: true,
          status: true,
          sent_at: true,
          delivered_at: true,
          failed_at: true,
          attempt_count: true,
          retryable: true,
          error_message: true,
        },
      },
    },
    orderBy: { created_at: 'desc' },
    skip: Math.max(0, (page - 1) * limit),
    take: limit,
  });
};

const countNotifications = async ({ tenantId, userId }) =>
  prisma.notification.count({
    where: {
      tenant_id: tenantId,
      user_id: userId,
      deleted_at: null,
    },
  });

const listDeliveries = async ({ tenantId, search, page = 1, limit = 40 }) => {
  const normalizedSearch = normalizeSearch(search);
  return prisma.notification_delivery.findMany({
    where: {
      deleted_at: null,
      notification: {
        tenant_id: tenantId,
        deleted_at: null,
      },
      ...(normalizedSearch
        ? {
            OR: [
              { human_friendly_id: { contains: normalizedSearch.toUpperCase() } },
              { recipient_target: { contains: normalizedSearch } },
              { provider_name: { contains: normalizedSearch } },
              {
                notification: {
                  OR: [
                    { title: { contains: normalizedSearch } },
                    { message: { contains: normalizedSearch } },
                    { human_friendly_id: { contains: normalizedSearch.toUpperCase() } },
                  ],
                },
              },
            ],
          }
        : {}),
    },
    include: {
      notification: {
        select: {
          id: true,
          human_friendly_id: true,
          title: true,
          target_path: true,
          user_id: true,
          user: {
            select: BASE_USER_SELECT,
          },
        },
      },
    },
    orderBy: [{ failed_at: 'desc' }, { updated_at: 'desc' }],
    skip: Math.max(0, (page - 1) * limit),
    take: limit,
  });
};

const countDeliveries = async ({ tenantId }) =>
  prisma.notification_delivery.count({
    where: {
      deleted_at: null,
      notification: {
        tenant_id: tenantId,
        deleted_at: null,
      },
    },
  });

const listTemplates = async ({ tenantId, search, page = 1, limit = 40 }) => {
  const normalizedSearch = normalizeSearch(search);
  return prisma.template.findMany({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      ...(normalizedSearch
        ? {
            OR: [
              { name: { contains: normalizedSearch } },
              { subject: { contains: normalizedSearch } },
              { body: { contains: normalizedSearch } },
              { human_friendly_id: { contains: normalizedSearch.toUpperCase() } },
            ],
          }
        : {}),
    },
    include: {
      variables: {
        where: { deleted_at: null },
        orderBy: { key: 'asc' },
      },
    },
    orderBy: [{ updated_at: 'desc' }, { name: 'asc' }],
    skip: Math.max(0, (page - 1) * limit),
    take: limit,
  });
};

const countTemplates = async ({ tenantId }) =>
  prisma.template.count({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
    },
  });

const listReferenceUsers = async ({ tenantId, search }) => {
  const normalizedSearch = normalizeSearch(search);
  return prisma.user.findMany({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      ...(normalizedSearch
        ? {
            OR: [
              { email: { contains: normalizedSearch } },
              { human_friendly_id: { contains: normalizedSearch.toUpperCase() } },
              {
                profile: {
                  OR: [
                    { first_name: { contains: normalizedSearch } },
                    { last_name: { contains: normalizedSearch } },
                  ],
                },
              },
            ],
          }
        : {}),
    },
    select: {
      ...BASE_USER_SELECT,
      roles: {
        where: { deleted_at: null },
        select: {
          role: {
            select: {
              name: true,
            },
          },
        },
      },
    },
    orderBy: { email: 'asc' },
    take: 50,
  });
};

const findExistingDirectConversation = async ({ tenantId, participantIds }) => {
  const uniqueIds = Array.from(new Set(participantIds.filter(Boolean)));
  if (uniqueIds.length !== 2) return null;

  const results = await prisma.conversation.findMany({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      conversation_type: 'DIRECT',
      participants: {
        some: {
          user_id: { in: uniqueIds },
          deleted_at: null,
        },
      },
    },
    include: CONVERSATION_DETAIL_INCLUDE,
    orderBy: { updated_at: 'desc' },
    take: 10,
  });

  return (
    results.find((record) => {
      const activeIds = (record.participants || [])
        .filter((entry) => entry.deleted_at == null)
        .map((entry) => entry.user_id)
        .sort();
      return activeIds.length === 2 && activeIds[0] === uniqueIds.slice().sort()[0] && activeIds[1] === uniqueIds.slice().sort()[1];
    }) || null
  );
};

const findConversationUnreadStats = async ({ tenantId, userId }) => {
  const rows = await prisma.conversation_participant.findMany({
    where: {
      user_id: userId,
      deleted_at: null,
      conversation: {
        tenant_id: tenantId,
        deleted_at: null,
      },
    },
    select: {
      archived_at: true,
      last_read_at: true,
      conversation: {
        select: {
          last_message_at: true,
          is_sensitive: true,
        },
      },
    },
  });

  return rows.reduce(
    (acc, row) => {
      if (row.archived_at) acc.archived += 1;
      if (row.conversation?.is_sensitive) acc.sensitive += 1;
      const lastMessageAt = row.conversation?.last_message_at ? new Date(row.conversation.last_message_at).getTime() : 0;
      const lastReadAt = row.last_read_at ? new Date(row.last_read_at).getTime() : 0;
      if (lastMessageAt > lastReadAt) acc.unread += 1;
      return acc;
    },
    { unread: 0, archived: 0, sensitive: 0 }
  );
};

module.exports = {
  prisma,
  createPublicId,
  resolveUserId,
  resolveConversationRecord,
  resolveMessageRecord,
  resolveNotificationRecord,
  resolveTemplateRecord,
  resolveParticipantRecord,
  listConversations,
  countConversations,
  getConversation,
  listMessages,
  getMessage,
  listNotifications,
  countNotifications,
  listDeliveries,
  countDeliveries,
  listTemplates,
  countTemplates,
  listReferenceUsers,
  findExistingDirectConversation,
  findConversationUnreadStats,
};
