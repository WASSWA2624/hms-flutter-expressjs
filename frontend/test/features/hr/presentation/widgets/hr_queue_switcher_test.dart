import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_queue_switcher.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockHrRepository extends Mock implements HrRepository {}

Future<void> _pumpSwitcher(
  WidgetTester tester, {
  required Size viewport,
  required HrQueue selectedQueue,
  bool enabled = true,
}) async {
  final _MockHrRepository repository = _MockHrRepository();
  when(() => repository.loadOverview()).thenAnswer(
    (_) async => const Result<HrWorkspaceOverview>.success(
      HrWorkspaceOverview(),
    ),
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
    (_) async => const Result<HrReferenceData>.success(HrReferenceData()),
  );
  when(() => repository.listWorkItems(any())).thenAnswer(
    (_) async => const Result<AppPage<HrWorkItem>>.success(
      AppPage<HrWorkItem>(
        items: <HrWorkItem>[],
        request: AppPageRequest(pageSize: 10),
      ),
    ),
  );

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hrRepositoryProvider.overrideWithValue(repository),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.authenticated(),
        ),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            width: viewport.width,
            child: HrQueueSwitcher(
              selectedQueue: selectedQueue,
              enabled: enabled,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() {
    registerFallbackValue(const HrWorkItemsQuery());
    registerFallbackValue(const HrStaffQuery());
  });

  testWidgets('HrQueueSwitcher shows labels without overflow at dialog width', (
    WidgetTester tester,
  ) async {
    await _pumpSwitcher(
      tester,
      viewport: const Size(980, 600),
      selectedQueue: HrQueue.swapRequests,
    );

    expect(find.text('Leave requests'), findsOneWidget);
    expect(find.text('Swap requests'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HrQueueSwitcher uses icon-only tabs at narrow width', (
    WidgetTester tester,
  ) async {
    await _pumpSwitcher(
      tester,
      viewport: const Size(360, 600),
      selectedQueue: HrQueue.leaveRequests,
    );

    expect(find.text('Leave requests'), findsNothing);
    expect(find.text('Swap requests'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HrQueueSwitcher disables non-selected tabs while loading', (
    WidgetTester tester,
  ) async {
    await _pumpSwitcher(
      tester,
      viewport: const Size(980, 600),
      selectedQueue: HrQueue.leaveRequests,
      enabled: false,
    );

    final Finder swapTab = find.byTooltip('Swap requests');
    expect(swapTab, findsOneWidget);
    final Element swapElement = tester.element(swapTab);
    final Widget swapWidget = swapElement.findAncestorWidgetOfExactType<
        ElevatedButton>() ??
        swapElement.widget;
    expect(swapWidget, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
