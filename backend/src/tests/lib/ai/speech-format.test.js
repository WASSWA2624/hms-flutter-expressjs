const { speechFormatTask } = require('@lib/ai/tasks/speech-format');

const parse = (completion, input) => speechFormatTask.outputParser(completion, input);

describe('speech_format output parser', () => {
  const fixtures = [
    ['text', 'hello, world', 'hello, world'],
    ['email', 'name@hospital.com', 'name@hospital.com'],
    ['digits', '1225', '1225'],
    ['decimal', '12.5', '12.5'],
    ['currency', '1500.00', '1500.00'],
    ['phone', '0772123456', '0772123456'],
    ['date', '2024-03-15', '2024-03-15'],
    ['time', '14:30', '14:30'],
  ];

  test.each(fixtures)('keeps format-only %s output', (mode, completion, expected) => {
    const input = { transcript: 'raw utterance', mode };
    expect(parse(completion, input)).toEqual({
      formatted_text: expected,
      mode,
    });
  });

  test('strips markdown fences and explanations', () => {
    const input = { transcript: 'name at hospital dot com', mode: 'email' };
    expect(
      parse('```\nname@hospital.com\n```\nThis is the email.', input).formatted_text
    ).toBe('name@hospital.com');
  });

  test('does not invent values when completion is empty', () => {
    const input = { transcript: 'patient has fever', mode: 'text' };
    expect(parse('   ', input).formatted_text).toBe('patient has fever');
  });
});
