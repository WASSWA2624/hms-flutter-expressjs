const {
  checkRosterDuplicates,
  compositeSimilarityScore,
  isRosterFullExactDuplicate,
} = require('@lib/roster/roster-similarity');

describe('roster-similarity', () => {
  const existing = [
    {
      id: 'roster-a',
      human_friendly_id: 'RST0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      department_id: null,
      name: 'Day Ward Template',
      is_recurring: true,
      period_start: '2026-01-01T00:00:00.000Z',
      period_end: '2026-01-08T00:00:00.000Z',
      constraints: {
        month_days: [1, 2, 3],
        weekly_schedule_json: [
          {
            day_of_week: 1,
            time_slots: [{ start_time: '08:00', end_time: '17:00' }],
          },
        ],
      },
    },
  ];

  it('weights name more heavily than recurring flag', () => {
    const nameHeavy = compositeSimilarityScore({
      nameScore: 100,
      recurringScore: 0,
    });
    const recurringHeavy = compositeSimilarityScore({
      nameScore: 0,
      recurringScore: 100,
    });
    expect(nameHeavy).toBeGreaterThan(recurringHeavy);
  });

  it('blocks only when every compared parameter is an exact match', () => {
    const result = checkRosterDuplicates({
      name: 'Day Ward Template',
      facilityId: 'facility-1',
      departmentId: null,
      isRecurring: true,
      periodStart: '2026-01-01T00:00:00.000Z',
      periodEnd: '2026-01-08T00:00:00.000Z',
      constraints: existing[0].constraints,
      existing,
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.hasFullExactDuplicate).toBe(true);
    expect(result.blockingMatches).toHaveLength(1);
    expect(result.overridableMatches).toHaveLength(0);
    expect(result.similarMatches[0].isFullExactDuplicate).toBe(true);
    expect(isRosterFullExactDuplicate(result.similarMatches[0])).toBe(true);
  });

  it('keeps create-anyway available when the name matches but schedule differs', () => {
    const result = checkRosterDuplicates({
      name: 'Day Ward Template',
      facilityId: 'facility-1',
      departmentId: null,
      isRecurring: true,
      periodStart: '2026-01-01T00:00:00.000Z',
      periodEnd: '2026-01-08T00:00:00.000Z',
      constraints: {
        month_days: [1, 2, 3],
        weekly_schedule_json: [
          {
            day_of_week: 1,
            time_slots: [{ start_time: '09:00', end_time: '18:00' }],
          },
        ],
      },
      existing,
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.hasFullExactDuplicate).toBe(false);
    expect(result.blockingMatches).toHaveLength(0);
    expect(result.overridableMatches.length).toBeGreaterThanOrEqual(1);
    expect(result.overridableMatches[0].exactNameConflict).toBe(true);
    expect(result.overridableMatches[0].isFullExactDuplicate).toBe(false);
  });

  it('surfaces overridable near matches for similar names and schedules', () => {
    const result = checkRosterDuplicates({
      name: 'Day Ward Templ',
      facilityId: 'facility-1',
      departmentId: null,
      isRecurring: true,
      periodStart: '2026-02-01T00:00:00.000Z',
      periodEnd: '2026-02-08T00:00:00.000Z',
      constraints: existing[0].constraints,
      existing,
    });

    expect(result.exactNameConflict).toBe(false);
    expect(result.hasFullExactDuplicate).toBe(false);
    expect(result.overridableMatches.length).toBeGreaterThanOrEqual(1);
    expect(result.overridableMatches[0].score).toBeGreaterThanOrEqual(80);
  });
});
