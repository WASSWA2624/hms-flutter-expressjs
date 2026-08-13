/**
 * AI utilities controller
 *
 * @description Request handlers for AI utility endpoints.
 */

const aiService = require('@services/ai/ai.service');
const { asyncHandler } = require('@lib/async');
const { createClientDisconnectSignal } = require('@lib/ai/client-disconnect-signal');
const { sendSuccess } = require('@lib/response');

const getAiStatus = asyncHandler(async (req, res) => {
  const result = await aiService.getAiStatus();
  return sendSuccess(res, 200, 'messages.ai.status.success', result);
});

const runAiTask = asyncHandler(async (req, res) => {
  const result = await aiService.runAiTask(req.params.task_key, req.body, {
    signal: createClientDisconnectSignal(req, res),
  });
  return sendSuccess(res, 200, 'messages.ai.task.success', result);
});

module.exports = {
  getAiStatus,
  runAiTask,
};
