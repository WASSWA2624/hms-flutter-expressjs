const {
  aiTaskKeyParamsSchema,
  aiTaskBodySchema,
} = require('@validations/ai/ai.schema');
const {
  clinicalNoteFormatTask,
} = require('@lib/ai/tasks/clinical-note-format');
const {
  drugPackExtractTask,
} = require('@lib/ai/tasks/drug-pack-extract');
const { speechFormatTask } = require('@lib/ai/tasks/speech-format');

describe('ai schemas', () => {
  test('accepts snake_case task keys', () => {
    expect(aiTaskKeyParamsSchema.parse({ task_key: 'speech_format' })).toEqual({
      task_key: 'speech_format',
    });
    expect(
      aiTaskKeyParamsSchema.parse({ task_key: 'clinical_note_format' })
    ).toEqual({
      task_key: 'clinical_note_format',
    });
    expect(
      aiTaskKeyParamsSchema.parse({ task_key: 'drug_pack_extract' })
    ).toEqual({
      task_key: 'drug_pack_extract',
    });
  });

  test('rejects invalid task keys', () => {
    expect(() => aiTaskKeyParamsSchema.parse({ task_key: 'Speech-Format' })).toThrow();
  });

  test('speech_format body requires transcript and mode', () => {
    expect(() => speechFormatTask.inputSchema.parse({})).toThrow();
    expect(
      speechFormatTask.inputSchema.parse({
        transcript: '  hello  ',
        mode: 'text',
      })
    ).toEqual({
      transcript: 'hello',
      mode: 'text',
      locale: 'en',
    });
  });

  test('clinical_note_format body requires text', () => {
    expect(() => clinicalNoteFormatTask.inputSchema.parse({})).toThrow();
    expect(
      clinicalNoteFormatTask.inputSchema.parse({
        text: '  patient febrile  ',
        hint: 'SOAP style',
      })
    ).toEqual({
      text: 'patient febrile',
      locale: 'en',
      hint: 'SOAP style',
    });
  });

  test('drug_pack_extract body requires images or ocr_text', () => {
    expect(() => drugPackExtractTask.inputSchema.parse({})).toThrow();
    expect(
      drugPackExtractTask.inputSchema.parse({
        ocr_text: '  Amoxil capsules  ',
        barcode: '8901',
      })
    ).toEqual({
      images: [],
      ocr_text: 'Amoxil capsules',
      barcode: '8901',
      locale: 'en',
    });
  });

  test('task body schema allows task-specific fields', () => {
    expect(
      aiTaskBodySchema.parse({
        transcript: 'one two',
        mode: 'digits',
      })
    ).toEqual({
      transcript: 'one two',
      mode: 'digits',
    });
  });
});
