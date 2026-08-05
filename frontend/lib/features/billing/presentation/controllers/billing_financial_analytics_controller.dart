import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';

final billingFinancialAnalyticsControllerProvider =
    AsyncNotifierProvider<
      BillingFinancialAnalyticsController,
      Result<BillingFinancialAnalytics>
    >(BillingFinancialAnalyticsController.new);

final class BillingFinancialAnalyticsController
    extends AsyncNotifier<Result<BillingFinancialAnalytics>> {
  BillingRepository get _repository => ref.read(billingRepositoryProvider);

  BillingAnalyticsQuery _query = const BillingAnalyticsQuery();

  BillingAnalyticsQuery get query => _query;

  @override
  Future<Result<BillingFinancialAnalytics>> build() async {
    watchSessionEpoch(ref);
    return _load(_query);
  }

  Future<Result<BillingFinancialAnalytics>> _load(
    BillingAnalyticsQuery query,
  ) async {
    if (query.period == BillingAnalyticsPeriod.custom) {
      final DateTime? from = query.from;
      final DateTime? to = query.to;
      if (from == null || to == null || from.isAfter(to)) {
        return Result<BillingFinancialAnalytics>.failure(
          AppFailure.validation(
            detailMessage: 'Enter a valid custom date range.',
            validationFields: const <String>{'from', 'to'},
            fieldMessages: const <String, String>{
              'from': 'required',
              'to': 'required',
            },
          ),
        );
      }
    }
    return _repository.getFinancialAnalytics(query);
  }

  Future<AppFailure?> applyPeriod(BillingAnalyticsPeriod period) async {
    _query = BillingAnalyticsQuery(
      period: period,
      from: period == BillingAnalyticsPeriod.custom ? _query.from : null,
      to: period == BillingAnalyticsPeriod.custom ? _query.to : null,
    );
    state = const AsyncLoading();
    final Result<BillingFinancialAnalytics> result = await _load(_query);
    state = AsyncData(result);
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> applyCustomRange({
    required DateTime from,
    required DateTime to,
  }) async {
    _query = BillingAnalyticsQuery(
      period: BillingAnalyticsPeriod.custom,
      from: from,
      to: to,
    );
    state = const AsyncLoading();
    final Result<BillingFinancialAnalytics> result = await _load(_query);
    state = AsyncData(result);
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  Future<AppFailure?> refresh() async {
    state = const AsyncLoading();
    final Result<BillingFinancialAnalytics> result = await _load(_query);
    state = AsyncData(result);
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }
}
