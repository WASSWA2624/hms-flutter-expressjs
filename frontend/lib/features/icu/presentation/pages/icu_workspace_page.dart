import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_bed_board_panel.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_format.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class IcuWorkspacePage extends ConsumerStatefulWidget {
  const IcuWorkspacePage({super.key, this.initialQuery});

  final IcuBoardQuery? initialQuery;

  @override
  ConsumerState<IcuWorkspacePage> createState() => _IcuWorkspacePageState();
}

class _IcuWorkspacePageState extends ConsumerState<IcuWorkspacePage> {
  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _scheduleDeepLink();
  }

  void _scheduleDeepLink() {
    final IcuBoardQuery? query = widget.initialQuery;
    if (query == null || !query.hasRouteTargeting || _deepLinkHandled) {
      return;
    }
    _deepLinkHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleDeepLink(query));
    });
  }

  Future<void> _handleDeepLink(IcuBoardQuery query) async {
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final String? focusId = query.focusAdmissionId?.trim();
    if (focusId == null || focusId.isEmpty) {
      return;
    }

    final AppFailure? failure = await controller.selectPatientByDisplayId(
      focusId,
    );
    if (!mounted || failure != null) {
      return;
    }
    final IcuWorkspaceState? state = _readIcuState(ref);
    if (state?.selectedDetail == null) {
      return;
    }
    await _openIcuDetailDialog(
      context,
      ref,
      state!,
      state.selectedDetail!.summary,
      _IcuWorkspaceContent.writeRequirement,
      focusPanel: query.focusPanel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Result<IcuWorkspaceState>> state = ref.watch(
      icuWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return AsyncStateScaffold<IcuWorkspaceState>(
      value: state,
      loadingTitle: l10n.icuLoadingBoardTitle,
      loadingBody: l10n.icuLoadingBoardBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(icuWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, IcuWorkspaceState data) {
        return _IcuWorkspaceContent(state: data);
      },
    );
  }
}

class _IcuWorkspaceContent extends ConsumerStatefulWidget {
  const _IcuWorkspaceContent({required this.state});

  final IcuWorkspaceState state;

  static const AccessRequirement writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.emergencyWrite,
    ],
    activeModules: <String>['icu-critical-care'],
  );

  @override
  ConsumerState<_IcuWorkspaceContent> createState() =>
      _IcuWorkspaceContentState();
}

class _IcuWorkspaceContentState extends ConsumerState<_IcuWorkspaceContent> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
  }

  @override
  void didUpdateWidget(covariant _IcuWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IcuWorkspaceState state = widget.state;
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final bool isBedView = state.view == IcuBoardView.bedBoard;

    return AppWorkspace(
      title: l10n.navigationIcuLabel,
      leadingIcon: AppRouteIcons.icu,
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        summaryNotifications: isBedView
            ? const <AppWorkspaceSummaryNotification>[]
            : [
                if (_pageTotal(state.board) > 0)
                  AppWorkspaceSummaryNotification(
                    label: l10n.icuAllIcuLabel,
                    count: _pageTotal(state.board),
                    icon: Icons.inventory_2_outlined,
                    onSelected: () => controller.applyScope(IcuBoardScope.all),
                  ),
                if (state.activeCount > 0)
                  AppWorkspaceSummaryNotification(
                    label: l10n.icuActiveIcuLabel,
                    count: state.activeCount,
                    icon: Icons.bed_outlined,
                    tone: AppWorkspaceStatusTone.info,
                    onSelected: () =>
                        controller.applyScope(IcuBoardScope.active),
                  ),
                if (state.criticalCount > 0)
                  AppWorkspaceSummaryNotification(
                    label: l10n.icuCriticalAlertsLabel,
                    count: state.criticalCount,
                    icon: Icons.priority_high_outlined,
                    tone: AppWorkspaceStatusTone.error,
                    onSelected: () =>
                        controller.applyScope(IcuBoardScope.critical),
                  ),
                if (state.transferCount > 0)
                  AppWorkspaceSummaryNotification(
                    label: l10n.icuTransfersLabel,
                    count: state.transferCount,
                    icon: Icons.compare_arrows_outlined,
                    tone: AppWorkspaceStatusTone.warning,
                    onSelected: () =>
                        controller.applyScope(IcuBoardScope.transfer),
                  ),
                if (state.dischargeReadyCount > 0)
                  AppWorkspaceSummaryNotification(
                    label: l10n.icuDischargeReadyLabel,
                    count: state.dischargeReadyCount,
                    icon: Icons.fact_check_outlined,
                    tone: AppWorkspaceStatusTone.success,
                    onSelected: () =>
                        controller.applyScope(IcuBoardScope.discharge),
                  ),
              ],
        secondary: <Widget>[
          AppWorkspaceBoardToggle<IcuBoardView>(
            value: state.view,
            segments: <ButtonSegment<IcuBoardView>>[
              ButtonSegment<IcuBoardView>(
                value: IcuBoardView.patientBoard,
                label: Text(l10n.icuViewPatientBoard),
                icon: const Icon(Icons.monitor_heart_outlined),
              ),
              ButtonSegment<IcuBoardView>(
                value: IcuBoardView.bedBoard,
                label: Text(l10n.icuViewBedBoard),
                icon: const Icon(Icons.bed_outlined),
              ),
            ],
            onChanged: controller.setView,
          ),
          AppAccessActionGate(
            requirement: _IcuWorkspaceContent.writeRequirement,
            builder: (BuildContext context, bool isAllowed) {
              final bool canStartStay =
                  state.selectedDetail?.isEligibleToStartStay ?? false;
              return AppButton.secondary(
                label: l10n.icuActionStartStay,
                leadingIcon: Icons.play_circle_outline,
                enabled: isAllowed && canStartStay && !state.isSaving,
                onPressed: () => _confirmAction(
                  context: context,
                  title: l10n.icuStartStayTitle,
                  body: l10n.icuStartStayBody,
                  actionLabel: l10n.icuStartStayActionLabel,
                  onConfirmed: controller.startIcuStay,
                ),
              );
            },
          ),
          AppAccessActionGate(
            requirement: _IcuWorkspaceContent.writeRequirement,
            builder: (BuildContext context, bool isAllowed) {
              final bool hasEncounter =
                  state.selectedDetail?.summary.encounterId != null;
              return AppButton.secondary(
                label: l10n.icuActionRecordVitals,
                leadingIcon: Icons.monitor_heart_outlined,
                enabled: isAllowed && hasEncounter && !state.isSaving,
                onPressed: () => _openVitalsDialog(context),
              );
            },
          ),
          AppAccessActionGate(
            requirement: _IcuWorkspaceContent.writeRequirement,
            builder: (BuildContext context, bool isAllowed) {
              final bool hasActiveStay =
                  state.selectedDetail?.canRecordIcuAction ?? false;
              return AppButton.secondary(
                label: l10n.icuActionRecordObservation,
                leadingIcon: Icons.note_add_outlined,
                enabled: isAllowed && hasActiveStay && !state.isSaving,
                onPressed: () => _openObservationDialog(context),
              );
            },
          ),
        ],
        onRefresh: () async {
          final AppFailure? failure = isBedView
              ? await controller.loadBedBoard()
              : await controller.refresh();
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
        isRefreshing: state.isRefreshingBoard || state.isRefreshingBeds,
      ),

      body: isBedView
          ? IcuBedBoardPanel(
              state: state,
              writeRequirement: _IcuWorkspaceContent.writeRequirement,
            )
          : _IcuBoardPanel(
              state: state,
              writeRequirement: _IcuWorkspaceContent.writeRequirement,
              searchController: _searchController,
            ),
    );
  }
}

class _IcuBoardPanel extends ConsumerWidget {
  const _IcuBoardPanel({
    required this.state,
    required this.writeRequirement,
    required this.searchController,
  });

  final IcuWorkspaceState state;
  final AccessRequirement writeRequirement;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.icuBoardTitle,
      description: l10n.icuBoardDescription,
      child: AppListTable<IcuPatientSummary>(
        page: state.board,
        isLoading: state.isRefreshingBoard,
        columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
        search: AppListTableSearch<IcuPatientSummary>(
          controller: searchController,
          semanticLabel: l10n.icuSearchHint,
          hintText: l10n.icuSearchHint,
          matcher: (_, _) => true,
          onSubmitted: controller.applySearch,
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.icuBoardScopeLabel,
          advancedFilterTitle: l10n.icuBoardFiltersTitle,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.opdClearFiltersAction,
          enableDateFilter: false,
          allFieldsLabel: l10n.icuActiveIcuLabel,
          filterGroups: <AppSearchBarFilterGroup>[
            AppSearchBarFilterGroup(
              key: _icuScopeFilterKey,
              label: l10n.icuBoardScopeLabel,
              allLabel: l10n.icuActiveIcuLabel,
              choices: _icuScopeFilterChoices(l10n),
            ),
          ],
          filterValue: _icuFilterValue(state.query),
          hasActiveFilters: state.query.scope != IcuBoardScope.active,
          onFilterChanged: (AppSearchBarFilterValue value) {
            controller.applyScope(
              _icuScopeFromFilter(value.option(_icuScopeFilterKey)),
            );
          },
        ),
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        pageLabelBuilder: (AppPage<IcuPatientSummary> page) {
          return _pageLabel(context, page);
        },
        onPageChanged: (AppPageRequest request) {
          controller.changePage(request);
        },
        onRowSelected: (IcuPatientSummary summary) {
          unawaited(
            _openIcuDetailDialog(
              context,
              ref,
              state,
              summary,
              writeRequirement,
            ),
          );
        },
        rowColorBuilder: _rowColor,
        emptyBuilder: (_) => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: l10n.icuNoPatientsTitle,
          body: l10n.icuNoPatientsBody,
          icon: Icons.bed_outlined,
        ),
        columns: <AppListTableColumn<IcuPatientSummary>>[
          AppListTableColumn<IcuPatientSummary>(
            label: l10n.opdPatientColumnLabel,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareText(left.displayTitle, right.displayTitle),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              return _IcuPatientCell(item: item);
            },
          ),
          AppListTableColumn<IcuPatientSummary>(
            label: l10n.icuColumnBedLabel,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareText(
                  left.locationLabel,
                  right.locationLabel,
                ),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              return Text(item.locationLabel);
            },
          ),
          AppListTableColumn<IcuPatientSummary>(
            label: l10n.icuColumnSourceLabel,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareText(left.sourceLabel, right.sourceLabel),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              final String label = item.sourceLabel;
              if (label.isEmpty) {
                return Text(l10n.profileUnknownValue);
              }
              return Text(apiLabel(label));
            },
          ),
          AppListTableColumn<IcuPatientSummary>(
            label: l10n.icuColumnAlertLabel,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareText(
                  left.criticalSeverity,
                  right.criticalSeverity,
                ),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              return AppWorkspaceStatusBadge(status: alertStatus(l10n, item));
            },
          ),
          AppListTableColumn<IcuPatientSummary>(
            label: l10n.opdStatusColumnLabel,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareText(left.icuStatus, right.icuStatus),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              return AppWorkspaceStatusBadge(status: icuStatus(item));
            },
          ),
          AppListTableColumn<IcuPatientSummary>(
            label: l10n.icuColumnStartLabel,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareDateTime(
                  left.boardIcuStartAt,
                  right.boardIcuStartAt,
                ),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              return Text(dateTimeLabel(context, item.boardIcuStartAt));
            },
          ),
          AppListTableColumn<IcuPatientSummary>(
            label: l10n.icuColumnTransferLabel,
            sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
                appListTableCompareText(
                  left.transferStatus ?? left.nextStep,
                  right.transferStatus ?? right.nextStep,
                ),
            cellBuilder: (BuildContext context, IcuPatientSummary item) {
              return Text(apiLabel(item.transferStatus ?? item.nextStep ?? ''));
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, IcuPatientSummary item) {
          final ThemeData theme = Theme.of(context);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _IcuPatientCell(item: item),
                SizedBox(height: theme.spacing.sm),
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    AppWorkspaceStatusBadge(status: alertStatus(l10n, item)),
                    AppWorkspaceStatusBadge(status: icuStatus(item)),
                    Text(
                      joinDisplay(<String?>[
                        item.locationLabel,
                        dateTimeLabel(context, item.admittedAt),
                      ]),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color? _rowColor(BuildContext context, IcuPatientSummary item) {
    if (!item.hasCriticalAlert) {
      return null;
    }
    return Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.22);
  }
}

class _IcuPatientCell extends StatelessWidget {
  const _IcuPatientCell({required this.item});

  final IcuPatientSummary item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          item.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          joinDisplay(<String?>[item.displayId]),
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

class _IcuDetailPanel extends ConsumerWidget {
  const _IcuDetailPanel({required this.state, required this.writeRequirement});

  final IcuWorkspaceState state;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IcuPatientDetail? detail = state.selectedDetail;
    if (state.isRefreshingDetail && detail == null) {
      return AppWorkspaceStatePanel.loading(
        title: l10n.icuDetailLoadingTitle,
        body: l10n.icuDetailLoadingBody,
      );
    }
    if (detail == null) {
      return AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.icuDetailEmptyTitle,
        body: l10n.icuDetailEmptyBody,
        icon: Icons.monitor_heart_outlined,
      );
    }

    final IcuPatientSummary summary = detail.summary;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: summary.displayTitle,
          patientNumber: summary.displayId ?? '',
          demographics: joinDisplay(<String?>[
            apiLabel(detail.patientGender ?? ''),
            dateLabel(context, detail.patientDateOfBirth),
          ]),
          status: icuStatus(summary),
          alerts: <AppWorkspaceStatus>[
            if (summary.hasCriticalAlert) alertStatus(l10n, summary),
            if (summary.showsBillingDeferredBadge)
              AppWorkspaceStatus(
                label: l10n.icuBillingDeferredLabel,
                tone: AppWorkspaceStatusTone.warning,
              ),
            if (summary.hasOpenTransfer)
              AppWorkspaceStatus(
                label: l10n.icuTransferPendingLabel,
                tone: AppWorkspaceStatusTone.warning,
              ),
            if (summary.isDischargePlanned)
              AppWorkspaceStatus(
                label: l10n.icuDischargeReadyLabel,
                tone: AppWorkspaceStatusTone.success,
              ),
          ],
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.icuAdmissionLabel,
              value: summary.displayId ?? '',
              icon: Icons.tag_outlined,
              copyable: true,
              copyTooltip: l10n.copyAdmissionIdAction,
              copiedMessage: l10n.admissionIdCopiedMessage,
            ),
            AppWorkspacePatientContextField(
              label: l10n.icuLocationLabel,
              value: summary.locationLabel,
              icon: Icons.bed_outlined,
            ),
            if (detail.sourceContextLabel != null)
              AppWorkspacePatientContextField(
                label: l10n.icuSourceLabel,
                value: apiLabel(detail.sourceContextLabel!),
                icon: Icons.alt_route_outlined,
              ),
            AppWorkspacePatientContextField(
              label: l10n.icuFacilityLabel,
              value: detail.facilityName ?? '',
              icon: Icons.domain_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.icuAdmittedLabel,
              value: dateTimeLabel(context, summary.admittedAt),
              icon: Icons.event_available_outlined,
            ),
            if (detail.icuStayStartedAt != null)
              AppWorkspacePatientContextField(
                label: l10n.icuStayStartedLabel,
                value: dateTimeLabel(context, detail.icuStayStartedAt),
                icon: Icons.timer_outlined,
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _IcuActionPanel(
          detail: detail,
          state: state,
          writeRequirement: writeRequirement,
        ),
        SizedBox(height: theme.spacing.md),
        _IcuAlertPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        _IcuObservationPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        _IcuVitalTrendPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        _IcuCarePanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        _IcuTransferPanel(detail: detail),
      ],
    );
  }
}

Future<void> _openIcuDetailDialog(
  BuildContext context,
  WidgetRef ref,
  IcuWorkspaceState fallbackState,
  IcuPatientSummary summary,
  AccessRequirement writeRequirement, {
  IcuDetailPanel? focusPanel,
}) async {
  final IcuWorkspaceController controller = ref.read(
    icuWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectPatient(summary);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final IcuWorkspaceState state = _readIcuState(ref) ?? fallbackState;
  if (state.selectedDetail == null) {
    return;
  }

  unawaited(
    showAppDialog<void>(
      context: context,
      builder: (_) => AppDialog(
        title: Text(context.l10n.icuStayDialogTitle),
        icon: const Icon(Icons.monitor_heart_outlined),
        scrollable: true,
        maxWidth: 980,
        content: Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            final IcuWorkspaceState current = _readIcuState(ref) ?? state;
            return _IcuDetailPanel(
              state: current,
              writeRequirement: writeRequirement,
            );
          },
        ),
      ),
    ),
  );

  if (focusPanel != null && context.mounted) {
    await _openFocusPanel(context, focusPanel, state.referenceData);
  }
}

Future<void> _openFocusPanel(
  BuildContext context,
  IcuDetailPanel panel,
  IcuReferenceData referenceData,
) async {
  switch (panel) {
    case IcuDetailPanel.vitals:
      await _openVitalsDialog(context);
    case IcuDetailPanel.alerts:
      await _openAlertDialog(context);
    case IcuDetailPanel.observations:
      await _openObservationDialog(context);
    case IcuDetailPanel.orders:
      await _openLabOrderDialog(context);
    case IcuDetailPanel.transfer:
      await _openTransferDialog(context, referenceData);
    case IcuDetailPanel.discharge:
      await _openReadinessDialog(context);
  }
}

IcuWorkspaceState? _readIcuState(WidgetRef ref) {
  return ref
      .read(icuWorkspaceControllerProvider)
      .asData
      ?.value
      .when(success: (IcuWorkspaceState state) => state, failure: (_) => null);
}

class _IcuActionPanel extends ConsumerWidget {
  const _IcuActionPanel({
    required this.detail,
    required this.state,
    required this.writeRequirement,
  });

  final IcuPatientDetail detail;
  final IcuWorkspaceState state;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final bool hasActiveStay = detail.canRecordIcuAction;
    final bool hasAlert = detail.latestAlert != null;
    final bool canStartStay = detail.isEligibleToStartStay;
    final bool hasEncounter = detail.summary.encounterId != null;
    final bool hasOpenTransfer = detail.summary.hasOpenTransfer;

    return AppAccessActionGate(
      requirement: writeRequirement,
      builder: (BuildContext context, bool isAllowed) => AppActionPanel(
        title: l10n.icuActionsTitle,
        actions: <AppActionItem>[
          if (canStartStay)
            AppActionItem(
              label: l10n.icuActionStartStay,
              leadingIcon: Icons.play_circle_outline,
              enabled: isAllowed,
              onPressed: () => _confirmAction(
                context: context,
                title: l10n.icuStartStayTitle,
                body: l10n.icuStartStayBody,
                actionLabel: l10n.icuStartStayActionLabel,
                onConfirmed: () => controller.startIcuStay(),
              ),
            ),
          AppActionItem(
            label: l10n.icuActionRecordObservation,
            leadingIcon: Icons.note_add_outlined,
            enabled: isAllowed && hasActiveStay,
            onPressed: () => _openObservationDialog(context),
          ),
          AppActionItem(
            label: l10n.icuActionRecordVitals,
            leadingIcon: Icons.monitor_heart_outlined,
            enabled: isAllowed && hasEncounter,
            onPressed: () => _openVitalsDialog(context),
          ),
          AppActionItem(
            label: l10n.icuActionRaiseAlert,
            leadingIcon: Icons.notification_important_outlined,
            enabled: isAllowed && hasActiveStay,
            onPressed: () => _openAlertDialog(context),
          ),
          AppActionItem(
            label: l10n.icuActionAcknowledgeAlert,
            leadingIcon: Icons.done_all_outlined,
            enabled: isAllowed && hasAlert,
            onPressed: () => _confirmAction(
              context: context,
              title: l10n.icuAcknowledgeTitle,
              body: l10n.icuAcknowledgeBody,
              actionLabel: l10n.icuActionAcknowledgeAlert,
              onConfirmed: controller.acknowledgeLatestAlert,
            ),
          ),
          AppActionItem(
            label: l10n.icuActionRound,
            leadingIcon: Icons.rate_review_outlined,
            enabled: isAllowed,
            onPressed: () => _openRoundDialog(context),
          ),
          AppActionItem(
            label: l10n.icuActionOrderLab,
            leadingIcon: Icons.science_outlined,
            enabled: isAllowed && hasEncounter,
            onPressed: () => _openLabOrderDialog(context),
          ),
          AppActionItem(
            label: l10n.icuActionOrderImaging,
            leadingIcon: Icons.radio_outlined,
            enabled: isAllowed && hasEncounter,
            onPressed: () => _openRadiologyOrderDialog(context),
          ),
          AppActionItem(
            label: l10n.icuActionPrescribe,
            leadingIcon: Icons.medication_outlined,
            enabled: isAllowed && hasEncounter,
            onPressed: () => _openPrescriptionDialog(context),
          ),
          if (!detail.summary.hasActiveBed)
            AppActionItem(
              label: l10n.icuActionAssignBed,
              leadingIcon: Icons.bed_outlined,
              enabled: isAllowed,
              onPressed: () => _openAssignBedDialog(context),
            ),
          AppActionItem(
            label: l10n.icuActionRequestTransfer,
            leadingIcon: Icons.compare_arrows_outlined,
            enabled: isAllowed && !hasOpenTransfer,
            onPressed: () => _openTransferDialog(context, state.referenceData),
          ),
          if (hasOpenTransfer)
            AppActionItem(
              label: l10n.icuActionManageTransfer,
              leadingIcon: Icons.published_with_changes_outlined,
              enabled: isAllowed,
              onPressed: () => _openManageTransferDialog(context),
            ),
          AppActionItem(
            label: l10n.icuActionMarkReadiness,
            leadingIcon: Icons.fact_check_outlined,
            enabled: isAllowed,
            onPressed: () => _openReadinessDialog(context),
          ),
          if (detail.summary.isDischargePlanned)
            AppActionItem(
              label: l10n.icuActionOpenDischargeClearance,
              leadingIcon: Icons.assignment_turned_in_outlined,
              enabled: detail.summary.displayId != null,
              onPressed: () =>
                  _openIpdDischargeClearance(context, detail.summary),
            ),
          AppActionItem(
            label: l10n.icuActionOpenBilling,
            leadingIcon: Icons.receipt_long_outlined,
            onPressed: () => context.go(AppRoutes.billing.path),
          ),
          AppActionItem(
            label: l10n.icuActionOpenIpd,
            leadingIcon: Icons.open_in_new_outlined,
            enabled: detail.summary.displayId != null,
            onPressed: () => _openIpdWorkspace(context, detail.summary),
          ),
          AppActionItem(
            label: l10n.icuActionEndStay,
            leadingIcon: Icons.output_outlined,
            enabled: isAllowed && hasActiveStay,
            onPressed: () => _confirmAction(
              context: context,
              title: l10n.icuEndStayTitle,
              body: l10n.icuEndStayBody,
              actionLabel: l10n.icuActionEndStay,
              onConfirmed: controller.transferOut,
            ),
          ),
        ],
        extraActions: <Widget>[
          AppReportActionButton.print(
            label: l10n.icuPrintSummaryLabel,
            onPressed: () async {
              await printFormTemplateDocument(
                ref: ref,
                context: context,
                title: l10n.icuStayDialogTitle,
                patientContext: buildPrintFormPatientContext(
                  l10n,
                  patientName: detail.summary.displayTitle,
                  patientId: detail.summary.patientId,
                  encounterId: detail.summary.encounterId,
                ),
                contextReference: PrintFormContextReference(
                  label: l10n.icuAdmissionLabel,
                  value:
                      detail.summary.displayId ??
                      context.l10n.profileUnknownValue,
                ),
                bodyHtml: _icuSummaryHtml(context, detail),
                includeSignatures: true,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IcuAlertPanel extends StatelessWidget {
  const _IcuAlertPanel({required this.detail});

  final IcuPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IcuCriticalAlertSummary summary = detail.alertSummary;
    return AppWorkspaceDetailPanel(
      title: l10n.icuCriticalAlertsPanelTitle,
      description: summary.total == 0
          ? l10n.icuNoActiveAlertsLabel
          : l10n.icuHighestSeverityLabel(
              apiLabel(summary.highestSeverity ?? ''),
            ),
      child: _RecordList<IcuCriticalAlert>(
        items: detail.alerts,
        emptyLabel: l10n.icuNoActiveAlertsListLabel,
        icon: Icons.notification_important_outlined,
        titleBuilder: (IcuCriticalAlert item) =>
            joinDisplay(<String?>[apiLabel(item.severity ?? ''), item.message]),
        subtitleBuilder: (BuildContext context, IcuCriticalAlert item) =>
            dateTimeLabel(context, item.createdAt),
        statusBuilder: (IcuCriticalAlert item) => AppWorkspaceStatus(
          label: apiLabel(item.severity ?? l10n.icuColumnAlertLabel),
          tone: severityTone(item.severity),
        ),
      ),
    );
  }
}

class _IcuObservationPanel extends StatelessWidget {
  const _IcuObservationPanel({required this.detail});

  final IcuPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: l10n.icuObservationsPanelTitle,
      description: l10n.icuObservationsPanelDescription,
      child: _RecordList<IcuObservation>(
        items: detail.observations,
        emptyLabel: l10n.icuNoObservationsLabel,
        icon: Icons.edit_note_outlined,
        titleBuilder: (IcuObservation item) => item.observation ?? '',
        subtitleBuilder: (BuildContext context, IcuObservation item) =>
            dateTimeLabel(context, item.observedAt ?? item.createdAt),
      ),
    );
  }
}

class _IcuVitalTrendPanel extends StatelessWidget {
  const _IcuVitalTrendPanel({required this.detail});

  final IcuPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: l10n.icuVitalsTrendTitle,
      description: l10n.icuVitalsTrendDescription,
      child: _RecordList<IcuVitalSign>(
        items: detail.vitalSigns,
        emptyLabel: l10n.icuNoVitalsLabel,
        icon: Icons.monitor_heart_outlined,
        titleBuilder: (IcuVitalSign item) =>
            joinDisplay(<String?>[apiLabel(item.vitalType), item.displayValue]),
        subtitleBuilder: (BuildContext context, IcuVitalSign item) =>
            dateTimeLabel(context, item.recordedAt),
        statusBuilder: (IcuVitalSign item) => AppWorkspaceStatus(
          label: apiLabel(item.vitalType),
          tone: vitalTone(item),
        ),
      ),
    );
  }
}

class _IcuCarePanel extends StatelessWidget {
  const _IcuCarePanel({required this.detail});

  final IcuPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<_CareItem> items = <_CareItem>[
      for (final IcuRoundNote item in detail.roundNotes)
        _CareItem(
          title: item.notes ?? l10n.icuRoundNoteFallback,
          subtitle: dateTimeLabel(context, item.roundAt ?? item.createdAt),
          icon: Icons.rate_review_outlined,
        ),
      for (final IcuNursingNote item in detail.nursingNotes)
        _CareItem(
          title: item.note ?? l10n.icuNursingNoteFallback,
          subtitle: joinDisplay(<String?>[
            item.nurseName,
            dateTimeLabel(context, item.createdAt),
          ]),
          icon: Icons.assignment_outlined,
        ),
      for (final IcuMedicationTask item in detail.medicationTasks)
        _CareItem(
          title:
              item.medicationLabel ??
              item.note ??
              l10n.icuMedicationTaskFallback,
          subtitle: joinDisplay(<String?>[
            apiLabel(item.status ?? ''),
            item.dose,
            item.unit,
            item.route,
            item.frequency,
            dateTimeLabel(context, item.scheduledAt),
          ]),
          icon: Icons.medication_outlined,
        ),
      for (final IcuMedicationAdministration item
          in detail.medicationAdministrations)
        _CareItem(
          title: joinDisplay(<String?>[
            l10n.icuDoseLabel,
            item.dose,
            item.unit,
          ]),
          subtitle: joinDisplay(<String?>[
            apiLabel(item.route ?? ''),
            dateTimeLabel(context, item.administeredAt),
          ]),
          icon: Icons.medication_liquid_outlined,
        ),
    ];

    return AppWorkspaceDetailPanel(
      title: l10n.icuCarePanelTitle,
      description: l10n.icuCarePanelDescription,
      child: _RecordList<_CareItem>(
        items: items,
        emptyLabel: l10n.icuNoCareTasksLabel,
        icon: Icons.playlist_add_check_outlined,
        titleBuilder: (_CareItem item) => item.title,
        subtitleBuilder: (_, _CareItem item) => item.subtitle,
        iconBuilder: (_CareItem item) => item.icon,
      ),
    );
  }
}

class _IcuTransferPanel extends StatelessWidget {
  const _IcuTransferPanel({required this.detail});

  final IcuPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<_CareItem> items = <_CareItem>[
      for (final IcuTransferRequest item in detail.transferRequests)
        _CareItem(
          title: joinDisplay(<String?>[
            l10n.icuTransferRecordLabel,
            apiLabel(item.status ?? ''),
          ]),
          subtitle: joinDisplay(<String?>[
            item.fromWardName,
            item.toWardName,
            dateTimeLabel(context, item.requestedAt),
          ]),
          icon: Icons.compare_arrows_outlined,
        ),
      for (final IcuDischargeSummary item in detail.dischargeSummaries)
        _CareItem(
          title: joinDisplay(<String?>[
            l10n.icuDischargeRecordLabel,
            apiLabel(item.status ?? ''),
          ]),
          subtitle: joinDisplay(<String?>[
            item.summary,
            dateTimeLabel(context, item.dischargedAt ?? item.updatedAt),
          ]),
          icon: Icons.fact_check_outlined,
        ),
      for (final IcuStaySummary item in detail.recentStays)
        _CareItem(
          title: item.isActive
              ? l10n.icuActiveStayLabel
              : l10n.icuPreviousStayLabel,
          subtitle: joinDisplay(<String?>[
            item.displayId,
            dateTimeLabel(context, item.startedAt),
            item.endedAt == null
                ? null
                : l10n.icuEndedAtLabel(dateTimeLabel(context, item.endedAt)),
          ]),
          icon: Icons.bed_outlined,
        ),
    ];

    return AppWorkspaceDetailPanel(
      title: l10n.icuTransferPanelTitle,
      description: l10n.icuTransferPanelDescription,
      child: _RecordList<_CareItem>(
        items: items,
        emptyLabel: l10n.icuNoTransferRecordsLabel,
        icon: Icons.compare_arrows_outlined,
        titleBuilder: (_CareItem item) => item.title,
        subtitleBuilder: (_, _CareItem item) => item.subtitle,
        iconBuilder: (_CareItem item) => item.icon,
      ),
    );
  }
}

class _RecordList<T> extends StatelessWidget {
  const _RecordList({
    required this.items,
    required this.emptyLabel,
    required this.titleBuilder,
    required this.subtitleBuilder,
    this.statusBuilder,
    this.iconBuilder,
    this.icon,
  });

  final List<T> items;
  final String emptyLabel;
  final String Function(T item) titleBuilder;
  final String Function(BuildContext context, T item) subtitleBuilder;
  final AppWorkspaceStatus Function(T item)? statusBuilder;
  final IconData Function(T item)? iconBuilder;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < items.length; index += 1) ...<Widget>[
          if (index > 0) const Divider(height: 1),
          _RecordRow<T>(
            item: items[index],
            titleBuilder: titleBuilder,
            subtitleBuilder: subtitleBuilder,
            statusBuilder: statusBuilder,
            icon: iconBuilder?.call(items[index]) ?? icon,
          ),
        ],
      ],
    );
  }
}

class _RecordRow<T> extends StatelessWidget {
  const _RecordRow({
    required this.item,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.statusBuilder,
    this.icon,
  });

  final T item;
  final String Function(T item) titleBuilder;
  final String Function(BuildContext context, T item) subtitleBuilder;
  final AppWorkspaceStatus Function(T item)? statusBuilder;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppWorkspaceStatus? status = statusBuilder?.call(item);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon ?? Icons.description_outlined,
            size: theme.appTokens.listIconSize,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  titleBuilder(item),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  subtitleBuilder(context, item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (status != null) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            Flexible(child: AppWorkspaceStatusBadge(status: status)),
          ],
        ],
      ),
    );
  }
}

class _CareItem {
  const _CareItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _ObservationDialog extends ConsumerStatefulWidget {
  const _ObservationDialog();

  @override
  ConsumerState<_ObservationDialog> createState() => _ObservationDialogState();
}

class _ObservationDialogState extends ConsumerState<_ObservationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _observationController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _observationController = TextEditingController();
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.icuObservationDialogTitle),
      icon: const Icon(Icons.note_add_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppTextField(
              controller: _observationController,
              labelText: l10n.icuObservationFieldLabel,
              enabled: !_isSaving,
              maxLines: 5,
              isRequired: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        l10n.icuRecordActionLabel,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(icuWorkspaceControllerProvider.notifier)
        .recordObservation(observation: _observationController.text.trim());
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _VitalsDialog extends ConsumerStatefulWidget {
  const _VitalsDialog();

  @override
  ConsumerState<_VitalsDialog> createState() => _VitalsDialogState();
}

class _VitalsDialogState extends ConsumerState<_VitalsDialog> {
  late final TextEditingController _temperatureController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _oxygenController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _temperatureController = TextEditingController();
    _systolicController = TextEditingController();
    _diastolicController = TextEditingController();
    _heartRateController = TextEditingController();
    _respiratoryRateController = TextEditingController();
    _oxygenController = TextEditingController();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _oxygenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.icuVitalsDialogTitle),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 780,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          AppFormSection(
            title: l10n.patientsVitalsSectionTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppVitalsForm(
                temperatureController: _temperatureController,
                systolicController: _systolicController,
                diastolicController: _diastolicController,
                heartRateController: _heartRateController,
                respiratoryRateController: _respiratoryRateController,
                oxygenSaturationController: _oxygenController,
                temperatureLabel: l10n.patientsTemperatureLabel,
                systolicLabel: l10n.patientsSystolicLabel,
                diastolicLabel: l10n.patientsDiastolicLabel,
                heartRateLabel: l10n.patientsHeartRateLabel,
                respiratoryRateLabel: l10n.patientsRespiratoryRateLabel,
                oxygenSaturationLabel: l10n.patientsOxygenSaturationLabel,
                bloodPressureLabel: l10n.patientsBloodPressureLabel,
                unitLabel: l10n.patientsVitalUnitLabel,
                enabled: !_isSaving,
              ),
            ],
          ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.icuVitalsUpdateActionLabel,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    final IcuVitalsInput input = IcuVitalsInput(
      temperature: normalizeCurrencyAmount(_temperatureController.text),
      systolic: normalizeCurrencyAmount(_systolicController.text),
      diastolic: normalizeCurrencyAmount(_diastolicController.text),
      heartRate: normalizeCurrencyAmount(_heartRateController.text),
      respiratoryRate: normalizeCurrencyAmount(_respiratoryRateController.text),
      oxygenSaturation: normalizeCurrencyAmount(_oxygenController.text),
      recordedAt: DateTime.now(),
    );
    if (!input.hasAnyValue) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(icuWorkspaceControllerProvider.notifier)
        .recordVitals(input);
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _CriticalAlertDialog extends ConsumerStatefulWidget {
  const _CriticalAlertDialog();

  @override
  ConsumerState<_CriticalAlertDialog> createState() =>
      _CriticalAlertDialogState();
}

class _CriticalAlertDialogState extends ConsumerState<_CriticalAlertDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _messageController;
  String _severity = 'HIGH';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.icuAlertDialogTitle),
      icon: const Icon(Icons.notification_important_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppSelectField<String>(
              value: _severity,
              labelText: l10n.icuAlertSeverityLabel,
              enabled: !_isSaving,
              options: _statusOptions(<String>[
                'LOW',
                'MEDIUM',
                'HIGH',
                'CRITICAL',
              ]),
              onChanged: (String? value) {
                setState(() => _severity = value ?? _severity);
              },
            ),
            AppTextField(
              controller: _messageController,
              labelText: l10n.icuAlertMessageLabel,
              enabled: !_isSaving,
              maxLines: 3,
              isRequired: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        l10n.icuAlertAddActionLabel,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(icuWorkspaceControllerProvider.notifier)
        .addCriticalAlert(
          severity: _severity,
          message: _messageController.text.trim(),
        );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _TransferRequestDialog extends ConsumerStatefulWidget {
  const _TransferRequestDialog({required this.referenceData});

  final IcuReferenceData referenceData;

  @override
  ConsumerState<_TransferRequestDialog> createState() =>
      _TransferRequestDialogState();
}

class _TransferRequestDialogState
    extends ConsumerState<_TransferRequestDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _wardController;
  String? _wardId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _wardController = TextEditingController();
  }

  @override
  void dispose() {
    _wardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<IcuWardOption> wards = widget.referenceData.wards;
    return AppDialog(
      title: Text(l10n.icuTransferDialogTitle),
      icon: const Icon(Icons.compare_arrows_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            if (wards.isEmpty)
              AppTextField(
                controller: _wardController,
                labelText: l10n.icuTransferTargetWardIdLabel,
                enabled: !_isSaving,
                isRequired: true,
                validator: AppValidators.requiredText(l10n.validationRequired),
              )
            else
              AppSelectField<String>.searchable(
                value: _wardId,
                labelText: l10n.icuTransferTargetWardLabel,
                enabled: !_isSaving,
                options: <AppSelectOption<String>>[
                  for (final IcuWardOption ward in wards)
                    AppSelectOption<String>(
                      value: ward.id,
                      label: joinDisplay(<String?>[
                        ward.displayTitle,
                        apiLabel(ward.wardType ?? ''),
                      ]),
                    ),
                ],
                onChanged: (String? value) => setState(() => _wardId = value),
                validator: (String? value) {
                  if ((value ?? '').trim().isEmpty) {
                    return l10n.validationRequired;
                  }
                  return null;
                },
              ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        l10n.icuTransferRequestActionLabel,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String toWardId = _wardId ?? _wardController.text.trim();
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(icuWorkspaceControllerProvider.notifier)
        .requestTransfer(toWardId: toWardId);
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _ManageTransferDialog extends ConsumerStatefulWidget {
  const _ManageTransferDialog();

  @override
  ConsumerState<_ManageTransferDialog> createState() =>
      _ManageTransferDialogState();
}

class _ManageTransferDialogState extends ConsumerState<_ManageTransferDialog> {
  String? _bedId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final IcuWorkspaceState? state = ref
        .read(icuWorkspaceControllerProvider)
        .asData
        ?.value
        .when(success: (IcuWorkspaceState s) => s, failure: (_) => null);
    if (state != null && state.bedBoard.beds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(icuWorkspaceControllerProvider.notifier).loadBedBoard();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IcuWorkspaceState? state = ref
        .watch(icuWorkspaceControllerProvider)
        .asData
        ?.value
        .when(success: (IcuWorkspaceState s) => s, failure: (_) => null);
    final IcuPatientDetail? detail = state?.selectedDetail;
    final IcuTransferRequest? open = detail?.transferRequests
        .where((IcuTransferRequest item) => _isOpenTransfer(item.status))
        .firstOrNull;

    if (open == null) {
      return AppDialog(
        title: Text(l10n.icuManageTransferDialogTitle),
        icon: const Icon(Icons.published_with_changes_outlined),
        content: Text(l10n.icuTransferNoOpenLabel),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      );
    }

    final List<IcuBed> availableBeds =
        (state?.bedBoard.beds ?? const <IcuBed>[])
            .where((IcuBed bed) => bed.isAvailable)
            .toList(growable: false);
    final String status = (open.status ?? '').toUpperCase();
    final List<IcuTransferAction> actions = _availableActions(status);

    return AppDialog(
      title: Text(l10n.icuManageTransferDialogTitle),
      icon: const Icon(Icons.published_with_changes_outlined),
      scrollable: true,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          Text(
            joinDisplay(<String?>[
              apiLabel(open.status ?? ''),
              open.fromWardName,
              open.toWardName,
            ]),
          ),
          if (actions.contains(IcuTransferAction.complete))
            AppSelectField<String>.searchable(
              value: _bedId,
              labelText: l10n.icuTransferSelectBedLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                for (final IcuBed bed in availableBeds)
                  AppSelectOption<String>(
                    value: bed.id,
                    label: bed.locationLabel,
                  ),
              ],
              onChanged: (String? value) => setState(() => _bedId = value),
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        for (final IcuTransferAction action in actions)
          AppButton.primary(
            label: _actionLabel(l10n, action),
            isLoading: _isSaving,
            onPressed: () => _submit(open, action),
          ),
      ],
    );
  }

  List<IcuTransferAction> _availableActions(String status) {
    return switch (status) {
      'REQUESTED' => <IcuTransferAction>[
        IcuTransferAction.approve,
        IcuTransferAction.cancel,
      ],
      'APPROVED' => <IcuTransferAction>[
        IcuTransferAction.start,
        IcuTransferAction.cancel,
      ],
      'IN_PROGRESS' => <IcuTransferAction>[
        IcuTransferAction.complete,
        IcuTransferAction.cancel,
      ],
      _ => <IcuTransferAction>[IcuTransferAction.cancel],
    };
  }

  String _actionLabel(AppLocalizations l10n, IcuTransferAction action) {
    return switch (action) {
      IcuTransferAction.approve => l10n.icuTransferActionApprove,
      IcuTransferAction.start => l10n.icuTransferActionStart,
      IcuTransferAction.complete => l10n.icuTransferActionComplete,
      IcuTransferAction.cancel => l10n.icuTransferActionCancel,
    };
  }

  Future<void> _submit(
    IcuTransferRequest open,
    IcuTransferAction action,
  ) async {
    if (action.requiresBed && (_bedId == null || _bedId!.isEmpty)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = await controller.updateTransfer(
      transferRequestId: open.id,
      action: action,
      toBedId: action.requiresBed ? _bedId : null,
    );
    if (!mounted) {
      return;
    }
    if (failure != null) {
      setState(() {
        _failure = failure;
        _isSaving = false;
      });
      return;
    }
    Navigator.of(context).pop(true);
    // After a completed step-down, prompt to end the ICU stay if still active.
    if (action == IcuTransferAction.complete) {
      final IcuWorkspaceState? latest = _readIcuState(ref);
      final bool stillActive = latest?.selectedDetail?.activeStay != null;
      if (stillActive && context.mounted) {
        unawaited(_promptEndStayAfterStepDown(context));
      }
    }
  }
}

class _ReadinessDialog extends ConsumerStatefulWidget {
  const _ReadinessDialog();

  @override
  ConsumerState<_ReadinessDialog> createState() => _ReadinessDialogState();
}

class _ReadinessDialogState extends ConsumerState<_ReadinessDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _summaryController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.icuReadinessDialogTitle),
      icon: const Icon(Icons.fact_check_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          description: l10n.icuReadinessDescription,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppTextField(
              controller: _summaryController,
              labelText: l10n.icuReadinessNoteLabel,
              enabled: !_isSaving,
              maxLines: 5,
              isRequired: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: _dialogActions(
        context,
        l10n.icuReadinessMarkActionLabel,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(icuWorkspaceControllerProvider.notifier)
        .markDischargeReady(summary: _summaryController.text.trim());
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

class _AssignBedDialog extends ConsumerStatefulWidget {
  const _AssignBedDialog();

  @override
  ConsumerState<_AssignBedDialog> createState() => _AssignBedDialogState();
}

class _AssignBedDialogState extends ConsumerState<_AssignBedDialog> {
  late final TextEditingController _bedController;
  String? _bedId;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _bedController = TextEditingController();
    final IcuWorkspaceState? state = _readIcuState(ref);
    if (state != null && state.bedBoard.beds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(icuWorkspaceControllerProvider.notifier).loadBedBoard();
      });
    }
  }

  @override
  void dispose() {
    _bedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final IcuWorkspaceState? state = ref
        .watch(icuWorkspaceControllerProvider)
        .asData
        ?.value
        .when(success: (IcuWorkspaceState s) => s, failure: (_) => null);
    final List<IcuBed> beds = (state?.bedBoard.beds ?? const <IcuBed>[])
        .where((IcuBed bed) => bed.isAvailable)
        .toList(growable: false);

    return AppDialog(
      title: Text(l10n.icuAssignBedDialogTitle),
      icon: const Icon(Icons.bed_outlined),
      scrollable: true,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          if (beds.isEmpty)
            AppTextField(
              controller: _bedController,
              labelText: l10n.icuTransferSelectBedLabel,
              enabled: !_isSaving,
            )
          else
            AppSelectField<String>.searchable(
              value: _bedId,
              labelText: l10n.icuTransferSelectBedLabel,
              enabled: !_isSaving,
              options: <AppSelectOption<String>>[
                for (final IcuBed bed in beds)
                  AppSelectOption<String>(
                    value: bed.id,
                    label: bed.locationLabel,
                  ),
              ],
              onChanged: (String? value) => setState(() => _bedId = value),
            ),
        ],
      ),
      actions: _dialogActions(
        context,
        l10n.icuActionAssignBed,
        _isSaving,
        _submit,
      ),
    );
  }

  Future<void> _submit() async {
    final String bedId = _bedId ?? _bedController.text.trim();
    if (bedId.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(icuWorkspaceControllerProvider.notifier)
        .assignBed(bedId);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

List<Widget> _dialogActions(
  BuildContext context,
  String submitLabel,
  bool isSaving,
  VoidCallback onSubmit,
) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    AppButton.tertiary(
      label: l10n.commonCancelActionLabel,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      isLoading: isSaving,
      onPressed: onSubmit,
    ),
  ];
}

Future<void> _openObservationDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ObservationDialog(),
    ),
  );
}

Future<void> _openVitalsDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _VitalsDialog(),
    ),
  );
}

Future<void> _openAlertDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CriticalAlertDialog(),
    ),
  );
}

Future<void> _openRoundDialog(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: l10n.icuRoundDialogTitle,
        label: l10n.icuRoundNoteLabel,
        submitLabel: l10n.icuRoundAddActionLabel,
        icon: const Icon(Icons.rate_review_outlined),
        maxLines: 4,
        onSubmit: (String note) {
          return ProviderScope.containerOf(context, listen: false)
              .read(icuWorkspaceControllerProvider.notifier)
              .addRoundNote(notes: note);
        },
      ),
    ),
  );
}

Future<void> _openTransferDialog(
  BuildContext context,
  IcuReferenceData referenceData,
) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferRequestDialog(referenceData: referenceData),
    ),
  );
}

Future<void> _openManageTransferDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ManageTransferDialog(),
    ),
  );
}

Future<void> _openReadinessDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReadinessDialog(),
    ),
  );
}

Future<void> _openAssignBedDialog(BuildContext context) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AssignBedDialog(),
    ),
  );
}

Future<void> _openLabOrderDialog(BuildContext context) async {
  final IcuWorkspaceController controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(icuWorkspaceControllerProvider.notifier);
  final ClinicalReferenceData referenceData = await controller
      .clinicalReferenceData();
  if (!context.mounted) {
    return;
  }
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalLabOrderActionDialog(
        referenceData: referenceData,
        onSearchLabTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 80,
                source: source,
              );
            },
        onRequest:
            ({
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return controller.orderLab(
                labTestIds: labTestIds,
                labPanelIds: labPanelIds,
                billing: billing,
              );
            },
        onUpdate:
            ({
              required String labOrderId,
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return controller.orderLab(
                labTestIds: labTestIds,
                labPanelIds: labPanelIds,
                billing: billing,
              );
            },
      ),
    ),
  );
}

Future<void> _openRadiologyOrderDialog(BuildContext context) async {
  final IcuWorkspaceController controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(icuWorkspaceControllerProvider.notifier);
  final ClinicalReferenceData referenceData = await controller
      .clinicalReferenceData();
  if (!context.mounted) {
    return;
  }
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalRadiologyOrderActionDialog(
        referenceData: referenceData,
        onSubmit: controller.orderRadiology,
      ),
    ),
  );
}

Future<void> _openPrescriptionDialog(BuildContext context) async {
  final IcuWorkspaceController controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(icuWorkspaceControllerProvider.notifier);
  final ClinicalReferenceData referenceData = await controller
      .clinicalReferenceData();
  if (!context.mounted) {
    return;
  }
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalPrescriptionActionDialog(
        referenceData: referenceData,
        onSubmit: controller.prescribeMedication,
      ),
    ),
  );
}

void _openIpdWorkspace(BuildContext context, IcuPatientSummary summary) {
  final String? displayId = summary.displayId?.trim();
  final String location = displayId == null || displayId.isEmpty
      ? AppRoutes.ipd.path
      : AppRoutes.ipd.location(
          queryParameters: <String, String>{'id': displayId},
        );
  context.go(location);
}

void _openIpdDischargeClearance(
  BuildContext context,
  IcuPatientSummary summary,
) {
  final String? displayId = summary.displayId?.trim();
  if (displayId == null || displayId.isEmpty) {
    context.go(AppRoutes.ipd.path);
    return;
  }
  context.go(
    AppRoutes.ipd.location(
      queryParameters: <String, String>{'id': displayId, 'panel': 'discharge'},
    ),
  );
}

Future<void> _promptEndStayAfterStepDown(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return _confirmAction(
    context: context,
    title: l10n.icuStepDownPromptTitle,
    body: l10n.icuStepDownPromptBody,
    actionLabel: l10n.icuActionEndStay,
    onConfirmed: () => ProviderScope.containerOf(
      context,
      listen: false,
    ).read(icuWorkspaceControllerProvider.notifier).transferOut(),
  );
}

Future<void> _confirmAction({
  required BuildContext context,
  required String title,
  required String body,
  required String actionLabel,
  required Future<AppFailure?> Function() onConfirmed,
}) {
  return _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppConfirmActionDialog(
        title: title,
        body: body,
        submitLabel: actionLabel,
        icon: const Icon(Icons.warning_amber_outlined),
        onConfirm: onConfirmed,
      ),
    ),
  );
}

Future<void> _showActionResult(
  BuildContext context,
  Future<bool?> future,
) async {
  final bool? saved = await future;
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.icuChangesSavedMessage)),
    );
  }
}

List<AppSelectOption<IcuBoardScope>> _scopeOptions(AppLocalizations l10n) {
  return <AppSelectOption<IcuBoardScope>>[
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.active,
      label: l10n.icuActiveIcuLabel,
    ),
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.critical,
      label: l10n.icuCriticalAlertsLabel,
    ),
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.transfer,
      label: l10n.icuTransferPendingLabel,
    ),
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.discharge,
      label: l10n.icuDischargeReadyLabel,
    ),
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.ended,
      label: l10n.icuEndedStaysLabel,
    ),
    AppSelectOption<IcuBoardScope>(
      value: IcuBoardScope.all,
      label: l10n.icuAllIcuLabel,
    ),
  ];
}

const String _icuScopeFilterKey = 'scope';

AppSearchBarFilterValue _icuFilterValue(IcuBoardQuery query) {
  if (query.scope == IcuBoardScope.active) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    options: <String, String>{_icuScopeFilterKey: query.scope.name},
  );
}

IcuBoardScope _icuScopeFromFilter(String? value) {
  for (final IcuBoardScope scope in IcuBoardScope.values) {
    if (scope.name == value) {
      return scope;
    }
  }
  return IcuBoardScope.active;
}

List<AppSearchBarFilterChoice> _icuScopeFilterChoices(AppLocalizations l10n) {
  return <AppSearchBarFilterChoice>[
    for (final AppSelectOption<IcuBoardScope> option in _scopeOptions(l10n))
      if (option.value != IcuBoardScope.active)
        AppSearchBarFilterChoice(
          value: option.value.name,
          label: option.label,
          icon: Icons.filter_list,
        ),
  ];
}

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: apiLabel(value)),
  ];
}

bool _isOpenTransfer(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'REQUESTED' || 'APPROVED' || 'IN_PROGRESS' => true,
    _ => false,
  };
}

int _pageTotal<T>(AppPage<T> page) => page.totalItemCount ?? page.items.length;

String _pageLabel(BuildContext context, AppPage<IcuPatientSummary> page) {
  final int total = page.totalItemCount ?? page.items.length;
  if (total == 0) {
    return context.l10n.opdPageLabel(0, 0, 0);
  }
  final int from = page.request.pageIndex * page.request.pageSize + 1;
  final int to = (from + page.items.length - 1).clamp(from, total);
  return context.l10n.opdPageLabel(from, to, total);
}

String _icuSummaryHtml(BuildContext context, IcuPatientDetail detail) {
  final AppLocalizations l10n = context.l10n;
  final StringBuffer buffer = StringBuffer()
    ..write(
      PrintFormTemplate.section(
        title: l10n.icuPrintAlertsSection,
        bodyHtml: _alertHtml(l10n, detail.alerts),
      ),
    )
    ..write(
      PrintFormTemplate.section(
        title: l10n.icuPrintObservationsSection,
        bodyHtml: _observationHtml(l10n, detail.observations),
      ),
    )
    ..write(
      PrintFormTemplate.section(
        title: l10n.icuPrintVitalsSection,
        bodyHtml: _vitalsHtml(l10n, detail.vitalSigns),
      ),
    )
    ..write(
      PrintFormTemplate.section(
        title: l10n.icuPrintTransferSection,
        bodyHtml: _readinessHtml(l10n, detail),
      ),
    );
  return buffer.toString();
}

String _alertHtml(AppLocalizations l10n, List<IcuCriticalAlert> alerts) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuCriticalAlert alert in alerts)
      joinDisplay(<String?>[apiLabel(alert.severity ?? ''), alert.message]),
  ], emptyText: l10n.icuNoActiveAlertsListLabel);
}

String _observationHtml(
  AppLocalizations l10n,
  List<IcuObservation> observations,
) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuObservation observation in observations)
      observation.observation ?? '',
  ], emptyText: l10n.icuNoObservationsLabel);
}

String _vitalsHtml(AppLocalizations l10n, List<IcuVitalSign> vitals) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuVitalSign vital in vitals)
      joinDisplay(<String?>[apiLabel(vital.vitalType), vital.displayValue]),
  ], emptyText: l10n.icuNoVitalsLabel);
}

String _readinessHtml(AppLocalizations l10n, IcuPatientDetail detail) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final IcuTransferRequest transfer in detail.transferRequests)
      joinDisplay(<String?>[
        l10n.icuTransferRecordLabel,
        apiLabel(transfer.status ?? ''),
        transfer.toWardName,
      ]),
    for (final IcuDischargeSummary discharge in detail.dischargeSummaries)
      joinDisplay(<String?>[
        l10n.icuDischargeRecordLabel,
        apiLabel(discharge.status ?? ''),
        discharge.summary,
      ]),
  ], emptyText: l10n.icuNoTransferRecordsLabel);
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}
