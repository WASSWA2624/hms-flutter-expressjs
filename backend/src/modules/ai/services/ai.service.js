/**
 * AI utilities service
 *
 * @module modules/ai/services
 * @description Provider-agnostic AI task execution. Does not import adapters.
 */

const { AI_ENABLED, AI_PROVIDER, AI_MODEL } = require('@config/env');
const { createAiProvider, runTask } = require('@lib/ai');
const { HttpError } = require('@lib/errors');

const getAiStatus = async () => {
  const enabled = Boolean(AI_ENABLED);
  if (!enabled) {
    return {
      enabled: false,
      provider: AI_PROVIDER,
      model: AI_MODEL,
      ready: false,
    };
  }

  const provider = createAiProvider();
  const ready = await provider.probe();
  return {
    enabled: true,
    provider: provider.name || AI_PROVIDER,
    model: AI_MODEL,
    ready: Boolean(ready),
  };
};

const runAiTask = async (taskKey, body, options = {}) => {
  const result = await runTask(taskKey, body, options);
  if (!result) {
    throw new HttpError('errors.ai.task_not_found', 404);
  }
  return result;
};

module.exports = {
  getAiStatus,
  runAiTask,
};
