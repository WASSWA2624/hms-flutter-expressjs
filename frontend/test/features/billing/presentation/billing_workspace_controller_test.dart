import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const BillingWorkspaceQuery());
    registerFallbackValue(
      const BillingWorkItem(id: 'invoice-1', kind: BillingWorkItemKind.invoice),
    );
    registerFallbackValue(
      const BillingPaymentDraft(amount: '1000.00', method: 'CASH'),
    );
  });

  group('BillingWorkspaceController', () {
    test('loads overview and selects the first work item', () async {
      final _MockBillingRepository repository = _MockBillingRepository();
      const BillingWorkItem invoice = BillingWorkItem(
        id: 'invoice-1',
        displayId: 'INV-001',
        kind: BillingWorkItemKind.invoice,
        tenantId: 'tenant-1',
        patientDisplayName: 'Jane Doe',
        billingStatus: 'ISSUED',
        amount: 1000,
      );
      _stubInitialLoad(repository, items: <BillingWorkItem>[invoice]);

      final ProviderContainer container = ProviderContainer(
        overrides: [billingRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final Result<BillingWorkspaceState> result = await container.read(
        billingWorkspaceControllerProvider.future,
      );

      final BillingWorkspaceState state = result.when(
        success: (BillingWorkspaceState value) => value,
        failure: (AppFailure failure) => fail(failure.code),
      );
      expect(state.selectedItem?.id, 'invoice-1');
      expect(state.overview.summary.pendingPayment, 1);
      verify(() => repository.getWorkspace(any())).called(1);
      verify(() => repository.listWorkItems(any())).called(1);
    });

    test(
      'submits payment for selected invoice and refreshes affected queues',
      () async {
        final _MockBillingRepository repository = _MockBillingRepository();
        const BillingWorkItem invoice = BillingWorkItem(
          id: 'invoice-1',
          displayId: 'INV-001',
          kind: BillingWorkItemKind.invoice,
          tenantId: 'tenant-1',
          patientDisplayName: 'Jane Doe',
          billingStatus: 'ISSUED',
          amount: 1000,
        );
        BillingWorkItem? submittedInvoice;
        BillingPaymentDraft? submittedDraft;
        _stubInitialLoad(repository, items: <BillingWorkItem>[invoice]);
        when(() => repository.receivePayment(any(), any())).thenAnswer((
          invocation,
        ) async {
          submittedInvoice =
              invocation.positionalArguments[0] as BillingWorkItem;
          submittedDraft =
              invocation.positionalArguments[1] as BillingPaymentDraft;
          return const Result<void>.success(null);
        });

        final ProviderContainer container = ProviderContainer(
          overrides: [billingRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        await container.read(billingWorkspaceControllerProvider.future);

        final AppFailure? failure = await container
            .read(billingWorkspaceControllerProvider.notifier)
            .receivePayment(
              const BillingPaymentDraft(amount: '1000.00', method: 'CASH'),
            );

        expect(failure, isNull);
        expect(submittedInvoice?.id, 'invoice-1');
        expect(submittedDraft?.amount, '1000.00');
        verify(() => repository.receivePayment(any(), any())).called(1);
        verify(() => repository.getWorkspace(any())).called(2);
        verify(() => repository.listWorkItems(any())).called(2);
      },
    );
  });
}

void _stubInitialLoad(
  _MockBillingRepository repository, {
  List<BillingWorkItem> items = const <BillingWorkItem>[],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((_) async {
    return const Result<BillingWorkspaceOverview>.success(
      BillingWorkspaceOverview(
        summary: BillingSummary(pendingPayment: 1),
        queues: <BillingQueueSummary>[
          BillingQueueSummary(
            queue: BillingQueueType.pendingPayment,
            label: 'Pending payment',
            count: 1,
          ),
        ],
      ),
    );
  });
  when(() => repository.listWorkItems(any())).thenAnswer((invocation) async {
    final BillingWorkspaceQuery query =
        invocation.positionalArguments.single as BillingWorkspaceQuery;
    return Result<AppPage<BillingWorkItem>>.success(
      AppPage<BillingWorkItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
}
