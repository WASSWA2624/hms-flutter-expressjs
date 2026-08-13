import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Sibling-count model: dedicated unfiltered [AccountsSummary] scope totals
/// (with live GL / invoices / ledgers / chart overrides when set).
///
/// Work-queue tabs (`work` / `journals` / `approvals`) share the workspace
/// query + `workItems` page: when the active tab is narrowed by search or
/// advanced filters, that badge uses `workItems.totalItemCount`.
///
/// Dedicated panels (`gl` / `ledgers` / `chart` / `invoices`) push filtered or
/// scope totals into their count providers; badges prefer those overrides.
int accountsSectionTabCount(
  AccountsWorkspaceState state,
  AccountsDeskSection section, {
  AccountsDeskSection? activeSection,
  int? glActivityOverride,
  int? invoicesOverride,
  int? ledgersBalanceOverride,
  int? chartActiveOverride,
  int? fiscalPeriodsOverride,
  int? currencyRatesOverride,
}) {
  final AccountsSummary summary = state.overview.summary;
  final int scopeTotal = switch (section) {
    AccountsDeskSection.gl => glActivityOverride ?? summary.countFor(section),
    AccountsDeskSection.invoices =>
      invoicesOverride ?? summary.countFor(section),
    AccountsDeskSection.ledgers =>
      ledgersBalanceOverride ?? summary.countFor(section),
    AccountsDeskSection.chart =>
      chartActiveOverride ?? summary.countFor(section),
    AccountsDeskSection.fiscalYearsAndPeriods =>
      fiscalPeriodsOverride ?? summary.countFor(section),
    AccountsDeskSection.currenciesAndExchangeRates =>
      currencyRatesOverride ?? summary.countFor(section),
    _ => summary.countFor(section),
  };

  final bool isDedicatedPanel =
      section == AccountsDeskSection.gl ||
      section == AccountsDeskSection.invoices ||
      section == AccountsDeskSection.ledgers ||
      section == AccountsDeskSection.chart ||
      section == AccountsDeskSection.fiscalYearsAndPeriods ||
      section == AccountsDeskSection.currenciesAndExchangeRates;
  if (isDedicatedPanel) {
    return scopeTotal;
  }

  if (activeSection == null || section != activeSection) {
    return scopeTotal;
  }
  if (!_accountsWorkQueueNarrowed(state.query)) {
    return scopeTotal;
  }
  return state.workItems.totalItemCount ?? scopeTotal;
}

bool _accountsWorkQueueNarrowed(AccountsWorkspaceQuery query) {
  return query.search.trim().isNotEmpty || query.hasActiveFilters;
}

AppTabCountTone accountsSectionCountTone(AccountsDeskSection section) {
  return switch (section) {
    AccountsDeskSection.journals ||
    AccountsDeskSection.approvals => AppTabCountTone.warning,
    AccountsDeskSection.work ||
    AccountsDeskSection.gl ||
    AccountsDeskSection.ledgers ||
    AccountsDeskSection.chart ||
    AccountsDeskSection.invoices ||
    AccountsDeskSection.fiscalYearsAndPeriods ||
    AccountsDeskSection.currenciesAndExchangeRates => AppTabCountTone.info,
  };
}

/// Folder badge = sum of its visible leaf tab counts.
int accountsCategoryTabCount(
  AccountsWorkspaceState state,
  AccountsDeskCategory category,
  List<AccountsDeskSection> visibleSections, {
  AccountsDeskSection? activeSection,
  int? glActivityOverride,
  int? invoicesOverride,
  int? ledgersBalanceOverride,
  int? chartActiveOverride,
  int? fiscalPeriodsOverride,
  int? currencyRatesOverride,
}) {
  int total = 0;
  for (final AccountsDeskSection section in category.sections) {
    if (!visibleSections.contains(section)) {
      continue;
    }
    total += accountsSectionTabCount(
      state,
      section,
      activeSection: activeSection,
      glActivityOverride: glActivityOverride,
      invoicesOverride: invoicesOverride,
      ledgersBalanceOverride: ledgersBalanceOverride,
      chartActiveOverride: chartActiveOverride,
      fiscalPeriodsOverride: fiscalPeriodsOverride,
      currencyRatesOverride: currencyRatesOverride,
    );
  }
  return total;
}
