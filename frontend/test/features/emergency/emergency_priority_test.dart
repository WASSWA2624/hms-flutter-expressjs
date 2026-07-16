import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/emergency/data/repositories/emergency_repository_impl.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/domain/repositories/emergency_repository.dart';
import 'package:hosspi_hms/features/emergency/presentation/controllers/emergency_workspace_controller.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_dialogs.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_harness.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const EmergencyBoardQuery());
    registerFallbackValue(_originalDetail());
    registerFallbackValue(_originalDetail().summary);
  });

  group('EmergencyWorkspaceController updatePriority', () {
    test(
      'patches summary priority, board row, and critical badge on success',
      () async {
        final _MockEmergencyRepository repository = _MockEmergencyRepository();
        var persisted = false;
        _stubInitialLoad(
          repository,
          boardSummary: () =>
              persisted ? _updatedDetail().summary : _originalDetail().summary,
          detail: () =>
              persisted ? _updatedDetail() : _originalDetail(),
        );
        when(
          () => repository.updateCasePriority(
            detail: any(named: 'detail'),
            severity: 'MEDIUM',
          ),
        ).thenAnswer((_) async {
          persisted = true;
          return Result<EmergencyCaseDetail>.success(_updatedDetail());
        });
        final ProviderContainer container = _container(repository);
        await container.read(emergencyWorkspaceControllerProvider.future);
        await container
            .read(emergencyWorkspaceControllerProvider.notifier)
            .selectCase(_originalDetail().summary);

        final AppFailure? failure = await container
            .read(emergencyWorkspaceControllerProvider.notifier)
            .updatePriority('MEDIUM');

        final EmergencyWorkspaceState state = _state(container);
        expect(failure, isNull);
        expect(state.selectedDetail?.summary.severity, 'MEDIUM');
        expect(state.board.items.single.severity, 'MEDIUM');
        expect(state.criticalCount, 0);
        expect(state.isSaving, isFalse);
        verify(
          () => repository.updateCasePriority(
            detail: any(named: 'detail'),
            severity: 'MEDIUM',
          ),
        ).called(1);
      },
    );

    test('keeps summary and board unchanged when persistence fails', () async {
      final _MockEmergencyRepository repository = _MockEmergencyRepository();
      _stubInitialLoad(repository);
      const AppFailure expectedFailure = AppFailure.network();
      when(
        () => repository.updateCasePriority(
          detail: any(named: 'detail'),
          severity: 'MEDIUM',
        ),
      ).thenAnswer(
        (_) async => const Result<EmergencyCaseDetail>.failure(expectedFailure),
      );
      final ProviderContainer container = _container(repository);
      await container.read(emergencyWorkspaceControllerProvider.future);
      await container
          .read(emergencyWorkspaceControllerProvider.notifier)
          .selectCase(_originalDetail().summary);

      final AppFailure? failure = await container
          .read(emergencyWorkspaceControllerProvider.notifier)
          .updatePriority('MEDIUM');

      final EmergencyWorkspaceState state = _state(container);
      expect(failure, expectedFailure);
      expect(state.selectedDetail?.summary.severity, 'HIGH');
      expect(state.board.items.single.severity, 'HIGH');
      expect(state.criticalCount, 1);
      expect(state.lastFailure, expectedFailure);
      expect(state.isSaving, isFalse);
    });
  });

  group('showEmergencyPriorityDialog', () {
    testWidgets(
      'uses AppSelectActionDialog with Edit/Cancel chrome and no patient name',
      (WidgetTester tester) async {
        await pumpLocalizedWidget(
          tester,
          Builder(
            builder: (BuildContext context) {
              return AppButton.primary(
                label: 'Open',
                leadingIcon: AppActionIcons.priority,
                onPressed: () {
                  unawaited(
                    showEmergencyPriorityDialog(
                      context: context,
                      initialSeverity: 'HIGH',
                      onSubmit: (_) async => null,
                    ),
                  );
                },
              );
            },
          ),
          padding: EdgeInsets.zero,
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final AppDialog dialog = tester.widget<AppDialog>(
          find.byType(AppDialog),
        );
        expect(dialog.closeEnabled, isTrue);
        expect(find.byType(AppSelectActionDialog<String>), findsOneWidget);
        expect(find.text('PRIORITY'), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Jane Doe'), findsNothing);
        expect(find.byIcon(AppActionIcons.priority), findsWidgets);
        expect(find.byIcon(AppActionIcons.edit), findsWidgets);
        expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
      },
    );

    testWidgets('Cancel pops false without mutating priority', (
      WidgetTester tester,
    ) async {
      bool? result;
      var submitted = false;

      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open',
              leadingIcon: AppActionIcons.priority,
              onPressed: () async {
                result = await showEmergencyPriorityDialog(
                  context: context,
                  initialSeverity: 'HIGH',
                  onSubmit: (_) async {
                    submitted = true;
                    return null;
                  },
                );
              },
            );
          },
        ),
        padding: EdgeInsets.zero,
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(submitted, isFalse);
    });

    testWidgets(
      'failure keeps dialog open and blocks dismiss while saving',
      (WidgetTester tester) async {
        final Completer<AppFailure?> completer = Completer<AppFailure?>();
        String? submittedSeverity;

        await pumpLocalizedWidget(
          tester,
          Builder(
            builder: (BuildContext context) {
              return AppButton.primary(
                label: 'Open',
                leadingIcon: AppActionIcons.priority,
                onPressed: () {
                  unawaited(
                    showEmergencyPriorityDialog(
                      context: context,
                      initialSeverity: 'HIGH',
                      onSubmit: (String severity) {
                        submittedSeverity = severity;
                        return completer.future;
                      },
                    ),
                  );
                },
              );
            },
          ),
          size: const Size(390, 700),
          padding: EdgeInsets.zero,
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AppButton, 'Edit'));
        await tester.pump();

        expect(submittedSeverity, 'HIGH');
        expect(_button(tester, 'Cancel').enabled, isFalse);
        expect(_button(tester, 'Edit').isLoading, isTrue);
        expect(
          tester.widget<AppDialog>(find.byType(AppDialog)).closeEnabled,
          isFalse,
        );

        completer.complete(const AppFailure.network());
        await tester.pumpAndSettle();

        expect(find.byType(AppSelectActionDialog<String>), findsOneWidget);
        expect(find.text('PRIORITY'), findsOneWidget);
        expect(_button(tester, 'Cancel').enabled, isTrue);
        expect(_button(tester, 'Edit').isLoading, isFalse);
      },
    );

    testWidgets('successful edit pops true after persisted priority', (
      WidgetTester tester,
    ) async {
      bool? result;

      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open',
              leadingIcon: AppActionIcons.priority,
              onPressed: () async {
                result = await showEmergencyPriorityDialog(
                  context: context,
                  initialSeverity: 'HIGH',
                  onSubmit: (_) async => null,
                );
              },
            );
          },
        ),
        padding: EdgeInsets.zero,
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Edit'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(AppSelectActionDialog<String>), findsNothing);
    });
  });
}

AppButton _button(WidgetTester tester, String label) {
  return tester.widget<AppButton>(
    find.byWidgetPredicate(
      (Widget widget) => widget is AppButton && widget.label == label,
    ),
  );
}

ProviderContainer _container(_MockEmergencyRepository repository) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Object?>[
      emergencyRepositoryProvider.overrideWithValue(repository),
    ].cast(),
  );
  addTearDown(container.dispose);
  return container;
}

void _stubInitialLoad(
  _MockEmergencyRepository repository, {
  EmergencyCaseSummary Function()? boardSummary,
  EmergencyCaseDetail Function()? detail,
}) {
  when(() => repository.listEmergencyBoard(any())).thenAnswer((invocation) {
    final EmergencyBoardQuery query =
        invocation.positionalArguments.single as EmergencyBoardQuery;
    return Future<Result<AppPage<EmergencyCaseSummary>>>.value(
      Result<AppPage<EmergencyCaseSummary>>.success(
        AppPage<EmergencyCaseSummary>(
          items: <EmergencyCaseSummary>[
            boardSummary?.call() ?? _originalDetail().summary,
          ],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer(
    (_) async => Result<EmergencyCaseDetail>.success(
      detail?.call() ?? _originalDetail(),
    ),
  );
}

EmergencyWorkspaceState _state(ProviderContainer container) {
  return container
      .read(emergencyWorkspaceControllerProvider)
      .requireValue
      .when(
        success: (EmergencyWorkspaceState state) => state,
        failure: (AppFailure failure) => throw StateError(failure.code),
      );
}

EmergencyCaseDetail _originalDetail() {
  return const EmergencyCaseDetail(
    summary: EmergencyCaseSummary(
      id: 'EME000001',
      displayId: 'EME000001',
      patientId: 'PAT000001',
      patientDisplayId: 'PAT000001',
      patientDisplayName: 'Jane Doe',
      severity: 'HIGH',
      status: 'OPEN',
    ),
  );
}

EmergencyCaseDetail _updatedDetail() {
  final EmergencyCaseDetail original = _originalDetail();
  return original.copyWith(
    summary: original.summary.copyWith(severity: 'MEDIUM'),
  );
}
