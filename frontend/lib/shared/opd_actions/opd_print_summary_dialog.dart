import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

/// Selectable OPD print-summary sections.
enum OpdPrintSection {
  visit,
  payment,
  vitals,
  notes,
  diagnoses,
  procedures,
  services,
  referralsFollowUps,
  timeline,
}

/// Opens [PrintOpdSummaryDialog] with non-dismissible barrier rules.
///
/// Print/copy are client-side only. The patient-report `print-events` route
/// audits section-based patient clinical reports, not OPD visit summaries, so
/// this path does not call it and never patches Riverpod. Returns `false`
/// after print so parents do not treat the action as a persisted mutation.
Future<bool?> showPrintOpdSummaryDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
  OpdFlowDetail? detail,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PrintOpdSummaryDialog(flow: flow, detail: detail),
  );
}

/// Preview / print / copy an OPD encounter summary (local-only read action).
class PrintOpdSummaryDialog extends ConsumerStatefulWidget {
  const PrintOpdSummaryDialog({
    required this.flow,
    this.detail,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;

  @override
  ConsumerState<PrintOpdSummaryDialog> createState() =>
      _PrintOpdSummaryDialogState();
}

class _PrintOpdSummaryDialogState extends ConsumerState<PrintOpdSummaryDialog> {
  static const double _previewHeight = 420;

  late Set<OpdPrintSection> _selectedSections;
  bool _isCopying = false;
  bool _isPrinting = false;
  bool _previewMaximized = false;
  AppFailure? _failure;

  bool get _isBusy => _isCopying || _isPrinting;

  @override
  void initState() {
    super.initState();
    _selectedSections = resolveDefaultReportSectionSelection(
      buildOpdPrintSectionAvailabilities(
        flow: widget.flow,
        detail: widget.detail,
      ),
    ).cast<OpdPrintSection>().toSet();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final OpdFlowSummary flow = widget.flow;
    final List<ReportSectionAvailability> availabilities =
        buildOpdPrintSectionAvailabilities(flow: flow, detail: widget.detail);
    final Set<OpdPrintSection> selected = sanitizeReportSectionSelection(
      selectedIds: _selectedSections,
      sections: availabilities,
    ).cast<OpdPrintSection>().toSet();
    final List<AppReportSectionData> tiles = buildReportSectionTiles(
      sections: availabilities,
      titleFor: (Object id) =>
          opdPrintSectionLabel(l10n, id as OpdPrintSection),
      iconFor: (Object id) => opdPrintSectionIcon(id as OpdPrintSection),
      emptyDisabledReason: l10n.reportSectionEmptyDisabledReason,
      unauthorizedDisabledReason: l10n.reportSectionUnauthorizedDisabledReason,
    );
    final String summaryText = buildOpdPrintSummaryText(
      context: context,
      flow: flow,
      detail: widget.detail,
      selectedSections: selected,
    );
    final String documentHtml = PrintDocumentTemplates.buildDocumentHtml(
      kind: PrintDocumentTemplateKind.clinicalSummary,
      ref: ref,
      context: context,
      title: l10n.opdPrintSummaryAction,
      patientContext: buildPrintFormPatientContext(
        l10n,
        patientName: flow.patientDisplayName ?? flow.displayTitle,
        patientId: flow.patientDisplayId,
        encounterId: flow.publicId,
      ),
      bodyHtml: buildOpdPrintSummaryHtml(
        context: context,
        flow: flow,
        detail: widget.detail,
        selectedSections: selected,
      ),
      includeSignatures: true,
    );
    final bool canExport = selected.isNotEmpty && !_isBusy;
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    final double maximizedPreviewHeight = (viewportHeight * 0.72).clamp(
      360.0,
      900.0,
    );

    return AppDialog(
      title: Text(l10n.opdPrintSummaryAction),
      icon: const Icon(AppActionIcons.print),
      maxWidth: 1040,
      scrollable: !_previewMaximized,
      pinActionsToBottom: true,
      closeEnabled: !_isBusy,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          if (!_previewMaximized) OpdActionContextPanel(flow: flow, showTitle: false),
          AppPrintPreviewLayout(
            previewMaximized: _previewMaximized,
            buildSectionPicker:
                (BuildContext context, {required bool sideBySide}) {
                  return AppFormSection(
                    title: l10n.patientsReportSectionsLabel,
                    density: AppFormSectionDensity.compact,
                    children: <Widget>[
                      AppReportSectionPicker(
                        sections: tiles,
                        selectedIds: selected,
                        maxColumns: sideBySide ? 1 : 3,
                        onSelectionChanged: _isBusy
                            ? (_) {}
                            : (Set<Object> next) {
                                setState(() {
                                  _selectedSections =
                                      sanitizeReportSectionSelection(
                                        selectedIds: next,
                                        sections: availabilities,
                                      ).cast<OpdPrintSection>().toSet();
                                });
                              },
                      ),
                    ],
                  );
                },
            preview: AppPrintPreviewPanel(
              html: documentHtml,
              title: l10n.printPreviewTitle,
              height: _previewMaximized
                  ? maximizedPreviewHeight
                  : _previewHeight,
              maximized: _previewMaximized,
              maximizeEnabled: !_isBusy,
              onMaximizeToggle: () {
                setState(() => _previewMaximized = !_previewMaximized);
              },
              fallbackChild: SelectableText(
                summaryText,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
      // Secondary (copy) → Cancel → primary (print). Client-side only; no patch.
      actions: <Widget>[
        AppReportActionButton.copy(
          label: l10n.opdCopySummaryAction,
          icon: AppActionIcons.copy,
          enabled: canExport,
          isLoading: _isCopying,
          onPressed: canExport ? () => _copySummary(summaryText) : null,
        ),
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: !_isBusy,
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
        ),
        AppReportActionButton.print(
          label: l10n.opdPrintAction,
          icon: AppActionIcons.print,
          enabled: canExport,
          isLoading: _isPrinting,
          onPressed: canExport
              ? () => _printSummaryDocument(selected)
              : null,
        ),
      ],
    );
  }

  Future<void> _copySummary(String summary) async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isCopying = true;
      _failure = null;
    });
    try {
      await Clipboard.setData(ClipboardData(text: summary));
      if (!mounted) {
        return;
      }
      // Copy is local-only — leave dialog open so Print remains available.
      setState(() => _isCopying = false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCopying = false;
        _failure = const AppFailure.unexpected();
      });
    }
  }

  Future<void> _printSummaryDocument(Set<OpdPrintSection> selected) async {
    if (_isBusy || selected.isEmpty) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary flow = widget.flow;
    setState(() {
      _isPrinting = true;
      _failure = null;
    });
    try {
      await PrintDocumentTemplates.clinicalSummary(
        ref: ref,
        context: context,
        title: l10n.opdPrintSummaryAction,
        patientContext: buildPrintFormPatientContext(
          l10n,
          patientName: flow.patientDisplayName ?? flow.displayTitle,
          patientId: flow.patientDisplayId,
          encounterId: flow.publicId,
        ),
        bodyHtml: buildOpdPrintSummaryHtml(
          context: context,
          flow: flow,
          detail: widget.detail,
          selectedSections: selected,
        ),
        includeSignatures: true,
        showPreview: false,
      );
      if (!mounted) {
        return;
      }
      // Clear busy before dismiss so a slow pop never looks stuck.
      setState(() => _isPrinting = false);
      // Print is client-side only — no Riverpod patch; dismiss without saved signal.
      Navigator.of(context).pop(false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPrinting = false;
        _failure = const AppFailure.unexpected();
      });
    }
  }
}

/// Section availability for the OPD print-summary picker.
@visibleForTesting
List<ReportSectionAvailability> buildOpdPrintSectionAvailabilities({
  required OpdFlowSummary flow,
  OpdFlowDetail? detail,
}) {
  final OpdFlowDetail value = detail ?? OpdFlowDetail(summary: flow);
  final int referralFollowUpCount =
      value.referrals.length + value.followUps.length;
  final int servicesCount =
      value.labOrders.length +
      value.radiologyOrders.length +
      value.pharmacyOrders.length;
  final int vitalsCount = value.vitalMeasurements.isNotEmpty
      ? value.vitalMeasurements.length
      : value.vitalSigns.length;

  return <ReportSectionAvailability>[
    const ReportSectionAvailability(
      id: OpdPrintSection.visit,
      count: 1,
      alwaysAvailable: true,
    ),
    const ReportSectionAvailability(
      id: OpdPrintSection.payment,
      count: 1,
      alwaysAvailable: true,
    ),
    ReportSectionAvailability(id: OpdPrintSection.vitals, count: vitalsCount),
    ReportSectionAvailability(
      id: OpdPrintSection.notes,
      count: value.clinicalNotes.length,
    ),
    ReportSectionAvailability(
      id: OpdPrintSection.diagnoses,
      count: value.diagnoses.length,
    ),
    ReportSectionAvailability(
      id: OpdPrintSection.procedures,
      count: value.procedures.length,
    ),
    ReportSectionAvailability(
      id: OpdPrintSection.services,
      count: servicesCount,
    ),
    ReportSectionAvailability(
      id: OpdPrintSection.referralsFollowUps,
      count: referralFollowUpCount,
    ),
    ReportSectionAvailability(
      id: OpdPrintSection.timeline,
      count: value.timeline.length,
    ),
  ];
}

@visibleForTesting
String opdPrintSectionLabel(AppLocalizations l10n, OpdPrintSection section) {
  return switch (section) {
    OpdPrintSection.visit => l10n.patientsVisitColumnLabel,
    OpdPrintSection.payment => l10n.opdPaymentStatusLabel,
    OpdPrintSection.vitals => l10n.opdVitalsSummaryLabel,
    OpdPrintSection.notes => l10n.opdClinicalNotesSummaryLabel,
    OpdPrintSection.diagnoses => l10n.opdDiagnosisLabel,
    OpdPrintSection.procedures => l10n.opdProceduresSummaryLabel,
    OpdPrintSection.services => l10n.opdServicesSummaryLabel,
    OpdPrintSection.referralsFollowUps => AppDisplay.joinNonEmpty(<String?>[
      l10n.opdReferralsTitle,
      l10n.opdFollowUpsTitle,
    ], separator: ' / '),
    OpdPrintSection.timeline => l10n.opdTimelineTitle,
  };
}

@visibleForTesting
IconData opdPrintSectionIcon(OpdPrintSection section) {
  return switch (section) {
    OpdPrintSection.visit => Icons.badge_outlined,
    OpdPrintSection.payment => AppActionIcons.payment,
    OpdPrintSection.vitals => Icons.monitor_heart_outlined,
    OpdPrintSection.notes => Icons.notes_outlined,
    OpdPrintSection.diagnoses => Icons.medical_information_outlined,
    OpdPrintSection.procedures => Icons.healing_outlined,
    OpdPrintSection.services => Icons.biotech_outlined,
    OpdPrintSection.referralsFollowUps => AppActionIcons.followUp,
    OpdPrintSection.timeline => Icons.timeline_outlined,
  };
}

/// Builds the plain-text OPD summary preview used by [PrintOpdSummaryDialog].
@visibleForTesting
String buildOpdPrintSummaryText({
  required BuildContext context,
  required OpdFlowSummary flow,
  OpdFlowDetail? detail,
  Set<OpdPrintSection>? selectedSections,
}) {
  final AppLocalizations l10n = context.l10n;
  final Set<OpdPrintSection> selected =
      selectedSections ??
      resolveDefaultReportSectionSelection(
        buildOpdPrintSectionAvailabilities(flow: flow, detail: detail),
      ).cast<OpdPrintSection>().toSet();
  final List<String> lines = <String>[
    if (selected.contains(OpdPrintSection.visit)) ..._visitTextLines(l10n, flow),
    if (selected.contains(OpdPrintSection.payment))
      '${l10n.opdPaymentStatusLabel}: ${opdFlowBillingDisplay(context, flow).label}',
    if (selected.contains(OpdPrintSection.vitals)) ..._vitalsTextLines(l10n, detail),
    if (selected.contains(OpdPrintSection.notes))
      ..._recordsTextLines(
        l10n,
        title: l10n.opdClinicalNotesSummaryLabel,
        records: detail?.clinicalNotes ?? const <OpdRelatedRecord>[],
      ),
    if (selected.contains(OpdPrintSection.diagnoses))
      ..._recordsTextLines(
        l10n,
        title: l10n.opdDiagnosisLabel,
        records: detail?.diagnoses ?? const <OpdRelatedRecord>[],
      ),
    if (selected.contains(OpdPrintSection.procedures))
      ..._recordsTextLines(
        l10n,
        title: l10n.opdProceduresSummaryLabel,
        records: detail?.procedures ?? const <OpdRelatedRecord>[],
      ),
    if (selected.contains(OpdPrintSection.services))
      ..._servicesTextLines(l10n, detail),
    if (selected.contains(OpdPrintSection.referralsFollowUps))
      ..._referralsFollowUpsTextLines(l10n, detail),
    if (selected.contains(OpdPrintSection.timeline))
      ..._timelineTextLines(l10n, detail),
  ];
  return lines.where((String line) => line.trim().isNotEmpty).join('\n');
}

/// Builds formatted HTML body sections for [PrintDocumentTemplates.clinicalSummary].
@visibleForTesting
String buildOpdPrintSummaryHtml({
  required BuildContext context,
  required OpdFlowSummary flow,
  OpdFlowDetail? detail,
  required Set<OpdPrintSection> selectedSections,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<String> sections = <String>[];

  if (selectedSections.contains(OpdPrintSection.visit)) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.patientsVisitColumnLabel,
        bodyHtml: PrintFormTemplate.keyValueGrid(_visitMetadata(l10n, flow)),
      ),
    );
  }
  if (selectedSections.contains(OpdPrintSection.payment)) {
    final OpdBillingDisplay billing = opdFlowBillingDisplay(context, flow);
    sections.add(
      PrintFormTemplate.section(
        title: l10n.opdPaymentStatusLabel,
        bodyHtml: PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
          PrintFormMetadataItem(
            label: l10n.opdPaymentStatusLabel,
            value: billing.label,
          ),
        ]),
      ),
    );
  }
  if (selectedSections.contains(OpdPrintSection.vitals)) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.opdVitalsSummaryLabel,
        bodyHtml: PrintFormTemplate.unorderedList(
          _vitalLines(l10n, detail),
          emptyText: l10n.reportSectionEmptyDisabledReason,
        ),
        avoidPageBreak: true,
      ),
    );
  }
  if (selectedSections.contains(OpdPrintSection.notes)) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.opdClinicalNotesSummaryLabel,
        bodyHtml: PrintFormTemplate.unorderedList(
          _recordLines(l10n, detail?.clinicalNotes ?? const <OpdRelatedRecord>[]),
          emptyText: l10n.reportSectionEmptyDisabledReason,
        ),
        avoidPageBreak: true,
      ),
    );
  }
  if (selectedSections.contains(OpdPrintSection.diagnoses)) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.opdDiagnosisLabel,
        bodyHtml: PrintFormTemplate.unorderedList(
          _recordLines(l10n, detail?.diagnoses ?? const <OpdRelatedRecord>[]),
          emptyText: l10n.reportSectionEmptyDisabledReason,
        ),
        avoidPageBreak: true,
      ),
    );
  }
  if (selectedSections.contains(OpdPrintSection.procedures)) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.opdProceduresSummaryLabel,
        bodyHtml: PrintFormTemplate.unorderedList(
          _recordLines(l10n, detail?.procedures ?? const <OpdRelatedRecord>[]),
          emptyText: l10n.reportSectionEmptyDisabledReason,
        ),
        avoidPageBreak: true,
      ),
    );
  }
  if (selectedSections.contains(OpdPrintSection.services)) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.opdServicesSummaryLabel,
        bodyHtml: PrintFormTemplate.unorderedList(
          _serviceLines(l10n, detail),
          emptyText: l10n.reportSectionEmptyDisabledReason,
        ),
        avoidPageBreak: true,
      ),
    );
  }
  if (selectedSections.contains(OpdPrintSection.referralsFollowUps)) {
    sections.add(
      PrintFormTemplate.section(
        title: AppDisplay.joinNonEmpty(<String?>[
          l10n.opdReferralsTitle,
          l10n.opdFollowUpsTitle,
        ], separator: ' / '),
        bodyHtml: PrintFormTemplate.unorderedList(
          <String>[
            ..._recordLines(
              l10n,
              detail?.referrals ?? const <OpdRelatedRecord>[],
            ),
            ..._recordLines(
              l10n,
              detail?.followUps ?? const <OpdRelatedRecord>[],
            ),
          ],
          emptyText: l10n.reportSectionEmptyDisabledReason,
        ),
        avoidPageBreak: true,
      ),
    );
  }
  if (selectedSections.contains(OpdPrintSection.timeline)) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.opdTimelineTitle,
        bodyHtml: PrintFormTemplate.unorderedList(
          _timelineLines(l10n, detail),
          emptyText: l10n.reportSectionEmptyDisabledReason,
        ),
        avoidPageBreak: true,
      ),
    );
  }

  return sections.join();
}

List<String> _visitTextLines(AppLocalizations l10n, OpdFlowSummary flow) {
  final String? doctor = flow.assignedStaffLabel ?? flow.providerDisplayName;
  return <String>[
    flow.displayTitle,
    AppDisplay.joinNonEmpty(<String?>[
      flow.patientIdentifier,
      _isNonEmpty(doctor) ? '${l10n.opdProviderColumnLabel}: $doctor' : null,
    ], separator: ' | '),
    '${l10n.opdStageLabel}: '
        '${opdStageDisplayLabel(l10n, flow.displayCode ?? flow.stage)}',
    '${l10n.opdNextStepColumnLabel}: '
        '${opdNextStepDisplayLabel(l10n, flow.displayNextStep ?? flow.nextStep)}',
    '${l10n.opdTriageLevelLabel}: ${_dashIfEmpty(triageLevelDisplayLabel(l10n, flow.triageLevel, emptyAsPending: false))}',
    '${l10n.opdRouteDecisionLabel}: ${_dashIfEmpty(AppDisplay.apiLabel(flow.lastRouteTo ?? ''))}',
    if (_isNonEmpty(flow.chiefComplaint))
      '${l10n.opdChiefComplaintLabel}: ${flow.chiefComplaint}',
    if (_isNonEmpty(flow.triageNotes))
      '${l10n.opdTriageNotesLabel}: ${flow.triageNotes}',
  ];
}

List<PrintFormMetadataItem> _visitMetadata(
  AppLocalizations l10n,
  OpdFlowSummary flow,
) {
  final String? doctor = flow.assignedStaffLabel ?? flow.providerDisplayName;
  return <PrintFormMetadataItem>[
    PrintFormMetadataItem(
      label: l10n.printFormPatientNameLabel,
      value: flow.patientDisplayName ?? flow.displayTitle,
    ),
    if (_isNonEmpty(flow.patientIdentifier))
      PrintFormMetadataItem(
        label: l10n.printFormPatientIdLabel,
        value: flow.patientIdentifier!,
      ),
    if (_isNonEmpty(doctor))
      PrintFormMetadataItem(label: l10n.opdProviderColumnLabel, value: doctor!),
    PrintFormMetadataItem(
      label: l10n.opdStageLabel,
      value: opdStageDisplayLabel(l10n, flow.displayCode ?? flow.stage),
    ),
    PrintFormMetadataItem(
      label: l10n.opdNextStepColumnLabel,
      value: opdNextStepDisplayLabel(
        l10n,
        flow.displayNextStep ?? flow.nextStep,
      ),
    ),
    PrintFormMetadataItem(
      label: l10n.opdTriageLevelLabel,
      value: _dashIfEmpty(
        triageLevelDisplayLabel(l10n, flow.triageLevel, emptyAsPending: false),
      ),
    ),
    PrintFormMetadataItem(
      label: l10n.opdRouteDecisionLabel,
      value: _dashIfEmpty(AppDisplay.apiLabel(flow.lastRouteTo ?? '')),
    ),
    if (_isNonEmpty(flow.chiefComplaint))
      PrintFormMetadataItem(
        label: l10n.opdChiefComplaintLabel,
        value: flow.chiefComplaint!,
      ),
    if (_isNonEmpty(flow.triageNotes))
      PrintFormMetadataItem(
        label: l10n.opdTriageNotesLabel,
        value: flow.triageNotes!,
      ),
  ];
}

List<String> _vitalsTextLines(AppLocalizations l10n, OpdFlowDetail? detail) {
  final List<String> lines = _vitalLines(l10n, detail);
  if (lines.isEmpty) {
    return <String>[];
  }
  return <String>[l10n.opdVitalsSummaryLabel, ...lines];
}

List<String> _vitalLines(AppLocalizations l10n, OpdFlowDetail? detail) {
  if (detail == null) {
    return const <String>[];
  }
  if (detail.vitalMeasurements.isNotEmpty) {
    return <String>[
      for (final OpdVitalSign vital in detail.vitalMeasurements)
        AppDisplay.joinNonEmpty(<String?>[
          AppDisplay.apiLabel(vital.vitalType),
          vital.displayValue.isEmpty ? null : vital.displayValue,
        ], separator: ' | '),
    ];
  }
  return _recordLines(l10n, detail.vitalSigns);
}

List<String> _recordsTextLines(
  AppLocalizations l10n, {
  required String title,
  required List<OpdRelatedRecord> records,
}) {
  if (records.isEmpty) {
    return const <String>[];
  }
  return <String>[title, ..._recordLines(l10n, records)];
}

List<String> _recordLines(
  AppLocalizations l10n,
  List<OpdRelatedRecord> records,
) {
  return <String>[
    for (final OpdRelatedRecord record in records) _recordLine(l10n, record),
  ];
}

String _recordLine(
  AppLocalizations l10n,
  OpdRelatedRecord record, {
  bool pendingWhenEmpty = false,
}) {
  return AppDisplay.joinNonEmpty(<String?>[
    _isNonEmpty(record.title) ? record.title : record.id,
    record.subtitle,
    _statusDisplay(
      l10n,
      record.status,
      pendingWhenEmpty: pendingWhenEmpty,
    ),
  ], separator: ' | ');
}

List<String> _servicesTextLines(AppLocalizations l10n, OpdFlowDetail? detail) {
  final List<String> lines = _serviceLines(l10n, detail);
  if (lines.isEmpty) {
    return const <String>[];
  }
  return <String>[l10n.opdServicesSummaryLabel, ...lines];
}

List<String> _serviceLines(AppLocalizations l10n, OpdFlowDetail? detail) {
  if (detail == null) {
    return const <String>[];
  }
  return <String>[
    for (final OpdRelatedRecord record in detail.labOrders)
      _prefixedRecordLine(l10n, l10n.clinicalResultsModuleLaboratoryLabel, record),
    for (final OpdRelatedRecord record in detail.radiologyOrders)
      _prefixedRecordLine(l10n, l10n.clinicalResultsModuleRadiologyLabel, record),
    for (final OpdRelatedRecord record in detail.pharmacyOrders)
      _prefixedRecordLine(l10n, l10n.pharmacyTitle, record),
  ];
}

String _prefixedRecordLine(
  AppLocalizations l10n,
  String prefix,
  OpdRelatedRecord record,
) {
  return AppDisplay.joinNonEmpty(<String?>[
    prefix,
    _recordLine(l10n, record, pendingWhenEmpty: true),
  ], separator: ' | ');
}

List<String> _referralsFollowUpsTextLines(
  AppLocalizations l10n,
  OpdFlowDetail? detail,
) {
  final List<String> lines = <String>[
    ..._recordLines(l10n, detail?.referrals ?? const <OpdRelatedRecord>[]),
    ..._recordLines(l10n, detail?.followUps ?? const <OpdRelatedRecord>[]),
  ];
  if (lines.isEmpty) {
    return const <String>[];
  }
  return <String>[
    AppDisplay.joinNonEmpty(<String?>[
      l10n.opdReferralsTitle,
      l10n.opdFollowUpsTitle,
    ], separator: ' / '),
    ...lines,
  ];
}

List<String> _timelineTextLines(AppLocalizations l10n, OpdFlowDetail? detail) {
  final List<String> lines = _timelineLines(l10n, detail);
  if (lines.isEmpty) {
    return const <String>[];
  }
  return <String>[l10n.opdTimelineTitle, ...lines];
}

List<String> _timelineLines(AppLocalizations l10n, OpdFlowDetail? detail) {
  final List<OpdTimelineItem> timeline =
      detail?.timeline ?? const <OpdTimelineItem>[];
  return <String>[
    for (final OpdTimelineItem item in timeline)
      AppDisplay.joinNonEmpty(<String?>[
        AppDisplay.apiLabel(item.action),
        opdStageDisplayLabel(l10n, item.stage),
        item.notes,
      ], separator: ' | '),
  ];
}

String? _statusDisplay(
  AppLocalizations l10n,
  String? status, {
  bool pendingWhenEmpty = false,
}) {
  final String normalized = (status ?? '').trim();
  if (normalized.isEmpty) {
    return pendingWhenEmpty
        ? l10n.opdClinicalServiceStatusPendingLabel
        : null;
  }
  final String upper = normalized.toUpperCase();
  if (upper.contains('PENDING') ||
      upper == 'REQUESTED' ||
      upper == 'ORDERED' ||
      upper == 'IN_PROGRESS') {
    return l10n.opdClinicalServiceStatusPendingLabel;
  }
  return AppDisplay.apiLabel(normalized);
}

String _dashIfEmpty(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? '-' : normalized;
}

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}
