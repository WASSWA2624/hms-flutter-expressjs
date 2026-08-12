const { createOllamaProvider } = require('@lib/ai/providers/ollama');

describe('ollama provider', () => {
  const originalFetch = global.fetch;

  beforeEach(() => {
    global.fetch = jest.fn();
  });

  afterEach(() => {
    global.fetch = originalFetch;
  });

  test('posts chat completions to the configured host', async () => {
    global.fetch.mockResolvedValue({
      ok: true,
      text: async () =>
        JSON.stringify({
          model: 'llama3.2:3b',
          message: { role: 'assistant', content: 'name@hospital.com' },
        }),
    });

    const provider = createOllamaProvider({
      baseUrl: 'http://127.0.0.1:11434',
      model: 'llama3.2:3b',
      timeoutMs: 8000,
    });
    const result = await provider.complete({
      system: 'format only',
      user: 'name at hospital dot com',
    });

    expect(result).toEqual({
      text: 'name@hospital.com',
      model: 'llama3.2:3b',
      provider: 'ollama',
    });
    expect(global.fetch).toHaveBeenCalledWith(
      'http://127.0.0.1:11434/api/chat',
      expect.objectContaining({
        method: 'POST',
      })
    );
    const body = JSON.parse(global.fetch.mock.calls[0][1].body);
    expect(body.stream).toBe(false);
    expect(body.model).toBe('llama3.2:3b');
    expect(JSON.stringify(body)).not.toMatch(/password|api_key/i);
  });

  test('probe returns false when the host is unreachable', async () => {
    global.fetch.mockRejectedValue(new Error('ECONNREFUSED'));
    const provider = createOllamaProvider({
      baseUrl: 'http://127.0.0.1:11434',
    });
    await expect(provider.probe()).resolves.toBe(false);
  });
});
