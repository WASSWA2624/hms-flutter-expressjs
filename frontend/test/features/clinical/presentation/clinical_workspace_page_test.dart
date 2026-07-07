import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/clinical/presentation/pages/clinical_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockIpdRepository extends Mock implements IpdRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ClinicalWorklistQuery());
    registerFallbackValue(
      const ClinicalWorklistEntry(
        id: 'encounter-fallback',
        sourceQueue: 'OPD',
        encounterId: 'encounter-fallback',
      ),
    );
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(const IpdAdmissionQuery());
  });

  testWidgets('renders the clinical workspace shell content', (tester) async {
    final _MockClinicalRepository clinicalRepository =
        _MockClinicalRepository();
    final _MockOpdRepository opdRepository = _MockOpdRepository();
    final _MockIpdRepository ipdRepository = _MockIpdRepository();
    final ClinicalWorklistEntry entry = ClinicalWorklistEntry(
      id: 'encounter-1',
      sourceQueue: 'OPD',
      encounterId: 'encounter-1',
      encounterPublicId: 'ENC000001',
      patientDisplayName: 'Sarah Clinical',
      patientPublicId: 'PAT000001',
      providerDisplayName: 'Dr Kizza',
      status: 'OPEN',
      stage: 'WAITING_DOCTOR_REVIEW',
      updatedAt: DateTime.now(),
    );
    final ClinicalWorklistEntry otherEntry = ClinicalWorklistEntry(
      id: 'encounter-2',
      sourceQueue: 'OPD',
      encounterId: 'encounter-2',
      encounterPublicId: 'ENC000002',
      patientDisplayName: 'John Other',
      patientPublicId: 'PAT000002',
      providerDisplayName: 'Dr Mugerwa',
      status: 'OPEN',
      stage: 'IN_PROGRESS',
      updatedAt: DateTime.now(),
    );
    _stubClinicalInitialLoad(
      clinicalRepository,
      encounters: <ClinicalWorklistEntry>[entry, otherEntry],
    );
    _stubOpdInitialLoad(opdRepository);
    _stubIpdInitialLoad(ipdRepository);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
          opdRepositoryProvider.overrideWithValue(opdRepository),
          ipdRepositoryProvider.overrideWithValue(ipdRepository),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.unauthenticated(),
          ),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: ClinicalWorkspacePage()),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Clinical workspace'));

    expect(find.text('Clinical workspace'), findsOneWidget);
    expect(find.text('Provider worklist'), findsNothing);
    expect(
      find.text(
        'Open consultations, admissions, triage handoffs, and '
        'result-review queues.',
      ),
      findsNothing,
    );
    expect(find.text('Current step'), findsWidgets);
    expect(find.text('Queue scope'), findsNothing);
    expect(find.text('Sarah Clinical'), findsOneWidget);
    expect(find.text('John Other'), findsOneWidget);
    expect(find.text('No encounter selected'), findsNothing);
    expect(tester.takeException(), isNull);

    clearInteractions(clinicalRepository);
    await tester.enterText(find.byType(TextFormField).first, 'Other');
    await tester.pump();

    expect(find.text('Sarah Clinical'), findsNothing);
    expect(find.text('John Other'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    final List<Object?> capturedQueries = verify(
      () => clinicalRepository.listEncounters(captureAny()),
    ).captured;
    expect(
      (capturedQueries.single as ClinicalWorklistQuery).databaseSearch,
      'Other',
    );
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    await _pumpUntilFound(tester, find.text('Sarah Clinical'));

    await tester.scrollUntilVisible(
      find.text('Sarah Clinical'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Sarah Clinical'),
      ),
    );
    await _pumpUntilFound(tester, find.text('Clinical actions'));

    expect(find.textContaining('Clinical details'), findsOneWidget);
    expect(find.text('Clinical actions'), findsOneWidget);
    expect(find.textContaining('ENC000001 ·'), findsOneWidget);
    expect(find.text('Order / test'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxAttempts = 100,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

void _stubClinicalInitialLoad(
  _MockClinicalRepository repository, {
  List<ClinicalWorklistEntry> encounters = const <ClinicalWorklistEntry>[],
}) {
  when(() => repository.listEncounters(any())).thenAnswer(
    (invocation) async => Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: encounters,
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: encounters.length,
      ),
    ),
  );
  when(() => repository.listAdmissions(any())).thenAnswer(
    (invocation) async => Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: const <ClinicalWorklistEntry>[],
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(repository.loadReferenceData).thenAnswer(
    (_) async =>
        const Result<ClinicalReferenceData>.success(ClinicalReferenceData()),
  );
  when(() => repository.loadEncounterBundle(any())).thenAnswer((invocation) {
    final ClinicalWorklistEntry entry =
        invocation.positionalArguments.single as ClinicalWorklistEntry;
    return Future<Result<ClinicalEncounterBundle>>.value(
      Result<ClinicalEncounterBundle>.success(
        ClinicalEncounterBundle(entry: entry),
      ),
    );
  });
}

void _stubOpdInitialLoad(_MockOpdRepository repository) {
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
}

void _stubIpdInitialLoad(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer(
    (invocation) async => Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[],
        request: (invocation.positionalArguments.single as IpdAdmissionQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
}
