/**
 * AI HTTP validation schemas
 *
 * @description Zod validation schemas for AI utility endpoints.
 */

const { z } = require('zod');
const { listAiTaskKeys } = require('@lib/ai');

const aiTaskKeyParamsSchema = z.object({
  task_key: z
    .string()
    .trim()
    .min(1)
    .max(80)
    .regex(/^[a-z][a-z0-9_]*$/, 'task_key must be snake_case'),
});

const aiTaskBodySchema = z.object({}).passthrough();

const knownAiTaskKeys = listAiTaskKeys();

module.exports = {
  aiTaskKeyParamsSchema,
  aiTaskBodySchema,
  knownAiTaskKeys,
};
