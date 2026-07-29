import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/communications_access.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_detail_dialogs.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_inbox_panel.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_new_conversation_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class CommunicationsWorkspacePage extends ConsumerWidget {
  const CommunicationsWorkspacePage({required this.initialQuery, super.key});

  final CommunicationsWorkspaceQuery initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<CommunicationsWorkspaceState>> workspace = ref
        .watch(communicationsWorkspaceControllerProvider);

    return AsyncStateScaffold<CommunicationsWorkspaceState>(
      value: workspace,
      loadingTitle: l10n.communicationsLoadingTitle,
      loadingBody: l10n.communicationsLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(communicationsWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, CommunicationsWorkspaceState state) {
        return _CommunicationsWorkspaceContent(
          state: state,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _CommunicationsWorkspaceContent extends ConsumerStatefulWidget {
  const _CommunicationsWorkspaceContent({
    required this.state,
    required this.initialQuery,
  });

  final CommunicationsWorkspaceState state;
  final CommunicationsWorkspaceQuery initialQuery;

  @override
  ConsumerState<_CommunicationsWorkspaceContent> createState() =>
      _CommunicationsWorkspaceContentState();
}

class _CommunicationsWorkspaceContentState
    extends ConsumerState<_CommunicationsWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<NotificationItem>
  _notificationColumns;
  late final AppListTableColumnVisibilityController<NotificationDelivery>
  _deliveryColumns;
  late final AppListTableColumnVisibilityController<CommunicationTemplate>
  _templateColumns;
  ProviderSubscription<AsyncValue<Result<CommunicationsWorkspaceState>>>?
  _routeSubscription;
  String? _appliedRouteSignature;
  String? _syncedRouteSignature;
  String? _openedDialogSignature;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _notificationColumns =
        AppListTableColumnVisibilityController<NotificationItem>();
    _deliveryColumns =
        AppListTableColumnVisibilityController<NotificationDelivery>();
    _templateColumns =
        AppListTableColumnVisibilityController<CommunicationTemplate>();

    _routeSubscription = ref.listenManual(
      communicationsWorkspaceControllerProvider,
      (
        AsyncValue<Result<CommunicationsWorkspaceState>>? previous,
        AsyncValue<Result<CommunicationsWorkspaceState>> next,
      ) {
        final CommunicationsWorkspaceState? previousState = previous
            ?.asData
            ?.value
            .when(
              success: (CommunicationsWorkspaceState value) => value,
              failure: (_) => null,
            );
        final CommunicationsWorkspaceState? nextState = next.asData?.value.when(
          success: (CommunicationsWorkspaceState value) => value,
          failure: (_) => null,
        );
        if (nextState == null || !mounted) {
          return;
        }
        if (previousState != null &&
            _querySignature(previousState.query) ==
                _querySignature(nextState.query)) {
          return;
        }
        _syncRoute(nextState.query);
      },
    );
    _scheduleRouteQuery(widget.initialQuery);
  }

  void _scheduleRouteQuery(CommunicationsWorkspaceQuery query) {
    final String signature = _querySignature(query);
    if (_appliedRouteSignature == signature || !_hasRouteQuery(query)) {
      return;
    }
    _appliedRouteSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref
            .read(communicationsWorkspaceControllerProvider.notifier)
            .applyRouteQuery(query),
      );
    });
  }

  void _syncRoute(CommunicationsWorkspaceQuery query) {
    final String signature = _querySignature(query);
    if (_syncedRouteSignature == signature) {
      return;
    }
    _syncedRouteSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final String location = AppRoutes.communications.location(
        queryParameters: query.toQueryParameters(),
      );
      final Uri currentUri = GoRouterState.of(context).uri;
      if (_routeUriMatchesQuery(currentUri, query)) {
        return;
      }
      context.go(location);
    });
  }

  bool _routeUriMatchesQuery(Uri uri, CommunicationsWorkspaceQuery query) {
    return _querySignature(CommunicationsWorkspaceQuery.fromUri(uri)) ==
        _querySignature(query);
  }

  @override
  void didUpdateWidget(covariant _CommunicationsWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextSearch = widget.state.query.search;
    if (oldWidget.state.query.search != nextSearch &&
        _searchController.text != nextSearch) {
      _searchController.text = nextSearch;
    }
    if (_querySignature(oldWidget.initialQuery) !=
        _querySignature(widget.initialQuery)) {
      _scheduleRouteQuery(widget.initialQuery);
    }
    _scheduleDeepLinkDialog(widget.state, oldWidget.state);
  }

  @override
  void dispose() {
    _routeSubscription?.close();
    _searchController.dispose();
    _notificationColumns.dispose();
    _deliveryColumns.dispose();
    _templateColumns.dispose();
    super.dispose();
  }

  Future<void> _openNewConversation(BuildContext context, WidgetRef ref) async {
    await showCommunicationsNewDirectMessageDialog(context, ref);
  }

  void _scheduleDeepLinkDialog(
    CommunicationsWorkspaceState state, [
    CommunicationsWorkspaceState? previousState,
  ]) {
    final String? dialogSignature = _targetedDialogSignature(
      state.query,
      state,
    );
    if (dialogSignature == null || dialogSignature == _openedDialogSignature) {
      return;
    }
    if (previousState != null &&
        _targetedDialogSignature(previousState.query, previousState) ==
            dialogSignature) {
      return;
    }
    _openedDialogSignature = dialogSignature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_openDeepLinkedDialog(state));
    });
  }

  Future<void> _openDeepLinkedDialog(CommunicationsWorkspaceState state) async {
    switch (state.query.panel) {
      case CommunicationsPanel.notifications:
        final NotificationItem? notification = state.selectedNotification;
        if (notification == null) {
          return;
        }
        final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
        if (!CommunicationsNotificationsAtomPermissions.detail.isAllowed(
          policy,
        )) {
          return;
        }
        await showCommunicationsNotificationDetailDialog(
          context,
          ref,
          state,
          notification,
          canDelete: CommunicationsNotificationsAtomPermissions.archive
              .isAllowed(policy),
        );
      case CommunicationsPanel.templates:
        final CommunicationTemplate? template = state.selectedTemplate;
        if (template == null) {
          return;
        }
        final AppAccessPolicy templatePolicy = ref.read(appAccessPolicyProvider);
        if (!CommunicationsTemplatesAtomPermissions.detail.isAllowed(
          templatePolicy,
        )) {
          return;
        }
        await showCommunicationsTemplateDetailDialog(
          context,
          ref,
          state,
          template,
        );
      case CommunicationsPanel.inbox:
      case CommunicationsPanel.deliveries:
        return;
    }
  }

  String? _targetedDialogSignature(
    CommunicationsWorkspaceQuery query,
    CommunicationsWorkspaceState state,
  ) {
    return switch (query.panel) {
      CommunicationsPanel.notifications =>
        query.notificationId != null && state.selectedNotification != null
            ? 'notification:${query.notificationId}'
            : null,
      CommunicationsPanel.templates =>
        query.templateId != null && state.selectedTemplate != null
            ? 'template:${query.templateId}'
            : null,
      CommunicationsPanel.inbox || CommunicationsPanel.deliveries => null,
    };
  }

  Widget? _buildPrimaryAction(
    AppLocalizations l10n,
    CommunicationsWorkspaceState state,
    AppAccessPolicy policy,
  ) {
    // Tab-strip Refresh was removed as redundant — workspace refreshes after
    // mutations / realtime / scaffold Try again.
    if (state.query.panel != CommunicationsPanel.inbox ||
        !CommunicationsMessagesAtomPermissions.newMessage.isAllowed(policy)) {
      return null;
    }
    return AppTabToolbarPrimary(
      label: l10n.communicationsNewMessageAction,
      icon: Icons.add_comment_outlined,
      onPressed: () => _openNewConversation(context, ref),
    );
  }

  List<Widget> _buildSecondaryActions(
    AppLocalizations l10n,
    CommunicationsWorkspaceState state,
    AppAccessPolicy policy,
  ) {
    if (state.query.panel != CommunicationsPanel.inbox ||
        !CommunicationsMessagesAtomPermissions.newGroup.isAllowed(policy)) {
      return const <Widget>[];
    }

    return <Widget>[
      AppTabToolbarAction(
        label: l10n.communicationsNewGroupAction,
        icon: Icons.group_add_outlined,
        onPressed: () => showCommunicationsNewGroupDialog(context, ref),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CommunicationsWorkspaceState state = widget.state;
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    // Messages New message/group / compose / thread menu — write ∩ via atom map.
    final bool canWrite =
        CommunicationsMessagesAtomPermissions.write.isAllowed(policy);
    final List<CommunicationsPanel> visiblePanels =
        communicationsAllowedPanels(policy);
    if (visiblePanels.isEmpty) {
      // No authorized panels — omit chrome (no routine "no access" banner).
      return const SizedBox.shrink();
    }
    final bool canShowCurrentPanel = visiblePanels.contains(state.query.panel);
    if (!canShowCurrentPanel) {
      final CommunicationsPanel? fallback = communicationsFallbackPanel(policy);
      if (fallback != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              communicationsAllowedPanels(
                ref.read(appAccessPolicyProvider),
              ).contains(widget.state.query.panel)) {
            return;
          }
          controller.applyPanel(fallback);
        });
      }
    }
    final Object? lastFailure = state.lastFailure;
    _scheduleDeepLinkDialog(state);

    return AppWorkspace(
      title: l10n.communicationsWorkspaceTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTabStrip(
            tabs: <AppTabItem>[
              for (final CommunicationsPanel panel in visiblePanels)
                AppTabItem(
                  id: panel.serverValue,
                  icon: _panelIcon(panel),
                  label: _panelTitle(l10n, panel),
                  count: _panelCount(state, panel),
                ),
            ],
            selectedId: canShowCurrentPanel
                ? state.query.panel.serverValue
                : visiblePanels.first.serverValue,
            onTabTapped: (String tabId) {
              final CommunicationsPanel panel = CommunicationsPanel.fromServer(
                tabId,
              );
              if (!visiblePanels.contains(panel)) {
                return;
              }
              controller.applyPanel(panel);
            },
            primaryAction: _buildPrimaryAction(l10n, state, policy),
            secondaryActions: _buildSecondaryActions(l10n, state, policy),
          ),
          SizedBox(height: Theme.of(context).spacing.sm),
          if (lastFailure is AppFailure) ...<Widget>[
            AppFailureStateView(
              failure: lastFailure,
              onRetry: controller.refresh,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          if (canShowCurrentPanel)
            _CommunicationsListPanel(
              state: state,
              searchController: _searchController,
              canWrite: canWrite,
              notificationColumns: _notificationColumns,
              deliveryColumns: _deliveryColumns,
              templateColumns: _templateColumns,
            ),
        ],
      ),
    );
  }
}

class _CommunicationsListPanel extends ConsumerWidget {
  const _CommunicationsListPanel({
    required this.state,
    required this.searchController,
    required this.canWrite,
    required this.notificationColumns,
    required this.deliveryColumns,
    required this.templateColumns,
  });

  final CommunicationsWorkspaceState state;
  final TextEditingController searchController;
  final bool canWrite;
  final AppListTableColumnVisibilityController<NotificationItem>
  notificationColumns;
  final AppListTableColumnVisibilityController<NotificationDelivery>
  deliveryColumns;
  final AppListTableColumnVisibilityController<CommunicationTemplate>
  templateColumns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.query.panel == CommunicationsPanel.inbox) {
      return CommunicationsInboxPanel(
        state: state,
        searchController: searchController,
        canWrite: canWrite,
      );
    }

    return _tableForPanel(context, ref);
  }

  Widget _tableForPanel(BuildContext context, WidgetRef ref) {
    return switch (state.query.panel) {
      CommunicationsPanel.inbox => const SizedBox.shrink(),
      CommunicationsPanel.notifications => _NotificationsTable(
        state: state,
        searchController: searchController,
        columnVisibilityController: notificationColumns,
      ),
      CommunicationsPanel.deliveries => _DeliveriesTable(
        state: state,
        searchController: searchController,
        columnVisibilityController: deliveryColumns,
      ),
      CommunicationsPanel.templates => _TemplatesTable(
        state: state,
        searchController: searchController,
        columnVisibilityController: templateColumns,
      ),
    };
  }
}

class _NotificationsTable extends ConsumerWidget {
  const _NotificationsTable({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final CommunicationsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<NotificationItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (!CommunicationsNotificationsAtomPermissions.listChrome.isAllowed(
      policy,
    )) {
      return const SizedBox.shrink();
    }
    final bool canWrite =
        CommunicationsNotificationsAtomPermissions.markRead.isAllowed(policy);
    final bool canDelete =
        CommunicationsNotificationsAtomPermissions.archive.isAllowed(policy);
    final bool canSelectRow =
        CommunicationsNotificationsAtomPermissions.rowSelect.isAllowed(policy);
    final AppLocalizations l10n = context.l10n;

    return AppListTable<NotificationItem>(
      page: state.notifications,
      isLoading: state.isRefreshingNotifications,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'communications_notifications',
      columnWidthStorageKey: 'communications_cw_notifications',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      search: _tableSearch<NotificationItem>(
        context,
        ref,
        state,
        searchController,
        matcher: _notificationSearchMatcher,
      ),
      itemKeyBuilder: (NotificationItem item) => ValueKey<String>(item.id),
      previousPageLabel: l10n.communicationsPreviousPageLabel,
      nextPageLabel: l10n.communicationsNextPageLabel,
      pageLabelBuilder: (AppPage<NotificationItem> page) {
        return _pageLabel(context, page);
      },
      onPageChanged: (AppPageRequest request) {
        unawaited(
          ref
              .read(communicationsWorkspaceControllerProvider.notifier)
              .changePage(request),
        );
      },
      onRowSelected: canSelectRow
          ? (NotificationItem item) {
              unawaited(
                showCommunicationsNotificationDetailDialog(
                  context,
                  ref,
                  state,
                  item,
                  canDelete: canDelete,
                ),
              );
            }
          : null,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.communicationsNoNotificationsTitle,
        body: l10n.communicationsNoNotificationsBody,
        icon: Icons.notifications_none_outlined,
      ),
      rowColorBuilder: (BuildContext context, NotificationItem item) {
        if (item.isRead) {
          return null;
        }
        return Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.18);
      },
      columns: <AppListTableColumn<NotificationItem>>[
        AppListTableColumn<NotificationItem>(
          id: 'alert',
          label: l10n.communicationsAlertColumnLabel,
          alwaysVisible: true,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareText(left.title, right.title),
          cellBuilder: (_, NotificationItem item) {
            return AppListItemText(title: item.title, subtitle: item.message);
          },
        ),
        AppListTableColumn<NotificationItem>(
          id: 'type',
          label: l10n.communicationsTypeColumnLabel,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareText(
                left.notificationType,
                right.notificationType,
              ),
          cellBuilder: (BuildContext context, NotificationItem item) {
            return Text(communicationsApiLabel(context, item.notificationType));
          },
        ),
        AppListTableColumn<NotificationItem>(
          id: 'time',
          label: l10n.communicationsTimeColumnLabel,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareDateTime(left.createdAt, right.createdAt),
          cellBuilder: (BuildContext context, NotificationItem item) {
            return Text(communicationsDateTimeLabel(context, item.createdAt));
          },
        ),
        AppListTableColumn<NotificationItem>(
          id: 'status',
          label: l10n.communicationsStateColumnLabel,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareText(
                communicationsReadStateLabel(context, left),
                communicationsReadStateLabel(context, right),
              ),
          cellBuilder: (BuildContext context, NotificationItem item) {
            return AppWorkspaceStatusBadge(
              status: communicationsReadStatus(context, item),
            );
          },
        ),
        AppListTableColumn<NotificationItem>(
          id: 'next_action',
          label: l10n.communicationsNextActionColumnLabel,
          alwaysVisible: true,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareText(
                _notificationNextActionLabel(context, left, canWrite),
                _notificationNextActionLabel(context, right, canWrite),
              ),
          cellBuilder: (BuildContext context, NotificationItem item) {
            return _NotificationNextActionCell(
              item: item,
              state: state,
              canWrite: canWrite,
              canDelete: canDelete,
            );
          },
        ),
      ],
      columnChoices: <AppListTableColumn<NotificationItem>>[
        AppListTableColumn<NotificationItem>(
          id: 'priority',
          label: l10n.communicationsPriorityColumnLabel,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareText(left.priority, right.priority),
          cellBuilder: (BuildContext context, NotificationItem item) {
            return AppWorkspaceStatusBadge(
              status: communicationsPriorityStatus(context, item.priority),
            );
          },
        ),
        AppListTableColumn<NotificationItem>(
          id: 'delivery_status',
          label: l10n.communicationsDeliveryStatusColumnLabel,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareText(
                left.effectiveDeliveryStatus,
                right.effectiveDeliveryStatus,
              ),
          cellBuilder: (BuildContext context, NotificationItem item) {
            return AppWorkspaceStatusBadge(
              status: communicationsDeliveryStatus(
                context,
                item.effectiveDeliveryStatus,
              ),
            );
          },
        ),
        AppListTableColumn<NotificationItem>(
          id: 'context',
          label: l10n.communicationsContextLabel,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareText(
                communicationsJoinDisplay(<String?>[
                  left.contextType,
                  left.contextPublicId,
                ]),
                communicationsJoinDisplay(<String?>[
                  right.contextType,
                  right.contextPublicId,
                ]),
              ),
          cellBuilder: (BuildContext context, NotificationItem item) {
            return Text(
              communicationsJoinDisplay(<String?>[
                    item.contextType,
                    item.contextPublicId,
                  ]) ??
                  context.l10n.profileUnknownValue,
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, NotificationItem item) {
        return AppListTableMobileItem(
          title: item.title,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: communicationsReadStatus(context, item).label,
            ),
            AppListTableMobileMeta(
              label: communicationsApiLabel(context, item.notificationType),
              icon: Icons.category_outlined,
            ),
            AppListTableMobileMeta(
              label: communicationsDateTimeLabel(context, item.createdAt),
              icon: Icons.schedule_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _DeliveriesTable extends ConsumerWidget {
  const _DeliveriesTable({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final CommunicationsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<NotificationDelivery>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (!CommunicationsDeliveriesAtomPermissions.listChrome.isAllowed(policy)) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = context.l10n;
    final bool canSelectRow =
        CommunicationsDeliveriesAtomPermissions.rowSelect.isAllowed(policy);
    final bool canShowNextAction =
        CommunicationsDeliveriesAtomPermissions.nextAction.isAllowed(policy);

    return AppListTable<NotificationDelivery>(
      page: state.deliveries,
      isLoading: state.isRefreshingDeliveries,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'communications_deliveries',
      columnWidthStorageKey: 'communications_cw_deliveries',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      search: _tableSearch<NotificationDelivery>(
        context,
        ref,
        state,
        searchController,
        matcher: _deliverySearchMatcher,
      ),
      itemKeyBuilder: (NotificationDelivery item) => ValueKey<String>(item.id),
      previousPageLabel: l10n.communicationsPreviousPageLabel,
      nextPageLabel: l10n.communicationsNextPageLabel,
      pageLabelBuilder: (AppPage<NotificationDelivery> page) {
        return _pageLabel(context, page);
      },
      onPageChanged: (AppPageRequest request) {
        unawaited(
          ref
              .read(communicationsWorkspaceControllerProvider.notifier)
              .changePage(request),
        );
      },
      onRowSelected: canSelectRow
          ? (NotificationDelivery item) {
              unawaited(
                showCommunicationsDeliveryDetailDialog(
                  context,
                  ref,
                  state,
                  item,
                ),
              );
            }
          : null,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.communicationsNoDeliveriesTitle,
        body: l10n.communicationsNoDeliveriesBody,
        icon: Icons.mark_email_read_outlined,
      ),
      columns: <AppListTableColumn<NotificationDelivery>>[
        AppListTableColumn<NotificationDelivery>(
          id: 'notification',
          label: l10n.communicationsNotificationColumnLabel,
          alwaysVisible: true,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareText(
                    left.notificationTitle,
                    right.notificationTitle,
                  ),
          cellBuilder: (_, NotificationDelivery item) {
            return AppListItemText(
              title: item.notificationTitle ?? context.l10n.profileUnknownValue,
              subtitle: item.errorMessage,
            );
          },
        ),
        AppListTableColumn<NotificationDelivery>(
          id: 'channel',
          label: l10n.communicationsChannelColumnLabel,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareText(left.channel, right.channel),
          cellBuilder: (BuildContext context, NotificationDelivery item) {
            return Text(communicationsApiLabel(context, item.channel));
          },
        ),
        AppListTableColumn<NotificationDelivery>(
          id: 'recipient',
          label: l10n.communicationsRecipientColumnLabel,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareText(
                    communicationsDeliveryRecipient(left),
                    communicationsDeliveryRecipient(right),
                  ),
          cellBuilder: (_, NotificationDelivery item) {
            return Text(communicationsDeliveryRecipient(item));
          },
        ),
        AppListTableColumn<NotificationDelivery>(
          id: 'status',
          label: l10n.communicationsStatusColumnLabel,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareText(left.status, right.status),
          cellBuilder: (BuildContext context, NotificationDelivery item) {
            return AppWorkspaceStatusBadge(
              status: communicationsDeliveryStatus(context, item.status),
            );
          },
        ),
        if (canShowNextAction)
          AppListTableColumn<NotificationDelivery>(
            id: 'next_action',
            label: l10n.communicationsNextActionColumnLabel,
            alwaysVisible: true,
            sortComparator:
                (NotificationDelivery left, NotificationDelivery right) =>
                    appListTableCompareNumber(
                      _deliveryNextActionLabel(context, left).length,
                      _deliveryNextActionLabel(context, right).length,
                    ),
            cellBuilder: (BuildContext context, NotificationDelivery item) {
              return _DeliveryNextActionCell(item: item, state: state);
            },
          ),
      ],
      columnChoices: <AppListTableColumn<NotificationDelivery>>[
        AppListTableColumn<NotificationDelivery>(
          id: 'attempts',
          label: l10n.communicationsAttemptsColumnLabel,
          numeric: true,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareNumber(
                    left.attemptCount,
                    right.attemptCount,
                  ),
          cellBuilder: (_, NotificationDelivery item) {
            return Text(item.attemptCount.toString());
          },
        ),
        AppListTableColumn<NotificationDelivery>(
          id: 'sent_at',
          label: l10n.communicationsSentAtLabel,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareDateTime(left.sentAt, right.sentAt),
          cellBuilder: (BuildContext context, NotificationDelivery item) {
            return Text(communicationsDateTimeLabel(context, item.sentAt));
          },
        ),
        AppListTableColumn<NotificationDelivery>(
          id: 'delivered_at',
          label: l10n.communicationsDeliveredAtLabel,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareDateTime(
                    left.deliveredAt,
                    right.deliveredAt,
                  ),
          cellBuilder: (BuildContext context, NotificationDelivery item) {
            return Text(communicationsDateTimeLabel(context, item.deliveredAt));
          },
        ),
        AppListTableColumn<NotificationDelivery>(
          id: 'failed_at',
          label: l10n.communicationsFailedAtLabel,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareDateTime(left.failedAt, right.failedAt),
          cellBuilder: (BuildContext context, NotificationDelivery item) {
            return Text(communicationsDateTimeLabel(context, item.failedAt));
          },
        ),
        AppListTableColumn<NotificationDelivery>(
          id: 'provider',
          label: l10n.communicationsProviderLabel,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareText(
                    left.providerName,
                    right.providerName,
                  ),
          cellBuilder: (BuildContext context, NotificationDelivery item) {
            return Text(item.providerName ?? context.l10n.profileUnknownValue);
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, NotificationDelivery item) {
        return AppListTableMobileItem(
          title: item.notificationTitle ?? context.l10n.profileUnknownValue,
          caption: communicationsDeliveryRecipient(item),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: communicationsDeliveryStatus(context, item.status).label,
            ),
            AppListTableMobileMeta(
              label: communicationsApiLabel(context, item.channel),
              icon: Icons.send_outlined,
            ),
          ],
          showAvatar: false,
        );
      },
    );
  }
}

class _TemplatesTable extends ConsumerWidget {
  const _TemplatesTable({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final CommunicationsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<CommunicationTemplate>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    // Search / Filters / Settings / pagination share listChrome (read ∩).
    if (!CommunicationsTemplatesAtomPermissions.listChrome.isAllowed(policy) ||
        !CommunicationsTemplatesAtomPermissions.search.isAllowed(policy)) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = context.l10n;
    final bool canSelectRow =
        CommunicationsTemplatesAtomPermissions.rowSelect.isAllowed(policy) &&
        CommunicationsTemplatesAtomPermissions.view.isAllowed(policy);

    return AppListTable<CommunicationTemplate>(
      page: state.templates,
      isLoading: state.isRefreshingTemplates,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'communications_templates',
      columnWidthStorageKey: 'communications_cw_templates',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      search: _tableSearch<CommunicationTemplate>(
        context,
        ref,
        state,
        searchController,
        matcher: _templateSearchMatcher,
      ),
      itemKeyBuilder: (CommunicationTemplate item) => ValueKey<String>(item.id),
      previousPageLabel: l10n.communicationsPreviousPageLabel,
      nextPageLabel: l10n.communicationsNextPageLabel,
      pageLabelBuilder: (AppPage<CommunicationTemplate> page) {
        return _pageLabel(context, page);
      },
      onPageChanged:
          CommunicationsTemplatesAtomPermissions.pagination.isAllowed(policy)
          ? (AppPageRequest request) {
              unawaited(
                ref
                    .read(communicationsWorkspaceControllerProvider.notifier)
                    .changePage(request),
              );
            }
          : null,
      onRowSelected: canSelectRow
          ? (CommunicationTemplate item) {
              unawaited(
                showCommunicationsTemplateDetailDialog(
                  context,
                  ref,
                  state,
                  item,
                ),
              );
            }
          : null,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.communicationsNoTemplatesTitle,
        body: l10n.communicationsNoTemplatesBody,
        icon: Icons.description_outlined,
      ),
      columns: <AppListTableColumn<CommunicationTemplate>>[
        AppListTableColumn<CommunicationTemplate>(
          id: 'template',
          label: l10n.communicationsTemplateColumnLabel,
          alwaysVisible: true,
          sortComparator:
              (CommunicationTemplate left, CommunicationTemplate right) =>
                  appListTableCompareText(left.name, right.name),
          cellBuilder: (_, CommunicationTemplate item) {
            return AppListItemText(
              title: item.name,
              subtitle: item.description,
            );
          },
        ),
        AppListTableColumn<CommunicationTemplate>(
          id: 'channel',
          label: l10n.communicationsChannelColumnLabel,
          sortComparator:
              (CommunicationTemplate left, CommunicationTemplate right) =>
                  appListTableCompareText(left.channel, right.channel),
          cellBuilder: (BuildContext context, CommunicationTemplate item) {
            return Text(communicationsApiLabel(context, item.channel));
          },
        ),
        AppListTableColumn<CommunicationTemplate>(
          id: 'state',
          label: l10n.communicationsStateColumnLabel,
          sortComparator:
              (CommunicationTemplate left, CommunicationTemplate right) =>
                  appListTableCompareText(
                    left.isActive.toString(),
                    right.isActive.toString(),
                  ),
          cellBuilder: (BuildContext context, CommunicationTemplate item) {
            return AppWorkspaceStatusBadge(
              status: communicationsTemplateStatus(context, item),
            );
          },
        ),
        AppListTableColumn<CommunicationTemplate>(
          id: 'variables',
          label: l10n.communicationsVariablesColumnLabel,
          numeric: true,
          sortComparator:
              (CommunicationTemplate left, CommunicationTemplate right) =>
                  appListTableCompareNumber(
                    left.variableCount,
                    right.variableCount,
                  ),
          cellBuilder: (_, CommunicationTemplate item) {
            return Text(item.variableCount.toString());
          },
        ),
      ],
      columnChoices: <AppListTableColumn<CommunicationTemplate>>[
        AppListTableColumn<CommunicationTemplate>(
          id: 'subject',
          label: l10n.communicationsSubjectLabel,
          sortComparator:
              (CommunicationTemplate left, CommunicationTemplate right) =>
                  appListTableCompareText(left.subject, right.subject),
          cellBuilder: (BuildContext context, CommunicationTemplate item) {
            return Text(item.subject ?? context.l10n.profileUnknownValue);
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, CommunicationTemplate item) {
        return AppListTableMobileItem(
          title: item.name,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: communicationsTemplateStatus(context, item).label,
            ),
            AppListTableMobileMeta(
              label: communicationsApiLabel(context, item.channel),
              icon: Icons.send_outlined,
            ),
            if (item.variableCount > 0)
              AppListTableMobileMeta(
                label: item.variableCount.toString(),
                icon: Icons.dynamic_form_outlined,
              ),
          ],
          showAvatar: false,
        );
      },
    );
  }
}

AppListTableSearch<T> _tableSearch<T>(
  BuildContext context,
  WidgetRef ref,
  CommunicationsWorkspaceState state,
  TextEditingController controller, {
  required AppListTableSearchMatcher<T> matcher,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableSearch<T>(
    controller: controller,
    semanticLabel: l10n.communicationsSearchSemanticLabel,
    hintText: l10n.communicationsSearchHint,
    clearLabel: l10n.communicationsClearSearchAction,
    matcher: matcher,
    onSubmitted: (String value) {
      ref
          .read(communicationsWorkspaceControllerProvider.notifier)
          .applySearch(value);
    },
    onClear: () {
      ref
          .read(communicationsWorkspaceControllerProvider.notifier)
          .applySearch('');
    },
    showAdvancedFilterButton: true,
    advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
    advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
    advancedFilterApplyLabel: l10n.communicationsApplyFiltersAction,
    advancedFilterResetLabel: l10n.communicationsResetFiltersAction,
    enableDateFilter: false,
    allFieldsLabel: _panelTitle(l10n, state.query.panel),
    filterGroups: _filterGroups(context, state),
    filterValue: _filterValue(state.query),
    hasActiveFilters: state.query.hasActiveFilters,
    onFilterChanged: (AppSearchBarFilterValue value) {
      final String? flag = value.option(_flagFilterKey);
      ref
          .read(communicationsWorkspaceControllerProvider.notifier)
          .applyFilter(
            filter: value.option(_queueFilterKey),
            unreadOnly: flag == _unreadFlagValue,
            sensitive: flag == _sensitiveFlagValue,
          );
    },
  );
}

class _NotificationNextActionCell extends ConsumerWidget {
  const _NotificationNextActionCell({
    required this.item,
    required this.state,
    required this.canWrite,
    required this.canDelete,
  });

  final NotificationItem item;
  final CommunicationsWorkspaceState state;
  final bool canWrite;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (!CommunicationsNotificationsAtomPermissions.nextAction.isAllowed(
      policy,
    )) {
      return const SizedBox.shrink();
    }
    final bool markAllowed =
        canWrite &&
        CommunicationsNotificationsAtomPermissions.markRead.isAllowed(policy);
    final String label = _notificationNextActionLabel(
      context,
      item,
      markAllowed,
    );
    return AppButton.tertiary(
      label: label,
      enabled: !state.isSaving,
      onPressed: () {
        if (markAllowed) {
          unawaited(_handleNotificationNextAction(context, ref, item));
          return;
        }
        unawaited(
          showCommunicationsNotificationDetailDialog(
            context,
            ref,
            state,
            item,
            canDelete: canDelete,
          ),
        );
      },
    );
  }
}

String _notificationNextActionLabel(
  BuildContext context,
  NotificationItem item,
  bool canWrite,
) {
  if (!canWrite) {
    return context.l10n.communicationsViewNotificationAction;
  }
  return item.isRead
      ? context.l10n.communicationsMarkUnreadAction
      : context.l10n.communicationsMarkReadAction;
}

Future<void> _handleNotificationNextAction(
  BuildContext context,
  WidgetRef ref,
  NotificationItem item,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  // Mark read/unread share write ∩; deny must not mount a mutation path.
  if (!CommunicationsNotificationsAtomPermissions.markRead.isAllowed(policy)) {
    return;
  }
  final CommunicationsWorkspaceController controller = ref.read(
    communicationsWorkspaceControllerProvider.notifier,
  );
  controller.selectNotification(item);
  // Mark read/unread is non-destructive — skip confirm (inventory).
  final AppFailure? failure = item.isRead
      ? await controller.markSelectedNotificationUnread()
      : await controller.markSelectedNotificationRead();
  if (!context.mounted) {
    return;
  }
  if (failure == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.communicationsActionSavedMessage)),
    );
    return;
  }
  _showFailureIfNeeded(context, failure);
}

class _DeliveryNextActionCell extends ConsumerWidget {
  const _DeliveryNextActionCell({required this.item, required this.state});

  final NotificationDelivery item;
  final CommunicationsWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (!CommunicationsDeliveriesAtomPermissions.nextAction.isAllowed(policy)) {
      return const SizedBox.shrink();
    }
    final String? path = communicationsInternalPath(item.targetPath);
    return AppButton.tertiary(
      label: _deliveryNextActionLabel(context, item),
      onPressed: path != null
          ? () => context.go(path)
          : () => unawaited(
              showCommunicationsDeliveryDetailDialog(context, ref, state, item),
            ),
    );
  }
}

String _deliveryNextActionLabel(
  BuildContext context,
  NotificationDelivery item,
) {
  if (communicationsInternalPath(item.targetPath) != null) {
    return context.l10n.communicationsOpenLinkedRecordAction;
  }
  final String status = (item.status ?? '').trim().toUpperCase();
  if (<String>{'FAILED', 'BOUNCED', 'ERROR'}.contains(status)) {
    return context.l10n.communicationsViewDeliveryErrorAction;
  }
  return context.l10n.communicationsViewDeliveryAction;
}

bool _notificationSearchMatcher(NotificationItem item, String query) {
  return _matchesQuery(query, <String?>[
    item.title,
    item.message,
    item.notificationType,
    item.priority,
    item.contextType,
    item.contextPublicId,
    item.deliveryStatus,
    for (final NotificationDelivery delivery in item.deliveries) ...<String?>[
      delivery.status,
      delivery.channel,
      delivery.providerName,
      delivery.errorMessage,
      delivery.recipientTarget,
    ],
  ]);
}

bool _deliverySearchMatcher(NotificationDelivery item, String query) {
  return _matchesQuery(query, <String?>[
    item.notificationTitle,
    item.errorMessage,
    item.channel,
    item.status,
    item.providerName,
    item.recipientTarget,
    item.recipient?.displayName,
    item.attemptCount.toString(),
  ]);
}

bool _templateSearchMatcher(CommunicationTemplate item, String query) {
  return _matchesQuery(query, <String?>[
    item.name,
    item.description,
    item.channel,
    item.subject,
    item.previewSubject,
    item.previewBody,
    item.body,
    item.variableCount.toString(),
    item.isActive ? 'active' : 'inactive',
  ]);
}

bool _matchesQuery(String query, Iterable<String?> values) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  for (final String? value in values) {
    final String normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.contains(needle)) {
      return true;
    }
  }
  return false;
}

List<AppSearchBarFilterGroup> _filterGroups(
  BuildContext context,
  CommunicationsWorkspaceState state,
) {
  final AppLocalizations l10n = context.l10n;
  final List<CommunicationsQueueSummary> queues = state.queueSummaries
      .where(
        (CommunicationsQueueSummary item) => item.panel == state.query.panel,
      )
      .toList(growable: false);

  return <AppSearchBarFilterGroup>[
    if (queues.isNotEmpty)
      AppSearchBarFilterGroup(
        key: _queueFilterKey,
        label: l10n.communicationsQueueFilterLabel,
        allLabel: l10n.communicationsAllFilterLabel,
        choices: <AppSearchBarFilterChoice>[
          for (final CommunicationsQueueSummary queue in queues)
            AppSearchBarFilterChoice(
              value: queue.filter ?? queue.id,
              label: queue.label,
              icon: _panelIcon(queue.panel),
            ),
        ],
      ),
    AppSearchBarFilterGroup(
      key: _flagFilterKey,
      label: l10n.communicationsFlagsFilterLabel,
      allLabel: l10n.communicationsAllFilterLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: _unreadFlagValue,
          label: l10n.communicationsUnreadFilterLabel,
          icon: Icons.mark_email_unread_outlined,
        ),
        AppSearchBarFilterChoice(
          value: _sensitiveFlagValue,
          label: l10n.communicationsSensitiveFilterLabel,
          icon: Icons.privacy_tip_outlined,
        ),
      ],
    ),
  ];
}

AppSearchBarFilterValue _filterValue(CommunicationsWorkspaceQuery query) {
  return AppSearchBarFilterValue(
    options: <String, String>{
      if (query.filter != null) _queueFilterKey: query.filter!,
      if (query.unreadOnly) _flagFilterKey: _unreadFlagValue,
      if (query.sensitive) _flagFilterKey: _sensitiveFlagValue,
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

int _panelCount(CommunicationsWorkspaceState state, CommunicationsPanel panel) {
  return switch (panel) {
    CommunicationsPanel.inbox => state.conversations.items.length,
    CommunicationsPanel.notifications =>
      state.notifications.totalItemCount ?? state.notifications.items.length,
    CommunicationsPanel.deliveries =>
      state.deliveries.totalItemCount ?? state.deliveries.items.length,
    CommunicationsPanel.templates =>
      state.templates.totalItemCount ?? state.templates.items.length,
  };
}

String _panelTitle(AppLocalizations l10n, CommunicationsPanel panel) {
  return switch (panel) {
    CommunicationsPanel.inbox => l10n.communicationsMessagesPanelLabel,
    CommunicationsPanel.notifications =>
      l10n.communicationsNotificationsPanelLabel,
    CommunicationsPanel.deliveries => l10n.communicationsDeliveriesPanelLabel,
    CommunicationsPanel.templates => l10n.communicationsTemplatesPanelLabel,
  };
}

IconData _panelIcon(CommunicationsPanel panel) {
  return switch (panel) {
    CommunicationsPanel.inbox => Icons.forum_outlined,
    CommunicationsPanel.notifications => Icons.notifications_none_outlined,
    CommunicationsPanel.deliveries => Icons.mark_email_read_outlined,
    CommunicationsPanel.templates => Icons.description_outlined,
  };
}

String _pageLabel<T>(BuildContext context, AppPage<T> page) {
  final int total = page.totalItemCount ?? page.items.length;
  return context.l10n.communicationsPageLabel(
    page.firstItemNumber,
    page.lastItemNumber,
    total,
  );
}

bool _hasRouteQuery(CommunicationsWorkspaceQuery query) {
  return query.panel != CommunicationsPanel.inbox ||
      query.hasActiveFilters ||
      query.conversationId != null;
}

String _querySignature(CommunicationsWorkspaceQuery query) {
  return <Object?>[
    query.panel.serverValue,
    query.search,
    query.filter,
    query.conversationId,
    query.messageId,
    query.notificationId,
    query.templateId,
    query.action,
    query.unreadOnly,
    query.sensitive,
  ].join(_signatureSeparator);
}

const String _queueFilterKey = 'queue';
const String _flagFilterKey = 'flag';
const String _unreadFlagValue = 'unread';
const String _sensitiveFlagValue = 'sensitive';
const String _signatureSeparator = '::';
