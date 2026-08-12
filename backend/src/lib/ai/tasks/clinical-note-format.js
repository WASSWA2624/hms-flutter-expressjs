/**
 * clinical_note_format task
 *
 * Rewrites a clinical note draft into professional medical language.
 * Format/clarity only — does not invent clinical facts.
 */

const { z } = require('zod');
const {
  AI_MAX_INPUT_CHARS,
  AI_CLINICAL_NOTE_FORMAT_TIMEOUT_MS,
} = require('@config/env');

const stripClinicalNoteCompletion = (raw) => {
  let text = String(raw || '').trim();
  if (!text) {
    return '';
  }
  text = text.replace(/^```(?:markdown|md|text|json)?\s*/i, '').replace(/\s*```$/i, '').trim();
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
  // Drop a single leading label line the model sometimes adds.
  text = text
    .replace(
      /^(?:here(?:'s| is)|formatted(?: clinical)? note|clinical note)\s*:\s*/i,
      ''
    )
    .trim();
  return text;
};

const clinicalNoteFormatTask = {
  key: 'clinical_note_format',
  failOpen: true,
  get timeoutMs() {
    return AI_CLINICAL_NOTE_FORMAT_TIMEOUT_MS;
  },
  inputSchema: z.object({
    text: z.string().trim().min(1).max(AI_MAX_INPUT_CHARS),
    locale: z.string().trim().min(1).max(32).optional().default('en'),
    hint: z.string().trim().max(200).optional(),
  }),
  systemPrompt: [
    'You rewrite clinician draft notes into clear, professional medical language.',
    'Preserve every clinical fact, symptom, finding, medication, dose, time, identifier, and question exactly as stated.',
    'Do not invent diagnoses, assessments, plans, medications, vitals, identifiers, imaging orders, or missing details.',
    'Do not add template headers, placeholders, Patient ID, Date, or sections that were not in the draft.',
    'Improve grammar, punctuation, spelling, and clinical phrasing only. Keep the rewrite concise.',
    'You may correct only unambiguous dictation/typo errors when the intended clinical term is obvious.',
    'Use concise clinical prose with paragraph breaks when helpful. Prefer plain text.',
    'Do not wrap the answer in markdown fences, quotes, labels, or explanations.',
    'If the note is already professional, return it unchanged.',
    'If you cannot improve it confidently, return the input text unchanged.',
  ].join(' '),
  buildUserPrompt: (input) => {
    const lines = [`locale: ${input.locale || 'en'}`];
    if (input.hint) {
      lines.push(`hint: ${input.hint}`);
    }
    lines.push('clinical_note:');
    lines.push(input.text);
    return lines.join('\n');
  },
  outputParser: (completionText, input) => {
    const formatted = stripClinicalNoteCompletion(completionText);
    return {
      formatted_text: formatted || input.text,
    };
  },
  failOpenOutput: (input) => ({
    formatted_text: input.text,
  }),
};

module.exports = {
  clinicalNoteFormatTask,
};
