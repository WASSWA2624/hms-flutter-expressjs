/**
 * Lab panel similarity helper tests
 */

const {
  checkLabPanelDuplicates,
  compositePanelSimilarityScore,
  compositionOverlapPercent,
  panelMembershipKeys,
  SIMILARITY_THRESHOLD
} = require('@lib/lab/lab-panel-similarity');

describe('lab-panel-similarity', () => {
  const existing = [
    {
      id: 'panel-1',
      name: 'Complete Blood Count Panel',
      code: 'CBC-PANEL',
      category: 'Hematology',
      panel_items: [
        { lab_test_id: 't1', test_code: 'HB' },
        { lab_test_id: 't2', test_code: 'WBC' },
        { lab_test_id: 't3', test_code: 'PLT' }
      ]
    },
    {
      id: 'panel-2',
      name: 'Liver Function Panel',
      code: 'LFT-PANEL',
      category: 'Liver',
      panel_items: [
        { lab_test_id: 't4', test_code: 'ALT' },
        { lab_test_id: 't5', test_code: 'AST' }
      ]
    }
  ];

  it('detects exact name and code conflicts with composite score', () => {
    const result = checkLabPanelDuplicates({
      name: 'Complete Blood Count Panel',
      code: 'CBC-PANEL',
      category: 'Hematology',
      panelItems: [
        { lab_test_id: 't1', test_code: 'HB' },
        { lab_test_id: 't2', test_code: 'WBC' },
        { lab_test_id: 't3', test_code: 'PLT' }
      ],
      existing
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.exactCodeConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].score).toBe(100);
    expect(result.similarMatches[0].reasons).toEqual(
      expect.arrayContaining(['name', 'code', 'category', 'composition'])
    );
  });

  it('surfaces high member-test composition overlap as a similarity signal', () => {
    const result = checkLabPanelDuplicates({
      name: 'Hematology Bundle',
      code: 'HEM-BUNDLE',
      category: 'Chemistry',
      panelItems: [
        { lab_test_id: 't1', test_code: 'HB' },
        { lab_test_id: 't2', test_code: 'WBC' },
        { lab_test_id: 't3', test_code: 'PLT' }
      ],
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.similarMatches.length).toBeGreaterThan(0);
    const match = result.similarMatches.find((row) => row.id === 'panel-1');
    expect(match).toBeDefined();
    expect(match.compositionScore).toBe(100);
    expect(match.reasons).toContain('composition');
    expect(match.score).toBe(
      compositePanelSimilarityScore({
        nameScore: match.nameScore,
        codeScore: match.codeScore,
        categoryScore: match.categoryScore,
        compositionScore: match.compositionScore
      })
    );
  });

  it('computes membership keys preferring test codes', () => {
    const keys = panelMembershipKeys({
      panel_items: [
        { lab_test_id: 'uuid-1', test_code: 'HB' },
        { lab_test_id: 'uuid-2' }
      ]
    });
    expect(keys.has('CODE:HB')).toBe(true);
    // Without a test code, the lab_test_id is used as a CODE:/ID-style key.
    expect(keys.has('CODE:UUID2') || keys.has('ID:UUID-2')).toBe(true);
  });

  it('computes Jaccard composition overlap', () => {
    expect(
      compositionOverlapPercent(
        new Set(['CODE:HB', 'CODE:WBC']),
        new Set(['CODE:HB', 'CODE:WBC', 'CODE:PLT'])
      )
    ).toBe(67);
  });

  it('excludes the panel being edited', () => {
    const result = checkLabPanelDuplicates({
      name: 'Complete Blood Count Panel',
      code: 'CBC-PANEL',
      category: 'Hematology',
      panelItems: existing[0].panel_items,
      existing,
      excludePanelIds: ['panel-1']
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.similarMatches.every((match) => match.id !== 'panel-1')).toBe(
      true
    );
  });

  it('does not surface unrelated panels below the threshold', () => {
    const result = checkLabPanelDuplicates({
      name: 'Zzyx Unique Panel Alpha',
      code: 'ZZYX-001',
      category: 'Admission',
      panelItems: [{ lab_test_id: 'unique-1', test_code: 'ZZ1' }],
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(
      result.similarMatches.every(
        (match) => match.score >= SIMILARITY_THRESHOLD
          || (match.compositionScore ?? 0) >= SIMILARITY_THRESHOLD
          || (match.nameScore ?? 0) >= SIMILARITY_THRESHOLD
          || (match.codeScore ?? 0) >= SIMILARITY_THRESHOLD
      )
    ).toBe(true);
    expect(result.similarMatches).toHaveLength(0);
  });
});
