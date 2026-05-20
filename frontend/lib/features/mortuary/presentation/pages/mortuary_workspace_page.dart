import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/presentation/controllers/mortuary_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class MortuaryWorkspacePage extends ConsumerWidget {
  const MortuaryWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<MortuaryWorkspaceState>> workspace = ref.watch(
      mortuaryWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return workspace.when(
      data: (Result<MortuaryWorkspaceState> result) {
        return result.when(
          success: (MortuaryWorkspaceState state) {
            return _MortuaryWorkspaceContent(state: state);
          },
          failure: (AppFailure failure) {
            return ResponsivePage(
              maxWidth: PageMaxWidth.form,
              centerVertically: true,
              child: AppFailureStateView(
                failure: failure,
                title: l10n.mortuaryLoadErrorTitle,
                body: l10n.mortuaryLoadErrorBody,
                onRetry: () {
                  ref.invalidate(mortuaryWorkspaceControllerProvider);
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
            title: l10n.mortuaryLoadErrorTitle,
            body: l10n.errorUnexpectedMessage,
          ),
        );
      },
      loading: () {
        return ResponsivePage(
          maxWidth: PageMaxWidth.form,
          centerVertically: true,
          child: AppWorkspaceStatePanel.loading(
            title: l10n.mortuaryLoadingTitle,
            body: l10n.mortuaryLoadingBody,
          ),
        );
      },
    );
  }
}

class _MortuaryWorkspaceContent extends ConsumerStatefulWidget {
  const _MortuaryWorkspaceContent({required this.state});

  final MortuaryWorkspaceState state;

  @override
  ConsumerState<_MortuaryWorkspaceContent> createState() {
    return _MortuaryWorkspaceContentState();
  }
}

class _MortuaryWorkspaceContentState
    extends ConsumerState<_MortuaryWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<MortuaryWorkspaceItem>
  _tableColumnController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<MortuaryWorkspaceItem>();
  }

  @override
  void didUpdateWidget(covariant _MortuaryWorkspaceContent oldWidget) {
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
    final MortuaryWorkspaceState state = widget.state;
    final MortuaryWorkspaceController controller = ref.read(
      mortuaryWorkspaceControllerProvider.notifier,
    );

    return AppWorkspace(
      title: l10n.mortuaryTitle,
      leadingIcon: AppRouteIcons.mortuary,
      status: AppWorkspaceStatus(
        label: state.lastFailure == null
            ? l10n.mortuaryOperationalStatusLabel
            : l10n.mortuaryAttentionStatusLabel,
        tone: state.lastFailure == null
            ? AppWorkspaceStatusTone.success
            : AppWorkspaceStatusTone.warning,
      ),
      primaryAction: AppPermissionActionButton(
        requirement: _exportRequirement,
        label: l10n.mortuaryPrintDocumentsAction,
        icon: Icons.print_outlined,
        variant: AppButtonVariant.primary,
        enabled: state.selectedItem != null,
        onPressed: state.selectedItem == null
            ? null
            : () {
                unawaited(_printItem(context, ref, state.selectedItem!));
              },
      ),
      secondaryActions: <Widget>[
        AppPermissionActionButton(
          requirement: _writeRequirement,
          label: l10n.mortuaryReceiveCaseAction,
          icon: Icons.inbox_outlined,
          enabled: false,
          tooltip: l10n.mortuaryActionsUnavailableTooltip,
          onPressed: null,
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
        for (final MortuarySummaryItem item in state.summary)
          AppWorkspaceSummaryCard(
            compact: true,
            label: _summaryLabel(l10n, item.id),
            value: item.value.toString(),
            icon: _summaryIcon(item.id),
            tone: _summaryTone(item.id),
            onPressed: item.id == 'total_cases'
                ? () {
                    unawaited(controller.switchPanel(mortuaryPanelOverview));
                  }
                : null,
          ),
        for (final MortuaryQueueSummary queue in state.spotlight)
          if (queue.count > 0)
            AppWorkspaceSummaryCard(
              compact: true,
              label: _queueLabel(l10n, queue.queue),
              value: queue.count.toString(),
              icon: _queueIcon(queue.queue),
              tone: _queueTone(queue.queue),
              onPressed: () {
                unawaited(controller.applyQueue(queue.queue));
              },
            ),
      ],
      body: _MortuaryWorklist(
        state: state,
        controller: controller,
        searchController: _searchController,
        tableColumnController: _tableColumnController,
      ),
      detail: _MortuaryDetailPanel(
        state: state,
        onPrint: state.selectedItem == null
            ? null
            : () {
                unawaited(_printItem(context, ref, state.selectedItem!));
              },
      ),
    );
  }
}

class _MortuaryWorklist extends StatelessWidget {
  const _MortuaryWorklist({
    required this.state,
    required this.controller,
    required this.searchController,
    required this.tableColumnController,
  });

  final MortuaryWorkspaceState state;
  final MortuaryWorkspaceController controller;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<MortuaryWorkspaceItem>
  tableColumnController;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppListTableColumn<MortuaryWorkspaceItem>> columns =
        _columns(context);

    return AppWorkspaceDetailPanel(
      title: l10n.mortuaryWorklistTitle,
      description: _resourceLabel(l10n, state.query.resource),
      child: AppListTable<MortuaryWorkspaceItem>(
        page: state.items,
        columns: columns,
        columnChoices: columns,
        columnVisibilityController: tableColumnController,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        columnVisibilityTitle: l10n.commonTableSettingsActionLabel,
        columnVisibilityApplyLabel: l10n.mortuaryApplyFiltersAction,
        columnVisibilityResetLabel: l10n.mortuaryResetFiltersAction,
        columnVisibilityCancelLabel: l10n.commonCancelActionLabel,
        isLoading: state.isRefreshing,
        itemKeyBuilder: (MortuaryWorkspaceItem item) =>
            ValueKey<String>('${item.resource}:${item.id}'),
        onRowSelected: (MortuaryWorkspaceItem item) {
          unawaited(controller.selectItem(item));
        },
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
          matcher: _matchesSearch,
          onSubmitted: (String value) {
            unawaited(controller.applySearch(value));
          },
          onClear: () {
            unawaited(controller.applySearch(''));
          },
          isLoading: state.isRefreshing,
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.mortuaryFiltersLabel,
          advancedFilterTitle: l10n.mortuaryFiltersLabel,
          advancedFilterApplyLabel: l10n.mortuaryApplyFiltersAction,
          advancedFilterResetLabel: l10n.mortuaryResetFiltersAction,
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
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
          trailingActions: <AppSearchBarAction>[
            tableColumnController.settingsAction(
              context,
              label: l10n.commonTableSettingsActionLabel,
              title: l10n.commonTableSettingsActionLabel,
              applyLabel: l10n.mortuaryApplyFiltersAction,
              resetLabel: l10n.mortuaryResetFiltersAction,
              cancelLabel: l10n.commonCancelActionLabel,
            ),
          ],
        ),
        emptyBuilder: (BuildContext context) {
          return AppWorkspaceStatePanel.empty(
            title: l10n.mortuaryWorklistEmptyTitle,
            body: l10n.mortuaryWorklistEmptyBody,
          );
        },
        mobileItemBuilder: (BuildContext context, MortuaryWorkspaceItem item) {
          return _MortuaryMobileListItem(item: item);
        },
      ),
    );
  }

  List<AppListTableColumn<MortuaryWorkspaceItem>> _columns(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    return <AppListTableColumn<MortuaryWorkspaceItem>>[
      AppListTableColumn<MortuaryWorkspaceItem>(
        id: 'reference',
        label: l10n.mortuaryReferenceColumnLabel,
        sortComparator: (MortuaryWorkspaceItem left, MortuaryWorkspaceItem right) {
          return appListTableCompareText(
            left.effectiveDisplayId,
            right.effectiveDisplayId,
          );
        },
        cellBuilder: (_, MortuaryWorkspaceItem item) {
          return _ReferenceCell(item: item);
        },
      ),
      AppListTableColumn<MortuaryWorkspaceItem>(
        id: 'deceased',
        label: l10n.mortuaryDeceasedColumnLabel,
        sortComparator: (MortuaryWorkspaceItem left, MortuaryWorkspaceItem right) {
          return appListTableCompareText(
            left.effectiveDeceasedLabel,
            right.effectiveDeceasedLabel,
          );
        },
        cellBuilder: (_, MortuaryWorkspaceItem item) {
          return _TwoLineCell(
            title: item.effectiveDeceasedLabel ?? l10n.mortuaryUnknownDeceasedLabel,
            subtitle: item.patientLabel ?? item.deceasedProfileId,
          );
        },
      ),
      AppListTableColumn<MortuaryWorkspaceItem>(
        id: 'source',
        label: l10n.mortuarySourceColumnLabel,
        cellBuilder: (_, MortuaryWorkspaceItem item) {
          return _TwoLineCell(
            title: item.sourceLabel ?? l10n.mortuaryUnknownValueLabel,
            subtitle: item.receivedFrom,
          );
        },
      ),
      AppListTableColumn<MortuaryWorkspaceItem>(
        id: 'storage',
        label: l10n.mortuaryStorageColumnLabel,
        cellBuilder: (_, MortuaryWorkspaceItem item) {
          return _TwoLineCell(
            title: item.storageLabel ?? l10n.mortuaryUnknownValueLabel,
            subtitle: _displayCode(
              item.storageSlotStatus ?? item.storageAssignment?.status,
            ),
          );
        },
      ),
      AppListTableColumn<MortuaryWorkspaceItem>(
        id: 'status',
        label: l10n.mortuaryStatusColumnLabel,
        cellBuilder: (_, MortuaryWorkspaceItem item) {
          return Wrap(
            spacing: Theme.of(context).spacing.xs,
            runSpacing: Theme.of(context).spacing.xs,
            children: <Widget>[
              AppWorkspaceStatusBadge(
                status: AppWorkspaceStatus(
                  label:
                      _displayCode(item.caseStatus ?? item.status) ??
                      l10n.mortuaryUnknownValueLabel,
                  tone: _statusTone(item.caseStatus ?? item.status),
                ),
              ),
              if ((item.caseBillingStatus ?? item.billingStatus) != null)
                AppWorkspaceStatusBadge(
                  status: AppWorkspaceStatus(
                    label:
                        _displayCode(item.caseBillingStatus ?? item.billingStatus) ??
                        l10n.mortuaryUnknownValueLabel,
                    tone: _billingTone(item.caseBillingStatus ?? item.billingStatus),
                  ),
                ),
            ],
          );
        },
      ),
      AppListTableColumn<MortuaryWorkspaceItem>(
        id: 'date',
        label: l10n.mortuaryDateColumnLabel,
        sortComparator: (MortuaryWorkspaceItem left, MortuaryWorkspaceItem right) {
          return appListTableCompareDateTime(left.timelineAt, right.timelineAt);
        },
        cellBuilder: (_, MortuaryWorkspaceItem item) {
          return Text(_formatDateTime(context, item.timelineAt));
        },
      ),
      AppListTableColumn<MortuaryWorkspaceItem>(
        id: 'nextAction',
        label: l10n.mortuaryNextActionColumnLabel,
        cellBuilder: (_, MortuaryWorkspaceItem item) {
          return Text(_nextActionLabel(l10n, item));
        },
      ),
    ];
  }
}

class _MortuaryMobileListItem extends StatelessWidget {
  const _MortuaryMobileListItem({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        item.effectiveDeceasedLabel ?? l10n.mortuaryUnknownDeceasedLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        <String>[
          item.effectiveDisplayId,
          if (item.storageLabel != null) item.storageLabel!,
          _displayCode(item.caseStatus ?? item.status) ??
              l10n.mortuaryUnknownValueLabel,
        ].join(' | '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _MortuaryDetailPanel extends StatelessWidget {
  const _MortuaryDetailPanel({required this.state, required this.onPrint});

  final MortuaryWorkspaceState state;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final MortuaryWorkspaceItem? item = state.selectedItem;
    if (item == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.mortuaryDetailTitle,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.mortuaryNoSelectionTitle,
          body: l10n.mortuaryNoSelectionBody,
        ),
      );
    }

    final ThemeData theme = Theme.of(context);
    return AppWorkspaceDetailPanel(
      title: l10n.mortuaryDetailTitle,
      description: item.effectiveDisplayId,
      actions: <Widget>[
        AppPermissionActionButton(
          requirement: _exportRequirement,
          label: l10n.mortuaryPrintDocumentsAction,
          icon: Icons.print_outlined,
          onPressed: onPrint,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state.isRefreshingDetail) const LinearProgressIndicator(),
          AppWorkspacePatientContextHeader(
            patientName:
                item.effectiveDeceasedLabel ?? l10n.mortuaryUnknownDeceasedLabel,
            patientNumber: item.caseId ?? item.effectiveDisplayId,
            patientNumberLabel: l10n.mortuaryCaseNumberLabel,
            semanticLabel: l10n.mortuaryDeceasedContextLabel,
            status: AppWorkspaceStatus(
              label:
                  _displayCode(item.caseStatus ?? item.status) ??
                  l10n.mortuaryUnknownValueLabel,
              tone: _statusTone(item.caseStatus ?? item.status),
            ),
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.mortuaryIdentificationFieldLabel,
                value:
                    _displayCode(item.caseIdentificationStatus) ??
                    l10n.mortuaryUnknownValueLabel,
                icon: Icons.badge_outlined,
                tone: _identificationTone(item.caseIdentificationStatus),
              ),
              AppWorkspacePatientContextField(
                label: l10n.mortuaryBillingFieldLabel,
                value:
                    _displayCode(item.caseBillingStatus) ??
                    l10n.mortuaryUnknownValueLabel,
                icon: Icons.receipt_long_outlined,
                tone: _billingTone(item.caseBillingStatus),
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
            ],
          ),
          SizedBox(height: theme.spacing.md),
          _ActionGapPanel(item: item),
          SizedBox(height: theme.spacing.md),
          _IdentitySection(item: item),
          SizedBox(height: theme.spacing.md),
          _StorageSection(item: item),
          SizedBox(height: theme.spacing.md),
          _CustodySection(item: item),
          SizedBox(height: theme.spacing.md),
          _ViewingSection(item: item),
          SizedBox(height: theme.spacing.md),
          _PostMortemSection(item: item),
          SizedBox(height: theme.spacing.md),
          _ReleaseSection(item: item),
          SizedBox(height: theme.spacing.md),
          _BillingSection(item: item),
          SizedBox(height: theme.spacing.md),
          _DocumentsSection(item: item),
        ],
      ),
    );
  }
}

class _ActionGapPanel extends StatelessWidget {
  const _ActionGapPanel({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppMessagePanel(
      title: l10n.mortuaryActionGapTitle,
      message: l10n.mortuaryActionGapBody,
      tone: AppWorkspaceStatusTone.warning,
      children: <Widget>[
        Wrap(
          spacing: Theme.of(context).spacing.sm,
          runSpacing: Theme.of(context).spacing.sm,
          children: <Widget>[
            _disabledAction(
              l10n.mortuaryReceiveCaseAction,
              Icons.inbox_outlined,
              _writeRequirement,
              l10n,
            ),
            _disabledAction(
              l10n.mortuaryAssignStorageAction,
              Icons.inventory_2_outlined,
              _storageRequirement,
              l10n,
            ),
            _disabledAction(
              l10n.mortuaryRecordCustodyAction,
              Icons.swap_horiz_outlined,
              _writeRequirement,
              l10n,
            ),
            _disabledAction(
              l10n.mortuaryScheduleViewingAction,
              Icons.event_available_outlined,
              _writeRequirement,
              l10n,
            ),
            _disabledAction(
              l10n.mortuaryPostMortemAction,
              Icons.fact_check_outlined,
              _postMortemRequirement,
              l10n,
            ),
            _disabledAction(
              l10n.mortuaryRequestBillingAction,
              Icons.request_quote_outlined,
              _billingRequirement,
              l10n,
            ),
            _disabledAction(
              l10n.mortuaryApproveReleaseAction,
              Icons.verified_outlined,
              _approveRequirement,
              l10n,
            ),
            _disabledAction(
              l10n.mortuaryConfirmReleaseAction,
              Icons.outbox_outlined,
              _releaseRequirement,
              l10n,
            ),
          ],
        ),
      ],
    );
  }

  Widget _disabledAction(
    String label,
    IconData icon,
    AccessRequirement requirement,
    AppLocalizations l10n,
  ) {
    return AppPermissionActionButton(
      requirement: requirement,
      label: label,
      icon: icon,
      enabled: false,
      tooltip: l10n.mortuaryActionsUnavailableTooltip,
      onPressed: null,
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppSectionPanel(
      title: l10n.mortuaryIdentitySectionTitle,
      leadingIcon: Icons.person_outline,
      children: <Widget>[
        AppInfoTileGrid(
          emptyValue: l10n.mortuaryUnknownValueLabel,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: l10n.mortuaryCaseFieldLabel,
              value: item.caseId ?? item.effectiveDisplayId,
              icon: Icons.tag_outlined,
            ),
            AppInfoTileData(
              label: l10n.mortuaryDeceasedFieldLabel,
              value: item.effectiveDeceasedLabel,
              icon: Icons.person_outline,
            ),
            AppInfoTileData(
              label: l10n.mortuaryPatientFieldLabel,
              value: item.patientLabel ?? item.patientId,
              icon: Icons.assignment_ind_outlined,
            ),
            AppInfoTileData(
              label: l10n.mortuaryFacilityFieldLabel,
              value: item.facilityLabel,
              icon: Icons.apartment_outlined,
            ),
            AppInfoTileData(
              label: l10n.mortuaryStatusFieldLabel,
              value: _displayCode(item.caseStatus ?? item.status),
              icon: Icons.flag_outlined,
            ),
            AppInfoTileData(
              label: l10n.mortuaryReceivedAtFieldLabel,
              value: _formatDateTime(context, item.receivedAt),
              icon: Icons.schedule_outlined,
            ),
          ],
        ),
        AppInfoTileGrid(
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
            ),
            AppInfoTileData(
              label: l10n.mortuaryReceivedFromFieldLabel,
              value: item.receivedFrom,
              icon: Icons.move_to_inbox_outlined,
            ),
          ],
        ),
      ],
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
    return AppSectionPanel(
      title: l10n.mortuaryStorageSectionTitle,
      leadingIcon: Icons.inventory_2_outlined,
      children: <Widget>[
        AppInfoTileGrid(
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
      ],
    );
  }
}

class _CustodySection extends StatelessWidget {
  const _CustodySection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> events = item.custodyEvents.map((
      MortuaryTimelineEvent event,
    ) {
      return AppWorkspaceActivityItem(
        title:
            _displayCode(event.eventType) ?? l10n.mortuaryCustodySectionTitle,
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
    }).toList(growable: false);

    return AppWorkspaceActivityList(
      title: l10n.mortuaryCustodySectionTitle,
      emptyTitle: l10n.mortuaryNoCustodyEventsLabel,
      emptyBody: l10n.mortuaryNoCustodyEventsBody,
      items: events,
    );
  }
}

class _ViewingSection extends StatelessWidget {
  const _ViewingSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> events = item.viewings.map((
      MortuaryViewing viewing,
    ) {
      return AppWorkspaceActivityItem(
        title: _displayCode(viewing.status) ?? l10n.mortuaryViewingSectionTitle,
        subtitle: _formatDateTime(context, viewing.scheduledAt),
        description: _joinValues(<String?>[
          viewing.authorisedByName,
          viewing.attendeeSummary,
          _formatDateTime(context, viewing.completedAt),
        ]),
        icon: Icons.event_available_outlined,
        tone: _statusTone(viewing.status),
      );
    }).toList(growable: false);

    return AppWorkspaceActivityList(
      title: l10n.mortuaryViewingSectionTitle,
      emptyTitle: l10n.mortuaryNoViewingsLabel,
      emptyBody: l10n.mortuaryNoViewingsBody,
      items: events,
    );
  }
}

class _PostMortemSection extends StatelessWidget {
  const _PostMortemSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> events = item.postMortemRequests.map((
      MortuaryPostMortemRequest request,
    ) {
      return AppWorkspaceActivityItem(
        title:
            _displayCode(request.status) ?? l10n.mortuaryPostMortemSectionTitle,
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
    }).toList(growable: false);

    return AppWorkspaceActivityList(
      title: l10n.mortuaryPostMortemSectionTitle,
      emptyTitle: l10n.mortuaryNoPostMortemLabel,
      emptyBody: l10n.mortuaryNoPostMortemBody,
      items: events,
    );
  }
}

class _ReleaseSection extends StatelessWidget {
  const _ReleaseSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> events = item.releaseAuthorisations.map((
      MortuaryReleaseAuthorisation release,
    ) {
      return AppWorkspaceActivityItem(
        title: _displayCode(release.status) ?? l10n.mortuaryReleaseSectionTitle,
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
    }).toList(growable: false);

    return AppWorkspaceActivityList(
      title: l10n.mortuaryReleaseSectionTitle,
      emptyTitle: l10n.mortuaryNoReleaseLabel,
      emptyBody: l10n.mortuaryNoReleaseBody,
      items: events,
    );
  }
}

class _BillingSection extends StatelessWidget {
  const _BillingSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppWorkspaceActivityItem> events = item.billableEvents.map((
      MortuaryBillableEvent event,
    ) {
      return AppWorkspaceActivityItem(
        title: _displayCode(event.status) ?? l10n.mortuaryBillingSectionTitle,
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
    }).toList(growable: false);

    return AppWorkspaceActivityList(
      title: l10n.mortuaryBillingSectionTitle,
      emptyTitle: l10n.mortuaryNoBillingLabel,
      emptyBody: l10n.mortuaryNoBillingBody,
      items: events,
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppSectionPanel(
      title: l10n.mortuaryDocumentsSectionTitle,
      leadingIcon: Icons.description_outlined,
      children: <Widget>[
        AppInfoTileGrid(
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
      ],
    );
  }
}

class _ReferenceCell extends StatelessWidget {
  const _ReferenceCell({required this.item});

  final MortuaryWorkspaceItem item;

  @override
  Widget build(BuildContext context) {
    return _TwoLineCell(
      title: item.effectiveDisplayId,
      subtitle: _resourceLabel(context.l10n, item.resource),
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
    panel: value.option('panel'),
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
  return AppSearchBarFilterValue(
    options: <String, String>{
      'panel': query.panel,
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
  return query.panel != mortuaryPanelOverview ||
      query.resource != mortuaryResourceCases ||
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
      key: 'panel',
      label: l10n.mortuaryPanelFilterLabel,
      allLabel: l10n.mortuaryAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        for (final String panel in mortuaryPanels)
          AppSearchBarFilterChoice(
            value: panel,
            label: _panelLabel(l10n, panel),
            icon: _panelIcon(panel),
          ),
      ],
    ),
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
      AppSearchBarFilterChoice(value: option.id, label: option.label, icon: icon),
  ];
}

bool _matchesSearch(MortuaryWorkspaceItem item, String query) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  return <String?>[
    item.effectiveDisplayId,
    item.effectiveDeceasedLabel,
    item.patientLabel,
    item.sourceLabel,
    item.storageLabel,
    item.caseStatus,
    item.caseBillingStatus,
    item.facilityLabel,
  ].whereType<String>().any((String value) {
    return value.toLowerCase().contains(normalized);
  });
}

String _summaryLabel(AppLocalizations l10n, String id) {
  return switch (id) {
    'total_cases' => l10n.mortuaryTotalCasesSummaryLabel,
    'identification_pending' => l10n.mortuaryIdentificationPendingSummaryLabel,
    'in_storage' => l10n.mortuaryInStorageSummaryLabel,
    'release_ready' => l10n.mortuaryReleaseReadySummaryLabel,
    'unsettled_billing' => l10n.mortuaryUnsettledBillingSummaryLabel,
    _ => _displayCode(id) ?? id,
  };
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
    mortuaryQueueStorageExceptions =>
      l10n.mortuaryQueueStorageExceptionsLabel,
    mortuaryQueueReleaseReady => l10n.mortuaryQueueReleaseReadyLabel,
    mortuaryQueueUnsettledBilling =>
      l10n.mortuaryQueueUnsettledBillingLabel,
    mortuaryQueuePostMortemPending =>
      l10n.mortuaryQueuePostMortemPendingLabel,
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

IconData _summaryIcon(String id) {
  return switch (id) {
    'identification_pending' => Icons.badge_outlined,
    'in_storage' => Icons.inventory_2_outlined,
    'release_ready' => Icons.outbox_outlined,
    'unsettled_billing' => Icons.receipt_long_outlined,
    _ => Icons.assignment_outlined,
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

AppWorkspaceStatusTone _summaryTone(String id) {
  return switch (id) {
    'identification_pending' || 'unsettled_billing' => AppWorkspaceStatusTone.warning,
    'release_ready' => AppWorkspaceStatusTone.success,
    'in_storage' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _queueTone(String queue) {
  return switch (queue) {
    mortuaryQueueReleaseReady => AppWorkspaceStatusTone.success,
    mortuaryQueueStorageExceptions ||
    mortuaryQueueUnsettledBilling ||
    mortuaryQueuePostMortemPending ||
    mortuaryQueueIdentificationPending => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _statusTone(String? status) {
  return switch (_normalized(status)) {
    'RELEASED' || 'CLOSED' || 'COMPLETED' || 'APPROVED' || 'VERIFIED' =>
      AppWorkspaceStatusTone.success,
    'CANCELLED' || 'OUT_OF_SERVICE' => AppWorkspaceStatusTone.error,
    'READY_FOR_RELEASE' || 'IN_STORAGE' || 'ACTIVE' || 'SCHEDULED' =>
      AppWorkspaceStatusTone.info,
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
  final String? billingStatus = _normalized(item.caseBillingStatus);
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
  await printFormTemplateDocument(
    ref: ref,
    context: context,
    title: l10n.mortuaryReportTitle,
    subtitle: item.effectiveDisplayId,
    metadata: <PrintFormMetadataItem>[
      PrintFormMetadataItem(
        label: l10n.mortuaryCaseFieldLabel,
        value: item.caseId ?? item.effectiveDisplayId,
      ),
      PrintFormMetadataItem(
        label: l10n.mortuaryDeceasedFieldLabel,
        value: item.effectiveDeceasedLabel ?? l10n.mortuaryUnknownDeceasedLabel,
      ),
      PrintFormMetadataItem(
        label: l10n.mortuaryStatusFieldLabel,
        value:
            _displayCode(item.caseStatus ?? item.status) ??
            l10n.mortuaryUnknownValueLabel,
      ),
    ],
    bodyHtml: _reportBodyHtml(context, l10n, item),
    footerNote: l10n.mortuaryReportFooter,
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
          value: item.caseId ?? item.effectiveDisplayId,
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
  if (failure == null) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${l10n.failureTitle(failure)}: ${l10n.failureMessage(failure)}')),
  );
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
  return words.map((String word) {
    if (word.length == 1) {
      return word.toUpperCase();
    }
    return '${word.substring(0, 1).toUpperCase()}${word.substring(1)}';
  }).join(' ');
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

const AccessRequirement _writeRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.mortuaryWrite],
  requiresFacilityContext: true,
);

const AccessRequirement _storageRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.mortuaryManageStorage],
  requiresFacilityContext: true,
);

const AccessRequirement _postMortemRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.mortuaryPostMortemRequest],
  requiresFacilityContext: true,
);

const AccessRequirement _billingRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.mortuaryBillingEvent],
  requiresFacilityContext: true,
);

const AccessRequirement _approveRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.mortuaryApprove],
  requiresFacilityContext: true,
);

const AccessRequirement _releaseRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.mortuaryRelease],
  requiresFacilityContext: true,
);

const AccessRequirement _exportRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.mortuaryExport,
    AppPermissions.reportsRead,
  ],
  requiresFacilityContext: true,
);
