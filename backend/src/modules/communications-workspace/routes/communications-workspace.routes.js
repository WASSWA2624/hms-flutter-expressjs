const express = require('express');
const multer = require('multer');
const communicationsWorkspaceController = require('@controllers/communications-workspace/communications-workspace.controller');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS } = require('@config/permissions');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  workspaceQuerySchema,
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
  conversationIdentifierParamsSchema,
  participantIdentifierParamsSchema,
  listConversationsQuerySchema,
  createConversationSchema,
  addParticipantSchema,
  listMessagesQuerySchema,
  createMessageSchema,
} = require('@validations/communications-workspace/communications-workspace.schema');

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    files: 5,
    fileSize: 10 * 1024 * 1024,
  },
});

const requireCommunicationsWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('communications_workspace_v1')) {
    return next(new HttpError('errors.communications.workspace_not_enabled', 404));
  }
  return next();
};

router.use(requireCommunicationsWorkspaceV1);

router.get(
  '/workspace',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  communicationsWorkspaceController.getWorkspace
);

router.get(
  '/reference-data',
  validateRequest({ query: referenceDataQuerySchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  communicationsWorkspaceController.getReferenceData
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  communicationsWorkspaceController.resolveLegacyRoute
);

router.get(
  '/conversations',
  validateRequest({ query: listConversationsQuerySchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  communicationsWorkspaceController.listConversations
);

router.get(
  '/conversations/:conversationIdentifier',
  validateRequest({ params: conversationIdentifierParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  communicationsWorkspaceController.getConversation
);

router.post(
  '/conversations',
  validateRequest({ body: createConversationSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  communicationsWorkspaceController.createConversation
);

router.post(
  '/conversations/:conversationIdentifier/read',
  validateRequest({ params: conversationIdentifierParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  communicationsWorkspaceController.markConversationRead
);

router.post(
  '/conversations/:conversationIdentifier/archive',
  validateRequest({ params: conversationIdentifierParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  communicationsWorkspaceController.archiveConversation
);

router.post(
  '/conversations/:conversationIdentifier/unarchive',
  validateRequest({ params: conversationIdentifierParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  communicationsWorkspaceController.unarchiveConversation
);

router.post(
  '/conversations/:conversationIdentifier/participants',
  validateRequest({
    params: conversationIdentifierParamsSchema,
    body: addParticipantSchema,
  }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  communicationsWorkspaceController.addParticipant
);

router.delete(
  '/conversations/:conversationIdentifier/participants/:participantIdentifier',
  validateRequest({ params: participantIdentifierParamsSchema }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  communicationsWorkspaceController.removeParticipant
);

router.get(
  '/conversations/:conversationIdentifier/messages',
  validateRequest({
    params: conversationIdentifierParamsSchema,
    query: listMessagesQuerySchema,
  }),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  communicationsWorkspaceController.listMessages
);

router.post(
  '/conversations/:conversationIdentifier/messages',
  upload.array('attachments', 5),
  validateRequest({
    params: conversationIdentifierParamsSchema,
    body: createMessageSchema,
  }),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  communicationsWorkspaceController.createMessage
);

module.exports = router;
