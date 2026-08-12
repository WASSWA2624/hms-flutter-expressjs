import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Sibling-count model: dedicated unfiltered [AccountsSummary] scope totals
/// (with live GL / books / ledgers / chart overrides when set).
///
/// Work-queue tabs (`work` / `journals` / `approvals`) share the workspace
/// query + `workItems` page: when the active tab is narrowed by search or
/// advanced filters, that badge uses `workItems.totalItemCount`.
///
/// Dedicated panels (`gl` / `ledgers` / `chart` / `books`) push filtered or
/// scope totals into their count providers; badges prefer those overrides.
int accountsSectionTabCount(
  AccountsWorkspaceState state,
  AccountsDeskSection section, {
  AccountsDeskSection? activeSection,
  int? glActivityOverride,
  int? openPeriodsOverride,
  int? ledgersBalanceOverride,
  int? chartActiveOverride,
}) {
  final AccountsSummary summary = state.overview.summary;
  final int scopeTotal = switch (section) {
    AccountsDeskSection.gl => glActivityOverride ?? summary.countFor(section),
    AccountsDeskSection.books =>
      openPeriodsOverride ?? summary.countFor(section),
    AccountsDeskSection.ledgers =>
      ledgersBalanceOverride ?? summary.countFor(section),
    AccountsDeskSection.chart =>
      chartActiveOverride ?? summary.countFor(section),
    _ => summary.countFor(section),
  };

  final bool isDedicatedPanel =
      section == AccountsDeskSection.gl ||
      section == AccountsDeskSection.books ||
      section == AccountsDeskSection.ledgers ||
      section == AccountsDeskSection.chart;
  if (isDedicatedPanel) {
    return scopeTotal;
  }

  if (activeSection == null || section != activeSection) {
    return scopeTotal;
  }
  if (!_accountsWorkQueueNarrowed(state.query)) {
    return scopeTotal;
  }
  return state.workItems.totalItemCount ?? state.workItems.items.length;
}

bool _accountsWorkQueueNarrowed(AccountsWorkspaceQuery query) {
  return query.search.trim().isNotEmpty || query.hasActiveFilters;
}

AppTabCountTone accountsSectionCountTone(AccountsDeskSection section) {
  return switch (section) {
    AccountsDeskSection.journals ||
    AccountsDeskSection.approvals ||
    AccountsDeskSection.books => AppTabCountTone.warning,
    AccountsDeskSection.work ||
    AccountsDeskSection.gl ||
    AccountsDeskSection.ledgers ||
    AccountsDeskSection.chart => AppTabCountTone.info,
  };
}
