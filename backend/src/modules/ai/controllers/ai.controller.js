/**
 * AI utilities controller
 *
 * @description Request handlers for AI utility endpoints.
 */

const aiService = require('@services/ai/ai.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');

const getAiStatus = asyncHandler(async (req, res) => {
  const result = await aiService.getAiStatus();
  return sendSuccess(res, 200, 'messages.ai.status.success', result);
});

const runAiTask = asyncHandler(async (req, res) => {
  // Send headers before the model call so browser XHR connect-timeout
  // does not abort while Ollama is still generating.
  if (typeof res.setHeader === 'function') {
    res.setHeader('X-Accel-Buffering', 'no');
  }
  if (typeof res.flushHeaders === 'function') {
    res.flushHeaders();
  }

  const result = await aiService.runAiTask(req.params.task_key, req.body, {
    signal: req.signal,
  });
  return sendSuccess(res, 200, 'messages.ai.task.success', result);
});

module.exports = {
  getAiStatus,
  runAiTask,
};
