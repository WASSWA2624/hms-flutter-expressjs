const { EventEmitter } = require('events');
const controller = require('../../../../modules/ai/controllers/ai.controller');
const service = require('../../../../modules/ai/services/ai.service');
const { sendSuccess } = require('@lib/response');

jest.mock('../../../../modules/ai/services/ai.service');
jest.mock('@lib/response');

describe('ai controller', () => {
  let req;
  let res;

  beforeEach(() => {
    req = { params: {}, body: {}, user: { id: 'user-1' }, signal: AbortSignal.abort() };
    res = Object.assign(new EventEmitter(), {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      writableEnded: false,
    });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  test('returns AI status', async () => {
    const data = { enabled: true, provider: 'ollama', model: 'llama3.2:3b', ready: false };
    service.getAiStatus.mockResolvedValue(data);

    await controller.getAiStatus(req, res);

    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.ai.status.success',
      data
    );
  });

  test('runs a named task', async () => {
    req.params = { task_key: 'speech_format' };
    req.body = { transcript: 'hello', mode: 'text' };
    const data = {
      task_key: 'speech_format',
      output: { formatted_text: 'hello', mode: 'text' },
      degraded: true,
      model: null,
      provider: null,
    };
    service.runAiTask.mockResolvedValue(data);

    await controller.runAiTask(req, res);

    const options = service.runAiTask.mock.calls[0][2];
    expect(service.runAiTask).toHaveBeenCalledWith(
      'speech_format',
      req.body,
      options
    );
    expect(options.signal).toBeInstanceOf(AbortSignal);
    expect(options.signal.aborted).toBe(false);
    expect(req.signal.aborted).toBe(true);
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.ai.task.success',
      data
    );
  });
});
