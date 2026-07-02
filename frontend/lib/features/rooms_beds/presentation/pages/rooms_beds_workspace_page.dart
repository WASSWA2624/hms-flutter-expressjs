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
import 'package:hosspi_hms/features/rooms_beds/presentation/widgets/rooms_beds_status_helpers.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class RoomsBedsWorkspacePage extends ConsumerStatefulWidget {
  const RoomsBedsWorkspacePage({this.initialQuery, super.key});

  final RoomsBedsQuery? initialQuery;

  @override
  ConsumerState<RoomsBedsWorkspacePage> createState() {
    return _RoomsBedsWorkspacePageState();
  }
}

class _RoomsBedsWorkspacePageState
    extends ConsumerState<RoomsBedsWorkspacePage> {
  String? _appliedRouteSignature;

  @override
  void initState() {
    super.initState();
    _scheduleRouteQuery(widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant RoomsBedsWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_querySignature(oldWidget.initialQuery) !=
        _querySignature(widget.initialQuery)) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  void _scheduleRouteQuery(RoomsBedsQuery? query) {
    if (query == null || !query.hasRouteTargeting) {
      return;
    }
    final String? signature = _querySignature(query);
    if (signature == null || _appliedRouteSignature == signature) {
      return;
    }
    _appliedRouteSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(roomsBedsWorkspaceControllerProvider.notifier)
          .applyRouteQuery(query);
    });
  }

  String? _querySignature(RoomsBedsQuery? query) {
    if (query == null) {
      return null;
    }
    return '${query.wardId}|${query.roomId}|${query.bedId}|${query.status?.apiValue}|${query.search}';
  }

  @override
  Widget build(BuildContext context) {
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
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        summaryNotifications: <AppWorkspaceSummaryNotification>[
          AppWorkspaceSummaryNotification(
            label: l10n.roomsBedsTotalSummaryLabel,
            count: state.totalBedCount,
            icon: Icons.bed_outlined,
            onSelected: controller.clearFilters,
          ),
          AppWorkspaceSummaryNotification(
            label: l10n.tenantFacilityBedStatusAvailable,
            count: state.availableCount,
            icon: Icons.check_circle_outline,
            tone: AppWorkspaceStatusTone.success,
            onSelected: () => controller.applyStatus(BedSetupStatus.available),
          ),
          AppWorkspaceSummaryNotification(
            label: l10n.tenantFacilityBedStatusOccupied,
            count: state.occupiedCount,
            icon: Icons.person_pin_circle_outlined,
            tone: AppWorkspaceStatusTone.info,
            onSelected: () => controller.applyStatus(BedSetupStatus.occupied),
          ),
          AppWorkspaceSummaryNotification(
            label: l10n.tenantFacilityBedStatusReserved,
            count: state.reservedCount,
            icon: Icons.event_available_outlined,
            tone: AppWorkspaceStatusTone.warning,
            onSelected: () => controller.applyStatus(BedSetupStatus.reserved),
          ),
          AppWorkspaceSummaryNotification(
            label: l10n.tenantFacilityBedStatusCleaning,
            count: state.cleaningCount,
            icon: Icons.cleaning_services_outlined,
            tone: AppWorkspaceStatusTone.warning,
            onSelected: () => controller.applyStatus(BedSetupStatus.cleaning),
          ),
          AppWorkspaceSummaryNotification(
            label: l10n.tenantFacilityBedStatusBlocked,
            count: state.blockedCount,
            icon: Icons.block_outlined,
            tone: AppWorkspaceStatusTone.error,
            onSelected: () => controller.applyStatus(BedSetupStatus.blocked),
          ),
        ],
        primary: canAdminBeds
            ? AppButton.primary(
                label: l10n.tenantFacilityAddRoomAction,
                leadingIcon: Icons.meeting_room_outlined,
                semanticLabel: l10n.tenantFacilityAddRoomAction,
                tooltip: l10n.tenantFacilityAddRoomAction,
                enabled: !state.isSaving,
                onPressed: () async {
                  await showTenantFacilityRoomFormDialog(
                    context,
                    state.referenceData.snapshot,
                  );
                  if (context.mounted) {
                    await controller.refresh();
                  }
                },
              )
            : null,
        secondary: <Widget>[
          if (canAdminBeds)
            AppButton.secondary(
              label: l10n.tenantFacilityAddBedAction,
              leadingIcon: Icons.bed_outlined,
              semanticLabel: l10n.tenantFacilityAddBedAction,
              tooltip: l10n.tenantFacilityAddBedAction,
              enabled: !state.isSaving,
              onPressed: () async {
                await showTenantFacilityBedFormDialog(
                  context,
                  state.referenceData.snapshot,
                );
                if (context.mounted) {
                  await controller.refresh();
                }
              },
            ),
          if (canAdminBeds)
            AppButton.secondary(
              label: l10n.roomsBedsManageCatalogAction,
              leadingIcon: Icons.apartment_outlined,
              enabled: !state.isSaving,
              onPressed: () =>
                  context.go(AppRoutes.tenantFacilitySetup.location()),
            ),
          AppButton.tertiary(
            label: l10n.navigationSetupLabel,
            leadingIcon: Icons.settings_outlined,
            onPressed: () =>
                context.go(AppRoutes.tenantFacilitySetup.location()),
          ),
        ],
        onRefresh: () async {
          final AppFailure? failure = await controller.refresh();
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
        isRefreshing: state.isRefreshing,
      ),

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
                choices: roomsBedsStatusFilterChoices(l10n),
              ),
            ],
            filterValue: _filterValue(state.query),
            hasActiveFilters: state.query.hasFilters,
            onFilterChanged: (AppSearchBarFilterValue value) async {
              AppFailure? failure;
              final String? facilityId = value.option(_facilityFilterKey);
              final String? wardId = value.option(_wardFilterKey);
              final String? roomId = value.option(_roomFilterKey);
              final BedSetupStatus? status = roomsBedsStatusFromFilter(
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
                  subtitle: _joinDisplay(<String?>[item.facility?.name]),
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
                  status: roomsBedsStatusBadge(context.l10n, item.status),
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
                  roomsBedsNextActionLabel(context.l10n, left),
                  roomsBedsNextActionLabel(context.l10n, right),
                );
              },
              cellBuilder: (BuildContext context, BedBoardItem item) {
                return Text(roomsBedsNextActionLabel(context.l10n, item));
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
    final String? admissionDisplayId = item.currentAdmissionDisplayId;

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
              value: roomsBedsStatusLabel(l10n, item.status),
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
              value: _readableDisplayText(admissionDisplayId),
              icon: Icons.assignment_ind_outlined,
            ),
            AppInfoTileData(
              label: l10n.roomsBedsReadinessLabel,
              value: roomsBedsReadinessLabel(l10n, item),
              icon: Icons.cleaning_services_outlined,
            ),
          ],
        ),
        if (admissionId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.tertiary(
              label: l10n.roomsBedsOpenIpdAdmissionAction,
              leadingIcon: Icons.open_in_new,
              onPressed: () {
                final String? target =
                    _readableDisplayText(admissionDisplayId) ??
                    _readableDisplayText(admissionId);
                if (target == null) {
                  return;
                }
                context.go(
                  AppRoutes.ipd.location(
                    queryParameters: <String, String>{'admission': target},
                  ),
                );
              },
            ),
          ),
        if (canAdminBeds || canIpdWrite)
          Wrap(
            spacing: Theme.of(context).spacing.sm,
            runSpacing: Theme.of(context).spacing.sm,
            children: <Widget>[
              if (canAdminBeds && !item.isOccupied)
                AppButton.secondary(
                  label: l10n.roomsBedsReserveAction,
                  leadingIcon: Icons.event_available_outlined,
                  enabled: !state.isSaving && item.isAvailable,
                  onPressed: () => _updateBedStatus(
                    context,
                    controller,
                    item,
                    BedSetupStatus.reserved,
                  ),
                ),
              if (canAdminBeds && !item.isAvailable)
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
              if (canAdminBeds &&
                  !item.isOccupied &&
                  item.status != BedSetupStatus.cleaning)
                AppButton.secondary(
                  label: l10n.roomsBedsMarkCleaningAction,
                  leadingIcon: Icons.cleaning_services_outlined,
                  enabled: !state.isSaving,
                  onPressed: () => _updateBedStatus(
                    context,
                    controller,
                    item,
                    BedSetupStatus.cleaning,
                  ),
                ),
              if (canAdminBeds &&
                  !item.isOccupied &&
                  item.status != BedSetupStatus.maintenance)
                AppButton.secondary(
                  label: l10n.roomsBedsMarkMaintenanceAction,
                  leadingIcon: Icons.build_outlined,
                  enabled: !state.isSaving,
                  onPressed: () => _updateBedStatus(
                    context,
                    controller,
                    item,
                    BedSetupStatus.maintenance,
                  ),
                ),
              if (canAdminBeds && !item.isOccupied && !item.isBlocked)
                AppButton.secondary(
                  label: l10n.roomsBedsMarkBlockedAction,
                  leadingIcon: Icons.block_outlined,
                  enabled: !state.isSaving,
                  onPressed: () => _updateBedStatus(
                    context,
                    controller,
                    item,
                    BedSetupStatus.blocked,
                  ),
                ),
              if (canAdminBeds && item.isCleaning)
                AppButton.tertiary(
                  label: l10n.roomsBedsOpenHousekeepingAction,
                  leadingIcon: Icons.cleaning_services_outlined,
                  onPressed: () =>
                      context.go(AppRoutes.housekeeping.location()),
                ),
              if (canAdminBeds && (item.isMaintenance || item.isBlocked))
                AppButton.tertiary(
                  label: l10n.roomsBedsOpenOperationsAction,
                  leadingIcon: Icons.handyman_outlined,
                  onPressed: () => context.go(AppRoutes.operations.location()),
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
                    admissionDisplayId: admissionDisplayId,
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
                    admissionDisplayId: admissionDisplayId,
                  ),
                ),
              if (canIpdWrite && item.hasOpenTransfer && admissionId != null)
                AppButton.secondary(
                  label: l10n.roomsBedsManageTransferAction,
                  leadingIcon: Icons.move_down_outlined,
                  enabled: !state.isSaving,
                  onPressed: () => _showTransferUpdateDialog(
                    context,
                    controller,
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
    final String title = _assignmentTitle(context, assignment);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        assignment.isActive
            ? Icons.person_pin_circle_outlined
            : Icons.history_outlined,
      ),
      title: Text(title),
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
      trailing: AppWorkspaceStatusBadge(
        status: roomsBedsStatusBadge(l10n, item.status),
      ),
      leading: Icon(
        item.isOccupied ? Icons.person_pin_circle_outlined : Icons.bed_outlined,
        semanticLabel: roomsBedsStatusLabel(l10n, item.status),
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

class _AdmissionActionForm extends StatefulWidget {
  const _AdmissionActionForm({
    required this.submitLabel,
    required this.submitIcon,
    required this.onSubmit,
    this.initialAdmissionId,
    this.fallbackAdmissionId,
    this.body,
  });

  final String submitLabel;
  final IconData submitIcon;
  final String? initialAdmissionId;
  final String? fallbackAdmissionId;
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
    final bool requiresAdmissionInput =
        (widget.fallbackAdmissionId?.trim() ?? '').isEmpty;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        if (widget.body != null) Text(widget.body!),
        AppTextField(
          controller: _admissionController,
          labelText: l10n.roomsBedsAdmissionFieldLabel,
          hintText: l10n.roomsBedsAdmissionFieldHint,
          isRequired: requiresAdmissionInput,
          validator: requiresAdmissionInput
              ? AppValidators.requiredText(
                  l10n.roomsBedsRequiredMessage(
                    l10n.roomsBedsAdmissionFieldLabel,
                  ),
                )
              : null,
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
    final String enteredAdmissionId = _admissionController.text.trim();
    final String admissionId = enteredAdmissionId.isNotEmpty
        ? enteredAdmissionId
        : widget.fallbackAdmissionId?.trim() ?? '';
    final AppFailure? failure = await widget.onSubmit(admissionId);
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
    this.fallbackAdmissionId,
    required this.onSubmit,
  });

  final RoomsBedsWorkspaceState state;
  final String initialAdmissionId;
  final String? fallbackAdmissionId;
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
    final bool requiresAdmissionInput =
        (widget.fallbackAdmissionId?.trim() ?? '').isEmpty;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        Text(l10n.roomsBedsTransferDialogBody),
        AppTextField(
          controller: _admissionController,
          labelText: l10n.roomsBedsAdmissionFieldLabel,
          hintText: l10n.roomsBedsAdmissionFieldHint,
          isRequired: requiresAdmissionInput,
          validator: requiresAdmissionInput
              ? AppValidators.requiredText(
                  l10n.roomsBedsRequiredMessage(
                    l10n.roomsBedsAdmissionFieldLabel,
                  ),
                )
              : null,
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
    final String enteredAdmissionId = _admissionController.text.trim();
    final String admissionId = enteredAdmissionId.isNotEmpty
        ? enteredAdmissionId
        : widget.fallbackAdmissionId?.trim() ?? '';
    final AppFailure? failure = await widget.onSubmit(
      admissionId: admissionId,
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

class _TransferUpdateForm extends StatefulWidget {
  const _TransferUpdateForm({
    required this.controller,
    required this.item,
    required this.admissionId,
    this.transferRequestId,
    this.transferStatus,
  });

  final RoomsBedsWorkspaceController controller;
  final BedBoardItem item;
  final String admissionId;
  final String? transferRequestId;
  final String? transferStatus;

  @override
  State<_TransferUpdateForm> createState() => _TransferUpdateFormState();
}

class _TransferUpdateFormState extends State<_TransferUpdateForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String _action;
  String? _bedId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _action = roomsBedsTransferActionForStatus(widget.transferStatus);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<BedBoardItem> destinationBeds = widget.controller
        .availableDestinationBeds(excludeBedId: widget.item.id);

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppSelectField<String>(
          labelText: l10n.ipdTransferActionFieldLabel,
          value: _action,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'APPROVE',
              label: l10n.ipdTransferApproveAction,
            ),
            AppSelectOption<String>(
              value: 'START',
              label: l10n.ipdTransferStartAction,
            ),
            AppSelectOption<String>(
              value: 'COMPLETE',
              label: l10n.ipdTransferCompleteAction,
            ),
            AppSelectOption<String>(
              value: 'CANCEL',
              label: l10n.ipdTransferCancelAction,
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _action = value);
            }
          },
        ),
        if (roomsBedsTransferRequiresDestinationBed(_action))
          AppSelectField<String>(
            labelText: l10n.ipdDestinationBedFieldLabel,
            value: _bedId,
            isRequired: true,
            options: <AppSelectOption<String>>[
              for (final BedBoardItem bed in destinationBeds)
                AppSelectOption<String>(
                  value: bed.id,
                  label: _joinDisplay(<String?>[bed.label, bed.ward?.name]),
                ),
            ],
            validator: AppValidators.requiredValue<String>(
              l10n.roomsBedsRequiredMessage(l10n.ipdDestinationBedFieldLabel),
            ),
            onChanged: (String? value) => setState(() => _bedId = value),
          ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.roomsBedsManageTransferAction,
          submitIcon: Icons.move_down_outlined,
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
    if (roomsBedsTransferRequiresDestinationBed(_action) && _bedId == null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.controller.updateTransfer(
      item: widget.item,
      admissionId: widget.admissionId,
      action: _action,
      transferRequestId: widget.transferRequestId,
      toBedId: _bedId,
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

Future<void> _showAssignDialog(
  BuildContext context,
  RoomsBedsWorkspaceController controller,
  BedBoardItem item,
) async {
  final AppLocalizations l10n = context.l10n;
  final WardSetupType? wardType = item.ward?.type;
  final String? suitabilityHint =
      wardType == null || wardType == WardSetupType.general
      ? null
      : switch (wardType) {
          WardSetupType.icu => l10n.tenantFacilityWardTypeIcu,
          WardSetupType.maternity => l10n.tenantFacilityWardTypeMaternity,
          WardSetupType.pediatric => l10n.tenantFacilityWardTypePediatric,
          WardSetupType.surgical => l10n.tenantFacilityWardTypeSurgical,
          WardSetupType.other => l10n.tenantFacilityWardTypeOther,
          WardSetupType.general => l10n.tenantFacilityWardTypeGeneral,
        };
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.roomsBedsAssignDialogTitle),
    content: _AdmissionActionForm(
      submitLabel: l10n.roomsBedsAssignAction,
      submitIcon: Icons.login_outlined,
      body: suitabilityHint == null
          ? null
          : l10n.roomsBedsAssignWardSuitabilityHint(suitabilityHint),
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
  String? admissionId, {
  String? admissionDisplayId,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.roomsBedsReleaseDialogTitle),
    content: _AdmissionActionForm(
      submitLabel: l10n.roomsBedsReleaseAction,
      submitIcon: Icons.logout_outlined,
      initialAdmissionId: _readableDisplayText(admissionDisplayId),
      fallbackAdmissionId: admissionId,
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
  String? admissionId, {
  String? admissionDisplayId,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.roomsBedsTransferDialogTitle),
    content: _TransferForm(
      state: state,
      initialAdmissionId: _readableDisplayText(admissionDisplayId) ?? '',
      fallbackAdmissionId: admissionId,
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

Future<void> _showTransferUpdateDialog(
  BuildContext context,
  RoomsBedsWorkspaceController controller,
  BedBoardItem item,
  String admissionId,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.roomsBedsTransferUpdateDialogTitle),
    content: _TransferUpdateForm(
      controller: controller,
      item: item,
      admissionId: admissionId,
      transferRequestId: item.admissionContext?.transferRequestId,
      transferStatus: item.admissionContext?.transferStatus,
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

String _locationLabel(BuildContext context, BedBoardItem item) {
  return _joinDisplay(<String?>[
    item.ward?.name,
    item.room?.name,
    item.room?.floor,
  ]).ifEmpty(context.l10n.profileUnknownValue);
}

String _assignmentLabel(BuildContext context, BedBoardItem item) {
  final String? admissionId = _readableDisplayText(
    item.currentAdmissionDisplayId,
  );
  if (admissionId != null) {
    return context.l10n.roomsBedsAdmissionAssignment(admissionId);
  }
  if (item.currentAdmissionId != null) {
    return context.l10n.roomsBedsCurrentAssignmentLabel;
  }
  if (item.isOccupied || item.isReserved) {
    return context.l10n.roomsBedsAssignmentNotLinked;
  }
  return context.l10n.profileUnknownValue;
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

String _assignmentTitle(BuildContext context, BedAssignmentRecord assignment) {
  final String? admissionId = _readableDisplayText(
    assignment.admissionDisplayId ?? assignment.admissionId,
  );
  if (admissionId != null) {
    return context.l10n.roomsBedsAdmissionAssignment(admissionId);
  }
  return assignment.isActive
      ? context.l10n.roomsBedsCurrentAssignmentLabel
      : context.l10n.roomsBedsReleasedAssignmentLabel;
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

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String? _readableDisplayText(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty || _isNonHumanReadableId(normalized)) {
    return null;
  }
  return normalized;
}

bool _isNonHumanReadableId(String value) {
  return _uuidPattern.hasMatch(value) || _longHexPattern.hasMatch(value);
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final RegExp _longHexPattern = RegExp(r'^[0-9a-fA-F]{24,}$');

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
