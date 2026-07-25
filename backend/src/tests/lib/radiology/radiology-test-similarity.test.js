/**
 * Radiology test similarity helper tests
 */

const {
  checkRadiologyTestDuplicates,
  compositeSimilarityScore,
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

  it('detects exact name and code conflicts with composite score', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY',
      existing
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.exactCodeConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].score).toBe(100);
    expect(result.similarMatches[0].reasons).toEqual(
      expect.arrayContaining(['name', 'code', 'modality'])
    );
  });

  it('lowers composite score when modality differs on exact name', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Chest X-Ray',
      code: '',
      modality: 'MRI',
      existing
    });

    expect(result.exactNameConflict).toBe(false);
    expect(result.hasExactConflict).toBe(false);
    expect(result.nonExactSimilarMatches.length).toBeGreaterThan(0);
    expect(result.nonExactSimilarMatches[0].score).toBeLessThan(100);
    expect(result.nonExactSimilarMatches[0].modalityScore).toBe(0);
    expect(result.nonExactSimilarMatches[0].nameScore).toBe(100);
  });

  it('detects punctuation-equivalent codes as exact conflicts', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Unique Procedure',
      code: 'CXR001',
      modality: 'XRAY',
      existing
    });

    expect(result.exactCodeConflict).toBe(true);
  });

  it('detects similar names above threshold', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Chest X-Rayy',
      code: 'NEW-001',
      modality: 'XRAY',
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.nonExactSimilarMatches.length).toBeGreaterThan(0);
    expect(result.nonExactSimilarMatches[0].reasons).toContain('name');
    expect(result.nonExactSimilarMatches[0].nameScore).toBeGreaterThanOrEqual(
      SIMILARITY_THRESHOLD
    );
  });

  it('builds composite score from name, code, and modality', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Chest X-Rayy',
      code: 'CXR-002',
      modality: 'XRAY',
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.nonExactSimilarMatches.length).toBeGreaterThan(0);
    const match = result.nonExactSimilarMatches[0];
    expect(match.codeScore).toBeGreaterThanOrEqual(SIMILARITY_THRESHOLD);
    expect(match.modalityScore).toBe(100);
    expect(match.score).toBe(compositeSimilarityScore({
      nameScore: match.nameScore,
      codeScore: match.codeScore,
      modalityScore: match.modalityScore
    }));
    expect(match.score).toBeLessThan(100);
  });

  it('detects similar codes above threshold', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Totally Unique Procedure',
      code: 'CXR-002',
      modality: 'CT',
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
      modality: 'XRAY',
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.nonExactSimilarMatches.length).toBeGreaterThan(0);
    expect(result.nonExactSimilarMatches[0].nameScore).toBeGreaterThanOrEqual(
      SIMILARITY_THRESHOLD
    );
  });

  it('ignores excluded test ids', () => {
    const result = checkRadiologyTestDuplicates({
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY',
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

  it('weights composite scores across parameters', () => {
    expect(compositeSimilarityScore({
      nameScore: 100,
      codeScore: 0,
      modalityScore: 100
    })).toBe(70);
    expect(compositeSimilarityScore({
      nameScore: 80,
      modalityScore: 100
    })).toBe(86);
  });
});
