import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';
import 'package:hosspi_hms/features/integrations/presentation/controllers/integrations_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

const AccessRequirement _integrationsManageRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.integrationWrite,
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.systemAdmin,
  ],
  activeModules: <String>['integrations-core'],
);

class IntegrationsWorkspacePage extends ConsumerWidget {
  const IntegrationsWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<IntegrationWorkspaceState>> value = ref.watch(
      integrationsWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return value.when(
      data: (Result<IntegrationWorkspaceState> result) {
        return result.when(
          success: (IntegrationWorkspaceState state) {
            return _IntegrationsWorkspaceContent(state: state);
          },
          failure: (AppFailure failure) {
            return ResponsivePage(
              maxWidth: PageMaxWidth.form,
              centerVertically: true,
              child: AppFailureStateView(
                failure: failure,
                title: l10n.integrationsLoadErrorTitle,
                body: l10n.integrationsLoadErrorBody,
                onRetry: () {
                  ref.invalidate(integrationsWorkspaceControllerProvider);
                },
              ),
            );
          },
        );
      },
      error: (_, _) {
        return ResponsivePage(
          maxWidth: PageMaxWidth.form,
          centerVertically: true,
          child: AppStateView(
            variant: AppStateViewVariant.error,
            title: l10n.integrationsLoadErrorTitle,
            body: l10n.errorUnexpectedMessage,
          ),
        );
      },
      loading: () {
        return ResponsivePage(
          maxWidth: PageMaxWidth.form,
          centerVertically: true,
          child: AppWorkspaceStatePanel.loading(
            title: l10n.integrationsLoadingTitle,
            body: l10n.integrationsLoadingBody,
          ),
        );
      },
    );
  }
}

class _IntegrationsWorkspaceContent extends ConsumerStatefulWidget {
  const _IntegrationsWorkspaceContent({required this.state});

  final IntegrationWorkspaceState state;

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<IntegrationWorkItem>();
  }

  @override
  void didUpdateWidget(covariant _IntegrationsWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.value = TextEditingValue(text: search);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IntegrationWorkspaceState state = widget.state;
    final IntegrationsWorkspaceController controller = ref.read(
      integrationsWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canManage = _integrationsManageRequirement.isAllowed(
      accessPolicy,
    );
    final int totalCount = state.workItems.length;
    final AppWorkspaceStatus workspaceStatus = state.failedCount > 0
        ? AppWorkspaceStatus(
            label: l10n.integrationsFailedStatusLabel,
            tone: AppWorkspaceStatusTone.error,
          )
        : state.warningCount > 0
        ? AppWorkspaceStatus(
            label: l10n.integrationsWarningStatusLabel,
            tone: AppWorkspaceStatusTone.warning,
          )
        : AppWorkspaceStatus(
            label: l10n.integrationsOperationalStatusLabel,
            tone: AppWorkspaceStatusTone.success,
          );

    return AppWorkspace(
      title: l10n.integrationsWorkspaceTitle,
      leadingIcon: AppRouteIcons.integrations,
      status: workspaceStatus,
      primaryAction: AppPermissionActionButton(
        requirement: _integrationsManageRequirement,
        label: l10n.integrationsCreateIntegrationAction,
        icon: Icons.add_link_outlined,
        variant: AppButtonVariant.primary,
        isLoading: state.isSaving,
        hideWhenDenied: true,
        onPressed: () {
          unawaited(_openIntegrationDialog(context, controller, state));
        },
      ),
      secondaryActions: <Widget>[
        AppPermissionActionButton(
          requirement: _integrationsManageRequirement,
          label: l10n.integrationsCreateApiKeyAction,
          icon: Icons.key_outlined,
          isLoading: state.isSaving,
          hideWhenDenied: true,
          onPressed: () {
            unawaited(_openApiKeyDialog(context, controller));
          },
        ),
        AppPermissionActionButton(
          requirement: _integrationsManageRequirement,
          label: l10n.integrationsCreateWebhookAction,
          icon: Icons.webhook_outlined,
          isLoading: state.isSaving,
          hideWhenDenied: true,
          onPressed: () {
            unawaited(_openWebhookDialog(context, controller, state));
          },
        ),
        AppButton.tertiary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          isLoading: state.isRefreshing,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      compactSummaryCards: true,
      summaryCards: <Widget>[
        AppWorkspaceSummaryCard(
          compact: true,
          label: l10n.integrationsAllSummaryLabel,
          value: totalCount.toString(),
          icon: Icons.hub_outlined,
          onPressed: () {
            unawaited(_applyFilter(controller, IntegrationWorkspaceFilter.all));
          },
        ),
        AppWorkspaceSummaryCard(
          compact: true,
          label: l10n.integrationsActiveSummaryLabel,
          value: state.activeCount.toString(),
          icon: Icons.check_circle_outline,
          tone: AppWorkspaceStatusTone.success,
          onPressed: () {
            unawaited(
              _applyFilter(controller, IntegrationWorkspaceFilter.active),
            );
          },
        ),
        AppWorkspaceSummaryCard(
          compact: true,
          label: l10n.integrationsWarningsSummaryLabel,
          value: state.warningCount.toString(),
          icon: Icons.warning_amber_outlined,
          tone: AppWorkspaceStatusTone.warning,
          onPressed: () {
            unawaited(
              _applyFilter(controller, IntegrationWorkspaceFilter.warning),
            );
          },
        ),
        AppWorkspaceSummaryCard(
          compact: true,
          label: l10n.integrationsFailedSummaryLabel,
          value: state.failedCount.toString(),
          icon: Icons.error_outline,
          tone: AppWorkspaceStatusTone.error,
          onPressed: () {
            unawaited(
              _applyFilter(controller, IntegrationWorkspaceFilter.failed),
            );
          },
        ),
        AppWorkspaceSummaryCard(
          compact: true,
          label: l10n.integrationsApiKeysSummaryLabel,
          value: state.apiKeys.length.toString(),
          icon: Icons.key_outlined,
          onPressed: () {
            unawaited(
              _applyFilter(controller, IntegrationWorkspaceFilter.apiKeys),
            );
          },
        ),
        AppWorkspaceSummaryCard(
          compact: true,
          label: l10n.integrationsWebhooksSummaryLabel,
          value: state.webhooks.length.toString(),
          icon: Icons.webhook_outlined,
          onPressed: () {
            unawaited(
              _applyFilter(controller, IntegrationWorkspaceFilter.webhooks),
            );
          },
        ),
      ],
      body: _IntegrationWorklistPanel(
        state: state,
        searchController: _searchController,
        columnVisibilityController: _tableColumnController,
      ),
      detail: _IntegrationDetailPanel(state: state, canManage: canManage),
    );
  }

  Future<void> _applyFilter(
    IntegrationsWorkspaceController controller,
    IntegrationWorkspaceFilter filter,
  ) async {
    final AppFailure? failure = await controller.applyFilter(filter);
    if (mounted) {
      _showFailureIfNeeded(context, failure);
    }
  }
}

class _IntegrationWorklistPanel extends ConsumerWidget {
  const _IntegrationWorklistPanel({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final IntegrationWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<IntegrationWorkItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IntegrationsWorkspaceController controller = ref.read(
      integrationsWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.integrationsWorklistTitle,
      description: l10n.integrationsWorklistDescription,
      child: SizedBox(
        height: 560,
        child: AppListTable<IntegrationWorkItem>(
          page: state.workItemsPage,
          isLoading: state.isRefreshing,
          columnVisibilityController: columnVisibilityController,
          columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
          search: AppListTableSearch<IntegrationWorkItem>(
            controller: searchController,
            semanticLabel: l10n.integrationsSearchLabel,
            hintText: l10n.integrationsSearchHint,
            matcher: (_, _) => true,
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
            advancedFilterButtonLabel: l10n.integrationsFiltersLabel,
            advancedFilterTitle: l10n.integrationsFiltersLabel,
            advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
            advancedFilterResetLabel: l10n.opdClearFiltersAction,
            advancedFilterCancelLabel: l10n.commonCancelActionLabel,
            enableDateFilter: false,
            allFieldsLabel: l10n.integrationsFilterAll,
            filterGroups: <AppSearchBarFilterGroup>[
              AppSearchBarFilterGroup(
                key: _integrationFilterKey,
                label: l10n.integrationsFilterGroupLabel,
                allLabel: l10n.integrationsFilterAll,
                choices: _filterChoices(l10n),
              ),
            ],
            filterValue: _filterValue(state.query),
            hasActiveFilters:
                state.query.filter != IntegrationWorkspaceFilter.all,
            onFilterChanged: (AppSearchBarFilterValue value) async {
              final AppFailure? failure = await controller.applyFilter(
                _filterFromValue(value.option(_integrationFilterKey)),
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
          onRowSelected: (IntegrationWorkItem item) {
            unawaited(controller.selectItem(item));
          },
          emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
            title: l10n.integrationsEmptyTitle,
            body: l10n.integrationsEmptyBody,
            icon: Icons.hub_outlined,
          ),
          columns: <AppListTableColumn<IntegrationWorkItem>>[
            AppListTableColumn<IntegrationWorkItem>(
              label: l10n.integrationsTypeColumnLabel,
              sortComparator:
                  (IntegrationWorkItem left, IntegrationWorkItem right) {
                    return appListTableCompareText(
                      _kindLabel(l10n, left.kind),
                      _kindLabel(l10n, right.kind),
                    );
                  },
              cellBuilder: (BuildContext context, IntegrationWorkItem item) {
                return Text(_kindLabel(context.l10n, item.kind));
              },
            ),
            AppListTableColumn<IntegrationWorkItem>(
              label: l10n.integrationsNameColumnLabel,
              sortComparator:
                  (IntegrationWorkItem left, IntegrationWorkItem right) {
                    return appListTableCompareText(left.title, right.title);
                  },
              cellBuilder: (BuildContext context, IntegrationWorkItem item) {
                return Text(item.title);
              },
            ),
            AppListTableColumn<IntegrationWorkItem>(
              label: l10n.integrationsStatusColumnLabel,
              sortComparator:
                  (IntegrationWorkItem left, IntegrationWorkItem right) {
                    return appListTableCompareText(left.status, right.status);
                  },
              cellBuilder: (BuildContext context, IntegrationWorkItem item) {
                return AppWorkspaceStatusBadge(
                  status: _statusFor(context, item),
                );
              },
            ),
            AppListTableColumn<IntegrationWorkItem>(
              label: l10n.integrationsOwnerColumnLabel,
              sortComparator:
                  (IntegrationWorkItem left, IntegrationWorkItem right) {
                    return appListTableCompareText(left.owner, right.owner);
                  },
              cellBuilder: (BuildContext context, IntegrationWorkItem item) {
                return Text(_fallback(context, item.owner));
              },
            ),
            AppListTableColumn<IntegrationWorkItem>(
              label: l10n.integrationsScopeColumnLabel,
              sortComparator:
                  (IntegrationWorkItem left, IntegrationWorkItem right) {
                    return appListTableCompareText(left.scope, right.scope);
                  },
              cellBuilder: (BuildContext context, IntegrationWorkItem item) {
                return Text(_scopeLabel(context, item.scope));
              },
            ),
            AppListTableColumn<IntegrationWorkItem>(
              label: l10n.integrationsLastEventColumnLabel,
              sortComparator:
                  (IntegrationWorkItem left, IntegrationWorkItem right) {
                    return appListTableCompareDateTime(
                      left.lastEventAt,
                      right.lastEventAt,
                    );
                  },
              cellBuilder: (BuildContext context, IntegrationWorkItem item) {
                return Text(_dateTimeLabel(context, item.lastEventAt));
              },
            ),
            AppListTableColumn<IntegrationWorkItem>(
              label: l10n.integrationsNextActionColumnLabel,
              sortComparator:
                  (IntegrationWorkItem left, IntegrationWorkItem right) {
                    return appListTableCompareText(
                      left.nextAction,
                      right.nextAction,
                    );
                  },
              cellBuilder: (BuildContext context, IntegrationWorkItem item) {
                return Text(_nextActionLabel(context, item.nextAction));
              },
            ),
          ],
          mobileItemBuilder: (BuildContext context, IntegrationWorkItem item) {
            return _MobileIntegrationItem(item: item);
          },
        ),
      ),
    );
  }
}

class _MobileIntegrationItem extends StatelessWidget {
  const _MobileIntegrationItem({required this.item});

  final IntegrationWorkItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_kindIcon(item.kind), size: theme.appTokens.listIconSize),
              SizedBox(width: theme.spacing.xs),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              AppWorkspaceStatusBadge(status: _statusFor(context, item)),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            l10n.integrationsMobileSubtitle(
              _kindLabel(l10n, item.kind),
              _scopeLabel(context, item.scope),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            _nextActionLabel(context, item.nextAction),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
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

    return AppWorkspaceDetailPanel(
      title: _detailTitle(context, item),
      description: _kindLabel(l10n, item.kind),
      actions: _detailActions(context, controller, state, item, canManage),
      child: _detailBody(context, state, item),
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
      AppButton.secondary(
        label: l10n.integrationsTestConnectionAction,
        leadingIcon: Icons.network_check_outlined,
        isLoading: state.isSaving,
        onPressed: () {
          unawaited(_confirmTestConnection(context, controller, item));
        },
      ),
      AppButton.secondary(
        label: l10n.integrationsSyncNowAction,
        leadingIcon: Icons.sync,
        isLoading: state.isSaving,
        onPressed: () {
          unawaited(_confirmSyncNow(context, controller, item));
        },
      ),
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
            message: status.backendGap == null
                ? l10n.integrationsInteropReadyBody
                : _interopGap(l10n, status.backendGap!),
            icon: Icons.compare_arrows_outlined,
            tone: status.backendGap == null
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

    return AppSectionPanel(
      title: l10n.integrationsConfigurationTitle,
      description: integration.hasConfig
          ? l10n.integrationsConfigurationMaskedBody
          : l10n.integrationsConfigurationEmptyBody,
      leadingIcon: Icons.settings_applications_outlined,
      children: <Widget>[
        if (entries.isEmpty)
          Text(l10n.integrationsNoConfigurationRows)
        else
          for (final String entry in entries)
            Text(entry, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _RelatedWebhooksPanel extends StatelessWidget {
  const _RelatedWebhooksPanel({required this.webhooks});

  final List<WebhookSubscriptionRecord> webhooks;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppSectionPanel(
      title: l10n.integrationsRelatedWebhooksTitle,
      leadingIcon: Icons.webhook_outlined,
      children: <Widget>[
        if (webhooks.isEmpty)
          Text(l10n.integrationsNoRelatedWebhooks)
        else
          for (final WebhookSubscriptionRecord webhook in webhooks.take(4))
            _CompactFactRow(
              label: _fallback(context, webhook.event),
              value: _fallback(context, webhook.targetHost),
            ),
      ],
    );
  }
}

class _RelatedLogsPanel extends StatelessWidget {
  const _RelatedLogsPanel({required this.logs});

  final List<IntegrationLogRecord> logs;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppSectionPanel(
      title: l10n.integrationsRelatedLogsTitle,
      leadingIcon: Icons.receipt_long_outlined,
      children: <Widget>[
        if (logs.isEmpty)
          Text(l10n.integrationsNoRelatedLogs)
        else
          for (final IntegrationLogRecord log in logs.take(4))
            _CompactFactRow(
              label: _statusLabelForValue(context, log.status),
              value: _fallback(context, log.message),
            ),
      ],
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

    return AppSectionPanel(
      title: l10n.integrationsPermissionsTitle,
      leadingIcon: Icons.admin_panel_settings_outlined,
      children: <Widget>[
        if (permissions.isEmpty)
          Text(l10n.integrationsNoPermissions)
        else
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
        AppIconButton(
          icon: Icons.remove_circle_outline,
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
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
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
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
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
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
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
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
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
  if (query.filter == IntegrationWorkspaceFilter.all) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    options: <String, String>{_integrationFilterKey: query.filter.name},
  );
}

IntegrationWorkspaceFilter _filterFromValue(String? value) {
  for (final IntegrationWorkspaceFilter filter
      in IntegrationWorkspaceFilter.values) {
    if (filter.name == value) {
      return filter;
    }
  }
  return IntegrationWorkspaceFilter.all;
}

List<AppSearchBarFilterChoice> _filterChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    for (final IntegrationWorkspaceFilter filter
        in IntegrationWorkspaceFilter.values)
      if (filter != IntegrationWorkspaceFilter.all)
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
    'BACKEND_GAP' => l10n.integrationsStatusBackendGap,
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
  if (status == 'INACTIVE' || status == 'BACKEND_GAP') {
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
    'INACTIVE' || 'BACKEND_GAP' => Icons.warning_amber_outlined,
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
    'RUN_FROM_ACTION_ENDPOINT' => l10n.integrationsNextActionRunEndpoint,
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

String _interopGap(AppLocalizations l10n, String value) {
  return switch (value) {
    'NO_DEDICATED_INTEROP_READINESS_ENDPOINT' =>
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
