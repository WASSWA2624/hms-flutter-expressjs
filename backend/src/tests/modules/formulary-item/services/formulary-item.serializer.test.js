const {
  mapFormularyItemRecord,
  mapFormularyDrugRecord,
} = require('@services/formulary-item/formulary-item.serializer');

describe('Formulary Item Serializer', () => {
  describe('mapFormularyDrugRecord', () => {
    it('maps drug display fields', () => {
      const result = mapFormularyDrugRecord({
        id: '550e8400-e29b-41d4-a716-446655440000',
        human_friendly_id: 'DRG-ACV400',
        name: 'Acyclovir',
        strength: '400 mg',
        form: 'Tablet',
        code: 'ACV400',
      });

      expect(result).toMatchObject({
        id: 'DRG-ACV400',
        display_id: 'DRG-ACV400',
        name: 'Acyclovir',
        code: 'ACV400',
        drug_display_name: 'Acyclovir | 400 mg | Tablet',
      });
    });
  });

  describe('mapFormularyItemRecord', () => {
    it('maps nested drug for list responses', () => {
      const result = mapFormularyItemRecord({
        id: '550e8400-e29b-41d4-a716-446655440001',
        human_friendly_id: 'FRM-78F1DB9675',
        drug_id: '550e8400-e29b-41d4-a716-446655440000',
        is_active: true,
        created_at: new Date('2026-01-01T00:00:00.000Z'),
        updated_at: new Date('2026-01-02T00:00:00.000Z'),
        drug: {
          id: '550e8400-e29b-41d4-a716-446655440000',
          human_friendly_id: 'DRG-ACV400',
          name: 'Acyclovir',
          strength: '400 mg',
          form: 'Tablet',
          code: 'ACV400',
        },
      });

      expect(result).toMatchObject({
        id: 'FRM-78F1DB9675',
        display_id: 'FRM-78F1DB9675',
        drug_id: 'DRG-ACV400',
        drug_display_name: 'Acyclovir | 400 mg | Tablet',
        drug_code: 'ACV400',
        is_active: true,
        drug: {
          name: 'Acyclovir',
          drug_display_name: 'Acyclovir | 400 mg | Tablet',
        },
      });
    });
  });
});
