jest.mock('@repositories/scheduling-workspace/scheduling-workspace.repository', () => ({
  buildAppointmentWhere: jest.fn(() => ({ scope: 'appointments' })),
  buildQueueWhere: jest.fn(() => ({ scope: 'queue' })),
  buildReminderWhere: jest.fn(() => ({ scope: 'reminders' })),
  buildFollowUpWhere: jest.fn(() => ({ scope: 'followups' })),
  buildScheduleWhere: jest.fn(() => ({ scope: 'capacity' })),
  buildOpenEncounterWhere: jest.fn(() => ({ scope: 'opd' })),
  findAppointments: jest.fn(),
  countAppointments: jest.fn(),
  findQueueEntries: jest.fn(),
  countQueueEntries: jest.fn(),
  findReminders: jest.fn(),
  countReminders: jest.fn(),
  findFollowUps: jest.fn(),
  countFollowUps: jest.fn(),
  findSchedules: jest.fn(),
  countSchedules: jest.fn(),
  findOpenEncounters: jest.fn(),
  countOpenEncounters: jest.fn(),
  findFacilities: jest.fn(),
  findProviders: jest.fn(),
  resolveLegacyRecord: jest.fn(),
}));

jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: (...values) => values.find((value) => value && !String(value).includes('-uuid')) || null,
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || null),
}));

const repository = require('@repositories/scheduling-workspace/scheduling-workspace.repository');
const { resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const subject = require('@services/scheduling-workspace/scheduling-workspace.service');

describe('scheduling-workspace.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    repository.findAppointments.mockResolvedValue([
      {
        human_friendly_id: 'APT0001',
        scheduled_start: new Date('2026-03-03T09:00:00.000Z'),
        scheduled_end: new Date('2026-03-03T09:30:00.000Z'),
        status: 'CONFIRMED',
        patient: { human_friendly_id: 'PAT0001', first_name: 'Jane', last_name: 'Doe' },
        provider: { human_friendly_id: 'USR0002', profile: { first_name: 'Dr', last_name: 'Kato' } },
        facility: { human_friendly_id: 'FAC0001', name: 'Main Clinic' },
      },
    ]);
    repository.countAppointments.mockResolvedValue(4);
    repository.findQueueEntries.mockResolvedValue([]);
    repository.countQueueEntries.mockResolvedValue(2);
    repository.findReminders.mockResolvedValue([]);
    repository.countReminders.mockResolvedValue(1);
    repository.findFollowUps.mockResolvedValue([]);
    repository.countFollowUps.mockResolvedValue(3);
    repository.findSchedules.mockResolvedValue([]);
    repository.countSchedules.mockResolvedValue(5);
    repository.findOpenEncounters.mockResolvedValue([
      {
        human_friendly_id: 'ENC0001',
        encounter_type: 'OPD',
        updated_at: new Date('2026-03-03T08:00:00.000Z'),
        extension_json: { opd_flow: { stage: 'WAITING_DOCTOR_REVIEW', next_step: 'DOCTOR_REVIEW' } },
        patient: { human_friendly_id: 'PAT0001', first_name: 'Jane', last_name: 'Doe' },
      },
    ]);
    repository.countOpenEncounters.mockResolvedValue(1);
    repository.findFacilities.mockResolvedValue([
      { human_friendly_id: 'FAC0001', name: 'Main Clinic' },
    ]);
    repository.findProviders.mockResolvedValue([
      { human_friendly_id: 'USR0002', profile: { first_name: 'Dr', last_name: 'Kato' }, email: 'kato@example.com' },
    ]);
    repository.resolveLegacyRecord.mockResolvedValue({ human_friendly_id: 'APT0001' });
  });

  it('builds workspace summary and boards without exposing internal uuids', async () => {
    const result = await subject.getWorkspace({
      tenant_id: 'TEN0001',
      facility_id: 'FAC0001',
      date: '2026-03-03',
    });

    expect(resolveIdentifierForFilter).toHaveBeenCalled();
    expect(result.summary_cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'today_appointments', value: 4 }),
        expect.objectContaining({ id: 'active_opd', value: 1 }),
      ])
    );
    expect(result.boards.arrivals.items[0]).toEqual(
      expect.objectContaining({
        id: 'APT0001',
        patient_id: 'PAT0001',
        provider_user_id: 'USR0002',
        target_path: expect.stringContaining('/scheduling/appointments/APT0001'),
      })
    );
  });

  it('returns provider and facility reference data options', async () => {
    const result = await subject.getReferenceData({ tenant_id: 'TEN0001' });

    expect(result.facilities).toEqual([{ value: 'FAC0001', label: 'Main Clinic' }]);
    expect(result.providers).toEqual([
      expect.objectContaining({
        value: 'USR0002',
        label: 'Dr Kato',
      }),
    ]);
  });

  it('maps legacy routes to frontend target paths', async () => {
    const result = await subject.resolveLegacyRouteIdentifier('appointments', 'APT0001');
    expect(result).toEqual({
      resource: 'appointments',
      id: 'APT0001',
      target_path: '/scheduling/appointments/APT0001',
    });
  });
});
