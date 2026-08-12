const {
  aiTaskKeyParamsSchema,
  aiTaskBodySchema,
} = require('@validations/ai/ai.schema');
const { speechFormatTask } = require('@lib/ai/tasks/speech-format');

describe('ai schemas', () => {
  test('accepts snake_case task keys', () => {
    expect(aiTaskKeyParamsSchema.parse({ task_key: 'speech_format' })).toEqual({
      task_key: 'speech_format',
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
