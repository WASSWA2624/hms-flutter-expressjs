/**
 * Radiology test similarity helper tests
 */

const {
  checkRadiologyTestDuplicates,
  nameSimilarityScore,
  textSimilarityScore,
  SIMILARITY_THRESHOLD
} = require('@lib/radiology/radiology-test-similarity');

describe('radiology-test-similarity', () => {
  const existing = [
    {
      id: 'rad-1',
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY'
    },
    {
      id: 'rad-2',
      name: 'Brain MRI',
      code: 'MRI-001',
      modality: 'MRI'
    }
  ];

  it('detects exact name and code conflicts', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Chest X-Ray',
      code: 'CXR-001',
      existing
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.exactCodeConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
  });

  it('detects punctuation-equivalent codes as exact conflicts', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Unique Procedure',
      code: 'CXR001',
      existing
    });

    expect(result.exactCodeConflict).toBe(true);
  });

  it('detects similar names above threshold', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Chest X-Rayy',
      code: 'NEW-001',
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.nonExactSimilarMatches.length).toBeGreaterThan(0);
    expect(result.nonExactSimilarMatches[0].score).toBeGreaterThanOrEqual(
      SIMILARITY_THRESHOLD
    );
    expect(result.nonExactSimilarMatches[0].reasons).toContain('name');
  });

  it('detects similar codes above threshold', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Totally Unique Procedure',
      code: 'CXR-002',
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.nonExactSimilarMatches.length).toBeGreaterThan(0);
    expect(result.nonExactSimilarMatches[0].reasons).toContain('code');
  });

  it('detects token-order variants in names', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Xray Chest',
      code: 'UNIQUE-99',
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.nonExactSimilarMatches.length).toBeGreaterThan(0);
    expect(result.nonExactSimilarMatches[0].score).toBeGreaterThanOrEqual(
      SIMILARITY_THRESHOLD
    );
  });

  it('ignores excluded test ids', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Chest X-Ray',
      code: 'CXR-001',
      existing,
      excludeTestId: 'rad-1'
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.similarMatches).toEqual([]);
  });

  it('scores identical normalized names as 100', () => {
    expect(nameSimilarityScore('chest xray', 'chest xray')).toBe(100);
    expect(textSimilarityScore('chest xray', 'chest xray')).toBe(100);
  });
});
