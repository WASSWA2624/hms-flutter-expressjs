import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/features/reception/presentation/controllers/reception_payment_gate_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const BillingWorkspaceQuery());
  });

  test(
    'refresh is single-flight and all callers await the same load',
    () async {
      final _MockBillingRepository repository = _MockBillingRepository();
      final Completer<Result<AppPage<BillingWorkItem>>> refreshCompleter =
          Completer<Result<AppPage<BillingWorkItem>>>();
      var calls = 0;
      when(() => repository.listWorkItems(any())).thenAnswer((invocation) {
        calls += 1;
        final BillingWorkspaceQuery query =
            invocation.positionalArguments.single as BillingWorkspaceQuery;
        if (calls == 1) {
          return Future<Result<AppPage<BillingWorkItem>>>.value(
            Result<AppPage<BillingWorkItem>>.success(
              AppPage<BillingWorkItem>(
                items: const <BillingWorkItem>[],
                request: query.pageRequest,
              ),
            ),
          );
        }
        return refreshCompleter.future;
      });
      final ProviderContainer container = _container(repository);
      addTearDown(container.dispose);
      await container.read(receptionPaymentGateControllerProvider.future);

      final ReceptionPaymentGateController controller = container.read(
        receptionPaymentGateControllerProvider.notifier,
      );
      final Future<AppFailure?> first = controller.refresh();
      final Future<AppFailure?> second = controller.refresh();
      expect(identical(first, second), isTrue);
      expect(calls, 2);

      refreshCompleter.complete(
        const Result<AppPage<BillingWorkItem>>.success(
          AppPage<BillingWorkItem>(
            items: <BillingWorkItem>[],
            request: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
          ),
        ),
      );
      expect(await first, isNull);
      expect(await second, isNull);
      expect(calls, 2);
    },
  );

  test('failed refresh retains the previous payment-gate entries', () async {
    final _MockBillingRepository repository = _MockBillingRepository();
    var calls = 0;
    when(() => repository.listWorkItems(any())).thenAnswer((invocation) async {
      calls += 1;
      if (calls > 1) {
        return const Result<AppPage<BillingWorkItem>>.failure(
          AppFailure.network(),
        );
      }
      final BillingWorkspaceQuery query =
          invocation.positionalArguments.single as BillingWorkspaceQuery;
      return Result<AppPage<BillingWorkItem>>.success(
        AppPage<BillingWorkItem>(
          items: <BillingWorkItem>[_invoice],
          request: query.pageRequest,
        ),
      );
    });
    final ProviderContainer container = _container(repository);
    addTearDown(container.dispose);
    await container.read(receptionPaymentGateControllerProvider.future);

    final AppFailure? failure = await container
        .read(receptionPaymentGateControllerProvider.notifier)
        .refresh();

    expect(failure, isNotNull);
    final ReceptionPaymentGateState state = _state(container);
    expect(state.entries.single.patientName, 'Retained Patient');
    expect(state.isRefreshing, isFalse);
    expect(state.lastFailure, isNotNull);
  });

  test('applyInvoiceUpdate removes settled invoices from the gate', () async {
    final _MockBillingRepository repository = _MockBillingRepository();
    when(() => repository.listWorkItems(any())).thenAnswer((invocation) async {
      final BillingWorkspaceQuery query =
          invocation.positionalArguments.single as BillingWorkspaceQuery;
      return Result<AppPage<BillingWorkItem>>.success(
        AppPage<BillingWorkItem>(
          items: <BillingWorkItem>[_invoice],
          request: query.pageRequest,
        ),
      );
    });
    final ProviderContainer container = _container(repository);
    addTearDown(container.dispose);
    await container.read(receptionPaymentGateControllerProvider.future);
    expect(_state(container).entries, hasLength(1));

    container
        .read(receptionPaymentGateControllerProvider.notifier)
        .applyInvoiceUpdate(
          _invoice.copyWith(
            billingStatus: 'PAID',
            financials: const BillingFinancials(
              invoiceTotal: 100,
              effectiveTotal: 100,
              grossPaidTotal: 100,
              netPaidTotal: 100,
              balanceDue: 0,
            ),
          ),
        );

    expect(_state(container).entries, isEmpty);
    verify(() => repository.listWorkItems(any())).called(1);
  });
}

ProviderContainer _container(_MockBillingRepository repository) {
  return ProviderContainer(
    overrides: [
      initialSessionStateProvider.overrideWithValue(const SessionState.ready()),
      billingRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

ReceptionPaymentGateState _state(ProviderContainer container) {
  final Result<ReceptionPaymentGateState> result = container
      .read(receptionPaymentGateControllerProvider)
      .requireValue;
  return result.when(
    success: (ReceptionPaymentGateState value) => value,
    failure: (AppFailure failure) => throw StateError(failure.toString()),
  );
}

const BillingWorkItem _invoice = BillingWorkItem(
  id: 'invoice-1',
  displayId: 'INV-1',
  kind: BillingWorkItemKind.invoice,
  patientId: 'patient-1',
  patientDisplayName: 'Retained Patient',
  encounterId: 'encounter-1',
  sourceModule: 'LABORATORY',
  status: 'SENT',
  billingStatus: 'ISSUED',
  currency: 'UGX',
  items: <BillingInvoiceItem>[
    BillingInvoiceItem(
      id: 'line-1',
      description: 'Consultation',
      sourceModule: 'LABORATORY',
      totalPrice: 100,
    ),
  ],
  financials: BillingFinancials(
    invoiceTotal: 100,
    effectiveTotal: 100,
    balanceDue: 100,
  ),
);
