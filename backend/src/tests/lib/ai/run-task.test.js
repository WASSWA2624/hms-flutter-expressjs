const { createAiProvider } = require('@lib/ai/factory');
const { runTask } = require('@lib/ai/run-task');
const { getAiTask } = require('@lib/ai/tasks');

describe('AI factory and runTask', () => {
  test('completes speech_format through a mocked provider', async () => {
    const provider = createAiProvider({
      name: 'mock-primary',
      complete: async () => ({
        text: 'name@hospital.com',
        model: 'mock-primary-model',
        provider: 'mock-primary',
      }),
    });

    const result = await runTask(
      'speech_format',
      {
        transcript: 'name at hospital dot com',
        mode: 'email',
      },
      { provider }
    );

    expect(result.degraded).toBe(false);
    expect(result.provider).toBe('mock-primary');
    expect(result.output).toEqual({
      formatted_text: 'name@hospital.com',
      mode: 'email',
    });
  });

  test('completes clinical_note_format through a mocked provider', async () => {
    const provider = createAiProvider({
      name: 'mock-clinical',
      complete: async ({ timeoutMs }) => {
        expect(timeoutMs).toBeGreaterThanOrEqual(60000);
        return {
          text: 'The patient reports fever since yesterday.',
          model: 'mock-clinical-model',
          provider: 'mock-clinical',
        };
      },
    });

    const result = await runTask(
      'clinical_note_format',
      {
        text: 'pt c/o fever since yesterday',
      },
      { provider }
    );

    expect(result.degraded).toBe(false);
    expect(result.provider).toBe('mock-clinical');
    expect(result.output).toEqual({
      formatted_text: 'The patient reports fever since yesterday.',
    });
    expect(getAiTask('clinical_note_format')).not.toBeNull();
  });

  test('a second mocked provider can satisfy speech_format without route changes', async () => {
    const provider = createAiProvider({
      name: 'mock-other',
      complete: async () => ({
        text: '2024-03-15',
        model: 'other-large',
        provider: 'mock-other',
      }),
    });

    const result = await runTask(
      'speech_format',
      {
        transcript: 'march fifteenth twenty twenty four',
        mode: 'date',
      },
      { provider }
    );

    expect(result.provider).toBe('mock-other');
    expect(result.model).toBe('other-large');
    expect(result.output.formatted_text).toBe('2024-03-15');
  });

  test('returns null for unknown tasks', async () => {
    const result = await runTask('not_a_task', { transcript: 'x', mode: 'text' });
    expect(result).toBeNull();
    expect(getAiTask('not_a_task')).toBeNull();
  });

  test('fails open on empty completion', async () => {
    const result = await runTask(
      'speech_format',
      { transcript: 'hello comma world', mode: 'text' },
      {
        provider: {
          name: 'empty',
          complete: async () => ({ text: '   ', model: 'empty', provider: 'empty' }),
        },
      }
    );

    expect(result.degraded).toBe(true);
    expect(result.model).toBeNull();
    expect(result.output.formatted_text).toBe('hello comma world');
  });

  test('fails open when the caller aborts the request', async () => {
    const abort = new AbortController();
    abort.abort();
    const complete = jest.fn(async ({ signal }) => {
      if (signal?.aborted) {
        const error = new Error('aborted');
        error.name = 'AbortError';
        throw error;
      }
      return { text: 'should not run', model: 'mock', provider: 'mock' };
    });

    const result = await runTask(
      'clinical_note_format',
      { text: 'pt febrile' },
      { provider: { name: 'mock', complete }, signal: abort.signal }
    );

    expect(result.degraded).toBe(true);
    expect(result.output.formatted_text).toBe('pt febrile');
  });

  test('fails open when the provider throws', async () => {
    const result = await runTask(
      'speech_format',
      { transcript: 'one two three', mode: 'digits' },
      {
        provider: {
          name: 'down',
          complete: async () => {
            throw new Error('ECONNREFUSED');
          },
        },
      }
    );

    expect(result.degraded).toBe(true);
    expect(result.output.formatted_text).toBe('one two three');
  });

  test('rejects unknown providers on the factory allowlist', () => {
    expect(() => createAiProvider({ provider: 'not-a-provider' })).toThrow(
      'Unsupported AI provider'
    );
  });

  test('fails open when AI_ENABLED is false without calling the provider', async () => {
    const complete = jest.fn();
    let result;

    await jest.isolateModulesAsync(async () => {
      const env = require('@config/env');
      env.setEnvForTests({
        JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
        DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
        CORS_ORIGINS: 'http://localhost:3000',
        NODE_ENV: 'test',
        AI_ENABLED: 'false',
      });
      const { runTask: runDisabledTask } = require('@lib/ai/run-task');
      result = await runDisabledTask(
        'speech_format',
        { transcript: 'keep me', mode: 'text' },
        { provider: { name: 'unused', complete } }
      );
    });

    expect(result.degraded).toBe(true);
    expect(result.output.formatted_text).toBe('keep me');
    expect(complete).not.toHaveBeenCalled();
    delete process.env.AI_ENABLED;
  });
});
