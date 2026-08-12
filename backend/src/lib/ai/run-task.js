/**
 * Run a named AI task through the configured provider.
 */

const {
  AI_ENABLED,
  AI_MODEL,
  AI_TEMPERATURE,
  AI_TIMEOUT_MS,
  AI_CLINICAL_NOTE_FORMAT_TIMEOUT_MS,
} = require('@config/env');
const { createAiProvider } = require('@lib/ai/factory');
const { getAiTask } = require('@lib/ai/tasks');
const { logger } = require('@lib/logging');

const degradedResult = (task, input) => ({
  task_key: task.key,
  output: task.failOpenOutput(input),
  model: null,
  provider: null,
  degraded: true,
});

const resolveTaskTimeoutMs = (task) => {
  if (task.key === 'clinical_note_format') {
    return AI_CLINICAL_NOTE_FORMAT_TIMEOUT_MS;
  }
  if (Number(task.timeoutMs) > 0) {
    return Number(task.timeoutMs);
  }
  return AI_TIMEOUT_MS;
};

const runTask = async (taskKey, rawInput, { signal, provider } = {}) => {
  const task = getAiTask(taskKey);
  if (!task) {
    return null;
  }

  const input = task.inputSchema.parse(rawInput || {});
  if (!AI_ENABLED) {
    return degradedResult(task, input);
  }

  const activeProvider = provider || createAiProvider();
  const startedAt = Date.now();

  try {
    const completion = await activeProvider.complete({
      system: task.systemPrompt,
      user: task.buildUserPrompt(input),
      model: AI_MODEL,
      temperature: AI_TEMPERATURE,
      timeoutMs: resolveTaskTimeoutMs(task),
      signal,
    });
    const text = String(completion?.text || '').trim();
    if (!text) {
      logger.warn('AI task empty completion', {
        task_key: task.key,
        elapsed_ms: Date.now() - startedAt,
      });
      return degradedResult(task, input);
    }

    logger.info('AI task completed', {
      task_key: task.key,
      elapsed_ms: Date.now() - startedAt,
      degraded: false,
    });
    return {
      task_key: task.key,
      output: task.outputParser(text, input),
      model: completion.model || AI_MODEL,
      provider: completion.provider || activeProvider.name,
      degraded: false,
    };
  } catch (error) {
    logger.warn('AI task failed open', {
      task_key: task.key,
      elapsed_ms: Date.now() - startedAt,
      reason: error?.name === 'AbortError' ? 'timeout_or_cancelled' : 'provider_error',
    });
    return degradedResult(task, input);
  }
};

module.exports = {
  runTask,
};
