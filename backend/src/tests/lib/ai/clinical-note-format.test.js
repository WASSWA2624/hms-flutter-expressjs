const {
  clinicalNoteFormatTask,
} = require('@lib/ai/tasks/clinical-note-format');

const parse = (completion, input) =>
  clinicalNoteFormatTask.outputParser(completion, input);

describe('clinical_note_format', () => {
  test('input schema requires trimmed text', () => {
    expect(() => clinicalNoteFormatTask.inputSchema.parse({})).toThrow();
    expect(
      clinicalNoteFormatTask.inputSchema.parse({
        text: '  patient has fever  ',
      })
    ).toEqual({
      text: 'patient has fever',
      locale: 'en',
    });
  });

  test('preserves multi-paragraph professional output', () => {
    const input = {
      text: 'pt c/o fever since yesterday. gave panadol',
    };
    const completion = [
      'The patient reports fever since yesterday.',
      '',
      'Paracetamol was administered.',
    ].join('\n');
    expect(parse(completion, input)).toEqual({
      formatted_text: completion,
    });
  });

  test('strips scare-quotes around fragments', () => {
    const input = { text: 'he had an accident the complete about just okay' };
    expect(
      parse(
        "Patient reports an 'accident.' He states, 'the complete about just okay'.",
        input
      ).formatted_text
    ).toBe(
      'Patient reports an accident. He states, the complete about just okay.'
    );
    expect(
      parse("The patient's fever resolved.", input).formatted_text
    ).toBe("The patient's fever resolved.");
  });

  test('strips markdown fences and leading labels', () => {
    const input = { text: 'sob and chest pain' };
    expect(
      parse(
        '```\nFormatted clinical note:\nPatient reports shortness of breath and chest pain.\n```',
        input
      ).formatted_text
    ).toBe('Patient reports shortness of breath and chest pain.');
  });

  test('fail-open keeps original text when completion is empty', () => {
    const input = { text: 'patient has fever' };
    expect(parse('   ', input).formatted_text).toBe('patient has fever');
    expect(clinicalNoteFormatTask.failOpenOutput(input)).toEqual({
      formatted_text: 'patient has fever',
    });
  });
});
