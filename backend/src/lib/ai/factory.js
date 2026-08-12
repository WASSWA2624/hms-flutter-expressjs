/**
 * AI provider factory
 *
 * Provider selection is configuration-driven (AI_PROVIDER).
 */

const { AI_PROVIDER } = require('@config/env');
const { AI_PROVIDER_ALLOWLIST } = require('@config/constants');
const { createOllamaProvider } = require('@lib/ai/providers/ollama');

const PROVIDER_FACTORIES = Object.freeze({
  ollama: createOllamaProvider,
});

const createAiProvider = (overrides = {}) => {
  if (typeof overrides.complete === 'function') {
    return {
      name: overrides.name || 'test',
      probe:
        overrides.probe ||
        (async () => true),
      complete: overrides.complete,
    };
  }

  const providerName = String(overrides.provider || AI_PROVIDER)
    .trim()
    .toLowerCase();
  const factory = PROVIDER_FACTORIES[providerName];
  if (!factory || !AI_PROVIDER_ALLOWLIST.includes(providerName)) {
    throw new Error(
      `Unsupported AI provider: ${providerName}. ` +
        `Supported providers: ${AI_PROVIDER_ALLOWLIST.join(', ')}`
    );
  }

  return factory(overrides);
};

module.exports = {
  createAiProvider,
  PROVIDER_FACTORIES,
};
