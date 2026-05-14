/**
 * Integration log module validation schemas
 *
 * @module modules/integration-log/schemas
 * @description Zod validation schemas for integration log endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 * Note: This is a READ-ONLY module (no create/update schemas)
 */

const { z } = require('zod');
const { 
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Enums ====================

/**
 * Integration status enum (matches Prisma schema)
 */
const IntegrationStatusEnum = z.enum(['ACTIVE', 'INACTIVE', 'ERROR']);

// ==================== URL Params ====================

/**
 * Integration log ID URL parameter validation
 * Used for GET /:id endpoint
 */
const integrationLogIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

/**
 * Integration ID URL parameter validation
 * Used for GET /integration/:integrationId endpoint
 */
const integrationIdParamsSchema = z.object({
  integrationId: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List integration logs query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with integration-log-specific filters
 */
const listIntegrationLogsQuerySchema = listQuerySchema.extend({
  integration_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: IntegrationStatusEnum.optional(),
  search: z.string().trim().optional()
});

const replayIntegrationLogSchema = z.object({
  notes: z.string().trim().max(10000).optional().nullable()
});

module.exports = {
  integrationLogIdParamsSchema,
  integrationIdParamsSchema,
  listIntegrationLogsQuerySchema,
  replayIntegrationLogSchema,
  IntegrationStatusEnum
};
