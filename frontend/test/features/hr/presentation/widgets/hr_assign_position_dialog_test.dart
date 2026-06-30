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
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_position_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockHrRepository extends Mock implements HrRepository {}

const HrReferenceData _referenceData = HrReferenceData(
  staffPositions: <HrOption>[
    HrOption(value: 'Nurse', label: 'Nurse'),
    HrOption(value: 'Doctor', label: 'Doctor'),
  ],
  departments: <HrOption>[
    HrOption(value: 'dept-er', label: 'Emergency'),
  ],
  practitionerTypes: <HrOption>[
    HrOption(value: 'MO', label: 'Medical Officer (MO)'),
  ],
  roles: <HrOption>[
    HrOption(value: 'role-nurse', label: 'Nurse'),
  ],
);

const HrStaffProfile _selectedStaff = HrStaffProfile(
  id: 'staff-1',
  displayId: 'STF0001',
  staffNumber: 'EMP-001',
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
}

class _AssignPositionLauncher extends ConsumerStatefulWidget {
  const _AssignPositionLauncher();

  @override
  ConsumerState<_AssignPositionLauncher> createState() =>
      _AssignPositionLauncherState();
}

class _AssignPositionLauncherState
    extends ConsumerState<_AssignPositionLauncher> {
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
      onPressed: () =>
          showHrAssignPositionDialog(context, ref, _selectedStaff),
      child: const Text('Open assign position'),
    );
  }
}

Future<void> _pumpAssignPositionDialog(
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
        home: Scaffold(body: _AssignPositionLauncher()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('Open assign position'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
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

  testWidgets('loads reference data and shows position options', (
    WidgetTester tester,
  ) async {
    await _pumpAssignPositionDialog(tester, repository);

    verify(
      () => repository.loadReferenceData(
        facilityId: any(named: 'facilityId'),
        departmentId: any(named: 'departmentId'),
      ),
    ).called(greaterThanOrEqualTo(1));

    expect(find.text('Assign position'), findsWidgets);
    expect(find.textContaining('Position'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
