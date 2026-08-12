/**
 * speech_format task
 *
 * Rewrites a speech-to-text transcript into a field's expected format.
 */

const { z } = require('zod');
const { AI_MAX_INPUT_CHARS } = require('@config/env');

const SPEECH_FORMAT_MODES = Object.freeze([
  'text',
  'email',
  'digits',
  'decimal',
  'date',
  'time',
  'phone',
  'currency',
]);

const MODE_RULES = {
  text: 'Punctuation words become marks. Spoken cardinals become digits. Preserve meaning and paragraph breaks.',
  email: 'Convert spoken email tokens (at, dot) into a compact address with no spaces.',
  digits: 'Return an integer digit string only.',
  decimal: 'Return a numeric string using a period as the decimal separator.',
  currency: 'Return a numeric amount string using a period as the decimal separator. Do not invent currency codes.',
  phone: 'Return the digit sequence only. Do not invent a country code.',
  date: 'If a full date is present, return ISO YYYY-MM-DD. Otherwise return the clearest partial the utterance supports.',
  time: 'If a time is present, return HH:mm in 24-hour form.',
};

const stripCompletion = (raw) => {
  let text = String(raw || '').trim();
  if (!text) {
    return '';
  }
  text = text.replace(/^```(?:json|text)?\s*/i, '').replace(/\s*```$/i, '').trim();
  if (
    (text.startsWith('"') && text.endsWith('"')) ||
    (text.startsWith("'") && text.endsWith("'"))
  ) {
    text = text.slice(1, -1).trim();
  }
  try {
    const parsed = JSON.parse(text);
    if (parsed && typeof parsed === 'object' && parsed.formatted_text != null) {
      return String(parsed.formatted_text).trim();
    }
  } catch (_error) {
    // Plain text completion.
  }
  const firstLine = text.split(/\r?\n/).find((line) => line.trim());
  return String(firstLine || text).trim();
};

const speechFormatTask = {
  key: 'speech_format',
  failOpen: true,
  inputSchema: z.object({
    transcript: z
      .string()
      .trim()
      .min(1)
      .max(AI_MAX_INPUT_CHARS),
    mode: z.enum(SPEECH_FORMAT_MODES),
    locale: z.string().trim().min(1).max(32).optional().default('en'),
    hint: z.string().trim().max(200).optional(),
  }),
  systemPrompt: [
    'You rewrite speech-to-text transcripts into the exact field format requested.',
    'Output only the formatted value. No markdown, labels, quotes, or explanation.',
    'Do not invent clinical facts, diagnoses, medications, identifiers, or missing values.',
    'If the utterance is already correctly formatted, return it unchanged.',
    'If you cannot format it confidently, return the input transcript unchanged.',
  ].join(' '),
  buildUserPrompt: (input) => {
    const lines = [
      `mode: ${input.mode}`,
      `locale: ${input.locale || 'en'}`,
      `mode_rules: ${MODE_RULES[input.mode]}`,
    ];
    if (input.hint) {
      lines.push(`hint: ${input.hint}`);
    }
    lines.push('transcript:');
    lines.push(input.transcript);
    return lines.join('\n');
  },
  outputParser: (completionText, input) => {
    const formatted = stripCompletion(completionText);
    return {
      formatted_text: formatted || input.transcript,
      mode: input.mode,
    };
  },
  failOpenOutput: (input) => ({
    formatted_text: input.transcript,
    mode: input.mode,
  }),
};

module.exports = {
  speechFormatTask,
  SPEECH_FORMAT_MODES,
};
