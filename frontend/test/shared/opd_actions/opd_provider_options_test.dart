import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';

void main() {
  test('dedupes provider API and schedule fallback options by person', () {
    final List<OpdProviderOption> providers = <OpdProviderOption>[
      const OpdProviderOption(
        id: 'USR-001',
        displayName: 'Jordani Demo Demo',
        email: 'jordan@example.com',
        positionTitle: 'Consultant',
        practitionerType: 'Doctor',
        staffProfileId: 'STAFF-PROFILE-001',
      ),
      const OpdProviderOption(
        id: 'USR-002',
        displayName: 'Jordani Demo Demo',
        email: 'jordan@example.com',
        positionTitle: 'Consultant',
        practitionerType: 'Doctor',
        staffProfileId: 'STAFF-PROFILE-001',
      ),
    ];
    final List<OpdProviderSchedule> schedules = <OpdProviderSchedule>[
      const OpdProviderSchedule(
        id: 'SCHED-001',
        providerUserId: 'RAW-USER-ID-001',
        providerPublicId: 'USR-001',
        providerDisplayName: 'Jordani Demo Demo',
        facilityName: 'Main OPD',
      ),
    ];

    final options = opdProviderSelectOptions(
      providers: providers,
      schedules: schedules,
    );

    expect(options, hasLength(1));
    expect(options.single.value, 'USR-001');
    expect(
      options.single.label,
      'Jordani Demo Demo | Consultant | Doctor · Available today',
    );
  });

  test('does not expose provider internal identifiers as visible text', () {
    const OpdProviderOption provider = OpdProviderOption(
      id: '550e8400-e29b-41d4-a716-446655440000',
      email: 'provider@example.com',
      phone: '+256700000000',
      positionTitle: 'Medical officer',
      practitionerType: 'Clinician',
      staffProfileId: 'staff_profile_123',
    );

    final options = opdProviderSelectOptions(
      providers: const <OpdProviderOption>[provider],
      schedules: const <OpdProviderSchedule>[],
    );

    expect(options, hasLength(1));
    expect(
      options.single.label,
      'Assigned staff unknown | Medical officer | Clinician',
    );
    expect(options.single.label, isNot(contains('550e8400')));
    expect(options.single.label, isNot(contains('staff_profile')));
    expect(options.single.label, isNot(contains('provider@example.com')));
    expect(provider.displayTitle, 'Assigned staff unknown');
  });

  test('injects and resolves an assigned provider missing from options', () {
    const OpdProviderOption catalog = OpdProviderOption(
      id: 'USR-100',
      displayName: 'Catalog Doctor',
    );
    final List<OpdProviderOption> providers = opdProvidersWithAssigned(
      providers: const <OpdProviderOption>[catalog],
      assignedProviderId: 'USR-ASSIGNED',
      assignedProviderDisplayName: 'Assigned Doctor',
    );
    expect(providers, hasLength(2));
    expect(providers.first.id, 'USR-ASSIGNED');

    final options = opdProviderSelectOptions(
      providers: providers,
      schedules: const <OpdProviderSchedule>[],
    );
    expect(
      resolveOpdProviderSelection(
        options: options,
        providers: providers,
        assignedProviderId: 'USR-ASSIGNED',
        assignedProviderDisplayName: 'Assigned Doctor',
      ),
      'USR-ASSIGNED',
    );
  });

  test('resolves assigned provider by display name when ids differ', () {
    const OpdProviderOption provider = OpdProviderOption(
      id: 'uuid-provider',
      displayName: 'Dr Match',
      staffProfileId: 'STAFF-9',
    );
    final options = opdProviderSelectOptions(
      providers: const <OpdProviderOption>[provider],
      schedules: const <OpdProviderSchedule>[],
    );

    expect(
      resolveOpdProviderSelection(
        options: options,
        providers: const <OpdProviderOption>[provider],
        assignedProviderId: 'STAFF-9',
        assignedProviderDisplayName: 'Dr Match',
      ),
      'uuid-provider',
    );
  });
}
