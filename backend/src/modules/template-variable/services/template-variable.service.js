/**
 * Template Variable service
 *
 * @module modules/template-variable/services
 * @description Business logic layer for template variable operations.
 * Per module-creation.mdc: Only import/use its own repo (no direct DB).
 * Per module-creation.mdc: All mutations call @lib/audit/createAuditLog.
 */

const templateVariableRepository = require('@modules/template-variable/repositories/template-variable.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List template variables with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @returns {Promise<Object>} Template variables and pagination info
 */
const listTemplateVariables = async (filters, page, limit) => {
  const skip = (page - 1) * limit;
  
  // Build filter object for repository
  const where = {};
  if (filters.template_id) where.template_id = filters.template_id;
  if (filters.key) where.key = { contains: filters.key };
  
  // Handle search across multiple fields
  if (filters.search) {
    where.OR = [
      { key: { contains: filters.search } },
      { description: { contains: filters.search } }
    ];
  }

  const [templateVariables, total] = await Promise.all([
    templateVariableRepository.findMany(where, skip, limit),
    templateVariableRepository.count(where)
  ]);

  return { templateVariables, total };
};

/**
 * Get template variable by ID
 *
 * @param {string} id - Template Variable ID
 * @returns {Promise<Object>} Template Variable object
 * @throws {HttpError} If template variable not found
 */
const getTemplateVariableById = async (id) => {
  const templateVariable = await templateVariableRepository.findById(id, {
    template: true
  });

  if (!templateVariable) {
    throw new HttpError('errors.template_variable.not_found', 404);
  }

  return templateVariable;
};

/**
 * Create new template variable
 *
 * @param {Object} data - Template Variable data
 * @param {string} userId - User ID creating the template variable
 * @param {string} tenantId - Tenant ID for audit log
 * @returns {Promise<Object>} Created template variable
 */
const createTemplateVariable = async (data, userId, tenantId) => {
  const templateVariable = await templateVariableRepository.create(data);

  // Create audit log
  await createAuditLog({
    action: 'CREATE',
    entity: 'template_variable',
    entity_id: templateVariable.id,
    tenant_id: tenantId,
    user_id: userId,
    changes: { new: templateVariable }
  });

  return templateVariable;
};

/**
 * Update template variable
 *
 * @param {string} id - Template Variable ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID updating the template variable
 * @param {string} tenantId - Tenant ID for audit log
 * @returns {Promise<Object>} Updated template variable
 * @throws {HttpError} If template variable not found
 */
const updateTemplateVariable = async (id, data, userId, tenantId) => {
  const existing = await templateVariableRepository.findById(id);
  
  if (!existing) {
    throw new HttpError('errors.template_variable.not_found', 404);
  }

  const updated = await templateVariableRepository.update(id, data);

  // Create audit log
  await createAuditLog({
    action: 'UPDATE',
    entity: 'template_variable',
    entity_id: id,
    tenant_id: tenantId,
    user_id: userId,
    changes: { old: existing, new: updated }
  });

  return updated;
};

/**
 * Delete template variable (soft delete)
 *
 * @param {string} id - Template Variable ID
 * @param {string} userId - User ID deleting the template variable
 * @param {string} tenantId - Tenant ID for audit log
 * @returns {Promise<void>}
 * @throws {HttpError} If template variable not found
 */
const deleteTemplateVariable = async (id, userId, tenantId) => {
  const existing = await templateVariableRepository.findById(id);
  
  if (!existing) {
    throw new HttpError('errors.template_variable.not_found', 404);
  }

  await templateVariableRepository.softDelete(id);

  // Create audit log
  await createAuditLog({
    action: 'DELETE',
    entity: 'template_variable',
    entity_id: id,
    tenant_id: tenantId,
    user_id: userId,
    changes: { old: existing }
  });
};

module.exports = {
  listTemplateVariables,
  getTemplateVariableById,
  createTemplateVariable,
  updateTemplateVariable,
  deleteTemplateVariable
};
