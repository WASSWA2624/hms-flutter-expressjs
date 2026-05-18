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
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
  });

  testWidgets('renders the clinical workspace shell content', (tester) async {
    final _MockClinicalRepository clinicalRepository =
        _MockClinicalRepository();
    final _MockOpdRepository opdRepository = _MockOpdRepository();
    _stubClinicalInitialLoad(
      clinicalRepository,
      encounters: <ClinicalWorklistEntry>[
        ClinicalWorklistEntry(
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
        ),
      ],
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
    expect(find.text('Provider worklist'), findsOneWidget);
    expect(find.text('Sarah Clinical'), findsOneWidget);
    expect(find.text('No encounter selected'), findsOneWidget);
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
