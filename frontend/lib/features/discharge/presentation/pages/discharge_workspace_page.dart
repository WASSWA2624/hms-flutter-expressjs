import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/presentation/controllers/discharge_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class DischargeWorkspacePage extends ConsumerWidget {
  const DischargeWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Result<DischargeWorkspaceState>> value = ref.watch(
      dischargeWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return value.when(
      data: (Result<DischargeWorkspaceState> result) {
        return result.when(
          success: (DischargeWorkspaceState state) {
            return _DischargeWorkspaceContent(state: state);
          },
          failure: (AppFailure failure) {
            return ResponsivePage(
              maxWidth: PageMaxWidth.form,
              centerVertically: true,
              child: AppFailureStateView(
                failure: failure,
                title: l10n.dischargeLoadErrorTitle,
                body: l10n.dischargeLoadErrorBody,
                onRetry: () {
                  ref.invalidate(dischargeWorkspaceControllerProvider);
                },
              ),
            );
          },
        );
      },
      error: (Object error, StackTrace stackTrace) {
        return ResponsivePage(
          maxWidth: PageMaxWidth.form,
          centerVertically: true,
          child: AppStateView(
            variant: AppStateViewVariant.error,
            title: l10n.dischargeLoadErrorTitle,
            body: l10n.errorUnexpectedMessage,
          ),
        );
      },
      loading: () {
        return ResponsivePage(
          maxWidth: PageMaxWidth.form,
          centerVertically: true,
          child: AppWorkspaceStatePanel.loading(
            title: l10n.dischargeLoadingTitle,
            body: l10n.dischargeLoadingBody,
          ),
        );
      },
    );
  }
}

class _DischargeWorkspaceContent extends ConsumerStatefulWidget {
  const _DischargeWorkspaceContent({required this.state});

  final DischargeWorkspaceState state;

  @override
  ConsumerState<_DischargeWorkspaceContent> createState() {
    return _DischargeWorkspaceContentState();
  }
}

class _DischargeWorkspaceContentState
    extends ConsumerState<_DischargeWorkspaceContent> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
  }

  @override
  void didUpdateWidget(covariant _DischargeWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.value = TextEditingValue(text: search);
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
    final DischargeWorkspaceState state = widget.state;
    final DischargeWorkspaceController controller = ref.read(
      dischargeWorkspaceControllerProvider.notifier,
    );

    return AppWorkspace(
      title: l10n.dischargeWorkspaceTitle,
      status: AppWorkspaceStatus(
        label: l10n.dischargeOperationalStatusLabel,
        tone: state.lastFailure == null
            ? AppWorkspaceStatusTone.success
            : AppWorkspaceStatusTone.warning,
      ),
      primaryAction: AppButton.primary(
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
      compactSummaryCards: true,
      summaryCards: <Widget>[
        AppWorkspaceSummaryCard(
          compact: true,
          label: l10n.dischargePlannedSummaryLabel,
          value: state.plannedCount.toString(),
          icon: Icons.event_available_outlined,
          tone: AppWorkspaceStatusTone.info,
        ),
        AppWorkspaceSummaryCard(
          compact: true,
          label: l10n.dischargeSummaryPendingSummaryLabel,
          value: state.summaryPendingCount.toString(),
          icon: Icons.edit_note_outlined,
          tone: AppWorkspaceStatusTone.warning,
        ),
        AppWorkspaceSummaryCard(
          compact: true,
          label: l10n.dischargeDocumentsReadySummaryLabel,
          value: state.documentsReadyCount.toString(),
          icon: Icons.description_outlined,
          tone: AppWorkspaceStatusTone.success,
        ),
        AppWorkspaceSummaryCard(
          compact: true,
          label: l10n.dischargeCompletedSummaryLabel,
          value: state.completedCount.toString(),
          icon: Icons.check_circle_outline,
          tone: AppWorkspaceStatusTone.neutral,
        ),
      ],
      filters: AppWorkspaceFilterBar(
        expandSearch: true,
        search: AppSearchBar(
          controller: _searchController,
          semanticLabel: l10n.dischargeQueueSearchLabel,
          hintText: l10n.dischargeQueueSearchHint,
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
        ),
        filters: <Widget>[
          SizedBox(
            width: 240,
            child: AppSelectField<DischargeStatusFilter>(
              labelText: l10n.dischargeStatusFilterLabel,
              value: state.query.status,
              options: _statusFilterOptions(l10n),
              onChanged: (DischargeStatusFilter? value) async {
                final AppFailure? failure = await controller.applyStatus(
                  value ?? DischargeStatusFilter.all,
                );
                if (context.mounted) {
                  _showFailureIfNeeded(context, failure);
                }
              },
            ),
          ),
        ],
      ),
      body: _DischargeQueuePanel(state: state),
      detail: _DischargeDetailPanel(state: state),
      activity: _DischargeBackendGapPanel(),
    );
  }
}

class _DischargeQueuePanel extends ConsumerWidget {
  const _DischargeQueuePanel({required this.state});

  final DischargeWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final DischargeWorkspaceController controller = ref.read(
      dischargeWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.dischargeWorklistTitle,
      description: l10n.dischargeWorklistDescription,
      child: SizedBox(
        height: 520,
        child: AppListTable<IpdAdmissionSummary>(
          page: state.queue,
          isLoading: state.isRefreshing,
          previousPageLabel: l10n.dischargePreviousPageLabel,
          nextPageLabel: l10n.dischargeNextPageLabel,
          pageLabelBuilder: (AppPage<IpdAdmissionSummary> page) {
            return _pageLabel(context, page);
          },
          onPageChanged: (request) {
            unawaited(controller.changePage(request));
          },
          onRowSelected: (IpdAdmissionSummary item) {
            unawaited(controller.selectAdmission(item));
          },
          emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
            title: l10n.dischargeEmptyQueueTitle,
            body: l10n.dischargeEmptyQueueBody,
            icon: Icons.inbox_outlined,
          ),
          columns: <AppListTableColumn<IpdAdmissionSummary>>[
            AppListTableColumn<IpdAdmissionSummary>(
              label: l10n.dischargePatientColumnLabel,
              cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
                return _QueuePatientCell(item: item);
              },
            ),
            AppListTableColumn<IpdAdmissionSummary>(
              label: l10n.dischargeLocationColumnLabel,
              cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
                return Text(_locationLabel(context, item));
              },
            ),
            AppListTableColumn<IpdAdmissionSummary>(
              label: l10n.dischargeStatusColumnLabel,
              cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
                return AppWorkspaceStatusBadge(
                  status: _statusFor(context, item),
                );
              },
            ),
            AppListTableColumn<IpdAdmissionSummary>(
              label: l10n.dischargeNextActionColumnLabel,
              cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
                return Text(_nextActionLabel(context, item));
              },
            ),
            AppListTableColumn<IpdAdmissionSummary>(
              label: l10n.dischargeTargetColumnLabel,
              cellBuilder: (BuildContext context, IpdAdmissionSummary item) {
                return Text(_dateLabel(context, item.dischargedAt));
              },
            ),
          ],
          mobileItemBuilder: (BuildContext context, IpdAdmissionSummary item) {
            return _MobileQueueItem(item: item);
          },
        ),
      ),
    );
  }
}

class _DischargeDetailPanel extends ConsumerWidget {
  const _DischargeDetailPanel({required this.state});

  final DischargeWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final DischargeAdmissionDetail? detail = state.selectedDetail;

    if (state.isRefreshingDetail && detail == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.dischargeDetailTitle,
        child: AppWorkspaceStatePanel.loading(
          title: l10n.dischargeDetailLoadingTitle,
          body: l10n.dischargeDetailLoadingBody,
          minHeight: 360,
        ),
      );
    }

    if (detail == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.dischargeDetailTitle,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.dischargeNoSelectionTitle,
          body: l10n.dischargeNoSelectionBody,
          icon: Icons.touch_app_outlined,
          minHeight: 360,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.dischargeDetailTitle,
      description: detail.summary.displayId ?? detail.summary.id,
      actions: <Widget>[
        AppReportActionButton.print(
          label: l10n.dischargePrintSummaryAction,
          onPressed: detail.hasSummary
              ? () async {
                  await printFormTemplateDocument(
                    ref: ref,
                    context: context,
                    title: l10n.dischargeReportTitle,
                    subtitle: detail.ipd.patientDisplayName,
                    metadata: <PrintFormMetadataItem>[
                      PrintFormMetadataItem(
                        label: l10n.dischargeReportPatientNoLabel,
                        value: detail.patientId ?? l10n.profileUnknownValue,
                      ),
                      PrintFormMetadataItem(
                        label: l10n.dischargeReportAdmissionLabel,
                        value: detail.summary.displayId ?? detail.summary.id,
                      ),
                      PrintFormMetadataItem(
                        label: l10n.dischargeReportLocationLabel,
                        value: _locationLabel(context, detail.summary),
                      ),
                    ],
                    bodyHtml: _dischargeSummaryHtml(context, detail),
                    footerNote: l10n.dischargeReportFooter,
                  );
                }
              : null,
        ),
      ],
      child: _DischargeDetailContent(state: state, detail: detail),
    );
  }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: detail.ipd.patientDisplayName,
          patientNumber: detail.patientId ?? l10n.profileUnknownValue,
          demographics: _patientDemographics(context, detail),
          semanticLabel: l10n.dischargePatientContextLabel,
          status: _statusFor(context, detail.summary),
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.dischargeAdmissionFieldLabel,
              value: detail.summary.displayId ?? detail.summary.id,
              icon: Icons.local_hotel_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.dischargeEncounterFieldLabel,
              value: detail.encounterId ?? '',
              icon: Icons.assignment_outlined,
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
            AppButton.secondary(
              label: detail.hasSummary
                  ? l10n.dischargeEditSummaryAction
                  : l10n.dischargeStartPlanAction,
              leadingIcon: Icons.edit_note_outlined,
              isLoading: state.isSaving,
              onPressed: () => _openPlanDialog(context, controller, detail),
            ),
            AppButton.secondary(
              label: l10n.dischargeRequestBillingAction,
              leadingIcon: Icons.receipt_long_outlined,
              isLoading: state.isSaving,
              onPressed: () => _openBillingDialog(context, controller),
            ),
            AppButton.secondary(
              label: l10n.dischargeRequestPharmacyAction,
              leadingIcon: Icons.medication_outlined,
              isLoading: state.isSaving,
              onPressed: () => _openPharmacyDialog(context, controller, state),
            ),
            AppButton.primary(
              label: l10n.dischargeCompleteAction,
              leadingIcon: Icons.exit_to_app_outlined,
              isLoading: state.isSaving,
              enabled:
                  detail.hasSummary &&
                  !detail.isCompleted &&
                  detail.blockingItems.isEmpty,
              onPressed: () => _openCompleteDialog(context, controller, detail),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        _ClearanceChecklist(detail: detail),
        SizedBox(height: theme.spacing.lg),
        _SummarySection(detail: detail),
        SizedBox(height: theme.spacing.lg),
        _RelatedRecordsSection(
          title: l10n.dischargeMedicinesSectionTitle,
          emptyBody: detail.pharmacyDataUnavailable
              ? l10n.dischargePharmacyUnavailableBody
              : l10n.dischargeNoMedicinesBody,
          records: detail.pharmacyOrders,
          icon: Icons.medication_outlined,
        ),
        SizedBox(height: theme.spacing.lg),
        _RelatedRecordsSection(
          title: l10n.dischargeBillingSectionTitle,
          emptyBody: detail.billingDataUnavailable
              ? l10n.dischargeBillingUnavailableBody
              : l10n.dischargeNoInvoicesBody,
          records: detail.invoices,
          icon: Icons.receipt_long_outlined,
        ),
        SizedBox(height: theme.spacing.lg),
        _TimelineSection(detail: detail),
      ],
    );
  }
}

class _ClearanceChecklist extends StatelessWidget {
  const _ClearanceChecklist({required this.detail});

  final DischargeAdmissionDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppWorkspaceDetailPanel(
      title: l10n.dischargeChecklistTitle,
      description: l10n.dischargeChecklistBody,
      child: Wrap(
        spacing: theme.spacing.sm,
        runSpacing: theme.spacing.sm,
        children: <Widget>[
          for (final DischargeClearanceItem item in detail.clearanceItems)
            SizedBox(width: 230, child: _ClearanceTile(item: item)),
        ],
      ),
    );
  }
}

class _ClearanceTile extends StatelessWidget {
  const _ClearanceTile({required this.item});

  final DischargeClearanceItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppWorkspaceStatus status = _clearanceStatus(context, item.state);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surface,
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  _clearanceIcon(item.code),
                  size: theme.appTokens.listIconSize,
                  color: colorScheme.primary,
                ),
                SizedBox(width: theme.spacing.xs),
                Expanded(
                  child: Text(
                    _clearanceLabel(context, item.code),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            AppWorkspaceStatusBadge(status: status),
            if (item.reference != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                item.reference!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
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
                    title: Text(record.title ?? record.id),
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
    final List<IpdTimelineItem> items = detail.ipd.timeline.take(6).toList();

    return AppWorkspaceActivityList(
      title: l10n.dischargeTimelineSectionTitle,
      emptyTitle: l10n.dischargeNoTimelineTitle,
      emptyBody: l10n.dischargeNoTimelineBody,
      items: <AppWorkspaceActivityItem>[
        for (final IpdTimelineItem item in items)
          AppWorkspaceActivityItem(
            title: item.label ?? _apiLabel(item.type),
            subtitle: _dateLabel(context, item.occurredAt),
            icon: Icons.history_outlined,
          ),
      ],
    );
  }
}

class _DischargeBackendGapPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppWorkspaceActivityList(
      title: l10n.dischargeBackendGapsTitle,
      emptyTitle: l10n.dischargeBackendGapsTitle,
      emptyBody: l10n.dischargeBackendGapsBody,
      items: <AppWorkspaceActivityItem>[
        AppWorkspaceActivityItem(
          title: l10n.dischargeGapChecklistTitle,
          subtitle: l10n.dischargeGapBackendSubtitle,
          description: l10n.dischargeGapChecklistBody,
          icon: Icons.fact_check_outlined,
          tone: AppWorkspaceStatusTone.warning,
        ),
        AppWorkspaceActivityItem(
          title: l10n.dischargeGapInsuranceTitle,
          subtitle: l10n.dischargeGapBackendSubtitle,
          description: l10n.dischargeGapInsuranceBody,
          icon: Icons.verified_user_outlined,
          tone: AppWorkspaceStatusTone.warning,
        ),
        AppWorkspaceActivityItem(
          title: l10n.dischargeGapDocumentsTitle,
          subtitle: l10n.dischargeGapBackendSubtitle,
          description: l10n.dischargeGapDocumentsBody,
          icon: Icons.description_outlined,
          tone: AppWorkspaceStatusTone.info,
        ),
        AppWorkspaceActivityItem(
          title: l10n.dischargeGapHousekeepingTitle,
          subtitle: l10n.dischargeGapBackendSubtitle,
          description: l10n.dischargeGapHousekeepingBody,
          icon: Icons.cleaning_services_outlined,
          tone: AppWorkspaceStatusTone.warning,
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
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          item.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge,
        ),
        Text(
          item.patientId ?? item.displayId ?? item.id,
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

class _MobileQueueItem extends StatelessWidget {
  const _MobileQueueItem({required this.item});

  final IpdAdmissionSummary item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: _QueuePatientCell(item: item)),
              AppWorkspaceStatusBadge(status: _statusFor(context, item)),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Text(_locationLabel(context, item)),
          SizedBox(height: theme.spacing.xs),
          Text(_nextActionLabel(context, item)),
        ],
      ),
    );
  }
}

class _PlanDischargeDialog extends StatefulWidget {
  const _PlanDischargeDialog({required this.detail, required this.onSubmit});

  final DischargeAdmissionDetail detail;
  final Future<AppFailure?> Function(String summary, DateTime? targetDate)
  onSubmit;

  @override
  State<_PlanDischargeDialog> createState() => _PlanDischargeDialogState();
}

class _PlanDischargeDialogState extends State<_PlanDischargeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _summaryController;
  DateTime? _targetDate;
  AppFailure? _failure;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController(
      text: widget.detail.summaryText ?? '',
    );
    _targetDate = widget.detail.latestDischargeSummary?.dischargedAt;
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DateTime now = DateTime.now();

    return AppFormShell(
      formKey: _formKey,
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
      children: <Widget>[
        Text(l10n.dischargePlanDialogBody),
        AppTextField(
          controller: _summaryController,
          labelText: l10n.dischargeSummaryFieldLabel,
          helperText: l10n.dischargeSummaryHelperText,
          isRequired: true,
          maxLines: 8,
          minLines: 5,
          validator: AppValidators.requiredText(
            l10n.dischargeSummaryRequiredMessage,
          ),
        ),
        AppDateField(
          value: _targetDate,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 2),
          labelText: l10n.dischargeTargetDateLabel,
          pickerButtonLabel: l10n.dischargeDatePickerLabel,
          invalidDateMessage: l10n.dischargeInvalidDateMessage,
          onChanged: (DateTime? value) {
            setState(() {
              _targetDate = value;
            });
          },
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.dischargeSavePlanAction,
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

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      _summaryController.text.trim(),
      _targetDate,
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
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
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
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
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

class _CompleteDialog extends StatefulWidget {
  const _CompleteDialog({required this.detail, required this.onSubmit});

  final DischargeAdmissionDetail detail;
  final Future<AppFailure?> Function() onSubmit;

  @override
  State<_CompleteDialog> createState() => _CompleteDialogState();
}

class _CompleteDialogState extends State<_CompleteDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _confirmed = false;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      formStatus: _failure == null
          ? null
          : AppFailureStateView(failure: _failure!),
      children: <Widget>[
        Text(l10n.dischargeCompleteDialogBody),
        if (widget.detail.blockingItems.isNotEmpty)
          AppWorkspaceStatePanel.state(
            variant: AppStateViewVariant.validation,
            title: l10n.dischargeCompletionBlockersTitle,
            body: l10n.dischargeCompletionBlockersBody,
            minHeight: 120,
          ),
        AppCheckboxField(
          title: l10n.dischargeCompleteConfirmLabel,
          value: _confirmed,
          validator: AppValidators.requiredTrue(
            l10n.dischargeCompleteConfirmRequiredMessage,
          ),
          onChanged: (bool value) {
            setState(() {
              _confirmed = value;
            });
          },
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.dischargeCompleteSubmitAction,
          submitIcon: Icons.exit_to_app_outlined,
          isSubmitting: _isSubmitting,
          enabled: widget.detail.blockingItems.isEmpty,
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
    final AppFailure? failure = await widget.onSubmit();
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

Future<void> _openPlanDialog(
  BuildContext context,
  DischargeWorkspaceController controller,
  DischargeAdmissionDetail detail,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.dischargePlanDialogTitle),
    content: _PlanDischargeDialog(
      detail: detail,
      onSubmit: (String summary, DateTime? targetDate) {
        return controller.planDischarge(
          summary: summary,
          targetDate: targetDate,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
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

Future<void> _openCompleteDialog(
  BuildContext context,
  DischargeWorkspaceController controller,
  DischargeAdmissionDetail detail,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.dischargeCompleteDialogTitle),
    content: _CompleteDialog(
      detail: detail,
      onSubmit: controller.completeDischarge,
    ),
  );
  if (context.mounted && saved == true) {
    _showSaved(context);
  }
}

List<AppSelectOption<DischargeStatusFilter>> _statusFilterOptions(
  AppLocalizations l10n,
) {
  return <AppSelectOption<DischargeStatusFilter>>[
    AppSelectOption<DischargeStatusFilter>(
      value: DischargeStatusFilter.all,
      label: l10n.dischargeStatusAll,
    ),
    AppSelectOption<DischargeStatusFilter>(
      value: DischargeStatusFilter.planned,
      label: l10n.dischargeStatusPlanned,
    ),
    AppSelectOption<DischargeStatusFilter>(
      value: DischargeStatusFilter.summaryPending,
      label: l10n.dischargeStatusSummaryPending,
    ),
    AppSelectOption<DischargeStatusFilter>(
      value: DischargeStatusFilter.pharmacyPending,
      label: l10n.dischargeStatusPharmacyPending,
    ),
    AppSelectOption<DischargeStatusFilter>(
      value: DischargeStatusFilter.nursingPending,
      label: l10n.dischargeStatusNursingPending,
    ),
    AppSelectOption<DischargeStatusFilter>(
      value: DischargeStatusFilter.billingPending,
      label: l10n.dischargeStatusBillingPending,
    ),
    AppSelectOption<DischargeStatusFilter>(
      value: DischargeStatusFilter.insurancePending,
      label: l10n.dischargeStatusInsurancePending,
    ),
    AppSelectOption<DischargeStatusFilter>(
      value: DischargeStatusFilter.documentsReady,
      label: l10n.dischargeStatusDocumentsReady,
    ),
    AppSelectOption<DischargeStatusFilter>(
      value: DischargeStatusFilter.completed,
      label: l10n.dischargeStatusCompleted,
    ),
  ];
}

List<AppSelectOption<String>> _simpleOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

String _pageLabel(BuildContext context, AppPage<IpdAdmissionSummary> page) {
  return context.l10n.dischargePageLabel(
    page.firstItemNumber,
    page.lastItemNumber,
    page.totalItemCount ?? page.items.length,
  );
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

AppWorkspaceStatus _clearanceStatus(
  BuildContext context,
  DischargeClearanceState state,
) {
  return switch (state) {
    DischargeClearanceState.complete => AppWorkspaceStatus(
      label: context.l10n.dischargeClearanceComplete,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.check_circle_outline,
    ),
    DischargeClearanceState.pending => AppWorkspaceStatus(
      label: context.l10n.dischargeClearancePending,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.schedule_outlined,
    ),
    DischargeClearanceState.backendGap => AppWorkspaceStatus(
      label: context.l10n.dischargeClearanceBackendGap,
      tone: AppWorkspaceStatusTone.info,
      icon: Icons.api_outlined,
    ),
    DischargeClearanceState.unavailable => AppWorkspaceStatus(
      label: context.l10n.dischargeClearanceUnavailable,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.lock_outline,
    ),
  };
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

IconData _clearanceIcon(DischargeClearanceCode code) {
  return switch (code) {
    DischargeClearanceCode.doctor => Icons.medical_information_outlined,
    DischargeClearanceCode.nursing => Icons.health_and_safety_outlined,
    DischargeClearanceCode.pharmacy => Icons.medication_outlined,
    DischargeClearanceCode.billing => Icons.receipt_long_outlined,
    DischargeClearanceCode.insurance => Icons.verified_user_outlined,
    DischargeClearanceCode.documents => Icons.description_outlined,
    DischargeClearanceCode.bedRelease => Icons.bed_outlined,
    DischargeClearanceCode.housekeeping => Icons.cleaning_services_outlined,
  };
}

String _clearanceLabel(BuildContext context, DischargeClearanceCode code) {
  final AppLocalizations l10n = context.l10n;
  return switch (code) {
    DischargeClearanceCode.doctor => l10n.dischargeClearanceDoctor,
    DischargeClearanceCode.nursing => l10n.dischargeClearanceNursing,
    DischargeClearanceCode.pharmacy => l10n.dischargeClearancePharmacy,
    DischargeClearanceCode.billing => l10n.dischargeClearanceBilling,
    DischargeClearanceCode.insurance => l10n.dischargeClearanceInsurance,
    DischargeClearanceCode.documents => l10n.dischargeClearanceDocuments,
    DischargeClearanceCode.bedRelease => l10n.dischargeClearanceBedRelease,
    DischargeClearanceCode.housekeeping => l10n.dischargeClearanceHousekeeping,
  };
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

String _patientDemographics(
  BuildContext context,
  DischargeAdmissionDetail detail,
) {
  final String gender = detail.ipd.patientGender == null
      ? context.l10n.profileUnknownValue
      : _apiLabel(detail.ipd.patientGender!);
  final DateTime? birthDate = detail.ipd.patientDateOfBirth;
  if (birthDate == null) {
    return gender;
  }
  return context.l10n.dischargePatientAgeSexLabel(
    _ageInYears(birthDate).toString(),
    gender,
  );
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

String _apiLabel(String value) {
  final String normalized = value.trim().replaceAll(RegExp(r'[_-]+'), ' ');
  if (normalized.isEmpty) {
    return value;
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map((String word) {
        if (word.isEmpty) {
          return word;
        }
        return '${word.substring(0, 1).toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.dischargeSavedMessage)));
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
        return '${record.title ?? record.id} - ${_apiLabel(record.billingStatus ?? record.status ?? '')}';
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
