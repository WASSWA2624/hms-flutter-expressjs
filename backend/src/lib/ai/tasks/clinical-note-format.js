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
  // Drop scare-quotes around fragments. Keep contractions such as patient's.
  text = text.replace(
    /['\u2018\u2019]([^'\u2018\u2019\n]{1,80})['\u2018\u2019]/g,
    (full, inner) => {
      if (/\s/.test(inner) || /[.,;:!?]$/.test(String(inner).trim())) {
        return inner;
      }
      return full;
    }
  );
  return text;
};

const clinicalNoteFormatTask = {
  key: 'clinical_note_format',
  failOpen: true,
  temperature: 0.2,
  get timeoutMs() {
    return AI_CLINICAL_NOTE_FORMAT_TIMEOUT_MS;
  },
  inputSchema: z.object({
    text: z.string().trim().min(1).max(AI_MAX_INPUT_CHARS),
    locale: z.string().trim().min(1).max(32).optional().default('en'),
    hint: z.string().trim().max(200).optional(),
  }),
  systemPrompt: [
    'You are a clinical documentation editor. Rewrite the draft into clear professional medical prose.',
    'Output only the rewritten note. No title, markdown, JSON, labels, or explanation.',
    'Use complete sentences. Use a new paragraph when the draft moves between history, findings, and plan.',
    'Expand common abbreviations (pt, c/o, SOB) into clinical phrasing.',
    'Correct obvious speech-to-text errors when the intended term is clear (immortal accident → motor accident; reading through the mouth → bleeding from the mouth).',
    'Remove filler (um, okay, just, like). Do not wrap words or fragments in quotation marks.',
    'If a fragment has no clinical meaning, omit it. Do not quote it.',
    'Preserve every concrete symptom, finding, medication, dose, time, and identifier that is present.',
    'Do not invent diagnoses, assessments, plans, vitals, imaging, or words such as unremarkable.',
    'Do not add SOAP headings, Patient ID, Date, or placeholders unless they already appear in the draft.',
    'Example draft: pt c/o fever since yesterday reading through the mouth we will observe',
    'Example rewrite: The patient reports fever since yesterday and bleeding from the mouth. Observation is planned.',
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
