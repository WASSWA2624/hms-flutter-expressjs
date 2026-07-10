import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/domain/repositories/subscriptions_repository.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockSubscriptionsRepository extends Mock
    implements SubscriptionsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const SubscriptionsWorkspaceQuery());
    registerFallbackValue(
      const SubscriptionPlanDraft(
        name: 'Starter',
        monthlyPrice: '0',
        annualPrice: '0',
        billingCycle: 'MONTHLY',
      ),
    );
  });

  group('SubscriptionsWorkspaceController', () {
    test(
      'applyRouteQuery resolves legacy identifiers before loading workspace',
      () async {
        final _MockSubscriptionsRepository repository =
            _MockSubscriptionsRepository();
        _stubWorkspace(repository);
        when(
          () => repository.resolveLegacyRoute(
            SubscriptionResource.subscriptions,
            'SUB-001',
          ),
        ).thenAnswer(
          (_) async => const Result<SubscriptionLegacyRouteResolution>.success(
            SubscriptionLegacyRouteResolution(
              panel: SubscriptionPanel.operations,
              resource: SubscriptionResource.subscriptions,
              id: 'subscription-1',
              action: 'view',
            ),
          ),
        );
        when(
          () => repository.getReferenceData(tenantId: any(named: 'tenantId')),
        ).thenAnswer(
          (_) async =>
              const Result<SubscriptionLookups>.success(SubscriptionLookups()),
        );

        final ProviderContainer container = ProviderContainer(
          overrides: [
            subscriptionsRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        await container.read(subscriptionsWorkspaceControllerProvider.future);

        final AppFailure? failure = await container
            .read(subscriptionsWorkspaceControllerProvider.notifier)
            .applyRouteQuery(
              const SubscriptionsWorkspaceQuery(
                recordId: 'SUB-001',
                action: 'view',
              ),
            );

        expect(failure, isNull);
        verify(
          () => repository.resolveLegacyRoute(
            SubscriptionResource.subscriptions,
            'SUB-001',
          ),
        ).called(1);
        verify(
          () => repository.getWorkspace(
            any(
              that: predicate<SubscriptionsWorkspaceQuery>(
                (SubscriptionsWorkspaceQuery query) =>
                    query.recordId == 'subscription-1' &&
                    query.action == 'view' &&
                    query.panel == SubscriptionPanel.operations,
              ),
            ),
          ),
        ).called(1);
      },
    );
  });
}

void _stubWorkspace(_MockSubscriptionsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((invocation) async {
    final SubscriptionsWorkspaceQuery query =
        invocation.positionalArguments.single as SubscriptionsWorkspaceQuery;
    return Result<SubscriptionsWorkspaceData>.success(
      SubscriptionsWorkspaceData(
        query: query,
        summary: const <SubscriptionSummaryMetric>[],
        queueSummaries: const <SubscriptionQueueSummary>[],
        panelSummaries: const <SubscriptionPanelSummary>[],
        lookups: const SubscriptionLookups(),
        items: AppPage<SubscriptionItem>(
          items: <SubscriptionItem>[
            SubscriptionItem(
              id: query.recordId ?? 'subscription-1',
              resource: query.resource,
              displayId: query.recordId ?? 'SUB-001',
              status: 'ACTIVE',
            ),
          ],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
        overview: const SubscriptionsOverview(),
        timeline: const <SubscriptionTimelineItem>[],
      ),
    );
  });
  when(
    () => repository.getReferenceData(tenantId: any(named: 'tenantId')),
  ).thenAnswer(
    (_) async =>
        const Result<SubscriptionLookups>.success(SubscriptionLookups()),
  );
}
