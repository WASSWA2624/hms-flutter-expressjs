/**
 * Conversation routes
 *
 * @module modules/conversation/routes
 * @description API routes for conversation management.
 * Per module-creation.mdc: Mount endpoints per P010_api_endpoints.mdc, apply all middlewares.
 * Per api.mdc: All endpoints under /api/v1/conversations
 */

const express = require('express');
const router = express.Router();
const { asyncHandler } = require('@lib/async');
const { validate } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const conversationController = require('@controllers/conversation/conversation.controller');
const {
  createConversationSchema,
  updateConversationSchema,
  conversationIdParamsSchema,
  listConversationsQuerySchema
} = require('@validations/conversation/conversation.schema');

/**
 * @description List conversations with pagination
 * @method GET
 * @route /api/v1/conversations
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @queryParams page, limit, sort_by, order, tenant_id, created_by_user_id, subject, search
 * @returns {Object} Paginated conversation list
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  validate({ query: listConversationsQuerySchema }),
  asyncHandler(conversationController.listConversations)
);

/**
 * @description Get conversation by ID
 * @method GET
 * @route /api/v1/conversations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams id (UUID)
 * @returns {Object} Conversation details
 * @throws 401 Unauthorized
 * @throws 404 Conversation not found
 */
router.get(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  validate({ params: conversationIdParamsSchema }),
  asyncHandler(conversationController.getConversation)
);

/**
 * @description Create new conversation
 * @method POST
 * @route /api/v1/conversations
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @bodyParams tenant_id, subject, created_by_user_id
 * @returns {Object} Created conversation
 * @throws 400 Validation error
 * @throws 401 Unauthorized
 */
router.post(
  '/',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  validate({ body: createConversationSchema }),
  asyncHandler(conversationController.createConversation)
);

/**
 * @description Update conversation
 * @method PUT
 * @route /api/v1/conversations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams id (UUID)
 * @bodyParams subject
 * @returns {Object} Updated conversation
 * @throws 400 Validation error
 * @throws 401 Unauthorized
 * @throws 404 Conversation not found
 */
router.put(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  validate({ params: conversationIdParamsSchema, body: updateConversationSchema }),
  asyncHandler(conversationController.updateConversation)
);

/**
 * @description Delete conversation (soft delete)
 * @method DELETE
 * @route /api/v1/conversations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams id (UUID)
 * @returns 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Conversation not found
 */
router.delete(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_DELETE, 'permission'),
  validate({ params: conversationIdParamsSchema }),
  asyncHandler(conversationController.deleteConversation)
);

module.exports = router;
