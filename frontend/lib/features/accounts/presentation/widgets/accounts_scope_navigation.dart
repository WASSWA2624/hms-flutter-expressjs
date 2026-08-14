import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Accounts & Finance submenu — its categories, one nesting level deep.
///
/// The menu carries exactly two levels: `Accounts & Finance` and its
/// categories. The sections inside a category are the workspace tab strip, not
/// menu items. Categories with no authorized section are omitted.
List<ShellSubmenuItem> accountsShellMenuChildren({
  required AppAccessPolicy accessPolicy,
  int? Function(AccountsDeskCategory category)? badgeCount,
}) {
  return <ShellSubmenuItem>[
    for (final AccountsDeskCategory category in AccountsDeskCategory.values)
      if (accountsVisibleCategorySections(accessPolicy, category).isNotEmpty)
        ShellSubmenuItem(
          id: category.name,
          label: accountsCategoryLabel(category),
          icon: accountsCategoryIcon(category),
          tooltip: accountsCategoryTooltip(category),
          badgeCount: badgeCount?.call(category),
        ),
  ];
}

/// Sections of [category] the user may open, in menu order.
List<AccountsDeskSection> accountsVisibleCategorySections(
  AppAccessPolicy accessPolicy,
  AccountsDeskCategory category,
) {
  return category.sections
      .where(
        (AccountsDeskSection section) =>
            canViewAccountsSection(accessPolicy, section),
      )
      .toList(growable: false);
}

/// Scope total for a category badge: the sum of its visible sections.
///
/// Reads the unfiltered workspace summary so the sidebar never depends on a
/// panel's live query state.
int accountsCategorySummaryCount(
  AccountsSummary summary,
  List<AccountsDeskSection> visibleSections,
) {
  int total = 0;
  for (final AccountsDeskSection section in visibleSections) {
    total += summary.countFor(section);
  }
  return total;
}

/// First section a category opens on, or null when none is authorized.
AccountsDeskSection? accountsCategoryLandingSection(
  AppAccessPolicy accessPolicy,
  AccountsDeskCategory category,
) {
  final List<AccountsDeskSection> sections = accountsVisibleCategorySections(
    accessPolicy,
    category,
  );
  return sections.isEmpty ? null : sections.first;
}

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
  int? departmentsOverride,
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
    AccountsDeskSection.departmentsAndCostCentres =>
      departmentsOverride ?? summary.countFor(section),
    _ => summary.countFor(section),
  };

  final bool isDedicatedPanel =
      section == AccountsDeskSection.gl ||
      section == AccountsDeskSection.invoices ||
      section == AccountsDeskSection.ledgers ||
      section == AccountsDeskSection.chart ||
      section == AccountsDeskSection.fiscalYearsAndPeriods ||
      section == AccountsDeskSection.departmentsAndCostCentres;
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
    AccountsDeskSection.departmentsAndCostCentres => AppTabCountTone.info,
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
  int? departmentsOverride,
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
      departmentsOverride: departmentsOverride,
    );
  }
  return total;
}
