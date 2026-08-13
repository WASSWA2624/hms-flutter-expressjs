const {
  drugPackExtractTask,
} = require('@lib/ai/tasks/drug-pack-extract');

const parse = (completion, input = { images: [], ocr_text: 'Paracetamol' }) =>
  drugPackExtractTask.outputParser(completion, input);

describe('drug_pack_extract', () => {
  test('input schema requires images or ocr_text', () => {
    expect(() => drugPackExtractTask.inputSchema.parse({})).toThrow();
    expect(() =>
      drugPackExtractTask.inputSchema.parse({ images: [], ocr_text: '' })
    ).toThrow();
    expect(
      drugPackExtractTask.inputSchema.parse({
        ocr_text: '  Paracetamol Tablets 500mg  ',
      })
    ).toEqual({
      images: [],
      ocr_text: 'Paracetamol Tablets 500mg',
      locale: 'en',
    });
  });

  test('accepts a pack photo payload', () => {
    const data = 'A'.repeat(40);
    const parsed = drugPackExtractTask.inputSchema.parse({
      images: [
        {
          mime_type: 'image/jpg',
          data: `data:image/jpeg;base64,${data}`,
        },
      ],
      barcode: '8901234567890',
    });
    expect(parsed.images[0].mime_type).toBe('image/jpeg');
    expect(parsed.images[0].data).toBe(data);
    expect(parsed.barcode).toBe('8901234567890');
  });

  test('parses JSON completion into catalog-shaped fields', () => {
    expect(
      parse(
        JSON.stringify({
          generic_name: 'Paracetamol',
          brand_name: 'AGOMO',
          form: 'tablets',
          strength: '500mg',
          code: null,
          batch_number: 'LOT-9',
          manufactured_at: '2025-01',
          expiry_date: '12/2027',
          barcode: '8901234567890',
          raw_text: 'AGOMO\nParacetamol Tablets 500 mg',
        })
      )
    ).toEqual({
      generic_name: 'Paracetamol',
      brand_name: 'AGOMO',
      form: 'Tablet',
      strength: '500 mg',
      code: null,
      batch_number: 'LOT-9',
      manufactured_at: '2025-01-01',
      expiry_date: '2027-12-01',
      barcode: '8901234567890',
      raw_text: 'AGOMO\nParacetamol Tablets 500 mg',
    });
  });

  test('strips markdown fences and unknown placeholders', () => {
    const result = parse(
      '```json\n{"generic_name":"Amoxicillin","brand_name":"unknown","form":"caps","strength":"n/a"}\n```'
    );
    expect(result.generic_name).toBe('Amoxicillin');
    expect(result.brand_name).toBeNull();
    expect(result.form).toBe('Capsule');
    expect(result.strength).toBeNull();
  });

  test('does not invent fields when completion is empty', () => {
    const input = { ocr_text: 'keep me', barcode: '123' };
    expect(parse('   ', input)).toEqual({
      generic_name: null,
      brand_name: null,
      form: null,
      strength: null,
      code: null,
      batch_number: null,
      manufactured_at: null,
      expiry_date: null,
      barcode: '123',
      raw_text: 'keep me',
    });
    expect(drugPackExtractTask.failOpenOutput(input)).toEqual({
      generic_name: null,
      brand_name: null,
      form: null,
      strength: null,
      code: null,
      batch_number: null,
      manufactured_at: null,
      expiry_date: null,
      barcode: '123',
      raw_text: 'keep me',
    });
  });

  test('buildImages returns stripped base64 only', () => {
    const images = drugPackExtractTask.buildImages({
      images: [
        { mime_type: 'image/png', data: 'data:image/png;base64,abcd1234' },
      ],
    });
    expect(images).toEqual(['abcd1234']);
  });
});
