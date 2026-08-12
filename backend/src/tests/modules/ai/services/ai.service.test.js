jest.mock('@lib/ai', () => ({
  createAiProvider: jest.fn(),
  runTask: jest.fn(),
  getAiTask: jest.fn(),
  listAiTaskKeys: jest.fn(() => ['speech_format']),
}));

const { createAiProvider, runTask } = require('@lib/ai');
const aiService = require('@services/ai/ai.service');
const { HttpError } = require('@lib/errors');

describe('ai.service', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  test('returns status from the factory provider probe', async () => {
    createAiProvider.mockReturnValue({
      name: 'ollama',
      probe: async () => true,
    });

    const status = await aiService.getAiStatus();
    expect(status).toEqual({
      enabled: true,
      provider: 'ollama',
      model: expect.any(String),
      ready: true,
    });
    expect(createAiProvider).toHaveBeenCalled();
  });

  test('runAiTask returns the task result', async () => {
    runTask.mockResolvedValue({
      task_key: 'speech_format',
      output: { formatted_text: '1225', mode: 'digits' },
      model: 'llama3.2:3b',
      provider: 'ollama',
      degraded: false,
    });

    const result = await aiService.runAiTask('speech_format', {
      transcript: 'one two two five',
      mode: 'digits',
    });
    expect(result.output.formatted_text).toBe('1225');
    expect(runTask).toHaveBeenCalledWith(
      'speech_format',
      { transcript: 'one two two five', mode: 'digits' },
      {}
    );
  });

  test('unknown tasks throw 404', async () => {
    runTask.mockResolvedValue(null);
    await expect(aiService.runAiTask('missing', {})).rejects.toBeInstanceOf(HttpError);
    try {
      await aiService.runAiTask('missing', {});
    } catch (error) {
      expect(error.statusCode).toBe(404);
      expect(error.messageKey).toBe('errors.ai.task_not_found');
    }
  });

  test('does not import the Ollama adapter', () => {
    const serviceSource = require('fs').readFileSync(
      require('path').join(
        __dirname,
        '../../../../modules/ai/services/ai.service.js'
      ),
      'utf8'
    );
    expect(serviceSource).not.toMatch(/providers\/ollama/);
  });
});
