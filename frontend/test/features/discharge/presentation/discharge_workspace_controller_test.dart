import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/domain/repositories/discharge_repository.dart';
import 'package:hosspi_hms/features/discharge/presentation/controllers/discharge_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockDischargeRepository extends Mock implements DischargeRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const DischargeWorklistQuery());
    registerFallbackValue(<String, Object?>{});
  });

  group('DischargeWorkspaceController', () {
    test(
      'selectAdmissionByDisplayId loads admission detail by display id',
      () async {
        final _MockDischargeRepository repository = _MockDischargeRepository();
        const IpdAdmissionDetail ipd = IpdAdmissionDetail(
          summary: IpdAdmissionSummary(
            id: 'uuid-1',
            displayId: 'ADM-001',
            stage: 'DISCHARGE_PLANNED',
          ),
        );
        const DischargeAdmissionDetail detail = DischargeAdmissionDetail(
          ipd: ipd,
        );

        when(() => repository.listQueue(any())).thenAnswer(
          (_) async => const Result<AppPage<IpdAdmissionSummary>>.success(
            AppPage<IpdAdmissionSummary>(
              items: <IpdAdmissionSummary>[],
              request: AppPageRequest(pageSize: 12),
            ),
          ),
        );
        when(() => repository.loadReferenceData()).thenAnswer(
          (_) async => const Result<DischargeReferenceData>.success(
            DischargeReferenceData(),
          ),
        );
        when(() => repository.getAdmissionDetail('ADM-001')).thenAnswer(
          (_) async => const Result<DischargeAdmissionDetail>.success(detail),
        );

        final ProviderContainer container = ProviderContainer(
          overrides: [
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            dischargeRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        await container.read(dischargeWorkspaceControllerProvider.future);

        final AppFailure? failure = await container
            .read(dischargeWorkspaceControllerProvider.notifier)
            .selectAdmissionByDisplayId('ADM-001');

        expect(failure, isNull);
        verify(() => repository.getAdmissionDetail('ADM-001')).called(1);
      },
    );

    test('completeDischarge syncs clearance before finalize', () async {
      final _MockDischargeRepository repository = _MockDischargeRepository();
      const DischargeAdmissionDetail detail = DischargeAdmissionDetail(
        ipd: IpdAdmissionDetail(
          summary: IpdAdmissionSummary(
            id: 'ADM-001',
            stage: 'DISCHARGE_PLANNED',
          ),
          latestDischargeSummary: IpdDischargeSummary(
            id: 'DS-001',
            status: 'PLANNED',
            summary: 'Ready for discharge',
            clearance: IpdDischargeClearance(
              summaryReady: true,
              pendingOrdersReviewed: true,
              pharmacyCleared: true,
              billingCleared: true,
              nursingCleared: true,
              documentsReady: true,
              patientExited: true,
            ),
          ),
        ),
      );
      Map<String, Object?>? clearancePayload;
      Map<String, Object?>? finalizePayload;

      when(() => repository.listQueue(any())).thenAnswer(
        (_) async => Result<AppPage<IpdAdmissionSummary>>.success(
          AppPage<IpdAdmissionSummary>(
            items: <IpdAdmissionSummary>[detail.summary],
            request: const AppPageRequest(pageSize: 12),
          ),
        ),
      );
      when(() => repository.loadReferenceData()).thenAnswer(
        (_) async => const Result<DischargeReferenceData>.success(
          DischargeReferenceData(),
        ),
      );
      when(() => repository.getAdmissionDetail('ADM-001')).thenAnswer(
        (_) async => const Result<DischargeAdmissionDetail>.success(detail),
      );
      when(() => repository.updateDischargeClearance(any(), any())).thenAnswer((
        invocation,
      ) async {
        clearancePayload =
            invocation.positionalArguments[1] as Map<String, Object?>;
        return const Result<void>.success(null);
      });
      when(() => repository.finalizeDischarge(any(), any())).thenAnswer((
        invocation,
      ) async {
        finalizePayload =
            invocation.positionalArguments[1] as Map<String, Object?>;
        return const Result<void>.success(null);
      });

      final ProviderContainer container = ProviderContainer(
        overrides: [
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          dischargeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(dischargeWorkspaceControllerProvider.future);
      await container
          .read(dischargeWorkspaceControllerProvider.notifier)
          .selectAdmission(detail.summary);

      final AppFailure? failure = await container
          .read(dischargeWorkspaceControllerProvider.notifier)
          .completeDischarge();

      expect(failure, isNull);
      expect(clearancePayload, containsPair('patient_exited', true));
      expect(finalizePayload, containsPair('summary', 'Ready for discharge'));
      verify(() => repository.updateDischargeClearance(any(), any())).called(1);
      verify(() => repository.finalizeDischarge(any(), any())).called(1);
    });
  });
}
