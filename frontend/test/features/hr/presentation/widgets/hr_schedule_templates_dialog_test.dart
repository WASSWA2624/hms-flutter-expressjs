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
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockHrRepository extends Mock implements HrRepository {}

const HrOption _template = HrOption(
  value: 'SHI0000001',
  label: 'Biomedical',
  displayId: 'SHI0000001',
  extra: <String, Object?>{
    'shift_type': 'DAY',
    'facility_id': 'fac-1',
    'is_active': true,
    'weekly_schedule_json': <Map<String, Object?>>[
      <String, Object?>{
        'day_of_week': 1,
        'time_slots': <Map<String, String>>[
          <String, String>{'start_time': '08:00', 'end_time': '17:00'},
        ],
      },
    ],
  },
);

const HrReferenceData _referenceData = HrReferenceData(
  shiftTemplates: <HrOption>[_template],
  facilities: <HrOption>[HrOption(value: 'fac-1', label: 'Biomedical dept')],
  shiftTypes: <HrOption>[HrOption(value: 'DAY', label: 'DAY')],
);

void _stubWorkspaceBootstrap(_MockHrRepository repository) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async =>
        const Result<HrWorkspaceOverview>.success(HrWorkspaceOverview()),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: <HrStaffProfile>[],
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
  when(
    () => repository.createShiftTemplate(any()),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
  when(
    () => repository.updateShiftTemplate(any(), any()),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
  when(
    () => repository.deleteShiftTemplate(any()),
  ).thenAnswer((_) async => const Result<Object?>.success(null));
}

class _ManageTemplatesLauncher extends ConsumerStatefulWidget {
  const _ManageTemplatesLauncher();

  @override
  ConsumerState<_ManageTemplatesLauncher> createState() =>
      _ManageTemplatesLauncherState();
}

class _ManageTemplatesLauncherState
    extends ConsumerState<_ManageTemplatesLauncher> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(hrWorkspaceControllerProvider.future),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => showHrManageScheduleTemplatesDialog(context, ref),
      child: const Text('Open schedule templates'),
    );
  }
}

Future<void> _pumpManageDialog(
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
        home: Scaffold(body: _ManageTemplatesLauncher()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('Open schedule templates'));
  await tester.pump();
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
    registerFallbackValue(<String, Object?>{});
  });

  testWidgets('manage dialog opens maximized with copyable template id', (
    WidgetTester tester,
  ) async {
    await _pumpManageDialog(tester, repository);

    expect(find.text('Schedule templates'), findsWidgets);
    expect(find.text('Biomedical'), findsOneWidget);
    expect(find.byType(AppCopyableIdentifier), findsOneWidget);
    expect(find.text('SHI0000001'), findsWidgets);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.initialMaximized, isTrue);
    expect(dialog.maxWidth, 980);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list row exposes icon-only edit and delete actions', (
    WidgetTester tester,
  ) async {
    await _pumpManageDialog(tester, repository);

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.text('Edit template'), findsNothing);
    expect(find.text('Delete template'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping row opens template detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpManageDialog(tester, repository);

    await tester.tap(find.text('Biomedical'));
    await tester.pumpAndSettle();

    expect(find.text('Template ID'), findsOneWidget);
    expect(find.text('Weekly schedule'), findsWidgets);
    expect(find.textContaining('08:00-17:00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
