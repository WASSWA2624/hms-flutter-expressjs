/**
 * Lab test similarity helper tests
 */

const {
  checkLabTestDuplicates,
  compositeSimilarityScore,
  SIMILARITY_THRESHOLD
} = require('@lib/lab/lab-test-similarity');

describe('lab-test-similarity', () => {
  const existing = [
    {
      id: 'lab-1',
      name: 'Complete Blood Count',
      code: 'CBC-001',
      category: 'Hematology'
    },
    {
      id: 'lab-2',
      name: 'Liver Function Panel',
      code: 'LFT-001',
      category: 'Liver'
    }
  ];

  it('detects exact name and code conflicts with composite score', () => {
    const result = checkLabTestDuplicates({
      name: 'Complete Blood Count',
      code: 'CBC-001',
      category: 'Hematology',
      existing
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.exactCodeConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].score).toBe(100);
    expect(result.similarMatches[0].reasons).toEqual(
      expect.arrayContaining(['name', 'code', 'category'])
    );
  });

  it('treats exact name as hard conflict even when category differs', () => {
    const result = checkLabTestDuplicates({
      name: 'Complete Blood Count',
      code: '',
      category: 'Chemistry',
      existing
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].isExact).toBe(true);
    expect(result.similarMatches[0].categoryScore).toBeGreaterThanOrEqual(0);
    expect(result.similarMatches[0].categoryScore).toBeLessThan(
      SIMILARITY_THRESHOLD
    );
    expect(result.similarMatches[0].nameScore).toBe(100);
    expect(result.similarMatches[0].score).toBe(
      compositeSimilarityScore({
        nameScore: result.similarMatches[0].nameScore,
        categoryScore: result.similarMatches[0].categoryScore
      })
    );
  });

  it('scores category misspellings in the composite percentage', () => {
    const result = checkLabTestDuplicates({
      name: 'Complete Blood Count',
      code: 'CBC-001',
      category: 'Haematology',
      existing
    });

    expect(result.hasExactConflict).toBe(true);
    const match = result.similarMatches[0];
    expect(match.categoryScore).toBeGreaterThan(0);
    expect(match.categoryScore).toBeLessThan(100);
    expect(match.score).toBe(
      compositeSimilarityScore({
        nameScore: match.nameScore,
        codeScore: match.codeScore,
        categoryScore: match.categoryScore
      })
    );
  });

  it('detects short exact names such as test', () => {
    const result = checkLabTestDuplicates({
      name: 'test',
      code: 'test',
      category: 'Admission',
      existing: [
        {
          id: 'lab-3',
          name: 'test',
          code: 'OTHER',
          category: 'Chemistry'
        }
      ]
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
  });

  it('detects punctuation-equivalent codes as exact conflicts', () => {
    const result = checkLabTestDuplicates({
      name: 'Unique Lab Test',
      code: 'CBC001',
      category: 'Hematology',
      existing
    });

    expect(result.exactCodeConflict).toBe(true);
  });

  it('detects similar names above threshold', () => {
    const result = checkLabTestDuplicates({
      name: 'Complete Blood Countt',
      code: 'NEW-001',
      category: 'Hematology',
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.nonExactSimilarMatches.length).toBeGreaterThan(0);
    expect(result.nonExactSimilarMatches[0].reasons).toContain('name');
    expect(result.nonExactSimilarMatches[0].nameScore).toBeGreaterThanOrEqual(
      SIMILARITY_THRESHOLD
    );
  });

  it('builds composite score from name, code, and category', () => {
    const result = checkLabTestDuplicates({
      name: 'Complete Blood Countt',
      code: 'CBC-002',
      category: 'Hematology',
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.nonExactSimilarMatches.length).toBeGreaterThan(0);
    const match = result.nonExactSimilarMatches[0];
    expect(match.codeScore).toBeGreaterThanOrEqual(SIMILARITY_THRESHOLD);
    expect(match.categoryScore).toBe(100);
    expect(match.score).toBe(
      compositeSimilarityScore({
        nameScore: match.nameScore,
        codeScore: match.codeScore,
        categoryScore: match.categoryScore
      })
    );
    expect(match.score).toBeLessThan(100);
  });

  it('excludes the current item by id', () => {
    const result = checkLabTestDuplicates({
      name: 'Complete Blood Count',
      code: 'CBC-001',
      category: 'Hematology',
      existing,
      excludeTestId: 'lab-1'
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.similarMatches).toHaveLength(0);
  });
});
