/**
 * Ollama AI provider adapter
 *
 * Talks to a local or remote Ollama host. Host and model come from env.
 */

const {
  AI_BASE_URL,
  AI_MODEL,
  AI_TIMEOUT_MS,
  AI_TEMPERATURE,
} = require('@config/env');
const { AI_STATUS_PROBE_TIMEOUT_MS } = require('@config/constants');
const { logger } = require('@lib/logging');

const PROVIDER_NAME = 'ollama';

const stripDataUrl = (value) => {
  const text = String(value || '').trim();
  if (!text) {
    return '';
  }
  const match = text.match(/^data:image\/[a-zA-Z0-9.+-]+;base64,(.+)$/s);
  return String(match ? match[1] : text).replace(/\s+/g, '');
};

const normalizeOllamaImages = (images) => {
  if (!Array.isArray(images)) {
    return [];
  }
  return images
    .map((item) => stripDataUrl(item))
    .filter((item) => item.length > 0);
};

const normalizeBaseUrl = (value) =>
  String(value || '').trim().replace(/\/+$/, '');

const combineSignals = (timeoutMs, externalSignal) => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  if (typeof timer.unref === 'function') {
    timer.unref();
  }

  // Do not pass Node's req.signal here. It aborts after the body is read.
  const onExternalAbort = () => controller.abort();
  if (externalSignal) {
    if (externalSignal.aborted) {
      controller.abort();
    } else {
      externalSignal.addEventListener('abort', onExternalAbort, { once: true });
    }
  }

  return {
    signal: controller.signal,
    cleanup: () => {
      clearTimeout(timer);
      if (externalSignal) {
        externalSignal.removeEventListener('abort', onExternalAbort);
      }
    },
  };
};

const readJson = async (response) => {
  const textPayload = await response.text();
  if (!textPayload) {
    return null;
  }
  try {
    return JSON.parse(textPayload);
  } catch (_error) {
    return null;
  }
};

const createOllamaProvider = (overrides = {}) => {
  const baseUrl = normalizeBaseUrl(overrides.baseUrl || AI_BASE_URL);
  const defaultModel = String(overrides.model || AI_MODEL).trim();
  const defaultTimeoutMs = Number(overrides.timeoutMs || AI_TIMEOUT_MS);
  const defaultTemperature = Number(
    overrides.temperature === undefined ? AI_TEMPERATURE : overrides.temperature
  );

  const request = async (path, { method = 'GET', body, timeoutMs, signal } = {}) => {
    const { signal: abortSignal, cleanup } = combineSignals(
      timeoutMs || defaultTimeoutMs,
      signal
    );

    try {
      const response = await fetch(`${baseUrl}${path}`, {
        method,
        headers: body
          ? { 'Content-Type': 'application/json', Accept: 'application/json' }
          : { Accept: 'application/json' },
        body: body ? JSON.stringify(body) : undefined,
        signal: abortSignal,
      });
      const payload = await readJson(response);
      if (!response.ok) {
        throw new Error(`Ollama HTTP ${response.status}`);
      }
      return payload;
    } finally {
      cleanup();
    }
  };

  return {
    name: PROVIDER_NAME,
    async probe() {
      try {
        await request('/api/tags', { timeoutMs: AI_STATUS_PROBE_TIMEOUT_MS });
        return true;
      } catch (_error) {
        return false;
      }
    },
    async complete({
      system,
      user,
      images,
      model,
      temperature,
      timeoutMs,
      signal,
    } = {}) {
      const resolvedModel = String(model || defaultModel).trim();
      const userMessage = {
        role: 'user',
        content: String(user || ''),
      };
      const normalizedImages = normalizeOllamaImages(images);
      if (normalizedImages.length > 0) {
        userMessage.images = normalizedImages;
      }

      const payload = await request('/api/chat', {
        method: 'POST',
        timeoutMs,
        signal,
        body: {
          model: resolvedModel,
          stream: false,
          messages: [
            { role: 'system', content: String(system || '') },
            userMessage,
          ],
          options: {
            temperature:
              temperature === undefined ? defaultTemperature : Number(temperature),
          },
        },
      });

      const text = String(payload?.message?.content || '').trim();
      if (!text) {
        logger.warn('AI provider returned an empty completion');
        throw new Error('empty_completion');
      }

      return {
        text,
        model: String(payload?.model || resolvedModel),
        provider: PROVIDER_NAME,
      };
    },
  };
};

module.exports = {
  createOllamaProvider,
};
