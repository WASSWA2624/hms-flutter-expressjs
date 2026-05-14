/**
 * Message routes
 *
 * @module modules/message/routes
 * @description API routes for message management.
 * Per module-creation.mdc: Mount endpoints per P010_api_endpoints.mdc, apply all middlewares.
 * Per api.mdc: All endpoints under /api/v1/messages
 */

const express = require('express');
const router = express.Router();
const { asyncHandler } = require('@lib/async');
const { validate } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const messageController = require('@controllers/message/message.controller');
const {
  createMessageSchema,
  updateMessageSchema,
  messageIdParamsSchema,
  listMessagesQuerySchema
} = require('@validations/message/message.schema');

/**
 * @description List messages with pagination
 * @method GET
 * @route /api/v1/messages
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @queryParams page, limit, sort_by, order, conversation_id, sender_user_id, sender_patient_id, search
 * @returns {Object} Paginated message list
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  validate({ query: listMessagesQuerySchema }),
  asyncHandler(messageController.listMessages)
);

/**
 * @description Get message by ID
 * @method GET
 * @route /api/v1/messages/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams id (UUID)
 * @returns {Object} Message details
 * @throws 401 Unauthorized
 * @throws 404 Message not found
 */
router.get(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  validate({ params: messageIdParamsSchema }),
  asyncHandler(messageController.getMessage)
);

/**
 * @description Create new message
 * @method POST
 * @route /api/v1/messages
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @bodyParams conversation_id, sender_user_id, sender_patient_id, content, sent_at
 * @returns {Object} Created message
 * @throws 400 Validation error
 * @throws 401 Unauthorized
 */
router.post(
  '/',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  validate({ body: createMessageSchema }),
  asyncHandler(messageController.createMessage)
);

/**
 * @description Update message
 * @method PUT
 * @route /api/v1/messages/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams id (UUID)
 * @bodyParams content
 * @returns {Object} Updated message
 * @throws 400 Validation error
 * @throws 401 Unauthorized
 * @throws 404 Message not found
 */
router.put(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  validate({ params: messageIdParamsSchema, body: updateMessageSchema }),
  asyncHandler(messageController.updateMessage)
);

/**
 * @description Delete message (soft delete)
 * @method DELETE
 * @route /api/v1/messages/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams id (UUID)
 * @returns 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Message not found
 */
router.delete(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_DELETE, 'permission'),
  validate({ params: messageIdParamsSchema }),
  asyncHandler(messageController.deleteMessage)
);

module.exports = router;
