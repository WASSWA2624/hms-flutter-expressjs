/**
 * Contact controller
 *
 * @module modules/contact/controllers
 * @description Request handlers for contact endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const contactService = require('@services/contact/contact.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List contacts with pagination
 * GET /api/v1/contacts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listContacts = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    contact_type,
    facility_id,
    branch_id,
    patient_id,
    user_profile_id,
    staff_profile_id,
    supplier_id,
    is_primary,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    contact_type,
    facility_id,
    branch_id,
    patient_id,
    user_profile_id,
    staff_profile_id,
    supplier_id,
    is_primary,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await contactService.listContacts(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.contact.list.success', result.contacts, result.pagination);
});

/**
 * Get contact by ID
 * GET /api/v1/contacts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getContactById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const contact = await contactService.getContactById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.contact.get.success', contact);
});

/**
 * Create new contact
 * POST /api/v1/contacts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createContact = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const contact = await contactService.createContact(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.contact.create.success', contact);
});

/**
 * Update contact
 * PUT /api/v1/contacts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateContact = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const contact = await contactService.updateContact(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.contact.update.success', contact);
});

/**
 * Delete contact (soft delete)
 * DELETE /api/v1/contacts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteContact = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await contactService.deleteContact(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listContacts,
  getContactById,
  createContact,
  updateContact,
  deleteContact
};
