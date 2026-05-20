import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class CommunicationsWorkspacePage extends ConsumerStatefulWidget {
  const CommunicationsWorkspacePage({required this.initialQuery, super.key});

  final CommunicationsWorkspaceQuery initialQuery;

  @override
  ConsumerState<CommunicationsWorkspacePage> createState() =>
      _CommunicationsWorkspacePageState();
}

class _CommunicationsWorkspacePageState
    extends ConsumerState<CommunicationsWorkspacePage> {
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant CommunicationsWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_querySignature(oldWidget.initialQuery) !=
        _querySignature(widget.initialQuery)) {
      _scheduleRouteQuery(widget.initialQuery);
    }
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
      ref
          .read(communicationsWorkspaceControllerProvider.notifier)
          .applyRouteQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
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
        return _CommunicationsWorkspaceContent(state: state);
      },
    );
  }
}

class _CommunicationsWorkspaceContent extends ConsumerStatefulWidget {
  const _CommunicationsWorkspaceContent({required this.state});

  final CommunicationsWorkspaceState state;

  @override
  ConsumerState<_CommunicationsWorkspaceContent> createState() =>
      _CommunicationsWorkspaceContentState();
}

class _CommunicationsWorkspaceContentState
    extends ConsumerState<_CommunicationsWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<CommunicationsConversation>
  _conversationColumns;
  late final AppListTableColumnVisibilityController<NotificationItem>
  _notificationColumns;
  late final AppListTableColumnVisibilityController<NotificationDelivery>
  _deliveryColumns;
  late final AppListTableColumnVisibilityController<CommunicationTemplate>
  _templateColumns;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _conversationColumns =
        AppListTableColumnVisibilityController<CommunicationsConversation>();
    _notificationColumns =
        AppListTableColumnVisibilityController<NotificationItem>();
    _deliveryColumns =
        AppListTableColumnVisibilityController<NotificationDelivery>();
    _templateColumns =
        AppListTableColumnVisibilityController<CommunicationTemplate>();
  }

  @override
  void didUpdateWidget(covariant _CommunicationsWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextSearch = widget.state.query.search;
    if (oldWidget.state.query.search != nextSearch &&
        _searchController.text != nextSearch) {
      _searchController.text = nextSearch;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _conversationColumns.dispose();
    _notificationColumns.dispose();
    _deliveryColumns.dispose();
    _templateColumns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CommunicationsWorkspaceState state = widget.state;
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = policy.grants(AppPermissions.communicationsWrite);
    final Object? lastFailure = state.lastFailure;

    return AppWorkspace(
      title: l10n.communicationsWorkspaceTitle,
      leadingIcon: AppRouteIcons.communications,
      compactSummaryCards: true,
      status: AppWorkspaceStatus(
        label: state.isSaving
            ? l10n.communicationsSavingStatus
            : l10n.communicationsLiveStatus,
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: state.isSaving ? Icons.sync_outlined : Icons.notifications_active,
      ),
      secondaryActions: <Widget>[
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading: state.isRefreshing,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      summaryCards: _summaryCards(context, state, controller),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (lastFailure is AppFailure) ...<Widget>[
            AppFailureStateView(
              failure: lastFailure,
              onRetry: controller.refresh,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          _CommunicationsListPanel(
            state: state,
            searchController: _searchController,
            conversationColumns: _conversationColumns,
            notificationColumns: _notificationColumns,
            deliveryColumns: _deliveryColumns,
            templateColumns: _templateColumns,
          ),
        ],
      ),
      detail: _CommunicationsDetailPanel(state: state, canWrite: canWrite),
    );
  }

  List<Widget> _summaryCards(
    BuildContext context,
    CommunicationsWorkspaceState state,
    CommunicationsWorkspaceController controller,
  ) {
    final Locale locale = Localizations.localeOf(context);
    final AppLocalizations l10n = context.l10n;

    return <Widget>[
      AppWorkspaceSummaryCard(
        label: l10n.communicationsUnreadThreadsSummaryLabel,
        value: AppFormatters.compactNumber(state.summary.unreadThreads, locale),
        icon: Icons.mark_chat_unread_outlined,
        tone: state.summary.unreadThreads > 0
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.neutral,
        compact: true,
        onPressed: () {
          controller.applyPanel(CommunicationsPanel.inbox);
          controller.applyFilter(unreadOnly: true);
        },
      ),
      AppWorkspaceSummaryCard(
        label: l10n.communicationsUnreadNotificationsSummaryLabel,
        value: AppFormatters.compactNumber(state.metrics.unread, locale),
        icon: Icons.notifications_active_outlined,
        tone: state.metrics.unread > 0
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.neutral,
        compact: true,
        onPressed: () {
          controller.applyPanel(CommunicationsPanel.notifications);
          controller.applyFilter(unreadOnly: true);
        },
      ),
      AppWorkspaceSummaryCard(
        label: l10n.communicationsFailedDeliveriesSummaryLabel,
        value: AppFormatters.compactNumber(
          state.metrics.failedDeliveries,
          locale,
        ),
        icon: Icons.error_outline,
        tone: state.metrics.failedDeliveries > 0
            ? AppWorkspaceStatusTone.error
            : AppWorkspaceStatusTone.neutral,
        compact: true,
        onPressed: () {
          controller.applyPanel(CommunicationsPanel.deliveries);
          controller.applyFilter(filter: _failedFilterValue);
        },
      ),
      AppWorkspaceSummaryCard(
        label: l10n.communicationsTemplatesSummaryLabel,
        value: AppFormatters.compactNumber(state.summary.templates, locale),
        icon: Icons.description_outlined,
        compact: true,
        onPressed: () => controller.applyPanel(CommunicationsPanel.templates),
      ),
    ];
  }
}

class _CommunicationsListPanel extends ConsumerWidget {
  const _CommunicationsListPanel({
    required this.state,
    required this.searchController,
    required this.conversationColumns,
    required this.notificationColumns,
    required this.deliveryColumns,
    required this.templateColumns,
  });

  final CommunicationsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<CommunicationsConversation>
  conversationColumns;
  final AppListTableColumnVisibilityController<NotificationItem>
  notificationColumns;
  final AppListTableColumnVisibilityController<NotificationDelivery>
  deliveryColumns;
  final AppListTableColumnVisibilityController<CommunicationTemplate>
  templateColumns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    return AppWorkspaceDetailPanel(
      title: _panelTitle(l10n, state.query.panel),
      description: l10n.communicationsListDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelSelector(selected: state.query.panel),
          SizedBox(height: Theme.of(context).spacing.sm),
          _tableForPanel(context, ref),
        ],
      ),
    );
  }

  Widget _tableForPanel(BuildContext context, WidgetRef ref) {
    return switch (state.query.panel) {
      CommunicationsPanel.inbox => _ConversationsTable(
        state: state,
        searchController: searchController,
        columnVisibilityController: conversationColumns,
      ),
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

class _PanelSelector extends ConsumerWidget {
  const _PanelSelector({required this.selected});

  final CommunicationsPanel selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );

    return Wrap(
      spacing: Theme.of(context).spacing.xs,
      runSpacing: Theme.of(context).spacing.xs,
      children: <Widget>[
        for (final CommunicationsPanel panel in CommunicationsPanel.values)
          AppButton(
            label: _panelTitle(l10n, panel),
            leadingIcon: _panelIcon(panel),
            variant: selected == panel
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            onPressed: selected == panel
                ? null
                : () => controller.applyPanel(panel),
          ),
      ],
    );
  }
}

class _ConversationsTable extends ConsumerWidget {
  const _ConversationsTable({
    required this.state,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final CommunicationsWorkspaceState state;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<CommunicationsConversation>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );

    return AppListTable<CommunicationsConversation>(
      page: state.conversations,
      isLoading: state.isRefreshing,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      search: _tableSearch<CommunicationsConversation>(
        context,
        ref,
        state,
        searchController,
      ),
      itemKeyBuilder: (CommunicationsConversation item) =>
          ValueKey<String>(item.id),
      previousPageLabel: l10n.communicationsPreviousPageLabel,
      nextPageLabel: l10n.communicationsNextPageLabel,
      pageLabelBuilder: (AppPage<CommunicationsConversation> page) {
        return _pageLabel(context, page);
      },
      onPageChanged: controller.changePage,
      onRowSelected: controller.selectConversation,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.communicationsNoConversationsTitle,
        body: l10n.communicationsNoConversationsBody,
        icon: Icons.forum_outlined,
      ),
      columns: <AppListTableColumn<CommunicationsConversation>>[
        AppListTableColumn<CommunicationsConversation>(
          label: l10n.communicationsThreadColumnLabel,
          sortComparator:
              (
                CommunicationsConversation left,
                CommunicationsConversation right,
              ) => appListTableCompareText(left.title, right.title),
          cellBuilder: (_, CommunicationsConversation item) {
            return AppListItemText(title: item.title, subtitle: item.preview);
          },
        ),
        AppListTableColumn<CommunicationsConversation>(
          label: l10n.communicationsParticipantsColumnLabel,
          sortComparator:
              (
                CommunicationsConversation left,
                CommunicationsConversation right,
              ) => appListTableCompareNumber(
                left.participants.length,
                right.participants.length,
              ),
          cellBuilder: (BuildContext context, CommunicationsConversation item) {
            return Text(_participantsLabel(context, item.participants));
          },
        ),
        AppListTableColumn<CommunicationsConversation>(
          label: l10n.communicationsStatusColumnLabel,
          sortComparator:
              (
                CommunicationsConversation left,
                CommunicationsConversation right,
              ) => appListTableCompareText(left.status, right.status),
          cellBuilder: (BuildContext context, CommunicationsConversation item) {
            return AppWorkspaceStatusBadge(
              status: _conversationStatus(context, item),
            );
          },
        ),
        AppListTableColumn<CommunicationsConversation>(
          label: l10n.communicationsLastMessageColumnLabel,
          sortComparator:
              (
                CommunicationsConversation left,
                CommunicationsConversation right,
              ) => appListTableCompareText(left.preview, right.preview),
          cellBuilder: (_, CommunicationsConversation item) {
            return Text(item.preview);
          },
        ),
        AppListTableColumn<CommunicationsConversation>(
          label: l10n.communicationsTimeColumnLabel,
          sortComparator:
              (
                CommunicationsConversation left,
                CommunicationsConversation right,
              ) => appListTableCompareDateTime(
                left.lastMessageAt,
                right.lastMessageAt,
              ),
          cellBuilder: (BuildContext context, CommunicationsConversation item) {
            return Text(_dateTimeLabel(context, item.lastMessageAt));
          },
        ),
      ],
      mobileItemBuilder:
          (BuildContext context, CommunicationsConversation item) {
            return AppListItemRow(
              title: item.title,
              subtitle: item.preview,
              leadingIcon: item.unread
                  ? Icons.mark_chat_unread_outlined
                  : Icons.forum_outlined,
              details: <Widget>[
                Wrap(
                  spacing: Theme.of(context).spacing.xs,
                  runSpacing: Theme.of(context).spacing.xs,
                  children: <Widget>[
                    AppWorkspaceStatusBadge(
                      status: _conversationStatus(context, item),
                    ),
                    AppInlineMetaText(
                      icon: Icons.schedule_outlined,
                      label: _dateTimeLabel(context, item.lastMessageAt),
                    ),
                  ],
                ),
              ],
            );
          },
    );
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
    final AppLocalizations l10n = context.l10n;
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );

    return AppListTable<NotificationItem>(
      page: state.notifications,
      isLoading: state.isRefreshing,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      search: _tableSearch<NotificationItem>(
        context,
        ref,
        state,
        searchController,
      ),
      itemKeyBuilder: (NotificationItem item) => ValueKey<String>(item.id),
      previousPageLabel: l10n.communicationsPreviousPageLabel,
      nextPageLabel: l10n.communicationsNextPageLabel,
      pageLabelBuilder: (AppPage<NotificationItem> page) {
        return _pageLabel(context, page);
      },
      onPageChanged: controller.changePage,
      onRowSelected: controller.selectNotification,
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
          label: l10n.communicationsAlertColumnLabel,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareText(left.title, right.title),
          cellBuilder: (_, NotificationItem item) {
            return AppListItemText(title: item.title, subtitle: item.message);
          },
        ),
        AppListTableColumn<NotificationItem>(
          label: l10n.communicationsTypeColumnLabel,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareText(
                left.notificationType,
                right.notificationType,
              ),
          cellBuilder: (BuildContext context, NotificationItem item) {
            return Text(_apiLabel(context, item.notificationType));
          },
        ),
        AppListTableColumn<NotificationItem>(
          label: l10n.communicationsPriorityColumnLabel,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareText(left.priority, right.priority),
          cellBuilder: (BuildContext context, NotificationItem item) {
            return AppWorkspaceStatusBadge(
              status: _priorityStatus(context, item.priority),
            );
          },
        ),
        AppListTableColumn<NotificationItem>(
          label: l10n.communicationsStateColumnLabel,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareText(
                _readStateLabel(context, left),
                _readStateLabel(context, right),
              ),
          cellBuilder: (BuildContext context, NotificationItem item) {
            return AppWorkspaceStatusBadge(status: _readStatus(context, item));
          },
        ),
        AppListTableColumn<NotificationItem>(
          label: l10n.communicationsTimeColumnLabel,
          sortComparator: (NotificationItem left, NotificationItem right) =>
              appListTableCompareDateTime(left.createdAt, right.createdAt),
          cellBuilder: (BuildContext context, NotificationItem item) {
            return Text(_dateTimeLabel(context, item.createdAt));
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, NotificationItem item) {
        return AppListItemRow(
          title: item.title,
          subtitle: item.message,
          leadingIcon: item.isRead
              ? Icons.notifications_none_outlined
              : Icons.notifications_active_outlined,
          details: <Widget>[
            Wrap(
              spacing: Theme.of(context).spacing.xs,
              runSpacing: Theme.of(context).spacing.xs,
              children: <Widget>[
                AppWorkspaceStatusBadge(
                  status: _priorityStatus(context, item.priority),
                ),
                AppWorkspaceStatusBadge(status: _readStatus(context, item)),
              ],
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
    final AppLocalizations l10n = context.l10n;
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );

    return AppListTable<NotificationDelivery>(
      page: state.deliveries,
      isLoading: state.isRefreshing,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      search: _tableSearch<NotificationDelivery>(
        context,
        ref,
        state,
        searchController,
      ),
      itemKeyBuilder: (NotificationDelivery item) => ValueKey<String>(item.id),
      previousPageLabel: l10n.communicationsPreviousPageLabel,
      nextPageLabel: l10n.communicationsNextPageLabel,
      pageLabelBuilder: (AppPage<NotificationDelivery> page) {
        return _pageLabel(context, page);
      },
      onPageChanged: controller.changePage,
      onRowSelected: controller.selectDelivery,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.communicationsNoDeliveriesTitle,
        body: l10n.communicationsNoDeliveriesBody,
        icon: Icons.mark_email_read_outlined,
      ),
      columns: <AppListTableColumn<NotificationDelivery>>[
        AppListTableColumn<NotificationDelivery>(
          label: l10n.communicationsNotificationColumnLabel,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareText(
                    left.notificationTitle,
                    right.notificationTitle,
                  ),
          cellBuilder: (_, NotificationDelivery item) {
            return AppListItemText(
              title: item.notificationTitle ?? item.id,
              subtitle: item.errorMessage,
            );
          },
        ),
        AppListTableColumn<NotificationDelivery>(
          label: l10n.communicationsChannelColumnLabel,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareText(left.channel, right.channel),
          cellBuilder: (BuildContext context, NotificationDelivery item) {
            return Text(_apiLabel(context, item.channel));
          },
        ),
        AppListTableColumn<NotificationDelivery>(
          label: l10n.communicationsRecipientColumnLabel,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareText(
                    _deliveryRecipient(left),
                    _deliveryRecipient(right),
                  ),
          cellBuilder: (_, NotificationDelivery item) {
            return Text(_deliveryRecipient(item));
          },
        ),
        AppListTableColumn<NotificationDelivery>(
          label: l10n.communicationsStatusColumnLabel,
          sortComparator:
              (NotificationDelivery left, NotificationDelivery right) =>
                  appListTableCompareText(left.status, right.status),
          cellBuilder: (BuildContext context, NotificationDelivery item) {
            return AppWorkspaceStatusBadge(
              status: _deliveryStatus(context, item.status),
            );
          },
        ),
        AppListTableColumn<NotificationDelivery>(
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
      ],
      mobileItemBuilder: (BuildContext context, NotificationDelivery item) {
        return AppListItemRow(
          title: item.notificationTitle ?? item.id,
          subtitle: _deliveryRecipient(item),
          leadingIcon: Icons.mark_email_read_outlined,
          details: <Widget>[
            Wrap(
              spacing: Theme.of(context).spacing.xs,
              runSpacing: Theme.of(context).spacing.xs,
              children: <Widget>[
                AppWorkspaceStatusBadge(
                  status: _deliveryStatus(context, item.status),
                ),
                AppInlineMetaText(
                  icon: Icons.send_outlined,
                  label: _apiLabel(context, item.channel),
                ),
              ],
            ),
          ],
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
    final AppLocalizations l10n = context.l10n;
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );

    return AppListTable<CommunicationTemplate>(
      page: state.templates,
      isLoading: state.isRefreshing,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      search: _tableSearch<CommunicationTemplate>(
        context,
        ref,
        state,
        searchController,
      ),
      itemKeyBuilder: (CommunicationTemplate item) => ValueKey<String>(item.id),
      previousPageLabel: l10n.communicationsPreviousPageLabel,
      nextPageLabel: l10n.communicationsNextPageLabel,
      pageLabelBuilder: (AppPage<CommunicationTemplate> page) {
        return _pageLabel(context, page);
      },
      onPageChanged: controller.changePage,
      onRowSelected: controller.selectTemplate,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.communicationsNoTemplatesTitle,
        body: l10n.communicationsNoTemplatesBody,
        icon: Icons.description_outlined,
      ),
      columns: <AppListTableColumn<CommunicationTemplate>>[
        AppListTableColumn<CommunicationTemplate>(
          label: l10n.communicationsTemplateColumnLabel,
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
          label: l10n.communicationsChannelColumnLabel,
          sortComparator:
              (CommunicationTemplate left, CommunicationTemplate right) =>
                  appListTableCompareText(left.channel, right.channel),
          cellBuilder: (BuildContext context, CommunicationTemplate item) {
            return Text(_apiLabel(context, item.channel));
          },
        ),
        AppListTableColumn<CommunicationTemplate>(
          label: l10n.communicationsStateColumnLabel,
          sortComparator:
              (CommunicationTemplate left, CommunicationTemplate right) =>
                  appListTableCompareText(
                    left.isActive.toString(),
                    right.isActive.toString(),
                  ),
          cellBuilder: (BuildContext context, CommunicationTemplate item) {
            return AppWorkspaceStatusBadge(
              status: _templateStatus(context, item),
            );
          },
        ),
        AppListTableColumn<CommunicationTemplate>(
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
      mobileItemBuilder: (BuildContext context, CommunicationTemplate item) {
        return AppListItemRow(
          title: item.name,
          subtitle: item.description,
          leadingIcon: Icons.description_outlined,
          details: <Widget>[
            Wrap(
              spacing: Theme.of(context).spacing.xs,
              runSpacing: Theme.of(context).spacing.xs,
              children: <Widget>[
                AppWorkspaceStatusBadge(status: _templateStatus(context, item)),
                AppInlineMetaText(
                  icon: Icons.dynamic_form_outlined,
                  label: item.variableCount.toString(),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CommunicationsDetailPanel extends ConsumerWidget {
  const _CommunicationsDetailPanel({
    required this.state,
    required this.canWrite,
  });

  final CommunicationsWorkspaceState state;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state.query.panel) {
      CommunicationsPanel.inbox => _conversationDetail(context, ref),
      CommunicationsPanel.notifications => _notificationDetail(context, ref),
      CommunicationsPanel.deliveries => _deliveryDetail(context),
      CommunicationsPanel.templates => _templateDetail(context),
    };
  }

  Widget _conversationDetail(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final CommunicationsConversation? conversation = state.selectedConversation;
    if (conversation == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.communicationsConversationDetailTitle,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.communicationsNoConversationSelectedTitle,
          body: l10n.communicationsNoConversationSelectedBody,
          icon: Icons.forum_outlined,
          minHeight: 220,
        ),
      );
    }

    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );
    return AppWorkspaceDetailPanel(
      title: l10n.communicationsConversationDetailTitle,
      actions: <Widget>[
        if (canWrite && conversation.unread)
          AppButton.secondary(
            label: l10n.communicationsMarkReadAction,
            leadingIcon: Icons.mark_chat_read_outlined,
            enabled: !state.isSaving,
            onPressed: () => _confirmAction(
              context,
              title: l10n.communicationsMarkReadDialogTitle,
              body: l10n.communicationsMarkConversationReadDialogBody,
              submitLabel: l10n.communicationsMarkReadAction,
              icon: const Icon(Icons.mark_chat_read_outlined),
              onConfirm: controller.markSelectedConversationRead,
            ),
          ),
        if (canWrite)
          AppButton.primary(
            label: l10n.communicationsSendMessageAction,
            leadingIcon: Icons.send_outlined,
            enabled: !state.isSaving,
            onPressed: () => _sendMessage(context, controller),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppWorkspaceStatusBadge(
            status: _conversationStatus(context, conversation),
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppInfoTileGrid(
            emptyValue: l10n.profileUnknownValue,
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.communicationsSubjectLabel,
                value: conversation.subject ?? conversation.title,
                icon: Icons.subject_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsParticipantsLabel,
                value: _participantsLabel(context, conversation.participants),
                icon: Icons.group_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsCreatedAtLabel,
                value: _dateTimeLabel(context, conversation.createdAt),
                icon: Icons.event_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsUpdatedAtLabel,
                value: _dateTimeLabel(context, conversation.lastMessageAt),
                icon: Icons.update_outlined,
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _LinkedRecordAction(targetPath: conversation.targetPath),
          SizedBox(height: Theme.of(context).spacing.md),
          _MessageThread(messages: conversation.messages),
          SizedBox(height: Theme.of(context).spacing.md),
          Wrap(
            spacing: Theme.of(context).spacing.xs,
            runSpacing: Theme.of(context).spacing.xs,
            children: <Widget>[
              if (canWrite && !conversation.archived)
                AppButton.secondary(
                  label: l10n.communicationsArchiveAction,
                  leadingIcon: Icons.archive_outlined,
                  enabled: !state.isSaving,
                  onPressed: () => _confirmAction(
                    context,
                    title: l10n.communicationsArchiveDialogTitle,
                    body: l10n.communicationsArchiveConversationDialogBody,
                    submitLabel: l10n.communicationsArchiveAction,
                    icon: const Icon(Icons.archive_outlined),
                    onConfirm: controller.archiveSelectedConversation,
                  ),
                ),
              if (canWrite && conversation.archived)
                AppButton.secondary(
                  label: l10n.communicationsUnarchiveAction,
                  leadingIcon: Icons.unarchive_outlined,
                  enabled: !state.isSaving,
                  onPressed: () => _confirmAction(
                    context,
                    title: l10n.communicationsUnarchiveDialogTitle,
                    body: l10n.communicationsUnarchiveConversationDialogBody,
                    submitLabel: l10n.communicationsUnarchiveAction,
                    icon: const Icon(Icons.unarchive_outlined),
                    onConfirm: controller.unarchiveSelectedConversation,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notificationDetail(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NotificationItem? notification = state.selectedNotification;
    if (notification == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.communicationsNotificationDetailTitle,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.communicationsNoNotificationSelectedTitle,
          body: l10n.communicationsNoNotificationSelectedBody,
          icon: Icons.notifications_none_outlined,
          minHeight: 220,
        ),
      );
    }

    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );
    return AppWorkspaceDetailPanel(
      title: l10n.communicationsNotificationDetailTitle,
      actions: <Widget>[
        if (canWrite && !notification.isRead)
          AppButton.secondary(
            label: l10n.communicationsMarkReadAction,
            leadingIcon: Icons.mark_email_read_outlined,
            enabled: !state.isSaving,
            onPressed: () => _confirmAction(
              context,
              title: l10n.communicationsMarkReadDialogTitle,
              body: l10n.communicationsMarkNotificationReadDialogBody,
              submitLabel: l10n.communicationsMarkReadAction,
              icon: const Icon(Icons.mark_email_read_outlined),
              onConfirm: controller.markSelectedNotificationRead,
            ),
          ),
        if (canWrite && notification.isRead)
          AppButton.secondary(
            label: l10n.communicationsMarkUnreadAction,
            leadingIcon: Icons.mark_email_unread_outlined,
            enabled: !state.isSaving,
            onPressed: () => _confirmAction(
              context,
              title: l10n.communicationsMarkUnreadDialogTitle,
              body: l10n.communicationsMarkNotificationUnreadDialogBody,
              submitLabel: l10n.communicationsMarkUnreadAction,
              icon: const Icon(Icons.mark_email_unread_outlined),
              onConfirm: controller.markSelectedNotificationUnread,
            ),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppListItemText(
            title: notification.title,
            subtitle: notification.message,
            titleStyle: Theme.of(context).textTheme.titleMedium,
            titleMaxLines: 3,
            subtitleMaxLines: 6,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          Wrap(
            spacing: Theme.of(context).spacing.xs,
            runSpacing: Theme.of(context).spacing.xs,
            children: <Widget>[
              AppWorkspaceStatusBadge(
                status: _priorityStatus(context, notification.priority),
              ),
              AppWorkspaceStatusBadge(
                status: _readStatus(context, notification),
              ),
              AppWorkspaceStatusBadge(
                status: _deliveryStatus(
                  context,
                  notification.effectiveDeliveryStatus,
                ),
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppInfoTileGrid(
            emptyValue: l10n.profileUnknownValue,
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.communicationsTypeLabel,
                value: _apiLabel(context, notification.notificationType),
                icon: Icons.category_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsContextLabel,
                value: _joinDisplay(<String?>[
                  notification.contextType,
                  notification.contextPublicId,
                ]),
                icon: Icons.link_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsCreatedAtLabel,
                value: _dateTimeLabel(context, notification.createdAt),
                icon: Icons.event_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsReadAtLabel,
                value: _dateTimeLabel(context, notification.readAt),
                icon: Icons.mark_email_read_outlined,
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _LinkedRecordAction(targetPath: notification.targetPath),
          if (notification.deliveries.isNotEmpty) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.md),
            _DeliveryHistory(deliveries: notification.deliveries),
          ],
          SizedBox(height: Theme.of(context).spacing.md),
          if (canWrite)
            AppButton.secondary(
              label: l10n.communicationsArchiveAction,
              leadingIcon: Icons.archive_outlined,
              enabled: !state.isSaving,
              onPressed: () => _confirmAction(
                context,
                title: l10n.communicationsArchiveDialogTitle,
                body: l10n.communicationsArchiveNotificationDialogBody,
                submitLabel: l10n.communicationsArchiveAction,
                icon: const Icon(Icons.archive_outlined),
                onConfirm: controller.archiveSelectedNotification,
              ),
            ),
        ],
      ),
    );
  }

  Widget _deliveryDetail(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final NotificationDelivery? delivery = state.selectedDelivery;
    if (delivery == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.communicationsDeliveryDetailTitle,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.communicationsNoDeliverySelectedTitle,
          body: l10n.communicationsNoDeliverySelectedBody,
          icon: Icons.mark_email_read_outlined,
          minHeight: 220,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.communicationsDeliveryDetailTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppWorkspaceStatusBadge(
            status: _deliveryStatus(context, delivery.status),
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppInfoTileGrid(
            emptyValue: l10n.profileUnknownValue,
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.communicationsNotificationLabel,
                value: delivery.notificationTitle,
                icon: Icons.notifications_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsChannelLabel,
                value: _apiLabel(context, delivery.channel),
                icon: Icons.send_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsRecipientLabel,
                value: _deliveryRecipient(delivery),
                icon: Icons.person_outline,
              ),
              AppInfoTileData(
                label: l10n.communicationsAttemptsLabel,
                value: delivery.attemptCount.toString(),
                icon: Icons.replay_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsProviderLabel,
                value: delivery.providerName,
                icon: Icons.cloud_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsSentAtLabel,
                value: _dateTimeLabel(context, delivery.sentAt),
                icon: Icons.schedule_send_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsDeliveredAtLabel,
                value: _dateTimeLabel(context, delivery.deliveredAt),
                icon: Icons.done_all_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsFailedAtLabel,
                value: _dateTimeLabel(context, delivery.failedAt),
                icon: Icons.error_outline,
              ),
            ],
          ),
          if (_nonEmpty(delivery.errorMessage) != null) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.md),
            AppMessagePanel(
              title: l10n.communicationsDeliveryErrorTitle,
              message: delivery.errorMessage!,
              tone: AppWorkspaceStatusTone.error,
              icon: Icons.error_outline,
            ),
          ],
          SizedBox(height: Theme.of(context).spacing.md),
          _LinkedRecordAction(targetPath: delivery.targetPath),
        ],
      ),
    );
  }

  Widget _templateDetail(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CommunicationTemplate? template = state.selectedTemplate;
    if (template == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.communicationsTemplateDetailTitle,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.communicationsNoTemplateSelectedTitle,
          body: l10n.communicationsNoTemplateSelectedBody,
          icon: Icons.description_outlined,
          minHeight: 220,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.communicationsTemplateDetailTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppListItemText(
            title: template.name,
            subtitle: template.description,
            titleStyle: Theme.of(context).textTheme.titleMedium,
            titleMaxLines: 2,
            subtitleMaxLines: 4,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppInfoTileGrid(
            emptyValue: l10n.profileUnknownValue,
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.communicationsChannelLabel,
                value: _apiLabel(context, template.channel),
                icon: Icons.send_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsSubjectLabel,
                value: template.subject,
                icon: Icons.subject_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsVariablesLabel,
                value: template.variableCount.toString(),
                icon: Icons.dynamic_form_outlined,
              ),
              AppInfoTileData(
                label: l10n.communicationsStatusLabel,
                value: _templateStatus(context, template).label,
                icon: Icons.flag_outlined,
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppSectionPanel(
            title: l10n.communicationsPreviewTitle,
            leadingIcon: Icons.preview_outlined,
            children: <Widget>[
              Text(
                template.previewSubject ??
                    template.subject ??
                    l10n.profileUnknownValue,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                template.previewBody ??
                    template.body ??
                    l10n.profileUnknownValue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkedRecordAction extends StatelessWidget {
  const _LinkedRecordAction({required this.targetPath});

  final String? targetPath;

  @override
  Widget build(BuildContext context) {
    final String? path = _internalPath(targetPath);
    return Align(
      alignment: Alignment.centerLeft,
      child: AppButton.secondary(
        label: context.l10n.communicationsOpenLinkedRecordAction,
        leadingIcon: Icons.open_in_new_outlined,
        enabled: path != null,
        onPressed: path == null ? null : () => context.go(path),
      ),
    );
  }
}

class _MessageThread extends StatelessWidget {
  const _MessageThread({required this.messages});

  final List<CommunicationMessage> messages;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (messages.isEmpty) {
      return AppMessagePanel(
        message: l10n.communicationsNoMessagesBody,
        icon: Icons.forum_outlined,
      );
    }

    return AppSectionPanel(
      title: l10n.communicationsMessageThreadTitle,
      leadingIcon: Icons.forum_outlined,
      children: <Widget>[
        for (final CommunicationMessage message in messages.take(8))
          AppListItemRow(
            title: message.sender?.displayName ?? l10n.profileUnknownValue,
            subtitle: message.preview,
            leadingIcon: Icons.person_outline,
            padding: EdgeInsets.zero,
            details: <Widget>[
              AppInlineMetaText(
                icon: Icons.schedule_outlined,
                label: _dateTimeLabel(context, message.sentAt),
              ),
            ],
          ),
      ],
    );
  }
}

class _DeliveryHistory extends StatelessWidget {
  const _DeliveryHistory({required this.deliveries});

  final List<NotificationDelivery> deliveries;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppSectionPanel(
      title: l10n.communicationsDeliveryHistoryTitle,
      leadingIcon: Icons.mark_email_read_outlined,
      children: <Widget>[
        for (final NotificationDelivery delivery in deliveries)
          AppListItemRow(
            title: _apiLabel(context, delivery.channel),
            subtitle: _deliveryRecipient(delivery),
            leadingIcon: Icons.send_outlined,
            padding: EdgeInsets.zero,
            trailing: AppWorkspaceStatusBadge(
              status: _deliveryStatus(context, delivery.status),
            ),
          ),
      ],
    );
  }
}

AppListTableSearch<T> _tableSearch<T>(
  BuildContext context,
  WidgetRef ref,
  CommunicationsWorkspaceState state,
  TextEditingController controller,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableSearch<T>(
    controller: controller,
    semanticLabel: l10n.communicationsSearchSemanticLabel,
    hintText: l10n.communicationsSearchHint,
    clearLabel: l10n.communicationsClearSearchAction,
    matcher: (_, _) => true,
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
    advancedFilterButtonLabel: l10n.communicationsAdvancedFiltersLabel,
    advancedFilterTitle: l10n.communicationsAdvancedFiltersTitle,
    advancedFilterApplyLabel: l10n.communicationsApplyFiltersAction,
    advancedFilterResetLabel: l10n.communicationsResetFiltersAction,
    advancedFilterCancelLabel: l10n.commonCancelActionLabel,
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

Future<void> _confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String submitLabel,
  required Widget icon,
  required Future<AppFailure?> Function() onConfirm,
}) async {
  final bool? changed = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppConfirmActionDialog(
      title: title,
      body: body,
      submitLabel: submitLabel,
      icon: icon,
      onConfirm: onConfirm,
    ),
  );
  if (changed == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.communicationsActionSavedMessage)),
    );
  }
}

Future<void> _sendMessage(
  BuildContext context,
  CommunicationsWorkspaceController controller,
) async {
  final bool? sent = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppTextActionDialog(
      title: context.l10n.communicationsSendMessageDialogTitle,
      fieldLabel: context.l10n.communicationsMessageFieldLabel,
      submitLabel: context.l10n.communicationsSendMessageAction,
      icon: const Icon(Icons.send_outlined),
      onSubmit: controller.sendMessage,
    ),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.communicationsMessageSentMessage)),
    );
  }
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

String _panelTitle(AppLocalizations l10n, CommunicationsPanel panel) {
  return switch (panel) {
    CommunicationsPanel.inbox => l10n.communicationsInboxPanelLabel,
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

String _participantsLabel(
  BuildContext context,
  List<CommunicationsParticipant> participants,
) {
  final String joined = participants
      .map((CommunicationsParticipant participant) {
        return participant.user?.displayName ?? participant.userId;
      })
      .where((String value) => value.trim().isNotEmpty)
      .take(3)
      .join(_listSeparator);
  return joined.isEmpty ? context.l10n.profileUnknownValue : joined;
}

String _deliveryRecipient(NotificationDelivery delivery) {
  return _joinDisplay(<String?>[
        delivery.recipient?.displayName,
        delivery.recipientTarget,
      ]) ??
      delivery.id;
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

AppWorkspaceStatus _conversationStatus(
  BuildContext context,
  CommunicationsConversation conversation,
) {
  final AppLocalizations l10n = context.l10n;
  if (conversation.archived) {
    return AppWorkspaceStatus(
      label: l10n.communicationsArchivedStatus,
      icon: Icons.archive_outlined,
    );
  }
  if (conversation.unread) {
    return AppWorkspaceStatus(
      label: l10n.communicationsUnreadStatus,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.mark_chat_unread_outlined,
    );
  }
  if (conversation.isSensitive) {
    return AppWorkspaceStatus(
      label: l10n.communicationsSensitiveStatus,
      tone: AppWorkspaceStatusTone.info,
      icon: Icons.privacy_tip_outlined,
    );
  }
  return AppWorkspaceStatus(
    label: _apiLabel(context, conversation.status),
    tone: AppWorkspaceStatusTone.success,
    icon: Icons.check_circle_outline,
  );
}

AppWorkspaceStatus _readStatus(BuildContext context, NotificationItem item) {
  return AppWorkspaceStatus(
    label: _readStateLabel(context, item),
    tone: item.isRead
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.warning,
    icon: item.isRead
        ? Icons.mark_email_read_outlined
        : Icons.mark_email_unread_outlined,
  );
}

String _readStateLabel(BuildContext context, NotificationItem item) {
  return item.isRead
      ? context.l10n.communicationsReadStatus
      : context.l10n.communicationsUnreadStatus;
}

AppWorkspaceStatus _priorityStatus(BuildContext context, String? value) {
  final String normalized = (value ?? '').trim().toUpperCase();
  return AppWorkspaceStatus(
    label: _apiLabel(context, value),
    tone: switch (normalized) {
      'HIGH' || 'URGENT' || 'CRITICAL' => AppWorkspaceStatusTone.error,
      'MEDIUM' || 'NORMAL' => AppWorkspaceStatusTone.warning,
      'LOW' => AppWorkspaceStatusTone.neutral,
      _ => AppWorkspaceStatusTone.info,
    },
    icon: switch (normalized) {
      'HIGH' || 'URGENT' || 'CRITICAL' => Icons.priority_high_outlined,
      _ => Icons.low_priority_outlined,
    },
  );
}

AppWorkspaceStatus _deliveryStatus(BuildContext context, String? value) {
  final String normalized = (value ?? '').trim().toUpperCase();
  return AppWorkspaceStatus(
    label: _apiLabel(context, value),
    tone: switch (normalized) {
      'DELIVERED' || 'SENT' || 'SUCCESS' => AppWorkspaceStatusTone.success,
      'FAILED' || 'BOUNCED' || 'ERROR' => AppWorkspaceStatusTone.error,
      'RETRYING' || 'PENDING' || 'QUEUED' => AppWorkspaceStatusTone.warning,
      _ => AppWorkspaceStatusTone.neutral,
    },
  );
}

AppWorkspaceStatus _templateStatus(
  BuildContext context,
  CommunicationTemplate template,
) {
  return AppWorkspaceStatus(
    label: template.isActive
        ? context.l10n.communicationsActiveStatus
        : context.l10n.communicationsInactiveStatus,
    tone: template.isActive
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.neutral,
    icon: template.isActive
        ? Icons.check_circle_outline
        : Icons.pause_circle_outline,
  );
}

String _apiLabel(BuildContext context, String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return context.l10n.profileUnknownValue;
  }

  return normalized
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .map((String word) {
        final String lower = word.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(_listSeparator);
  return joined.isEmpty ? null : joined;
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _internalPath(String? value) {
  final String? path = _nonEmpty(value);
  if (path == null || !path.startsWith('/')) {
    return null;
  }
  return path;
}

bool _hasRouteQuery(CommunicationsWorkspaceQuery query) {
  return query.panel != CommunicationsPanel.inbox || query.hasActiveFilters;
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
const String _failedFilterValue = 'failed';
const String _listSeparator = ' | ';
const String _signatureSeparator = '::';
