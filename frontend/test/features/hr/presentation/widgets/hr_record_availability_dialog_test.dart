import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_record_availability_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockHrRepository extends Mock implements HrRepository {}

const HrReferenceData _referenceData = HrReferenceData(
  staffProfiles: <HrOption>[
    HrOption(value: 'staff-1', label: 'Alice Nurse'),
    HrOption(value: 'staff-2', label: 'Bob Clinician'),
  ],
);

const HrStaffProfile _selectedStaff = HrStaffProfile(
  id: 'staff-1',
  displayId: 'STF0001',
  staffNumber: 'EMP-001',
);

const HrStaffAvailability _mondayAvailability = HrStaffAvailability(
  id: 'avail-1',
  staffProfileId: 'staff-2',
  dayOfWeek: 1,
  timeSlots: <HrAvailabilitySlot>[
    HrAvailabilitySlot(startTime: '08:00', endTime: '10:00'),
    HrAvailabilitySlot(startTime: '14:00', endTime: '16:00'),
  ],
);

void _stubWorkspaceBootstrap(_MockHrRepository repository) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async =>
        const Result<HrWorkspaceOverview>.success(HrWorkspaceOverview()),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: <HrStaffProfile>[_selectedStaff],
        request: AppPageRequest(),
      ),
    ),
  );
  when(
    () => repository.loadReferenceData(
      facilityId: any(named: 'facilityId'),
      departmentId: any(named: 'departmentId'),
    ),
  ).thenAnswer(
    (_) async => const Result<HrReferenceData>.success(_referenceData),
  );
  when(() => repository.listWorkItems(any())).thenAnswer(
    (_) async => const Result<AppPage<HrWorkItem>>.success(
      AppPage<HrWorkItem>(
        items: <HrWorkItem>[],
        request: AppPageRequest(pageSize: 10),
      ),
    ),
  );
  when(() => repository.loadStaffDetail(any())).thenAnswer(
    (_) async => const Result<HrStaffDetail>.success(
      HrStaffDetail(profile: _selectedStaff),
    ),
  );
  when(() => repository.loadStaffAccessSummary(any())).thenAnswer(
    (_) async =>
        const Result<HrStaffAccessSummary>.success(HrStaffAccessSummary()),
  );
  when(() => repository.createStaffAvailabilityBatch(any())).thenAnswer(
    (_) async => const Result<Object?>.success(<String, Object?>{}),
  );
  when(() => repository.createStaffAvailability(any())).thenAnswer(
    (_) async => const Result<Object?>.success(<String, Object?>{}),
  );
  when(() => repository.listStaffAvailabilities(any())).thenAnswer(
    (_) async => const Result<List<HrStaffAvailability>>.success(
      <HrStaffAvailability>[_mondayAvailability],
    ),
  );
}

class _RecordAvailabilityLauncher extends ConsumerStatefulWidget {
  const _RecordAvailabilityLauncher();

  @override
  ConsumerState<_RecordAvailabilityLauncher> createState() =>
      _RecordAvailabilityLauncherState();
}

class _RecordAvailabilityLauncherState
    extends ConsumerState<_RecordAvailabilityLauncher> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(hrWorkspaceControllerProvider.future);
      await ref
          .read(hrWorkspaceControllerProvider.notifier)
          .selectStaff(_selectedStaff);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => showHrRecordAvailabilityDialog(context, ref),
      child: const Text('Open record availability'),
    );
  }
}

Future<void> _pumpRecordAvailabilityDialog(
  WidgetTester tester,
  _MockHrRepository repository,
) async {
  _stubWorkspaceBootstrap(repository);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hrRepositoryProvider.overrideWithValue(repository),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.authenticated(),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _RecordAvailabilityLauncher()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('Open record availability'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _selectCopySourceStaff(WidgetTester tester) async {
  await tester.tap(find.byType(TextField).first, warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Bob');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bob Clinician').last);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late _MockHrRepository repository;

  setUp(() {
    repository = _MockHrRepository();
  });

  setUpAll(() {
    registerFallbackValue(const HrStaffQuery());
    registerFallbackValue(const HrWorkItemsQuery());
    registerFallbackValue(_selectedStaff);
  });

  testWidgets('shows weekly schedule builder with shared fields', (
    WidgetTester tester,
  ) async {
    await _pumpRecordAvailabilityDialog(tester, repository);

    expect(find.text('Record availability'), findsWidgets);
    expect(find.text('Weekly schedule'), findsOneWidget);
    expect(find.text('Monday'), findsWidgets);
    expect(find.text('Sunday'), findsWidgets);
    expect(find.textContaining('Effective from'), findsOneWidget);
    expect(find.text('Copy from staff'), findsOneWidget);
    expect(find.textContaining('08:00-17:00'), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('copy from staff pre-fills slots from colleague schedule', (
    WidgetTester tester,
  ) async {
    await _pumpRecordAvailabilityDialog(tester, repository);

    await _selectCopySourceStaff(tester);

    verify(() => repository.listStaffAvailabilities('staff-2')).called(1);

    await tester.tap(find.text('Monday'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('08:00-10:00'), findsOneWidget);
    expect(find.textContaining('14:00-16:00'), findsOneWidget);
    expect(find.text('08'), findsWidgets);
    expect(find.text('02'), findsWidgets);
  });

  testWidgets('duplicate day dialog offers other weekdays as targets', (
    WidgetTester tester,
  ) async {
    await _pumpRecordAvailabilityDialog(tester, repository);

    await _selectCopySourceStaff(tester);

    final Finder duplicateButton = find.text('Duplicate to…').first;
    await tester.ensureVisible(duplicateButton);
    await tester.pump();
    await tester.tap(duplicateButton);
    await tester.pumpAndSettle();

    expect(find.text('Duplicate schedule'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppDialog).last,
        matching: find.text('Tuesday'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
