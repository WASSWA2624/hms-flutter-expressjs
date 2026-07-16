import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_action_dialogs.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_admission_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_harness.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _summary = IcuPatientSummary(
  id: 'ADM-1',
  admissionId: 'ADM-1',
  displayId: 'ADM0001',
  patientDisplayName: 'Ada Active',
  icuStatus: 'ACTIVE',
);

const IcuPatientDetail _detail = IcuPatientDetail(summary: _summary);

const IcuBedBoard _bedBoard = IcuBedBoard(
  wards: <IcuBedWard>[
    IcuBedWard(id: 'ward-icu-1', name: 'Medical ICU', wardType: 'ICU'),
  ],
  beds: <IcuBed>[
    IcuBed(
      id: 'BED0000001',
      label: 'Bed A',
      status: 'AVAILABLE',
      wardId: 'ward-icu-1',
      wardName: 'Medical ICU',
      wardType: 'ICU',
      roomId: 'room-1',
      roomName: 'Room 1',
    ),
  ],
);

void main() {
  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(_summary);
    registerFallbackValue(_detail);
  });

  group('IcuWorkspaceController.assignBed', () {
    test('patches admission detail and refreshes bed board on success', () async {
      final _MockIcuRepository repository = _MockIcuRepository();
      _stubInitialLoad(repository);
      const IcuPatientDetail assigned = IcuPatientDetail(
        summary: IcuPatientSummary(
          id: 'ADM-1',
          admissionId: 'ADM-1',
          displayId: 'ADM0001',
          patientDisplayName: 'Ada Active',
          icuStatus: 'ACTIVE',
          bedLabel: 'Bed A',
          hasActiveBed: true,
        ),
      );
      when(
        () => repository.assignBed(
          detail: any(named: 'detail'),
          bedId: 'BED0000001',
        ),
      ).thenAnswer((_) async => const Result<IcuPatientDetail>.success(assigned));
      when(() => repository.loadBedBoard()).thenAnswer(
        (_) async => Result<IcuBedBoard>.success(
          IcuBedBoard(
            wards: _bedBoard.wards,
            beds: const <IcuBed>[
              IcuBed(
                id: 'BED0000001',
                label: 'Bed A',
                status: 'OCCUPIED',
                wardId: 'ward-icu-1',
                wardName: 'Medical ICU',
                roomId: 'room-1',
                roomName: 'Room 1',
                occupantAdmissionId: 'ADM0001',
              ),
            ],
          ),
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          icuRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(icuWorkspaceControllerProvider.future);
      await container
          .read(icuWorkspaceControllerProvider.notifier)
          .selectPatient(_summary);

      final AppFailure? failure = await container
          .read(icuWorkspaceControllerProvider.notifier)
          .assignBed('BED0000001');

      expect(failure, isNull);
      final IcuWorkspaceState state = container
          .read(icuWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (IcuWorkspaceState value) => value,
            failure: (AppFailure f) => fail(f.code),
          );
      expect(state.selectedDetail?.summary.bedLabel, 'Bed A');
      expect(state.selectedDetail?.summary.hasActiveBed, isTrue);
      expect(state.board.items.single.bedLabel, 'Bed A');
      verify(
        () => repository.assignBed(
          detail: any(named: 'detail'),
          bedId: 'BED0000001',
        ),
      ).called(1);
      await Future<void>.delayed(Duration.zero);
      verify(() => repository.loadBedBoard()).called(greaterThanOrEqualTo(1));
    });

    test('keeps detail unchanged and skips bed-board patch on failure', () async {
      final _MockIcuRepository repository = _MockIcuRepository();
      _stubInitialLoad(repository);
      const AppFailure expectedFailure = AppFailure.network();
      when(
        () => repository.assignBed(
          detail: any(named: 'detail'),
          bedId: 'BED0000001',
        ),
      ).thenAnswer(
        (_) async => const Result<IcuPatientDetail>.failure(expectedFailure),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          icuRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(icuWorkspaceControllerProvider.future);
      await container
          .read(icuWorkspaceControllerProvider.notifier)
          .selectPatient(_summary);

      final AppFailure? failure = await container
          .read(icuWorkspaceControllerProvider.notifier)
          .assignBed('BED0000001');

      expect(failure, expectedFailure);
      final IcuWorkspaceState state = container
          .read(icuWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (IcuWorkspaceState value) => value,
            failure: (AppFailure f) => fail(f.code),
          );
      expect(state.selectedDetail?.summary.hasActiveBed, isFalse);
      expect(state.lastFailure, expectedFailure);
      verifyNever(() => repository.loadBedBoard());
    });
  });

  testWidgets(
    'assign bed dialog reuses ClinicalAdmissionActionDialog with Cancel/primary',
    (WidgetTester tester) async {
      final _MockIcuRepository repository = _MockIcuRepository();
      _stubInitialLoad(repository);
      when(() => repository.loadBedBoard()).thenAnswer(
        (_) async => const Result<IcuBedBoard>.success(_bedBoard),
      );

      await pumpLocalizedWidget(
        tester,
        ProviderScope(
          overrides: [
            icuRepositoryProvider.overrideWithValue(repository),
          ],
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              return AppButton.primary(
                label: 'Open assign bed',
                onPressed: () async {
                  await ref
                      .read(icuWorkspaceControllerProvider.future);
                  await ref
                      .read(icuWorkspaceControllerProvider.notifier)
                      .selectPatient(_summary);
                  if (!context.mounted) {
                    return;
                  }
                  await openIcuAssignBedDialog(context);
                },
              );
            },
          ),
        ),
        size: const Size(900, 800),
        padding: EdgeInsets.zero,
      );

      await tester.tap(find.text('Open assign bed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.byType(ClinicalAdmissionActionDialog), findsOneWidget);
      expect(find.text('ASSIGN ICU BED'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Assign ICU bed'), findsWidgets);
      expect(find.text('Ward'), findsOneWidget);
      expect(find.text('Room'), findsOneWidget);
      expect(find.text('Bed'), findsOneWidget);
      expect(find.textContaining('Ada Active'), findsNothing);
    },
  );

  testWidgets(
    'assign bed dialog stays open and preserves selection after failure',
    (WidgetTester tester) async {
      final _MockIcuRepository repository = _MockIcuRepository();
      _stubInitialLoad(repository);
      when(() => repository.loadBedBoard()).thenAnswer(
        (_) async => const Result<IcuBedBoard>.success(_bedBoard),
      );
      final Completer<AppFailure> completer = Completer<AppFailure>();
      when(
        () => repository.assignBed(
          detail: any(named: 'detail'),
          bedId: 'BED0000001',
        ),
      ).thenAnswer((_) async {
        final AppFailure failure = await completer.future;
        return Result<IcuPatientDetail>.failure(failure);
      });

      await pumpLocalizedWidget(
        tester,
        ProviderScope(
          overrides: [
            icuRepositoryProvider.overrideWithValue(repository),
          ],
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              return AppButton.primary(
                label: 'Open assign bed',
                onPressed: () async {
                  await ref.read(icuWorkspaceControllerProvider.future);
                  await ref
                      .read(icuWorkspaceControllerProvider.notifier)
                      .selectPatient(_summary);
                  if (!context.mounted) {
                    return;
                  }
                  await openIcuAssignBedDialog(context);
                },
              );
            },
          ),
        ),
        size: const Size(900, 800),
        padding: EdgeInsets.zero,
      );

      await tester.tap(find.text('Open assign bed'));
      await tester.pumpAndSettle();

      await _selectSearchableOption(tester, 0, 'Medical ICU');
      await _selectSearchableOption(tester, 1, 'Room 1');
      await _selectSearchableOption(tester, 2, 'Bed A');

      await tester.tap(find.text('Assign ICU bed').last);
      await tester.pump();

      expect(_button(tester, 'Cancel').enabled, isFalse);
      expect(_button(tester, 'Assign ICU bed').isLoading, isTrue);

      completer.complete(const AppFailure.network());
      await tester.pumpAndSettle();

      expect(find.byType(ClinicalAdmissionActionDialog), findsOneWidget);
      expect(find.text('ASSIGN ICU BED'), findsOneWidget);
      expect(_button(tester, 'Cancel').enabled, isTrue);
    },
  );
}

void _stubInitialLoad(_MockIcuRepository repository) {
  when(() => repository.listIcuBoard(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<IcuPatientSummary>>.success(
      AppPage<IcuPatientSummary>(
        items: const <IcuPatientSummary>[_summary],
        request: (invocation.positionalArguments.single as IcuBoardQuery)
            .pageRequest,
        totalItemCount: 1,
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer(
    (_) async => const Result<IcuPatientDetail>.success(_detail),
  );
}

Future<void> _selectSearchableOption(
  WidgetTester tester,
  int fieldIndex,
  String optionLabel,
) async {
  await tester.tap(find.byType(EditableText).at(fieldIndex));
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .descendant(
          of: find.byType(MenuItemButton),
          matching: find.textContaining(optionLabel),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

AppButton _button(WidgetTester tester, String label) {
  return tester.widget<AppButton>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(AppButton),
    ).first,
  );
}
