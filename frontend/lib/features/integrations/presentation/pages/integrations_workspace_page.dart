import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';
import 'package:hosspi_hms/features/integrations/presentation/controllers/integrations_workspace_controller.dart';
import 'package:hosspi_hms/features/integrations/presentation/integrations_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class IntegrationsWorkspacePage extends ConsumerWidget {
  const IntegrationsWorkspacePage({this.initialQuery, super.key});

  final IntegrationWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<IntegrationWorkspaceState>> value = ref.watch(
      integrationsWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return AsyncStateScaffold<IntegrationWorkspaceState>(
      value: value,
      loadingTitle: l10n.integrationsLoadingTitle,
      loadingBody: l10n.integrationsLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.invalidate(integrationsWorkspaceControllerProvider);
      },
      dataBuilder: (BuildContext context, IntegrationWorkspaceState state) {
        return _IntegrationsWorkspaceContent(
          state: state,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _IntegrationsWorkspaceContent extends ConsumerStatefulWidget {
  const _IntegrationsWorkspaceContent({required this.state, this.initialQuery});

  final IntegrationWorkspaceState state;
  final IntegrationWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_IntegrationsWorkspaceContent> createState() {
    return _IntegrationsWorkspaceContentState();
  }
}

class _IntegrationsWorkspaceContentState
    extends ConsumerState<_IntegrationsWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<IntegrationWorkItem>
  _tableColumnController;
  late IntegrationDeskSection _section;
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<IntegrationWorkItem>();
    _section = _sectionFromFilter(widget.state.query.filter);
    _scheduleRouteQuery(widget.initialQuery);
    if ((widget.initialQuery == null ||
            !widget.initialQuery!.hasRouteTargeting) &&
        widget.state.query.filter == IntegrationWorkspaceFilter.all) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          ref
              .read(integrationsWorkspaceControllerProvider.notifier)
              .applyFilter(_filterForSection(_section)),
        );
      });
    }
  }

  @override
  void didUpdateWidget(covariant _IntegrationsWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.value = TextEditingValue(text: search);
    }
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  void _scheduleRouteQuery(IntegrationWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_applyDeepLink(query));
    });
  }

  Future<void> _applyDeepLink(IntegrationWorkspaceQuery query) async {
    if (_appliedRouteSignature == query.signature) {
      return;
    }
    _appliedRouteSignature = query.signature;

    final IntegrationDeskSection section = _sectionFromFilter(query.filter);
    setState(() => _section = section);

    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
    }

    final IntegrationWorkspaceFilter filter = _filterForSection(_section);
    await ref
        .read(integrationsWorkspaceControllerProvider.notifier)
        .applyFilter(filter);
  }

  void _updateUrlForSection(IntegrationDeskSection section) {
    if (!mounted) {
      return;
    }
    final String sectionValue = _sectionToQueryValue(section);
    final String location = AppRoutes.integrations.location(
      queryParameters: <String, String>{
        if (sectionValue.isNotEmpty) 'section': sectionValue,
      },
    );
    GoRouter.of(context).replace<void>(location);
  }

  static IntegrationDeskSection _sectionFromFilter(
    IntegrationWorkspaceFilter filter,
  ) {
    return switch (filter) {
      IntegrationWorkspaceFilter.integrations =>
        IntegrationDeskSection.integrations,
      IntegrationWorkspaceFilter.apiKeys => IntegrationDeskSection.apiKeys,
      IntegrationWorkspaceFilter.webhooks => IntegrationDeskSection.webhooks,
      IntegrationWorkspaceFilter.logs => IntegrationDeskSection.logs,
      IntegrationWorkspaceFilter.interop => IntegrationDeskSection.interop,
      _ => IntegrationDeskSection.integrations,
    };
  }

  static IntegrationWorkspaceFilter _filterForSection(
    IntegrationDeskSection section,
  ) {
    return switch (section) {
      IntegrationDeskSection.integrations =>
        IntegrationWorkspaceFilter.integrations,
      IntegrationDeskSection.apiKeys => IntegrationWorkspaceFilter.apiKeys,
      IntegrationDeskSection.webhooks => IntegrationWorkspaceFilter.webhooks,
      IntegrationDeskSection.logs => IntegrationWorkspaceFilter.logs,
      IntegrationDeskSection.interop => IntegrationWorkspaceFilter.interop,
    };
  }

  static String _sectionToQueryValue(IntegrationDeskSection section) {
    return switch (section) {
      IntegrationDeskSection.integrations => 'integrations',
      IntegrationDeskSection.apiKeys => 'api-keys',
      IntegrationDeskSection.webhooks => 'webhooks',
      IntegrationDeskSection.logs => 'logs',
      IntegrationDeskSection.interop => 'interop',
    };
  }

  static IconData _sectionIcon(IntegrationDeskSection section) {
    return switch (section) {
      IntegrationDeskSection.integrations => Icons.hub_outlined,
      IntegrationDeskSection.apiKeys => Icons.key_outlined,
      IntegrationDeskSection.webhooks => Icons.webhook_outlined,
      IntegrationDeskSection.logs => Icons.history_outlined,
      IntegrationDeskSection.interop => Icons.compare_arrows_outlined,
    };
  }

  String _sectionLabel(AppLocalizations l10n, IntegrationDeskSection section) {
    return switch (section) {
      IntegrationDeskSection.integrations =>
        l10n.integrationsFilterIntegrations,
      IntegrationDeskSection.apiKeys => l10n.integrationsFilterApiKeys,
      IntegrationDeskSection.webhooks => l10n.integrationsFilterWebhooks,
      IntegrationDeskSection.logs => l10n.integrationsFilterLogs,
      IntegrationDeskSection.interop => l10n.integrationsFilterInterop,
    };
  }

  int _sectionCount(
    IntegrationWorkspaceState state,
    IntegrationDeskSection section,
  ) {
    return switch (section) {
      IntegrationDeskSection.integrations => state.integrations.length,
      IntegrationDeskSection.apiKeys => state.apiKeys.length,
      IntegrationDeskSection.webhooks => state.webhooks.length,
      IntegrationDeskSection.logs => state.logs.length,
      IntegrationDeskSection.interop => state.interopStatuses.length,
    };
  }

  Widget? _buildSectionPrimaryAction(
    AppLocalizations l10n,
    IntegrationWorkspaceState state,
    AppAccessPolicy policy,
  ) {
    final IntegrationsWorkspaceController controller = ref.read(
      integrationsWorkspaceControllerProvider.notifier,
    );
    return switch (_section) {
      IntegrationDeskSection.integrations =>
        canManageIntegrations(policy)
            ? AppTabToolbarPrimary(
                label: l10n.integrationsCreateIntegrationAction,
                icon: Icons.add_link_outlined,
                isLoading: state.isSaving,
                onPressed: () => unawaited(
                  _openIntegrationDialog(context, controller, state),
                ),
              )
            : null,
      IntegrationDeskSection.apiKeys =>
        canManageIntegrations(policy)
            ? AppTabToolbarPrimary(
                label: l10n.integrationsCreateApiKeyAction,
                icon: Icons.key_outlined,
                isLoading: state.isSaving,
                onPressed: () =>
                    unawaited(_openApiKeyDialog(context, controller)),
              )
            : null,
      IntegrationDeskSection.webhooks =>
        IntegrationsWebhooksAtomPermissions.create.isAllowed(policy)
            ? AppTabToolbarPrimary(
                label: l10n.integrationsCreateWebhookAction,
                icon: Icons.webhook_outlined,
                isLoading: state.isSaving,
                onPressed: () =>
                    unawaited(_openWebhookDialog(context, controller, state)),
              )
            : null,
      IntegrationDeskSection.logs || IntegrationDeskSection.interop => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final IntegrationWorkspaceState state = widget.state;
    final IntegrationsWorkspaceController controller = ref.read(
      integrationsWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canManage = canManageIntegrations(accessPolicy);
    final List<IntegrationDeskSection> visibleSections =
        integrationsAllowedSections(accessPolicy);
    if (visibleSections.isEmpty) {
      // No authorized sections — omit chrome (no routine "no access" banner).
      return const SizedBox.shrink();
    }
    final bool canShowCurrentSection = visibleSections.contains(_section);
    if (!canShowCurrentSection) {
      final IntegrationDeskSection? fallback = integrationsFallbackSection(
        accessPolicy,
      );
      if (fallback != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              integrationsAllowedSections(
                ref.read(appAccessPolicyProvider),
              ).contains(_section)) {
            return;
          }
          setState(() => _section = fallback);
          _updateUrlForSection(fallback);
          unawaited(controller.applyFilter(_filterForSection(fallback)));
        });
      }
    }

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final IntegrationDeskSection section in visibleSections)
                  AppTabItem(
                    id: section.name,
                    icon: _sectionIcon(section),
                    label: _sectionLabel(l10n, section),
                    count: _sectionCount(state, section),
                  ),
              ],
              selectedId: canShowCurrentSection
                  ? _section.name
                  : visibleSections.first.name,
              onTabTapped: (String tabId) {
                for (final IntegrationDeskSection section in visibleSections) {
                  if (section.name == tabId) {
                    setState(() => _section = section);
                    _updateUrlForSection(section);
                    unawaited(
                      controller.applyFilter(_filterForSection(section)),
                    );
                    break;
                  }
                }
              },
              primaryAction: _buildSectionPrimaryAction(
                l10n,
                state,
                accessPolicy,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            if (canShowCurrentSection)
              _IntegrationWorklistPanel(
                state: state,
                section: _section,
                searchController: _searchController,
                columnVisibilityController: _tableColumnController,
                canManage: canManage,
                onItemSelected: (IntegrationWorkItem item) {
                  if (_section == IntegrationDeskSection.webhooks &&
                      !IntegrationsWebhooksAtomPermissions.rowSelect.isAllowed(
                        accessPolicy,
                      )) {
                    return;
                  }
                  unawaited(
                    _openIntegrationDetailDialog(context, item, canManage),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openIntegrationDetailDialog(
    BuildContext context,
    IntegrationWorkItem item,
    bool canManage,
  ) async {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (item.kind == IntegrationWorkItemKind.webhook &&
        !IntegrationsWebhooksAtomPermissions.detail.isAllowed(policy)) {
      return;
    }

    final IntegrationsWorkspaceController controller = ref.read(
      integrationsWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = await controller.selectItem(item);
    if (failure != null || !context.mounted) {
      if (context.mounted) {
        _showFailureIfNeeded(context, failure ?? const AppFailure.unexpected());
      }
      return;
    }

    final AppLocalizations l10n = context.l10n;
    final bool detailCanManage = item.kind == IntegrationWorkItemKind.webhook
        ? IntegrationsWebhooksAtomPermissions.update.isAllowed(policy)
        : canManage;
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AppDialog(
        title: Text(_detailTitle(context, item)),
        icon: Icon(_kindIcon(item.kind)),
        scrollable: true,
        maxWidth: 980,
        content: Consumer(
          builder: (BuildContext context, WidgetRef dialogRef, _) {
            final IntegrationWorkspaceState dialogState =
                _integrationStateFromAsync(
                  dialogRef.watch(integrationsWorkspaceControllerProvider),
                ) ??
                widget.state;
            return _IntegrationDetailPanel(
              state: dialogState,
              canManage: detailCanManage,
            );
          },
        ),
        actions: <Widget>[
          AppButton.secondary(
            label: l10n.commonCloseActionLabel,
            onPressed: () => Navigator.of(dialogContext).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _IntegrationWorklistPanel extends ConsumerWidget {
  const _IntegrationWorklistPanel({
    required this.state,
    required this.section,
    required this.searchController,
    required this.columnVisibilityController,
    required this.canManage,
    required this.onItemSelected,
  });

  final IntegrationWorkspaceState state;
  final IntegrationDeskSection section;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<IntegrationWorkItem>
  columnVisibilityController;
  final bool canManage;
  final ValueChanged<IntegrationWorkItem> onItemSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (section == IntegrationDeskSection.webhooks &&
        (!IntegrationsWebhooksAtomPermissions.listChrome.isAllowed(policy) ||
            !IntegrationsWebhooksAtomPermissions.search.isAllowed(policy))) {
      return const SizedBox.shrink();
    }
    final IntegrationsWorkspaceController controller = ref.read(
      integrationsWorkspaceControllerProvider.notifier,
    );

    return AppListTable<IntegrationWorkItem>(
      page: state.workItemsPage,
      isLoading: state.isRefreshing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'integrations_${section.name}',
      columnWidthStorageKey: 'integrations_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columns: _defaultColumnsForSection(
        context,
        ref,
        l10n,
        section,
        state,
        canManage,
      ),
      columnChoices: _allColumnsForSection(
        context,
        ref,
        l10n,
        section,
        state,
        canManage,
      ),
      search: AppListTableSearch<IntegrationWorkItem>(
        controller: searchController,
        semanticLabel: l10n.integrationsSearchLabel,
        hintText: l10n.integrationsSearchHint,
        matcher: (IntegrationWorkItem item, String query) =>
            integrationWorklistSearchMatcher(
              context,
              l10n,
              section,
              item,
              query,
            ),
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
        enableDateFilter: false,
        allFieldsLabel: l10n.integrationsFilterAll,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _integrationFilterKey,
            label: l10n.integrationsFilterGroupLabel,
            allLabel: l10n.integrationsFilterAll,
            choices: _statusFilterChoices(l10n),
          ),
        ],
        filterValue: _filterValue(state.query),
        hasActiveFilters: state.query.statusFilter != null,
        onFilterChanged: (AppSearchBarFilterValue value) async {
          final AppFailure? failure = await controller.applyStatusFilter(
            _statusFilterFromValue(value.option(_integrationFilterKey)),
          );
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
      ),
      previousPageLabel: l10n.integrationsPreviousPageLabel,
      nextPageLabel: l10n.integrationsNextPageLabel,
      pageLabelBuilder: (AppPage<IntegrationWorkItem> page) {
        return l10n.integrationsPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          page.totalItemCount ?? page.items.length,
        );
      },
      onPageChanged: (AppPageRequest request) {
        unawaited(controller.changePage(request));
      },
      onRowSelected: onItemSelected,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.integrationsEmptyTitle,
        body: l10n.integrationsEmptyBody,
        icon: Icons.hub_outlined,
      ),
      mobileItemBuilder: (BuildContext context, IntegrationWorkItem item) {
        final String subtitle = switch (section) {
          IntegrationDeskSection.integrations => _scopeLabel(
            context,
            item.integration?.integrationType ?? item.scope,
          ),
          IntegrationDeskSection.apiKeys =>
            item.apiKey?.maskedValue ??
                _fallback(context, item.apiKey?.userId),
          IntegrationDeskSection.webhooks =>
            _fallback(context, item.webhook?.targetHost),
          IntegrationDeskSection.logs =>
            _fallback(context, item.log?.message),
          IntegrationDeskSection.interop => _scopeLabel(context, item.scope),
        };
        return AppListTableMobileItem(
          title: item.title,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: _statusLabel(context, item),
              icon: _statusIcon(item),
            ),
            AppListTableMobileMeta(
              label: subtitle,
              icon: Icons.info_outline,
            ),
          ],
          showAvatar: false,
          trailing: _IntegrationNextActionButton(
            item: item,
            section: section,
            state: state,
            canManage: canManage,
          ),
        );
      },
    );
  }
}

List<AppListTableColumn<IntegrationWorkItem>> _defaultColumnsForSection(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  IntegrationDeskSection section,
  IntegrationWorkspaceState state,
  bool canManage,
) {
  return switch (section) {
    IntegrationDeskSection.integrations =>
      <AppListTableColumn<IntegrationWorkItem>>[
        _integrationsNameColumn(l10n),
        _integrationsTypeColumn(l10n),
        _integrationsLastUpdatedColumn(l10n),
        _integrationStatusColumn(l10n),
        _integrationNextActionColumn(context, ref, section, state, canManage),
      ],
    IntegrationDeskSection.apiKeys => <AppListTableColumn<IntegrationWorkItem>>[
      _apiKeysNameColumn(l10n),
      _apiKeysReferenceColumn(l10n),
      _apiKeysLastUsedColumn(l10n),
      _integrationStatusColumn(l10n),
      _integrationNextActionColumn(context, ref, section, state, canManage),
    ],
    IntegrationDeskSection.webhooks =>
      <AppListTableColumn<IntegrationWorkItem>>[
        _webhooksEventColumn(l10n),
        _webhooksIntegrationColumn(l10n),
        _webhooksTargetHostColumn(l10n),
        _integrationStatusColumn(l10n),
        _integrationNextActionColumn(context, ref, section, state, canManage),
      ],
    IntegrationDeskSection.logs => <AppListTableColumn<IntegrationWorkItem>>[
      _logsIntegrationColumn(l10n),
      _logsMessageColumn(l10n),
      _logsLoggedAtColumn(l10n),
      _integrationStatusColumn(l10n),
      _integrationNextActionColumn(context, ref, section, state, canManage),
    ],
    IntegrationDeskSection.interop => <AppListTableColumn<IntegrationWorkItem>>[
      _interopTitleColumn(l10n),
      _interopScopeColumn(l10n),
      _interopLastUpdatedColumn(l10n),
      _integrationStatusColumn(l10n),
      _integrationNextActionColumn(context, ref, section, state, canManage),
    ],
  };
}

List<AppListTableColumn<IntegrationWorkItem>> _allColumnsForSection(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  IntegrationDeskSection section,
  IntegrationWorkspaceState state,
  bool canManage,
) {
  return switch (section) {
    IntegrationDeskSection.integrations =>
      <AppListTableColumn<IntegrationWorkItem>>[
        _integrationsNameColumn(l10n),
        _integrationsTypeColumn(l10n),
        _integrationsLastUpdatedColumn(l10n),
        _integrationStatusColumn(l10n),
        _integrationNextActionColumn(context, ref, section, state, canManage),
        _integrationsOwnerColumn(l10n),
        _integrationsHasConfigColumn(l10n),
        _integrationsWebhookCountColumn(l10n),
        _integrationsLogCountColumn(l10n),
      ],
    IntegrationDeskSection.apiKeys => <AppListTableColumn<IntegrationWorkItem>>[
      _apiKeysNameColumn(l10n),
      _apiKeysReferenceColumn(l10n),
      _apiKeysLastUsedColumn(l10n),
      _integrationStatusColumn(l10n),
      _integrationNextActionColumn(context, ref, section, state, canManage),
      _apiKeysUserColumn(l10n),
      _apiKeysPermissionsColumn(l10n),
      _apiKeysExpiresAtColumn(l10n),
    ],
    IntegrationDeskSection.webhooks =>
      <AppListTableColumn<IntegrationWorkItem>>[
        _webhooksEventColumn(l10n),
        _webhooksIntegrationColumn(l10n),
        _webhooksTargetHostColumn(l10n),
        _integrationStatusColumn(l10n),
        _integrationNextActionColumn(context, ref, section, state, canManage),
        _webhooksIntegrationStatusColumn(l10n),
        _webhooksCreatedAtColumn(l10n),
      ],
    IntegrationDeskSection.logs => <AppListTableColumn<IntegrationWorkItem>>[
      _logsIntegrationColumn(l10n),
      _logsMessageColumn(l10n),
      _logsLoggedAtColumn(l10n),
      _integrationStatusColumn(l10n),
      _integrationNextActionColumn(context, ref, section, state, canManage),
      _logsIntegrationTypeColumn(l10n),
    ],
    IntegrationDeskSection.interop => <AppListTableColumn<IntegrationWorkItem>>[
      _interopTitleColumn(l10n),
      _interopScopeColumn(l10n),
      _interopLastUpdatedColumn(l10n),
      _integrationStatusColumn(l10n),
      _integrationNextActionColumn(context, ref, section, state, canManage),
      _interopUnavailableReasonColumn(l10n),
    ],
  };
}

AppListTableColumn<IntegrationWorkItem> _integrationStatusColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'status',
    label: l10n.integrationsStatusColumnLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.status, b.status),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        AppWorkspaceStatusBadge(status: _statusFor(context, item)),
  );
}

AppListTableColumn<IntegrationWorkItem> _integrationNextActionColumn(
  BuildContext context,
  WidgetRef ref,
  IntegrationDeskSection section,
  IntegrationWorkspaceState state,
  bool canManage,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'next_action',
    label: context.l10n.integrationsNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.nextAction, b.nextAction),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) {
      return _IntegrationNextActionButton(
        item: item,
        section: section,
        state: state,
        canManage: canManage,
      );
    },
  );
}

AppListTableColumn<IntegrationWorkItem> _integrationsNameColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'name',
    label: l10n.integrationsNameColumnLabel,
    alwaysVisible: true,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.title, b.title),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) {
      final String? displayId = item.displayId?.trim();
      if (displayId != null && displayId.isNotEmpty) {
        return AppListItemText(title: item.title, subtitle: displayId);
      }
      return Text(item.title);
    },
  );
}

AppListTableColumn<IntegrationWorkItem> _integrationsTypeColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'type',
    label: l10n.integrationsTypeColumnLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(
          a.integration?.integrationType,
          b.integration?.integrationType,
        ),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_scopeLabel(context, item.integration?.integrationType ?? '')),
  );
}

AppListTableColumn<IntegrationWorkItem> _integrationsLastUpdatedColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'last_updated',
    label: l10n.integrationsLastEventColumnLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareDateTime(a.lastEventAt, b.lastEventAt),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_dateTimeLabel(context, item.lastEventAt)),
  );
}

AppListTableColumn<IntegrationWorkItem> _integrationsOwnerColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'owner',
    label: l10n.integrationsOwnerColumnLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.owner, b.owner),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_fallback(context, item.integration?.tenantLabel)),
  );
}

AppListTableColumn<IntegrationWorkItem> _integrationsHasConfigColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'has_config',
    label: l10n.integrationsConfigurationTitle,
    cellBuilder: (BuildContext context, IntegrationWorkItem item) => Icon(
      item.integration?.hasConfig == true
          ? Icons.check_circle_outline
          : Icons.remove_circle_outline,
      size: 18,
      color: item.integration?.hasConfig == true
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.outline,
    ),
  );
}

AppListTableColumn<IntegrationWorkItem> _integrationsWebhookCountColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'webhook_count',
    label: l10n.integrationsRelatedWebhooksTitle,
    numeric: true,
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text('${item.integration?.webhookSubscriptionCount ?? 0}'),
  );
}

AppListTableColumn<IntegrationWorkItem> _integrationsLogCountColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'log_count',
    label: l10n.integrationsRelatedLogsTitle,
    numeric: true,
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text('${item.integration?.logCount ?? 0}'),
  );
}

AppListTableColumn<IntegrationWorkItem> _apiKeysNameColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'name',
    label: l10n.integrationsNameColumnLabel,
    alwaysVisible: true,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.title, b.title),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(item.title),
  );
}

AppListTableColumn<IntegrationWorkItem> _apiKeysReferenceColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'key_id',
    label: l10n.integrationsReferenceLabel,
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(item.apiKey?.maskedValue ?? ''),
  );
}

AppListTableColumn<IntegrationWorkItem> _apiKeysLastUsedColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'last_used',
    label: l10n.integrationsLastEventColumnLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareDateTime(a.apiKey?.lastUsedAt, b.apiKey?.lastUsedAt),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_dateTimeLabel(context, item.apiKey?.lastUsedAt)),
  );
}

AppListTableColumn<IntegrationWorkItem> _apiKeysUserColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'user',
    label: l10n.integrationsOwnerColumnLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.owner, b.owner),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_fallback(context, item.apiKey?.userId)),
  );
}

AppListTableColumn<IntegrationWorkItem> _apiKeysPermissionsColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'permissions',
    label: l10n.integrationsPermissionsTitle,
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_scopeLabel(context, item.scope)),
  );
}

AppListTableColumn<IntegrationWorkItem> _apiKeysExpiresAtColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'expires_at',
    label: l10n.integrationsExpiresAtFieldLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareDateTime(a.apiKey?.expiresAt, b.apiKey?.expiresAt),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_dateTimeLabel(context, item.apiKey?.expiresAt)),
  );
}

AppListTableColumn<IntegrationWorkItem> _webhooksEventColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'event',
    label: l10n.integrationsEventLabel,
    alwaysVisible: true,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.webhook?.event, b.webhook?.event),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_fallback(context, item.webhook?.event)),
  );
}

AppListTableColumn<IntegrationWorkItem> _webhooksIntegrationColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'integration',
    label: l10n.integrationsIntegrationLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(
          a.webhook?.integrationLabel,
          b.webhook?.integrationLabel,
        ),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_fallback(context, item.webhook?.integrationLabel)),
  );
}

AppListTableColumn<IntegrationWorkItem> _webhooksTargetHostColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'target_host',
    label: l10n.integrationsTargetHostLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.webhook?.targetHost, b.webhook?.targetHost),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_fallback(context, item.webhook?.targetHost)),
  );
}

AppListTableColumn<IntegrationWorkItem> _webhooksIntegrationStatusColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'integration_status',
    label:
        '${l10n.integrationsIntegrationLabel} ${l10n.integrationsStatusColumnLabel}',
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(
          a.webhook?.integrationStatus,
          b.webhook?.integrationStatus,
        ),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_fallback(context, item.webhook?.integrationStatus)),
  );
}

AppListTableColumn<IntegrationWorkItem> _webhooksCreatedAtColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'created_at',
    label: l10n.integrationsLastEventColumnLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareDateTime(a.webhook?.createdAt, b.webhook?.createdAt),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_dateTimeLabel(context, item.webhook?.createdAt)),
  );
}

AppListTableColumn<IntegrationWorkItem> _logsIntegrationColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'integration',
    label: l10n.integrationsIntegrationLabel,
    alwaysVisible: true,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.title, b.title),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(item.title),
  );
}

AppListTableColumn<IntegrationWorkItem> _logsMessageColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'message',
    label: l10n.integrationsSanitizedLogTitle,
    cellBuilder: (BuildContext context, IntegrationWorkItem item) => Text(
      _fallback(context, item.log?.message),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

AppListTableColumn<IntegrationWorkItem> _logsLoggedAtColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'logged_at',
    label: l10n.integrationsLastEventColumnLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareDateTime(a.log?.loggedAt, b.log?.loggedAt),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_dateTimeLabel(context, item.log?.loggedAt)),
  );
}

AppListTableColumn<IntegrationWorkItem> _logsIntegrationTypeColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'integration_type',
    label: l10n.integrationsTypeColumnLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.log?.integrationType, b.log?.integrationType),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_scopeLabel(context, item.log?.integrationType ?? '')),
  );
}

AppListTableColumn<IntegrationWorkItem> _interopTitleColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'title',
    label: l10n.integrationsNameColumnLabel,
    alwaysVisible: true,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.title, b.title),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) => Text(
      item.interop != null
          ? _interopTitle(context.l10n, item.interop!.title)
          : item.title,
    ),
  );
}

AppListTableColumn<IntegrationWorkItem> _interopScopeColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'scope',
    label: l10n.integrationsScopeColumnLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareText(a.scope, b.scope),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_scopeLabel(context, item.scope)),
  );
}

AppListTableColumn<IntegrationWorkItem> _interopLastUpdatedColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'last_updated',
    label: l10n.integrationsLastEventColumnLabel,
    sortComparator: (IntegrationWorkItem a, IntegrationWorkItem b) =>
        appListTableCompareDateTime(a.interop?.updatedAt, b.interop?.updatedAt),
    cellBuilder: (BuildContext context, IntegrationWorkItem item) =>
        Text(_dateTimeLabel(context, item.interop?.updatedAt)),
  );
}

AppListTableColumn<IntegrationWorkItem> _interopUnavailableReasonColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IntegrationWorkItem>(
    id: 'unavailable_reason',
    label: l10n.integrationsInteropReadinessTitle,
    cellBuilder: (BuildContext context, IntegrationWorkItem item) {
      final String? reason = item.interop?.unavailableReason;
      if (reason == null) {
        return Text(context.l10n.integrationsInteropReadyBody);
      }
      return Text(_interopUnavailableReason(context.l10n, reason));
    },
  );
}

bool integrationWorklistSearchMatcher(
  BuildContext context,
  AppLocalizations l10n,
  IntegrationDeskSection section,
  IntegrationWorkItem item,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  final List<String> haystack = <String>[
    item.title,
    item.status,
    item.scope,
    item.nextAction,
    item.kind.name,
    _statusLabelForValue(context, item.status),
    _scopeLabel(context, item.scope),
    _nextActionLabel(context, item.nextAction),
    _kindLabel(l10n, item.kind),
    ?item.displayId,
    ?item.owner,
    ?item.errorSummary,
  ];

  switch (section) {
    case IntegrationDeskSection.integrations:
      haystack.addAll(<String>[
        ?item.integration?.integrationType,
        ?item.integration?.tenantLabel,
        ?item.integration?.tenantId,
        ?item.integration?.name,
        _scopeLabel(context, item.integration?.integrationType ?? ''),
        '${item.integration?.webhookSubscriptionCount ?? 0}',
        '${item.integration?.logCount ?? 0}',
        '${item.integration?.hasConfig ?? false}',
      ]);
      if (item.lastEventAt != null) {
        haystack.add(_dateTimeLabel(context, item.lastEventAt));
      }
    case IntegrationDeskSection.apiKeys:
      haystack.addAll(<String>[
        ?item.apiKey?.maskedValue,
        ?item.apiKey?.userId,
        ?item.apiKey?.name,
        ?item.apiKey?.displayId,
        ?item.apiKey?.humanFriendlyId,
      ]);
      if (item.apiKey?.expiresAt != null) {
        haystack.add(_dateTimeLabel(context, item.apiKey?.expiresAt));
      }
      if (item.apiKey?.lastUsedAt != null) {
        haystack.add(_dateTimeLabel(context, item.apiKey?.lastUsedAt));
      }
    case IntegrationDeskSection.webhooks:
      haystack.addAll(<String>[
        ?item.webhook?.event,
        ?item.webhook?.integrationLabel,
        ?item.webhook?.targetHost,
        ?item.webhook?.targetUrl,
        ?item.webhook?.integrationStatus,
        _statusLabelForValue(context, item.webhook?.integrationStatus),
      ]);
      if (item.webhook?.createdAt != null) {
        haystack.add(_dateTimeLabel(context, item.webhook?.createdAt));
      }
    case IntegrationDeskSection.logs:
      haystack.addAll(<String>[
        ?item.log?.message,
        ?item.log?.integrationType,
        ?item.log?.integrationLabel,
        _scopeLabel(context, item.log?.integrationType ?? ''),
      ]);
      if (item.log?.loggedAt != null) {
        haystack.add(_dateTimeLabel(context, item.log?.loggedAt));
      }
    case IntegrationDeskSection.interop:
      haystack.addAll(<String>[
        item.interop != null
            ? _interopTitle(l10n, item.interop!.title)
            : item.title,
        ?item.interop?.title,
        ?item.interop?.unavailableReason,
        item.interop?.unavailableReason == null
            ? l10n.integrationsInteropReadyBody
            : _interopUnavailableReason(l10n, item.interop!.unavailableReason!),
      ]);
      if (item.interop?.updatedAt != null) {
        haystack.add(_dateTimeLabel(context, item.interop?.updatedAt));
      }
  }

  return haystack.any(
    (String value) =>
        value.trim().isNotEmpty && value.toLowerCase().contains(needle),
  );
}

class _IntegrationNextActionButton extends ConsumerWidget {
  const _IntegrationNextActionButton({
    required this.item,
    required this.section,
    required this.state,
    required this.canManage,
  });

  final IntegrationWorkItem item;
  final IntegrationDeskSection section;
  final IntegrationWorkspaceState state;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (section == IntegrationDeskSection.webhooks &&
        !IntegrationsWebhooksAtomPermissions.nextAction.isAllowed(policy)) {
      return const SizedBox.shrink();
    }

    final bool requiresWrite = switch (item.nextAction) {
      'enable' ||
      'enable_webhook' ||
      'review_failure' ||
      'monitor' ||
      'review_key' ||
      'replay_or_escalate' => true,
      _ => false,
    };

    final bool writeAllowed = section == IntegrationDeskSection.webhooks
        ? IntegrationsWebhooksAtomPermissions.update.isAllowed(policy)
        : canManage;

    // Write-gated next-actions omit when unauthorized; view-only remains.
    if (requiresWrite && !writeAllowed) {
      final AppLocalizations l10n = context.l10n;
      final String viewLabel = section == IntegrationDeskSection.webhooks
          ? l10n.integrationsNextActionMonitorDelivery
          : l10n.integrationsNextActionReview;
      return AppButton.tertiary(
        label: viewLabel,
        onPressed: () => unawaited(
          _handleIntegrationNextAction(
            context,
            ref,
            state,
            item,
            canManage,
            openDetailOnly: true,
          ),
        ),
      );
    }

    final String label = _nextActionLabel(context, item.nextAction);
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    if (!requiresWrite) {
      return AppButton.tertiary(
        label: label,
        onPressed: () => unawaited(
          _handleIntegrationNextAction(
            context,
            ref,
            state,
            item,
            canManage,
            openDetailOnly: true,
          ),
        ),
      );
    }

    return AppAccessActionGate(
      requirement: section == IntegrationDeskSection.webhooks
          ? IntegrationsWebhooksAtomPermissions.update
          : integrationsManageRequirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed) {
          return const SizedBox.shrink();
        }
        return AppButton.tertiary(
          label: label,
          onPressed: () => unawaited(
            _handleIntegrationNextAction(
              context,
              ref,
              state,
              item,
              canManage,
            ),
          ),
        );
      },
    );
  }
}

Future<void> _handleIntegrationNextAction(
  BuildContext context,
  WidgetRef ref,
  IntegrationWorkspaceState state,
  IntegrationWorkItem item,
  bool canManage, {
  bool openDetailOnly = false,
}) async {
  final IntegrationsWorkspaceController controller = ref.read(
    integrationsWorkspaceControllerProvider.notifier,
  );

  Future<void> openDetail() async {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (item.kind == IntegrationWorkItemKind.webhook &&
        !IntegrationsWebhooksAtomPermissions.detail.isAllowed(policy)) {
      return;
    }
    final bool detailCanManage = item.kind == IntegrationWorkItemKind.webhook
        ? IntegrationsWebhooksAtomPermissions.update.isAllowed(policy)
        : canManage;
    final AppFailure? failure = await controller.selectItem(item);
    if (!context.mounted) {
      return;
    }
    if (failure != null) {
      _showFailureIfNeeded(context, failure);
      return;
    }
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AppDialog(
        title: Text(_detailTitle(context, item)),
        icon: Icon(_kindIcon(item.kind)),
        scrollable: true,
        maxWidth: 980,
        content: Consumer(
          builder: (BuildContext context, WidgetRef dialogRef, _) {
            final IntegrationWorkspaceState dialogState =
                _integrationStateFromAsync(
                  dialogRef.watch(integrationsWorkspaceControllerProvider),
                ) ??
                state;
            return _IntegrationDetailPanel(
              state: dialogState,
              canManage: detailCanManage,
            );
          },
        ),
        actions: <Widget>[
          AppButton.secondary(
            label: context.l10n.commonCloseActionLabel,
            onPressed: () => Navigator.of(dialogContext).maybePop(),
          ),
        ],
      ),
    );
  }

  if (openDetailOnly) {
    await openDetail();
    return;
  }

  switch (item.nextAction) {
    case 'review_failure':
      await _confirmTestConnection(context, controller, item);
    case 'enable':
      await _toggleIntegration(context, controller, item);
    case 'monitor':
      await _confirmSyncNow(context, controller, item);
    case 'review_key':
      await _openPermissionDialog(
        context,
        controller,
        state,
        apiKey: item.apiKey,
      );
    case 'rotate_or_monitor':
    case 'review':
    case 'RUN_AVAILABLE_ACTION':
    case 'USE_INTEGRATION_STATUS_AND_LOGS':
    case 'monitor_delivery':
      await openDetail();
    case 'enable_webhook':
      await _toggleWebhook(context, controller, item);
    case 'replay_or_escalate':
      await _confirmReplayLog(context, controller, item);
    default:
      await openDetail();
  }
}


class _IntegrationDetailPanel extends ConsumerWidget {
  const _IntegrationDetailPanel({required this.state, required this.canManage});

  final IntegrationWorkspaceState state;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IntegrationWorkItem? item = state.selectedItem;
    final IntegrationsWorkspaceController controller = ref.read(
      integrationsWorkspaceControllerProvider.notifier,
    );

    if (item == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.integrationsNoSelectionTitle,
        description: l10n.integrationsNoSelectionBody,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.integrationsNoSelectionTitle,
          body: l10n.integrationsNoSelectionBody,
          icon: Icons.hub_outlined,
        ),
      );
    }

    final ThemeData theme = Theme.of(context);
    final List<Widget> detailActions = _detailActions(
      context,
      controller,
      state,
      item,
      canManage,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (detailActions.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: detailActions,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        _detailBody(context, state, item),
      ],
    );
  }
}

List<Widget> _detailActions(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkspaceState state,
  IntegrationWorkItem item,
  bool canManage,
) {
  if (!canManage) {
    return const <Widget>[];
  }

  final AppLocalizations l10n = context.l10n;
  final String nextAction = item.nextAction;
  return switch (item.kind) {
    IntegrationWorkItemKind.integration => <Widget>[
      AppButton.secondary(
        label: l10n.integrationsConfigureAction,
        leadingIcon: Icons.tune_outlined,
        isLoading: state.isSaving,
        onPressed: () {
          unawaited(
            _openIntegrationDialog(
              context,
              controller,
              state,
              integration: item.integration,
            ),
          );
        },
      ),
      if (nextAction != 'review_failure')
        AppButton.secondary(
          label: l10n.integrationsTestConnectionAction,
          leadingIcon: Icons.network_check_outlined,
          isLoading: state.isSaving,
          onPressed: () {
            unawaited(_confirmTestConnection(context, controller, item));
          },
        ),
      if (nextAction != 'monitor')
        AppButton.secondary(
          label: l10n.integrationsSyncNowAction,
          leadingIcon: Icons.sync,
          isLoading: state.isSaving,
          onPressed: () {
            unawaited(_confirmSyncNow(context, controller, item));
          },
        ),
      if (nextAction != 'enable')
        AppButton.tertiary(
          label: item.integration?.isActive == true
              ? l10n.integrationsDisableAction
              : l10n.integrationsEnableAction,
          leadingIcon: item.integration?.isActive == true
              ? Icons.pause_circle_outline
              : Icons.play_circle_outline,
          isLoading: state.isSaving,
          onPressed: () {
            unawaited(_toggleIntegration(context, controller, item));
          },
        ),
    ],
    IntegrationWorkItemKind.apiKey => <Widget>[
      if (nextAction != 'review_key')
        AppButton.secondary(
          label: l10n.integrationsManagePermissionsAction,
          leadingIcon: Icons.admin_panel_settings_outlined,
          isLoading: state.isSaving,
          onPressed: () {
            unawaited(
              _openPermissionDialog(
                context,
                controller,
                state,
                apiKey: item.apiKey,
              ),
            );
          },
        ),
      AppButton.secondary(
        label: item.apiKey?.isActive == true
            ? l10n.integrationsDisableAction
            : l10n.integrationsEnableAction,
        leadingIcon: item.apiKey?.isActive == true
            ? Icons.pause_circle_outline
            : Icons.play_circle_outline,
        isLoading: state.isSaving,
        onPressed: () {
          unawaited(_toggleApiKey(context, controller, item));
        },
      ),
      AppButton.tertiary(
        label: l10n.integrationsRevokeApiKeyAction,
        leadingIcon: Icons.block_outlined,
        isLoading: state.isSaving,
        onPressed: () {
          unawaited(_confirmRevokeApiKey(context, controller, item));
        },
      ),
    ],
    IntegrationWorkItemKind.webhook => <Widget>[
      AppButton.secondary(
        label: l10n.integrationsEditWebhookAction,
        leadingIcon: Icons.edit_outlined,
        isLoading: state.isSaving,
        onPressed: () {
          unawaited(
            _openWebhookDialog(
              context,
              controller,
              state,
              webhook: item.webhook,
            ),
          );
        },
      ),
      AppButton.secondary(
        label: l10n.integrationsReplayWebhookAction,
        leadingIcon: Icons.replay_outlined,
        isLoading: state.isSaving,
        onPressed: () {
          unawaited(_confirmReplayWebhook(context, controller, item));
        },
      ),
      if (nextAction != 'enable_webhook')
        AppButton.tertiary(
          label: item.webhook?.isActive == true
              ? l10n.integrationsDisableAction
              : l10n.integrationsEnableAction,
          leadingIcon: item.webhook?.isActive == true
              ? Icons.pause_circle_outline
              : Icons.play_circle_outline,
          isLoading: state.isSaving,
          onPressed: () {
            unawaited(_toggleWebhook(context, controller, item));
          },
        ),
    ],
    IntegrationWorkItemKind.log => <Widget>[
      if (nextAction != 'replay_or_escalate')
        AppButton.secondary(
          label: l10n.integrationsReplayLogAction,
          leadingIcon: Icons.replay_outlined,
          isLoading: state.isSaving,
          onPressed: () {
            unawaited(_confirmReplayLog(context, controller, item));
          },
        ),
    ],
    IntegrationWorkItemKind.interop => const <Widget>[],
  };
}

Widget _detailBody(
  BuildContext context,
  IntegrationWorkspaceState state,
  IntegrationWorkItem item,
) {
  final AppLocalizations l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final List<Widget> children = <Widget>[
    AppInfoTileGrid(
      emptyValue: l10n.profileUnknownValue,
      items: <AppInfoTileData>[
        AppInfoTileData(
          label: l10n.integrationsReferenceLabel,
          value: item.displayId ?? item.id,
          icon: Icons.tag_outlined,
          copyable: true,
        ),
        AppInfoTileData(
          label: l10n.integrationsStatusColumnLabel,
          value: _statusLabel(context, item),
          icon: Icons.info_outline,
        ),
        AppInfoTileData(
          label: l10n.integrationsScopeColumnLabel,
          value: _scopeLabel(context, item.scope),
          icon: Icons.security_outlined,
        ),
        AppInfoTileData(
          label: l10n.integrationsLastEventColumnLabel,
          value: _dateTimeLabel(context, item.lastEventAt),
          icon: Icons.schedule_outlined,
        ),
      ],
    ),
  ];

  final IntegrationActionResult? actionResult = state.lastActionResult;
  if (actionResult != null) {
    children.add(
      AppMessagePanel(
        title: l10n.integrationsActionResultTitle,
        message: _actionResultMessage(context, actionResult),
      ),
    );
  }

  switch (item.kind) {
    case IntegrationWorkItemKind.integration:
      final IntegrationRecord? integration = item.integration;
      if (integration != null) {
        children.addAll(<Widget>[
          _IntegrationConfigSummary(integration: integration),
          _RelatedWebhooksPanel(
            webhooks: state.webhooksForIntegration(integration),
          ),
          _RelatedLogsPanel(logs: state.logsForIntegration(integration)),
        ]);
      }
    case IntegrationWorkItemKind.apiKey:
      final ApiKeyRecord? key = item.apiKey;
      if (key != null) {
        children.addAll(<Widget>[
          AppMessagePanel(
            title: l10n.integrationsMaskedSecretTitle,
            message: key.maskedValue,
            icon: Icons.visibility_off_outlined,
            tone: AppWorkspaceStatusTone.neutral,
          ),
          AppMessagePanel(
            title: l10n.integrationsRotationGapTitle,
            message: l10n.integrationsRotationGapBody,
            icon: Icons.info_outline,
          ),
          _ApiKeyPermissionsPanel(apiKey: key, state: state),
        ]);
      }
    case IntegrationWorkItemKind.webhook:
      final WebhookSubscriptionRecord? webhook = item.webhook;
      if (webhook != null) {
        children.add(
          AppInfoTileGrid(
            emptyValue: l10n.profileUnknownValue,
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.integrationsEventLabel,
                value: webhook.event,
                icon: Icons.event_outlined,
              ),
              AppInfoTileData(
                label: l10n.integrationsTargetHostLabel,
                value: webhook.targetHost,
                icon: Icons.public_outlined,
              ),
              AppInfoTileData(
                label: l10n.integrationsIntegrationLabel,
                value: webhook.integrationLabel ?? webhook.integrationDisplayId,
                icon: Icons.hub_outlined,
                copyable: webhook.integrationDisplayId != null,
              ),
            ],
          ),
        );
      }
    case IntegrationWorkItemKind.log:
      final IntegrationLogRecord? log = item.log;
      children.add(
        AppMessagePanel(
          title: l10n.integrationsSanitizedLogTitle,
          message: _fallback(context, log?.message),
          icon: Icons.receipt_long_outlined,
          tone: log?.requiresAttention == true
              ? AppWorkspaceStatusTone.error
              : AppWorkspaceStatusTone.neutral,
        ),
      );
    case IntegrationWorkItemKind.interop:
      final InteropCapabilityStatus? status = item.interop;
      if (status != null) {
        children.add(
          AppMessagePanel(
            title: _interopTitle(l10n, status.title),
            message: status.unavailableReason == null
                ? l10n.integrationsInteropReadyBody
                : _interopUnavailableReason(l10n, status.unavailableReason!),
            icon: Icons.compare_arrows_outlined,
            tone: status.unavailableReason == null
                ? AppWorkspaceStatusTone.success
                : AppWorkspaceStatusTone.warning,
          ),
        );
      }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (var index = 0; index < children.length; index += 1) ...<Widget>[
        if (index > 0) SizedBox(height: theme.spacing.md),
        children[index],
      ],
    ],
  );
}

class _IntegrationConfigSummary extends StatelessWidget {
  const _IntegrationConfigSummary({required this.integration});

  final IntegrationRecord integration;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<String> entries = integration.configSummary.entries
        .map((MapEntry<String, Object?> entry) {
          return '${entry.key}: ${entry.value ?? l10n.profileUnknownValue}';
        })
        .toList(growable: false);

    return AppWorkspaceDetailPanel(
      title: l10n.integrationsConfigurationTitle,
      description: integration.hasConfig
          ? l10n.integrationsConfigurationMaskedBody
          : l10n.integrationsConfigurationEmptyBody,
      titleIcon: Icons.settings_applications_outlined,
      child: entries.isEmpty
          ? Text(l10n.integrationsNoConfigurationRows)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String entry in entries)
                  Text(entry, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
    );
  }
}

class _RelatedWebhooksPanel extends StatelessWidget {
  const _RelatedWebhooksPanel({required this.webhooks});

  final List<WebhookSubscriptionRecord> webhooks;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppWorkspaceDetailPanel(
      title: l10n.integrationsRelatedWebhooksTitle,
      titleIcon: Icons.webhook_outlined,
      child: webhooks.isEmpty
          ? Text(l10n.integrationsNoRelatedWebhooks)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final WebhookSubscriptionRecord webhook in webhooks.take(4))
                  _CompactFactRow(
                    label: _fallback(context, webhook.event),
                    value: _fallback(context, webhook.targetHost),
                  ),
              ],
            ),
    );
  }
}

class _RelatedLogsPanel extends StatelessWidget {
  const _RelatedLogsPanel({required this.logs});

  final List<IntegrationLogRecord> logs;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppWorkspaceDetailPanel(
      title: l10n.integrationsRelatedLogsTitle,
      titleIcon: Icons.receipt_long_outlined,
      child: logs.isEmpty
          ? Text(l10n.integrationsNoRelatedLogs)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final IntegrationLogRecord log in logs.take(4))
                  _CompactFactRow(
                    label: _statusLabelForValue(context, log.status),
                    value: _fallback(context, log.message),
                  ),
              ],
            ),
    );
  }
}

class _ApiKeyPermissionsPanel extends ConsumerWidget {
  const _ApiKeyPermissionsPanel({required this.apiKey, required this.state});

  final ApiKeyRecord apiKey;
  final IntegrationWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IntegrationsWorkspaceController controller = ref.read(
      integrationsWorkspaceControllerProvider.notifier,
    );
    final List<ApiKeyPermissionRecord> permissions = state.permissionsForKey(
      apiKey,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.integrationsPermissionsTitle,
      titleIcon: Icons.admin_panel_settings_outlined,
      child: permissions.isEmpty
          ? Text(l10n.integrationsNoPermissions)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final ApiKeyPermissionRecord permission in permissions)
                  _PermissionGrantRow(
                    label:
                        state.permissionOption(permission.permissionId)?.label ??
                        permission.permissionId,
                    onRemove: () async {
                      final bool confirmed = await _confirm(
                        context,
                        title: l10n.integrationsRemovePermissionDialogTitle,
                        message: l10n.integrationsRemovePermissionDialogBody,
                        confirmLabel: l10n.integrationsRemovePermissionAction,
                        icon: Icons.remove_circle_outline,
                      );
                      if (!context.mounted || !confirmed) {
                        return;
                      }
                      final AppFailure? failure = await controller
                          .removeApiKeyPermission(permission.id);
                      if (context.mounted) {
                        _showFailureIfNeeded(context, failure);
                        _showSavedIfNeeded(context, failure);
                      }
                    },
                  ),
              ],
            ),
    );
  }
}

class _PermissionGrantRow extends StatelessWidget {
  const _PermissionGrantRow({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        SizedBox(width: theme.spacing.xs),
        AppButton(
          iconOnly: true,
          leadingIcon: Icons.remove_circle_outline,
          label: l10n.integrationsRemovePermissionAction,

          semanticLabel: l10n.integrationsRemovePermissionAction,
          tooltip: l10n.integrationsRemovePermissionAction,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

class _CompactFactRow extends StatelessWidget {
  const _CompactFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _IntegrationConfigDialog extends StatefulWidget {
  const _IntegrationConfigDialog({
    required this.onSubmit,
    required this.tenantId,
    this.integration,
  });

  final IntegrationRecord? integration;
  final String? tenantId;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  State<_IntegrationConfigDialog> createState() {
    return _IntegrationConfigDialogState();
  }
}

class _IntegrationConfigDialogState extends State<_IntegrationConfigDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final TextEditingController _configController = TextEditingController();
  late String _type;
  late String _status;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final IntegrationRecord? integration = widget.integration;
    _nameController = TextEditingController(text: integration?.name ?? '');
    _type = integration?.integrationType ?? 'FHIR';
    _status = integration?.status ?? 'ACTIVE';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _configController.dispose();
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
          controller: _nameController,
          labelText: l10n.integrationsNameFieldLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.integrationsNameRequiredMessage,
          ),
        ),
        AppSelectField<String>(
          labelText: l10n.integrationsTypeFieldLabel,
          value: _type,
          isRequired: true,
          allowClear: false,
          options: _integrationTypeOptions(l10n),
          onChanged: (String? value) {
            setState(() {
              _type = value ?? _type;
            });
          },
        ),
        AppSelectField<String>(
          labelText: l10n.integrationsStatusColumnLabel,
          value: _status,
          isRequired: true,
          allowClear: false,
          options: _integrationStatusOptions(l10n),
          onChanged: (String? value) {
            setState(() {
              _status = value ?? _status;
            });
          },
        ),
        AppTextField(
          controller: _configController,
          labelText: l10n.integrationsConfigFieldLabel,
          helperText: widget.integration == null
              ? l10n.integrationsConfigCreateHelper
              : l10n.integrationsConfigUpdateHelper,
          maxLines: 4,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.integration == null
              ? l10n.integrationsCreateIntegrationSubmitAction
              : l10n.integrationsSaveIntegrationAction,
          submitIcon: Icons.check,
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

    final Map<String, Object?> config = _parseConfigLines(
      _configController.text,
    );
    final Map<String, Object?> payload = <String, Object?>{
      if (widget.integration == null) 'tenant_id': widget.tenantId,
      'name': _nameController.text.trim(),
      'integration_type': _type,
      'status': _status,
      if (config.isNotEmpty) 'config_json': config,
    };
    final AppFailure? failure = await widget.onSubmit(payload);
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

class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({required this.contextPayload, required this.onSubmit});

  final Map<String, Object?> contextPayload;
  final Future<Result<ApiKeyRecord>> Function(Map<String, Object?> payload)
  onSubmit;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _expiresAtController = TextEditingController();
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _nameController.dispose();
    _expiresAtController.dispose();
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
          controller: _nameController,
          labelText: l10n.integrationsApiKeyNameFieldLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.integrationsApiKeyNameRequiredMessage,
          ),
        ),
        AppTextField(
          controller: _expiresAtController,
          labelText: l10n.integrationsExpiresAtFieldLabel,
          hintText: l10n.integrationsIsoDateHint,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.integrationsCreateApiKeySubmitAction,
          submitIcon: Icons.key_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(),
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

    final Result<ApiKeyRecord> result = await widget.onSubmit(<String, Object?>{
      ...widget.contextPayload,
      'name': _nameController.text.trim(),
      'expires_at': _expiresAtController.text.trim(),
    });
    if (!mounted) {
      return;
    }
    result.when(
      success: (ApiKeyRecord record) {
        Navigator.of(context).pop(record);
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isSubmitting = false;
        });
      },
    );
  }
}

class _WebhookDialog extends StatefulWidget {
  const _WebhookDialog({
    required this.state,
    required this.tenantId,
    required this.onSubmit,
    this.webhook,
  });

  final IntegrationWorkspaceState state;
  final String? tenantId;
  final WebhookSubscriptionRecord? webhook;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  State<_WebhookDialog> createState() => _WebhookDialogState();
}

class _WebhookDialogState extends State<_WebhookDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _eventController;
  late final TextEditingController _targetUrlController;
  String? _integrationId;
  late bool _isActive;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final WebhookSubscriptionRecord? webhook = widget.webhook;
    _eventController = TextEditingController(text: webhook?.event ?? '');
    _targetUrlController = TextEditingController(
      text: webhook?.targetUrl ?? '',
    );
    _integrationId = webhook?.integrationId;
    _isActive = webhook?.isActive ?? true;
  }

  @override
  void dispose() {
    _eventController.dispose();
    _targetUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppSelectField<String>.searchable(
          labelText: l10n.integrationsIntegrationFieldLabel,
          value: _integrationId,
          options: <AppSelectOption<String>>[
            for (final IntegrationRecord integration
                in widget.state.integrations)
              AppSelectOption<String>(
                value: integration.id,
                label: integration.title,
              ),
          ],
          onChanged: (String? value) {
            setState(() {
              _integrationId = value;
            });
          },
        ),
        AppTextField(
          controller: _eventController,
          labelText: l10n.integrationsEventFieldLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.integrationsEventRequiredMessage,
          ),
        ),
        AppTextField(
          controller: _targetUrlController,
          labelText: l10n.integrationsTargetUrlFieldLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.integrationsTargetUrlRequiredMessage,
          ),
          keyboardType: TextInputType.url,
        ),
        AppSwitchField(
          title: l10n.integrationsWebhookActiveFieldLabel,
          value: _isActive,
          onChanged: (bool value) {
            setState(() {
              _isActive = value;
            });
          },
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.webhook == null
              ? l10n.integrationsCreateWebhookSubmitAction
              : l10n.integrationsSaveWebhookAction,
          submitIcon: Icons.webhook_outlined,
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

    final Map<String, Object?> payload = <String, Object?>{
      if (widget.webhook == null) 'tenant_id': widget.tenantId,
      'integration_id': _integrationId,
      'event': _eventController.text.trim(),
      'target_url': _targetUrlController.text.trim(),
      'is_active': _isActive,
    };
    final AppFailure? failure = await widget.onSubmit(payload);
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

class _PermissionDialog extends StatefulWidget {
  const _PermissionDialog({
    required this.state,
    required this.onSubmit,
    this.apiKey,
  });

  final IntegrationWorkspaceState state;
  final ApiKeyRecord? apiKey;
  final Future<AppFailure?> Function({
    required String apiKeyId,
    required String permissionId,
  })
  onSubmit;

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _apiKeyId;
  String? _permissionId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _apiKeyId = widget.apiKey?.id;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppSelectField<String>.searchable(
          labelText: l10n.integrationsApiKeyFieldLabel,
          value: _apiKeyId,
          isRequired: true,
          options: <AppSelectOption<String>>[
            for (final ApiKeyRecord key in widget.state.apiKeys)
              AppSelectOption<String>(value: key.id, label: key.title),
          ],
          validator: AppValidators.requiredValue<String>(
            l10n.integrationsApiKeyRequiredMessage,
          ),
          onChanged: (String? value) {
            setState(() {
              _apiKeyId = value;
            });
          },
        ),
        AppSelectField<String>.searchable(
          labelText: l10n.integrationsPermissionFieldLabel,
          value: _permissionId,
          isRequired: true,
          options: <AppSelectOption<String>>[
            for (final IntegrationPermissionOption option
                in widget.state.permissionOptions)
              AppSelectOption<String>(value: option.id, label: option.label),
          ],
          validator: AppValidators.requiredValue<String>(
            l10n.integrationsPermissionRequiredMessage,
          ),
          onChanged: (String? value) {
            setState(() {
              _permissionId = value;
            });
          },
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.integrationsAddPermissionAction,
          submitIcon: Icons.admin_panel_settings_outlined,
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

    final String? apiKeyId = _apiKeyId;
    final String? permissionId = _permissionId;
    if (apiKeyId == null || permissionId == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      apiKeyId: apiKeyId,
      permissionId: permissionId,
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

Future<void> _openIntegrationDialog(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkspaceState state, {
  IntegrationRecord? integration,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(
      integration == null
          ? l10n.integrationsCreateIntegrationDialogTitle
          : l10n.integrationsConfigureIntegrationDialogTitle,
    ),
    icon: const Icon(Icons.add_link_outlined),
    content: _IntegrationConfigDialog(
      integration: integration,
      tenantId: controller.currentTenantId(),
      onSubmit: (Map<String, Object?> payload) {
        if (integration == null) {
          return controller.createIntegration(payload);
        }
        return controller.updateIntegration(integration.id, payload);
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _openApiKeyDialog(
  BuildContext context,
  IntegrationsWorkspaceController controller,
) async {
  final AppLocalizations l10n = context.l10n;
  final ApiKeyRecord? record = await showAppWorkspaceActionDialog<ApiKeyRecord>(
    context: context,
    title: Text(l10n.integrationsCreateApiKeyDialogTitle),
    icon: const Icon(Icons.key_outlined),
    content: _ApiKeyDialog(
      contextPayload: controller.currentApiKeyCreateContext(),
      onSubmit: controller.createApiKey,
    ),
  );
  if (!context.mounted || record == null) {
    return;
  }
  _showSaved(context);
  await _showCreatedSecretDialog(context, record);
}

Future<void> _openWebhookDialog(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkspaceState state, {
  WebhookSubscriptionRecord? webhook,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(
      webhook == null
          ? l10n.integrationsCreateWebhookDialogTitle
          : l10n.integrationsEditWebhookDialogTitle,
    ),
    icon: const Icon(Icons.webhook_outlined),
    content: _WebhookDialog(
      state: state,
      webhook: webhook,
      tenantId: controller.currentTenantId(),
      onSubmit: (Map<String, Object?> payload) {
        if (webhook == null) {
          return controller.createWebhook(payload);
        }
        return controller.updateWebhook(webhook.id, payload);
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _openPermissionDialog(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkspaceState state, {
  ApiKeyRecord? apiKey,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.integrationsManagePermissionsDialogTitle),
    icon: const Icon(Icons.admin_panel_settings_outlined),
    content: _PermissionDialog(
      state: state,
      apiKey: apiKey,
      onSubmit: controller.addApiKeyPermission,
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _showCreatedSecretDialog(
  BuildContext context,
  ApiKeyRecord record,
) async {
  final AppLocalizations l10n = context.l10n;
  final String secret = record.oneTimeSecret ?? l10n.integrationsSecretMissing;

  await showAppWorkspaceActionDialog<void>(
    context: context,
    title: Text(l10n.integrationsApiKeyCreatedDialogTitle),
    icon: const Icon(Icons.key_outlined),
    content: AppSectionPanel(
      title: l10n.integrationsApiKeyCreatedSecretTitle,
      description: l10n.integrationsApiKeyCreatedSecretBody,
      leadingIcon: Icons.visibility_outlined,
      children: <Widget>[SelectableText(secret)],
    ),
    actions: <Widget>[
      AppButton.secondary(
        label: l10n.integrationsCopySecretAction,
        leadingIcon: Icons.copy_outlined,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: secret));
          Navigator.of(context).pop();
        },
      ),
      AppButton.primary(
        label: l10n.commonCloseActionLabel,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

Future<void> _confirmTestConnection(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool confirmed = await _confirm(
    context,
    title: l10n.integrationsTestConnectionDialogTitle,
    message: l10n.integrationsTestConnectionDialogBody,
    confirmLabel: l10n.integrationsTestConnectionAction,
    icon: Icons.network_check_outlined,
  );
  if (!context.mounted || !confirmed) {
    return;
  }
  final Result<IntegrationActionResult> result = await controller
      .testConnection(item.id, <String, Object?>{'dry_run': true});
  if (context.mounted) {
    _showResult(context, result);
  }
}

Future<void> _confirmSyncNow(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool confirmed = await _confirm(
    context,
    title: l10n.integrationsSyncNowDialogTitle,
    message: l10n.integrationsSyncNowDialogBody,
    confirmLabel: l10n.integrationsSyncNowAction,
    icon: Icons.sync,
  );
  if (!context.mounted || !confirmed) {
    return;
  }
  final Result<IntegrationActionResult> result = await controller.syncNow(
    item.id,
    <String, Object?>{'force': true},
  );
  if (context.mounted) {
    _showResult(context, result);
  }
}

Future<void> _toggleIntegration(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkItem item,
) async {
  final IntegrationRecord? integration = item.integration;
  if (integration == null) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  final bool activate = !integration.isActive;
  final bool confirmed = await _confirm(
    context,
    title: activate
        ? l10n.integrationsEnableIntegrationDialogTitle
        : l10n.integrationsDisableIntegrationDialogTitle,
    message: activate
        ? l10n.integrationsEnableIntegrationDialogBody
        : l10n.integrationsDisableIntegrationDialogBody,
    confirmLabel: activate
        ? l10n.integrationsEnableAction
        : l10n.integrationsDisableAction,
    icon: activate ? Icons.play_circle_outline : Icons.pause_circle_outline,
  );
  if (!context.mounted || !confirmed) {
    return;
  }
  final AppFailure? failure = await controller.updateIntegration(
    integration.id,
    <String, Object?>{'status': activate ? 'ACTIVE' : 'INACTIVE'},
  );
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
    _showSavedIfNeeded(context, failure);
  }
}

Future<void> _toggleApiKey(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkItem item,
) async {
  final ApiKeyRecord? key = item.apiKey;
  if (key == null) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  final bool activate = !key.isActive;
  final bool confirmed = await _confirm(
    context,
    title: activate
        ? l10n.integrationsEnableApiKeyDialogTitle
        : l10n.integrationsDisableApiKeyDialogTitle,
    message: activate
        ? l10n.integrationsEnableApiKeyDialogBody
        : l10n.integrationsDisableApiKeyDialogBody,
    confirmLabel: activate
        ? l10n.integrationsEnableAction
        : l10n.integrationsDisableAction,
    icon: activate ? Icons.play_circle_outline : Icons.pause_circle_outline,
  );
  if (!context.mounted || !confirmed) {
    return;
  }
  final AppFailure? failure = await controller.updateApiKey(
    key.id,
    <String, Object?>{'is_active': activate},
  );
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
    _showSavedIfNeeded(context, failure);
  }
}

Future<void> _toggleWebhook(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkItem item,
) async {
  final WebhookSubscriptionRecord? webhook = item.webhook;
  if (webhook == null) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  final bool activate = !webhook.isActive;
  final bool confirmed = await _confirm(
    context,
    title: activate
        ? l10n.integrationsEnableWebhookDialogTitle
        : l10n.integrationsDisableWebhookDialogTitle,
    message: activate
        ? l10n.integrationsEnableWebhookDialogBody
        : l10n.integrationsDisableWebhookDialogBody,
    confirmLabel: activate
        ? l10n.integrationsEnableAction
        : l10n.integrationsDisableAction,
    icon: activate ? Icons.play_circle_outline : Icons.pause_circle_outline,
  );
  if (!context.mounted || !confirmed) {
    return;
  }
  final AppFailure? failure = await controller.updateWebhook(
    webhook.id,
    <String, Object?>{'is_active': activate},
  );
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
    _showSavedIfNeeded(context, failure);
  }
}

Future<void> _confirmRevokeApiKey(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final ApiKeyRecord? key = item.apiKey;
  if (key == null) {
    return;
  }
  final bool confirmed = await _confirm(
    context,
    title: l10n.integrationsRevokeApiKeyDialogTitle,
    message: l10n.integrationsRevokeApiKeyDialogBody,
    confirmLabel: l10n.integrationsRevokeApiKeyAction,
    icon: Icons.block_outlined,
  );
  if (!context.mounted || !confirmed) {
    return;
  }
  final AppFailure? failure = await controller.deleteApiKey(key.id);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
    _showSavedIfNeeded(context, failure);
  }
}

Future<void> _confirmReplayWebhook(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool confirmed = await _confirm(
    context,
    title: l10n.integrationsReplayWebhookDialogTitle,
    message: l10n.integrationsReplayWebhookDialogBody,
    confirmLabel: l10n.integrationsReplayWebhookAction,
    icon: Icons.replay_outlined,
  );
  if (!context.mounted || !confirmed) {
    return;
  }
  final Result<IntegrationActionResult> result = await controller.replayWebhook(
    item.id,
    <String, Object?>{},
  );
  if (context.mounted) {
    _showResult(context, result);
  }
}

Future<void> _confirmReplayLog(
  BuildContext context,
  IntegrationsWorkspaceController controller,
  IntegrationWorkItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool confirmed = await _confirm(
    context,
    title: l10n.integrationsReplayLogDialogTitle,
    message: l10n.integrationsReplayLogDialogBody,
    confirmLabel: l10n.integrationsReplayLogAction,
    icon: Icons.replay_outlined,
  );
  if (!context.mounted || !confirmed) {
    return;
  }
  final Result<IntegrationActionResult> result = await controller.replayLog(
    item.id,
    <String, Object?>{},
  );
  if (context.mounted) {
    _showResult(context, result);
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required IconData icon,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? result = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(title),
    icon: Icon(icon),
    content: Text(message),
    actions: <Widget>[
      AppButton.tertiary(
        label: l10n.commonCancelActionLabel,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      AppButton.primary(
        label: confirmLabel,
        leadingIcon: icon,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );
  return result == true;
}

Map<String, Object?> _parseConfigLines(String value) {
  final Map<String, Object?> config = <String, Object?>{};
  for (final String line in value.split(RegExp(r'\r?\n'))) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final int separator = trimmed.indexOf('=');
    if (separator <= 0) {
      config[trimmed] = true;
      continue;
    }
    final String key = trimmed.substring(0, separator).trim();
    final String entryValue = trimmed.substring(separator + 1).trim();
    if (key.isNotEmpty) {
      config[key] = entryValue;
    }
  }
  return config;
}

const String _integrationFilterKey = 'integration_filter';

AppSearchBarFilterValue _filterValue(IntegrationWorkspaceQuery query) {
  final IntegrationWorkspaceFilter? status = query.statusFilter;
  if (status == null) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    options: <String, String>{_integrationFilterKey: status.name},
  );
}

IntegrationWorkspaceFilter? _statusFilterFromValue(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  for (final IntegrationWorkspaceFilter filter
      in IntegrationWorkspaceFilter.values) {
    if (filter.name == value && _isStatusFilter(filter)) {
      return filter;
    }
  }
  return null;
}

bool _isStatusFilter(IntegrationWorkspaceFilter filter) {
  return switch (filter) {
    IntegrationWorkspaceFilter.active ||
    IntegrationWorkspaceFilter.warning ||
    IntegrationWorkspaceFilter.failed ||
    IntegrationWorkspaceFilter.disabled => true,
    _ => false,
  };
}

List<AppSearchBarFilterChoice> _statusFilterChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    for (final IntegrationWorkspaceFilter filter
        in <IntegrationWorkspaceFilter>[
          IntegrationWorkspaceFilter.active,
          IntegrationWorkspaceFilter.warning,
          IntegrationWorkspaceFilter.failed,
          IntegrationWorkspaceFilter.disabled,
        ])
      AppSearchBarFilterChoice(
        value: filter.name,
        label: _filterLabel(l10n, filter),
        icon: Icons.filter_list,
      ),
  ];
}

String _filterLabel(AppLocalizations l10n, IntegrationWorkspaceFilter filter) {
  return switch (filter) {
    IntegrationWorkspaceFilter.all => l10n.integrationsFilterAll,
    IntegrationWorkspaceFilter.integrations =>
      l10n.integrationsFilterIntegrations,
    IntegrationWorkspaceFilter.apiKeys => l10n.integrationsFilterApiKeys,
    IntegrationWorkspaceFilter.webhooks => l10n.integrationsFilterWebhooks,
    IntegrationWorkspaceFilter.logs => l10n.integrationsFilterLogs,
    IntegrationWorkspaceFilter.interop => l10n.integrationsFilterInterop,
    IntegrationWorkspaceFilter.active => l10n.integrationsFilterActive,
    IntegrationWorkspaceFilter.warning => l10n.integrationsFilterWarning,
    IntegrationWorkspaceFilter.failed => l10n.integrationsFilterFailed,
    IntegrationWorkspaceFilter.disabled => l10n.integrationsFilterDisabled,
  };
}

List<AppSelectOption<String>> _integrationTypeOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(value: 'HL7', label: l10n.integrationsTypeHl7),
    AppSelectOption<String>(value: 'FHIR', label: l10n.integrationsTypeFhir),
    AppSelectOption<String>(value: 'LAB', label: l10n.integrationsTypeLab),
    AppSelectOption<String>(
      value: 'RADIOLOGY',
      label: l10n.integrationsTypeRadiology,
    ),
    AppSelectOption<String>(
      value: 'BILLING',
      label: l10n.integrationsTypeBilling,
    ),
    AppSelectOption<String>(value: 'OTHER', label: l10n.integrationsTypeOther),
  ];
}

List<AppSelectOption<String>> _integrationStatusOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'ACTIVE',
      label: l10n.integrationsStatusActive,
    ),
    AppSelectOption<String>(
      value: 'INACTIVE',
      label: l10n.integrationsStatusInactive,
    ),
    AppSelectOption<String>(
      value: 'ERROR',
      label: l10n.integrationsStatusError,
    ),
  ];
}

String _kindLabel(AppLocalizations l10n, IntegrationWorkItemKind kind) {
  return switch (kind) {
    IntegrationWorkItemKind.integration => l10n.integrationsKindIntegration,
    IntegrationWorkItemKind.apiKey => l10n.integrationsKindApiKey,
    IntegrationWorkItemKind.webhook => l10n.integrationsKindWebhook,
    IntegrationWorkItemKind.log => l10n.integrationsKindLog,
    IntegrationWorkItemKind.interop => l10n.integrationsKindInterop,
  };
}

IconData _kindIcon(IntegrationWorkItemKind kind) {
  return switch (kind) {
    IntegrationWorkItemKind.integration => Icons.hub_outlined,
    IntegrationWorkItemKind.apiKey => Icons.key_outlined,
    IntegrationWorkItemKind.webhook => Icons.webhook_outlined,
    IntegrationWorkItemKind.log => Icons.receipt_long_outlined,
    IntegrationWorkItemKind.interop => Icons.compare_arrows_outlined,
  };
}

AppWorkspaceStatus _statusFor(BuildContext context, IntegrationWorkItem item) {
  return AppWorkspaceStatus(
    label: _statusLabel(context, item),
    tone: _statusTone(item),
    icon: _statusIcon(item),
  );
}

String _statusLabel(BuildContext context, IntegrationWorkItem item) {
  return _statusLabelForValue(context, item.status);
}

String _statusLabelForValue(BuildContext context, String? value) {
  final AppLocalizations l10n = context.l10n;
  return switch ((value ?? '').toUpperCase()) {
    'ACTIVE' => l10n.integrationsStatusActive,
    'INACTIVE' => l10n.integrationsStatusInactive,
    'ERROR' => l10n.integrationsStatusError,
    'FAILED' => l10n.integrationsStatusFailed,
    'READY' => l10n.integrationsStatusReady,
    'UNAVAILABLE' => l10n.integrationsStatusBackendGap,
    'QUEUED' => l10n.integrationsStatusQueued,
    'CONNECTED' => l10n.integrationsStatusConnected,
    'UNKNOWN' => l10n.profileUnknownValue,
    _ => _apiLabel(value ?? ''),
  };
}

AppWorkspaceStatusTone _statusTone(IntegrationWorkItem item) {
  final String status = item.status.toUpperCase();
  if (status == 'ERROR' || status == 'FAILED') {
    return AppWorkspaceStatusTone.error;
  }
  if (status == 'INACTIVE' || status == 'UNAVAILABLE') {
    return AppWorkspaceStatusTone.warning;
  }
  if (status == 'ACTIVE' || status == 'READY' || status == 'CONNECTED') {
    return AppWorkspaceStatusTone.success;
  }
  return AppWorkspaceStatusTone.neutral;
}

IconData _statusIcon(IntegrationWorkItem item) {
  return switch (item.status.toUpperCase()) {
    'ACTIVE' || 'READY' || 'CONNECTED' => Icons.check_circle_outline,
    'INACTIVE' || 'UNAVAILABLE' => Icons.warning_amber_outlined,
    'ERROR' || 'FAILED' => Icons.error_outline,
    'QUEUED' => Icons.schedule_outlined,
    _ => Icons.info_outline,
  };
}

String _scopeLabel(BuildContext context, String value) {
  final AppLocalizations l10n = context.l10n;
  return switch (value.toUpperCase()) {
    'HL7' => l10n.integrationsTypeHl7,
    'FHIR' => l10n.integrationsTypeFhir,
    'LAB' => l10n.integrationsTypeLab,
    'RADIOLOGY' => l10n.integrationsTypeRadiology,
    'BILLING' => l10n.integrationsTypeBilling,
    'OTHER' => l10n.integrationsTypeOther,
    'NO_SCOPES' => l10n.integrationsNoScopesLabel,
    '1_SCOPE' => l10n.integrationsOneScopeLabel,
    'WEBHOOK' => l10n.integrationsKindWebhook,
    'LOG' => l10n.integrationsKindLog,
    'FHIR_EXPORT_IMPORT' => l10n.integrationsInteropFhirScope,
    'HL7_SUBMIT' => l10n.integrationsInteropHl7Scope,
    'DICOM_STUDY_LINK' => l10n.integrationsInteropDicomScope,
    'MIGRATION_EXPORT_IMPORT' => l10n.integrationsInteropMigrationScope,
    'INTEROP_STATUS' => l10n.integrationsInteropStatusScope,
    _ =>
      value.endsWith('_SCOPES')
          ? l10n.integrationsManyScopesLabel(value.split('_').first)
          : _apiLabel(value),
  };
}

String _nextActionLabel(BuildContext context, String value) {
  final AppLocalizations l10n = context.l10n;
  return switch (value) {
    'review_failure' => l10n.integrationsNextActionReviewFailure,
    'enable' => l10n.integrationsNextActionEnable,
    'monitor' => l10n.integrationsNextActionMonitor,
    'review_key' => l10n.integrationsNextActionReviewKey,
    'rotate_or_monitor' => l10n.integrationsNextActionRotateOrMonitor,
    'enable_webhook' => l10n.integrationsNextActionEnableWebhook,
    'monitor_delivery' => l10n.integrationsNextActionMonitorDelivery,
    'replay_or_escalate' => l10n.integrationsNextActionReplayOrEscalate,
    'review' => l10n.integrationsNextActionReview,
    'RUN_AVAILABLE_ACTION' => l10n.integrationsNextActionRunEndpoint,
    'USE_INTEGRATION_STATUS_AND_LOGS' =>
      l10n.integrationsNextActionUseStatusLogs,
    _ => _apiLabel(value),
  };
}

String _interopTitle(AppLocalizations l10n, String value) {
  return switch (value) {
    'FHIR_EXCHANGE' => l10n.integrationsInteropFhirTitle,
    'HL7_MESSAGES' => l10n.integrationsInteropHl7Title,
    'DICOM_LINK' => l10n.integrationsInteropDicomTitle,
    'MIGRATION_EXCHANGE' => l10n.integrationsInteropMigrationTitle,
    'EXTERNAL_READINESS_STATUS' => l10n.integrationsInteropReadinessTitle,
    _ => _apiLabel(value),
  };
}

String _interopUnavailableReason(AppLocalizations l10n, String value) {
  return switch (value) {
    'INTEROP_READINESS_SIGNAL_UNAVAILABLE' =>
      l10n.integrationsInteropReadinessGapBody,
    _ => _apiLabel(value),
  };
}

String _detailTitle(BuildContext context, IntegrationWorkItem item) {
  return item.title.trim().isEmpty
      ? context.l10n.profileUnknownValue
      : item.title;
}

String _actionResultMessage(
  BuildContext context,
  IntegrationActionResult result,
) {
  final String status = _statusLabelForValue(context, result.status);
  final String? message = result.message;
  if (message == null || message.trim().isEmpty) {
    return status;
  }
  return '$status: ${_apiLabel(message)}';
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

void _showResult(BuildContext context, Result<IntegrationActionResult> result) {
  result.when(
    success: (IntegrationActionResult actionResult) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_actionResultMessage(context, actionResult))),
      );
    },
    failure: (AppFailure failure) {
      _showFailureIfNeeded(context, failure);
    },
  );
}

IntegrationWorkspaceState? _integrationStateFromAsync(
  AsyncValue<Result<IntegrationWorkspaceState>> asyncState,
) {
  return asyncState.asData?.value.when(
    success: (IntegrationWorkspaceState state) => state,
    failure: (_) => null,
  );
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

void _showSavedIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    _showSaved(context);
  }
}

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.integrationsSavedMessage)),
  );
}
