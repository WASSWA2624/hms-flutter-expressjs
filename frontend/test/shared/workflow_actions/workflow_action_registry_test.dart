import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_executor.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_registry.dart';

void main() {
  setUpAll(() {
    initializeWorkflowActionRegistry();
  });

  group('WorkflowActionRegistry', () {
    final WorkflowActionRegistry registry = WorkflowActionRegistry.instance;

    group('canonicalize', () {
      test('returns canonical code for known codes', () {
        expect(registry.canonicalize('PAY_CONSULTATION'), 'PAY_CONSULTATION');
        expect(registry.canonicalize('RECORD_VITALS'), 'RECORD_VITALS');
        expect(registry.canonicalize('ASSIGN_DOCTOR'), 'ASSIGN_DOCTOR');
        expect(registry.canonicalize('DOCTOR_REVIEW'), 'DOCTOR_REVIEW');
        expect(registry.canonicalize('COLLECT_SAMPLE'), 'COLLECT_SAMPLE');
        expect(registry.canonicalize('PERFORM_IMAGING'), 'PERFORM_IMAGING');
        expect(registry.canonicalize('DISPENSE_MEDICINE'), 'DISPENSE_MEDICINE');
        expect(registry.canonicalize('DISPOSITION'), 'DISPOSITION');
        expect(registry.canonicalize('ADMISSION_HANDOFF'), 'ADMISSION_HANDOFF');
      });

      test('resolves legacy aliases to canonical codes', () {
        expect(
          registry.canonicalize('WAITING_CONSULTATION_PAYMENT'),
          'PAY_CONSULTATION',
        );
        expect(registry.canonicalize('PAYMENT_DUE'), 'PAY_CONSULTATION');
        expect(registry.canonicalize('WAITING_VITALS'), 'RECORD_VITALS');
        expect(registry.canonicalize('VITALS_NEEDED'), 'RECORD_VITALS');
        expect(
          registry.canonicalize('WAITING_DOCTOR_ASSIGNMENT'),
          'ASSIGN_DOCTOR',
        );
        expect(registry.canonicalize('DOCTOR_NEEDED'), 'ASSIGN_DOCTOR');
        expect(registry.canonicalize('WAITING_DOCTOR_REVIEW'), 'DOCTOR_REVIEW');
        expect(registry.canonicalize('WITH_DOCTOR'), 'DOCTOR_REVIEW');
        expect(registry.canonicalize('LAB_REQUESTED'), 'COLLECT_SAMPLE');
        expect(registry.canonicalize('LAB_PENDING'), 'COLLECT_SAMPLE');
        expect(registry.canonicalize('RADIOLOGY_REQUESTED'), 'PERFORM_IMAGING');
        expect(registry.canonicalize('PHARMACY_PENDING'), 'DISPENSE_MEDICINE');
        expect(registry.canonicalize('DECISION_NEEDED'), 'DISPOSITION');
        expect(registry.canonicalize('ADMISSION_PENDING'), 'ADMISSION_HANDOFF');
      });

      test('normalizes case and whitespace', () {
        expect(
          registry.canonicalize('  pay_consultation  '),
          'PAY_CONSULTATION',
        );
        expect(registry.canonicalize('waiting_vitals'), 'RECORD_VITALS');
        expect(registry.canonicalize('Doctor_Needed'), 'ASSIGN_DOCTOR');
      });

      test('returns input for unknown codes', () {
        expect(registry.canonicalize('UNKNOWN_CODE'), 'UNKNOWN_CODE');
        expect(registry.canonicalize('MADE_UP'), 'MADE_UP');
      });
    });

    group('isRegistered', () {
      test('returns true for canonical codes', () {
        expect(registry.isRegistered('PAY_CONSULTATION'), isTrue);
        expect(registry.isRegistered('RECORD_VITALS'), isTrue);
        expect(registry.isRegistered('ASSIGN_DOCTOR'), isTrue);
        expect(registry.isRegistered('COLLECT_SAMPLE'), isTrue);
        expect(registry.isRegistered('PERFORM_IMAGING'), isTrue);
        expect(registry.isRegistered('DISPENSE_MEDICINE'), isTrue);
      });

      test('returns true for legacy aliases', () {
        expect(registry.isRegistered('WAITING_CONSULTATION_PAYMENT'), isTrue);
        expect(registry.isRegistered('WAITING_VITALS'), isTrue);
        expect(registry.isRegistered('LAB_PENDING'), isTrue);
        expect(registry.isRegistered('PHARMACY_REQUESTED'), isTrue);
      });

      test('returns false for unregistered codes', () {
        expect(registry.isRegistered('UNKNOWN_CODE'), isFalse);
        expect(registry.isRegistered('NOT_A_REAL_ACTION'), isFalse);
      });
    });

    group('definitionFor', () {
      test('returns definition for known canonical codes', () {
        final def = registry.definitionFor('PAY_CONSULTATION');
        expect(def, isNotNull);
        expect(def!.code, 'PAY_CONSULTATION');
        expect(def.targetModule, 'billing');
        expect(def.mode, WorkflowActionMode.dialog);
        expect(def.icon, Icons.payments_outlined);
      });

      test('returns null for unknown codes', () {
        expect(registry.definitionFor('UNKNOWN'), isNull);
      });

      test('returns null for alias codes (must canonicalize first)', () {
        expect(registry.definitionFor('WAITING_VITALS'), isNull);
        final canonical = registry.canonicalize('WAITING_VITALS');
        expect(registry.definitionFor(canonical), isNotNull);
      });
    });

    group('registeredCodes', () {
      test('contains all expected canonical codes', () {
        final codes = registry.registeredCodes.toList();
        expect(codes, contains('PAY_CONSULTATION'));
        expect(codes, contains('RECORD_VITALS'));
        expect(codes, contains('ASSIGN_DOCTOR'));
        expect(codes, contains('DOCTOR_REVIEW'));
        expect(codes, contains('COLLECT_SAMPLE'));
        expect(codes, contains('PERFORM_IMAGING'));
        expect(codes, contains('DISPENSE_MEDICINE'));
        expect(codes, contains('DISPOSITION'));
        expect(codes, contains('ADMISSION_HANDOFF'));
        expect(codes, contains('ADMITTED'));
        expect(codes, contains('DISCHARGE_PLANNING'));
        expect(codes, contains('ASSIGN_BED'));
        expect(codes, contains('INSURANCE_PREAUTH'));
        expect(codes, contains('THEATRE_SCHEDULING'));
        expect(codes, contains('PHYSIOTHERAPY_SESSION'));
      });

      test('includes IPD-specific codes', () {
        final codes = registry.registeredCodes.toList();
        expect(codes, contains('RECORD_NURSING_NOTE'));
        expect(codes, contains('APPROVE_TRANSFER'));
        expect(codes, contains('START_TRANSFER'));
        expect(codes, contains('COMPLETE_TRANSFER'));
        expect(codes, contains('COMPLETE_THEATRE_HANDOVER'));
        expect(codes, contains('FINALIZE_DISCHARGE'));
      });
    });

    group('resolve', () {
      testWidgets('returns null for empty action code', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: _ResolveTestWidget(actionCode: '')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('null'), findsOneWidget);
      });

      testWidgets('returns unsupported for unknown code', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: _ResolveTestWidget(actionCode: 'FAKE_CODE_XYZ'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('unsupported'), findsOneWidget);
      });

      testWidgets('resolves PAY_CONSULTATION action', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: _ResolveTestWidget(actionCode: 'PAY_CONSULTATION'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('billing'), findsOneWidget);
      });

      testWidgets('resolves legacy alias WAITING_VITALS', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: _ResolveTestWidget(actionCode: 'WAITING_VITALS'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('nursing'), findsOneWidget);
      });

      testWidgets(
        'receptionist denied RECORD_VITALS falls back to Change doctor',
        (tester) async {
          late WorkflowAction? action;
          final AppAccessPolicy policy = AppAccessPolicy.fromSession(
            AuthSession(
              tokens: SessionTokens(accessToken: 'access-token'),
              user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
              permissions: <AppPermission>{
                AppPermissions.patientRead,
                AppPermissions.patientWrite,
              },
              moduleEntitlements: const <AppModuleEntitlement>[
                AppModuleEntitlement(
                  code: 'scheduling-queue',
                  licenseStatus: 'ACTIVE',
                ),
              ],
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Builder(
                builder: (BuildContext context) {
                  action = WorkflowActionRegistry.instance.resolve(
                    context,
                    const WorkflowActionContext(
                      encounterId: 'enc-123',
                      nextStep: 'RECORD_VITALS',
                      assignedStaffId: 'USR-DOC001',
                    ),
                    policy: policy,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          final WorkflowAction resolved = action!;
          expect(resolved.code, 'ASSIGN_DOCTOR');
          expect(resolved.isAvailable, isTrue);
          expect(resolved.label, 'Change doctor');
        },
      );
    });
  });

  group('WorkflowAction', () {
    test('effectiveActionCode prefers displayNextStep', () {
      const ctx = WorkflowActionContext(
        encounterId: 'enc-1',
        stage: 'WITH_DOCTOR',
        nextStep: 'RECORD_VITALS',
        displayNextStep: 'PAY_CONSULTATION',
      );
      expect(ctx.effectiveActionCode, 'PAY_CONSULTATION');
    });

    test('effectiveActionCode falls back to nextStep', () {
      const ctx = WorkflowActionContext(
        encounterId: 'enc-1',
        stage: 'WITH_DOCTOR',
        nextStep: 'RECORD_VITALS',
      );
      expect(ctx.effectiveActionCode, 'RECORD_VITALS');
    });

    test('effectiveActionCode falls back to stage', () {
      const ctx = WorkflowActionContext(
        encounterId: 'enc-1',
        stage: 'WITH_DOCTOR',
      );
      expect(ctx.effectiveActionCode, 'WITH_DOCTOR');
    });

    test('effectiveActionCode normalizes to uppercase', () {
      const ctx = WorkflowActionContext(
        encounterId: 'enc-1',
        nextStep: '  pay_consultation  ',
      );
      expect(ctx.effectiveActionCode, 'PAY_CONSULTATION');
    });
  });

  group('dialogOpenerFor', () {
    test('returns null when no dialog opener is registered', () {
      expect(
        WorkflowActionRegistry.instance.dialogOpenerFor('RECORD_VITALS'),
        isNull,
      );
    });

    test('returns opener after registerDialogOpener', () {
      WorkflowActionRegistry.instance.registerDialogOpener(
        'RECORD_VITALS',
        (_, _, _) async => true,
      );
      final opener = WorkflowActionRegistry.instance.dialogOpenerFor(
        'RECORD_VITALS',
      );
      expect(opener, isNotNull);
    });

    test('postSuccessCallbackFor returns callback', () {
      WorkflowActionRegistry.instance.registerDialogOpener(
        'DOCTOR_REVIEW',
        (_, _, _) async => true,
        onSuccess: (_) {},
      );
      final callback = WorkflowActionRegistry.instance.postSuccessCallbackFor(
        'DOCTOR_REVIEW',
      );
      expect(callback, isNotNull);
    });
  });

  group('WorkflowActionExecutor', () {
    test('isExecuting is false when idle', () {
      expect(WorkflowActionExecutor.instance.isExecuting, isFalse);
    });

    testWidgets('execute returns denied for permission-denied action', (
      WidgetTester tester,
    ) async {
      late WorkflowActionResult result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (BuildContext context) {
              Future.microtask(() async {
                result = await WorkflowActionExecutor.instance.execute(
                  context,
                  const WorkflowAction(
                    code: 'PAY_CONSULTATION',
                    label: 'Pay',
                    icon: Icons.payment,
                    mode: WorkflowActionMode.dialog,
                    targetModule: 'billing',
                    availability: WorkflowActionAvailability.permissionDenied,
                    unavailableReason: 'No access',
                  ),
                );
              });
              return const Scaffold();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(result, WorkflowActionResult.denied);
    });

    testWidgets('execute returns unavailable for unsupported action', (
      WidgetTester tester,
    ) async {
      late WorkflowActionResult result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (BuildContext context) {
              Future.microtask(() async {
                result = await WorkflowActionExecutor.instance.execute(
                  context,
                  const WorkflowAction(
                    code: 'FAKE',
                    label: 'Fake',
                    icon: Icons.error,
                    mode: WorkflowActionMode.route,
                    targetModule: 'unknown',
                    availability: WorkflowActionAvailability.unsupported,
                  ),
                );
              });
              return const Scaffold();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(result, WorkflowActionResult.unavailable);
    });
  });
}

class _ResolveTestWidget extends StatelessWidget {
  const _ResolveTestWidget({required this.actionCode});

  final String actionCode;

  @override
  Widget build(BuildContext context) {
    final action = WorkflowActionRegistry.instance.resolve(
      context,
      WorkflowActionContext(encounterId: 'enc-123', nextStep: actionCode),
    );
    if (action == null) {
      return const Text('null');
    }
    if (action.availability == WorkflowActionAvailability.unsupported) {
      return const Text('unsupported');
    }
    return Text(action.targetModule);
  }
}
