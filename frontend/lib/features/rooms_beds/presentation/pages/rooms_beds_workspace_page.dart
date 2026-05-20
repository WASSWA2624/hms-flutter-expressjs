import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/controllers/rooms_beds_workspace_controller.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class RoomsBedsWorkspacePage extends ConsumerWidget {
  const RoomsBedsWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<RoomsBedsWorkspaceState>> workspace = ref.watch(
      roomsBedsWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<RoomsBedsWorkspaceState>(
      value: workspace,
      appBarTitle: l10n.roomsBedsTitle,
      loadingTitle: l10n.roomsBedsLoadingTitle,
      loadingBody: l10n.roomsBedsLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      onRetry: () {
        ref.read(roomsBedsWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, RoomsBedsWorkspaceState state) {
        return _RoomsBedsWorkspaceContent(state: state);
      },
    );
  }
}

class _RoomsBedsWorkspaceContent extends ConsumerStatefulWidget {
  const _RoomsBedsWorkspaceContent({required this.state});

  final RoomsBedsWorkspaceState state;

  @override
  ConsumerState<_RoomsBedsWorkspaceContent> createState() {
    return _RoomsBedsWorkspaceContentState();
  }
}

class _RoomsBedsWorkspaceContentState
    extends ConsumerState<_RoomsBedsWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<BedBoardItem>
  _tableColumnController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<BedBoardItem>();
  }

  @override
  void didUpdateWidget(covariant _RoomsBedsWorkspaceContent oldWidget) {
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
    final RoomsBedsWorkspaceState state = widget.state;
    final RoomsBedsWorkspaceController controller = ref.read(
      roomsBedsWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canAdminBeds = _canAdminBeds(accessPolicy);
    final bool canIpdWrite = accessPolicy.grants(AppPermissions.clinicalWrite);
    final AppFailure? lastFailure = state.lastFailure as AppFailure?;

    return AppWorkspace(
      title: l10n.roomsBedsTitle,
      leadingIcon: AppRouteIcons.roomsBeds,
      status: AppWorkspaceStatus(
        label: state.isSaving
            ? l10n.roomsBedsSavingStatus
            : l10n.roomsBedsLiveStatus,
        tone: state.isSaving
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: state.isSaving ? Icons.sync_outlined : Icons.sensors_outlined,
      ),
      primaryAction: canAdminBeds
          ? AppButton.primary(
              label: l10n.tenantFacilityAddBedAction,
              leadingIcon: Icons.add,
              enabled: !state.isSaving,
              onPressed: () => _showBedDialog(context, ref, state),
            )
          : null,
      secondaryActions: <Widget>[
        if (canAdminBeds)
          AppButton.secondary(
            label: l10n.tenantFacilityAddRoomAction,
            leadingIcon: Icons.meeting_room_outlined,
            enabled: !state.isSaving,
            onPressed: () => _showRoomDialog(context, ref, state),
          ),
        if (canAdminBeds)
          AppButton.secondary(
            label: l10n.tenantFacilityAddWardAction,
            leadingIcon: Icons.apartment_outlined,
            enabled: !state.isSaving,
            onPressed: () => _showWardDialog(context, ref, state),
          ),
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          isLoading: state.isRefreshing,
          onPressed: state.isRefreshing
              ? null
              : () async {
                  final AppFailure? failure = await controller.refresh();
                  if (context.mounted) {
                    _showFailureIfNeeded(context, failure);
                  }
                },
        ),
        AppButton.tertiary(
          label: l10n.navigationSetupLabel,
          leadingIcon: Icons.settings_outlined,
          onPressed: () => context.go(AppRoutes.tenantFacilitySetup.location()),
        ),
      ],
      compactSummaryCards: true,
      summaryCards: <Widget>[
        AppWorkspaceSummaryCard(
          label: l10n.roomsBedsTotalSummaryLabel,
          value: state.totalBedCount.toString(),
          icon: Icons.bed_outlined,
          compact: true,
          onPressed: controller.clearFilters,
        ),
        AppWorkspaceSummaryCard(
          label: l10n.tenantFacilityBedStatusAvailable,
          value: state.availableCount.toString(),
          icon: Icons.check_circle_outline,
          tone: AppWorkspaceStatusTone.success,
          compact: true,
          onPressed: () => controller.applyStatus(BedSetupStatus.available),
        ),
        AppWorkspaceSummaryCard(
          label: l10n.tenantFacilityBedStatusOccupied,
          value: state.occupiedCount.toString(),
          icon: Icons.person_pin_circle_outlined,
          tone: AppWorkspaceStatusTone.info,
          compact: true,
          onPressed: () => controller.applyStatus(BedSetupStatus.occupied),
        ),
        AppWorkspaceSummaryCard(
          label: l10n.tenantFacilityBedStatusReserved,
          value: state.reservedCount.toString(),
          icon: Icons.event_available_outlined,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
          onPressed: () => controller.applyStatus(BedSetupStatus.reserved),
        ),
        AppWorkspaceSummaryCard(
          label: l10n.tenantFacilityBedStatusOutOfService,
          value: state.outOfServiceCount.toString(),
          icon: Icons.block_outlined,
          tone: AppWorkspaceStatusTone.error,
          compact: true,
          onPressed: () => controller.applyStatus(BedSetupStatus.outOfService),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (lastFailure != null) ...<Widget>[
            AppFailureStateView(
              failure: lastFailure,
              onRetry: controller.refresh,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          AppMessagePanel(
            title: l10n.roomsBedsBackendGapsTitle,
            message: l10n.roomsBedsBackendGapsBody,
            icon: Icons.api_outlined,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          _BedBoardPanel(
            state: state,
            canAdminBeds: canAdminBeds,
            canIpdWrite: canIpdWrite,
            searchController: _searchController,
            columnVisibilityController: _tableColumnController,
          ),
        ],
      ),
    );
  }
}

class _BedBoardPanel extends ConsumerWidget {
  const _BedBoardPanel({
    required this.state,
    required this.canAdminBeds,
    required this.canIpdWrite,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final RoomsBedsWorkspaceState state;
  final bool canAdminBeds;
  final bool canIpdWrite;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<BedBoardItem>
  columnVisibilityController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final RoomsBedsWorkspaceController controller = ref.read(
      roomsBedsWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.roomsBedsBoardTitle,
      description: l10n.roomsBedsBoardDescription,
      child: SizedBox(
        height: 560,
        child: AppListTable<BedBoardItem>(
          page: state.beds,
          isLoading: state.isRefreshing,
          columnVisibilityController: columnVisibilityController,
          columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
          search: AppListTableSearch<BedBoardItem>(
            controller: searchController,
            semanticLabel: l10n.roomsBedsSearchLabel,
            hintText: l10n.roomsBedsSearchHint,
            matcher: (_, _) => true,
            isLoading: state.isRefreshing,
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
            advancedFilterButtonLabel: l10n.roomsBedsFiltersLabel,
            advancedFilterTitle: l10n.roomsBedsFiltersLabel,
            advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
            advancedFilterResetLabel: l10n.opdClearFiltersAction,
            advancedFilterCancelLabel: l10n.commonCancelActionLabel,
            enableDateFilter: false,
            allFieldsLabel: l10n.roomsBedsAllFilterLabel,
            filterGroups: <AppSearchBarFilterGroup>[
              AppSearchBarFilterGroup(
                key: _facilityFilterKey,
                label: l10n.roomsBedsFacilityFilterLabel,
                allLabel: l10n.roomsBedsAllFacilitiesLabel,
                choices: _facilityChoices(state.referenceData.facilities),
              ),
              AppSearchBarFilterGroup(
                key: _wardFilterKey,
                label: l10n.roomsBedsWardFilterLabel,
                allLabel: l10n.roomsBedsAllWardsLabel,
                choices: _wardChoices(state.referenceData.wards),
              ),
              AppSearchBarFilterGroup(
                key: _roomFilterKey,
                label: l10n.roomsBedsRoomFilterLabel,
                allLabel: l10n.roomsBedsAllRoomsLabel,
                choices: _roomChoices(state.referenceData.rooms),
              ),
              AppSearchBarFilterGroup(
                key: _statusFilterKey,
                label: l10n.roomsBedsStatusFilterLabel,
                allLabel: l10n.roomsBedsAllStatusesLabel,
                choices: _statusChoices(l10n),
              ),
            ],
            filterValue: _filterValue(state.query),
            hasActiveFilters: state.query.hasFilters,
            onFilterChanged: (AppSearchBarFilterValue value) async {
              AppFailure? failure;
              final String? facilityId = value.option(_facilityFilterKey);
              final String? wardId = value.option(_wardFilterKey);
              final String? roomId = value.option(_roomFilterKey);
              final BedSetupStatus? status = _statusFromFilter(
                value.option(_statusFilterKey),
              );
              if (facilityId != state.query.facilityId) {
                failure = await controller.applyFacility(facilityId);
              }
              if (wardId != state.query.wardId) {
                failure ??= await controller.applyWard(wardId);
              }
              if (roomId != state.query.roomId) {
                failure ??= await controller.applyRoom(roomId);
              }
              if (status != state.query.status) {
                failure ??= await controller.applyStatus(status);
              }
              if (context.mounted) {
                _showFailureIfNeeded(context, failure);
              }
            },
          ),
          itemKeyBuilder: (BedBoardItem item) => ValueKey<String>(item.id),
          onPageChanged: (AppPageRequest request) {
            unawaited(controller.changePage(request));
          },
          onRowSelected: (BedBoardItem item) {
            unawaited(
              _openBedDetailDialog(
                context,
                ref,
                state,
                item,
                canAdminBeds: canAdminBeds,
                canIpdWrite: canIpdWrite,
              ),
            );
          },
          previousPageLabel: l10n.roomsBedsPreviousPageLabel,
          nextPageLabel: l10n.roomsBedsNextPageLabel,
          pageLabelBuilder: (AppPage<BedBoardItem> page) {
            return l10n.roomsBedsPageLabel(
              page.firstItemNumber,
              page.lastItemNumber,
              page.totalItemCount ?? page.items.length,
            );
          },
          emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
            title: l10n.roomsBedsEmptyTitle,
            body: l10n.roomsBedsEmptyBody,
            icon: Icons.bed_outlined,
          ),
          columns: <AppListTableColumn<BedBoardItem>>[
            AppListTableColumn<BedBoardItem>(
              label: l10n.roomsBedsBedColumnLabel,
              sortComparator: (BedBoardItem left, BedBoardItem right) {
                return appListTableCompareText(left.label, right.label);
              },
              cellBuilder: (BuildContext context, BedBoardItem item) {
                return _TwoLineCell(
                  title: item.label,
                  subtitle: _joinDisplay(<String?>[
                    item.id,
                    item.facility?.name,
                  ]),
                );
              },
            ),
            AppListTableColumn<BedBoardItem>(
              label: l10n.roomsBedsLocationColumnLabel,
              sortComparator: (BedBoardItem left, BedBoardItem right) {
                return appListTableCompareText(
                  _locationLabel(context, left),
                  _locationLabel(context, right),
                );
              },
              cellBuilder: (BuildContext context, BedBoardItem item) {
                return Text(_locationLabel(context, item));
              },
            ),
            AppListTableColumn<BedBoardItem>(
              label: l10n.roomsBedsStatusColumnLabel,
              sortComparator: (BedBoardItem left, BedBoardItem right) {
                return appListTableCompareText(
                  left.status.apiValue,
                  right.status.apiValue,
                );
              },
              cellBuilder: (BuildContext context, BedBoardItem item) {
                return AppWorkspaceStatusBadge(
                  status: _statusFor(context, item),
                );
              },
            ),
            AppListTableColumn<BedBoardItem>(
              label: l10n.roomsBedsAssignmentColumnLabel,
              sortComparator: (BedBoardItem left, BedBoardItem right) {
                return appListTableCompareText(
                  _assignmentLabel(context, left),
                  _assignmentLabel(context, right),
                );
              },
              cellBuilder: (BuildContext context, BedBoardItem item) {
                return Text(_assignmentLabel(context, item));
              },
            ),
            AppListTableColumn<BedBoardItem>(
              label: l10n.roomsBedsNextActionColumnLabel,
              sortComparator: (BedBoardItem left, BedBoardItem right) {
                return appListTableCompareText(
                  _nextActionLabel(context, left),
                  _nextActionLabel(context, right),
                );
              },
              cellBuilder: (BuildContext context, BedBoardItem item) {
                return Text(_nextActionLabel(context, item));
              },
            ),
          ],
          mobileItemBuilder: (BuildContext context, BedBoardItem item) {
            return _BedMobileItem(item: item);
          },
        ),
      ),
    );
  }
}

Future<void> _openBedDetailDialog(
  BuildContext context,
  WidgetRef ref,
  RoomsBedsWorkspaceState fallbackState,
  BedBoardItem item, {
  required bool canAdminBeds,
  required bool canIpdWrite,
}) async {
  final RoomsBedsWorkspaceController controller = ref.read(
    roomsBedsWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectBed(item);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final RoomsBedsWorkspaceState state =
      _readRoomsBedsState(ref) ?? fallbackState;
  final BedBoardItem selected = state.selectedBed ?? item;

  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.roomsBedsDetailTitle),
      icon: const Icon(Icons.bed_outlined),
      scrollable: true,
      maxWidth: 900,
      content: _BedDetailContent(
        state: state,
        item: selected,
        canAdminBeds: canAdminBeds,
        canIpdWrite: canIpdWrite,
      ),
    ),
  );
}

RoomsBedsWorkspaceState? _readRoomsBedsState(WidgetRef ref) {
  return ref
      .read(roomsBedsWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (RoomsBedsWorkspaceState state) => state,
        failure: (_) => null,
      );
}

class _BedDetailContent extends ConsumerWidget {
  const _BedDetailContent({
    required this.state,
    required this.item,
    required this.canAdminBeds,
    required this.canIpdWrite,
  });

  final RoomsBedsWorkspaceState state;
  final BedBoardItem item;
  final bool canAdminBeds;
  final bool canIpdWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final RoomsBedsWorkspaceController controller = ref.read(
      roomsBedsWorkspaceControllerProvider.notifier,
    );
    final String? admissionId = item.currentAdmissionId;

    return AppFormSection(
      children: <Widget>[
        AppInfoTileGrid(
          emptyValue: l10n.profileUnknownValue,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: l10n.tenantFacilityBedLabelLabel,
              value: item.label,
              icon: Icons.bed_outlined,
            ),
            AppInfoTileData(
              label: l10n.roomsBedsStatusColumnLabel,
              value: _statusLabel(l10n, item.status),
              icon: Icons.fact_check_outlined,
            ),
            AppInfoTileData(
              label: l10n.roomsBedsWardFilterLabel,
              value: item.ward?.name,
              icon: Icons.apartment_outlined,
            ),
            AppInfoTileData(
              label: l10n.roomsBedsRoomFilterLabel,
              value: item.room?.name,
              icon: Icons.meeting_room_outlined,
            ),
            AppInfoTileData(
              label: l10n.roomsBedsCurrentAdmissionLabel,
              value: admissionId,
              icon: Icons.assignment_ind_outlined,
            ),
            AppInfoTileData(
              label: l10n.roomsBedsReadinessLabel,
              value: _readinessLabel(context, item),
              icon: Icons.cleaning_services_outlined,
            ),
          ],
        ),
        if (canAdminBeds || canIpdWrite)
          Wrap(
            spacing: Theme.of(context).spacing.sm,
            runSpacing: Theme.of(context).spacing.sm,
            children: <Widget>[
              if (canAdminBeds)
                AppButton.secondary(
                  label: l10n.tenantFacilityEditBedTitle,
                  leadingIcon: Icons.edit_outlined,
                  enabled: !state.isSaving,
                  onPressed: () =>
                      _showBedDialog(context, ref, state, item: item),
                ),
              if (canAdminBeds && item.status != BedSetupStatus.reserved)
                AppButton.secondary(
                  label: l10n.roomsBedsReserveAction,
                  leadingIcon: Icons.event_available_outlined,
                  enabled: !state.isSaving && !item.isOccupied,
                  onPressed: () => _updateBedStatus(
                    context,
                    controller,
                    item,
                    BedSetupStatus.reserved,
                  ),
                ),
              if (canAdminBeds && item.status != BedSetupStatus.available)
                AppButton.secondary(
                  label: l10n.roomsBedsMarkAvailableAction,
                  leadingIcon: Icons.check_circle_outline,
                  enabled: !state.isSaving && !item.isOccupied,
                  onPressed: () => _updateBedStatus(
                    context,
                    controller,
                    item,
                    BedSetupStatus.available,
                  ),
                ),
              if (canAdminBeds && item.status != BedSetupStatus.outOfService)
                AppButton.secondary(
                  label: l10n.roomsBedsMarkOutOfServiceAction,
                  leadingIcon: Icons.block_outlined,
                  enabled: !state.isSaving && !item.isOccupied,
                  onPressed: () => _updateBedStatus(
                    context,
                    controller,
                    item,
                    BedSetupStatus.outOfService,
                  ),
                ),
              if (canIpdWrite)
                AppButton.secondary(
                  label: l10n.roomsBedsAssignAction,
                  leadingIcon: Icons.login_outlined,
                  enabled: !state.isSaving && item.isAvailable,
                  onPressed: () => _showAssignDialog(context, controller, item),
                ),
              if (canIpdWrite)
                AppButton.secondary(
                  label: l10n.roomsBedsReleaseAction,
                  leadingIcon: Icons.logout_outlined,
                  enabled:
                      !state.isSaving && item.isOccupied && admissionId != null,
                  onPressed: () => _showReleaseDialog(
                    context,
                    controller,
                    item,
                    admissionId,
                  ),
                ),
              if (canIpdWrite)
                AppButton.secondary(
                  label: l10n.roomsBedsRequestTransferAction,
                  leadingIcon: Icons.alt_route_outlined,
                  enabled:
                      !state.isSaving && item.isOccupied && admissionId != null,
                  onPressed: () => _showTransferDialog(
                    context,
                    controller,
                    state,
                    item,
                    admissionId,
                  ),
                ),
            ],
          ),
        AppSectionPanel(
          title: l10n.roomsBedsAssignmentHistoryTitle,
          leadingIcon: Icons.history_outlined,
          children: <Widget>[
            if (item.assignmentHistory.isEmpty)
              Text(l10n.roomsBedsNoAssignmentsLabel)
            else
              for (final BedAssignmentRecord assignment
                  in item.assignmentHistory)
                _AssignmentListItem(assignment: assignment),
          ],
        ),
      ],
    );
  }
}

class _AssignmentListItem extends StatelessWidget {
  const _AssignmentListItem({required this.assignment});

  final BedAssignmentRecord assignment;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        assignment.isActive
            ? Icons.person_pin_circle_outlined
            : Icons.history_outlined,
      ),
      title: Text(assignment.admissionId),
      subtitle: Text(
        _joinDisplay(<String?>[
          _dateLabel(context, assignment.assignedAt),
          assignment.releasedAt == null
              ? l10n.roomsBedsCurrentAssignmentLabel
              : _dateLabel(context, assignment.releasedAt),
        ]),
      ),
      trailing: AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: assignment.isActive
              ? l10n.roomsBedsCurrentAssignmentLabel
              : l10n.roomsBedsReleasedAssignmentLabel,
          tone: assignment.isActive
              ? AppWorkspaceStatusTone.info
              : AppWorkspaceStatusTone.neutral,
        ),
      ),
    );
  }
}

class _BedMobileItem extends StatelessWidget {
  const _BedMobileItem({required this.item});

  final BedBoardItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.label),
      subtitle: Text(
        _joinDisplay(<String?>[
          _locationLabel(context, item),
          _assignmentLabel(context, item),
        ]),
      ),
      trailing: AppWorkspaceStatusBadge(status: _statusFor(context, item)),
      leading: Icon(
        item.isOccupied ? Icons.person_pin_circle_outlined : Icons.bed_outlined,
        semanticLabel: _statusLabel(l10n, item.status),
      ),
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
    final String? subtitle = this.subtitle;

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
        if (subtitle != null && subtitle.isNotEmpty)
          Text(
            subtitle,
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

class _WardForm extends StatefulWidget {
  const _WardForm({required this.state, required this.onSubmit, this.ward});

  final RoomsBedsWorkspaceState state;
  final WardProfile? ward;
  final Future<AppFailure?> Function({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    required WardSetupType type,
    String? departmentId,
    required bool isActive,
  })
  onSubmit;

  @override
  State<_WardForm> createState() => _WardFormState();
}

class _WardFormState extends State<_WardForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late WardSetupType _type;
  String? _departmentId;
  bool _isActive = true;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ward?.name);
    _type = widget.ward?.type ?? WardSetupType.general;
    _departmentId = widget.ward?.departmentId;
    _isActive = widget.ward?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          labelText: l10n.tenantFacilityWardNameLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.roomsBedsRequiredMessage(l10n.tenantFacilityWardNameLabel),
          ),
        ),
        AppSelectField<WardSetupType>(
          labelText: l10n.tenantFacilityWardTypeLabel,
          value: _type,
          isRequired: true,
          options: <AppSelectOption<WardSetupType>>[
            for (final WardSetupType type in WardSetupType.values)
              AppSelectOption<WardSetupType>(
                value: type,
                label: _wardTypeLabel(l10n, type),
              ),
          ],
          onChanged: (WardSetupType? value) {
            if (value != null) {
              setState(() => _type = value);
            }
          },
        ),
        AppSelectField<String>(
          labelText: l10n.tenantFacilityWardDepartmentLabel,
          value: _departmentId,
          options: <AppSelectOption<String>>[
            for (final DepartmentProfile department
                in widget.state.referenceData.snapshot.departments)
              AppSelectOption<String>(
                value: department.id,
                label: department.name,
              ),
          ],
          onChanged: (String? value) => setState(() => _departmentId = value),
        ),
        AppSwitchField(
          title: l10n.tenantFacilityActiveLabel,
          value: _isActive,
          onChanged: (bool value) => setState(() => _isActive = value),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.tenantFacilitySaveAction,
          submitIcon: Icons.save_outlined,
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
    final TenantProfile? tenant = widget.state.referenceData.tenant;
    final FacilityProfile? facility = widget.state.referenceData.facility;
    if (tenant == null || facility == null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      id: widget.ward?.id,
      tenantId: tenant.id,
      facilityId: facility.id,
      name: _nameController.text.trim(),
      type: _type,
      departmentId: _departmentId,
      isActive: _isActive,
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

class _RoomForm extends StatefulWidget {
  const _RoomForm({required this.state, required this.onSubmit, this.room});

  final RoomsBedsWorkspaceState state;
  final RoomProfile? room;
  final Future<AppFailure?> Function({
    String? id,
    required String tenantId,
    required String facilityId,
    required String name,
    String? wardId,
    String? floor,
  })
  onSubmit;

  @override
  State<_RoomForm> createState() => _RoomFormState();
}

class _RoomFormState extends State<_RoomForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _floorController;
  String? _wardId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name);
    _floorController = TextEditingController(text: widget.room?.floor);
    _wardId = widget.room?.wardId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _floorController.dispose();
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
          labelText: l10n.tenantFacilityRoomNameLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.roomsBedsRequiredMessage(l10n.tenantFacilityRoomNameLabel),
          ),
        ),
        AppSelectField<String>(
          labelText: l10n.tenantFacilityRoomWardLabel,
          value: _wardId,
          options: <AppSelectOption<String>>[
            for (final WardProfile ward in widget.state.referenceData.wards)
              AppSelectOption<String>(value: ward.id, label: ward.name),
          ],
          onChanged: (String? value) => setState(() => _wardId = value),
        ),
        AppTextField(
          controller: _floorController,
          labelText: l10n.tenantFacilityRoomFloorLabel,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.tenantFacilitySaveAction,
          submitIcon: Icons.save_outlined,
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
    final TenantProfile? tenant = widget.state.referenceData.tenant;
    final FacilityProfile? facility = widget.state.referenceData.facility;
    if (tenant == null || facility == null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      id: widget.room?.id,
      tenantId: tenant.id,
      facilityId: facility.id,
      name: _nameController.text.trim(),
      wardId: _wardId,
      floor: _floorController.text.trim(),
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

class _BedForm extends StatefulWidget {
  const _BedForm({required this.state, required this.onSubmit, this.item});

  final RoomsBedsWorkspaceState state;
  final BedBoardItem? item;
  final Future<AppFailure?> Function({
    String? id,
    required String tenantId,
    required String facilityId,
    required String wardId,
    required String label,
    required BedSetupStatus status,
    String? roomId,
  })
  onSubmit;

  @override
  State<_BedForm> createState() => _BedFormState();
}

class _BedFormState extends State<_BedForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late BedSetupStatus _status;
  String? _wardId;
  String? _roomId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final BedBoardItem? item = widget.item;
    _labelController = TextEditingController(text: item?.label);
    _status = item?.status ?? BedSetupStatus.available;
    _wardId = item?.wardId ?? widget.state.referenceData.wards.firstOrNull?.id;
    _roomId = item?.roomId;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<RoomProfile> rooms = widget.state.referenceData.rooms
        .where((RoomProfile room) => _wardId == null || room.wardId == _wardId)
        .toList(growable: false);

    return AppFormShell(
      formKey: _formKey,
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
      children: <Widget>[
        AppTextField(
          controller: _labelController,
          labelText: l10n.tenantFacilityBedLabelLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.roomsBedsRequiredMessage(l10n.tenantFacilityBedLabelLabel),
          ),
        ),
        AppSelectField<String>(
          labelText: l10n.tenantFacilityBedWardLabel,
          value: _wardId,
          isRequired: true,
          options: <AppSelectOption<String>>[
            for (final WardProfile ward in widget.state.referenceData.wards)
              AppSelectOption<String>(value: ward.id, label: ward.name),
          ],
          validator: AppValidators.requiredValue<String>(
            l10n.roomsBedsRequiredMessage(l10n.tenantFacilityBedWardLabel),
          ),
          onChanged: (String? value) {
            setState(() {
              _wardId = value;
              if (rooms.every((RoomProfile room) => room.id != _roomId)) {
                _roomId = null;
              }
            });
          },
        ),
        AppSelectField<String>(
          labelText: l10n.tenantFacilityBedRoomLabel,
          value: _roomId,
          options: <AppSelectOption<String>>[
            for (final RoomProfile room in rooms)
              AppSelectOption<String>(value: room.id, label: room.name),
          ],
          onChanged: (String? value) => setState(() => _roomId = value),
        ),
        AppSelectField<BedSetupStatus>(
          labelText: l10n.tenantFacilityBedStatusLabel,
          value: _status,
          options: <AppSelectOption<BedSetupStatus>>[
            for (final BedSetupStatus status in BedSetupStatus.values)
              AppSelectOption<BedSetupStatus>(
                value: status,
                label: _statusLabel(l10n, status),
              ),
          ],
          onChanged: (BedSetupStatus? value) {
            if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.tenantFacilitySaveAction,
          submitIcon: Icons.save_outlined,
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
    final TenantProfile? tenant = widget.state.referenceData.tenant;
    final FacilityProfile? facility = widget.state.referenceData.facility;
    final String? wardId = _wardId;
    if (tenant == null || facility == null || wardId == null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      id: widget.item?.id,
      tenantId: tenant.id,
      facilityId: facility.id,
      wardId: wardId,
      label: _labelController.text.trim(),
      status: _status,
      roomId: _roomId,
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

class _AdmissionActionForm extends StatefulWidget {
  const _AdmissionActionForm({
    required this.submitLabel,
    required this.submitIcon,
    required this.onSubmit,
    this.initialAdmissionId,
    this.body,
  });

  final String submitLabel;
  final IconData submitIcon;
  final String? initialAdmissionId;
  final String? body;
  final Future<AppFailure?> Function(String admissionId) onSubmit;

  @override
  State<_AdmissionActionForm> createState() => _AdmissionActionFormState();
}

class _AdmissionActionFormState extends State<_AdmissionActionForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _admissionController;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _admissionController = TextEditingController(
      text: widget.initialAdmissionId,
    );
  }

  @override
  void dispose() {
    _admissionController.dispose();
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
        if (widget.body != null) Text(widget.body!),
        AppTextField(
          controller: _admissionController,
          labelText: l10n.roomsBedsAdmissionFieldLabel,
          hintText: l10n.roomsBedsAdmissionFieldHint,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.roomsBedsRequiredMessage(l10n.roomsBedsAdmissionFieldLabel),
          ),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.submitLabel,
          submitIcon: widget.submitIcon,
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
      _admissionController.text.trim(),
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

class _TransferForm extends StatefulWidget {
  const _TransferForm({
    required this.state,
    required this.initialAdmissionId,
    required this.onSubmit,
  });

  final RoomsBedsWorkspaceState state;
  final String initialAdmissionId;
  final Future<AppFailure?> Function({
    required String admissionId,
    required String toWardId,
  })
  onSubmit;

  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _admissionController;
  String? _toWardId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _admissionController = TextEditingController(
      text: widget.initialAdmissionId,
    );
  }

  @override
  void dispose() {
    _admissionController.dispose();
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
        Text(l10n.roomsBedsTransferDialogBody),
        AppTextField(
          controller: _admissionController,
          labelText: l10n.roomsBedsAdmissionFieldLabel,
          hintText: l10n.roomsBedsAdmissionFieldHint,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.roomsBedsRequiredMessage(l10n.roomsBedsAdmissionFieldLabel),
          ),
        ),
        AppSelectField<String>(
          labelText: l10n.roomsBedsDestinationWardLabel,
          value: _toWardId,
          isRequired: true,
          options: <AppSelectOption<String>>[
            for (final WardProfile ward in widget.state.referenceData.wards)
              AppSelectOption<String>(value: ward.id, label: ward.name),
          ],
          validator: AppValidators.requiredValue<String>(
            l10n.roomsBedsRequiredMessage(l10n.roomsBedsDestinationWardLabel),
          ),
          onChanged: (String? value) => setState(() => _toWardId = value),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.roomsBedsRequestTransferAction,
          submitIcon: Icons.alt_route_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey) || _toWardId == null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      admissionId: _admissionController.text.trim(),
      toWardId: _toWardId!,
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

Future<void> _showWardDialog(
  BuildContext context,
  WidgetRef ref,
  RoomsBedsWorkspaceState state, {
  WardProfile? ward,
}) async {
  final AppLocalizations l10n = context.l10n;
  final RoomsBedsWorkspaceController controller = ref.read(
    roomsBedsWorkspaceControllerProvider.notifier,
  );
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(
      ward == null
          ? l10n.tenantFacilityAddWardTitle
          : l10n.tenantFacilityEditWardTitle,
    ),
    content: _WardForm(state: state, ward: ward, onSubmit: controller.saveWard),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _showRoomDialog(
  BuildContext context,
  WidgetRef ref,
  RoomsBedsWorkspaceState state, {
  RoomProfile? room,
}) async {
  final AppLocalizations l10n = context.l10n;
  final RoomsBedsWorkspaceController controller = ref.read(
    roomsBedsWorkspaceControllerProvider.notifier,
  );
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(
      room == null
          ? l10n.tenantFacilityAddRoomTitle
          : l10n.tenantFacilityEditRoomTitle,
    ),
    content: _RoomForm(state: state, room: room, onSubmit: controller.saveRoom),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _showBedDialog(
  BuildContext context,
  WidgetRef ref,
  RoomsBedsWorkspaceState state, {
  BedBoardItem? item,
}) async {
  final AppLocalizations l10n = context.l10n;
  final RoomsBedsWorkspaceController controller = ref.read(
    roomsBedsWorkspaceControllerProvider.notifier,
  );
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(
      item == null
          ? l10n.tenantFacilityAddBedTitle
          : l10n.tenantFacilityEditBedTitle,
    ),
    content: _BedForm(state: state, item: item, onSubmit: controller.saveBed),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _showAssignDialog(
  BuildContext context,
  RoomsBedsWorkspaceController controller,
  BedBoardItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.roomsBedsAssignDialogTitle),
    content: _AdmissionActionForm(
      submitLabel: l10n.roomsBedsAssignAction,
      submitIcon: Icons.login_outlined,
      onSubmit: (String admissionId) {
        return controller.assignBed(item: item, admissionId: admissionId);
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _showReleaseDialog(
  BuildContext context,
  RoomsBedsWorkspaceController controller,
  BedBoardItem item,
  String? admissionId,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.roomsBedsReleaseDialogTitle),
    content: _AdmissionActionForm(
      submitLabel: l10n.roomsBedsReleaseAction,
      submitIcon: Icons.logout_outlined,
      initialAdmissionId: admissionId,
      body: l10n.roomsBedsReleaseDialogBody,
      onSubmit: (String admissionId) {
        return controller.releaseBed(item: item, admissionId: admissionId);
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _showTransferDialog(
  BuildContext context,
  RoomsBedsWorkspaceController controller,
  RoomsBedsWorkspaceState state,
  BedBoardItem item,
  String? admissionId,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.roomsBedsTransferDialogTitle),
    content: _TransferForm(
      state: state,
      initialAdmissionId: admissionId ?? '',
      onSubmit: ({required String admissionId, required String toWardId}) {
        return controller.requestTransfer(
          item: item,
          admissionId: admissionId,
          toWardId: toWardId,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _updateBedStatus(
  BuildContext context,
  RoomsBedsWorkspaceController controller,
  BedBoardItem item,
  BedSetupStatus status,
) async {
  final AppFailure? failure = await controller.updateBedStatus(item, status);
  if (context.mounted) {
    if (failure == null) {
      _showSaved(context);
    } else {
      _showFailureIfNeeded(context, failure);
    }
  }
}

bool _canAdminBeds(AppAccessPolicy accessPolicy) {
  return accessPolicy.isElevated ||
      accessPolicy.grantsAny(const <AppPermission>[
        AppPermissions.tenantAdmin,
        AppPermissions.facilityAdmin,
        AppPermissions.systemAdmin,
      ]);
}

AppWorkspaceStatus _statusFor(BuildContext context, BedBoardItem item) {
  return AppWorkspaceStatus(
    label: _statusLabel(context.l10n, item.status),
    tone: _statusTone(item.status),
    icon: _statusIcon(item.status),
  );
}

AppWorkspaceStatusTone _statusTone(BedSetupStatus status) {
  return switch (status) {
    BedSetupStatus.available => AppWorkspaceStatusTone.success,
    BedSetupStatus.occupied => AppWorkspaceStatusTone.info,
    BedSetupStatus.reserved => AppWorkspaceStatusTone.warning,
    BedSetupStatus.outOfService => AppWorkspaceStatusTone.error,
  };
}

IconData _statusIcon(BedSetupStatus status) {
  return switch (status) {
    BedSetupStatus.available => Icons.check_circle_outline,
    BedSetupStatus.occupied => Icons.person_pin_circle_outlined,
    BedSetupStatus.reserved => Icons.event_available_outlined,
    BedSetupStatus.outOfService => Icons.block_outlined,
  };
}

String _statusLabel(AppLocalizations l10n, BedSetupStatus status) {
  return switch (status) {
    BedSetupStatus.available => l10n.tenantFacilityBedStatusAvailable,
    BedSetupStatus.occupied => l10n.tenantFacilityBedStatusOccupied,
    BedSetupStatus.reserved => l10n.tenantFacilityBedStatusReserved,
    BedSetupStatus.outOfService => l10n.tenantFacilityBedStatusOutOfService,
  };
}

String _wardTypeLabel(AppLocalizations l10n, WardSetupType type) {
  return switch (type) {
    WardSetupType.general => l10n.tenantFacilityWardTypeGeneral,
    WardSetupType.icu => l10n.tenantFacilityWardTypeIcu,
    WardSetupType.maternity => l10n.tenantFacilityWardTypeMaternity,
    WardSetupType.pediatric => l10n.tenantFacilityWardTypePediatric,
    WardSetupType.surgical => l10n.tenantFacilityWardTypeSurgical,
    WardSetupType.other => l10n.tenantFacilityWardTypeOther,
  };
}

String _locationLabel(BuildContext context, BedBoardItem item) {
  return _joinDisplay(<String?>[
    item.ward?.name,
    item.room?.name,
    item.room?.floor,
  ]).ifEmpty(context.l10n.profileUnknownValue);
}

String _assignmentLabel(BuildContext context, BedBoardItem item) {
  final String? admissionId = item.currentAdmissionId;
  if (admissionId != null) {
    return context.l10n.roomsBedsAdmissionAssignment(admissionId);
  }
  if (item.isOccupied || item.isReserved) {
    return context.l10n.roomsBedsAssignmentNotLinked;
  }
  return context.l10n.profileUnknownValue;
}

String _nextActionLabel(BuildContext context, BedBoardItem item) {
  final AppLocalizations l10n = context.l10n;
  return switch (item.status) {
    BedSetupStatus.available => l10n.roomsBedsNextActionAssign,
    BedSetupStatus.occupied => l10n.roomsBedsNextActionReleaseOrTransfer,
    BedSetupStatus.reserved => l10n.roomsBedsNextActionAssignOrReleaseHold,
    BedSetupStatus.outOfService => l10n.roomsBedsNextActionResolveBlock,
  };
}

String _readinessLabel(BuildContext context, BedBoardItem item) {
  if (item.isAvailable) {
    return context.l10n.roomsBedsReadyLabel;
  }
  if (item.isOutOfService) {
    return context.l10n.roomsBedsUnavailableLabel;
  }
  return context.l10n.roomsBedsReadinessBackendGapLabel;
}

String _dateLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

List<AppSearchBarFilterChoice> _facilityChoices(
  List<FacilityProfile> facilities,
) {
  return <AppSearchBarFilterChoice>[
    for (final FacilityProfile facility in facilities)
      AppSearchBarFilterChoice(
        value: facility.id,
        label: facility.name,
        icon: Icons.local_hospital_outlined,
      ),
  ];
}

List<AppSearchBarFilterChoice> _wardChoices(List<WardProfile> wards) {
  return <AppSearchBarFilterChoice>[
    for (final WardProfile ward in wards)
      AppSearchBarFilterChoice(
        value: ward.id,
        label: ward.name,
        icon: Icons.apartment_outlined,
      ),
  ];
}

List<AppSearchBarFilterChoice> _roomChoices(List<RoomProfile> rooms) {
  return <AppSearchBarFilterChoice>[
    for (final RoomProfile room in rooms)
      AppSearchBarFilterChoice(
        value: room.id,
        label: room.name,
        icon: Icons.meeting_room_outlined,
      ),
  ];
}

List<AppSearchBarFilterChoice> _statusChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    for (final BedSetupStatus status in BedSetupStatus.values)
      AppSearchBarFilterChoice(
        value: status.apiValue,
        label: _statusLabel(l10n, status),
        icon: _statusIcon(status),
      ),
  ];
}

AppSearchBarFilterValue _filterValue(RoomsBedsQuery query) {
  return AppSearchBarFilterValue(
    options: <String, String>{
      if (query.facilityId != null) _facilityFilterKey: query.facilityId!,
      if (query.wardId != null) _wardFilterKey: query.wardId!,
      if (query.roomId != null) _roomFilterKey: query.roomId!,
      if (query.status != null) _statusFilterKey: query.status!.apiValue,
    },
  );
}

BedSetupStatus? _statusFromFilter(String? value) {
  if (value == null) {
    return null;
  }
  for (final BedSetupStatus status in BedSetupStatus.values) {
    if (status.apiValue == value) {
      return status;
    }
  }
  return null;
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.roomsBedsSavedMessage)));
}

const String _facilityFilterKey = 'facility';
const String _wardFilterKey = 'ward';
const String _roomFilterKey = 'room';
const String _statusFilterKey = 'status';

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
