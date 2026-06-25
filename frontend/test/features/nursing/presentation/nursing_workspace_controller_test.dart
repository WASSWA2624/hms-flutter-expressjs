import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/nursing/data/repositories/nursing_repository_impl.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/domain/repositories/nursing_repository.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockNursingRepository extends Mock implements NursingRepository {}

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

const NursingPatientSummary _summary = NursingPatientSummary(
  id: 'adm-1',
  admissionId: 'adm-1',
  displayId: 'ADM000001',
  patientId: 'PAT000001',
  patientDisplayName: 'Jane Inpatient',
  encounterDisplayId: 'ENC000001',
  stage: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward A',
  bedDisplayLabel: 'Bed 1',
);

NursingPatientDetail _detail({
  List<NursingNoteRecord> notes = const <NursingNoteRecord>[],
}) {
  return NursingPatientDetail(summary: _summary, nursingNotes: notes);
}

void main() {
  setUpAll(() {
    registerFallbackValue(const NursingWorklistQuery());
    registerFallbackValue(_summary);
    registerFallbackValue(<String, Object?>{});
  });

  ProviderContainer buildContainer({
    required _MockNursingRepository nursing,
    required _MockClinicalRepository clinical,
  }) {
    when(() => nursing.listWardPatients(any())).thenAnswer(
      (invocation) async => Result<AppPage<NursingPatientSummary>>.success(
        AppPage<NursingPatientSummary>(
          items: const <NursingPatientSummary>[_summary],
          request:
              (invocation.positionalArguments.single as NursingWorklistQuery)
                  .pageRequest,
          totalItemCount: 1,
        ),
      ),
    );
    when(
      () => nursing.loadPatientDetail(any()),
    ).thenAnswer((_) async => Result<NursingPatientDetail>.success(_detail()));

    final ProviderContainer container = ProviderContainer(
      overrides: [
        nursingRepositoryProvider.overrideWithValue(nursing),
        clinicalRepositoryProvider.overrideWithValue(clinical),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'selectPatientByDisplayId resolves an admission from the worklist',
    () async {
      final _MockNursingRepository nursing = _MockNursingRepository();
      final _MockClinicalRepository clinical = _MockClinicalRepository();
      final ProviderContainer container = buildContainer(
        nursing: nursing,
        clinical: clinical,
      );

      await container.read(nursingWorkspaceControllerProvider.future);
      final NursingWorkspaceController controller = container.read(
        nursingWorkspaceControllerProvider.notifier,
      );

      final NursingPatientSummary? resolved = await controller
          .selectPatientByDisplayId('ADM000001');
      expect(resolved, isNotNull);
      expect(resolved!.admissionId, 'adm-1');
      verify(
        () => nursing.loadPatientDetail(any()),
      ).called(greaterThanOrEqualTo(1));
    },
  );

  test(
    'orderLab posts encounter and patient context to the clinical repository',
    () async {
      final _MockNursingRepository nursing = _MockNursingRepository();
      final _MockClinicalRepository clinical = _MockClinicalRepository();
      when(
        () => clinical.createLabOrder(any()),
      ).thenAnswer((_) async => const Result<void>.success(null));
      final ProviderContainer container = buildContainer(
        nursing: nursing,
        clinical: clinical,
      );

      await container.read(nursingWorkspaceControllerProvider.future);
      final NursingWorkspaceController controller = container.read(
        nursingWorkspaceControllerProvider.notifier,
      );
      await controller.selectPatientByDisplayId('ADM000001');

      final AppFailure? failure = await controller.orderLab(
        labTestIds: const <String>['LAB000001'],
        labPanelIds: const <String>[],
      );
      expect(failure, isNull);

      final List<Object?> captured = verify(
        () => clinical.createLabOrder(captureAny()),
      ).captured;
      final Map<String, Object?> payload =
          captured.first as Map<String, Object?>;
      expect(payload['encounter_id'], 'ENC000001');
      expect(payload['patient_id'], 'PAT000001');
      expect(payload['requested_tests'], isA<List<Object?>>());
    },
  );

  test('addCarePlan records a plan against the selected admission', () async {
    final _MockNursingRepository nursing = _MockNursingRepository();
    final _MockClinicalRepository clinical = _MockClinicalRepository();
    when(
      () => nursing.addCarePlan(any(), any()),
    ).thenAnswer((_) async => Result<NursingPatientDetail>.success(_detail()));
    final ProviderContainer container = buildContainer(
      nursing: nursing,
      clinical: clinical,
    );

    await container.read(nursingWorkspaceControllerProvider.future);
    final NursingWorkspaceController controller = container.read(
      nursingWorkspaceControllerProvider.notifier,
    );
    await controller.selectPatientByDisplayId('ADM000001');

    final AppFailure? failure = await controller.addCarePlan('Hourly turns');
    expect(failure, isNull);

    final List<Object?> captured = verify(
      () => nursing.addCarePlan(any(), captureAny()),
    ).captured;
    final Map<String, Object?> payload = captured.first as Map<String, Object?>;
    expect(payload['plan'], 'Hourly turns');
    expect(payload['encounter_id'], 'ENC000001');
  });
}
