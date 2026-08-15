import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_controller.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_approvals_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_department_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_departments_and_cost_centres_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_document_numbering_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_document_sequence_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_fiscal_period_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_fiscal_periods_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_gl_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_invoices_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_ledgers_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_open_work_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_payment_method_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_payment_methods_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_to_post_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/routing/workspace_location_sync.dart';

/// Flat tab strip for the sections inside the category the sidebar resolved.
const Key accountsSectionTabsKey = Key('accounts-section-tabs');

/// Body of the active section.
const Key accountsSectionBodyKey = Key('accounts-section-body');

/// Accounts desk shell (`/accounts`).
///
/// Books: Open work / To post / Need approval / GL / Ledgers / Chart /
/// Invoices. Setup & Controls: Fiscal Years & Periods / Departments & Cost
/// Centres / Payment Methods.
///
/// Menu depth stops at the category: `Accounts & Finance → <Category>` are the
/// two menu levels, and the category's sections are this page's tabs
/// (`.cursor/finance/_shared/navigation-model.md`). There is no category tab
/// row and no nested tab-strip variant.
class AccountsWorkspacePage extends ConsumerWidget {
  const AccountsWorkspacePage({super.key, this.initialQuery});

  final AccountsWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<AccountsWorkspaceState>> workspace = ref.watch(
      accountsWorkspaceControllerProvider,
    );

    return AppAccessGate(
      requirement: accountsWorkspaceEntryRequirement,
      deniedBuilder: (_, _) => const SizedBox.shrink(),
      child: AsyncStateScaffold<AccountsWorkspaceState>(
        value: workspace,
        appBarTitle: AccountsStrings.workspaceTitle,
        loadingTitle: AccountsStrings.loadingTitle,
        loadingBody: AccountsStrings.loadingBody,
        maxWidth: PageMaxWidth.dataHeavy,
        centerVertically: false,
        scrollable: false,
        onRetry: () {
          ref.read(accountsWorkspaceControllerProvider.notifier).refresh();
        },
        dataBuilder: (BuildContext context, AccountsWorkspaceState state) {
          if (!canEnterAccounts(ref.watch(appAccessPolicyProvider))) {
            return const SizedBox.shrink();
          }
          return _AccountsWorkspaceContent(
            state: state,
            initialQuery: initialQuery,
          );
        },
      ),
    );
  }
}

class _AccountsWorkspaceContent extends ConsumerStatefulWidget {
  const _AccountsWorkspaceContent({required this.state, this.initialQuery});

  final AccountsWorkspaceState state;
  final AccountsWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_AccountsWorkspaceContent> createState() =>
      _AccountsWorkspaceContentState();
}

class _AccountsWorkspaceContentState
    extends ConsumerState<_AccountsWorkspaceContent> {
  late AccountsDeskSection _section;
  bool _handledRouteQuery = false;

  @override
  void initState() {
    super.initState();
    final accessPolicy = ref.read(appAccessPolicyProvider);
    _section = resolveAccountsSection(
      accessPolicy,
      preferred: widget.initialQuery?.section ?? widget.state.query.section,
    );
    _scheduleRouteQuery(widget.initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.initialQuery?.hasRouteTargeting == true) {
        return;
      }
      ref.read(accountsWorkspaceControllerProvider.notifier).refresh();
    });
  }

  @override
  void didUpdateWidget(covariant _AccountsWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _handledRouteQuery = false;
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  void _scheduleRouteQuery(AccountsWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _handledRouteQuery) {
        return;
      }
      _handledRouteQuery = true;
      unawaited(_applyRouteQuery(query));
    });
  }

  Future<void> _applyRouteQuery(AccountsWorkspaceQuery query) async {
    final accessPolicy = ref.read(appAccessPolicyProvider);
    final AccountsDeskSection section = resolveAccountsSection(
      accessPolicy,
      preferred: query.section,
    );
    if (_section != section) {
      setState(() => _section = section);
    }
    final AccountsWorkspaceController controller = ref.read(
      accountsWorkspaceControllerProvider.notifier,
    );
    if (query.hasActiveFilters ||
        query.search.trim().isNotEmpty ||
        query.id.trim().isNotEmpty ||
        query.action.trim().isNotEmpty ||
        query.accountId.trim().isNotEmpty ||
        query.patientId.trim().isNotEmpty ||
        query.periodId.trim().isNotEmpty) {
      await controller.applyQuery(query.copyWith(section: section));
    } else {
      await controller.applySection(section);
    }
    if (mounted) {
      _updateUrlForSection(section, query: query);
    }
  }

  void _updateUrlForSection(
    AccountsDeskSection section, {
    AccountsWorkspaceQuery? query,
  }) {
    if (!mounted) {
      return;
    }
    final Map<String, String> params = <String, String>{
      'section': section.sectionQueryValue,
    };
    final String accountId = (query?.accountId ?? '').trim();
    if (accountId.isNotEmpty && section == AccountsDeskSection.gl) {
      params['accountId'] = accountId;
    }
    final String patientId = (query?.patientId ?? '').trim();
    if (patientId.isNotEmpty && section == AccountsDeskSection.ledgers) {
      params['patientId'] = patientId;
    }
    final String search = (query?.search ?? widget.state.query.search).trim();
    if (search.isNotEmpty) {
      params['search'] = search;
    }
    final String action = (query?.action ?? '').trim();
    if (action.isNotEmpty && section == AccountsDeskSection.journals) {
      params['action'] = action;
    }
    final String id = (query?.id ?? '').trim();
    if (id.isNotEmpty && section == AccountsDeskSection.journals) {
      params['id'] = id;
    }
    syncWorkspaceLocation(
      context,
      AppRoutes.accounts.location(queryParameters: params),
    );
  }

  void _selectSection(AccountsDeskSection section) {
    if (_section == section) {
      return;
    }
    setState(() => _section = section);
    unawaited(
      ref
          .read(accountsWorkspaceControllerProvider.notifier)
          .applySection(section),
    );
    _updateUrlForSection(section);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final List<AccountsDeskSection> visibleSections = AccountsDeskSection.values
        .where(
          (AccountsDeskSection section) =>
              canViewAccountsSection(accessPolicy, section),
        )
        .toList(growable: false);

    if (visibleSections.isEmpty) {
      return const SizedBox.shrink();
    }

    final AccountsDeskSection active = visibleSections.contains(_section)
        ? _section
        : visibleSections.first;

    if (active != _section) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleSections.contains(_section)) {
          return;
        }
        _selectSection(active);
      });
    }

    // The sidebar menu resolved the leaf; the page renders only its body.
    // The sidebar resolved the category; its sections are this page's tabs.
    final List<AccountsDeskSection> categorySections = active.category.sections
        .where(visibleSections.contains)
        .toList(growable: false);

    return ResponsivePage(
      padding: ResponsiveSpacing.workspacePagePaddingFor(
        spacing: theme.spacing,
      ),
      maxWidth: PageMaxWidth.dataHeavy,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTabStrip(
            key: accountsSectionTabsKey,
            tabs: <AppTabItem>[
              for (final AccountsDeskSection section in categorySections)
                AppTabItem(
                  id: section.name,
                  icon: accountsSectionIcon(section),
                  label: accountsSectionLabel(l10n, section),
                  tooltip: accountsSectionTooltip(l10n, section),
                  count: _sectionCount(section),
                  countTone: accountsSectionCountTone(section),
                ),
            ],
            selectedId: active.name,
            onTabTapped: (String tabId) {
              for (final AccountsDeskSection section in categorySections) {
                if (section.name == tabId) {
                  _selectSection(section);
                  break;
                }
              }
            },
          ),
          SizedBox(height: theme.spacing.md),
          Expanded(key: accountsSectionBodyKey, child: _sectionBody(active)),
        ],
      ),
    );
  }

  int _sectionCount(AccountsDeskSection section) {
    return accountsSectionTabCount(
      widget.state,
      section,
      activeSection: _section,
      glActivityOverride: ref.watch(accountsGlActivityCountProvider),
      invoicesOverride: ref.watch(accountsInvoicesCountProvider),
      ledgersBalanceOverride: ref.watch(
        accountsPatientLedgersBalanceCountProvider,
      ),
      chartActiveOverride: ref.watch(accountsChartActiveCountProvider),
      fiscalPeriodsOverride: ref.watch(accountsFiscalPeriodCountProvider),
      departmentsOverride: ref.watch(accountsDepartmentCountProvider),
      paymentMethodsOverride: ref.watch(accountsPaymentMethodCountProvider),
      documentSequencesOverride: ref.watch(accountsDocumentSequenceCountProvider),
    );
  }

  Widget _sectionBody(AccountsDeskSection section) {
    return switch (section) {
      AccountsDeskSection.work => AccountsOpenWorkPanel(state: widget.state),
      AccountsDeskSection.journals => AccountsToPostPanel(
        state: widget.state,
        initialAction: widget.initialQuery?.action ?? '',
        initialId: widget.initialQuery?.id ?? '',
      ),
      AccountsDeskSection.approvals =>
        AccountsApprovalsPanel(state: widget.state),
      AccountsDeskSection.gl => AccountsGlPanel(
        initialAccountId: widget.initialQuery?.accountId ?? '',
        initialSearch: widget.initialQuery?.search ?? '',
      ),
      AccountsDeskSection.ledgers => AccountsLedgersPanel(
        initialPatientId: widget.initialQuery?.patientId ?? '',
        initialSearch: widget.initialQuery?.search ?? '',
      ),
      AccountsDeskSection.chart => const AccountsChartPanel(),
      AccountsDeskSection.invoices => const AccountsInvoicesPanel(),
      AccountsDeskSection.fiscalYearsAndPeriods =>
        const AccountsFiscalPeriodsPanel(),
      AccountsDeskSection.departmentsAndCostCentres =>
        const AccountsDepartmentsAndCostCentresPanel(),
      AccountsDeskSection.paymentMethods =>
        const AccountsPaymentMethodsPanel(),
      AccountsDeskSection.documentNumbering =>
        const AccountsDocumentNumberingPanel(),
    };
  }
}
