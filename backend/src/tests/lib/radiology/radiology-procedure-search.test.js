/**
 * Radiology procedure search helper tests
 */

const {
  buildRadiologyProcedureSearchFilter,
  buildRadiologyProcedureSearchOr,
  matchingImagingModalities,
} = require('@lib/radiology/radiology-procedure-search');

describe('radiology-procedure-search', () => {
  it('does not use contains on modality enum fields', () => {
    const or = buildRadiologyProcedureSearchOr('abdomino');
    expect(or).toEqual(
      expect.arrayContaining([
        { name: { contains: 'abdomino' } },
        { code: { contains: 'abdomino' } },
        { body_region: { contains: 'abdomino' } },
      ])
    );
    expect(or.some((clause) => clause.modality && clause.modality.contains)).toBe(
      false
    );
  });

  it('matches modality enums with equals when the query is a modality', () => {
    expect(matchingImagingModalities('ct')).toEqual(['CT']);
    expect(matchingImagingModalities('ultrasound')).toEqual(['ULTRASOUND']);
    expect(buildRadiologyProcedureSearchOr('CT')).toEqual(
      expect.arrayContaining([{ modality: 'CT' }])
    );
  });

  it('builds a nested procedure filter for offering queries', () => {
    expect(buildRadiologyProcedureSearchFilter('')).toBeNull();
    expect(buildRadiologyProcedureSearchFilter('chest')).toEqual({
      deleted_at: null,
      OR: expect.arrayContaining([
        { name: { contains: 'chest' } },
        { code: { contains: 'chest' } },
        { body_region: { contains: 'chest' } },
      ]),
    });
  });
});
