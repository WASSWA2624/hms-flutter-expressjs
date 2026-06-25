import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/clinical/presentation/controllers/clinical_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockIpdRepository extends Mock implements IpdRepository {}

IpdAdmissionDetail _detail(IpdAdmissionSummary summary) {
  return IpdAdmissionDetail(summary: summary);
}

IpdAdmissionSummary _ipdSummary({
  String id = 'adm-uuid-1',
  String displayId = 'ADM000001',
  String encounterId = 'enc-ipd-1',
  String stage = 'ADMITTED_IN_BED',
  String admissionStatus = 'ADMITTED',
}) {
  return IpdAdmissionSummary(
    id: id,
    displayId: displayId,
    patientId: 'pat-ipd-1',
    patientDisplayName: 'Jane Inpatient',
    encounterId: encounterId,
    stage: stage,
    nextStep: 'RECORD_NURSING_NOTE',
    wardDisplayName: 'Ward A',
    bedDisplayLabel: 'Bed 1',
    admittedAt: DateTime.utc(2026, 6, 25, 8),
    admissionStatus: admissionStatus,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const ClinicalWorklistQuery());
    registerFallbackValue(
      const ClinicalWorklistEntry(
        id: 'fallback',
        sourceQueue: 'ENCOUNTER',
        encounterId: 'fallback',
      ),
    );
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  ProviderContainer buildContainer({
    required _MockClinicalRepository clinical,
    required _MockOpdRepository opd,
    required _MockIpdRepository ipd,
    List<ClinicalWorklistEntry> encounters = const <ClinicalWorklistEntry>[],
    List<IpdAdmissionSummary> ipdAdmissions = const <IpdAdmissionSummary>[],
  }) {
    when(() => clinical.listEncounters(any())).thenAnswer(
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
    when(clinical.loadReferenceData).thenAnswer(
      (_) async =>
          const Result<ClinicalReferenceData>.success(ClinicalReferenceData()),
    );
    when(() => clinical.loadEncounterBundle(any())).thenAnswer((invocation) {
      final ClinicalWorklistEntry entry =
          invocation.positionalArguments.single as ClinicalWorklistEntry;
      return Future<Result<ClinicalEncounterBundle>>.value(
        Result<ClinicalEncounterBundle>.success(
          ClinicalEncounterBundle(entry: entry),
        ),
      );
    });

    when(() => opd.listOpdFlows(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: const <OpdFlowSummary>[],
          request: (invocation.positionalArguments.single as OpdFlowQuery)
              .pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
    when(() => opd.listTriageQueue(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: const <OpdFlowSummary>[],
          request:
              (invocation.positionalArguments.single as OpdTriageQueueQuery)
                  .pageRequest,
          totalItemCount: 0,
        ),
      ),
    );

    when(() => ipd.listAdmissions(any())).thenAnswer(
      (invocation) async => Result<AppPage<IpdAdmissionSummary>>.success(
        AppPage<IpdAdmissionSummary>(
          items: ipdAdmissions,
          request: (invocation.positionalArguments.single as IpdAdmissionQuery)
              .pageRequest,
          totalItemCount: ipdAdmissions.length,
        ),
      ),
    );

    final ProviderContainer container = ProviderContainer(
      overrides: [
        clinicalRepositoryProvider.overrideWithValue(clinical),
        opdRepositoryProvider.overrideWithValue(opd),
        ipdRepositoryProvider.overrideWithValue(ipd),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  ClinicalWorkspaceState? readState(ProviderContainer container) {
    return container
        .read(clinicalWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (ClinicalWorkspaceState value) => value,
          failure: (_) => null,
        );
  }

  test('maps ipd-flows admissions into the clinical worklist', () async {
    final _MockClinicalRepository clinical = _MockClinicalRepository();
    final _MockOpdRepository opd = _MockOpdRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      clinical: clinical,
      opd: opd,
      ipd: ipd,
      ipdAdmissions: <IpdAdmissionSummary>[_ipdSummary()],
    );

    await container.read(clinicalWorkspaceControllerProvider.future);

    final ClinicalWorkspaceState? state = readState(container);
    expect(state, isNotNull);
    final ClinicalWorklistEntry entry = state!.worklist.items.singleWhere(
      (ClinicalWorklistEntry item) => item.sourceQueue == 'IPD',
    );
    expect(entry.encounterId, 'enc-ipd-1');
    expect(entry.admissionId, 'adm-uuid-1');
    expect(entry.apiAdmissionId, 'ADM000001');
    expect(entry.stage, 'ADMITTED_IN_BED');
    expect(entry.currentLocation, 'Ward A | Bed 1');

    // The legacy admissions endpoint must no longer power the worklist.
    verifyNever(() => clinical.listAdmissions(any()));
    verify(() => ipd.listAdmissions(any())).called(greaterThanOrEqualTo(1));
  });

  test('active inpatient discharge plans discharge via ipd-flows', () async {
    final _MockClinicalRepository clinical = _MockClinicalRepository();
    final _MockOpdRepository opd = _MockOpdRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      clinical: clinical,
      opd: opd,
      ipd: ipd,
    );
    when(() => ipd.planDischarge(any(), any())).thenAnswer(
      (_) async => Result<IpdAdmissionDetail>.success(_detail(_ipdSummary())),
    );

    await container.read(clinicalWorkspaceControllerProvider.future);
    final ClinicalWorkspaceController controller = container.read(
      clinicalWorkspaceControllerProvider.notifier,
    );

    const ClinicalWorklistEntry entry = ClinicalWorklistEntry(
      id: 'IPD_adm-uuid-1',
      sourceQueue: 'IPD',
      encounterId: 'enc-ipd-1',
      patientId: 'pat-ipd-1',
      status: 'ADMITTED',
      stage: 'ADMITTED_IN_BED',
      currentLocation: 'Ward A | Bed 1',
      admissionId: 'adm-uuid-1',
      admissionPublicId: 'ADM000001',
    );
    await controller.selectEntry(entry);

    final AppFailure? failure = await controller.completeDisposition(
      reason: 'Recovered',
    );
    expect(failure, isNull);

    final List<Object?> captured = verify(
      () => ipd.planDischarge('ADM000001', captureAny()),
    ).captured;
    expect(
      (captured.single as Map<String, Object?>)['summary'],
      contains('Recovered'),
    );
    verifyNever(() => ipd.finalizeDischarge(any(), any()));
  });

  test(
    'discharge-planned inpatient finalizes discharge via ipd-flows',
    () async {
      final _MockClinicalRepository clinical = _MockClinicalRepository();
      final _MockOpdRepository opd = _MockOpdRepository();
      final _MockIpdRepository ipd = _MockIpdRepository();
      final ProviderContainer container = buildContainer(
        clinical: clinical,
        opd: opd,
        ipd: ipd,
      );
      when(() => ipd.finalizeDischarge(any(), any())).thenAnswer(
        (_) async => Result<IpdAdmissionDetail>.success(
          _detail(
            _ipdSummary(stage: 'DISCHARGED', admissionStatus: 'DISCHARGED'),
          ),
        ),
      );

      await container.read(clinicalWorkspaceControllerProvider.future);
      final ClinicalWorkspaceController controller = container.read(
        clinicalWorkspaceControllerProvider.notifier,
      );

      const ClinicalWorklistEntry entry = ClinicalWorklistEntry(
        id: 'IPD_adm-uuid-1',
        sourceQueue: 'IPD',
        encounterId: 'enc-ipd-1',
        patientId: 'pat-ipd-1',
        status: 'ADMITTED',
        stage: 'DISCHARGE_PLANNED',
        admissionId: 'adm-uuid-1',
        admissionPublicId: 'ADM000001',
      );
      await controller.selectEntry(entry);

      final AppFailure? failure = await controller.completeDisposition(
        reason: 'Clearance complete',
      );
      expect(failure, isNull);

      verify(() => ipd.finalizeDischarge('ADM000001', any())).called(1);
      verifyNever(() => ipd.planDischarge(any(), any()));
    },
  );

  test('requestAdmission routes through ipd-flows start endpoint', () async {
    final _MockClinicalRepository clinical = _MockClinicalRepository();
    final _MockOpdRepository opd = _MockOpdRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      clinical: clinical,
      opd: opd,
      ipd: ipd,
    );
    when(() => ipd.startAdmission(any())).thenAnswer(
      (_) async => Result<IpdAdmissionDetail>.success(_detail(_ipdSummary())),
    );

    await container.read(clinicalWorkspaceControllerProvider.future);
    final ClinicalWorkspaceController controller = container.read(
      clinicalWorkspaceControllerProvider.notifier,
    );

    const ClinicalWorklistEntry entry = ClinicalWorklistEntry(
      id: 'encounter-1',
      sourceQueue: 'ENCOUNTER',
      encounterId: 'enc-1',
      encounterPublicId: 'ENC000001',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      patientId: 'pat-1',
      patientPublicId: 'PAT000001',
      status: 'OPEN',
      stage: 'WAITING_DISPOSITION',
    );
    await controller.selectEntry(entry);

    const ClinicalCatalogOption bed = ClinicalCatalogOption(
      id: 'bed-uuid-1',
      publicId: 'BED000001',
      parentId: 'WRD000001',
      secondaryId: 'ROM000001',
      status: 'AVAILABLE',
    );

    final AppFailure? failure = await controller.requestAdmission(bed);
    expect(failure, isNull);

    final List<Object?> captured = verify(
      () => ipd.startAdmission(captureAny()),
    ).captured;
    final Map<String, Object?> payload =
        captured.single as Map<String, Object?>;
    expect(payload['patient_id'], 'PAT000001');
    expect(payload['encounter_id'], 'ENC000001');
    expect(payload['bed_id'], 'BED000001');
    expect(payload['ward_id'], 'WRD000001');
    expect(payload['room_id'], 'ROM000001');
    verifyNever(() => clinical.createAdmission(any()));
  });
}
