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
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/controllers/rooms_beds_workspace_controller.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/rooms_beds_access.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/widgets/rooms_beds_next_action_button.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/widgets/rooms_beds_status_helpers.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/routing/workspace_location_sync.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      // Wait for the provider's initial load so it cannot overwrite the routed
      // selection / detail open.
      await ref.read(roomsBedsWorkspaceControllerProvider.future);
      if (!mounted) {
        return;
      }
      final AppFailure? failure = await ref
          .read(roomsBedsWorkspaceControllerProvider.notifier)
          .applyRouteQuery(query);
      if (!mounted || failure != null) {
        return;
      }
      final String? bedId = query.bedId;
      if (bedId == null || bedId.isEmpty) {
        return;
      }
      final RoomsBedsWorkspaceState? state = _readRoomsBedsState(ref);
      BedBoardItem? selected = state?.selectedBed;
      if (state != null && (selected == null || selected.id != bedId)) {
        selected = state.beds.items
            .where((BedBoardItem item) => item.id == bedId)
            .firstOrNull;
      }
      if (state == null || selected == null) {
        return;
      }
      final RoomsBedsCapabilities capabilities =
          RoomsBedsCapabilities.fromPolicy(ref.read(appAccessPolicyProvider));
      await _openBedDetailDialog(
        context,
        ref,
        state,
        selected,
        canAdminBeds: capabilities.canAdminBeds,
        canIpdWrite: capabilities.canOccupancyWrite,
      );
    });
  }

  String? _querySignature(RoomsBedsQuery? query) {
    if (query == null) {
      return null;
    }
    return '${query.section.name}|${query.wardId}|${query.roomId}|${query.bedId}|${query.status?.apiValue}|${query.search}';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<RoomsBedsWorkspaceState>> workspace = ref.watch(
      roomsBedsWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<RoomsBedsWorkspaceState>(
      value: workspace,
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
  late RoomsBedsSection _section;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<BedBoardItem>();
    _section = widget.state.query.section;
  }

  @override
  void didUpdateWidget(covariant _RoomsBedsWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.value = TextEditingValue(text: search);
    }
    if (oldWidget.state.query.section != widget.state.query.section) {
      _section = widget.state.query.section;
    }
  }

  void _ensureAuthorizedSection(AppAccessPolicy accessPolicy) {
    if (canViewRoomsBedsSection(accessPolicy, _section)) {
      return;
    }
    final RoomsBedsSection? fallback = roomsBedsFallbackSection(accessPolicy);
    if (fallback == null || fallback == _section) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _section = fallback);
      _updateUrlForSection(fallback);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  void _updateUrlForSection(RoomsBedsSection section) {
    if (!mounted) {
      return;
    }
    final String tab = _roomsBedsSectionQueryValue(section);
    final String location = AppRoutes.roomsBeds.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    syncWorkspaceLocation(context, location);
  }

  void _handleTabChanged(RoomsBedsSection section) {
    if (section == _section) {
      return;
    }
    setState(() => _section = section);
    _updateUrlForSection(section);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RoomsBedsWorkspaceState state = widget.state;
    final RoomsBedsWorkspaceController controller = ref.read(
      roomsBedsWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final RoomsBedsCapabilities capabilities = RoomsBedsCapabilities.fromPolicy(
      accessPolicy,
    );
    final bool canAdminBeds = capabilities.canAdminBeds;
    final bool canIpdWrite = capabilities.canOccupancyWrite;
    _ensureAuthorizedSection(accessPolicy);
    final List<RoomsBedsSection> visibleSections = roomsBedsAllowedSections(
      accessPolicy,
    );
    // Mutation dialogs/snackbars already surface actionable errors. Do not park
    // a page-level failure banner between the tabs and table.
    final AppFailure? lastFailure = state.lastFailure as AppFailure?;
    if (lastFailure != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.clearLastFailure();
      });
    }

    if (visibleSections.isEmpty) {
      return const SizedBox.shrink();
    }

    final AppPage<BedBoardItem> sectionPage = roomsBedsSectionFilteredPage(
      state.beds,
      _section,
    );
    final RoomsBedsNextActionCallbacks nextActionCallbacks =
        RoomsBedsNextActionCallbacks(
          onAssign: (BedBoardItem item) =>
              _showAssignDialog(context, controller, item),
          onRelease: (BedBoardItem item) => _showReleaseDialog(
            context,
            controller,
            item,
            item.currentAdmissionId,
            admissionDisplayId: item.currentAdmissionDisplayId,
          ),
          onCompleteTransfer: (BedBoardItem item) {
            final String? admissionId = item.currentAdmissionId;
            if (admissionId == null) {
              return Future<void>.value();
            }
            return _showTransferUpdateDialog(
              context,
              controller,
              item,
              admissionId,
            );
          },
          onMarkAvailable: (BedBoardItem item) => _updateBedStatus(
            context,
            controller,
            item,
            BedSetupStatus.available,
          ),
          onOpenDetail: (BedBoardItem item) => _openBedDetailDialog(
            context,
            ref,
            state,
            item,
            canAdminBeds: canAdminBeds,
            canIpdWrite: canIpdWrite,
          ),
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
            // Room/bed catalog CRUD lives in admin setup → Facility only.
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final RoomsBedsSection section in visibleSections)
                  AppTabItem(
                    id: section.name,
                    icon: _roomsBedsSectionIcon(section),
                    label: _roomsBedsSectionLabel(l10n, section),
                    count: roomsBedsSectionCount(state, section),
                    countTone: _roomsBedsSectionCountTone(section),
                  ),
              ],
              selectedId: _section.name,
              onTabTapped: (String tabId) {
                for (final RoomsBedsSection section in visibleSections) {
                  if (section.name == tabId) {
                    _handleTabChanged(section);
                    break;
                  }
                }
              },
            ),
            SizedBox(height: theme.spacing.sm),
            if (canViewRoomsBedsSection(accessPolicy, _section))
              AppListTable<BedBoardItem>(
                page: sectionPage,
                isLoading: state.isRefreshing,
                columnVisibilityController: _tableColumnController,
                columnVisibilityStorageKey: 'rooms_beds_${_section.name}',
                columnWidthStorageKey: 'rooms_beds_cw_${_section.name}',
                columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
                columnVisibilityTitle: l10n.commonTableSettingsTitle,
                columnChoices: roomsBedsBedBoardColumnChoices(l10n),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                search: AppListTableSearch<BedBoardItem>(
                  controller: _searchController,
                  semanticLabel: l10n.roomsBedsSearchLabel,
                  hintText: l10n.roomsBedsSearchHint,
                  matcher: roomsBedsBedBoardSearchMatcher(l10n),
                  onSubmitted: (String value) async {
                    final AppFailure? failure = await controller.applySearch(
                      value,
                    );
                    if (context.mounted) {
                      _showFailureIfNeeded(context, failure);
                    }
                  },
                  onClear: () async {
                    final AppFailure? failure = await controller.applySearch(
                      '',
                    );
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
                  allFieldsLabel: l10n.roomsBedsAllFilterLabel,
                  filterGroups: _filterGroups(l10n, state, section: _section),
                  filterValue: _filterValue(state.query, section: _section),
                  hasActiveFilters: _hasActiveFilters(state.query, _section),
                  onFilterChanged: (AppSearchBarFilterValue value) async {
                    AppFailure? failure;
                    final String? facilityId = value.option(_facilityFilterKey);
                    final String? wardId = value.option(_wardFilterKey);
                    final String? roomId = value.option(_roomFilterKey);
                    final BedSetupStatus? status =
                        _section == RoomsBedsSection.all
                        ? roomsBedsStatusFromFilter(
                            value.option(_statusFilterKey),
                          )
                        : state.query.status;
                    if (facilityId != state.query.facilityId) {
                      failure = await controller.applyFacility(facilityId);
                    }
                    if (wardId != state.query.wardId) {
                      failure ??= await controller.applyWard(wardId);
                    }
                    if (roomId != state.query.roomId) {
                      failure ??= await controller.applyRoom(roomId);
                    }
                    if (_section == RoomsBedsSection.all &&
                        status != state.query.status) {
                      failure ??= await controller.applyStatus(status);
                    }
                    if (context.mounted) {
                      _showFailureIfNeeded(context, failure);
                    }
                  },
                ),
                itemKeyBuilder: (BedBoardItem item) =>
                    ValueKey<String>(item.id),
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
                columns: roomsBedsBedBoardColumns(
                  l10n: l10n,
                  includeNextAction: switch (_section) {
                    // Available / Occupied primaries are occupancy write only
                    // (Assign / Release|complete transfer).
                    RoomsBedsSection.available ||
                    RoomsBedsSection.occupied => canIpdWrite,
                    // Turnover / OOS include navigate next-actions for board
                    // readers (Open operations); write buttons still omit.
                    RoomsBedsSection.turnover ||
                    RoomsBedsSection.outOfService => true,
                    // All beds mixes admin mark-available and occupancy writes.
                    RoomsBedsSection.all => canAdminBeds || canIpdWrite,
                  },
                  nextActionCellBuilder:
                      (BuildContext context, BedBoardItem item) {
                        final RoomsBedsNextActionKind kind =
                            roomsBedsPrimaryNextActionKind(item);
                        if (!roomsBedsNextActionShouldRender(
                          kind: kind,
                          canAdminBeds: canAdminBeds,
                          canIpdWrite: canIpdWrite,
                        )) {
                          return const SizedBox.shrink();
                        }
                        return RoomsBedsNextActionButton(
                          item: item,
                          state: state,
                          canAdminBeds: canAdminBeds,
                          canIpdWrite: canIpdWrite,
                          callbacks: nextActionCallbacks,
                        );
                      },
                ),
                mobileItemBuilder: (BuildContext context, BedBoardItem item) {
                  final RoomsBedsNextActionKind kind =
                      roomsBedsPrimaryNextActionKind(item);
                  final Widget? trailing =
                      roomsBedsNextActionShouldRender(
                        kind: kind,
                        canAdminBeds: canAdminBeds,
                        canIpdWrite: canIpdWrite,
                      )
                      ? RoomsBedsNextActionButton(
                          item: item,
                          state: state,
                          canAdminBeds: canAdminBeds,
                          canIpdWrite: canIpdWrite,
                          callbacks: nextActionCallbacks,
                          compact: true,
                        )
                      : null;
                  return AppListTableMobileItem(
                    title: item.label,
                    meta: <AppListTableMobileMeta>[
                      AppListTableMobileMeta(
                        label: roomsBedsStatusBadge(l10n, item.status).label,
                      ),
                      AppListTableMobileMeta(
                        label: roomsBedsLocationLabel(l10n, item),
                        icon: Icons.location_on_outlined,
                      ),
                      if (item.isOccupied)
                        AppListTableMobileMeta(
                          label: roomsBedsAssignmentLabel(l10n, item),
                          icon: Icons.person_outline,
                        ),
                    ],
                    trailing: trailing,
                  );
                },
              ),
          ],
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
    final RoomsBedsNextActionKind omitNextActionKind =
        roomsBedsPrimaryNextActionKind(item);

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
              if (canAdminBeds && item.isAvailable)
                AppButton.secondary(
                  label: l10n.roomsBedsReserveAction,
                  leadingIcon: Icons.event_available_outlined,
                  enabled: !state.isSaving,
                  onPressed: () => _updateBedStatus(
                    context,
                    controller,
                    item,
                    BedSetupStatus.reserved,
                  ),
                ),
              if (canAdminBeds &&
                  !item.isAvailable &&
                  omitNextActionKind != RoomsBedsNextActionKind.markAvailable)
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
              if (canAdminBeds &&
                  item.isCleaning &&
                  omitNextActionKind !=
                      RoomsBedsNextActionKind.openHousekeeping)
                AppButton.tertiary(
                  label: l10n.roomsBedsOpenHousekeepingAction,
                  leadingIcon: Icons.cleaning_services_outlined,
                  onPressed: () =>
                      context.go(AppRoutes.housekeeping.location()),
                ),
              if (canAdminBeds &&
                  (item.isMaintenance || item.isBlocked) &&
                  omitNextActionKind != RoomsBedsNextActionKind.openOperations)
                AppButton.tertiary(
                  label: l10n.roomsBedsOpenOperationsAction,
                  leadingIcon: Icons.handyman_outlined,
                  onPressed: () => context.go(AppRoutes.operations.location()),
                ),
              if (canIpdWrite &&
                  omitNextActionKind != RoomsBedsNextActionKind.assign)
                AppButton.secondary(
                  label: l10n.roomsBedsAssignAction,
                  leadingIcon: Icons.login_outlined,
                  enabled: !state.isSaving && item.isAvailable,
                  onPressed: () => _showAssignDialog(context, controller, item),
                ),
              if (canIpdWrite &&
                  omitNextActionKind != RoomsBedsNextActionKind.release)
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
              if (canIpdWrite &&
                  item.hasOpenTransfer &&
                  admissionId != null &&
                  omitNextActionKind !=
                      RoomsBedsNextActionKind.completeTransfer)
                AppButton.secondary(
                  label: l10n.roomsBedsManageTransferAction,
                  leadingIcon: AppActionIcons.transfer,
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
        AppCollapsibleSection(
          title: l10n.roomsBedsAssignmentHistoryTitle,
          titleIcon: Icons.history_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (item.assignmentHistory.isEmpty)
                Text(l10n.roomsBedsNoAssignmentsLabel)
              else
                for (final BedAssignmentRecord assignment
                    in item.assignmentHistory)
                  _AssignmentListItem(assignment: assignment),
            ],
          ),
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

class _AdmissionActionForm extends StatefulWidget {
  const _AdmissionActionForm({
    required this.submitLabel,
    required this.submitIcon,
    required this.onSubmit,
    this.initialAdmissionId,
    this.fallbackAdmissionId,
    this.body,
    this.hideAdmissionField = false,
  });

  final String submitLabel;
  final IconData submitIcon;
  final String? initialAdmissionId;
  final String? fallbackAdmissionId;
  final String? body;
  final bool hideAdmissionField;
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
        !widget.hideAdmissionField &&
        (widget.fallbackAdmissionId?.trim() ?? '').isEmpty;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        if (widget.body != null) Text(widget.body!),
        if (!widget.hideAdmissionField)
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

  bool get _admissionKnown {
    return (widget.fallbackAdmissionId?.trim() ?? '').isNotEmpty;
  }

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
    final bool requiresAdmissionInput = !_admissionKnown;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        Text(l10n.roomsBedsTransferDialogBody),
        if (!_admissionKnown)
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
  final bool admissionKnown = (admissionId?.trim() ?? '').isNotEmpty;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.roomsBedsReleaseDialogTitle),
    content: _AdmissionActionForm(
      submitLabel: l10n.roomsBedsReleaseAction,
      submitIcon: Icons.logout_outlined,
      initialAdmissionId: admissionKnown
          ? null
          : _readableDisplayText(admissionDisplayId),
      fallbackAdmissionId: admissionId,
      hideAdmissionField: admissionKnown,
      body: l10n.roomsBedsReleaseDialogBody,
      onSubmit: (String resolvedAdmissionId) {
        return controller.releaseBed(
          item: item,
          admissionId: resolvedAdmissionId,
        );
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
  final List<BedBoardItem> destinationBeds = controller
      .availableDestinationBeds(excludeBedId: item.id);
  final bool? saved = await showAppTransferUpdateDialog(
    context: context,
    title: l10n.roomsBedsManageTransferAction,
    semanticLabel: l10n.roomsBedsManageTransferAction,
    actionLabel: l10n.ipdTransferActionFieldLabel,
    destinationBedLabel: l10n.ipdDestinationBedFieldLabel,
    destinationBedHint: l10n.ipdSelectBedHint,
    submitLabel: l10n.patientsEditAction,
    requiredMessage: l10n.roomsBedsRequiredMessage(
      l10n.ipdDestinationBedFieldLabel,
    ),
    initialAction: appTransferDefaultActionForStatus(
      item.admissionContext?.transferStatus,
    ),
    actionOptions: <AppSelectOption<String>>[
      AppSelectOption<String>(
        value: AppTransferUpdateActions.approve,
        label: l10n.ipdTransferApproveAction,
      ),
      AppSelectOption<String>(
        value: AppTransferUpdateActions.start,
        label: l10n.ipdTransferStartAction,
      ),
      AppSelectOption<String>(
        value: AppTransferUpdateActions.complete,
        label: l10n.ipdTransferCompleteAction,
      ),
      AppSelectOption<String>(
        value: AppTransferUpdateActions.cancel,
        label: l10n.ipdTransferCancelAction,
      ),
    ],
    bedOptions: <AppSelectOption<String>>[
      for (final BedBoardItem bed in destinationBeds)
        AppSelectOption<String>(
          value: bed.id,
          label: _joinDisplay(<String?>[bed.label, bed.ward?.name]),
        ),
    ],
    onSubmit: ({required String action, String? toBedId}) {
      return controller.updateTransfer(
        item: item,
        admissionId: admissionId,
        action: action,
        transferRequestId: item.admissionContext?.transferRequestId,
        toBedId: toBedId,
      );
    },
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

IconData _roomsBedsSectionIcon(RoomsBedsSection section) {
  return switch (section) {
    RoomsBedsSection.all => Icons.bed_outlined,
    RoomsBedsSection.available => Icons.check_circle_outline,
    RoomsBedsSection.occupied => Icons.person_pin_circle_outlined,
    RoomsBedsSection.turnover => Icons.swap_horiz_outlined,
    RoomsBedsSection.outOfService => Icons.block_outlined,
  };
}

String _roomsBedsSectionLabel(AppLocalizations l10n, RoomsBedsSection section) {
  return switch (section) {
    RoomsBedsSection.all => l10n.roomsBedsSectionAllLabel,
    RoomsBedsSection.available => l10n.roomsBedsSectionAvailableLabel,
    RoomsBedsSection.occupied => l10n.roomsBedsSectionOccupiedLabel,
    RoomsBedsSection.turnover => l10n.roomsBedsSectionTurnoverLabel,
    RoomsBedsSection.outOfService => l10n.roomsBedsSectionOutOfServiceLabel,
  };
}

AppTabCountTone _roomsBedsSectionCountTone(RoomsBedsSection section) {
  return switch (section) {
    RoomsBedsSection.all => AppTabCountTone.info,
    RoomsBedsSection.available => AppTabCountTone.info,
    RoomsBedsSection.occupied => AppTabCountTone.info,
    RoomsBedsSection.turnover => AppTabCountTone.warning,
    RoomsBedsSection.outOfService => AppTabCountTone.danger,
  };
}

String _roomsBedsSectionQueryValue(RoomsBedsSection section) {
  return switch (section) {
    RoomsBedsSection.all => '',
    RoomsBedsSection.available => 'available',
    RoomsBedsSection.occupied => 'occupied',
    RoomsBedsSection.turnover => 'turnover',
    RoomsBedsSection.outOfService => 'out-of-service',
  };
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

AppSearchBarFilterValue _filterValue(
  RoomsBedsQuery query, {
  required RoomsBedsSection section,
}) {
  return AppSearchBarFilterValue(
    options: <String, String>{
      if (query.facilityId != null) _facilityFilterKey: query.facilityId!,
      if (query.wardId != null) _wardFilterKey: query.wardId!,
      if (query.roomId != null) _roomFilterKey: query.roomId!,
      if (section == RoomsBedsSection.all && query.status != null)
        _statusFilterKey: query.status!.apiValue,
    },
  );
}

bool _hasActiveFilters(RoomsBedsQuery query, RoomsBedsSection section) {
  return query.search.trim().isNotEmpty ||
      query.facilityId != null ||
      query.wardId != null ||
      query.roomId != null ||
      query.bedId != null ||
      (section == RoomsBedsSection.all && query.status != null);
}

List<AppSearchBarFilterGroup> _filterGroups(
  AppLocalizations l10n,
  RoomsBedsWorkspaceState state, {
  required RoomsBedsSection section,
}) {
  return <AppSearchBarFilterGroup>[
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
    if (section == RoomsBedsSection.all)
      AppSearchBarFilterGroup(
        key: _statusFilterKey,
        label: l10n.roomsBedsStatusFilterLabel,
        allLabel: l10n.roomsBedsAllStatusesLabel,
        choices: roomsBedsStatusFilterChoices(l10n),
      ),
  ];
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
