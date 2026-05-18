import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/clinical/presentation/pages/clinical_workspace_page.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

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
  });

  testWidgets('renders the clinical workspace shell content', (tester) async {
    final _MockClinicalRepository clinicalRepository =
        _MockClinicalRepository();
    final _MockOpdRepository opdRepository = _MockOpdRepository();
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

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
          opdRepositoryProvider.overrideWithValue(opdRepository),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: ClinicalWorkspacePage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Clinical workspace'), findsOneWidget);
    expect(find.text('Provider worklist'), findsNothing);
    expect(
      find.text(
        'Open consultations, admissions, triage handoffs, and '
        'result-review queues.',
      ),
      findsNothing,
    );
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
    verifyNever(() => clinicalRepository.listEncounters(any()));
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.pump();

    await tester.tap(find.byTooltip('Clinical filters'));
    await tester.pumpAndSettle();

    expect(find.text('Queue scope'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sarah Clinical'));
    await tester.pumpAndSettle();

    expect(find.text('Clinical actions'), findsOneWidget);
    expect(find.text('Encounter'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Waiting review'));
    await tester.pumpAndSettle();

    expect(find.text('Waiting review'), findsNWidgets(2));
    expect(find.text('Sarah Clinical'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });
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
