import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_action_dialogs.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_format.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_next_action_button.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class IcuWorkspaceWriteRequirement {
  const IcuWorkspaceWriteRequirement._();

  static const AccessRequirement writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.emergencyWrite,
    ],
    activeModules: <String>['icu-critical-care'],
  );
}

class IcuStayDetailPanel extends ConsumerWidget {
  const IcuStayDetailPanel({
    required this.state,
    required this.writeRequirement,
    this.omitNextActionKind,
    super.key,
  });

  final IcuWorkspaceState state;
  final AccessRequirement writeRequirement;
  final IcuNextActionKind? omitNextActionKind;

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
        AppPatientDetails(
          patientName: summary.displayTitle,
          patientNumber: summary.displayId ?? '',
          ageLabel: dateLabel(context, detail.patientDateOfBirth),
          genderLabel: detail.patientGender == null
              ? null
              : apiLabel(detail.patientGender!),
          showAvatar: false,
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
          expandedFields: <AppWorkspacePatientContextField>[
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
        IcuActionPanel(
          detail: detail,
          state: state,
          writeRequirement: writeRequirement,
          omitNextActionKind: omitNextActionKind,
        ),
        SizedBox(height: theme.spacing.md),
        IcuAlertPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        IcuObservationPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        IcuVitalTrendPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        IcuCarePanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        IcuTransferPanel(detail: detail),
      ],
    );
  }
}

class IcuActionPanel extends ConsumerWidget {
  const IcuActionPanel({
    required this.detail,
    required this.state,
    required this.writeRequirement,
    this.omitNextActionKind,
    super.key,
  });

  final IcuPatientDetail detail;
  final IcuWorkspaceState state;
  final AccessRequirement writeRequirement;
  final IcuNextActionKind? omitNextActionKind;

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
    final IcuNextActionKind? omit = omitNextActionKind;
    const AccessRequirement navigationRequirement = AccessRequirement();

    return AppQuickActions(
      title: l10n.icuActionsTitle,
      presentation: AppQuickActionsPresentation.detailPanel,
      permissionActions: <AppPermissionActionItem>[
        if (canStartStay && omit != IcuNextActionKind.startStay)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionStartStay,
            icon: Icons.play_circle_outline,
            onPressed: () => confirmIcuAction(
              context: context,
              title: l10n.icuStartStayTitle,
              body: l10n.icuStartStayBody,
              actionLabel: l10n.icuStartStayActionLabel,
              onConfirmed: () => controller.startIcuStay(),
            ),
          ),
        if (hasActiveStay && omit != IcuNextActionKind.recordObservation)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionRecordObservation,
            icon: Icons.note_add_outlined,
            onPressed: () => openIcuObservationDialog(context),
          ),
        if (hasEncounter)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionRecordVitals,
            icon: Icons.monitor_heart_outlined,
            onPressed: () => openIcuVitalsDialog(context),
          ),
        if (hasActiveStay)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionRaiseAlert,
            icon: Icons.notification_important_outlined,
            onPressed: () => openIcuAlertDialog(context),
          ),
        if (hasAlert && omit != IcuNextActionKind.acknowledgeAlert)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionAcknowledgeAlert,
            icon: Icons.done_all_outlined,
            onPressed: () => confirmIcuAction(
              context: context,
              title: l10n.icuAcknowledgeTitle,
              body: l10n.icuAcknowledgeBody,
              actionLabel: l10n.icuActionAcknowledgeAlert,
              onConfirmed: controller.acknowledgeLatestAlert,
            ),
          ),
        AppPermissionActionItem(
          requirement: writeRequirement,
          label: l10n.icuActionRound,
          icon: Icons.rate_review_outlined,
          onPressed: () => openIcuRoundDialog(context),
        ),
        if (hasEncounter)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionOrderLab,
            icon: Icons.science_outlined,
            onPressed: () => openIcuLabOrderDialog(context),
          ),
        if (hasEncounter)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionOrderImaging,
            icon: Icons.radio_outlined,
            onPressed: () => openIcuRadiologyOrderDialog(context),
          ),
        if (hasEncounter)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionPrescribe,
            icon: Icons.medication_outlined,
            onPressed: () => openIcuPrescriptionDialog(context),
          ),
        if (!detail.summary.hasActiveBed &&
            omit != IcuNextActionKind.assignBed)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionAssignBed,
            icon: Icons.bed_outlined,
            onPressed: () => openIcuAssignBedDialog(context),
          ),
        if (!hasOpenTransfer && omit != IcuNextActionKind.requestTransfer)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionRequestTransfer,
            icon: AppActionIcons.transfer,
            onPressed: () =>
                openIcuTransferDialog(context, state.referenceData),
          ),
        if (hasOpenTransfer && omit != IcuNextActionKind.manageTransfer)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionManageTransfer,
            icon: Icons.published_with_changes_outlined,
            onPressed: () => openIcuManageTransferDialog(context),
          ),
        if (omit != IcuNextActionKind.markReadiness)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionMarkReadiness,
            icon: Icons.fact_check_outlined,
            onPressed: () => openIcuReadinessDialog(context),
          ),
        if (detail.summary.isDischargePlanned &&
            detail.summary.displayId != null &&
            omit != IcuNextActionKind.openDischargeClearance)
          AppPermissionActionItem(
            requirement: navigationRequirement,
            label: l10n.icuActionOpenDischargeClearance,
            icon: Icons.assignment_turned_in_outlined,
            onPressed: () =>
                openIpdDischargeClearance(context, detail.summary),
          ),
        AppPermissionActionItem(
          requirement: navigationRequirement,
          label: l10n.icuActionOpenBilling,
          icon: Icons.receipt_long_outlined,
          onPressed: () => context.go(AppRoutes.billing.path),
        ),
        if (detail.summary.displayId != null &&
            omit != IcuNextActionKind.openIpd)
          AppPermissionActionItem(
            requirement: navigationRequirement,
            label: l10n.icuActionOpenIpd,
            icon: Icons.open_in_new_outlined,
            onPressed: () => openIpdWorkspace(context, detail.summary),
          ),
        if (hasActiveStay)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.icuActionEndStay,
            icon: Icons.output_outlined,
            onPressed: () => confirmIcuAction(
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
              bodyHtml: icuSummaryHtml(context, detail),
              includeSignatures: true,
            );
          },
        ),
      ],
    );
  }
}

class IcuAlertPanel extends StatelessWidget {
  const IcuAlertPanel({required this.detail, super.key});

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

class IcuObservationPanel extends StatelessWidget {
  const IcuObservationPanel({required this.detail, super.key});

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

class IcuVitalTrendPanel extends StatelessWidget {
  const IcuVitalTrendPanel({required this.detail, super.key});

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

class IcuCarePanel extends StatelessWidget {
  const IcuCarePanel({required this.detail, super.key});

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

class IcuTransferPanel extends StatelessWidget {
  const IcuTransferPanel({required this.detail, super.key});

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
                    fontWeight: FontWeight.w600,
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
