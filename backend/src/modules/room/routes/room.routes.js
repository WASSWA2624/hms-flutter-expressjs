/**
 * Room routes
 *
 * @module modules/room/routes
 * @description Room endpoints mounted at /api/v1/rooms
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const roomController = require('@controllers/room/room.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createRoomSchema,
  updateRoomSchema,
  roomIdParamsSchema,
  listRoomsQuerySchema
} = require('@validations/room/room.schema');

const BED_MANAGEMENT_READ_SCOPES = [
  PERMISSIONS.CLINICAL_READ,
  PERMISSIONS.OPERATIONS_READ,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const BED_MANAGEMENT_ADMIN_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @description List rooms with pagination and filters
 * @method GET
 * @route /api/v1/rooms/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [ward_id] - Filter by ward ID (UUID)
 * @queryParams {string} [search] - Search by name
 * @bodyParams None
 * @returns {Object} Paginated list of rooms
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listRoomsQuerySchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_READ_SCOPES, 'permission'),
  roomController.listRooms
);

/**
 * @description Get room by ID
 * @method GET
 * @route /api/v1/rooms/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Room ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Room data
 * @throws 401 Unauthorized
 * @throws 404 Room not found
 */
router.get(
  '/:id',  validateRequest({ params: roomIdParamsSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_READ_SCOPES, 'permission'),
  roomController.getRoomById
);

/**
 * @description Create new room
 * @method POST
 * @route /api/v1/rooms/
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} facility_id - Facility ID (required, UUID)
 * @bodyParams {string} [ward_id] - Ward ID (UUID)
 * @bodyParams {string} name - Room name (required, max 255 chars)
 * @bodyParams {string} [floor] - Floor (max 50 chars)
 * @returns {Object} Created room
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createRoomSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_ADMIN_SCOPES, 'permission'),
  roomController.createRoom
);

/**
 * @description Update room
 * @method PUT
 * @route /api/v1/rooms/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Room ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [ward_id] - Ward ID (UUID)
 * @bodyParams {string} [name] - Room name (max 255 chars)
 * @bodyParams {string} [floor] - Floor (max 50 chars)
 * @returns {Object} Updated room
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Room not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: roomIdParamsSchema, body: updateRoomSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_ADMIN_SCOPES, 'permission'),
  roomController.updateRoom
);

/**
 * @description Delete room (soft delete)
 * @method DELETE
 * @route /api/v1/rooms/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Room ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Room not found
 */
router.delete(
  '/:id',  validateRequest({ params: roomIdParamsSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_ADMIN_SCOPES, 'permission'),
  roomController.deleteRoom
);

module.exports = router;
