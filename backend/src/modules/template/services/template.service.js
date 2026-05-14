/**
 * Template service
 *
 * @module modules/template/services
 * @description Business logic layer for template operations.
 * Per module-creation.mdc: Only import/use its own repo (no direct DB).
 * Per module-creation.mdc: All mutations call @lib/audit/createAuditLog.
 */

const templateRepository = require('@modules/template/repositories/template.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List templates with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @returns {Promise<Object>} Templates and pagination info
 */
const listTemplates = async (filters, page, limit) => {
  const skip = (page - 1) * limit;
  
  // Build filter object for repository
  const where = {};
  if (filters.tenant_id) where.tenant_id = filters.tenant_id;
  if (filters.name) where.name = { contains: filters.name };
  if (filters.channel) where.channel = filters.channel;
  
  // Handle search across multiple fields
  if (filters.search) {
    where.OR = [
      { name: { contains: filters.search } },
      { body: { contains: filters.search } }
    ];
  }

  const [templates, total] = await Promise.all([
    templateRepository.findMany(where, skip, limit),
    templateRepository.count(where)
  ]);

  return { templates, total };
};

/**
 * Get template by ID
 *
 * @param {string} id - Template ID
 * @returns {Promise<Object>} Template object
 * @throws {HttpError} If template not found
 */
const getTemplateById = async (id) => {
  const template = await templateRepository.findById(id, {
    variables: true
  });

  if (!template) {
    throw new HttpError('errors.template.not_found', 404);
  }

  return template;
};

/**
 * Create new template
 *
 * @param {Object} data - Template data
 * @param {string} userId - User ID creating the template
 * @returns {Promise<Object>} Created template
 */
const createTemplate = async (data, userId) => {
  const template = await templateRepository.create(data);

  // Create audit log
  await createAuditLog({
    action: 'CREATE',
    entity: 'template',
    entity_id: template.id,
    tenant_id: data.tenant_id,
    user_id: userId,
    changes: { new: template }
  });

  return template;
};

/**
 * Update template
 *
 * @param {string} id - Template ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID updating the template
 * @returns {Promise<Object>} Updated template
 * @throws {HttpError} If template not found
 */
const updateTemplate = async (id, data, userId) => {
  const existing = await templateRepository.findById(id);
  
  if (!existing) {
    throw new HttpError('errors.template.not_found', 404);
  }

  const updated = await templateRepository.update(id, data);

  // Create audit log
  await createAuditLog({
    action: 'UPDATE',
    entity: 'template',
    entity_id: id,
    tenant_id: existing.tenant_id,
    user_id: userId,
    changes: { old: existing, new: updated }
  });

  return updated;
};

/**
 * Delete template (soft delete)
 *
 * @param {string} id - Template ID
 * @param {string} userId - User ID deleting the template
 * @returns {Promise<void>}
 * @throws {HttpError} If template not found
 */
const deleteTemplate = async (id, userId) => {
  const existing = await templateRepository.findById(id);
  
  if (!existing) {
    throw new HttpError('errors.template.not_found', 404);
  }

  await templateRepository.softDelete(id);

  // Create audit log
  await createAuditLog({
    action: 'DELETE',
    entity: 'template',
    entity_id: id,
    tenant_id: existing.tenant_id,
    user_id: userId,
    changes: { old: existing }
  });
};

module.exports = {
  listTemplates,
  getTemplateById,
  createTemplate,
  updateTemplate,
  deleteTemplate
};
