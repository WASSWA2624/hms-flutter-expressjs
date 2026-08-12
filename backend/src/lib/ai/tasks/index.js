/**
 * AI task registry
 *
 * Add a new capability by exporting a task object and registering it here.
 * HTTP routes stay generic: POST /api/v1/ai/tasks/:task_key
 */

const { speechFormatTask } = require('./speech-format');

const TASKS = Object.freeze({
  [speechFormatTask.key]: speechFormatTask,
});

const getAiTask = (taskKey) => TASKS[String(taskKey || '').trim()] || null;

const listAiTaskKeys = () => Object.keys(TASKS);

module.exports = {
  TASKS,
  getAiTask,
  listAiTaskKeys,
};
