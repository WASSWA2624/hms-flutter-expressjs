import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';
import 'package:hosspi_hms/features/claims/presentation/controllers/claims_workspace_controller.dart';
import 'package:hosspi_hms/features/claims/presentation/widgets/claims_insurance_config_dialogs.dart';
import 'package:hosspi_hms/features/claims/presentation/widgets/claims_scope_navigation.dart';
import 'package:hosspi_hms/features/claims/presentation/widgets/claims_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';
import 'package:hosspi_hms/shared/routing/workspace_location_sync.dart';

class ClaimsWorkspacePage extends ConsumerWidget {
  const ClaimsWorkspacePage({this.initialQuery, super.key});

  final ClaimsWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<ClaimsWorkspaceState>> value = ref.watch(
      claimsWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return AsyncStateScaffold<ClaimsWorkspaceState>(
      value: value,
      loadingTitle: l10n.claimsLoadingTitle,
      loadingBody: l10n.claimsLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.invalidate(claimsWorkspaceControllerProvider);
      },
      dataBuilder: (BuildContext context, ClaimsWorkspaceState state) {
        return _ClaimsWorkspaceContent(
          state: state,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _ClaimsWorkspaceContent extends ConsumerStatefulWidget {
  const _ClaimsWorkspaceContent({required this.state, this.initialQuery});

  final ClaimsWorkspaceState state;
  final ClaimsWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_ClaimsWorkspaceContent> createState() {
    return _ClaimsWorkspaceContentState();
  }
}

class _ClaimsWorkspaceContentState
    extends ConsumerState<_ClaimsWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<ClaimsQueueItem>
  _tableColumnController;
  late ClaimsDeskSection _section;
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    _section = widget.initialQuery?.section.isNotEmpty == true
        ? claimsDeskSectionFromQuery(widget.initialQuery!.section)
        : ClaimsDeskSection.authorizations;
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<ClaimsQueueItem>();
    _scheduleRouteQuery(widget.initialQuery);
    if (widget.initialQuery?.section.isNotEmpty != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(claimsWorkspaceControllerProvider.notifier)
              .applyFilter(_defaultFilterForSection(_section)),
        );
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ClaimsWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.value = TextEditingValue(text: search);
    }
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  void _scheduleRouteQuery(ClaimsWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) return;
    if (_appliedRouteSignature == query.signature) return;
    _appliedRouteSignature = query.signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_applyRouteQuery(query));
    });
  }

  Future<void> _applyRouteQuery(ClaimsWorkspaceQuery query) async {
    final ClaimsWorkspaceController controller = ref.read(
      claimsWorkspaceControllerProvider.notifier,
    );
    if (query.section.isNotEmpty) {
      final ClaimsDeskSection section = claimsDeskSectionFromQuery(
        query.section,
      );
      setState(() => _section = section);
      unawaited(controller.applyFilter(_defaultFilterForSection(section)));
    }
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
      await controller.applySearch(query.search);
    }
    if (query.encounterId.isNotEmpty || query.patientId.isNotEmpty) {
      final ClaimsQueueItem? item = _findQueueItem(
        encounterId: query.encounterId,
        patientId: query.patientId,
      );
      if (item != null && mounted) {
        await _openClaimsDetailDialog(
          context,
          ref,
          widget.state,
          item,
          section: _section,
        );
      }
    }
    if (query.action == 'preauth' && mounted) {
      final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
      if (ClaimsAuthorizationsAtomPermissions.requestAuthorization.isAllowed(
        policy,
      )) {
        unawaited(
          _openRequestAuthorizationDialog(context, controller, widget.state),
        );
      }
    }
    if ((query.action == 'prepare' || query.action == 'prepare-claim') &&
        mounted) {
      final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
      if (ClaimsActiveClaimsAtomPermissions.prepare.isAllowed(policy)) {
        unawaited(
          _openPrepareClaimDialog(context, ref, controller, widget.state),
        );
      }
    }
  }

  ClaimsQueueItem? _findQueueItem({
    required String encounterId,
    required String patientId,
  }) {
    for (final ClaimsQueueItem item in widget.state.queue.items) {
      if (encounterId.isNotEmpty) {
        final String? authEncounter = item.authorization?.encounterId;
        final String? authEncounterDisplay =
            item.authorization?.encounterDisplayId;
        if (authEncounter == encounterId ||
            authEncounterDisplay == encounterId) {
          return item;
        }
      }
      if (patientId.isNotEmpty) {
        final String? authPatient = item.authorization?.patientId;
        final String? authPatientDisplay = item.authorization?.patientDisplayId;
        final String? claimPatientDisplay = item.claim?.patientDisplayId;
        if (authPatient == patientId ||
            authPatientDisplay == patientId ||
            claimPatientDisplay == patientId) {
          return item;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  void _updateUrlForSection(ClaimsDeskSection section) {
    if (!mounted) return;
    final String tab = claimsDeskSectionToQuery(section);
    final String location = AppRoutes.claims.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    syncWorkspaceLocation(context, location);
  }

  static ClaimsQueueFilter _defaultFilterForSection(ClaimsDeskSection section) {
    return claimsDefaultFilterForSection(section);
  }

  static IconData _sectionIcon(ClaimsDeskSection section) {
    return switch (section) {
      ClaimsDeskSection.authorizations => Icons.verified_user_outlined,
      ClaimsDeskSection.activeClaims => Icons.receipt_long_outlined,
      ClaimsDeskSection.settled => Icons.task_alt_outlined,
      ClaimsDeskSection.insuranceSetup => Icons.business_outlined,
    };
  }

  String _sectionLabel(AppLocalizations l10n, ClaimsDeskSection section) {
    return switch (section) {
      ClaimsDeskSection.authorizations => l10n.claimsSectionAuthorizations,
      ClaimsDeskSection.activeClaims => l10n.claimsSectionActiveClaims,
      ClaimsDeskSection.settled => l10n.claimsSectionSettled,
      ClaimsDeskSection.insuranceSetup => l10n.claimsSectionInsuranceSetup,
    };
  }

  void _selectSection(ClaimsDeskSection section) {
    if (_section != section) {
      setState(() => _section = section);
    }
    _updateUrlForSection(section);
    unawaited(
      ref
          .read(claimsWorkspaceControllerProvider.notifier)
          .applyFilter(_defaultFilterForSection(section)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClaimsWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final ClaimsWorkspaceController controller = ref.read(
      claimsWorkspaceControllerProvider.notifier,
    );
    final List<ClaimsDeskSection> visibleSections = <ClaimsDeskSection>[
      for (final ClaimsDeskSection section in ClaimsDeskSection.values)
        if (canViewClaimsDeskSection(accessPolicy, section)) section,
    ];
    if (visibleSections.isEmpty) {
      // No authorized sections — omit chrome (no routine "no access" banner).
      return const SizedBox.shrink();
    }
    // Never mount unauthorized section body (deep link / stale section) —
    // render the first allowed tab immediately; sync URL/_section next frame.
    final ClaimsDeskSection effectiveSection =
        visibleSections.contains(_section)
        ? _section
        : visibleSections.first;
    if (effectiveSection != _section) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleSections.contains(_section)) {
          return;
        }
        _selectSection(effectiveSection);
      });
    }
    final Widget tabStrip = AppTabStrip(
      tabs: <AppTabItem>[
        for (final ClaimsDeskSection section in visibleSections)
          AppTabItem(
            id: section.name,
            icon: _sectionIcon(section),
            label: _sectionLabel(l10n, section),
            // Insurance Setup is a catalog hub — omit count chrome (`tabs.mdc`).
            count: claimsSectionTabCount(
              state,
              section,
              activeSection: effectiveSection,
            ),
            countTone: claimsSectionCountTone(section),
          ),
      ],
      selectedId: effectiveSection.name,
      onTabTapped: (String tabId) {
        for (final ClaimsDeskSection section in visibleSections) {
          if (section.name == tabId) {
            _selectSection(section);
            break;
          }
        }
      },
      primaryAction: _buildPrimaryActionButton(
        l10n,
        state,
        controller,
        accessPolicy,
        effectiveSection,
      ),
      // Refresh and insurance-setup creates were removed from the strip —
      // mutations/realtime refresh the queue; setup actions live on the panel.
    );

    return ResponsivePage(
      padding: ResponsiveSpacing.workspacePagePaddingFor(
        spacing: Theme.of(context).spacing,
      ),
      maxWidth: PageMaxWidth.dataHeavy,
      scrollable: false,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            tabStrip,
            SizedBox(height: theme.spacing.sm),
            if (effectiveSection == ClaimsDeskSection.authorizations ||
                effectiveSection == ClaimsDeskSection.activeClaims) ...<Widget>[
              _ClaimsSummaryBar(
                state: state,
                section: effectiveSection,
                onFilterApplied: (ClaimsQueueFilter filter) {
                  unawaited(_applySummaryFilter(controller, filter));
                },
              ),
              SizedBox(height: theme.spacing.md),
            ],
            if (effectiveSection == ClaimsDeskSection.insuranceSetup)
              Expanded(child: _ClaimsInsuranceSetupPanel(state: state))
            else
              Expanded(
                child: AppAccessGate(
                  // Queue list chrome → each tab atom map's listChrome (read ∩).
                  requirement: switch (effectiveSection) {
                    ClaimsDeskSection.authorizations =>
                      ClaimsAuthorizationsAtomPermissions.listChrome,
                    ClaimsDeskSection.activeClaims =>
                      ClaimsActiveClaimsAtomPermissions.listChrome,
                    ClaimsDeskSection.settled =>
                      ClaimsSettledAtomPermissions.listChrome,
                    ClaimsDeskSection.insuranceSetup =>
                      ClaimsInsuranceSetupAtomPermissions.listChrome,
                  },
                  child: _ClaimsQueuePanel(
                    state: state,
                    section: effectiveSection,
                    searchController: _searchController,
                    columnVisibilityController: _tableColumnController,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _buildPrimaryActionButton(
    AppLocalizations l10n,
    ClaimsWorkspaceState state,
    ClaimsWorkspaceController controller,
    AppAccessPolicy accessPolicy,
    ClaimsDeskSection section,
  ) {
    // Settled is review-only; Insurance Setup actions live on the panel.
    if (section == ClaimsDeskSection.settled ||
        section == ClaimsDeskSection.insuranceSetup) {
      return null;
    }
    // Unauthorized write chrome must not mount (no disabled stub).
    // Authorizations + Active Claims prepare share write ∩ (`billing:write`).
    return switch (section) {
      ClaimsDeskSection.authorizations
          when ClaimsAuthorizationsAtomPermissions.requestAuthorization
              .isAllowed(accessPolicy) =>
        AppTabToolbarPrimary(
          label: l10n.claimsRequestAuthorizationAction,
          icon: Icons.verified_user_outlined,
          semanticLabel: l10n.claimsRequestAuthorizationAction,
          tooltip: l10n.claimsRequestAuthorizationAction,
          isLoading: state.isSaving,
          onPressed: () => unawaited(
            _openRequestAuthorizationDialog(context, controller, state),
          ),
        ),
      ClaimsDeskSection.activeClaims
          when ClaimsActiveClaimsAtomPermissions.prepare.isAllowed(
            accessPolicy,
          ) =>
        AppTabToolbarPrimary(
          label: l10n.claimsPrepareClaimAction,
          icon: Icons.receipt_long_outlined,
          semanticLabel: l10n.claimsPrepareClaimAction,
          tooltip: l10n.claimsPrepareClaimAction,
          isLoading: state.isSaving,
          onPressed: () => unawaited(
            _openPrepareClaimDialog(context, ref, controller, state),
          ),
        ),
      ClaimsDeskSection.authorizations ||
      ClaimsDeskSection.activeClaims ||
      ClaimsDeskSection.settled ||
      ClaimsDeskSection.insuranceSetup => null,
    };
  }

  Future<void> _applySummaryFilter(
    ClaimsWorkspaceController controller,
    ClaimsQueueFilter filter,
  ) async {
    final AppFailure? failure = await controller.applyFilter(filter);
    if (mounted) {
      _showFailureIfNeeded(context, failure);
    }
  }
}

class _ClaimsSummaryBar extends StatelessWidget {
  const _ClaimsSummaryBar({
    required this.state,
    required this.section,
    required this.onFilterApplied,
  });

  final ClaimsWorkspaceState state;
  final ClaimsDeskSection section;
  final ValueChanged<ClaimsQueueFilter> onFilterApplied;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceSummaryNotification> cards = switch (section) {
      ClaimsDeskSection.authorizations => <AppWorkspaceSummaryNotification>[
        if (state.authorizationPendingCount > 0)
          AppWorkspaceSummaryNotification(
            label: l10n.claimsAuthorizationPendingSummaryLabel,
            count: state.authorizationPendingCount,
            icon: Icons.schedule_outlined,
            tone: AppWorkspaceStatusTone.warning,
            onSelected: () =>
                onFilterApplied(ClaimsQueueFilter.authorizationPending),
          ),
        if (state.authorizationApprovedCount > 0)
          AppWorkspaceSummaryNotification(
            label: l10n.claimsAuthorizationApprovedSummaryLabel,
            count: state.authorizationApprovedCount,
            icon: Icons.verified_outlined,
            tone: AppWorkspaceStatusTone.success,
            onSelected: () =>
                onFilterApplied(ClaimsQueueFilter.authorizationApproved),
          ),
        if (_claimsCountForFilter(
              state,
              ClaimsQueueFilter.authorizationDenied,
            ) >
            0)
          AppWorkspaceSummaryNotification(
            label: l10n.claimsFilterAuthorizationDenied,
            count: _claimsCountForFilter(
              state,
              ClaimsQueueFilter.authorizationDenied,
            ),
            icon: Icons.report_gmailerrorred_outlined,
            tone: AppWorkspaceStatusTone.error,
            onSelected: () =>
                onFilterApplied(ClaimsQueueFilter.authorizationDenied),
          ),
        if (_claimsCountForFilter(
              state,
              ClaimsQueueFilter.authorizationExpired,
            ) >
            0)
          AppWorkspaceSummaryNotification(
            label: l10n.claimsFilterAuthorizationExpired,
            count: _claimsCountForFilter(
              state,
              ClaimsQueueFilter.authorizationExpired,
            ),
            icon: Icons.block_outlined,
            onSelected: () =>
                onFilterApplied(ClaimsQueueFilter.authorizationExpired),
          ),
      ],
      ClaimsDeskSection.activeClaims => <AppWorkspaceSummaryNotification>[
        if (state.submittedClaimsCount > 0)
          AppWorkspaceSummaryNotification(
            label: l10n.claimsSubmittedSummaryLabel,
            count: state.submittedClaimsCount,
            icon: Icons.outbox_outlined,
            tone: AppWorkspaceStatusTone.info,
            onSelected: () => onFilterApplied(ClaimsQueueFilter.claimSubmitted),
          ),
        if (state.approvedClaimsCount > 0)
          AppWorkspaceSummaryNotification(
            label: l10n.claimsApprovedSummaryLabel,
            count: state.approvedClaimsCount,
            icon: Icons.fact_check_outlined,
            tone: AppWorkspaceStatusTone.success,
            onSelected: () => onFilterApplied(ClaimsQueueFilter.claimApproved),
          ),
        if (state.partialClaimsCount > 0)
          AppWorkspaceSummaryNotification(
            label: l10n.claimsPartialSummaryLabel,
            count: state.partialClaimsCount,
            icon: Icons.pie_chart_outline,
            tone: AppWorkspaceStatusTone.warning,
            onSelected: () => onFilterApplied(ClaimsQueueFilter.claimPartial),
          ),
        if (state.rejectedResubmissionCount > 0)
          AppWorkspaceSummaryNotification(
            label: l10n.claimsFilterClaimRejected,
            count: state.rejectedResubmissionCount,
            icon: Icons.report_gmailerrorred_outlined,
            tone: AppWorkspaceStatusTone.error,
            onSelected: () => onFilterApplied(ClaimsQueueFilter.claimRejected),
          ),
      ],
      _ => const <AppWorkspaceSummaryNotification>[],
    };

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.sm,
      children: <Widget>[
        for (final AppWorkspaceSummaryNotification card in cards)
          ActionChip(
            avatar: Icon(
              card.icon,
              size: 18,
              color: workspaceStatusToneAccentColor(theme, card.tone),
            ),
            label: Text('${card.label} (${card.count})'),
            onPressed: card.onSelected,
          ),
      ],
    );
  }
}

class _ClaimsInsuranceSetupPanel extends ConsumerWidget {
  const _ClaimsInsuranceSetupPanel({required this.state});

  final ClaimsWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClaimsReferenceData referenceData = state.referenceData;

    return AppAccessGate(
      requirement: ClaimsInsuranceSetupAtomPermissions.tab,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.claimsInsuranceSetupDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.lg),
            AppQuickActions(
              title: l10n.claimsSectionInsuranceSetup,
              presentation: AppQuickActionsPresentation.detailPanel,
              // hideWhenEmpty (default): collapses when all create ∩ actions
              // are filtered for read-only / subscription-stripped users.
              permissionActions: <AppPermissionActionItem>[
                AppPermissionActionItem(
                  requirement: ClaimsInsuranceSetupAtomPermissions.addCompany,
                  label: l10n.claimsAddCompanyAction,
                  icon: Icons.business_outlined,
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    unawaited(
                      openClaimsInsuranceCompanyDialog(
                        context: context,
                        ref: ref,
                        referenceData: referenceData,
                      ),
                    );
                  },
                ),
                AppPermissionActionItem(
                  requirement: ClaimsInsuranceSetupAtomPermissions.addScheme,
                  label: l10n.claimsAddSchemeAction,
                  icon: Icons.account_balance_outlined,
                  onPressed: () {
                    unawaited(
                      openClaimsSchemeDialog(
                        context: context,
                        ref: ref,
                        referenceData: referenceData,
                      ),
                    );
                  },
                ),
                AppPermissionActionItem(
                  requirement: ClaimsInsuranceSetupAtomPermissions.addOffer,
                  label: l10n.claimsAddOfferAction,
                  icon: Icons.local_offer_outlined,
                  onPressed: () {
                    unawaited(
                      openClaimsSchemeOfferDialog(
                        context: context,
                        ref: ref,
                        referenceData: referenceData,
                      ),
                    );
                  },
                ),
                AppPermissionActionItem(
                  requirement:
                      ClaimsInsuranceSetupAtomPermissions.enrollPatient,
                  label: l10n.claimsAddEnrollmentAction,
                  icon: Icons.badge_outlined,
                  onPressed: () {
                    unawaited(
                      openClaimsEnrollmentDialog(
                        context: context,
                        ref: ref,
                        referenceData: referenceData,
                      ),
                    );
                  },
                ),
                AppPermissionActionItem(
                  requirement: ClaimsInsuranceSetupAtomPermissions.addPrice,
                  label: l10n.claimsAddPriceBookAction,
                  icon: Icons.menu_book_outlined,
                  onPressed: () {
                    unawaited(
                      openClaimsPriceBookEntryDialog(
                        context: context,
                        ref: ref,
                        referenceData: referenceData,
                      ),
                    );
                  },
                ),
                AppPermissionActionItem(
                  requirement: ClaimsInsuranceSetupAtomPermissions.insurerApi,
                  label: l10n.claimsAddInsurerIntegrationAction,
                  icon: Icons.vpn_key_outlined,
                  onPressed: () {
                    unawaited(
                      openClaimsInsurerIntegrationDialog(
                        context: context,
                        ref: ref,
                        referenceData: referenceData,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimsQueuePanel extends ConsumerWidget {
  const _ClaimsQueuePanel({
    required this.state,
    required this.section,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final ClaimsWorkspaceState state;
  final ClaimsDeskSection section;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<ClaimsQueueItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final ClaimsWorkspaceController controller = ref.read(
      claimsWorkspaceControllerProvider.notifier,
    );
    final bool showNextAction = claimsSectionShowsNextActionColumn(
      accessPolicy,
      section,
    );
    final bool canExport = canExportClaimsWorkspace(accessPolicy);
    final bool canPrint = canPrintClaimsWorkspace(accessPolicy);
    final List<AppListTableColumn<ClaimsQueueItem>> columns =
        _defaultColumnsForSection(
          context,
          ref,
          l10n,
          section,
          showNextAction: showNextAction,
        );
    final List<AppListTableColumn<ClaimsQueueItem>> columnChoices =
        _columnChoicesForSection(
          context,
          l10n,
          section,
          showNextAction: showNextAction,
        );

    return AppListTable<ClaimsQueueItem>(
      page: state.queue,
      isLoading: state.isRefreshing,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'claims_${section.name}',
      columnWidthStorageKey: 'claims_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
      enableExport: true,
      canExport: canExport,
      exportLabel: l10n.commonTableExportActionLabel,
      exportDialogTitle: l10n.commonTableExportDialogTitle,
      exportCancelLabel: l10n.commonCancelActionLabel,
      exportColumnsSectionLabel: l10n.commonTableExportColumnsSectionLabel,
      exportFiltersSectionLabel: l10n.commonTableExportFiltersSectionLabel,
      exportEmptyColumnsMessage: l10n.commonTableExportEmptyColumnsMessage,
      exportEmptyRowsMessage: l10n.commonTableExportEmptyRowsMessage,
      exportSuccessMessage: l10n.commonTableExportSuccessMessage,
      exportFailureMessage: l10n.commonTableExportFailureMessage,
      exportInvalidDateMessage: l10n.opdInvalidDateMessage,
      enablePrint: true,
      canPrint: canPrint,
      printLabel: l10n.commonPrintActionLabel,
      onPrint: () => printClaimsListTable<ClaimsQueueItem>(
        ref: ref,
        context: context,
        title: switch (section) {
          ClaimsDeskSection.authorizations => l10n.claimsSectionAuthorizations,
          ClaimsDeskSection.activeClaims => l10n.claimsSectionActiveClaims,
          ClaimsDeskSection.settled => l10n.claimsSectionSettled,
          ClaimsDeskSection.insuranceSetup => l10n.claimsSectionInsuranceSetup,
        },
        columns: <AppListTableColumn<ClaimsQueueItem>>[
          ...columns,
          ...columnChoices,
        ],
        items: state.queue.items,
        emptyText: l10n.claimsEmptyQueueTitle,
      ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      exportConfig: AppListTableExportConfig<ClaimsQueueItem>(
        fileNameStem: 'claims_${section.name}',
        dateOf: (ClaimsQueueItem item) => item.timelineAt,
        sheetName: switch (section) {
          ClaimsDeskSection.authorizations => l10n.claimsSectionAuthorizations,
          ClaimsDeskSection.activeClaims => l10n.claimsSectionActiveClaims,
          ClaimsDeskSection.settled => l10n.claimsSectionSettled,
          ClaimsDeskSection.insuranceSetup => l10n.claimsSectionInsuranceSetup,
        },
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
      ),
      search: AppListTableSearch<ClaimsQueueItem>(
        controller: searchController,
        semanticLabel: l10n.claimsSearchSemanticLabel,
        hintText: l10n.claimsSearchHint,
        matcher: (ClaimsQueueItem item, String query) =>
            _claimsQueueSearchMatcher(context, l10n, section, item, query),
        onSubmitted: (String value) async {
          final AppFailure? failure = await controller.applySearch(value);
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
        onClear: () async {
          final AppFailure? failure = await controller.applySearch('');
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        advancedFilterCloseLabel: l10n.commonCloseActionLabel,
        // Product exception (tabs/15-claims/99): ClaimsQueueQuery has no date
        // range; work-items API does not accept date_from/date_to.
        enableDateFilter: false,
        allFieldsLabel: l10n.claimsFilterAll,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _claimsQueueFilterKey,
            label: l10n.claimsQueueFilterLabel,
            allLabel: l10n.claimsFilterAll,
            choices: _claimsFilterChoicesForSection(l10n, section),
          ),
        ],
        filterValue: _claimsFilterValue(state.query),
        hasActiveFilters:
            claimsQueueQueryNarrowed(state.query, section) ||
            state.query.filter != ClaimsQueueFilter.all,
        onFilterChanged: (AppSearchBarFilterValue value) async {
          final AppFailure? failure = await controller.applyFilter(
            _claimsFilterFromValue(value.option(_claimsQueueFilterKey)),
          );
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
      ),
      previousPageLabel: l10n.claimsPreviousPageLabel,
      nextPageLabel: l10n.claimsNextPageLabel,
      pageLabelBuilder: (AppPage<ClaimsQueueItem> page) {
        return l10n.claimsPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          page.totalItemCount ?? page.items.length,
        );
      },
      onPageChanged: (AppPageRequest request) {
        unawaited(controller.changePage(request));
      },
      onRowSelected: (ClaimsQueueItem item) {
        unawaited(
          _openClaimsDetailDialog(
            context,
            ref,
            state,
            item,
            section: section,
          ),
        );
      },
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.claimsEmptyQueueTitle,
        body: l10n.claimsEmptyQueueBody,
        icon: Icons.inbox_outlined,
      ),
      columns: columns,
      columnChoices: columnChoices,
      mobileItemBuilder: (BuildContext context, ClaimsQueueItem item) {
        return AppListTableMobileItem(
          title: item.displayId,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: _statusLabel(context, item),
            ),
            AppListTableMobileMeta(
              label: _fallback(context, item.patientDisplayId),
              icon: Icons.person_outline,
            ),
            AppListTableMobileMeta(
              label: _fallback(context, item.coveragePlanDisplayId),
              icon: Icons.health_and_safety_outlined,
            ),
          ],
          showAvatar: false,
          // Same stage write as the desktop next-action column (sole primary).
          trailing: showNextAction
              ? _ClaimsNextActionButton(
                  item: item,
                  section: section,
                )
              : null,
        );
      },
    );
  }
}

List<AppListTableColumn<ClaimsQueueItem>> _defaultColumnsForSection(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  ClaimsDeskSection section, {
  required bool showNextAction,
}) {
  return switch (section) {
    // Prefer 5 defaults (tables.mdc). When Next is omitted, promote the first
    // optional fact column so read-only queues still ship five visible columns.
    ClaimsDeskSection.authorizations => <AppListTableColumn<ClaimsQueueItem>>[
      _claimsReferenceColumn(l10n, id: 'auth_reference'),
      _claimsPatientColumn(l10n, id: 'auth_patient'),
      _claimsCoverageColumn(l10n, id: 'auth_coverage'),
      _claimsStatusColumn(l10n),
      if (showNextAction)
        _claimsNextActionColumn(context, ref, section)
      else
        _claimsApprovedAmountColumn(l10n, id: 'auth_approved_amount'),
    ],
    ClaimsDeskSection.activeClaims => <AppListTableColumn<ClaimsQueueItem>>[
      _claimsReferenceColumn(l10n, id: 'claim_reference'),
      _claimsPatientColumn(l10n, id: 'claim_patient'),
      _claimsCoverageColumn(l10n, id: 'claim_coverage'),
      _claimsStatusColumn(l10n),
      if (showNextAction)
        _claimsNextActionColumn(context, ref, section)
      else
        _claimsInvoiceColumn(l10n, id: 'claim_invoice'),
    ],
    ClaimsDeskSection.settled => <AppListTableColumn<ClaimsQueueItem>>[
      _claimsReferenceColumn(l10n, id: 'settled_reference'),
      _claimsPatientColumn(l10n, id: 'settled_patient'),
      _claimsCoverageColumn(l10n, id: 'settled_coverage'),
      _claimsSettlementAmountColumn(l10n),
      _claimsStatusColumn(l10n),
    ],
    ClaimsDeskSection.insuranceSetup =>
      const <AppListTableColumn<ClaimsQueueItem>>[],
  };
}

List<AppListTableColumn<ClaimsQueueItem>> _columnChoicesForSection(
  BuildContext context,
  AppLocalizations l10n,
  ClaimsDeskSection section, {
  required bool showNextAction,
}) {
  return switch (section) {
    ClaimsDeskSection.authorizations => <AppListTableColumn<ClaimsQueueItem>>[
      if (showNextAction)
        _claimsApprovedAmountColumn(l10n, id: 'auth_approved_amount'),
      _claimsRequestedAtColumn(l10n, id: 'auth_requested_at'),
    ],
    ClaimsDeskSection.activeClaims => <AppListTableColumn<ClaimsQueueItem>>[
      if (showNextAction) _claimsInvoiceColumn(l10n, id: 'claim_invoice'),
      _claimsClaimAmountColumn(l10n, id: 'claim_amount'),
      _claimsSubmittedAtColumn(l10n, id: 'claim_submitted_at'),
    ],
    ClaimsDeskSection.settled => <AppListTableColumn<ClaimsQueueItem>>[
      _claimsInvoiceColumn(l10n, id: 'settled_invoice'),
      _claimsClaimAmountColumn(l10n, id: 'settled_claim_amount'),
      _claimsTimelineColumn(l10n, id: 'settled_timeline'),
    ],
    ClaimsDeskSection.insuranceSetup =>
      const <AppListTableColumn<ClaimsQueueItem>>[],
  };
}

AppListTableColumn<ClaimsQueueItem> _claimsReferenceColumn(
  AppLocalizations l10n, {
  required String id,
}) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: id,
    label: l10n.claimsReferenceColumnLabel,
    alwaysVisible: true,
    sortComparator: (ClaimsQueueItem a, ClaimsQueueItem b) =>
        appListTableCompareText(a.displayId, b.displayId),
    exportValue: (ClaimsQueueItem item) => item.displayId,
    cellBuilder: (BuildContext context, ClaimsQueueItem item) =>
        Text(item.displayId),
  );
}

AppListTableColumn<ClaimsQueueItem> _claimsPatientColumn(
  AppLocalizations l10n, {
  required String id,
}) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: id,
    label: l10n.claimsPatientColumnLabel,
    sortComparator: (ClaimsQueueItem a, ClaimsQueueItem b) =>
        appListTableCompareText(a.patientDisplayId, b.patientDisplayId),
    exportValue: (ClaimsQueueItem item) => item.patientDisplayId,
    cellBuilder: (BuildContext context, ClaimsQueueItem item) =>
        Text(_fallback(context, item.patientDisplayId)),
  );
}

AppListTableColumn<ClaimsQueueItem> _claimsCoverageColumn(
  AppLocalizations l10n, {
  required String id,
}) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: id,
    label: l10n.claimsCoverageColumnLabel,
    sortComparator: (ClaimsQueueItem a, ClaimsQueueItem b) =>
        appListTableCompareText(
          a.coveragePlanDisplayId,
          b.coveragePlanDisplayId,
        ),
    exportValue: (ClaimsQueueItem item) => item.coveragePlanDisplayId,
    cellBuilder: (BuildContext context, ClaimsQueueItem item) =>
        Text(_fallback(context, item.coveragePlanDisplayId)),
  );
}

AppListTableColumn<ClaimsQueueItem> _claimsStatusColumn(AppLocalizations l10n) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: 'status',
    label: l10n.claimsStatusColumnLabel,
    sortComparator: (ClaimsQueueItem a, ClaimsQueueItem b) =>
        appListTableCompareText(a.status, b.status),
    exportValue: (ClaimsQueueItem item) => item.status,
    cellBuilder: (BuildContext context, ClaimsQueueItem item) =>
        AppWorkspaceStatusBadge(status: _statusFor(context, item)),
  );
}

AppListTableColumn<ClaimsQueueItem> _claimsInvoiceColumn(
  AppLocalizations l10n, {
  required String id,
}) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: id,
    label: l10n.claimsInvoiceColumnLabel,
    sortComparator: (ClaimsQueueItem a, ClaimsQueueItem b) =>
        appListTableCompareText(a.invoiceDisplayId, b.invoiceDisplayId),
    exportValue: (ClaimsQueueItem item) => item.invoiceDisplayId,
    cellBuilder: (BuildContext context, ClaimsQueueItem item) =>
        Text(_fallback(context, item.invoiceDisplayId)),
  );
}

AppListTableColumn<ClaimsQueueItem> _claimsClaimAmountColumn(
  AppLocalizations l10n, {
  required String id,
}) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: id,
    label: l10n.claimsAmountColumnLabel,
    numeric: true,
    exportValue: (ClaimsQueueItem item) => item.claim?.claimAmount,
    cellBuilder: (BuildContext context, ClaimsQueueItem item) {
      final num? amount = item.claim?.claimAmount;
      if (amount == null) return Text(_fallback(context, null));
      return Text(
        AppFormatters.currency(amount, Localizations.localeOf(context)),
      );
    },
  );
}

AppListTableColumn<ClaimsQueueItem> _claimsApprovedAmountColumn(
  AppLocalizations l10n, {
  required String id,
}) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: id,
    label: l10n.claimsAmountColumnLabel,
    numeric: true,
    exportValue: (ClaimsQueueItem item) => item.authorization?.approvedAmount,
    cellBuilder: (BuildContext context, ClaimsQueueItem item) {
      final num? amount = item.authorization?.approvedAmount;
      if (amount == null) return Text(_fallback(context, null));
      return Text(
        AppFormatters.currency(amount, Localizations.localeOf(context)),
      );
    },
  );
}

AppListTableColumn<ClaimsQueueItem> _claimsSettlementAmountColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: 'settled_settlement_amount',
    label: l10n.claimsSettlementAmountColumnLabel,
    numeric: true,
    exportValue: (ClaimsQueueItem item) => item.claim?.settlementAmount,
    cellBuilder: (BuildContext context, ClaimsQueueItem item) {
      final num? amount = item.claim?.settlementAmount;
      if (amount == null) return Text(_fallback(context, null));
      return Text(
        AppFormatters.currency(amount, Localizations.localeOf(context)),
      );
    },
  );
}

AppListTableColumn<ClaimsQueueItem> _claimsRequestedAtColumn(
  AppLocalizations l10n, {
  required String id,
}) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: id,
    label: l10n.claimsRequestedAtColumnLabel,
    sortComparator: (ClaimsQueueItem a, ClaimsQueueItem b) =>
        appListTableCompareDateTime(
          a.authorization?.requestedAt,
          b.authorization?.requestedAt,
        ),
    exportValue: (ClaimsQueueItem item) =>
        item.authorization?.requestedAt?.toIso8601String(),
    cellBuilder: (BuildContext context, ClaimsQueueItem item) =>
        Text(_dateTimeLabel(context, item.authorization?.requestedAt)),
  );
}

AppListTableColumn<ClaimsQueueItem> _claimsSubmittedAtColumn(
  AppLocalizations l10n, {
  required String id,
}) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: id,
    label: l10n.claimsSubmittedAtColumnLabel,
    sortComparator: (ClaimsQueueItem a, ClaimsQueueItem b) =>
        appListTableCompareDateTime(a.claim?.submittedAt, b.claim?.submittedAt),
    exportValue: (ClaimsQueueItem item) =>
        item.claim?.submittedAt?.toIso8601String(),
    cellBuilder: (BuildContext context, ClaimsQueueItem item) =>
        Text(_dateTimeLabel(context, item.claim?.submittedAt)),
  );
}

AppListTableColumn<ClaimsQueueItem> _claimsTimelineColumn(
  AppLocalizations l10n, {
  required String id,
}) {
  return AppListTableColumn<ClaimsQueueItem>(
    id: id,
    label: l10n.claimsTimelineColumnLabel,
    sortComparator: (ClaimsQueueItem a, ClaimsQueueItem b) =>
        appListTableCompareDateTime(a.timelineAt, b.timelineAt),
    exportValue: (ClaimsQueueItem item) => item.timelineAt?.toIso8601String(),
    cellBuilder: (BuildContext context, ClaimsQueueItem item) =>
        Text(_dateTimeLabel(context, item.timelineAt)),
  );
}

AppListTableColumn<ClaimsQueueItem> _claimsNextActionColumn(
  BuildContext context,
  WidgetRef ref,
  ClaimsDeskSection section,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<ClaimsQueueItem>(
    id: 'next_action',
    label: l10n.claimsNextActionColumnLabel,
    alwaysVisible: true,
    exportable: false,
    sortComparator: (ClaimsQueueItem a, ClaimsQueueItem b) =>
        appListTableCompareText(
          _claimsNextActionLabel(l10n, a),
          _claimsNextActionLabel(l10n, b),
        ),
    cellBuilder: (BuildContext context, ClaimsQueueItem item) {
      return _ClaimsNextActionButton(
        item: item,
        section: section,
      );
    },
  );
}

String _claimsNextActionLabel(AppLocalizations l10n, ClaimsQueueItem item) {
  if (item.isAuthorization) {
    return l10n.claimsUpdateStatusAction;
  }
  final String status = item.status.toUpperCase();
  if (status == 'PAID' || status == 'CANCELLED') {
    return '';
  }
  return switch (status) {
    'REJECTED' => l10n.claimsResubmitClaimAction,
    'SUBMITTED' => l10n.claimsRecordResponseAction,
    'APPROVED' => l10n.claimsCloseClaimAction,
    'PARTIAL' => l10n.claimsRecordResponseAction,
    _ => l10n.claimsSubmitClaimAction,
  };
}

bool _claimsQueueSearchMatcher(
  BuildContext context,
  AppLocalizations l10n,
  ClaimsDeskSection section,
  ClaimsQueueItem item,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  final Locale locale = Localizations.localeOf(context);
  final List<String> haystack = <String>[
    item.displayId,
    item.patientDisplayId ?? '',
    item.coveragePlanDisplayId,
    item.invoiceDisplayId ?? '',
    _statusLabel(context, item),
    _kindLabel(context, item.kind),
    _claimsNextActionLabel(l10n, item),
  ];

  final num? approvedAmount = item.authorization?.approvedAmount;
  if (approvedAmount != null) {
    haystack.add(AppFormatters.currency(approvedAmount, locale));
  }
  final num? claimAmount = item.claim?.claimAmount;
  if (claimAmount != null) {
    haystack.add(AppFormatters.currency(claimAmount, locale));
  }
  final num? settlementAmount = item.claim?.settlementAmount;
  if (settlementAmount != null) {
    haystack.add(AppFormatters.currency(settlementAmount, locale));
  }

  final DateTime? requestedAt = item.authorization?.requestedAt;
  if (requestedAt != null) {
    haystack.add(_dateTimeLabel(context, requestedAt));
  }
  final DateTime? submittedAt = item.claim?.submittedAt;
  if (submittedAt != null) {
    haystack.add(_dateTimeLabel(context, submittedAt));
  }
  if (item.timelineAt != null) {
    haystack.add(_dateTimeLabel(context, item.timelineAt));
  }

  return haystack.any(
    (String value) =>
        value.trim().isNotEmpty && value.toLowerCase().contains(needle),
  );
}

class _ClaimsNextActionButton extends ConsumerWidget {
  const _ClaimsNextActionButton({
    required this.item,
    required this.section,
  });

  final ClaimsQueueItem item;
  final ClaimsDeskSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (section == ClaimsDeskSection.settled) {
      return const SizedBox.shrink();
    }

    final AppLocalizations l10n = context.l10n;
    final String label = _claimsNextActionLabel(l10n, item);
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppAccessActionGate(
      requirement: item.isAuthorization
          ? ClaimsAuthorizationsAtomPermissions.nextAction
          : claimsNextActionRequirement(item),
      builder: (BuildContext context, bool isAllowed) {
        final bool isNarrow = MediaQuery.sizeOf(context).width < 600;
        return AppButton.tertiary(
          label: label,
          icon: isNarrow ? Icons.play_arrow_outlined : null,
          iconOnly: isNarrow,
          tooltip: label,
          semanticLabel: label,
          onPressed: () => unawaited(
            _handleClaimsNextAction(context, ref, item),
          ),
        );
      },
    );
  }
}

Future<void> _handleClaimsNextAction(
  BuildContext context,
  WidgetRef ref,
  ClaimsQueueItem item,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  // Defense in depth: gated chrome must not open write dialogs without rights.
  if (!claimsNextActionIsAllowed(policy, item)) {
    return;
  }

  final ClaimsWorkspaceController controller = ref.read(
    claimsWorkspaceControllerProvider.notifier,
  );
  // Capture a navigator-owned context before focus rebuilds the queue row.
  final NavigatorState navigator = Navigator.of(context);
  // Stage writes only need embedded ids — skip the detail fetch shell.
  controller.focusItem(item);

  final BuildContext dialogContext = navigator.context;
  if (!dialogContext.mounted) {
    return;
  }

  final AppLocalizations l10n = dialogContext.l10n;
  final ClaimsQueueDetail focused = ClaimsQueueDetail(
    item: item,
    authorization: item.authorization,
    claim: item.claim,
  );

  if (item.isAuthorization) {
    await _openAuthorizationStatusDialog(dialogContext, controller, focused);
    return;
  }

  final String status = item.status.toUpperCase();
  if (status == 'PAID' || status == 'CANCELLED') {
    return;
  }

  switch (status) {
    case 'REJECTED':
      await _openSubmitClaimDialog(dialogContext, controller);
    case 'SUBMITTED':
    case 'PARTIAL':
      await _openClaimResponseDialog(
        dialogContext,
        controller,
        initialStatus: 'APPROVED',
        title: l10n.claimsRecordResponseDialogTitle,
        submitLabel: l10n.claimsRecordResponseSubmitAction,
      );
    case 'APPROVED':
      // Next-action already chose "Close as paid" — do not restate status.
      await _openClaimResponseDialog(
        dialogContext,
        controller,
        initialStatus: 'PAID',
        title: l10n.claimsCloseClaimDialogTitle,
        submitLabel: l10n.claimsCloseClaimSubmitAction,
        statusEditable: false,
      );
    default:
      await _openSubmitClaimDialog(dialogContext, controller);
  }
}


Future<void> _openClaimsDetailDialog(
  BuildContext context,
  WidgetRef ref,
  ClaimsWorkspaceState fallbackState,
  ClaimsQueueItem item, {
  required ClaimsDeskSection section,
}) async {
  final ClaimsWorkspaceController controller = ref.read(
    claimsWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectItem(item);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final ClaimsWorkspaceState state = _readClaimsState(ref) ?? fallbackState;
  final ClaimsQueueDetail? detail = state.selectedDetail;
  if (detail == null) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  final AppAccessPolicy accessPolicy = ref.read(appAccessPolicyProvider);
  final AccessRequirement printRequirement = claimsDetailPrintRequirement(section);
  final bool canPrint = printRequirement.isAllowed(accessPolicy);

  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.claimsDetailTitle),
      icon: const Icon(Icons.fact_check_outlined),
      scrollable: true,
      maxWidth: 960,
      content: _ClaimsDetailContent(
        state: state,
        detail: detail,
        section: section,
      ),
      actions: <Widget>[
        // Detail Print — [claimsDetailPrintRequirement] (Settled ∩ evidence:export;
        // other sections: document read ∩). Unauthorized Print does not mount.
        if (canPrint)
          AppReportActionButton.print(
            label: l10n.commonPrintActionLabel,
            onPressed: () async {
              final String title = detail.isAuthorization
                  ? l10n.claimsAuthorizationStatementTitle
                  : l10n.claimsClaimStatementTitle;
              await PrintDocumentTemplates.claimStatement(
                ref: ref,
                context: context,
                title: title,
                patientContext: detail.item.patientDisplayId == null
                    ? null
                    : buildPrintFormPatientContext(
                        l10n,
                        patientName: detail.item.patientDisplayId!,
                        patientId: detail.item.patientDisplayId,
                      ),
                claimReference: PrintFormContextReference(
                  label: detail.isAuthorization
                      ? l10n.claimsAuthorizationStatementTitle
                      : l10n.claimsClaimStatementTitle,
                  value: detail.item.displayId,
                ),
                bodyHtml: _claimsStatementHtml(context, detail),
                footerNote: l10n.claimsReportFooter,
                includeSignatures: true,
              );
            },
          ),
      ],
    ),
  );
}

ClaimsWorkspaceState? _readClaimsState(WidgetRef ref) {
  return ref
      .read(claimsWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (ClaimsWorkspaceState state) => state,
        failure: (_) => null,
      );
}

class _ClaimsDetailContent extends ConsumerWidget {
  const _ClaimsDetailContent({
    required this.state,
    required this.detail,
    required this.section,
  });

  final ClaimsWorkspaceState state;
  final ClaimsQueueDetail detail;
  final ClaimsDeskSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClaimsWorkspaceController controller = ref.read(
      claimsWorkspaceControllerProvider.notifier,
    );
    final List<AppPermissionActionItem> detailActions =
        _detailPermissionActions(
          context,
          controller,
          state,
          detail,
          section: section,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPatientDetails(
          patientName: _detailTitle(context, detail),
          patientNumber: _detailNumber(context, detail),
          compactSupportingText: _detailSubtitle(context, detail),
          semanticLabel: l10n.claimsPatientContextLabel,
          showAvatar: false,
          status: _statusFor(context, detail.item),
          expandedFields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.claimsCoverageFieldLabel,
              value: _coverageLabel(context, detail),
              icon: Icons.verified_user_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.claimsInsuranceCompanyFieldLabel,
              value:
                  detail.coveragePlan?.insuranceCompanyName ??
                  detail.coveragePlan?.providerName ??
                  l10n.claimsUnknownPayerLabel,
              icon: Icons.business_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.claimsInvoiceFieldLabel,
              value: detail.claim?.invoiceDisplayId ?? '',
              icon: Icons.receipt_long_outlined,
              copyable: true,
              copyTooltip: l10n.copyIdentifierAction,
              copiedMessage: l10n.identifierCopiedMessage,
            ),
            AppWorkspacePatientContextField(
              label: l10n.claimsClaimAmountFieldLabel,
              value: _claimAmountLabel(context, detail),
              icon: Icons.request_quote_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.claimsAmountFieldLabel,
              value: _amountLabel(context, detail.invoice),
              icon: Icons.payments_outlined,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        // Status-primary writes live on row next-action; detail keeps Sync only.
        if (detailActions.isNotEmpty) ...<Widget>[
          AppQuickActions(
            title: l10n.claimsDetailTitle,
            presentation: AppQuickActionsPresentation.detailPanel,
            permissionActions: detailActions,
          ),
          SizedBox(height: theme.spacing.lg),
        ],
        _BillingImpactPanel(detail: detail),
        SizedBox(height: theme.spacing.lg),
        _RequiredDocumentsPanel(detail: detail),
        SizedBox(height: theme.spacing.lg),
        _TimelinePanel(detail: detail),
      ],
    );
  }
}

class _BillingImpactPanel extends StatelessWidget {
  const _BillingImpactPanel({required this.detail});

  final ClaimsQueueDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ClaimInvoiceOption? invoice = detail.invoice;
    final CoveragePlanOption? coverage = detail.coveragePlan;
    final PreAuthorizationRecord? authorization = detail.authorization;
    final String body = detail.isAuthorization
        ? l10n.claimsAuthorizationBillingImpactBody
        : _claimBillingImpact(context, detail);

    final List<AppInfoTileData> tiles = detail.isAuthorization
        ? <AppInfoTileData>[
            AppInfoTileData(
              icon: Icons.verified_user_outlined,
              label: l10n.claimsCoveragePercentLabel,
              value: coverage?.coveragePercentage == null
                  ? l10n.profileUnknownValue
                  : l10n.claimsCoveragePercentValue(
                      coverage!.coveragePercentage!.toString(),
                    ),
            ),
            AppInfoTileData(
              icon: Icons.check_circle_outline,
              label: l10n.claimsApprovedAmountLabel,
              value: _preAuthMoneyLabel(context, authorization?.approvedAmount),
            ),
            AppInfoTileData(
              icon: Icons.payments_outlined,
              label: l10n.claimsConsumedAmountLabel,
              value: _preAuthMoneyLabel(context, authorization?.consumedAmount),
            ),
            AppInfoTileData(
              icon: Icons.account_balance_wallet_outlined,
              label: l10n.claimsRemainingAmountLabel,
              value: _preAuthMoneyLabel(context, authorization?.remainingAmount),
            ),
          ]
        : <AppInfoTileData>[
            AppInfoTileData(
              icon: Icons.verified_user_outlined,
              label: l10n.claimsCoveragePercentLabel,
              value: coverage?.coveragePercentage == null
                  ? l10n.profileUnknownValue
                  : l10n.claimsCoveragePercentValue(
                      coverage!.coveragePercentage!.toString(),
                    ),
            ),
            AppInfoTileData(
              icon: Icons.receipt_long_outlined,
              label: l10n.claimsInvoiceStatusLabel,
              value: _invoiceStatusLabel(context, invoice),
            ),
            AppInfoTileData(
              icon: Icons.payments_outlined,
              label: l10n.claimsPatientBalanceLabel,
              value: _patientBalanceLabel(context, detail),
            ),
          ];

    return AppCollapsibleSection(
      title: l10n.claimsBillingImpactTitle,
      description: body,
      child: AppInfoTileGrid(items: tiles),
    );
  }
}

class _RequiredDocumentsPanel extends StatelessWidget {
  const _RequiredDocumentsPanel({required this.detail});

  final ClaimsQueueDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceStatus> statuses = <AppWorkspaceStatus>[
      AppWorkspaceStatus(
        label: l10n.claimsDocumentInvoiceSummary,
        tone: detail.invoice == null && detail.isClaim
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: detail.invoice == null && detail.isClaim
            ? Icons.schedule_outlined
            : Icons.check_circle_outline,
      ),
      AppWorkspaceStatus(
        label: l10n.claimsDocumentCoveragePlan,
        tone: detail.coveragePlan == null
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: detail.coveragePlan == null
            ? Icons.schedule_outlined
            : Icons.check_circle_outline,
      ),
      AppWorkspaceStatus(
        label: l10n.claimsDocumentPayerResponse,
        tone: _hasPayerResponse(detail)
            ? AppWorkspaceStatusTone.success
            : AppWorkspaceStatusTone.info,
        icon: _hasPayerResponse(detail)
            ? Icons.check_circle_outline
            : Icons.info_outline,
      ),
    ];

    return AppCollapsibleSection(
      title: l10n.claimsRequiredDocumentsTitle,
      description: l10n.claimsRequiredDocumentsBody,
      child: Wrap(
        spacing: Theme.of(context).spacing.sm,
        runSpacing: Theme.of(context).spacing.sm,
        children: <Widget>[
          for (final AppWorkspaceStatus status in statuses)
            AppStatusBadge.fromStatus(status),
        ],
      ),
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.detail});

  final ClaimsQueueDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppTimeline(
      title: l10n.claimsTimelineTitle,
      description: l10n.claimsTimelineDescription,
      asActivityList: true,
      items: <AppTimelineItem>[
        if (detail.authorization?.requestedAt != null)
          AppTimelineItem(
            title: l10n.claimsTimelineAuthorizationRequested,
            occurredAt: detail.authorization!.requestedAt,
            icon: Icons.schedule_outlined,
            tone: AppWorkspaceStatusTone.info,
          ),
        if (detail.authorization?.approvedAt != null)
          AppTimelineItem(
            title: l10n.claimsTimelineAuthorizationResponded,
            occurredAt: detail.authorization!.approvedAt,
            icon: Icons.verified_outlined,
            tone: AppWorkspaceStatusTone.success,
          ),
        if (detail.claim?.submittedAt != null)
          AppTimelineItem(
            title: l10n.claimsTimelineClaimSubmitted,
            occurredAt: detail.claim!.submittedAt,
            icon: Icons.outbox_outlined,
            tone: AppWorkspaceStatusTone.info,
          ),
        AppTimelineItem(
          title: l10n.claimsTimelineCurrentStatus,
          subtitle: _statusLabel(context, detail.item),
          icon: _kindIcon(detail.item.kind),
          tone: _statusTone(detail.item),
        ),
      ],
    );
  }
}

class _CoveragePlanDialog extends StatefulWidget {
  const _CoveragePlanDialog({
    required this.insuranceCompanies,
    required this.coveragePlans,
    required this.onSubmit,
  });

  final List<InsuranceCompanyOption> insuranceCompanies;
  final List<CoveragePlanOption> coveragePlans;
  final Future<AppFailure?> Function(String coveragePlanId) onSubmit;

  @override
  State<_CoveragePlanDialog> createState() => _CoveragePlanDialogState();
}

class _CoveragePlanDialogState extends State<_CoveragePlanDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _insuranceCompanyId;
  String? _coveragePlanId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  List<CoveragePlanOption> get _schemes {
    if (_insuranceCompanyId == null || _insuranceCompanyId!.isEmpty) {
      return widget.coveragePlans;
    }
    return widget.coveragePlans
        .where(
          (CoveragePlanOption plan) =>
              plan.insuranceCompanyId == _insuranceCompanyId,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<CoveragePlanOption> schemes = _schemes;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        if (widget.insuranceCompanies.isNotEmpty)
          AppSelectField<String>.searchable(
            labelText: l10n.claimsInsuranceCompanyFieldLabel,
            value: _insuranceCompanyId,
            enabled: widget.insuranceCompanies.isNotEmpty,
            options: <AppSelectOption<String>>[
              for (final InsuranceCompanyOption company
                  in widget.insuranceCompanies)
                AppSelectOption<String>(
                  value: company.id,
                  label: company.title,
                ),
            ],
            onChanged: (String? value) {
              setState(() {
                _insuranceCompanyId = value;
                final List<CoveragePlanOption> next = widget.coveragePlans
                    .where(
                      (CoveragePlanOption plan) =>
                          plan.insuranceCompanyId == value,
                    )
                    .toList(growable: false);
                _coveragePlanId = next.isEmpty ? null : next.first.apiId;
              });
            },
          ),
        AppSelectField<String>.searchable(
          labelText: l10n.claimsCoverageSchemeFieldLabel,
          hintText: l10n.claimsCoveragePlanHint,
          value: _coveragePlanId,
          isRequired: true,
          enabled: schemes.isNotEmpty,
          validator: AppValidators.requiredValue<String>(
            l10n.claimsCoveragePlanRequiredMessage,
          ),
          options: _coveragePlanOptions(schemes),
          onChanged: (String? value) {
            setState(() {
              _coveragePlanId = value;
            });
          },
        ),
        if (widget.coveragePlans.isEmpty)
          AppWorkspaceStatePanel.state(
            variant: AppStateViewVariant.validation,
            title: l10n.claimsCoverageUnavailableTitle,
            body: l10n.claimsCoverageUnavailableBody,
            minHeight: 120,
          ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsRequestAuthorizationSubmitAction,
          submitIcon: Icons.verified_user_outlined,
          isSubmitting: _isSubmitting,
          enabled: schemes.isNotEmpty,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(_coveragePlanId!);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

class _PrepareClaimDialog extends StatefulWidget {
  const _PrepareClaimDialog({
    required this.insuranceCompanies,
    required this.coveragePlans,
    required this.invoices,
    required this.onSubmit,
  });

  final List<InsuranceCompanyOption> insuranceCompanies;
  final List<CoveragePlanOption> coveragePlans;
  final List<ClaimInvoiceOption> invoices;
  final Future<AppFailure?> Function({
    required String coveragePlanId,
    required String invoiceId,
  })
  onSubmit;

  @override
  State<_PrepareClaimDialog> createState() => _PrepareClaimDialogState();
}

class _PrepareClaimDialogState extends State<_PrepareClaimDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _insuranceCompanyId;
  String? _coveragePlanId;
  String? _invoiceId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  List<CoveragePlanOption> get _schemes {
    if (_insuranceCompanyId == null || _insuranceCompanyId!.isEmpty) {
      return widget.coveragePlans;
    }
    return widget.coveragePlans
        .where(
          (CoveragePlanOption plan) =>
              plan.insuranceCompanyId == _insuranceCompanyId,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<CoveragePlanOption> schemes = _schemes;
    final bool hasRequiredData =
        schemes.isNotEmpty && widget.invoices.isNotEmpty;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        if (widget.insuranceCompanies.isNotEmpty)
          AppSelectField<String>.searchable(
            labelText: l10n.claimsInsuranceCompanyFieldLabel,
            value: _insuranceCompanyId,
            enabled: widget.insuranceCompanies.isNotEmpty,
            options: <AppSelectOption<String>>[
              for (final InsuranceCompanyOption company
                  in widget.insuranceCompanies)
                AppSelectOption<String>(
                  value: company.id,
                  label: company.title,
                ),
            ],
            onChanged: (String? value) {
              setState(() {
                _insuranceCompanyId = value;
                final List<CoveragePlanOption> next = widget.coveragePlans
                    .where(
                      (CoveragePlanOption plan) =>
                          plan.insuranceCompanyId == value,
                    )
                    .toList(growable: false);
                _coveragePlanId = next.isEmpty ? null : next.first.apiId;
              });
            },
          ),
        AppSelectField<String>.searchable(
          labelText: l10n.claimsCoverageSchemeFieldLabel,
          hintText: l10n.claimsCoveragePlanHint,
          value: _coveragePlanId,
          isRequired: true,
          enabled: schemes.isNotEmpty,
          validator: AppValidators.requiredValue<String>(
            l10n.claimsCoveragePlanRequiredMessage,
          ),
          options: _coveragePlanOptions(schemes),
          onChanged: (String? value) {
            setState(() {
              _coveragePlanId = value;
            });
          },
        ),
        AppSelectField<String>.searchable(
          labelText: l10n.claimsInvoiceFieldLabel,
          hintText: l10n.claimsInvoiceHint,
          value: _invoiceId,
          isRequired: true,
          enabled: widget.invoices.isNotEmpty,
          validator: AppValidators.requiredValue<String>(
            l10n.claimsInvoiceRequiredMessage,
          ),
          options: _invoiceOptions(context, widget.invoices),
          onChanged: (String? value) {
            setState(() {
              _invoiceId = value;
            });
          },
        ),
        if (!hasRequiredData)
          AppWorkspaceStatePanel.state(
            variant: AppStateViewVariant.validation,
            title: l10n.claimsPrepareClaimUnavailableTitle,
            body: l10n.claimsPrepareClaimUnavailableBody,
            minHeight: 120,
          ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsPrepareClaimSubmitAction,
          submitIcon: Icons.receipt_long_outlined,
          isSubmitting: _isSubmitting,
          enabled: hasRequiredData,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      coveragePlanId: _coveragePlanId!,
      invoiceId: _invoiceId!,
    );
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

class _AuthorizationStatusDialog extends StatefulWidget {
  const _AuthorizationStatusDialog({
    required this.currentStatus,
    required this.onSubmit,
  });

  final String currentStatus;
  final Future<AppFailure?> Function(String status, num? approvedAmount)
  onSubmit;

  @override
  State<_AuthorizationStatusDialog> createState() {
    return _AuthorizationStatusDialogState();
  }
}

class _AuthorizationStatusDialogState
    extends State<_AuthorizationStatusDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _approvedAmountController =
      TextEditingController();
  late String _status;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus.toUpperCase();
  }

  @override
  void dispose() {
    _approvedAmountController.dispose();
    super.dispose();
  }

  bool get _needsAmount => _status == 'APPROVED' || _status == 'PARTIAL';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppSelectField<String>(
          labelText: l10n.claimsAuthorizationStatusFieldLabel,
          value: _status,
          isRequired: true,
          options: _authorizationStatusOptions(l10n),
          validator: AppValidators.requiredValue<String>(
            l10n.claimsStatusRequiredMessage,
          ),
          onChanged: (String? value) {
            setState(() {
              _status = value ?? _status;
            });
          },
        ),
        if (_needsAmount)
          AppTextField(
            controller: _approvedAmountController,
            labelText: l10n.claimsApprovedAmountFieldLabel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            isRequired: true,
            validator: AppValidators.compose(<FormFieldValidator<String>>[
              AppValidators.requiredText(l10n.claimsStatusRequiredMessage),
              (String? value) {
                final num? amount = num.tryParse(value?.trim() ?? '');
                if (amount == null || amount < 0) {
                  return l10n.claimsStatusRequiredMessage;
                }
                return null;
              },
            ]),
          ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsUpdateStatusSubmitAction,
          submitIcon: Icons.fact_check_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final num? approvedAmount = num.tryParse(
      _approvedAmountController.text.trim(),
    );
    final AppFailure? failure = await widget.onSubmit(_status, approvedAmount);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

class _ClaimSubmitDialog extends StatefulWidget {
  const _ClaimSubmitDialog({required this.onSubmit});

  final Future<AppFailure?> Function(String notes) onSubmit;

  @override
  State<_ClaimSubmitDialog> createState() => _ClaimSubmitDialogState();
}

class _ClaimSubmitDialogState extends State<_ClaimSubmitDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppTextField(
          controller: _notesController,
          labelText: l10n.claimsNotesFieldLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsSubmitClaimSubmitAction,
          submitIcon: Icons.outbox_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      _notesController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

class _ClaimResponseDialog extends StatefulWidget {
  const _ClaimResponseDialog({
    required this.initialStatus,
    required this.submitLabel,
    required this.onSubmit,
    this.statusEditable = true,
    this.allowSettlingStatuses = false,
  });

  final String initialStatus;
  final String submitLabel;
  final bool statusEditable;

  /// PAID / PARTIAL remittance requires financial:approve ∩.
  final bool allowSettlingStatuses;
  final Future<AppFailure?> Function({
    required String status,
    required String notes,
    num? settlementAmount,
  })
  onSubmit;

  @override
  State<_ClaimResponseDialog> createState() => _ClaimResponseDialogState();
}

class _ClaimResponseDialogState extends State<_ClaimResponseDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _settlementController = TextEditingController();
  late String _status;
  bool _isSubmitting = false;
  AppFailure? _failure;

  bool get _requiresSettlement => _status == 'PAID' || _status == 'PARTIAL';

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _settlementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        if (widget.statusEditable)
          AppSelectField<String>(
            labelText: l10n.claimsClaimResponseFieldLabel,
            value: _status,
            isRequired: true,
            options: _claimResponseOptions(
              l10n,
              allowSettlingStatuses: widget.allowSettlingStatuses,
            ),
            validator: AppValidators.requiredValue<String>(
              l10n.claimsStatusRequiredMessage,
            ),
            onChanged: (String? value) {
              setState(() {
                _status = value ?? _status;
              });
            },
          ),
        if (_requiresSettlement)
          AppTextField(
            controller: _settlementController,
            labelText: l10n.claimsSettlementAmountColumnLabel,
            isRequired: _status == 'PARTIAL',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (String? value) {
              if (_status != 'PARTIAL') {
                return null;
              }
              final String normalized = value?.replaceAll(',', '').trim() ?? '';
              if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized) ||
                  (num.tryParse(normalized) ?? 0) <= 0) {
                return l10n.billingAdjustmentAmountValidation;
              }
              return null;
            },
          ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.claimsNotesFieldLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.submitLabel,
          submitIcon: Icons.fact_check_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final String settlementRaw = _settlementController.text
        .replaceAll(',', '')
        .trim();
    final num? settlementAmount = _requiresSettlement && settlementRaw.isNotEmpty
        ? num.tryParse(settlementRaw)
        : null;
    final AppFailure? failure = await widget.onSubmit(
      status: _status,
      notes: _notesController.text.trim(),
      settlementAmount: settlementAmount,
    );
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

Future<void> _openRequestAuthorizationDialog(
  BuildContext context,
  ClaimsWorkspaceController controller,
  ClaimsWorkspaceState state,
) async {
  // Defense in depth: strip primary / deep-link must not open create without write ∩.
  final AppAccessPolicy policy = ProviderScope.containerOf(
    context,
  ).read(appAccessPolicyProvider);
  if (!ClaimsAuthorizationsAtomPermissions.requestAuthorization.isAllowed(
    policy,
  )) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsRequestAuthorizationDialogTitle),
    content: _CoveragePlanDialog(
      insuranceCompanies: state.referenceData.insuranceCompanies,
      coveragePlans: state.referenceData.coveragePlans,
      onSubmit: (String coveragePlanId) {
        return controller.requestPreAuthorization(
          coveragePlanId: coveragePlanId,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _openPrepareClaimDialog(
  BuildContext context,
  WidgetRef ref,
  ClaimsWorkspaceController controller,
  ClaimsWorkspaceState state,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  // Defense in depth: never open prepare for read-only / stripped policies.
  if (!ClaimsActiveClaimsAtomPermissions.prepare.isAllowed(policy)) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsPrepareClaimDialogTitle),
    content: _PrepareClaimDialog(
      insuranceCompanies: state.referenceData.insuranceCompanies,
      coveragePlans: state.referenceData.coveragePlans,
      invoices: state.referenceData.invoices,
      onSubmit: controller.prepareClaim,
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _openAuthorizationStatusDialog(
  BuildContext context,
  ClaimsWorkspaceController controller,
  ClaimsQueueDetail detail,
) async {
  // Defense in depth: next-action must not open update without write ∩.
  final AppAccessPolicy policy = ProviderScope.containerOf(
    context,
  ).read(appAccessPolicyProvider);
  if (!ClaimsAuthorizationsAtomPermissions.update.isAllowed(policy)) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsUpdateAuthorizationDialogTitle),
    content: _AuthorizationStatusDialog(
      currentStatus: detail.item.status,
      onSubmit: (String status, num? approvedAmount) {
        return controller.updateAuthorizationStatus(
          status: status,
          approvedAmount: approvedAmount,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _openSubmitClaimDialog(
  BuildContext context,
  ClaimsWorkspaceController controller,
) async {
  // Defense in depth: submit / resubmit need write ∩ (Active Claims update).
  final AppAccessPolicy policy = ProviderScope.containerOf(
    context,
  ).read(appAccessPolicyProvider);
  if (!ClaimsActiveClaimsAtomPermissions.submit.isAllowed(policy)) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsSubmitClaimDialogTitle),
    content: _ClaimSubmitDialog(
      onSubmit: (String notes) {
        return controller.submitClaim(notes: notes);
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _openClaimResponseDialog(
  BuildContext context,
  ClaimsWorkspaceController controller, {
  required String initialStatus,
  required String title,
  required String submitLabel,
  bool statusEditable = true,
}) async {
  // Defense in depth: record response → write ∩; close-as-paid → approve ∩.
  // Editable PAID option also needs financial:approve (settlement).
  final AppAccessPolicy policy = ProviderScope.containerOf(
    context,
  ).read(appAccessPolicyProvider);
  final AccessRequirement requirement = statusEditable
      ? ClaimsActiveClaimsAtomPermissions.recordResponse
      : ClaimsActiveClaimsAtomPermissions.closeAsPaid;
  if (!requirement.isAllowed(policy)) {
    return;
  }
  final bool allowSettlingStatuses =
      ClaimsActiveClaimsAtomPermissions.closeAsPaid.isAllowed(policy);

  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(title),
    content: _ClaimResponseDialog(
      initialStatus: initialStatus,
      submitLabel: submitLabel,
      statusEditable: statusEditable,
      allowSettlingStatuses: allowSettlingStatuses,
      onSubmit:
          ({
            required String status,
            required String notes,
            num? settlementAmount,
          }) async {
            final String normalized = status.toUpperCase();
            // PAID / PARTIAL remittance always needs approve ∩.
            if ((normalized == 'PAID' || normalized == 'PARTIAL') &&
                !allowSettlingStatuses) {
              return AppFailure.forbidden();
            }
            return controller.reconcileClaim(
              status: status,
              notes: notes,
              settlementAmount: settlementAmount,
            );
          },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

List<AppPermissionActionItem> _detailPermissionActions(
  BuildContext context,
  ClaimsWorkspaceController controller,
  ClaimsWorkspaceState state,
  ClaimsQueueDetail detail, {
  required ClaimsDeskSection section,
}) {
  // Status-primary mutations match row next-action — omit from detail.
  // Sync is Active Claims detail-only (inventory); Settled is review-only.
  // Residual co-pay deep-links Billing receive-payment (no local cashier).
  final AppLocalizations l10n = context.l10n;
  if (section == ClaimsDeskSection.settled ||
      section == ClaimsDeskSection.insuranceSetup ||
      detail.isAuthorization) {
    return const <AppPermissionActionItem>[];
  }

  final String status = detail.item.status.toUpperCase();
  final List<AppPermissionActionItem> actions = <AppPermissionActionItem>[];

  if (status != 'PAID' && status != 'CANCELLED') {
    actions.add(
      AppPermissionActionItem(
        requirement: ClaimsActiveClaimsAtomPermissions.sync,
        label: l10n.claimsSyncClaimStatusAction,
        icon: Icons.sync_outlined,
        isLoading: state.isSaving,
        onPressed: () {
          unawaited(() async {
            final AppFailure? failure = await controller.syncClaimStatus();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
              if (failure == null) {
                _showSaved(context);
              }
            }
          }());
        },
      ),
    );
  }

  final ClaimInvoiceOption? invoice = detail.invoice;
  if (invoice != null && invoice.hasCollectibleBalance) {
    actions.add(
      AppPermissionActionItem(
        requirement: ClaimsActiveClaimsAtomPermissions.collectPatientShare,
        label: l10n.billingReceivePayment,
        icon: Icons.payments_outlined,
        onPressed: () {
          final Uri billingPayUri = Uri(
            path: AppRoutes.billing.path,
            queryParameters: <String, String>{
              'queue': 'awaiting-payment',
              'invoice': invoice.apiId,
              'action': 'pay',
            },
          );
          context.go(billingPayUri.toString());
        },
      ),
    );
  }

  return actions;
}

const String _claimsQueueFilterKey = 'queue';

AppSearchBarFilterValue _claimsFilterValue(ClaimsQueueQuery query) {
  if (query.filter == ClaimsQueueFilter.all) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    options: <String, String>{_claimsQueueFilterKey: query.filter.name},
  );
}

ClaimsQueueFilter _claimsFilterFromValue(String? value) {
  for (final ClaimsQueueFilter filter in ClaimsQueueFilter.values) {
    if (filter.name == value) {
      return filter;
    }
  }
  return ClaimsQueueFilter.all;
}

List<AppSearchBarFilterChoice> _claimsFilterChoicesForSection(
  AppLocalizations l10n,
  ClaimsDeskSection section,
) {
  final List<ClaimsQueueFilter> filters = switch (section) {
    ClaimsDeskSection.authorizations => <ClaimsQueueFilter>[
      ClaimsQueueFilter.authorizationPending,
      ClaimsQueueFilter.authorizationApproved,
      ClaimsQueueFilter.authorizationDenied,
      ClaimsQueueFilter.authorizationExpired,
    ],
    ClaimsDeskSection.activeClaims => <ClaimsQueueFilter>[
      ClaimsQueueFilter.claimSubmitted,
      ClaimsQueueFilter.claimApproved,
      ClaimsQueueFilter.claimPartial,
      ClaimsQueueFilter.claimRejected,
    ],
    ClaimsDeskSection.settled => <ClaimsQueueFilter>[
      ClaimsQueueFilter.claimPaid,
      ClaimsQueueFilter.claimCancelled,
    ],
    ClaimsDeskSection.insuranceSetup => <ClaimsQueueFilter>[],
  };
  return <AppSearchBarFilterChoice>[
    for (final ClaimsQueueFilter filter in filters)
      AppSearchBarFilterChoice(
        value: filter.name,
        label: _claimsFilterLabel(l10n, filter),
        icon: Icons.filter_list,
      ),
  ];
}

int _claimsCountForFilter(
  ClaimsWorkspaceState state,
  ClaimsQueueFilter filter,
) {
  final String? authorizationStatus = preAuthorizationStatusForFilter(filter);
  final String? claimStatus = insuranceClaimStatusForFilter(filter);
  return state.queue.items.where((ClaimsQueueItem item) {
    final String status = item.status.toUpperCase();
    if (item.isAuthorization && authorizationStatus != null) {
      return status == authorizationStatus;
    }
    if (item.isClaim && claimStatus != null) {
      return status == claimStatus;
    }
    return filter == ClaimsQueueFilter.all;
  }).length;
}

String _claimsFilterLabel(AppLocalizations l10n, ClaimsQueueFilter filter) {
  return switch (filter) {
    ClaimsQueueFilter.all => l10n.claimsFilterAll,
    ClaimsQueueFilter.authorizationPending =>
      l10n.claimsFilterAuthorizationPending,
    ClaimsQueueFilter.authorizationApproved =>
      l10n.claimsFilterAuthorizationApproved,
    ClaimsQueueFilter.authorizationDenied =>
      l10n.claimsFilterAuthorizationDenied,
    ClaimsQueueFilter.authorizationExpired =>
      l10n.claimsFilterAuthorizationExpired,
    ClaimsQueueFilter.claimSubmitted => l10n.claimsFilterClaimSubmitted,
    ClaimsQueueFilter.claimApproved => l10n.claimsFilterClaimApproved,
    ClaimsQueueFilter.claimPartial => l10n.claimsFilterClaimPartial,
    ClaimsQueueFilter.claimRejected => l10n.claimsFilterClaimRejected,
    ClaimsQueueFilter.claimPaid => l10n.claimsFilterClaimPaid,
    ClaimsQueueFilter.claimCancelled => l10n.claimsFilterClaimCancelled,
  };
}

List<AppSelectOption<String>> _authorizationStatusOptions(
  AppLocalizations l10n,
) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(value: 'PENDING', label: l10n.claimsStatusPending),
    AppSelectOption<String>(
      value: 'APPROVED',
      label: l10n.claimsStatusApproved,
    ),
    AppSelectOption<String>(value: 'PARTIAL', label: l10n.claimsStatusPartial),
    AppSelectOption<String>(value: 'DENIED', label: l10n.claimsStatusDenied),
    AppSelectOption<String>(value: 'EXPIRED', label: l10n.claimsStatusExpired),
  ];
}

List<AppSelectOption<String>> _claimResponseOptions(
  AppLocalizations l10n, {
  bool allowSettlingStatuses = false,
}) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'APPROVED',
      label: l10n.claimsStatusApproved,
    ),
    AppSelectOption<String>(
      value: 'REJECTED',
      label: l10n.claimsStatusRejected,
    ),
    if (allowSettlingStatuses) ...<AppSelectOption<String>>[
      AppSelectOption<String>(
        value: 'PARTIAL',
        label: l10n.claimsStatusPartial,
      ),
      AppSelectOption<String>(value: 'PAID', label: l10n.claimsStatusPaid),
    ],
  ];
}

List<AppSelectOption<String>> _coveragePlanOptions(
  List<CoveragePlanOption> plans,
) {
  return <AppSelectOption<String>>[
    for (final CoveragePlanOption plan in plans)
      AppSelectOption<String>(
        value: plan.apiId,
        label: _joinLabel(<String?>[plan.title, plan.subtitle]),
      ),
  ];
}

List<AppSelectOption<String>> _invoiceOptions(
  BuildContext context,
  List<ClaimInvoiceOption> invoices,
) {
  return <AppSelectOption<String>>[
    for (final ClaimInvoiceOption invoice in invoices)
      AppSelectOption<String>(
        value: invoice.apiId,
        label: _joinLabel(<String?>[
          invoice.title,
          invoice.patientDisplayId,
          _amountLabel(context, invoice),
        ]),
      ),
  ];
}

AppWorkspaceStatus _statusFor(BuildContext context, ClaimsQueueItem item) {
  return AppWorkspaceStatus(
    label: _statusLabel(context, item),
    tone: _statusTone(item),
    icon: _statusIcon(item),
  );
}

String _statusLabel(BuildContext context, ClaimsQueueItem item) {
  final AppLocalizations l10n = context.l10n;
  return switch (item.status.toUpperCase()) {
    'PENDING' => l10n.claimsStatusPending,
    'APPROVED' => l10n.claimsStatusApproved,
    'DENIED' => l10n.claimsStatusDenied,
    'EXPIRED' => l10n.claimsStatusExpired,
    'SUBMITTED' => l10n.claimsStatusSubmitted,
    'PARTIAL' => l10n.claimsStatusPartial,
    'REJECTED' => l10n.claimsStatusRejected,
    'PAID' => l10n.claimsStatusPaid,
    'CANCELLED' => l10n.claimsStatusCancelled,
    _ => _apiLabel(item.status),
  };
}

AppWorkspaceStatusTone _statusTone(ClaimsQueueItem item) {
  return switch (item.status.toUpperCase()) {
    'APPROVED' || 'PAID' => AppWorkspaceStatusTone.success,
    'PENDING' || 'SUBMITTED' => AppWorkspaceStatusTone.info,
    'PARTIAL' => AppWorkspaceStatusTone.warning,
    'DENIED' || 'REJECTED' || 'EXPIRED' => AppWorkspaceStatusTone.error,
    'CANCELLED' => AppWorkspaceStatusTone.neutral,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

IconData _statusIcon(ClaimsQueueItem item) {
  return switch (item.status.toUpperCase()) {
    'APPROVED' || 'PAID' => Icons.check_circle_outline,
    'PENDING' || 'SUBMITTED' => Icons.schedule_outlined,
    'PARTIAL' => Icons.pie_chart_outline,
    'DENIED' || 'REJECTED' => Icons.report_gmailerrorred_outlined,
    'EXPIRED' || 'CANCELLED' => Icons.block_outlined,
    _ => Icons.info_outline,
  };
}

String _kindLabel(BuildContext context, ClaimsQueueKind kind) {
  final AppLocalizations l10n = context.l10n;
  return switch (kind) {
    ClaimsQueueKind.authorization => l10n.claimsAuthorizationTypeLabel,
    ClaimsQueueKind.claim => l10n.claimsClaimTypeLabel,
  };
}

IconData _kindIcon(ClaimsQueueKind kind) {
  return switch (kind) {
    ClaimsQueueKind.authorization => Icons.verified_user_outlined,
    ClaimsQueueKind.claim => Icons.receipt_long_outlined,
  };
}

String _detailTitle(BuildContext context, ClaimsQueueDetail detail) {
  if (detail.isAuthorization) {
    return detail.coveragePlan?.title ?? context.l10n.claimsAuthorizationTitle;
  }
  return detail.claim?.patientDisplayId ?? context.l10n.claimsClaimPatientTitle;
}

String _detailNumber(BuildContext context, ClaimsQueueDetail detail) {
  return detail.isClaim
      ? _fallback(context, detail.claim?.patientDisplayId)
      : detail.item.displayId;
}

String _detailSubtitle(BuildContext context, ClaimsQueueDetail detail) {
  return detail.isAuthorization
      ? context.l10n.claimsAuthorizationSubtitle
      : context.l10n.claimsClaimSubtitle(detail.item.displayId);
}

String _coverageLabel(BuildContext context, ClaimsQueueDetail detail) {
  final CoveragePlanOption? plan = detail.coveragePlan;
  if (plan == null) {
    return _fallback(context, detail.item.coveragePlanDisplayId);
  }
  return _joinLabel(<String?>[plan.title, plan.subtitle]);
}

String _amountLabel(BuildContext context, ClaimInvoiceOption? invoice) {
  final num? amount = invoice?.totalAmount;
  if (amount == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.currency(
    amount,
    Localizations.localeOf(context),
    currencyCode: invoice?.currency,
  );
}

String _claimAmountLabel(BuildContext context, ClaimsQueueDetail detail) {
  final num? amount = detail.claim?.claimAmount;
  if (amount == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.currency(
    amount,
    Localizations.localeOf(context),
    currencyCode: detail.invoice?.currency,
  );
}

String _invoiceStatusLabel(BuildContext context, ClaimInvoiceOption? invoice) {
  final String? status = invoice?.billingStatus ?? invoice?.status;
  if (status == null || status.trim().isEmpty) {
    return context.l10n.profileUnknownValue;
  }
  return _apiLabel(status);
}

String _patientBalanceLabel(BuildContext context, ClaimsQueueDetail detail) {
  final ClaimInvoiceOption? invoice = detail.invoice;
  // Prefer Billing ledger balance_due (posted remittances / payments). Do not
  // invent patient responsibility from coverage % — that diverges after settle.
  final num? balanceDue = invoice?.balanceDue;
  if (balanceDue == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.currency(
    balanceDue,
    Localizations.localeOf(context),
    currencyCode: invoice?.currency,
  );
}

String _preAuthMoneyLabel(BuildContext context, num? amount) {
  if (amount == null) {
    return context.l10n.billingNotRecorded;
  }
  return AppFormatters.currency(amount, Localizations.localeOf(context));
}

String _claimBillingImpact(BuildContext context, ClaimsQueueDetail detail) {
  final AppLocalizations l10n = context.l10n;
  final String status = detail.item.status.toUpperCase();
  if (detail.invoiceUnavailable) {
    return l10n.claimsBillingInvoiceUnavailableBody;
  }
  return switch (status) {
    'APPROVED' => l10n.claimsBillingAuthorizedBody,
    'PARTIAL' => l10n.claimsBillingNeutralBody,
    'PAID' => l10n.claimsBillingPaidBody,
    'REJECTED' => l10n.claimsBillingRejectedBody,
    'SUBMITTED' => l10n.claimsBillingPendingBody,
    _ => l10n.claimsBillingNeutralBody,
  };
}

bool _hasPayerResponse(ClaimsQueueDetail detail) {
  return switch (detail.item.status.toUpperCase()) {
    'APPROVED' || 'PARTIAL' || 'DENIED' || 'REJECTED' || 'PAID' => true,
    _ => false,
  };
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

String _fallback(BuildContext context, String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? context.l10n.profileUnknownValue : normalized;
}

String _joinLabel(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String _apiLabel(String value) {
  final String normalized = value.trim().replaceAll(RegExp(r'[_-]+'), ' ');
  if (normalized.isEmpty) {
    return value;
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map((String word) {
        if (word.isEmpty) {
          return word;
        }
        return '${word.substring(0, 1).toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.claimsSavedMessage)));
}

String _claimsStatementHtml(BuildContext context, ClaimsQueueDetail detail) {
  final AppLocalizations l10n = context.l10n;
  final String factsHtml =
      PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
        PrintFormMetadataItem(
          label: l10n.claimsReferenceColumnLabel,
          value: detail.item.displayId,
        ),
        PrintFormMetadataItem(
          label: l10n.claimsStatusColumnLabel,
          value: _statusLabel(context, detail.item),
        ),
        PrintFormMetadataItem(
          label: l10n.claimsCoverageFieldLabel,
          value: _coverageLabel(context, detail),
        ),
        PrintFormMetadataItem(
          label: l10n.claimsInvoiceFieldLabel,
          value: _fallback(context, detail.claim?.invoiceDisplayId),
        ),
        PrintFormMetadataItem(
          label: l10n.claimsAmountFieldLabel,
          value: _amountLabel(context, detail.invoice),
        ),
      ]);
  final String impact = detail.isClaim
      ? _claimBillingImpact(context, detail)
      : l10n.claimsAuthorizationBillingImpactBody;
  final String impactHtml = PrintFormTemplate.section(
    title: l10n.claimsBillingImpactTitle,
    bodyHtml: '<p>${_htmlEscape(impact)}</p>',
  );

  return '$factsHtml$impactHtml';
}

String _htmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
