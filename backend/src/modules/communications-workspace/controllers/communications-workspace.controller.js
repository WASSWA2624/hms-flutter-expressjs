const communicationsWorkspaceService = require('@services/communications-workspace/communications-workspace.service');
const { asyncHandler } = require('@lib/async');
const { sendCreated, sendSuccess } = require('@lib/response');

const getWorkspace = asyncHandler(async (req, res) => {
  const { page = 1, limit = 30, sort_by, order = 'desc', ...filters } = req.query;
  const data = await communicationsWorkspaceService.getWorkspace(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );
  return sendSuccess(res, 200, 'Communications workspace loaded.', data);
});

const getReferenceData = asyncHandler(async (req, res) => {
  const data = await communicationsWorkspaceService.getReferenceData(req.query, req.user);
  return sendSuccess(res, 200, 'Communications reference data loaded.', data);
});

const resolveLegacyRoute = asyncHandler(async (req, res) => {
  const data = await communicationsWorkspaceService.resolveLegacyRoute(
    req.params.resource,
    req.params.id,
    req.user
  );
  return sendSuccess(res, 200, 'Legacy communications route resolved.', data);
});

const listConversations = asyncHandler(async (req, res) => {
  const { page = 1, limit = 30, sort_by, order = 'desc', ...filters } = req.query;
  const data = await communicationsWorkspaceService.listConversations(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );
  return sendSuccess(res, 200, 'Conversations loaded.', data);
});

const getConversation = asyncHandler(async (req, res) => {
  const data = await communicationsWorkspaceService.getConversation(
    req.params.conversationIdentifier,
    req.user
  );
  return sendSuccess(res, 200, 'Conversation loaded.', data);
});

const createConversation = asyncHandler(async (req, res) => {
  const data = await communicationsWorkspaceService.createConversation(req.body, req.user);
  return sendCreated(res, data, 'Conversation created.');
});

const markConversationRead = asyncHandler(async (req, res) => {
  const data = await communicationsWorkspaceService.markConversationRead(
    req.params.conversationIdentifier,
    req.user
  );
  return sendSuccess(res, 200, 'Conversation marked as read.', data);
});

const archiveConversation = asyncHandler(async (req, res) => {
  const data = await communicationsWorkspaceService.archiveConversation(
    req.params.conversationIdentifier,
    req.user,
    true
  );
  return sendSuccess(res, 200, 'Conversation archived.', data);
});

const unarchiveConversation = asyncHandler(async (req, res) => {
  const data = await communicationsWorkspaceService.archiveConversation(
    req.params.conversationIdentifier,
    req.user,
    false
  );
  return sendSuccess(res, 200, 'Conversation unarchived.', data);
});

const addParticipant = asyncHandler(async (req, res) => {
  const data = await communicationsWorkspaceService.addConversationParticipant(
    req.params.conversationIdentifier,
    req.body,
    req.user
  );
  return sendSuccess(res, 200, 'Conversation participant added.', data);
});

const removeParticipant = asyncHandler(async (req, res) => {
  const data = await communicationsWorkspaceService.removeConversationParticipant(
    req.params.conversationIdentifier,
    req.params.participantIdentifier,
    req.user
  );
  return sendSuccess(res, 200, 'Conversation participant removed.', data);
});

const listMessages = asyncHandler(async (req, res) => {
  const { page = 1, limit = 100, sort_by, order = 'asc', ...filters } = req.query;
  const data = await communicationsWorkspaceService.listConversationMessages(
    req.params.conversationIdentifier,
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );
  return sendSuccess(res, 200, 'Conversation messages loaded.', data);
});

const createMessage = asyncHandler(async (req, res) => {
  const data = await communicationsWorkspaceService.createConversationMessage(
    req.params.conversationIdentifier,
    req.body,
    req.files,
    req.user
  );
  return sendCreated(res, data, 'Conversation message created.');
});

module.exports = {
  getWorkspace,
  getReferenceData,
  resolveLegacyRoute,
  listConversations,
  getConversation,
  createConversation,
  markConversationRead,
  archiveConversation,
  unarchiveConversation,
  addParticipant,
  removeParticipant,
  listMessages,
  createMessage,
};
