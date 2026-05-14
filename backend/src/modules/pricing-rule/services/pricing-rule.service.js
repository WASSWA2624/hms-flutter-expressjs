/**
 * Pricing Rule service
 *
 * @module modules/pricing-rule/services
 * @description Business logic layer for pricing rule operations.
 */

const pricingRuleRepository = require('@repositories/pricing-rule/pricing-rule.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

const PRICING_RULE_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
};

const buildEmptyListResult = (page, limit) => ({
  pricingRules: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const mapPricingRuleForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    tenant_display_id: resolvePublicIdentifier(
      record?.tenant_display_id,
      record?.tenant?.human_friendly_id,
      record?.tenant_id
    ),
    timeline_at: record?.timeline_at || record?.effective_from || record?.created_at || null,
  };
};

/**
 * List pricing rules with pagination and filtering
 */
const listPricingRules = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};

    if (filters.tenant_id !== undefined) {
      const tenantId = await resolveIdentifierForFilter({
        value: filters.tenant_id,
        model: 'tenant',
      });
      if (tenantId === null) return buildEmptyListResult(page, limit);
      if (tenantId !== undefined) whereClause.tenant_id = tenantId;
    }

    if (filters.currency) whereClause.currency = filters.currency;
    if (filters.name) whereClause.name = { contains: filters.name };

    const search = sanitizeIdentifier(filters.search);
    if (search) {
      whereClause.OR = [
        { name: { contains: search } },
        { description: { contains: search } },
        { human_friendly_id: { contains: search.toUpperCase() } },
      ];
    }

    const [pricingRules, total] = await Promise.all([
      pricingRuleRepository.findMany(whereClause, skip, limit, orderBy, PRICING_RULE_INCLUDE),
      pricingRuleRepository.count(whereClause),
    ]);

    return {
      pricingRules: pricingRules.map(mapPricingRuleForDisplay),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get pricing rule by ID
 */
const getPricingRuleById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'pricing_rule',
      identifier: id,
    });

    const pricingRule = await pricingRuleRepository.findById(resolvedId, PRICING_RULE_INCLUDE);

    if (!pricingRule) {
      throw new HttpError('errors.pricing_rule.not_found', 404);
    }

    return mapPricingRuleForDisplay(pricingRule);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new pricing rule
 */
const createPricingRule = async (data, userId, ipAddress) => {
  try {
    const tenantId = await resolveIdentifierForPayload({
      value: data?.tenant_id,
      field: 'tenant_id',
      model: 'tenant',
    });

    const pricingRule = await pricingRuleRepository.create({
      ...data,
      tenant_id: tenantId,
    });

    const createdRecord = await pricingRuleRepository.findById(pricingRule.id, PRICING_RULE_INCLUDE);

    createAuditLog({
      tenant_id: pricingRule.tenant_id,
      user_id: userId,
      action: 'CREATE',
      entity: 'pricing_rule',
      entity_id: pricingRule.id,
      diff: { after: pricingRule },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapPricingRuleForDisplay(createdRecord || pricingRule);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update pricing rule
 */
const updatePricingRule = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'pricing_rule',
      identifier: id,
    });

    const before = await pricingRuleRepository.findById(resolvedId, PRICING_RULE_INCLUDE);

    if (!before) {
      throw new HttpError('errors.pricing_rule.not_found', 404);
    }

    const pricingRule = await pricingRuleRepository.update(before.id, data);
    const updatedRecord = await pricingRuleRepository.findById(pricingRule.id, PRICING_RULE_INCLUDE);

    createAuditLog({
      tenant_id: pricingRule.tenant_id || before.tenant_id,
      user_id: userId,
      action: 'UPDATE',
      entity: 'pricing_rule',
      entity_id: pricingRule.id,
      diff: { before, after: pricingRule },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapPricingRuleForDisplay(updatedRecord || pricingRule);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete pricing rule (soft delete)
 */
const deletePricingRule = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'pricing_rule',
      identifier: id,
    });

    const before = await pricingRuleRepository.findById(resolvedId, PRICING_RULE_INCLUDE);

    if (!before) {
      throw new HttpError('errors.pricing_rule.not_found', 404);
    }

    await pricingRuleRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'DELETE',
      entity: 'pricing_rule',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listPricingRules,
  getPricingRuleById,
  createPricingRule,
  updatePricingRule,
  deletePricingRule,
};
