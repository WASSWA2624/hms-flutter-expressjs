const {
  inferDosageForm,
  inferStrength,
} = require('@lib/pharmacy/drug-import/drug-product-attributes');

describe('drug-product-attributes', () => {
  describe('inferDosageForm', () => {
    it.each([
      ['AZITHROMYCIN 500MG TABLET', null, 'Tablet'],
      ['CEFIXIME 400MG CAPSULE', null, 'Capsule'],
      ['RELCER GEL SYRUP 100ML', 'RELCER SYP', 'Syrup'],
      ['MENTHOXYL HERBAL COUGH LOZENGES', null, 'Lozenge'],
      ['FLUTICASONE PROPIONATE 50MCG', 'DALMAN NASAL SPRAY', 'Spray'],
      ['M.C.G Cream', 'M.C.G CREAM 15G', 'Cream'],
    ])('infers %s (%s) as %s', (name, brand, expected) => {
      expect(inferDosageForm(name, brand)).toBe(expected);
    });

    it('returns null for non-drug supplies', () => {
      expect(inferDosageForm('DISPOSABLE GOWNS', 'Blue gowns')).toBeNull();
    });
  });

  describe('inferStrength', () => {
    it.each([
      ['AZITHROMYCIN 500MG TABLET', null, '500 mg'],
      ['Dexamethasone 0.5mg', null, '0.5 mg'],
      ['FLUTICASONE PROPIONATE 50MCG', null, '50 mcg'],
      ['Paracetamol BP 500 mg + Caffeine (Anydrous) BP 65mg', null, '500 mg + 65 mg'],
      ['VITAMIN C ,ZINC 10MG AND VITAMIN D3 1000IU', null, '10 mg + 1000 IU'],
      ['ETORICOXIB TABLETS', 'ATOXIA 90MG', '90 mg'],
    ])('infers %s (%s) as %s', (name, brand, expected) => {
      expect(inferStrength(name, brand)).toBe(expected);
    });

    it('ignores pack counts without units', () => {
      expect(inferStrength('PANADOL EXTRA 10X10', 'PANADOL EXTRA')).toBeNull();
    });
  });
});
