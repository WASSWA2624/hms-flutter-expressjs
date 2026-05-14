const { z } = require('zod');
const {
  booleanStringSchema,
  listQuerySchema,
  nonEmptyStringSchema,
  uuidOrFriendlyIdentifierSchema,
} = require('@lib/validation/zod');

const communicationsPanelSchema = z.enum([
  'inbox',
  'notifications',
  'deliveries',
  'templates',
]);

const communicationsActionSchema = z.enum([
  'view',
  'compose',
  'create',
  'edit',
]);

const workspaceQuerySchema = listQuerySchema.extend({
  panel: communicationsPanelSchema.optional(),
  conversationId: uuidOrFriendlyIdentifierSchema.optional(),
  messageId: uuidOrFriendlyIdentifierSchema.optional(),
  templateId: uuidOrFriendlyIdentifierSchema.optional(),
  notificationId: uuidOrFriendlyIdentifierSchema.optional(),
  action: communicationsActionSchema.optional(),
  filter: z.string().trim().min(1).max(80).optional(),
  search: z.string().trim().max(160).optional(),
  sensitive: booleanStringSchema.optional(),
  unreadOnly: booleanStringSchema.optional(),
});

const referenceDataQuerySchema = z.object({
  search: z.string().trim().max(120).optional(),
});

const resolveLegacyParamsSchema = z.object({
  resource: z.enum([
    'conversations',
    'messages',
    'notifications',
    'notification-deliveries',
    'templates',
    'template-variables',
  ]),
  id: uuidOrFriendlyIdentifierSchema,
});

const conversationIdentifierParamsSchema = z.object({
  conversationIdentifier: uuidOrFriendlyIdentifierSchema,
});

const messageIdentifierParamsSchema = z.object({
  messageIdentifier: uuidOrFriendlyIdentifierSchema,
});

const participantIdentifierParamsSchema = conversationIdentifierParamsSchema.extend({
  participantIdentifier: uuidOrFriendlyIdentifierSchema,
});

const listConversationsQuerySchema = listQuerySchema.extend({
  search: z.string().trim().max(160).optional(),
  filter: z.string().trim().min(1).max(80).optional(),
  sensitive: booleanStringSchema.optional(),
  unreadOnly: booleanStringSchema.optional(),
});

const createConversationSchema = z.object({
  subject: z.string().trim().max(255).optional().nullable(),
  participant_ids: z.array(uuidOrFriendlyIdentifierSchema).min(1).max(25),
  is_sensitive: z.coerce.boolean().optional().default(false),
  conversation_type: z.enum(['DIRECT', 'GROUP']).optional(),
  visibility_roles: z.array(nonEmptyStringSchema.max(80)).max(12).optional(),
});

const addParticipantSchema = z.object({
  user_id: uuidOrFriendlyIdentifierSchema,
  role_snapshot: z.string().trim().max(80).optional().nullable(),
});

const listMessagesQuerySchema = listQuerySchema.extend({
  search: z.string().trim().max(160).optional(),
});

const createMessageSchema = z.object({
  content: z.string().trim().max(12000).optional().nullable(),
  reply_to_message_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
});

module.exports = {
  communicationsPanelSchema,
  communicationsActionSchema,
  workspaceQuerySchema,
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
  conversationIdentifierParamsSchema,
  messageIdentifierParamsSchema,
  participantIdentifierParamsSchema,
  listConversationsQuerySchema,
  createConversationSchema,
  addParticipantSchema,
  listMessagesQuerySchema,
  createMessageSchema,
};
