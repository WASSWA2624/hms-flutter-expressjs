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
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/presentation/controllers/mortuary_workspace_controller.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class MortuaryWorkspacePage extends ConsumerWidget {
  const MortuaryWorkspacePage({this.initialQuery, super.key});

  final MortuaryRouteQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<MortuaryWorkspaceState>> workspace = ref.watch(
      mortuaryWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return AppAccessGate(
      requirement: mortuaryWorkspaceRouteEntryRequirement,
      deniedBuilder: (_, _) => AppStateScaffold(
        variant: AppStateViewVariant.forbidden,
        title: l10n.routeForbiddenTitle,
        body: l10n.routeForbiddenBody,
      ),
      child: AsyncStateScaffold<MortuaryWorkspaceState>(
        value: workspace,
        loadingTitle: l10n.mortuaryLoadingTitle,
        loadingBody: l10n.mortuaryLoadingBody,
        maxWidth: PageMaxWidth.dataHeavy,
        centerVertically: false,
        onRetry: () {
          ref.read(mortuaryWorkspaceControllerProvider.notifier).refresh();
        },
        dataBuilder: (BuildContext context, MortuaryWorkspaceState state) {
          return _MortuaryWorkspaceContent(
            state: state,
            initialQuery: initialQuery,
          );
        },
      ),
    );
  }
}

class _MortuaryWorkspaceContent extends ConsumerStatefulWidget {
  const _MortuaryWorkspaceContent({required this.state, this.initialQuery});

  final MortuaryWorkspaceState state;
  final MortuaryRouteQuery? initialQuery;

  @override
  ConsumerState<_MortuaryWorkspaceContent> createState() {
    return _MortuaryWorkspaceContentState();
  }
}

class _MortuaryWorkspaceContentState
    extends ConsumerState<_MortuaryWorkspaceContent> {
  late final TextEditingController _searchController;
  late AppListTableColumnVisibilityController<MortuaryWorkspaceItem>
  _tableColumnController;
  late String _currentPanel;
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    _currentPanel = _initialPanel(
      widget.initialQuery,
      widget.state.query.panel,
    );
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<MortuaryWorkspaceItem>();
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant _MortuaryWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.value = TextEditingValue(text: search);
    }
    if (widget.state.query.panel != _currentPanel) {
      _currentPanel = widget.state.query.panel;
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

  static String _initialPanel(MortuaryRouteQuery? query, String fallback) {
    if (query != null && query.panel.isNotEmpty) {
      return query.normalizedPanel;
    }
    return fallback;
  }

  void _scheduleRouteQuery(MortuaryRouteQuery? query) {
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

  Future<void> _applyDeepLink(MortuaryRouteQuery query) async {
    if (_appliedRouteSignature == query.signature) {
      return;
    }
    _appliedRouteSignature = query.signature;

    final MortuaryWorkspaceController controller = ref.read(
      mortuaryWorkspaceControllerProvider.notifier,
    );

    if (query.queue.isNotEmpty) {
      final AppFailure? failure = await controller.applyQueue(query.queue);
      if (!mounted) {
        return;
      }
      _showFailureIfNeeded(context, failure);
      final MortuaryWorkspaceState? next = _mortuaryStateFromAsync(
        ref.read(mortuaryWorkspaceControllerProvider),
      );
      if (next != null) {
        setState(() => _currentPanel = next.query.panel);
      }
    } else if (query.panel.isNotEmpty) {
      final String panel = query.normalizedPanel;
      setState(() => _currentPanel = panel);
      final AppFailure? failure = await controller.switchPanel(panel);
      if (!mounted) {
        return;
      }
      _showFailureIfNeeded(context, failure);
    }

    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
      final AppFailure? failure = await controller.applySearch(query.search);
      if (!mounted) {
        return;
      }
      _showFailureIfNeeded(context, failure);
    }

    if (query.id.isNotEmpty && mounted) {
      final MortuaryWorkspaceState state = widget.state;
      final MortuaryWorkspaceState? latest = _mortuaryStateFromAsync(
        ref.read(mortuaryWorkspaceControllerProvider),
      );
      final List<MortuaryWorkspaceItem> items = (latest ?? state).items.items;
      for (final MortuaryWorkspaceItem item in items) {
        if (item.id == query.id) {
          await _openMortuaryDetailDialog(context, item);
          break;
        }
      }
    }
  }

  void _switchPanel(String panel) {
    if (panel == _currentPanel) {
      return;
    }
    final MortuaryWorkspaceController controller = ref.read(
      mortuaryWorkspaceControllerProvider.notifier,
    );
    _tableColumnController.dispose();
    setState(() {
      _currentPanel = panel;
      _tableColumnController =
          AppListTableColumnVisibilityController<MortuaryWorkspaceItem>();
    });
    unawaited(controller.switchPanel(panel));
  }

  void _updateUrl({String? panel, String? queue}) {
    if (!mounted) {
      return;
    }
    final String effectivePanel = panel ?? _currentPanel;
    final String location = AppRoutes.mortuary.location(
      queryParameters: <String, String>{
        if (effectivePanel != mortuaryPanelOverview) 'panel': effectivePanel,
        if (queue != null && queue.isNotEmpty) 'queue': queue,
      },
    );
    GoRouter.of(context).replace<void>(location);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final MortuaryWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final List<String> visiblePanels = mortuaryAllowedPanels(accessPolicy);
    if (visiblePanels.isEmpty) {
      return const SizedBox.shrink();
    }
    if (!visiblePanels.contains(_currentPanel)) {
      final String? fallback = mortuaryFallbackPanel(accessPolicy);
      if (fallback != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || visiblePanels.contains(_currentPanel)) {
            return;
          }
          _switchPanel(fallback);
          _updateUrl(panel: fallback);
        });
      }
    }

    final MortuaryWorkspaceController controller = ref.read(
      mortuaryWorkspaceControllerProvider.notifier,
    );

    return ResponsivePage(
      padding: ResponsiveSpacing.workspacePagePaddingFor(
        spacing: Theme.of(context).spacing,
      ),
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final String panel in visiblePanels)
                  AppTabItem(
                    id: panel,
                    icon: _panelIcon(panel),
                    label: _panelLabel(l10n, panel),
                    count: _panelCount(state, panel),
                  ),
              ],
              selectedId: _currentPanel,
              onTabTapped: (String tabId) {
                if (!visiblePanels.contains(tabId)) {
                  return;
                }
                _switchPanel(tabId);
                _updateUrl(panel: tabId);
              },
            ),
            SizedBox(height: theme.spacing.sm),
            _MortuaryWorklist(
              state: state,
              panel: _currentPanel,
              controller: controller,
              searchController: _searchController,
              tableColumnController: _tableColumnController,
              onItemSelected: (MortuaryWorkspaceItem item) {
                unawaited(_openMortuaryDetailDialog(context, item));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMortuaryDetailDialog(
    BuildContext context,
    MortuaryWorkspaceItem item,
  ) async {
    final MortuaryWorkspaceController controller = ref.read(
      mortuaryWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = await controller.selectItem(item);
    if (!context.mounted) {
      return;
    }
    if (failure != null) {
      _showFailureIfNeeded(context, failure);
      return;
    }

    final String detailPanel = _currentPanel;
    await showAppDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (BuildContext dialogContext, WidgetRef dialogRef, _) {
          final MortuaryWorkspaceState dialogState =
              _mortuaryStateFromAsync(
                dialogRef.watch(mortuaryWorkspaceControllerProvider),
              ) ??
              widget.state;
          final MortuaryWorkspaceItem? selected = dialogState.selectedItem;
          return AppDialog(
            title: Text(dialogContext.l10n.mortuaryDetailTitle),
            icon: const Icon(Icons.inventory_2_outlined),
            scrollable: true,
            maxWidth: 980,
            content: _MortuaryDetailPanel(
              state: dialogState,
              panel: detailPanel,
              onPrint: selected == null
                  ? null
                  : () {
                      unawaited(_printItem(dialogContext, dialogRef, selected));
                    },
            ),
          );
        },
      ),
    );
  }
}

int _panelCount(MortuaryWorkspaceState state, String panel) {
  for (final MortuaryPanelSummary item in state.panels) {
    if (item.id == panel) {
      return item.count;
    }
  }
  if (panel == mortuaryPanelOverview) {
    return state.summaryValue('total_cases');
  }
  return 0;
}

enum _MortuaryTableColumnId {
  deceased,
  reference,
  source,
  storage,
  status,
  nextAction,
  date,
  billingStatus,
  facility,
  identification,
  event,
  actor,
  location,
  notes,
  recipient,
  verification,
  funeralService,
  request,
  scheduled,
  requestedBy,
  completed,
}

const List<_MortuaryTableColumnId> _mortuaryCasePanelDefaultColumns =
    <_MortuaryTableColumnId>[
      _MortuaryTableColumnId.deceased,
      _MortuaryTableColumnId.reference,
      _MortuaryTableColumnId.source,
      _MortuaryTableColumnId.status,
      _MortuaryTableColumnId.nextAction,
    ];

const List<_MortuaryTableColumnId> _mortuaryCasePanelAllColumns =
    <_MortuaryTableColumnId>[
      _MortuaryTableColumnId.deceased,
      _MortuaryTableColumnId.reference,
      _MortuaryTableColumnId.source,
      _MortuaryTableColumnId.storage,
      _MortuaryTableColumnId.status,
      _MortuaryTableColumnId.nextAction,
      _MortuaryTableColumnId.date,
      _MortuaryTableColumnId.billingStatus,
      _MortuaryTableColumnId.facility,
      _MortuaryTableColumnId.identification,
    ];

List<_MortuaryTableColumnId> _mortuaryDefaultColumnsForPanel(String panel) {
  return switch (panel) {
    mortuaryPanelStorage => const <_MortuaryTableColumnId>[
      _MortuaryTableColumnId.deceased,
      _MortuaryTableColumnId.storage,
      _MortuaryTableColumnId.status,
      _MortuaryTableColumnId.billingStatus,
      _MortuaryTableColumnId.date,
      _MortuaryTableColumnId.nextAction,
    ],
    mortuaryPanelCustody => const <_MortuaryTableColumnId>[
      _MortuaryTableColumnId.deceased,
      _MortuaryTableColumnId.event,
      _MortuaryTableColumnId.actor,
      _MortuaryTableColumnId.date,
      _MortuaryTableColumnId.status,
    ],
    mortuaryPanelRelease => const <_MortuaryTableColumnId>[
      _MortuaryTableColumnId.deceased,
      _MortuaryTableColumnId.recipient,
      _MortuaryTableColumnId.status,
      _MortuaryTableColumnId.billingStatus,
      _MortuaryTableColumnId.date,
      _MortuaryTableColumnId.nextAction,
    ],
    mortuaryPanelReporting => const <_MortuaryTableColumnId>[
      _MortuaryTableColumnId.deceased,
      _MortuaryTableColumnId.request,
      _MortuaryTableColumnId.scheduled,
      _MortuaryTableColumnId.status,
      _MortuaryTableColumnId.nextAction,
    ],
    _ => _mortuaryCasePanelDefaultColumns,
  };
}

List<_MortuaryTableColumnId> _mortuaryAllColumnsForPanel(String panel) {
  return switch (panel) {
    mortuaryPanelStorage => const <_MortuaryTableColumnId>[
      _MortuaryTableColumnId.deceased,
      _MortuaryTableColumnId.storage,
      _MortuaryTableColumnId.status,
      _MortuaryTableColumnId.date,
      _MortuaryTableColumnId.nextAction,
      _MortuaryTableColumnId.reference,
      _MortuaryTableColumnId.source,
      _MortuaryTableColumnId.facility,
      _MortuaryTableColumnId.billingStatus,
    ],
    mortuaryPanelCustody => const <_MortuaryTableColumnId>[
      _MortuaryTableColumnId.deceased,
      _MortuaryTableColumnId.event,
      _MortuaryTableColumnId.actor,
      _MortuaryTableColumnId.date,
      _MortuaryTableColumnId.status,
      _MortuaryTableColumnId.location,
      _MortuaryTableColumnId.reference,
      _MortuaryTableColumnId.notes,
    ],
    mortuaryPanelRelease => const <_MortuaryTableColumnId>[
      _MortuaryTableColumnId.deceased,
      _MortuaryTableColumnId.recipient,
      _MortuaryTableColumnId.status,
      _MortuaryTableColumnId.billingStatus,
      _MortuaryTableColumnId.date,
      _MortuaryTableColumnId.nextAction,
      _MortuaryTableColumnId.reference,
      _MortuaryTableColumnId.verification,
      _MortuaryTableColumnId.funeralService,
    ],
    mortuaryPanelReporting => const <_MortuaryTableColumnId>[
      _MortuaryTableColumnId.deceased,
      _MortuaryTableColumnId.request,
      _MortuaryTableColumnId.scheduled,
      _MortuaryTableColumnId.status,
      _MortuaryTableColumnId.nextAction,
      _MortuaryTableColumnId.requestedBy,
      _MortuaryTableColumnId.reference,
      _MortuaryTableColumnId.completed,
    ],
    _ => _mortuaryCasePanelAllColumns,
  };
}

String _mortuaryColumnId(_MortuaryTableColumnId column) {
  return switch (column) {
    _MortuaryTableColumnId.nextAction => 'next_action',
    _MortuaryTableColumnId.billingStatus => 'billing_status',
    _MortuaryTableColumnId.funeralService => 'funeral_service',
    _MortuaryTableColumnId.requestedBy => 'requested_by',
    _ => column.name,
  };
}

String _mortuaryColumnLabel(
  AppLocalizations l10n,
  _MortuaryTableColumnId column,
) {
  return switch (column) {
    _MortuaryTableColumnId.deceased => l10n.mortuaryDeceasedColumnLabel,
    _MortuaryTableColumnId.reference => l10n.mortuaryReferenceColumnLabel,
    _MortuaryTableColumnId.source => l10n.mortuarySourceColumnLabel,
    _MortuaryTableColumnId.storage => l10n.mortuaryStorageColumnLabel,
    _MortuaryTableColumnId.status => l10n.mortuaryStatusColumnLabel,
    _MortuaryTableColumnId.nextAction => l10n.mortuaryNextActionColumnLabel,
    _MortuaryTableColumnId.date => l10n.mortuaryDateColumnLabel,
    _MortuaryTableColumnId.billingStatus => l10n.mortuaryBillingColumnLabel,
    _MortuaryTableColumnId.facility => l10n.mortuaryFacilityFieldLabel,
    _MortuaryTableColumnId.identification =>
      l10n.mortuaryIdentificationFieldLabel,
    _MortuaryTableColumnId.event => l10n.mortuaryEventColumnLabel,
    _MortuaryTableColumnId.actor => l10n.mortuaryActorColumnLabel,
    _MortuaryTableColumnId.location => l10n.mortuaryLocationColumnLabel,
    _MortuaryTableColumnId.notes => l10n.mortuaryReasonColumnLabel,
    _MortuaryTableColumnId.recipient => l10n.mortuaryRecipientColumnLabel,
    _MortuaryTableColumnId.verification =>
      l10n.mortuaryDiagnosticsRefColumnLabel,
    _MortuaryTableColumnId.funeralService =>
      l10n.mortuaryFuneralServiceColumnLabel,
    _MortuaryTableColumnId.request => l10n.mortuaryReasonColumnLabel,
    _MortuaryTableColumnId.scheduled => l10n.mortuaryDateColumnLabel,
    _MortuaryTableColumnId.requestedBy => l10n.mortuaryRequestedByColumnLabel,
    _MortuaryTableColumnId.completed => l10n.mortuaryDateColumnLabel,
  };
}

String? _mortuaryPanelStatus(MortuaryWorkspaceItem item, String panel) {
  return switch (panel) {
    mortuaryPanelStorage =>
      item.storageSlotStatus ?? item.storageAssignment?.status ?? item.status,
    mortuaryPanelRelease => item.releaseStatus ?? item.status,
    _ => item.caseStatus ?? item.status,
  };
}

DateTime? _mortuaryPanelDate(MortuaryWorkspaceItem item, String panel) {
  return switch (panel) {
    mortuaryPanelStorage =>
      item.timelineAt ?? item.storageAssignment?.assignedAt,
    mortuaryPanelCustody => item.eventAt ?? item.timelineAt,
    mortuaryPanelRelease =>
      item.releasedAt ?? item.approvedAt ?? item.timelineAt,
    mortuaryPanelReporting => item.scheduledAt,
    _ => item.timelineAt,
  };
}


class _MortuaryWorklist extends StatelessWidget {
  const _MortuaryWorklist({
    required this.state,
    required this.panel,
    required this.controller,
    required this.searchController,
    required this.tableColumnController,
    required this.onItemSelected,
  });

  final MortuaryWorkspaceState state;
  final String panel;
  final MortuaryWorkspaceController controller;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<MortuaryWorkspaceItem>
  tableColumnController;
  final ValueChanged<MortuaryWorkspaceItem> onItemSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy policy = ProviderScope.containerOf(
      context,
    ).read(appAccessPolicyProvider);
    final List<AppListTableColumn<MortuaryWorkspaceItem>> defaultColumns =
        <AppListTableColumn<MortuaryWorkspaceItem>>[
          for (final _MortuaryTableColumnId column
              in _mortuaryDefaultColumnsForPanel(panel))
            _mortuaryDataColumn(
              context,
              panel: panel,
              column: column,
              policy: policy,
            ),
        ];
    final List<AppListTableColumn<MortuaryWorkspaceItem>> columnChoices =
        <AppListTableColumn<MortuaryWorkspaceItem>>[
          for (final _MortuaryTableColumnId column
              in _mortuaryAllColumnsForPanel(panel))
            _mortuaryDataColumn(
              context,
              panel: panel,
              column: column,
              policy: policy,
            ),
        ];

    return AppListTable<MortuaryWorkspaceItem>(
      key: ValueKey<String>('mortuary_table_$panel'),
      page: state.items,
      columns: defaultColumns,
      columnChoices: columnChoices,
      columnVisibilityController: tableColumnController,
      columnVisibilityStorageKey: 'mortuary_$panel',
      columnWidthStorageKey: 'mortuary_cw_$panel',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.mortuaryApplyFiltersAction,
      columnVisibilityResetLabel: l10n.mortuaryResetFiltersAction,
      isLoading: state.isRefreshing,
      itemKeyBuilder: (MortuaryWorkspaceItem item) =>
          ValueKey<String>('${item.resource}:${item.id}'),
      onRowSelected: onItemSelected,
      onPageChanged: (AppPageRequest request) {
        unawaited(controller.changePage(request));
      },
      pageLabelBuilder: (AppPage<MortuaryWorkspaceItem> page) {
        final int total = page.totalItemCount ?? page.items.length;
        final int from = total == 0 ? 0 : page.firstItemNumber;
        final int to = page.lastItemNumber;
        return l10n.mortuaryPageLabel(from, to, total);
      },
      previousPageLabel: l10n.mortuaryPreviousPageLabel,
      nextPageLabel: l10n.mortuaryNextPageLabel,
      search: AppListTableSearch<MortuaryWorkspaceItem>(
        controller: searchController,
        semanticLabel: l10n.mortuarySearchLabel,
        hintText: l10n.mortuarySearchHint,
        matcher: (MortuaryWorkspaceItem item, String query) {
          return _matchesSearch(item, query, context: context, panel: panel);
        },
        onSubmitted: (String value) {
          unawaited(controller.applySearch(value));
        },
        onClear: () {
          unawaited(controller.applySearch(''));
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.mortuaryFiltersLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.mortuaryApplyFiltersAction,
        advancedFilterResetLabel: l10n.mortuaryResetFiltersAction,
        searchFieldLabel: l10n.mortuarySearchFieldLabel,
        allFieldsLabel: l10n.mortuaryAllFieldsLabel,
        dateFilterLabel: l10n.mortuaryDateFilterLabel,
        dateFromLabel: l10n.mortuaryDateFromLabel,
        dateToLabel: l10n.mortuaryDateToLabel,
        datePickerButtonLabel: l10n.mortuaryDatePickerButtonLabel,
        invalidDateMessage: l10n.mortuaryInvalidDateMessage,
        enableDateFilter: false,
        filterValue: _filterValueForQuery(state.query),
        hasActiveFilters: _hasActiveFilters(state.query),
        filterGroups: _filterGroups(l10n, state.lookups),
        onFilterChanged: (AppSearchBarFilterValue value) {
          unawaited(_applyFilterValue(controller, value));
        },
      ),
      emptyBuilder: (BuildContext context) {
        return AppWorkspaceStatePanel.empty(
          title: l10n.mortuaryWorklistEmptyTitle,
          body: l10n.mortuaryWorklistEmptyBody,
        );
      },
      mobileItemBuilder: (BuildContext context, MortuaryWorkspaceItem item) {
        final String? status = _mortuaryPanelStatus(item, panel);
        final String panelSubtitle = switch (panel) {
          mortuaryPanelStorage =>
            _joinValues(<String?>[item.storageLabel, _displayCode(status)]) ??
                l10n.mortuaryUnknownValueLabel,
          mortuaryPanelCustody =>
            _joinValues(<String?>[
              _displayCode(item.eventType),
              item.actorName,
            ]) ??
                l10n.mortuaryUnknownValueLabel,
          mortuaryPanelRelease =>
            _joinValues(<String?>[
              item.recipientName,
              item.recipientRelationship,
            ]) ??
                l10n.mortuaryUnknownValueLabel,
          mortuaryPanelReporting =>
            _joinValues(<String?>[
              item.requestReason,
              item.diagnosticsReferenceId,
            ]) ??
                l10n.mortuaryUnknownValueLabel,
          _ =>
            _joinValues(<String?>[
              _mortuaryPublicIdentifier(item),
              item.sourceLabel,
            ]) ??
                l10n.mortuaryUnknownValueLabel,
        };
        return AppListTableMobileItem(
          title:
              item.effectiveDeceasedLabel ?? l10n.mortuaryUnknownDeceasedLabel,
          caption: _mortuaryPublicIdentifier(item),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: _displayCode(status) ?? l10n.mortuaryUnknownValueLabel,
            ),
            AppListTableMobileMeta(label: panelSubtitle),
          ],
          showAvatar: false,
        );
      },
    );
  }
}

AppListTableColumn<MortuaryWorkspaceItem> _mortuaryDataColumn(
  BuildContext context, {
  required String panel,
  required _MortuaryTableColumnId column,
  required AppAccessPolicy policy,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<MortuaryWorkspaceItem>(
    id: _mortuaryColumnId(column),
    label: _mortuaryColumnLabel(l10n, column),
    alwaysVisible:
        column == _MortuaryTableColumnId.status ||
        column == _MortuaryTableColumnId.nextAction,
    sortComparator: _mortuarySortComparator(panel, column),
    cellBuilder: (BuildContext cellContext, MortuaryWorkspaceItem item) {
      return switch (column) {
        _MortuaryTableColumnId.deceased => AppListItemText(
          title:
              item.effectiveDeceasedLabel ?? l10n.mortuaryUnknownDeceasedLabel,
          subtitle: item.patientLabel ?? item.deceasedProfileId,
        ),
        _MortuaryTableColumnId.reference => _ReferenceCell(item: item),
        _MortuaryTableColumnId.source => AppListItemText(
          title: item.sourceLabel ?? l10n.mortuaryUnknownValueLabel,
          subtitle: item.receivedFrom,
        ),
        _MortuaryTableColumnId.storage => AppListItemText(
          title: item.storageLabel ?? l10n.mortuaryUnknownValueLabel,
          subtitle: _displayCode(
            item.storageSlotStatus ?? item.storageAssignment?.status,
          ),
        ),
        _MortuaryTableColumnId.status => AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label:
                _displayCode(_mortuaryPanelStatus(item, panel)) ??
                l10n.mortuaryUnknownValueLabel,
            tone: _statusTone(_mortuaryPanelStatus(item, panel)),
          ),
        ),
        _MortuaryTableColumnId.nextAction => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final String label = _nextActionLabel(l10n, item);
            if (label == l10n.mortuaryNextActionClearBilling &&
                canOpenMortuaryBilling(policy, panel) &&
                (item.effectivePatientId?.trim().isNotEmpty ?? false)) {
              _openMortuaryBillingWorkspace(cellContext, item);
            }
          },
          child: Text(
            _nextActionLabel(l10n, item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _MortuaryTableColumnId.date => Text(
          _formatDateTime(context, _mortuaryPanelDate(item, panel)),
        ),
        _MortuaryTableColumnId.billingStatus => AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label:
                _displayCode(item.caseBillingStatus ?? item.billingStatus) ??
                l10n.mortuaryUnknownValueLabel,
            tone: _billingTone(item.caseBillingStatus ?? item.billingStatus),
          ),
        ),
        _MortuaryTableColumnId.facility => Text(
          item.facilityLabel ?? l10n.mortuaryUnknownValueLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _MortuaryTableColumnId.identification => AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label:
                _displayCode(item.caseIdentificationStatus) ??
                l10n.mortuaryUnknownValueLabel,
            tone: _identificationTone(item.caseIdentificationStatus),
          ),
        ),
        _MortuaryTableColumnId.event => Text(
          _displayCode(item.eventType) ?? l10n.mortuaryUnknownValueLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _MortuaryTableColumnId.actor => AppListItemText(
          title: item.actorName ?? l10n.mortuaryUnknownValueLabel,
          subtitle: item.actorRole,
        ),
        _MortuaryTableColumnId.location => Text(
          item.locationLabel ?? l10n.mortuaryUnknownValueLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _MortuaryTableColumnId.notes => Text(
          item.notes ?? item.reason ?? l10n.mortuaryUnknownValueLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        _MortuaryTableColumnId.recipient => AppListItemText(
          title: item.recipientName ?? l10n.mortuaryUnknownValueLabel,
          subtitle: item.recipientRelationship,
        ),
        _MortuaryTableColumnId.verification => Text(
          item.verificationReference ?? l10n.mortuaryUnknownValueLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _MortuaryTableColumnId.funeralService => Text(
          item.funeralServiceName ?? l10n.mortuaryUnknownValueLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _MortuaryTableColumnId.request => AppListItemText(
          title: item.requestReason ?? l10n.mortuaryUnknownValueLabel,
          subtitle: item.diagnosticsReferenceId,
        ),
        _MortuaryTableColumnId.scheduled => Text(
          _formatDateTime(context, item.scheduledAt),
        ),
        _MortuaryTableColumnId.requestedBy => Text(
          item.requestedByName ?? l10n.mortuaryUnknownValueLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _MortuaryTableColumnId.completed => Text(
          _formatDateTime(context, item.completedAt),
        ),
      };
    },
  );
}

int Function(MortuaryWorkspaceItem, MortuaryWorkspaceItem)?
_mortuarySortComparator(String panel, _MortuaryTableColumnId column) {
  return switch (column) {
    _MortuaryTableColumnId.deceased =>
      (MortuaryWorkspaceItem left, MortuaryWorkspaceItem right) {
        return appListTableCompareText(
          left.effectiveDeceasedLabel,
          right.effectiveDeceasedLabel,
        );
      },
    _MortuaryTableColumnId.reference =>
      (MortuaryWorkspaceItem left, MortuaryWorkspaceItem right) {
        return appListTableCompareText(
          left.effectiveDisplayId,
          right.effectiveDisplayId,
        );
      },
    _MortuaryTableColumnId.date =>
      (MortuaryWorkspaceItem left, MortuaryWorkspaceItem right) {
        return appListTableCompareDateTime(
          _mortuaryPanelDate(left, panel),
          _mortuaryPanelDate(right, panel),
        );
      },
    _MortuaryTableColumnId.scheduled =>
      (MortuaryWorkspaceItem left, MortuaryWorkspaceItem right) {
        return appListTableCompareDateTime(left.scheduledAt, right.scheduledAt);
      },
    _MortuaryTableColumnId.completed =>
      (MortuaryWorkspaceItem left, MortuaryWorkspaceItem right) {
        return appListTableCompareDateTime(left.completedAt, right.completedAt);
      },
    _ => null,
  };
}

class _MortuaryDetailPanel extends ConsumerWidget {
  const _MortuaryDetailPanel({
    required this.state,
    required this.panel,
    required this.onPrint,
  });

  final MortuaryWorkspaceState state;
  final String panel;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final AccessRequirement printRequirement = mortuaryPanelPrintRequirement(
      panel,
    );
    final AccessRequirement billingRequirement =
        mortuaryPanelBillingRequirement(panel);
    final MortuaryWorkspaceItem? item = state.selectedItem;
    if (item == null) {
      return AppCollapsibleSection(
        title: l10n.mortuaryDetailTitle,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.mortuaryNoSelectionTitle,
          body: l10n.mortuaryNoSelectionBody,
        ),
      );
    }

    final AccessRequirement? openBillingRequirement =
        mortuaryPanelOpenBillingRequirement(panel);
    final bool showOpenBilling =
        openBillingRequirement != null &&
        openBillingRequirement.isAllowed(policy) &&
        (item.effectivePatientId?.trim().isNotEmpty ?? false);

    final List<Widget> actions = <Widget>[
      if (showOpenBilling)
        AppPermissionActionButton(
          requirement: openBillingRequirement,
          label: l10n.icuActionOpenBilling,
          icon: Icons.receipt_long_outlined,
          onPressed: () => _openMortuaryBillingWorkspace(context, item),
        ),
      if (onPrint != null)
        AppPermissionActionButton(
          requirement: printRequirement,
          label: l10n.mortuaryPrintDocumentsAction,
          icon: Icons.print_outlined,
          onPressed: onPrint,
        ),
    ];

    final List<Widget> sections = <Widget>[
      if (state.isRefreshingDetail) const LinearProgressIndicator(),
      AppPatientDetails(
        patientName:
            item.effectiveDeceasedLabel ?? l10n.mortuaryUnknownDeceasedLabel,
        patientNumber:
            _mortuaryCaseIdentifier(item) ?? l10n.mortuaryUnknownValueLabel,
        patientNumberLabel: l10n.mortuaryCaseNumberLabel,
        copyPatientNumberMessage: l10n.identifierCopiedMessage,
        copyPatientNumberSemanticLabel: l10n.copyIdentifierAction,
        semanticLabel: l10n.mortuaryDeceasedContextLabel,
        showAvatar: false,
        status: AppWorkspaceStatus(
          label:
              _displayCode(item.caseStatus ?? item.status) ??
              l10n.mortuaryUnknownValueLabel,
          tone: _statusTone(item.caseStatus ?? item.status),
        ),
        actions: actions,
        expandedFields: <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: l10n.mortuaryIdentificationFieldLabel,
            value:
                _displayCode(item.caseIdentificationStatus) ??
                l10n.mortuaryUnknownValueLabel,
            icon: Icons.badge_outlined,
            tone: _identificationTone(item.caseIdentificationStatus),
          ),
          AppWorkspacePatientContextField(
            label: l10n.mortuaryPatientFieldLabel,
            value: item.patientLabel ?? '',
            icon: Icons.assignment_ind_outlined,
            copyable: (item.patientLabel ?? '').trim().isNotEmpty,
            copyTooltip: l10n.copyIdentifierAction,
            copiedMessage: l10n.identifierCopiedMessage,
          ),
          AppWorkspacePatientContextField(
            label: l10n.mortuaryBillingFieldLabel,
            value:
                _displayCode(
                  item.caseBillingStatus ?? item.billingStatus,
                ) ??
                l10n.mortuaryUnknownValueLabel,
            icon: Icons.receipt_long_outlined,
            tone: _billingTone(item.caseBillingStatus ?? item.billingStatus),
          ),
          AppWorkspacePatientContextField(
            label: l10n.mortuaryStorageSlotFieldLabel,
            value: item.storageLabel ?? l10n.mortuaryUnknownValueLabel,
            icon: Icons.inventory_2_outlined,
          ),
          AppWorkspacePatientContextField(
            label: l10n.mortuaryFacilityFieldLabel,
            value: item.facilityLabel ?? l10n.mortuaryUnknownValueLabel,
            icon: Icons.apartment_outlined,
          ),
          AppWorkspacePatientContextField(
            label: l10n.mortuaryReceivedAtFieldLabel,
            value: _formatDateTime(context, item.receivedAt),
            icon: Icons.schedule_outlined,
          ),
        ],
      ),
      _SourceContextSection(item: item),
      _StorageSection(item: item),
      _CustodySection(item: item),
      _ViewingSection(item: item),
      _PostMortemSection(item: item),
      _ReleaseSection(item: item),
      if (billingRequirement.isAllowed(policy)) _BillingSection(item: item),
      _DocumentsSection(item: item),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withMortuaryDetailSectionSpacing(context, sections),
    );
  }
}

/// Opens Billing workspace for outstanding mortuary settle — never a local
/// cashier dialog. Billing owns payment methods, idempotency, and ledger rows.
void _openMortuaryBillingWorkspace(
  BuildContext context,
  MortuaryWorkspaceItem item,
) {
  final String? patientId = item.effectivePatientId?.trim();
  final String location = (patientId == null || patientId.isEmpty)
      ? AppRoutes.billing.path
      : AppRoutes.billing.location(
          queryParameters: <String, String>{'patient_id': patientId},
        );
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
  if (context.mounted) {
    context.go(location);
  }
}

class _SourceContextSection extends StatelessWidget {
  const _SourceContextSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCollapsibleSection(
      title: l10n.mortuaryIdentitySectionTitle,
      titleIcon: Icons.account_tree_outlined,
      initiallyExpanded: false,
      child: AppInfoTileGrid(
        emptyValue: l10n.mortuaryUnknownValueLabel,
        items: <AppInfoTileData>[
          AppInfoTileData(
            label: l10n.mortuarySourceWorkflowFieldLabel,
            value: item.sourceWorkflow,
            icon: Icons.account_tree_outlined,
          ),
          AppInfoTileData(
            label: l10n.mortuarySourceDepartmentFieldLabel,
            value: item.sourceDepartment,
            icon: Icons.local_hospital_outlined,
          ),
          AppInfoTileData(
            label: l10n.mortuarySourceReferenceFieldLabel,
            value: item.sourceReferenceId,
            icon: Icons.link_outlined,
            copyable: true,
          ),
          AppInfoTileData(
            label: l10n.mortuaryReceivedFromFieldLabel,
            value: item.receivedFrom,
            icon: Icons.move_to_inbox_outlined,
          ),
        ],
      ),
    );
  }
}

class _StorageSection extends StatelessWidget {
  const _StorageSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final MortuaryStorageAssignment? assignment = item.storageAssignment;
    return AppCollapsibleSection(
      title: l10n.mortuaryStorageSectionTitle,
      titleIcon: Icons.inventory_2_outlined,
      child: AppInfoTileGrid(
        emptyValue: l10n.mortuaryUnknownValueLabel,
        items: <AppInfoTileData>[
          AppInfoTileData(
            label: l10n.mortuaryStorageUnitFieldLabel,
            value: item.storageUnitLabel ?? assignment?.storageUnitLabel,
            icon: Icons.inventory_outlined,
          ),
          AppInfoTileData(
            label: l10n.mortuaryStorageSlotFieldLabel,
            value: item.storageSlotLabel ?? assignment?.storageSlotLabel,
            icon: Icons.grid_view_outlined,
          ),
          AppInfoTileData(
            label: l10n.mortuaryStorageStatusFieldLabel,
            value: _displayCode(
              item.storageSlotStatus ?? assignment?.storageSlotStatus,
            ),
            icon: Icons.thermostat_outlined,
          ),
          AppInfoTileData(
            label: l10n.mortuaryAssignedAtFieldLabel,
            value: _formatDateTime(context, assignment?.assignedAt),
            icon: Icons.login_outlined,
          ),
        ],
      ),
    );
  }
}

class _CustodySection extends StatelessWidget {
  const _CustodySection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> events = item.custodyEvents
        .map((MortuaryTimelineEvent event) {
          return AppWorkspaceActivityItem(
            title:
                _displayCode(event.eventType) ??
                l10n.mortuaryCustodySectionTitle,
            subtitle: _formatDateTime(context, event.eventAt),
            description: _joinValues(<String?>[
              event.actorName,
              event.actorRole,
              event.locationLabel,
              event.reason,
              event.notes,
            ]),
            icon: Icons.swap_horiz_outlined,
            tone: AppWorkspaceStatusTone.info,
          );
        })
        .toList(growable: false);

    return AppCollapsibleSection(
      title: l10n.mortuaryCustodySectionTitle,
      titleIcon: Icons.swap_horiz_outlined,
      child: AppWorkspaceActivityList(
        emptyTitle: l10n.mortuaryNoCustodyEventsLabel,
        emptyBody: l10n.mortuaryNoCustodyEventsBody,
        items: events,
      ),
    );
  }
}

class _ViewingSection extends StatelessWidget {
  const _ViewingSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> events = item.viewings
        .map((MortuaryViewing viewing) {
          return AppWorkspaceActivityItem(
            title:
                _displayCode(viewing.status) ??
                l10n.mortuaryViewingSectionTitle,
            subtitle: _formatDateTime(context, viewing.scheduledAt),
            description: _joinValues(<String?>[
              viewing.authorisedByName,
              viewing.attendeeSummary,
              _formatDateTime(context, viewing.completedAt),
            ]),
            icon: Icons.event_available_outlined,
            tone: _statusTone(viewing.status),
          );
        })
        .toList(growable: false);

    return AppCollapsibleSection(
      title: l10n.mortuaryViewingSectionTitle,
      titleIcon: Icons.event_available_outlined,
      child: AppWorkspaceActivityList(
        emptyTitle: l10n.mortuaryNoViewingsLabel,
        emptyBody: l10n.mortuaryNoViewingsBody,
        items: events,
      ),
    );
  }
}

class _PostMortemSection extends StatelessWidget {
  const _PostMortemSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> events = item.postMortemRequests
        .map((MortuaryPostMortemRequest request) {
          return AppWorkspaceActivityItem(
            title:
                _displayCode(request.status) ??
                l10n.mortuaryPostMortemSectionTitle,
            subtitle: _formatDateTime(context, request.scheduledAt),
            description: _joinValues(<String?>[
              request.requestedByName,
              request.requestReason,
              request.diagnosticsReferenceId,
              _formatDateTime(context, request.completedAt),
              _formatDateTime(context, request.reportReceivedAt),
            ]),
            icon: Icons.fact_check_outlined,
            tone: _statusTone(request.status),
          );
        })
        .toList(growable: false);

    return AppCollapsibleSection(
      title: l10n.mortuaryPostMortemSectionTitle,
      titleIcon: Icons.fact_check_outlined,
      child: AppWorkspaceActivityList(
        emptyTitle: l10n.mortuaryNoPostMortemLabel,
        emptyBody: l10n.mortuaryNoPostMortemBody,
        items: events,
      ),
    );
  }
}

class _ReleaseSection extends StatelessWidget {
  const _ReleaseSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> events = item.releaseAuthorisations
        .map((MortuaryReleaseAuthorisation release) {
          return AppWorkspaceActivityItem(
            title:
                _displayCode(release.status) ??
                l10n.mortuaryReleaseSectionTitle,
            subtitle: _formatDateTime(
              context,
              release.releasedAt ?? release.approvedAt,
            ),
            description: _joinValues(<String?>[
              release.recipientName,
              release.recipientRelationship,
              release.verificationReference,
              release.funeralServiceName,
              release.releaseMethod,
              release.approvedByName,
            ]),
            icon: Icons.outbox_outlined,
            tone: _statusTone(release.status),
          );
        })
        .toList(growable: false);

    return AppCollapsibleSection(
      title: l10n.mortuaryReleaseSectionTitle,
      titleIcon: Icons.outbox_outlined,
      child: AppWorkspaceActivityList(
        emptyTitle: l10n.mortuaryNoReleaseLabel,
        emptyBody: l10n.mortuaryNoReleaseBody,
        items: events,
      ),
    );
  }
}

class _BillingSection extends StatelessWidget {
  const _BillingSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> events = item.billableEvents
        .map((MortuaryBillableEvent event) {
          return AppWorkspaceActivityItem(
            title:
                _displayCode(event.status) ?? l10n.mortuaryBillingSectionTitle,
            subtitle: _formatDateTime(context, event.chargedAt),
            description: _joinValues(<String?>[
              _displayCode(event.eventType),
              event.description,
              _formatAmount(context, event.amountText, event.currency),
              event.billingReferenceId,
              _formatDateTime(context, event.settledAt),
            ]),
            icon: Icons.receipt_long_outlined,
            tone: _billingTone(event.status),
          );
        })
        .toList(growable: false);

    return AppCollapsibleSection(
      title: l10n.mortuaryBillingSectionTitle,
      titleIcon: Icons.receipt_long_outlined,
      child: AppWorkspaceActivityList(
        emptyTitle: l10n.mortuaryNoBillingLabel,
        emptyBody: l10n.mortuaryNoBillingBody,
        items: events,
      ),
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCollapsibleSection(
      title: l10n.mortuaryDocumentsSectionTitle,
      titleIcon: Icons.description_outlined,
      child: AppInfoTileGrid(
        emptyValue: l10n.mortuaryNoDocumentsBody,
        items: <AppInfoTileData>[
          AppInfoTileData(
            label: l10n.mortuaryIntakeDocumentLabel,
            value: item.receivedAt == null
                ? null
                : _formatDateTime(context, item.receivedAt),
            icon: Icons.assignment_outlined,
          ),
          AppInfoTileData(
            label: l10n.mortuaryCustodyLogDocumentLabel,
            value: item.custodyEvents.length.toString(),
            icon: Icons.timeline_outlined,
          ),
          AppInfoTileData(
            label: l10n.mortuaryReleaseDocumentLabel,
            value: item.releaseAuthorisations.isEmpty
                ? null
                : item.releaseAuthorisations.length.toString(),
            icon: Icons.outbox_outlined,
          ),
        ],
      ),
    );
  }
}

class _ReferenceCell extends StatelessWidget {
  const _ReferenceCell({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String value =
        _mortuaryPublicIdentifier(item) ?? l10n.mortuaryUnknownValueLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppCopyableIdentifier(value: value),
        Text(
          _resourceLabel(l10n, item.resource),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

Future<void> _applyFilterValue(
  MortuaryWorkspaceController controller,
  AppSearchBarFilterValue value,
) {
  return controller.applyFilters(
    resource: value.option('resource'),
    queue: value.option('queue'),
    status: value.option('status'),
    identificationStatus: value.option('identification_status'),
    facilityId: value.option('facility_id'),
    storageUnitId: value.option('storage_unit_id'),
    storageSlotId: value.option('storage_slot_id'),
    datePreset: value.option('date_preset'),
  );
}

AppSearchBarFilterValue _filterValueForQuery(MortuaryWorkspaceQuery query) {
  final String defaultResource =
      mortuaryDefaultResourceByPanel[query.panel] ?? mortuaryResourceCases;
  return AppSearchBarFilterValue(
    options: <String, String>{
      if (query.resource.isNotEmpty && query.resource != defaultResource)
        'resource': query.resource,
      if (query.queue != null) 'queue': query.queue!,
      if (query.status != null) 'status': query.status!,
      if (query.identificationStatus != null)
        'identification_status': query.identificationStatus!,
      if (query.facilityId != null) 'facility_id': query.facilityId!,
      if (query.storageUnitId != null) 'storage_unit_id': query.storageUnitId!,
      if (query.storageSlotId != null) 'storage_slot_id': query.storageSlotId!,
      if (query.datePreset != null) 'date_preset': query.datePreset!,
    },
  );
}

bool _hasActiveFilters(MortuaryWorkspaceQuery query) {
  final String defaultResource =
      mortuaryDefaultResourceByPanel[query.panel] ?? mortuaryResourceCases;
  return query.resource != defaultResource ||
      query.queue != null ||
      query.status != null ||
      query.identificationStatus != null ||
      query.facilityId != null ||
      query.storageUnitId != null ||
      query.storageSlotId != null ||
      query.datePreset != null;
}

List<AppSearchBarFilterGroup> _filterGroups(
  AppLocalizations l10n,
  MortuaryLookupData lookups,
) {
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: 'resource',
      label: l10n.mortuaryResourceFilterLabel,
      allLabel: l10n.mortuaryAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        for (final String resource in mortuaryResources)
          AppSearchBarFilterChoice(
            value: resource,
            label: _resourceLabel(l10n, resource),
            icon: _resourceIcon(resource),
          ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'queue',
      label: l10n.mortuaryQueueFilterLabel,
      allLabel: l10n.mortuaryAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        for (final String queue in mortuaryQueues)
          AppSearchBarFilterChoice(
            value: queue,
            label: _queueLabel(l10n, queue),
            icon: _queueIcon(queue),
          ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'status',
      label: l10n.mortuaryStatusFilterLabel,
      allLabel: l10n.mortuaryAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        for (final MortuaryLookupOption option in lookups.statuses)
          AppSearchBarFilterChoice(
            value: option.id,
            label: _displayCode(option.label) ?? option.label,
            icon: Icons.flag_outlined,
          ),
        if (lookups.statuses.isEmpty)
          for (final String status in mortuaryCaseStatuses)
            AppSearchBarFilterChoice(
              value: status,
              label: _displayCode(status) ?? status,
              icon: Icons.flag_outlined,
            ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'identification_status',
      label: l10n.mortuaryIdentificationFilterLabel,
      allLabel: l10n.mortuaryAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        for (final MortuaryLookupOption option
            in lookups.identificationStatuses)
          AppSearchBarFilterChoice(
            value: option.id,
            label: _displayCode(option.label) ?? option.label,
            icon: Icons.badge_outlined,
          ),
        if (lookups.identificationStatuses.isEmpty)
          for (final String status in mortuaryIdentificationStatuses)
            AppSearchBarFilterChoice(
              value: status,
              label: _displayCode(status) ?? status,
              icon: Icons.badge_outlined,
            ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'facility_id',
      label: l10n.mortuaryFacilityFilterLabel,
      allLabel: l10n.mortuaryAllFieldsLabel,
      choices: _lookupChoices(lookups.facilities, Icons.apartment_outlined),
    ),
    AppSearchBarFilterGroup(
      key: 'storage_unit_id',
      label: l10n.mortuaryStorageUnitFilterLabel,
      allLabel: l10n.mortuaryAllFieldsLabel,
      choices: _lookupChoices(lookups.storageUnits, Icons.inventory_outlined),
    ),
    AppSearchBarFilterGroup(
      key: 'storage_slot_id',
      label: l10n.mortuaryStorageSlotFilterLabel,
      allLabel: l10n.mortuaryAllFieldsLabel,
      choices: _lookupChoices(lookups.storageSlots, Icons.grid_view_outlined),
    ),
    AppSearchBarFilterGroup(
      key: 'date_preset',
      label: l10n.mortuaryDatePresetFilterLabel,
      allLabel: l10n.mortuaryAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        for (final String preset in mortuaryDatePresets)
          AppSearchBarFilterChoice(
            value: preset,
            label: _datePresetLabel(l10n, preset),
            icon: Icons.event_outlined,
          ),
      ],
    ),
  ];
}

List<AppSearchBarFilterChoice> _lookupChoices(
  List<MortuaryLookupOption> options,
  IconData icon,
) {
  return <AppSearchBarFilterChoice>[
    for (final MortuaryLookupOption option in options)
      AppSearchBarFilterChoice(
        value: option.id,
        label: option.label,
        icon: icon,
      ),
  ];
}

bool _matchesSearch(
  MortuaryWorkspaceItem item,
  String query, {
  required BuildContext context,
  required String panel,
}) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  return _mortuarySearchHaystack(context, panel, item).any((String value) {
    return value.toLowerCase().contains(normalized);
  });
}

List<String> _mortuarySearchHaystack(
  BuildContext context,
  String panel,
  MortuaryWorkspaceItem item,
) {
  final AppLocalizations l10n = context.l10n;
  return <String?>[
        item.effectiveDisplayId,
        item.id,
        item.effectiveDeceasedLabel,
        item.patientLabel,
        item.deceasedProfileId,
        item.sourceLabel,
        item.receivedFrom,
        item.sourceReferenceId,
        item.sourceDepartment,
        item.sourceWorkflow,
        item.storageLabel,
        item.storageSlotStatus,
        item.storageAssignment?.status,
        item.caseStatus,
        item.status,
        item.caseBillingStatus,
        item.billingStatus,
        item.caseIdentificationStatus,
        item.identificationStatus,
        item.facilityLabel,
        item.eventType,
        item.actorName,
        item.actorRole,
        item.locationLabel,
        item.reason,
        item.notes,
        item.recipientName,
        item.recipientRelationship,
        item.verificationReference,
        item.funeralServiceName,
        item.requestReason,
        item.diagnosticsReferenceId,
        item.requestedByName,
        item.releaseStatus,
        _resourceLabel(l10n, item.resource),
        _nextActionLabel(l10n, item),
        _formatDateTime(context, item.timelineAt),
        _formatDateTime(context, item.eventAt),
        _formatDateTime(context, item.scheduledAt),
        _formatDateTime(context, item.completedAt),
        _formatDateTime(context, item.releasedAt),
        _formatDateTime(context, item.approvedAt),
        _formatDateTime(context, item.storageAssignment?.assignedAt),
        _displayCode(item.caseStatus ?? item.status),
        _displayCode(item.caseBillingStatus ?? item.billingStatus),
        _displayCode(item.eventType),
      ]
      .whereType<String>()
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
}

String _panelLabel(AppLocalizations l10n, String id) {
  return switch (id) {
    mortuaryPanelOverview => l10n.mortuaryPanelOverviewLabel,
    mortuaryPanelIntake => l10n.mortuaryPanelIntakeLabel,
    mortuaryPanelStorage => l10n.mortuaryPanelStorageLabel,
    mortuaryPanelCustody => l10n.mortuaryPanelCustodyLabel,
    mortuaryPanelRelease => l10n.mortuaryPanelReleaseLabel,
    mortuaryPanelReporting => l10n.mortuaryPanelReportingLabel,
    _ => _displayCode(id) ?? id,
  };
}

String _resourceLabel(AppLocalizations l10n, String id) {
  return switch (id) {
    mortuaryResourceCases => l10n.mortuaryResourceCasesLabel,
    mortuaryResourceStorageUnits => l10n.mortuaryResourceStorageUnitsLabel,
    mortuaryResourceStorageSlots => l10n.mortuaryResourceStorageSlotsLabel,
    mortuaryResourceStorageAssignments =>
      l10n.mortuaryResourceStorageAssignmentsLabel,
    mortuaryResourceCustodyEvents => l10n.mortuaryResourceCustodyEventsLabel,
    mortuaryResourceViewings => l10n.mortuaryResourceViewingsLabel,
    mortuaryResourcePostMortemRequests =>
      l10n.mortuaryResourcePostMortemRequestsLabel,
    mortuaryResourceReleaseAuthorisations =>
      l10n.mortuaryResourceReleaseAuthorisationsLabel,
    mortuaryResourceBillableEvents => l10n.mortuaryResourceBillableEventsLabel,
    _ => _displayCode(id) ?? id,
  };
}

String _queueLabel(AppLocalizations l10n, String id) {
  return switch (id) {
    mortuaryQueueIdentificationPending =>
      l10n.mortuaryQueueIdentificationPendingLabel,
    mortuaryQueueStorageExceptions => l10n.mortuaryQueueStorageExceptionsLabel,
    mortuaryQueueReleaseReady => l10n.mortuaryQueueReleaseReadyLabel,
    mortuaryQueueUnsettledBilling => l10n.mortuaryQueueUnsettledBillingLabel,
    mortuaryQueuePostMortemPending => l10n.mortuaryQueuePostMortemPendingLabel,
    _ => _displayCode(id) ?? id,
  };
}

String _datePresetLabel(AppLocalizations l10n, String id) {
  return switch (id) {
    'today' => l10n.mortuaryDatePresetTodayLabel,
    'next_7_days' => l10n.mortuaryDatePresetNext7DaysLabel,
    'overdue' => l10n.mortuaryDatePresetOverdueLabel,
    'this_month' => l10n.mortuaryDatePresetThisMonthLabel,
    _ => _displayCode(id) ?? id,
  };
}

IconData _panelIcon(String id) {
  return switch (id) {
    mortuaryPanelIntake => Icons.inbox_outlined,
    mortuaryPanelStorage => Icons.inventory_2_outlined,
    mortuaryPanelCustody => Icons.swap_horiz_outlined,
    mortuaryPanelRelease => Icons.outbox_outlined,
    mortuaryPanelReporting => Icons.fact_check_outlined,
    _ => Icons.dashboard_outlined,
  };
}

IconData _resourceIcon(String id) {
  return switch (id) {
    mortuaryResourceStorageUnits => Icons.inventory_outlined,
    mortuaryResourceStorageSlots => Icons.grid_view_outlined,
    mortuaryResourceStorageAssignments => Icons.inventory_2_outlined,
    mortuaryResourceCustodyEvents => Icons.swap_horiz_outlined,
    mortuaryResourceViewings => Icons.event_available_outlined,
    mortuaryResourcePostMortemRequests => Icons.fact_check_outlined,
    mortuaryResourceReleaseAuthorisations => Icons.outbox_outlined,
    mortuaryResourceBillableEvents => Icons.receipt_long_outlined,
    _ => Icons.assignment_outlined,
  };
}

IconData _queueIcon(String queue) {
  return switch (queue) {
    mortuaryQueueIdentificationPending => Icons.badge_outlined,
    mortuaryQueueStorageExceptions => Icons.inventory_2_outlined,
    mortuaryQueueReleaseReady => Icons.outbox_outlined,
    mortuaryQueueUnsettledBilling => Icons.receipt_long_outlined,
    mortuaryQueuePostMortemPending => Icons.fact_check_outlined,
    _ => Icons.flag_outlined,
  };
}

AppWorkspaceStatusTone _statusTone(String? status) {
  return switch (_normalized(status)) {
    'RELEASED' ||
    'CLOSED' ||
    'COMPLETED' ||
    'APPROVED' ||
    'VERIFIED' => AppWorkspaceStatusTone.success,
    'CANCELLED' || 'OUT_OF_SERVICE' => AppWorkspaceStatusTone.error,
    'READY_FOR_RELEASE' ||
    'IN_STORAGE' ||
    'ACTIVE' ||
    'SCHEDULED' => AppWorkspaceStatusTone.info,
    'IDENTIFICATION_PENDING' ||
    'POST_MORTEM_PENDING' ||
    'REQUESTED' ||
    'PARTIAL' ||
    'UNVERIFIED' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _identificationTone(String? status) {
  return switch (_normalized(status)) {
    'VERIFIED' => AppWorkspaceStatusTone.success,
    'PARTIAL' => AppWorkspaceStatusTone.warning,
    'UNVERIFIED' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _billingTone(String? status) {
  return switch (_normalized(status)) {
    'SETTLED' || 'PAID' || 'CANCELLED' => AppWorkspaceStatusTone.success,
    'PENDING' || 'UNSETTLED' || 'PARTIAL' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String _nextActionLabel(AppLocalizations l10n, MortuaryWorkspaceItem item) {
  final String? status = _normalized(item.caseStatus ?? item.status);
  final String? billingStatus = _normalized(
    item.caseBillingStatus ?? item.billingStatus,
  );
  final String? identification = _normalized(item.caseIdentificationStatus);
  if (identification != null && identification != 'VERIFIED') {
    return l10n.mortuaryNextActionVerifyIdentity;
  }
  if (item.storageLabel == null && status != 'RELEASED') {
    return l10n.mortuaryNextActionAssignStorage;
  }
  if (status == 'POST_MORTEM_PENDING') {
    return l10n.mortuaryNextActionPostMortem;
  }
  if (billingStatus != null &&
      !<String>{'SETTLED', 'PAID', 'CANCELLED'}.contains(billingStatus)) {
    return l10n.mortuaryNextActionClearBilling;
  }
  if (status == 'READY_FOR_RELEASE') {
    return l10n.mortuaryNextActionApproveRelease;
  }
  if (status == 'RELEASED' || status == 'CLOSED') {
    return l10n.mortuaryNextActionReleased;
  }
  return l10n.mortuaryNextActionReview;
}

Future<void> _printItem(
  BuildContext context,
  WidgetRef ref,
  MortuaryWorkspaceItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  await PrintDocumentTemplates.mortuaryCase(
    ref: ref,
    context: context,
    title: l10n.mortuaryReportTitle,
    deceasedContext: buildPrintFormPatientContext(
      l10n,
      patientName:
          item.effectiveDeceasedLabel ?? l10n.mortuaryUnknownDeceasedLabel,
      patientNameLabel: l10n.mortuaryDeceasedFieldLabel,
    ),
    caseReference: PrintFormContextReference(
      label: l10n.mortuaryCaseFieldLabel,
      value: _mortuaryCaseIdentifier(item) ?? l10n.mortuaryUnknownValueLabel,
    ),
    bodyHtml: _reportBodyHtml(context, l10n, item),
    footerNote: l10n.mortuaryReportFooter,
    includeSignatures: true,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.mortuaryReportGeneratedMessage)),
    );
  }
}

String _reportBodyHtml(
  BuildContext context,
  AppLocalizations l10n,
  MortuaryWorkspaceItem item,
) {
  return <String>[
    PrintFormTemplate.section(
      title: l10n.mortuaryIdentitySectionTitle,
      bodyHtml: PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
        PrintFormMetadataItem(
          label: l10n.mortuaryCaseFieldLabel,
          value:
              _mortuaryCaseIdentifier(item) ?? l10n.mortuaryUnknownValueLabel,
        ),
        PrintFormMetadataItem(
          label: l10n.mortuaryDeceasedFieldLabel,
          value:
              item.effectiveDeceasedLabel ?? l10n.mortuaryUnknownDeceasedLabel,
        ),
        PrintFormMetadataItem(
          label: l10n.mortuaryPatientFieldLabel,
          value: item.patientLabel ?? l10n.mortuaryUnknownValueLabel,
        ),
        PrintFormMetadataItem(
          label: l10n.mortuaryReceivedAtFieldLabel,
          value: _formatDateTime(context, item.receivedAt),
        ),
      ]),
    ),
    PrintFormTemplate.section(
      title: l10n.mortuaryStorageSectionTitle,
      bodyHtml: PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
        PrintFormMetadataItem(
          label: l10n.mortuaryStorageUnitFieldLabel,
          value: item.storageUnitLabel ?? l10n.mortuaryUnknownValueLabel,
        ),
        PrintFormMetadataItem(
          label: l10n.mortuaryStorageSlotFieldLabel,
          value: item.storageSlotLabel ?? l10n.mortuaryUnknownValueLabel,
        ),
        PrintFormMetadataItem(
          label: l10n.mortuaryStorageStatusFieldLabel,
          value:
              _displayCode(item.storageSlotStatus) ??
              l10n.mortuaryUnknownValueLabel,
        ),
      ]),
    ),
    PrintFormTemplate.section(
      title: l10n.mortuaryCustodySectionTitle,
      bodyHtml: PrintFormTemplate.table(
        headers: <String>[
          l10n.mortuaryStatusFieldLabel,
          l10n.mortuaryDateColumnLabel,
          l10n.mortuaryActorFieldLabel,
          l10n.mortuaryLocationFieldLabel,
          l10n.mortuaryNotesFieldLabel,
        ],
        rows: <List<String>>[
          for (final MortuaryTimelineEvent event in item.custodyEvents)
            <String>[
              _displayCode(event.eventType) ?? l10n.mortuaryUnknownValueLabel,
              _formatDateTime(context, event.eventAt),
              event.actorName ?? l10n.mortuaryUnknownValueLabel,
              event.locationLabel ?? l10n.mortuaryUnknownValueLabel,
              event.notes ?? event.reason ?? l10n.mortuaryUnknownValueLabel,
            ],
        ],
        emptyText: l10n.mortuaryNoCustodyEventsLabel,
      ),
    ),
    PrintFormTemplate.section(
      title: l10n.mortuaryReleaseSectionTitle,
      bodyHtml: PrintFormTemplate.table(
        headers: <String>[
          l10n.mortuaryReleaseFieldLabel,
          l10n.mortuaryReleasedAtFieldLabel,
          l10n.mortuaryDeceasedFieldLabel,
          l10n.mortuarySourceReferenceFieldLabel,
        ],
        rows: <List<String>>[
          for (final MortuaryReleaseAuthorisation release
              in item.releaseAuthorisations)
            <String>[
              _displayCode(release.status) ?? l10n.mortuaryUnknownValueLabel,
              _formatDateTime(context, release.releasedAt),
              release.recipientName ?? l10n.mortuaryUnknownValueLabel,
              release.verificationReference ?? l10n.mortuaryUnknownValueLabel,
            ],
        ],
        emptyText: l10n.mortuaryNoReleaseLabel,
      ),
    ),
  ].join();
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  showAppFailureSnackBar(context, failure);
}

String _formatDateTime(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.mortuaryUnknownValueLabel;
  }
  return AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String? _formatAmount(BuildContext context, String? amount, String? currency) {
  if (amount == null || amount.trim().isEmpty) {
    return null;
  }
  final num? parsed = num.tryParse(amount);
  if (parsed == null) {
    return currency == null ? amount : '$currency $amount';
  }
  return AppFormatters.currency(
    parsed,
    Localizations.localeOf(context),
    currencyCode: currency,
  );
}

String? _mortuaryPublicIdentifier(MortuaryWorkspaceItem item) {
  return _nonEmpty(item.displayId);
}

String? _mortuaryCaseIdentifier(MortuaryWorkspaceItem item) {
  if (item.isCase) {
    return _nonEmpty(item.displayId);
  }
  return _nonEmpty(item.mortuaryCase?.id);
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _displayCode(String? value) {
  final String? normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final String spaced = normalized
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .toLowerCase();
  final List<String> words = spaced
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .toList(growable: false);
  return words
      .map((String word) {
        if (word.length == 1) {
          return word.toUpperCase();
        }
        return '${word.substring(0, 1).toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}

String? _normalized(String? value) {
  final String? normalized = value?.trim().toUpperCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _joinValues(Iterable<String?> values) {
  final List<String> visible = values
      .map((String? value) => value?.trim())
      .whereType<String>()
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
  return visible.isEmpty ? null : visible.join(' | ');
}

MortuaryWorkspaceState? _mortuaryStateFromAsync(
  AsyncValue<Result<MortuaryWorkspaceState>> asyncState,
) {
  return asyncState.asData?.value.when(
    success: (MortuaryWorkspaceState state) => state,
    failure: (_) => null,
  );
}

List<Widget> _withMortuaryDetailSectionSpacing(
  BuildContext context,
  List<Widget> sections,
) {
  return appCollapsibleSectionSpacing(context, sections);
}
