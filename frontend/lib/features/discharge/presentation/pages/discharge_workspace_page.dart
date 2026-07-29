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
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/presentation/controllers/discharge_workspace_controller.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';
import 'package:hosspi_hms/features/discharge/presentation/widgets/discharge_clearance_tile.dart';
import 'package:hosspi_hms/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class DischargeWorkspacePage extends ConsumerStatefulWidget {
  const DischargeWorkspacePage({super.key, this.initialQuery});

  final DischargeWorklistQuery? initialQuery;

  @override
  ConsumerState<DischargeWorkspacePage> createState() =>
      _DischargeWorkspacePageState();
}

class _DischargeWorkspacePageState
    extends ConsumerState<DischargeWorkspacePage> {
  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _scheduleDeepLink();
  }

  void _scheduleDeepLink() {
    final DischargeWorklistQuery? query = widget.initialQuery;
    if (query == null || !query.hasRouteTargeting || _deepLinkHandled) {
      return;
    }
    _deepLinkHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_handleDeepLink(query));
    });
  }

  Future<void> _handleDeepLink(DischargeWorklistQuery query) async {
    final DischargeWorkspaceController controller = ref.read(
      dischargeWorkspaceControllerProvider.notifier,
    );
    if (query.focusAdmissionId == null && query.search.isNotEmpty) {
      await controller.applyBoardQuery(query);
    }
    final String? focusId = query.focusAdmissionId?.trim();
    if (focusId == null || focusId.isEmpty) {
      return;
    }
    final AppFailure? failure = await controller.selectAdmissionByDisplayId(
      focusId,
    );
    if (!mounted || failure != null) {
      return;
    }
    final DischargeWorkspaceState? state = _readDischargeState(ref);
    final DischargeAdmissionDetail? detail = state?.selectedDetail;
    if (detail == null) {
      return;
    }
    await _openDischargeDetailDialog(context, ref, state!, detail.summary);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Result<DischargeWorkspaceState>> value = ref.watch(
      dischargeWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return AsyncStateScaffold<DischargeWorkspaceState>(
      value: value,
      loadingTitle: l10n.dischargeLoadingTitle,
      loadingBody: l10n.dischargeLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.invalidate(dischargeWorkspaceControllerProvider);
      },
      dataBuilder: (BuildContext context, DischargeWorkspaceState state) {
        return _DischargeWorkspaceContent(
          state: state,
          initialQuery: widget.initialQuery,
        );
      },
    );
  }
}

class _DischargeWorkspaceContent extends ConsumerStatefulWidget {
  const _DischargeWorkspaceContent({required this.state, this.initialQuery});

  final DischargeWorkspaceState state;
  final DischargeWorklistQuery? initialQuery;

  @override
  ConsumerState<_DischargeWorkspaceContent> createState() {
    return _DischargeWorkspaceContentState();
  }
}

class _DischargeWorkspaceContentState
    extends ConsumerState<_DischargeWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<IpdAdmissionSummary>
  _columnVisibilityController;
  late DischargeDeskSection _section;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _columnVisibilityController =
        AppListTableColumnVisibilityController<IpdAdmissionSummary>();
    _section =
        _sectionFromQuery(widget.initialQuery?.section ?? '') ??
        DischargeDeskSection.all;
  }

  @override
  void didUpdateWidget(covariant _DischargeWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.value = TextEditingValue(text: search);
    }
    final String? nextSection = widget.initialQuery?.section;
    final String? previousSection = oldWidget.initialQuery?.section;
    if (nextSection != previousSection) {
      final DischargeDeskSection? parsed = _sectionFromQuery(nextSection ?? '');
      if (parsed != null && parsed != _section) {
        _section = parsed;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  void _updateUrlForSection(DischargeDeskSection section) {
    if (!mounted) {
      return;
    }
    final String tab = _sectionToQueryValue(section);
    final String location = AppRoutes.discharge.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    GoRouter.of(context).replace<void>(location);
  }

  static String _sectionToQueryValue(DischargeDeskSection section) {
    return switch (section) {
      DischargeDeskSection.all => 'all',
      DischargeDeskSection.planned => 'planned',
      DischargeDeskSection.pendingClearance => 'pending',
      DischargeDeskSection.completed => 'completed',
      DischargeDeskSection.followUps => 'follow-ups',
    };
  }

  static DischargeDeskSection? _sectionFromQuery(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'all':
        return DischargeDeskSection.all;
      case 'planned':
        return DischargeDeskSection.planned;
      case 'pending':
      case 'pending_clearance':
      case 'pending-clearance':
      case 'pendingclearance':
        return DischargeDeskSection.pendingClearance;
      case 'completed':
      case 'discharged':
        return DischargeDeskSection.completed;
      case 'follow-ups':
      case 'follow_ups':
      case 'followups':
        return DischargeDeskSection.followUps;
      default:
        return null;
    }
  }

  String _sectionLabel(AppLocalizations l10n, DischargeDeskSection section) {
    return switch (section) {
      DischargeDeskSection.all => l10n.dischargeSectionAll,
      DischargeDeskSection.planned => l10n.dischargeSectionPlanned,
      DischargeDeskSection.pendingClearance =>
        l10n.dischargeSectionPendingClearance,
      DischargeDeskSection.completed => l10n.dischargeSectionCompleted,
      DischargeDeskSection.followUps => l10n.opdFollowUpsTitle,
    };
  }

  static IconData _sectionIcon(DischargeDeskSection section) {
    return switch (section) {
      DischargeDeskSection.all => Icons.inventory_2_outlined,
      DischargeDeskSection.planned => Icons.event_available_outlined,
      DischargeDeskSection.pendingClearance => Icons.pending_actions_outlined,
      DischargeDeskSection.completed => Icons.check_circle_outline,
      DischargeDeskSection.followUps => Icons.phone_callback_outlined,
    };
  }

  int? _sectionCount(
    DischargeWorkspaceState state,
    DischargeDeskSection section,
  ) {
    if (section.isFollowUps) {
      return null;
    }
    return switch (section) {
      DischargeDeskSection.all => state.queue.items.length,
      DischargeDeskSection.planned => state.plannedCount,
      DischargeDeskSection.pendingClearance => state.summaryPendingCount,
      DischargeDeskSection.completed => state.completedCount,
      DischargeDeskSection.followUps => null,
    };
  }

  static AppTabCountTone _sectionCountTone(DischargeDeskSection section) {
    return switch (section) {
      DischargeDeskSection.planned ||
      DischargeDeskSection.pendingClearance => AppTabCountTone.warning,
      DischargeDeskSection.all ||
      DischargeDeskSection.completed ||
      DischargeDeskSection.followUps => AppTabCountTone.info,
    };
  }

  List<IpdAdmissionSummary> _buildRows(DischargeWorkspaceState state) {
    return switch (_section) {
      DischargeDeskSection.followUps => const <IpdAdmissionSummary>[],
      DischargeDeskSection.all => state.queue.items.toList(),
      DischargeDeskSection.planned =>
        state.queue.items.where(isPlannedDischarge).toList(),
      DischargeDeskSection.pendingClearance =>
        state.queue.items
            .where(
              (IpdAdmissionSummary item) =>
                  !isCompletedDischarge(item) && !isPlannedDischarge(item),
            )
            .toList(),
      DischargeDeskSection.completed =>
        state.queue.items.where(isCompletedDischarge).toList(),
    };
  }

  void _handleTabChanged(DischargeDeskSection section) {
    if (section == _section) {
      return;
    }
    setState(() {
      _section = section;
    });
    _updateUrlForSection(section);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DischargeWorkspaceState state = widget.state;
    final DischargeWorkspaceController controller = ref.read(
      dischargeWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final List<DischargeDeskSection> visibleSections =
        dischargeAllowedSections(accessPolicy);
    if (visibleSections.isEmpty) {
      return const SizedBox.shrink();
    }
    if (!visibleSections.contains(_section)) {
      final DischargeDeskSection fallback = visibleSections.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleSections.contains(_section)) {
          return;
        }
        _handleTabChanged(fallback);
      });
    }

    final List<IpdAdmissionSummary> rows = _buildRows(state);
    final List<AppListTableColumn<IpdAdmissionSummary>> allColumns =
        _dischargeTableColumns(context);
    final List<AppListTableColumn<IpdAdmissionSummary>> defaultColumns =
        _dischargeDefaultColumns(context, section: _section);

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final DischargeDeskSection section in visibleSections)
                  AppTabItem(
                    id: section.name,
                    icon: _sectionIcon(section),
                    label: _sectionLabel(l10n, section),
                    count: section == DischargeDeskSection.followUps
                        ? ref.watch(
                            followUpTabCountProvider(
                              const FollowUpWorklistScope(
                                encounterType: 'IPD',
                              ),
                            ),
                          )
                        : _sectionCount(state, section),
                    countTone: _sectionCountTone(section),
                  ),
              ],
              selectedId: _section.name,
              onTabTapped: (String tabId) {
                for (final DischargeDeskSection section in visibleSections) {
                  if (section.name == tabId) {
                    _handleTabChanged(section);
                    break;
                  }
                }
              },
            ),
            SizedBox(height: theme.spacing.sm),
            if (_section.isFollowUps)
              const FollowUpWorklistPanel(
                scope: FollowUpWorklistScope(encounterType: 'IPD'),
                storageKeyPrefix: 'discharge_follow_ups',
                readRequirement: dischargeFollowUpsRequirement,
                writeRequirement: dischargeFollowUpsWriteRequirement,
              )
            else if (dischargeSectionTabRequirement(_section).isAllowed(
              accessPolicy,
            ))
              AppListTable<IpdAdmissionSummary>(
              items: rows,
              columns: defaultColumns,
              columnChoices: allColumns,
              columnVisibilityController: _columnVisibilityController,
              columnVisibilityStorageKey: 'discharge_${_section.name}',
              columnWidthStorageKey: 'discharge_cw_${_section.name}',
              columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
              columnVisibilityTitle: l10n.commonTableSettingsTitle,
              isLoading: state.isRefreshing,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onRowSelected: (IpdAdmissionSummary item) {
                unawaited(
                  _openDischargeDetailDialog(context, ref, state, item),
                );
              },
              search: AppListTableSearch<IpdAdmissionSummary>(
                controller: _searchController,
                semanticLabel: l10n.dischargeQueueSearchLabel,
                hintText: l10n.dischargeQueueSearchHint,
                matcher: (IpdAdmissionSummary item, String query) =>
                    _dischargeMatchesSearch(context, item, query),
                onSubmitted: (String value) async {
                  final AppFailure? failure = await controller.applySearch(
                    value,
                  );
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
                advancedFilterButtonLabel: l10n.dischargeFiltersLabel,
                advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
                advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                advancedFilterResetLabel: l10n.opdClearFiltersAction,
                enableDateFilter: false,
                allFieldsLabel: l10n.dischargeStatusAll,
                filterGroups: <AppSearchBarFilterGroup>[
                  AppSearchBarFilterGroup(
                    key: _dischargeStatusFilterKey,
                    label: l10n.dischargeStatusFilterLabel,
                    allLabel: l10n.dischargeStatusAll,
                    choices: _dischargeStatusFilterChoices(l10n),
                  ),
                ],
                filterValue: _dischargeFilterValue(state.query),
                hasActiveFilters:
                    state.query.status != DischargeStatusFilter.all,
                onFilterChanged: (AppSearchBarFilterValue value) async {
                  final AppFailure? failure = await controller.applyStatus(
                    _dischargeStatusFromFilter(
                      value.option(_dischargeStatusFilterKey),
                    ),
                  );
                  if (context.mounted) {
                    _showFailureIfNeeded(context, failure);
                  }
                },
              ),
              emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
                title: l10n.dischargeEmptyQueueTitle,
                body: l10n.dischargeEmptyQueueBody,
                icon: Icons.inbox_outlined,
              ),
              mobileItemBuilder:
                  (BuildContext context, IpdAdmissionSummary item) {
                    final AppLocalizations l10n = context.l10n;
                    return AppListTableMobileItem(
                      title: item.displayTitle,
                      caption: item.displayId ?? l10n.profileUnknownValue,
                      meta: <AppListTableMobileMeta>[
                        AppListTableMobileMeta(
                          label: _locationLabel(context, item),
                        ),
                        AppListTableMobileMeta(
                          label: _statusFor(context, item).label,
                        ),
                        ...switch (_section) {
                          DischargeDeskSection.all ||
                          DischargeDeskSection.completed =>
                            <AppListTableMobileMeta>[
                              AppListTableMobileMeta(
                                label: _dateLabel(
                                  context,
                                  item.dischargedAt,
                                ),
                                icon: AppActionIcons.calendar,
                              ),
                            ],
                          DischargeDeskSection.planned =>
                            item.clearancePhase != null
                                ? <AppListTableMobileMeta>[
                                    AppListTableMobileMeta(
                                      label: _apiLabel(item.clearancePhase!),
                                    ),
                                  ]
                                : <AppListTableMobileMeta>[],
                          DischargeDeskSection.pendingClearance =>
                            <AppListTableMobileMeta>[
                              AppListTableMobileMeta(
                                label: _blockingItemLabel(context, item),
                              ),
                            ],
                          _ => <AppListTableMobileMeta>[],
                        },
                      ],
                    );
                  },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openDischargeDetailDialog(
  BuildContext context,
  WidgetRef ref,
  DischargeWorkspaceState fallbackState,
  IpdAdmissionSummary admission,
) async {
  final DischargeWorkspaceController controller = ref.read(
    dischargeWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectAdmission(admission);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final DischargeWorkspaceState state =
      _readDischargeState(ref) ?? fallbackState;
  final DischargeAdmissionDetail? detail = state.selectedDetail;
  if (detail == null) {
    return;
  }
  final AppLocalizations l10n = context.l10n;

  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.dischargeDetailTitle),
      icon: const Icon(Icons.assignment_turned_in_outlined),
      scrollable: true,
      maxWidth: 980,
      content: _DischargeDetailContent(state: state, detail: detail),
      actions: <Widget>[
        AppReportActionButton.print(
          label: l10n.dischargePrintSummaryAction,
          onPressed: detail.hasSummary
              ? () => unawaited(_printDischargeSummary(context, ref, detail))
              : null,
        ),
      ],
    ),
  );
}

DischargeWorkspaceState? _readDischargeState(WidgetRef ref) {
  return ref
      .read(dischargeWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (DischargeWorkspaceState state) => state,
        failure: (_) => null,
      );
}

class _DischargeDetailContent extends ConsumerWidget {
  const _DischargeDetailContent({required this.state, required this.detail});

  final DischargeWorkspaceState state;
  final DischargeAdmissionDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DischargeWorkspaceController controller = ref.read(
      dischargeWorkspaceControllerProvider.notifier,
    );
    final String continueDischargeLabel = detail.hasSummary
        ? clinicalDispositionActionLabel(
            l10n,
            sourceQueue: 'IPD',
            status: detail.summary.admissionStatus,
            stage: detail.summary.stage,
            location: detail.summary.location,
            hasAdmission: true,
          )
        : l10n.dischargeStartPlanAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPatientDetails(
          patientName: detail.ipd.patientDisplayName,
          patientNumber: (detail.patientId ?? '').trim(),
          patientNumberLabel: l10n.dischargeReportPatientNoLabel,
          ageLabel: _patientAgeLabel(context, detail),
          genderLabel: _patientGenderLabel(context, detail),
          semanticLabel: l10n.dischargePatientContextLabel,
          showAvatar: false,
          status: _statusFor(context, detail.summary),
          expandedFields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.dischargeAdmissionFieldLabel,
              value: detail.summary.displayId ?? '',
              icon: Icons.local_hotel_outlined,
              copyable: true,
              copyTooltip: l10n.copyAdmissionIdAction,
              copiedMessage: l10n.admissionIdCopiedMessage,
            ),
            AppWorkspacePatientContextField(
              label: l10n.dischargeEncounterFieldLabel,
              value: detail.encounterId ?? detail.summary.encounterId ?? '',
              icon: Icons.assignment_outlined,
              copyable:
                  (detail.encounterId ?? detail.summary.encounterId)
                      ?.isNotEmpty ==
                  true,
              copyTooltip: l10n.opdCopyEncounterIdAction,
              copiedMessage: l10n.opdEncounterIdCopiedMessage,
            ),
            AppWorkspacePatientContextField(
              label: l10n.dischargeLocationFieldLabel,
              value: _locationLabel(context, detail.summary),
              icon: Icons.location_on_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.dischargeTargetFieldLabel,
              value: _dateLabel(
                context,
                detail.latestDischargeSummary?.dischargedAt,
              ),
              icon: Icons.event_outlined,
            ),
          ],
          actions: <Widget>[
            if (!detail.isCompleted)
              AppAccessActionGate(
                requirement: DischargeAllPatientsAtomPermissions.continueDischarge,
                builder: (BuildContext context, bool isAllowed) {
                  return AppButton.primary(
                    label: continueDischargeLabel,
                    leadingIcon: detail.hasSummary
                        ? Icons.exit_to_app_outlined
                        : Icons.edit_note_outlined,
                    isLoading: state.isSaving,
                    onPressed: () => _openDischargePlanningDialog(
                      context,
                      ref,
                      detail,
                      title: Text(continueDischargeLabel),
                    ),
                  );
                },
              ),
            AppAccessActionGate(
              requirement: DischargeAllPatientsAtomPermissions.requestBilling,
              builder: (BuildContext context, bool isAllowed) {
                return AppButton.secondary(
                  label: l10n.dischargeRequestBillingAction,
                  leadingIcon: Icons.receipt_long_outlined,
                  isLoading: state.isSaving,
                  onPressed: () => _openBillingDialog(context, controller),
                );
              },
            ),
            AppAccessActionGate(
              requirement: DischargeAllPatientsAtomPermissions.requestPharmacy,
              builder: (BuildContext context, bool isAllowed) {
                return AppButton.secondary(
                  label: l10n.dischargeRequestPharmacyAction,
                  leadingIcon: Icons.medication_outlined,
                  isLoading: state.isSaving,
                  onPressed: () =>
                      _openPharmacyDialog(context, controller, state),
                );
              },
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        _CrossModuleLinksSection(detail: detail),
        SizedBox(height: theme.spacing.lg),
        if (detail.ipd.pendingDischargeOrders.isNotEmpty) ...<Widget>[
          _PendingOrdersSection(detail: detail),
          SizedBox(height: theme.spacing.lg),
        ],
        _ClearanceChecklist(detail: detail),
        SizedBox(height: theme.spacing.lg),
        _SummarySection(detail: detail),
        SizedBox(height: theme.spacing.lg),
        AppAccessGate(
          requirement: DischargeAllPatientsAtomPermissions.medicinesPanel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _RelatedRecordsSection(
                title: l10n.dischargeMedicinesSectionTitle,
                emptyBody: detail.pharmacyDataUnavailable
                    ? l10n.dischargePharmacyUnavailableBody
                    : l10n.dischargeNoMedicinesBody,
                records: detail.pharmacyOrders,
                icon: Icons.medication_outlined,
              ),
              SizedBox(height: theme.spacing.lg),
            ],
          ),
        ),
        AppAccessGate(
          requirement: DischargeAllPatientsAtomPermissions.billingPanel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _RelatedRecordsSection(
                title: l10n.dischargeBillingSectionTitle,
                emptyBody: detail.billingDataUnavailable
                    ? l10n.dischargeBillingUnavailableBody
                    : l10n.dischargeNoInvoicesBody,
                records: detail.invoices,
                icon: Icons.receipt_long_outlined,
              ),
              SizedBox(height: theme.spacing.lg),
            ],
          ),
        ),
        _TimelineSection(detail: detail),
      ],
    );
  }
}

class _PendingOrdersSection extends StatelessWidget {
  const _PendingOrdersSection({required this.detail});

  final DischargeAdmissionDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppWorkspaceDetailPanel(
      title: l10n.dischargePendingOrdersTitle,
      description: l10n.dischargePendingOrdersBody,
      child: Column(
        children: <Widget>[
          for (final IpdPendingOrder order in detail.ipd.pendingDischargeOrders)
            ListTile(
              leading: const Icon(Icons.pending_actions_outlined),
              title: Text(order.label ?? order.kind ?? order.id),
              subtitle: Text(order.status ?? ''),
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

class _CrossModuleLinksSection extends ConsumerWidget {
  const _CrossModuleLinksSection({required this.detail});

  final DischargeAdmissionDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final String admissionId = detail.summary.displayId ?? detail.summary.id;
    final List<AppActionItem> actions = <AppActionItem>[
      if (DischargeAllPatientsAtomPermissions.openIpd.isAllowed(policy))
        AppActionItem(
          label: l10n.dischargeOpenIpdAction,
          leadingIcon: Icons.local_hotel_outlined,
          variant: AppActionVariant.tertiary,
          onPressed: () => _openLinkedWorkspace(
            context,
            admissionId.isEmpty
                ? AppRoutes.ipd.path
                : AppRoutes.ipd.location(
                    queryParameters: <String, String>{'id': admissionId},
                  ),
          ),
        ),
      if (DischargeAllPatientsAtomPermissions.openNursing.isAllowed(policy))
        AppActionItem(
          label: l10n.dischargeOpenNursingAction,
          leadingIcon: Icons.health_and_safety_outlined,
          variant: AppActionVariant.tertiary,
          onPressed: () =>
              _openLinkedWorkspace(context, AppRoutes.nursing.path),
        ),
      if (DischargeAllPatientsAtomPermissions.openPharmacy.isAllowed(policy))
        AppActionItem(
          label: l10n.dischargeOpenPharmacyAction,
          leadingIcon: Icons.medication_outlined,
          variant: AppActionVariant.tertiary,
          onPressed: () =>
              _openLinkedWorkspace(context, AppRoutes.pharmacy.path),
        ),
      if (DischargeAllPatientsAtomPermissions.openBilling.isAllowed(policy))
        AppActionItem(
          label: l10n.dischargeOpenBillingAction,
          leadingIcon: Icons.receipt_long_outlined,
          variant: AppActionVariant.tertiary,
          onPressed: () =>
              _openLinkedWorkspace(context, AppRoutes.billing.path),
        ),
      if (DischargeAllPatientsAtomPermissions.openHousekeeping.isAllowed(policy))
        AppActionItem(
          label: l10n.dischargeOpenHousekeepingAction,
          leadingIcon: Icons.cleaning_services_outlined,
          variant: AppActionVariant.tertiary,
          onPressed: () =>
              _openLinkedWorkspace(context, AppRoutes.housekeeping.path),
        ),
    ];
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppQuickActions(
      title: l10n.dischargeCrossModuleLinksTitle,
      description: l10n.dischargeCrossModuleLinksBody,
      presentation: AppQuickActionsPresentation.detailPanel,
      actions: actions,
    );
  }
}

void _openLinkedWorkspace(BuildContext context, String location) {
  context.go(location);
}

class _ClearanceChecklist extends ConsumerWidget {
  const _ClearanceChecklist({required this.detail});

  final DischargeAdmissionDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final List<DischargeClearanceItem> items = dischargeVisibleClearanceItems(
      policy,
      detail.clearanceItems,
    );
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final int firstPendingIndex = items.indexWhere(
      (DischargeClearanceItem item) =>
          item.state == DischargeClearanceState.pending,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.dischargeChecklistTitle,
      description: l10n.dischargeChecklistBody,
      child: AppWorkflowStepper(
        semanticLabel: l10n.dischargeClearanceProgressTitle,
        showDescriptions: false,
        steps: <AppWorkflowStepItem>[
          for (var index = 0; index < items.length; index += 1)
            AppWorkflowStepItem(
              id: items[index].code.name,
              label: dischargeClearanceLabel(context, items[index].code),
              icon: dischargeClearanceIcon(items[index].code),
              helpText: items[index].reference,
              state: switch (items[index].state) {
                DischargeClearanceState.complete =>
                  AppWorkflowStepState.completed,
                DischargeClearanceState.unavailable =>
                  AppWorkflowStepState.unavailable,
                DischargeClearanceState.pending =>
                  index == firstPendingIndex
                      ? AppWorkflowStepState.current
                      : AppWorkflowStepState.upcoming,
              },
            ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.detail});

  final DischargeAdmissionDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? summary = detail.summaryText;

    return AppWorkspaceDetailPanel(
      title: l10n.dischargeSummarySectionTitle,
      description: l10n.dischargeSummarySectionBody,
      child: summary == null
          ? AppWorkspaceStatePanel.empty(
              title: l10n.dischargeEmptySummaryTitle,
              body: l10n.dischargeEmptySummaryBody,
              icon: Icons.edit_note_outlined,
              minHeight: 180,
            )
          : AppReportPreviewPanel(
              title: l10n.dischargeGeneratedDocumentsTitle,
              selectable: true,
              child: Text(summary),
            ),
    );
  }
}

class _RelatedRecordsSection extends StatelessWidget {
  const _RelatedRecordsSection({
    required this.title,
    required this.emptyBody,
    required this.records,
    required this.icon,
  });

  final String title;
  final String emptyBody;
  final List<DischargeRelatedRecord> records;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppWorkspaceDetailPanel(
      title: title,
      child: records.isEmpty
          ? AppWorkspaceStatePanel.empty(
              title: l10n.dischargeNoRecordsTitle,
              body: emptyBody,
              icon: icon,
              minHeight: 160,
            )
          : Column(
              children: <Widget>[
                for (final DischargeRelatedRecord record in records)
                  ListTile(
                    leading: Icon(icon),
                    title: Text(
                      (record.title ?? '').trim().isNotEmpty
                          ? record.title!.trim()
                          : record.kind,
                    ),
                    subtitle: Text(_relatedSubtitle(context, record)),
                    trailing: AppWorkspaceStatusBadge(
                      status: _recordStatus(context, record),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                SizedBox(height: theme.spacing.xs),
              ],
            ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.detail});

  final DischargeAdmissionDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppTimeline(
      title: l10n.dischargeTimelineSectionTitle,
      emptyTitle: l10n.dischargeNoTimelineTitle,
      emptyBody: l10n.dischargeNoTimelineBody,
      asActivityList: true,
      maxItems: 6,
      items: <AppTimelineItem>[
        for (final IpdTimelineItem item in detail.ipd.timeline)
          AppTimelineItem(
            title: item.label ?? _apiLabel(item.type),
            occurredAt: item.occurredAt,
            icon: Icons.history_outlined,
          ),
      ],
    );
  }
}

class _QueuePatientCell extends StatelessWidget {
  const _QueuePatientCell({required this.item});

  final IpdAdmissionSummary item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppListItemText(
      title: item.displayTitle,
      subtitle: item.displayId ?? l10n.profileUnknownValue,
    );
  }
}


class _BillingDialog extends StatefulWidget {
  const _BillingDialog({required this.onSubmit});

  final Future<AppFailure?> Function(String amount, String currency) onSubmit;

  @override
  State<_BillingDialog> createState() => _BillingDialogState();
}

class _BillingDialogState extends State<_BillingDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController(
    text: 'UGX',
  );
  AppFailure? _failure;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        Text(l10n.dischargeBillingDialogBody),
        AppTextField(
          controller: _amountController,
          labelText: l10n.dischargeBillingAmountLabel,
          keyboardType: TextInputType.number,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.dischargeBillingAmountRequiredMessage,
          ),
        ),
        AppTextField(
          controller: _currencyController,
          labelText: l10n.dischargeBillingCurrencyLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.dischargeBillingCurrencyRequiredMessage,
          ),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.dischargeRequestBillingSubmitAction,
          submitIcon: Icons.receipt_long_outlined,
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
      _amountController.text.trim(),
      _currencyController.text.trim(),
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

class _PharmacyDialog extends StatefulWidget {
  const _PharmacyDialog({required this.drugs, required this.onSubmit});

  final List<DischargeDrugOption> drugs;
  final Future<AppFailure?> Function({
    required String drugId,
    required String customPrescription,
    required String instructions,
    required int? quantity,
    required String? route,
    required String? frequency,
  })
  onSubmit;

  @override
  State<_PharmacyDialog> createState() => _PharmacyDialogState();
}

class _PharmacyDialogState extends State<_PharmacyDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _prescriptionController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String? _drugId;
  String? _route = 'ORAL';
  String? _frequency = 'BID';
  AppFailure? _failure;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _prescriptionController.dispose();
    _instructionsController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        Text(l10n.dischargePharmacyDialogBody),
        AppSelectField<String>(
          labelText: l10n.dischargeDrugFieldLabel,
          value: _drugId,
          isRequired: true,
          options: <AppSelectOption<String>>[
            for (final DischargeDrugOption drug in widget.drugs)
              AppSelectOption<String>(
                value: drug.id,
                label: drug.displayTitle,
                labelWidget: Text(
                  drug.displaySubtitle == null
                      ? drug.displayTitle
                      : '${drug.displayTitle} - ${drug.displaySubtitle}',
                ),
              ),
          ],
          validator: AppValidators.requiredValue<String>(
            l10n.dischargeDrugRequiredMessage,
          ),
          onChanged: (String? value) {
            setState(() {
              _drugId = value;
            });
          },
        ),
        AppTextField(
          controller: _prescriptionController,
          labelText: l10n.dischargePrescriptionFieldLabel,
          helperText: l10n.dischargePrescriptionHelperText,
          isRequired: true,
          maxLines: 3,
          validator: AppValidators.requiredText(
            l10n.dischargePrescriptionRequiredMessage,
          ),
        ),
        AppTextField(
          controller: _quantityController,
          labelText: l10n.dischargeQuantityFieldLabel,
          keyboardType: TextInputType.number,
        ),
        AppSelectField<String>(
          labelText: l10n.dischargeMedicationRouteLabel,
          value: _route,
          options: _simpleOptions(const <String>[
            'ORAL',
            'IV',
            'IM',
            'TOPICAL',
            'INHALATION',
            'OTHER',
          ]),
          onChanged: (String? value) {
            setState(() {
              _route = value;
            });
          },
        ),
        AppSelectField<String>(
          labelText: l10n.dischargeMedicationFrequencyLabel,
          value: _frequency,
          options: _simpleOptions(const <String>[
            'ONCE',
            'OD',
            'BID',
            'TID',
            'QID',
            'PRN',
            'STAT',
            'CUSTOM',
          ]),
          onChanged: (String? value) {
            setState(() {
              _frequency = value;
            });
          },
        ),
        AppTextField(
          controller: _instructionsController,
          labelText: l10n.dischargeMedicineInstructionsLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.dischargeRequestPharmacySubmitAction,
          submitIcon: Icons.medication_outlined,
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
      drugId: _drugId!,
      customPrescription: _prescriptionController.text.trim(),
      instructions: _instructionsController.text.trim(),
      quantity: int.tryParse(_quantityController.text.trim()),
      route: _route,
      frequency: _frequency,
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

Future<void> _openDischargePlanningDialog(
  BuildContext context,
  WidgetRef ref,
  DischargeAdmissionDetail detail, {
  Widget? title,
}) async {
  final bool? saved = await showDischargePlanningDialog(
    context: context,
    ref: ref,
    admissionId: detail.summary.apiId,
    title: title,
    initialDetail: detail,
  );
  if (saved == true && context.mounted) {
    await ref.read(dischargeWorkspaceControllerProvider.notifier).refresh();
    if (context.mounted) {
      _showSaved(context);
    }
  }
}

Future<void> _openBillingDialog(
  BuildContext context,
  DischargeWorkspaceController controller,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.dischargeBillingDialogTitle),
    content: _BillingDialog(
      onSubmit: (String amount, String currency) {
        return controller.requestFinalBilling(
          amount: amount,
          currency: currency,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

Future<void> _openPharmacyDialog(
  BuildContext context,
  DischargeWorkspaceController controller,
  DischargeWorkspaceState state,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.dischargePharmacyDialogTitle),
    content: _PharmacyDialog(
      drugs: state.referenceData.drugs,
      onSubmit: controller.requestPharmacyMedicines,
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

const String _dischargeStatusFilterKey = 'status';

List<AppListTableColumn<IpdAdmissionSummary>> _dischargeTableColumns(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<IpdAdmissionSummary>>[
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'patient',
      label: l10n.dischargePatientColumnLabel,
      alwaysVisible: true,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareText(left.displayTitle, right.displayTitle),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return _QueuePatientCell(item: item);
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'location',
      label: l10n.dischargeLocationColumnLabel,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareText(
            _locationLabel(context, left),
            _locationLabel(context, right),
          ),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return Text(_locationLabel(context, item));
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'target_date',
      label: l10n.dischargeTargetColumnLabel,
      // API maps target discharge date onto dischargedAt on the summary.
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareDateTime(left.dischargedAt, right.dischargedAt),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return Text(_dateLabel(context, item.dischargedAt));
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'clearance_phase',
      label: l10n.ipdDischargeClearancePhaseLabel,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareText(left.clearancePhase, right.clearancePhase),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return _dischargeClearancePhaseCell(context, item);
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'blocking_item',
      label: l10n.dischargeStatusSummaryPending,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareText(
            left.clearancePhase ?? left.nextStep,
            right.clearancePhase ?? right.nextStep,
          ),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return _dischargeBlockingItemCell(context, item);
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'discharged_at',
      label: l10n.ipdDischargedAtLabel,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareDateTime(left.dischargedAt, right.dischargedAt),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return Text(_dateLabel(context, item.dischargedAt));
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'admitted_at',
      label: l10n.ipdAdmittedAtColumnLabel,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareDateTime(left.admittedAt, right.admittedAt),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return Text(_dateLabel(context, item.admittedAt));
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'status',
      label: l10n.dischargeStatusColumnLabel,
      alwaysVisible: true,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareText(
            left.dischargeStatus ?? left.stage,
            right.dischargeStatus ?? right.stage,
          ),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return AppWorkspaceStatusBadge(status: _statusFor(context, item));
      },
    ),
    AppListTableColumn<IpdAdmissionSummary>(
      id: 'next_action',
      label: l10n.dischargeNextActionColumnLabel,
      alwaysVisible: true,
      sortComparator: (IpdAdmissionSummary left, IpdAdmissionSummary right) =>
          appListTableCompareText(
            _nextActionLabel(context, left),
            _nextActionLabel(context, right),
          ),
      cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
        return _dischargeNextActionWidget(context, item);
      },
    ),
  ];
}

List<AppListTableColumn<IpdAdmissionSummary>> _dischargeDefaultColumns(
  BuildContext context, {
  required DischargeDeskSection section,
}) {
  final Map<String, AppListTableColumn<IpdAdmissionSummary>> columnsById =
      <String, AppListTableColumn<IpdAdmissionSummary>>{
        for (final AppListTableColumn<IpdAdmissionSummary> column
            in _dischargeTableColumns(context))
          if (column.id != null) column.id!: column,
      };
  final List<String> columnIds = switch (section) {
    DischargeDeskSection.all => <String>[
      'patient',
      'location',
      'target_date',
      'status',
      'next_action',
    ],
    DischargeDeskSection.planned => <String>[
      'patient',
      'location',
      'clearance_phase',
      'status',
      'next_action',
    ],
    DischargeDeskSection.pendingClearance => <String>[
      'patient',
      'location',
      'blocking_item',
      'status',
      'next_action',
    ],
    DischargeDeskSection.completed => <String>[
      'patient',
      'location',
      'discharged_at',
      'status',
      'next_action',
    ],
    DischargeDeskSection.followUps => <String>[
      'patient',
      'location',
      'target_date',
      'status',
      'next_action',
    ],
  };
  return columnIds.map((String id) => columnsById[id]!).toList(growable: false);
}

Widget _dischargeClearancePhaseCell(
  BuildContext context,
  IpdAdmissionSummary item,
) {
  final String phase = item.clearancePhase ?? '';
  if (phase.isEmpty) {
    return const SizedBox.shrink();
  }
  return AppWorkspaceStatusBadge(
    status: AppWorkspaceStatus(
      label: _apiLabel(phase),
      tone: AppWorkspaceStatusTone.info,
    ),
  );
}

Widget _dischargeBlockingItemCell(
  BuildContext context,
  IpdAdmissionSummary item,
) {
  final AppLocalizations l10n = context.l10n;
  final String blocker =
      item.clearancePhase ?? item.nextStep ?? item.stage ?? '';
  if (blocker.isEmpty) {
    return Text(l10n.dischargeStatusSummaryPending);
  }
  return AppWorkspaceStatusBadge(
    status: AppWorkspaceStatus(
      label: _apiLabel(blocker),
      tone: AppWorkspaceStatusTone.warning,
    ),
  );
}

Widget _dischargeNextActionWidget(
  BuildContext context,
  IpdAdmissionSummary item,
) {
  return _DischargeNextActionButton(item: item);
}

class _DischargeNextActionButton extends ConsumerWidget {
  const _DischargeNextActionButton({required this.item});

  final IpdAdmissionSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    if (isCompletedDischarge(item)) {
      return _DischargeCompactAction(
        label: l10n.dischargePrintSummaryAction,
        icon: Icons.print_outlined,
        onPressed: () =>
            unawaited(_printOrOpenDetailFromQueue(context, ref, item)),
      );
    }

    return AppAccessActionGate(
      requirement: DischargeAllPatientsAtomPermissions.nextActionPlan,
      builder: (BuildContext context, bool isAllowed) {
        final String label = isPlannedDischarge(item)
            ? l10n.dischargeManageClearanceAction
            : l10n.dischargeStartPlanAction;
        return _DischargeCompactAction(
          label: label,
          icon: isPlannedDischarge(item)
              ? Icons.fact_check_outlined
              : Icons.edit_note_outlined,
          onPressed: () =>
              unawaited(_openPlanningFromQueue(context, ref, item)),
        );
      },
    );
  }
}

class _DischargeCompactAction extends StatelessWidget {
  const _DischargeCompactAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    return Semantics(
      button: true,
      enabled: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xs,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 14, color: primaryColor),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openPlanningFromQueue(
  BuildContext context,
  WidgetRef ref,
  IpdAdmissionSummary admission,
) async {
  final DischargeWorkspaceController controller = ref.read(
    dischargeWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectAdmission(admission);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }
  final DischargeAdmissionDetail? detail = _readDischargeState(
    ref,
  )?.selectedDetail;
  if (detail == null) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  final String title = detail.hasSummary
      ? clinicalDispositionActionLabel(
          l10n,
          sourceQueue: 'IPD',
          status: detail.summary.admissionStatus,
          stage: detail.summary.stage,
          location: detail.summary.location,
          hasAdmission: true,
        )
      : l10n.dischargeStartPlanAction;
  await _openDischargePlanningDialog(
    context,
    ref,
    detail,
    title: Text(title),
  );
}

Future<void> _printOrOpenDetailFromQueue(
  BuildContext context,
  WidgetRef ref,
  IpdAdmissionSummary admission,
) async {
  final DischargeWorkspaceController controller = ref.read(
    dischargeWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectAdmission(admission);
  if (context.mounted) {
    _showFailureIfNeeded(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }
  final DischargeWorkspaceState? state = _readDischargeState(ref);
  final DischargeAdmissionDetail? detail = state?.selectedDetail;
  if (detail == null || state == null) {
    return;
  }
  if (detail.hasSummary) {
    await _printDischargeSummary(context, ref, detail);
    return;
  }
  if (context.mounted) {
    await _openDischargeDetailDialog(context, ref, state, admission);
  }
}

bool _dischargeMatchesSearch(
  BuildContext context,
  IpdAdmissionSummary item,
  String query,
) {
  if (item.matchesSearch(query)) {
    return true;
  }
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  return <String>[
    _locationLabel(context, item),
    _statusFor(context, item).label,
    _nextActionLabel(context, item),
    _dateLabel(context, item.dischargedAt),
    _dateLabel(context, item.admittedAt),
    _blockingItemLabel(context, item),
    if (item.clearancePhase != null) _apiLabel(item.clearancePhase!),
    if (item.nextStep != null) _apiLabel(item.nextStep!),
    if (item.stage != null) _apiLabel(item.stage!),
  ].any((String value) => value.toLowerCase().contains(needle));
}

String _blockingItemLabel(BuildContext context, IpdAdmissionSummary item) {
  final AppLocalizations l10n = context.l10n;
  final String blocker =
      item.clearancePhase ?? item.nextStep ?? item.stage ?? '';
  if (blocker.isEmpty) {
    return l10n.dischargeStatusSummaryPending;
  }
  return _apiLabel(blocker);
}

AppSearchBarFilterValue _dischargeFilterValue(DischargeWorklistQuery query) {
  if (query.status == DischargeStatusFilter.all) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    options: <String, String>{_dischargeStatusFilterKey: query.status.name},
  );
}

DischargeStatusFilter _dischargeStatusFromFilter(String? value) {
  for (final DischargeStatusFilter status in DischargeStatusFilter.values) {
    if (status.name == value) {
      return status;
    }
  }
  return DischargeStatusFilter.all;
}

List<AppSearchBarFilterChoice> _dischargeStatusFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: DischargeStatusFilter.planned.name,
      label: l10n.dischargeStatusPlanned,
      icon: Icons.filter_list,
    ),
    AppSearchBarFilterChoice(
      value: DischargeStatusFilter.summaryPending.name,
      label: l10n.dischargeStatusSummaryPending,
      icon: Icons.filter_list,
    ),
    AppSearchBarFilterChoice(
      value: DischargeStatusFilter.pharmacyPending.name,
      label: l10n.dischargeStatusPharmacyPending,
      icon: Icons.filter_list,
    ),
    AppSearchBarFilterChoice(
      value: DischargeStatusFilter.nursingPending.name,
      label: l10n.dischargeStatusNursingPending,
      icon: Icons.filter_list,
    ),
    AppSearchBarFilterChoice(
      value: DischargeStatusFilter.billingPending.name,
      label: l10n.dischargeStatusBillingPending,
      icon: Icons.filter_list,
    ),
    AppSearchBarFilterChoice(
      value: DischargeStatusFilter.insurancePending.name,
      label: l10n.dischargeStatusInsurancePending,
      icon: Icons.filter_list,
    ),
    AppSearchBarFilterChoice(
      value: DischargeStatusFilter.documentsReady.name,
      label: l10n.dischargeStatusDocumentsReady,
      icon: Icons.filter_list,
    ),
    AppSearchBarFilterChoice(
      value: DischargeStatusFilter.completed.name,
      label: l10n.dischargeStatusCompleted,
      icon: Icons.filter_list,
    ),
  ];
}

List<AppSelectOption<String>> _simpleOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

AppWorkspaceStatus _statusFor(BuildContext context, IpdAdmissionSummary item) {
  if (isCompletedDischarge(item)) {
    return AppWorkspaceStatus(
      label: context.l10n.dischargeStatusCompleted,
      tone: AppWorkspaceStatusTone.success,
    );
  }
  if (isPlannedDischarge(item)) {
    return AppWorkspaceStatus(
      label: context.l10n.dischargeStatusPlanned,
      tone: AppWorkspaceStatusTone.info,
    );
  }
  return AppWorkspaceStatus(
    label: context.l10n.dischargeStatusSummaryPending,
    tone: AppWorkspaceStatusTone.warning,
  );
}

AppWorkspaceStatus _recordStatus(
  BuildContext context,
  DischargeRelatedRecord record,
) {
  final String status = record.billingStatus ?? record.status ?? '';
  return AppWorkspaceStatus(
    label: status.isEmpty
        ? context.l10n.profileUnknownValue
        : _apiLabel(status),
    tone: switch (status.toUpperCase()) {
      'PAID' || 'DISPENSED' || 'CANCELLED' => AppWorkspaceStatusTone.success,
      'PARTIAL' ||
      'PARTIALLY_DISPENSED' ||
      'ISSUED' ||
      'SENT' => AppWorkspaceStatusTone.warning,
      'OVERDUE' => AppWorkspaceStatusTone.error,
      _ => AppWorkspaceStatusTone.neutral,
    },
  );
}

String _locationLabel(BuildContext context, IpdAdmissionSummary item) {
  return item.location ?? context.l10n.profileUnknownValue;
}

String _nextActionLabel(BuildContext context, IpdAdmissionSummary item) {
  if (isCompletedDischarge(item)) {
    return context.l10n.dischargeNextActionCompleted;
  }
  if (isPlannedDischarge(item)) {
    return context.l10n.dischargeNextActionClearance;
  }
  return context.l10n.dischargeNextActionStartPlan;
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

String? _patientAgeLabel(
  BuildContext context,
  DischargeAdmissionDetail detail,
) {
  final DateTime? birthDate = detail.ipd.patientDateOfBirth;
  if (birthDate == null) {
    return null;
  }
  return _ageInYears(birthDate).toString();
}

String _patientGenderLabel(
  BuildContext context,
  DischargeAdmissionDetail detail,
) {
  if (detail.ipd.patientGender == null) {
    return context.l10n.profileUnknownValue;
  }
  return _apiLabel(detail.ipd.patientGender!);
}

int _ageInYears(DateTime birthDate) {
  final DateTime today = DateTime.now();
  int age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age -= 1;
  }
  return age < 0 ? 0 : age;
}

String _relatedSubtitle(BuildContext context, DischargeRelatedRecord record) {
  final String amount = record.amount == null
      ? ''
      : AppFormatters.currency(
          record.amount!,
          Localizations.localeOf(context),
          currencyCode: record.currency,
        );
  return <String>[
    if (amount.isNotEmpty) amount,
    if (record.createdAt != null) _dateLabel(context, record.createdAt),
    if (record.subtitle != null) record.subtitle!,
  ].where((String value) => value.trim().isNotEmpty).join(' | ');
}

String _apiLabel(String value) => AppDisplay.apiLabel(value);

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  showAppFailureSnackBar(context, failure);
}

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.dischargeSavedMessage)));
}

Future<void> _printDischargeSummary(
  BuildContext context,
  WidgetRef ref,
  DischargeAdmissionDetail detail,
) async {
  final AppLocalizations l10n = context.l10n;
  await printFormTemplateDocument(
    ref: ref,
    context: context,
    title: l10n.dischargeReportTitle,
    patientContext: buildPrintFormPatientContext(
      l10n,
      patientName: detail.ipd.patientDisplayName,
      patientId: detail.patientId,
      encounterId: detail.encounterId,
      patientNameLabel: l10n.dischargeReportPatientLabel,
      patientIdLabel: l10n.dischargeReportPatientNoLabel,
    ),
    contextReference: PrintFormContextReference(
      label: l10n.dischargeReportAdmissionLabel,
      value: detail.summary.displayId ?? l10n.profileUnknownValue,
    ),
    bodyHtml: _dischargeSummaryHtml(context, detail),
    footerNote: l10n.dischargeReportFooter,
    includeSignatures: true,
  );
}

String _dischargeSummaryHtml(
  BuildContext context,
  DischargeAdmissionDetail detail,
) {
  final AppLocalizations l10n = context.l10n;
  final String summary = detail.summaryText ?? '';
  final String summaryHtml = PrintFormTemplate.section(
    title: l10n.dischargeSummarySectionTitle,
    bodyHtml: '<div class="print-template-note">${_htmlEscape(summary)}</div>',
  );
  final String medicinesHtml = PrintFormTemplate.section(
    title: l10n.dischargeMedicinesSectionTitle,
    bodyHtml:
        '<div class="print-template-note">${_htmlEscape(_printRecords(context, detail.pharmacyOrders, l10n.dischargeNoMedicinesBody))}</div>',
  );
  final String billingHtml = PrintFormTemplate.section(
    title: l10n.dischargeBillingSectionTitle,
    bodyHtml:
        '<div class="print-template-note">${_htmlEscape(_printRecords(context, detail.invoices, l10n.dischargeNoInvoicesBody))}</div>',
  );

  return '''
$summaryHtml
$medicinesHtml
$billingHtml
  <div class="print-template-signatures">
    <div class="print-template-signature">${_htmlEscape(l10n.dischargeDoctorSignatureLabel)}</div>
    <div class="print-template-signature">${_htmlEscape(l10n.dischargeNurseSignatureLabel)}</div>
  </div>
''';
}

String _printRecords(
  BuildContext context,
  List<DischargeRelatedRecord> records,
  String empty,
) {
  if (records.isEmpty) {
    return empty;
  }

  return records
      .map((DischargeRelatedRecord record) {
        final String label = (record.title ?? '').trim().isNotEmpty
            ? record.title!.trim()
            : record.kind;
        return '$label - ${_apiLabel(record.billingStatus ?? record.status ?? '')}';
      })
      .join('\n');
}

String _htmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
