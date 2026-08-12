const {
  aiTaskKeyParamsSchema,
  aiTaskBodySchema,
} = require('@validations/ai/ai.schema');
const {
  clinicalNoteFormatTask,
} = require('@lib/ai/tasks/clinical-note-format');
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
