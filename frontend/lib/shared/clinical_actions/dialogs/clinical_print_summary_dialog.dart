import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_display.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

/// Selectable clinical consultation-summary sections.
enum ClinicalPrintSection {
  coverage,
  vitals,
  notes,
  prescriptions,
  diagnoses,
  labResults,
  radiology,
  procedures,
  carePlans,
  referrals,
  followUps,
  admissions,
}

/// Opens the clinical print dialog with section checkboxes and live preview.
Future<bool?> showClinicalPrintSummaryDialog({
  required BuildContext context,
  required ClinicalEncounterBundle bundle,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalPrintSummaryDialog(bundle: bundle),
  );
}

class ClinicalPrintSummaryDialog extends ConsumerStatefulWidget {
  const ClinicalPrintSummaryDialog({required this.bundle, super.key});

  final ClinicalEncounterBundle bundle;

  @override
  ConsumerState<ClinicalPrintSummaryDialog> createState() =>
      _ClinicalPrintSummaryDialogState();
}

class _ClinicalPrintSummaryDialogState
    extends ConsumerState<ClinicalPrintSummaryDialog> {
  late Set<Object> _selectedSections;
  bool _facilityTouched = false;
  bool _isCopying = false;
  bool _isPrinting = false;
  AppPrintPreviewPaneMode _paneMode = AppPrintPreviewPaneMode.split;
  double _scale = 1;
  int _currentPage = 1;
  AppFailure? _failure;

  bool get _isBusy => _isCopying || _isPrinting;

  Set<Object> _effectiveSelection(
    List<ReportSectionAvailability> availabilities,
  ) {
    if (_facilityTouched) {
      return sanitizeReportSectionSelection(
        selectedIds: _selectedSections,
        sections: availabilities,
      );
    }
    final Set<Object> facilityDefaults = <Object>{
      for (final ReportSectionAvailability section in availabilities)
        if (section.id is PrintFacilitySection && section.enabled) section.id,
    };
    return sanitizeReportSectionSelection(
      selectedIds: <Object>{..._selectedSections, ...facilityDefaults},
      sections: availabilities,
    );
  }

  @override
  void initState() {
    super.initState();
    final PrintFormTemplateContext branding = ref.read(
      printFormTemplateContextProvider,
    );
    _selectedSections = resolveDefaultReportSectionSelection(
      buildClinicalPrintSectionAvailabilities(
        bundle: widget.bundle,
        branding: branding,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClinicalEncounterBundle bundle = widget.bundle;
    final PrintFormTemplateContext branding = ref.watch(
      printFormTemplateContextProvider,
    );
    final List<ReportSectionAvailability> availabilities =
        buildClinicalPrintSectionAvailabilities(
          bundle: bundle,
          branding: branding,
        );
    final Set<Object> selected = _effectiveSelection(availabilities);
    final List<AppReportSectionData> tiles = buildReportSectionTiles(
      sections: availabilities,
      titleFor: (Object id) => clinicalPrintSectionLabel(l10n, id),
      iconFor: clinicalPrintSectionIcon,
      emptyDisabledReason: l10n.reportSectionEmptyDisabledReason,
      unauthorizedDisabledReason: l10n.reportSectionUnauthorizedDisabledReason,
    );
    final String summaryText = buildClinicalPrintSummaryText(
      context: context,
      bundle: bundle,
      selectedSections: selected,
    );
    final PrintFormBrandingOptions brandingOptions =
        brandingOptionsFromFacilitySections(selected);
    final String documentHtml = PrintDocumentTemplates.buildDocumentHtml(
      kind: PrintDocumentTemplateKind.clinicalSummary,
      ref: ref,
      context: context,
      title: l10n.clinicalConsultationSummaryTitle,
      brandingOptions: brandingOptions,
      patientContext: buildPrintFormPatientContext(
        l10n,
        patientName: bundle.entry.displayTitle,
        patientId: bundle.entry.apiPatientId,
        encounterId: bundle.entry.encounterPublicId,
      ),
      bodyHtml: buildClinicalPrintSummaryHtml(
        context: context,
        bundle: bundle,
        selectedSections: selected,
      ),
      includeSignatures: true,
    );
    final bool canExport = selected.isNotEmpty && !_isBusy;
    final int pageCount = AppPrintPreviewPages.countFromHtml(documentHtml);
    final int currentPage = AppPrintPreviewPages.clampPage(
      _currentPage,
      pageCount,
    );

    return AppDialog(
      title: Text(l10n.clinicalPrintSummaryAction),
      icon: const Icon(AppActionIcons.print),
      maxWidth: 1120,
      scrollable: false,
      pinActionsToBottom: true,
      stackActionsWhenCompact: false,
      contentPadding: EdgeInsets.zero,
      closeEnabled: !_isBusy,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null) ...<Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.sm,
                theme.spacing.sm,
                theme.spacing.sm,
                0,
              ),
              child: AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
          ],
          Expanded(
            child: AppPrintPreviewWorkspace(
              paneMode: _paneMode,
              paneModeEnabled: !_isBusy,
              onPaneModeChanged: (AppPrintPreviewPaneMode next) {
                setState(() => _paneMode = next);
              },
              toolbar: AppPrintPreviewToolbar(
                scale: _scale,
                enabled: !_isBusy,
                currentPage: currentPage,
                pageCount: pageCount,
                onZoomIn: () {
                  setState(() => _scale = AppPrintPreviewZoom.zoomIn(_scale));
                },
                onZoomOut: () {
                  setState(() => _scale = AppPrintPreviewZoom.zoomOut(_scale));
                },
                onZoomIncrease: () {
                  setState(
                    () => _scale = AppPrintPreviewZoom.increase(_scale),
                  );
                },
                onZoomDecrease: () {
                  setState(
                    () => _scale = AppPrintPreviewZoom.decrease(_scale),
                  );
                },
                onFitPage: () {
                  setState(() {
                    _scale = AppPrintPreviewZoom.fitPage(
                      1120 * 0.55 - theme.spacing.lg * 2,
                    );
                  });
                },
                onPagePrevious: () {
                  setState(() {
                    _currentPage = AppPrintPreviewPages.clampPage(
                      currentPage - 1,
                      pageCount,
                    );
                  });
                },
                onPageNext: () {
                  setState(() {
                    _currentPage = AppPrintPreviewPages.clampPage(
                      currentPage + 1,
                      pageCount,
                    );
                  });
                },
              ),
              sectionPicker: AppReportSectionPicker(
                sections: tiles,
                selectedIds: selected,
                compact: true,
                minTileWidth: 140,
                onSelectionChanged: _isBusy
                    ? (_) {}
                    : (Set<Object> next) {
                        setState(() {
                          _selectedSections = sanitizeReportSectionSelection(
                            selectedIds: next,
                            sections: availabilities,
                          );
                          _facilityTouched = true;
                          _currentPage = 1;
                        });
                      },
              ),
              preview: AppPrintPreviewPanel(
                html: documentHtml,
                scale: _scale,
                toolbarEnabled: false,
                focusedPage: currentPage,
                currentPage: currentPage,
                pageCount: pageCount,
                fallbackChild: SelectableText(
                  summaryText,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppReportActionButton.copy(
          label: l10n.opdCopySummaryAction,
          icon: AppActionIcons.copy,
          enabled: canExport,
          isLoading: _isCopying,
          onPressed: canExport ? () => _copySummary(summaryText) : null,
        ),
        AppButton.close(
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
          onPressed: canExport ? () => _printDocument(selected) : null,
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

  Future<void> _printDocument(Set<Object> selected) async {
    if (_isBusy || selected.isEmpty) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final ClinicalEncounterBundle bundle = widget.bundle;
    setState(() {
      _isPrinting = true;
      _failure = null;
    });
    try {
      await PrintDocumentTemplates.clinicalSummary(
        ref: ref,
        context: context,
        title: l10n.clinicalConsultationSummaryTitle,
        brandingOptions: brandingOptionsFromFacilitySections(selected),
        patientContext: buildPrintFormPatientContext(
          l10n,
          patientName: bundle.entry.displayTitle,
          patientId: bundle.entry.apiPatientId,
          encounterId: bundle.entry.encounterPublicId,
        ),
        bodyHtml: buildClinicalPrintSummaryHtml(
          context: context,
          bundle: bundle,
          selectedSections: selected,
        ),
        includeSignatures: true,
        showPreview: false,
      );
      if (!mounted) {
        return;
      }
      setState(() => _isPrinting = false);
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

@visibleForTesting
List<ReportSectionAvailability> buildClinicalPrintSectionAvailabilities({
  required ClinicalEncounterBundle bundle,
  PrintFormTemplateContext? branding,
}) {
  final ClinicalTriageHandoff? handoff = bundle.triageHandoff;
  final List<ClinicalRelatedRecord> notes = clinicalNotesForDisplay(
    bundle.clinicalNotes,
  );
  final List<ClinicalRelatedRecord> diagnoses =
      deduplicateClinicalRelatedRecords(bundle.diagnoses, diagnoses: true);
  final List<ClinicalRelatedRecord> pharmacy =
      deduplicateClinicalRelatedRecords(bundle.pharmacyOrders);
  final List<ClinicalRelatedRecord> labs = deduplicateClinicalRelatedRecords(
    bundle.labOrders,
  );
  final int labItemCount = labs.fold<int>(
    0,
    (int sum, ClinicalRelatedRecord order) =>
        sum +
        (order.labOrderItems.isEmpty ? 1 : order.labOrderItems.length),
  );
  final List<ReportSectionAvailability> facilitySections = branding == null
      ? const <ReportSectionAvailability>[]
      : buildFacilityPrintSectionAvailabilities(
          effectivePrintBranding(
            appBranding: branding.appBranding,
            facilityBranding: branding.facilityBranding,
          ),
        );

  return <ReportSectionAvailability>[
    ...facilitySections,
    ReportSectionAvailability(
      id: ClinicalPrintSection.coverage,
      count: handoff?.hasCoverageDetails == true ? 1 : 0,
    ),
    ReportSectionAvailability(
      id: ClinicalPrintSection.vitals,
      count: handoff?.vitalSigns.length ?? 0,
    ),
    ReportSectionAvailability(id: ClinicalPrintSection.notes, count: notes.length),
    ReportSectionAvailability(
      id: ClinicalPrintSection.prescriptions,
      count: pharmacy.fold<int>(
        0,
        (int sum, ClinicalRelatedRecord order) =>
            sum +
            (order.pharmacyOrderItems.isEmpty
                ? 1
                : order.pharmacyOrderItems.length),
      ),
    ),
    ReportSectionAvailability(
      id: ClinicalPrintSection.diagnoses,
      count: diagnoses.length,
    ),
    ReportSectionAvailability(
      id: ClinicalPrintSection.labResults,
      count: labItemCount,
    ),
    ReportSectionAvailability(
      id: ClinicalPrintSection.radiology,
      count: bundle.radiologyOrders.length,
    ),
    ReportSectionAvailability(
      id: ClinicalPrintSection.procedures,
      count: bundle.procedures.length,
    ),
    ReportSectionAvailability(
      id: ClinicalPrintSection.carePlans,
      count: bundle.carePlans.length,
    ),
    ReportSectionAvailability(
      id: ClinicalPrintSection.referrals,
      count: bundle.referrals.length,
    ),
    ReportSectionAvailability(
      id: ClinicalPrintSection.followUps,
      count: bundle.followUps.length,
    ),
    ReportSectionAvailability(
      id: ClinicalPrintSection.admissions,
      count: bundle.admissions.length,
    ),
  ];
}

@visibleForTesting
String clinicalPrintSectionLabel(AppLocalizations l10n, Object section) {
  if (section is PrintFacilitySection) {
    return printFacilitySectionLabel(l10n, section);
  }
  return switch (section as ClinicalPrintSection) {
    ClinicalPrintSection.coverage => l10n.claimsCoverageFieldLabel,
    ClinicalPrintSection.vitals => l10n.clinicalVitalsSectionTitle,
    ClinicalPrintSection.notes => l10n.clinicalPatientNotesTitle,
    ClinicalPrintSection.prescriptions => l10n.clinicalPharmacyOrdersTitle,
    ClinicalPrintSection.diagnoses => l10n.clinicalPatientDiagnosesTitle,
    ClinicalPrintSection.labResults => l10n.labResultsSectionTitle,
    ClinicalPrintSection.radiology => l10n.clinicalRadiologyOrdersTitle,
    ClinicalPrintSection.procedures => l10n.opdProceduresSummaryLabel,
    ClinicalPrintSection.carePlans => l10n.clinicalCarePlansTitle,
    ClinicalPrintSection.referrals => l10n.opdReferralsTitle,
    ClinicalPrintSection.followUps => l10n.opdFollowUpsTitle,
    ClinicalPrintSection.admissions => l10n.patientsAdmissionsSectionTitle,
  };
}

@visibleForTesting
IconData clinicalPrintSectionIcon(Object section) {
  if (section is PrintFacilitySection) {
    return printFacilitySectionIcon(section);
  }
  return switch (section as ClinicalPrintSection) {
    ClinicalPrintSection.coverage => AppActionIcons.payment,
    ClinicalPrintSection.vitals => Icons.monitor_heart_outlined,
    ClinicalPrintSection.notes => Icons.sticky_note_2_outlined,
    ClinicalPrintSection.prescriptions => Icons.medication_outlined,
    ClinicalPrintSection.diagnoses => Icons.medical_information_outlined,
    ClinicalPrintSection.labResults => Icons.science_outlined,
    ClinicalPrintSection.radiology => Icons.radar_outlined,
    ClinicalPrintSection.procedures => Icons.healing_outlined,
    ClinicalPrintSection.carePlans => Icons.assignment_outlined,
    ClinicalPrintSection.referrals => AppActionIcons.referral,
    ClinicalPrintSection.followUps => AppActionIcons.followUp,
    ClinicalPrintSection.admissions => AppActionIcons.bed,
  };
}

@visibleForTesting
String buildClinicalPrintSummaryText({
  required BuildContext context,
  required ClinicalEncounterBundle bundle,
  Set<Object>? selectedSections,
}) {
  final AppLocalizations l10n = context.l10n;
  final Set<Object> selected =
      selectedSections ??
      resolveDefaultReportSectionSelection(
        buildClinicalPrintSectionAvailabilities(bundle: bundle),
      );
  final List<String> lines = <String>[];

  void addHeading(String title, Iterable<String> body) {
    final List<String> values = body
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    if (values.isEmpty) {
      return;
    }
    lines.add(title);
    lines.addAll(values.map((String line) => '- $line'));
  }

  if (selected.contains(ClinicalPrintSection.coverage)) {
    addHeading(
      l10n.claimsCoverageFieldLabel,
      _coverageTextLines(l10n, bundle.triageHandoff),
    );
  }
  if (selected.contains(ClinicalPrintSection.vitals)) {
    addHeading(
      l10n.clinicalVitalsSectionTitle,
      _vitalTextLines(bundle.triageHandoff),
    );
  }
  if (selected.contains(ClinicalPrintSection.notes)) {
    addHeading(
      l10n.clinicalPatientNotesTitle,
      clinicalNotesForDisplay(
        bundle.clinicalNotes,
      ).map((ClinicalRelatedRecord note) => note.title ?? note.id),
    );
  }
  if (selected.contains(ClinicalPrintSection.prescriptions)) {
    addHeading(
      l10n.clinicalPharmacyOrdersTitle,
      _prescriptionTextLines(bundle.pharmacyOrders),
    );
  }
  if (selected.contains(ClinicalPrintSection.diagnoses)) {
    addHeading(
      l10n.clinicalPatientDiagnosesTitle,
      deduplicateClinicalRelatedRecords(
        bundle.diagnoses,
        diagnoses: true,
      ).map(_diagnosisLine),
    );
  }
  if (selected.contains(ClinicalPrintSection.labResults)) {
    addHeading(
      l10n.labResultsSectionTitle,
      _labResultTextLines(l10n, bundle.labOrders),
    );
  }
  if (selected.contains(ClinicalPrintSection.radiology)) {
    addHeading(
      l10n.clinicalRadiologyOrdersTitle,
      _radiologyTextLines(bundle.radiologyOrders),
    );
  }
  if (selected.contains(ClinicalPrintSection.procedures)) {
    addHeading(
      l10n.opdProceduresSummaryLabel,
      bundle.procedures.map(_simpleRecordLine),
    );
  }
  if (selected.contains(ClinicalPrintSection.carePlans)) {
    addHeading(
      l10n.clinicalCarePlansTitle,
      bundle.carePlans.map(_simpleRecordLine),
    );
  }
  if (selected.contains(ClinicalPrintSection.referrals)) {
    addHeading(l10n.opdReferralsTitle, bundle.referrals.map(_simpleRecordLine));
  }
  if (selected.contains(ClinicalPrintSection.followUps)) {
    addHeading(l10n.opdFollowUpsTitle, bundle.followUps.map(_simpleRecordLine));
  }
  if (selected.contains(ClinicalPrintSection.admissions)) {
    addHeading(
      l10n.patientsAdmissionsSectionTitle,
      bundle.admissions.map(_simpleRecordLine),
    );
  }

  return lines.join('\n');
}

@visibleForTesting
String buildClinicalPrintSummaryHtml({
  required BuildContext context,
  required ClinicalEncounterBundle bundle,
  required Set<Object> selectedSections,
}) {
  final AppLocalizations l10n = context.l10n;
  final ClinicalTriageHandoff? handoff = bundle.triageHandoff;
  final List<String> sections = <String>[];

  if (selectedSections.contains(ClinicalPrintSection.coverage) &&
      (handoff?.hasCoverageDetails ?? false)) {
    final List<PrintFormMetadataItem> items = _coverageMetadata(l10n, handoff!);
    if (items.isNotEmpty) {
      sections.add(
        PrintFormTemplate.section(
          title: l10n.claimsCoverageFieldLabel,
          bodyHtml: PrintFormTemplate.keyValueGrid(items),
        ),
      );
    }
  }

  if (selectedSections.contains(ClinicalPrintSection.vitals) &&
      (handoff?.vitalSigns.isNotEmpty ?? false)) {
    sections.add(
      PrintFormTemplate.section(
        title: l10n.clinicalVitalsSectionTitle,
        bodyHtml: PrintFormTemplate.unorderedList(
          _vitalTextLines(handoff),
          emptyText: l10n.reportSectionEmptyDisabledReason,
        ),
        avoidPageBreak: true,
      ),
    );
  }

  if (selectedSections.contains(ClinicalPrintSection.notes)) {
    final List<ClinicalRelatedRecord> notes = clinicalNotesForDisplay(
      bundle.clinicalNotes,
    );
    if (notes.isNotEmpty) {
      sections.add(
        PrintFormTemplate.section(
          title: l10n.clinicalPatientNotesTitle,
          bodyHtml: PrintFormTemplate.unorderedList(
            notes
                .map((ClinicalRelatedRecord note) => (note.title ?? '').trim())
                .where((String text) => text.isNotEmpty),
            emptyText: l10n.reportSectionEmptyDisabledReason,
          ),
          avoidPageBreak: true,
        ),
      );
    }
  }

  if (selectedSections.contains(ClinicalPrintSection.prescriptions)) {
    final List<String> lines = _prescriptionTextLines(bundle.pharmacyOrders);
    if (lines.isNotEmpty) {
      sections.add(
        PrintFormTemplate.section(
          title: l10n.clinicalPharmacyOrdersTitle,
          bodyHtml: PrintFormTemplate.unorderedList(
            lines,
            emptyText: l10n.reportSectionEmptyDisabledReason,
          ),
          avoidPageBreak: true,
        ),
      );
    }
  }

  if (selectedSections.contains(ClinicalPrintSection.diagnoses)) {
    final List<ClinicalRelatedRecord> diagnoses =
        deduplicateClinicalRelatedRecords(bundle.diagnoses, diagnoses: true);
    if (diagnoses.isNotEmpty) {
      sections.add(
        PrintFormTemplate.section(
          title: l10n.clinicalPatientDiagnosesTitle,
          bodyHtml: PrintFormTemplate.unorderedList(
            diagnoses.map(_diagnosisLine),
            emptyText: l10n.reportSectionEmptyDisabledReason,
          ),
          avoidPageBreak: true,
        ),
      );
    }
  }

  if (selectedSections.contains(ClinicalPrintSection.labResults)) {
    final String labHtml = _labResultsHtml(l10n, bundle.labOrders);
    if (labHtml.isNotEmpty) {
      sections.add(
        PrintFormTemplate.section(
          title: l10n.labResultsSectionTitle,
          bodyHtml: labHtml,
          avoidPageBreak: true,
        ),
      );
    }
  }

  if (selectedSections.contains(ClinicalPrintSection.radiology)) {
    final List<String> lines = _radiologyTextLines(bundle.radiologyOrders);
    if (lines.isNotEmpty) {
      sections.add(
        PrintFormTemplate.section(
          title: l10n.clinicalRadiologyOrdersTitle,
          bodyHtml: PrintFormTemplate.unorderedList(
            lines,
            emptyText: l10n.reportSectionEmptyDisabledReason,
          ),
          avoidPageBreak: true,
        ),
      );
    }
  }

  void addSimple(
    ClinicalPrintSection section,
    String title,
    List<ClinicalRelatedRecord> records,
  ) {
    if (!selectedSections.contains(section) || records.isEmpty) {
      return;
    }
    sections.add(
      PrintFormTemplate.section(
        title: title,
        bodyHtml: PrintFormTemplate.unorderedList(
          records.map(_simpleRecordLine),
          emptyText: l10n.reportSectionEmptyDisabledReason,
        ),
        avoidPageBreak: true,
      ),
    );
  }

  addSimple(
    ClinicalPrintSection.procedures,
    l10n.opdProceduresSummaryLabel,
    bundle.procedures,
  );
  addSimple(
    ClinicalPrintSection.carePlans,
    l10n.clinicalCarePlansTitle,
    bundle.carePlans,
  );
  addSimple(
    ClinicalPrintSection.referrals,
    l10n.opdReferralsTitle,
    bundle.referrals,
  );
  addSimple(
    ClinicalPrintSection.followUps,
    l10n.opdFollowUpsTitle,
    bundle.followUps,
  );
  addSimple(
    ClinicalPrintSection.admissions,
    l10n.patientsAdmissionsSectionTitle,
    bundle.admissions,
  );

  return sections.join();
}

List<PrintFormMetadataItem> _coverageMetadata(
  AppLocalizations l10n,
  ClinicalTriageHandoff handoff,
) {
  return <PrintFormMetadataItem>[
    if (_hasText(handoff.consultationPaymentStatus))
      PrintFormMetadataItem(
        label: l10n.opdPaymentStatusLabel,
        value: AppDisplay.apiLabel(handoff.consultationPaymentStatus!),
      ),
    if (handoff.consultationPaid)
      PrintFormMetadataItem(
        label: l10n.claimsCoverageFieldLabel,
        value: l10n.opdCoverageVerifiedLabel,
      ),
    if (_hasText(handoff.consultationFeeLabel))
      PrintFormMetadataItem(
        label: l10n.opdConsultationFeeLabel,
        value: handoff.consultationFeeLabel!,
      ),
    if (_hasText(handoff.consultationPaidAmountLabel))
      PrintFormMetadataItem(
        label: l10n.opdBillingAmountPaidLabel,
        value: handoff.consultationPaidAmountLabel!,
      ),
  ];
}

List<String> _coverageTextLines(
  AppLocalizations l10n,
  ClinicalTriageHandoff? handoff,
) {
  if (handoff == null || !handoff.hasCoverageDetails) {
    return const <String>[];
  }
  return _coverageMetadata(l10n, handoff)
      .map((PrintFormMetadataItem item) => '${item.label}: ${item.value}')
      .toList(growable: false);
}

List<String> _vitalTextLines(ClinicalTriageHandoff? handoff) {
  if (handoff == null) {
    return const <String>[];
  }
  return <String>[
    for (final ClinicalVitalSummary vital in handoff.vitalSigns)
      AppDisplay.joinNonEmpty(<String?>[
        AppDisplay.apiLabel(vital.vitalType),
        vital.displayValue,
        vital.status.trim().isEmpty ||
                vital.status.toUpperCase() == 'RECORDED'
            ? null
            : AppDisplay.apiLabel(vital.status),
      ], separator: ': '),
  ];
}

List<String> _prescriptionTextLines(List<ClinicalRelatedRecord> orders) {
  final List<ClinicalRelatedRecord> pharmacy =
      deduplicateClinicalRelatedRecords(orders);
  return <String>[
    for (final ClinicalRelatedRecord order in pharmacy)
      if (order.pharmacyOrderItems.isEmpty)
        _simpleRecordLine(order)
      else
        for (final ClinicalPharmacyOrderItem item in order.pharmacyOrderItems)
          clinicalPrescriptionItemPaperLine(item),
  ];
}

String _diagnosisLine(ClinicalRelatedRecord diagnosis) {
  return AppDisplay.joinNonEmpty(<String?>[
    diagnosis.title,
    if (_hasText(diagnosis.diagnosisType))
      AppDisplay.apiLabel(diagnosis.diagnosisType!),
    diagnosis.code,
  ], separator: ' · ');
}

String _simpleRecordLine(ClinicalRelatedRecord record) {
  return AppDisplay.joinNonEmpty(<String?>[
    record.title,
    record.subtitle,
    if (_hasText(record.status)) AppDisplay.apiLabel(record.status!),
  ], separator: ' · ');
}

List<String> _radiologyTextLines(List<ClinicalRelatedRecord> orders) {
  return <String>[
    for (final ClinicalRelatedRecord order
        in deduplicateClinicalRelatedRecords(orders))
      if (order.radiologyOrderItems.isEmpty)
        _simpleRecordLine(order)
      else
        for (final ClinicalRadiologyOrderItem item in order.radiologyOrderItems)
          AppDisplay.joinNonEmpty(<String?>[
            item.displayTitle,
            item.displaySubtitle,
            item.clinicalNote,
            if (_hasText(order.status)) AppDisplay.apiLabel(order.status!),
          ], separator: ' · '),
  ];
}

List<String> _labResultTextLines(
  AppLocalizations l10n,
  List<ClinicalRelatedRecord> orders,
) {
  final String pending = l10n.labStatusPending;
  return <String>[
    for (final ClinicalRelatedRecord order
        in deduplicateClinicalRelatedRecords(orders))
      if (order.labOrderItems.isEmpty)
        _simpleRecordLine(order)
      else
        for (final ClinicalLabOrderItem item in order.labOrderItems)
          clinicalLabResultPrintLine(l10n, item, pendingLabel: pending),
  ];
}

String _labResultValueLabel(ClinicalLabOrderItem item, String pendingLabel) {
  if (!item.hasResult) {
    return pendingLabel;
  }
  final String? amount = item.resultValue?.trim();
  final String? unit = (item.resultUnit ?? item.unit)?.trim();
  if (amount != null && amount.isNotEmpty) {
    if (unit == null || unit.isEmpty) {
      return amount;
    }
    return '$amount $unit';
  }
  return item.displayResultValue ?? pendingLabel;
}

String _labResultsHtml(
  AppLocalizations l10n,
  List<ClinicalRelatedRecord> orders,
) {
  final List<ClinicalRelatedRecord> labs = deduplicateClinicalRelatedRecords(
    orders,
  );
  if (labs.isEmpty) {
    return '';
  }

  final String pending = l10n.labStatusPending;
  final List<List<String>> rows = <List<String>>[
    for (final ClinicalRelatedRecord order in labs)
      if (order.labOrderItems.isEmpty)
        <String>[
          order.title ?? order.id,
          pending,
          '—',
          '—',
          _hasText(order.status) ? AppDisplay.apiLabel(order.status!) : pending,
        ]
      else
        for (final ClinicalLabOrderItem item in order.labOrderItems)
          <String>[
            _labTestLabel(order, item),
            _labResultValueLabel(item, pending),
            item.displayReferenceRange ?? '—',
            _hasText(item.effectiveResultFlag)
                ? AppDisplay.apiLabel(item.effectiveResultFlag!)
                : '—',
            _hasText(item.status)
                ? AppDisplay.apiLabel(item.status!)
                : (_hasText(order.status)
                      ? AppDisplay.apiLabel(order.status!)
                      : pending),
          ],
  ];

  return PrintFormTemplate.table(
    headers: <String>[
      l10n.labTestNameLabel,
      l10n.labResultColumnLabel,
      l10n.labReportRangeLabel,
      l10n.labResultFlagLabel,
      l10n.opdStatusColumnLabel,
    ],
    rows: rows,
    emptyText: l10n.reportSectionEmptyDisabledReason,
  );
}

String _labTestLabel(ClinicalRelatedRecord order, ClinicalLabOrderItem item) {
  final String? panel = item.panelTitle;
  if (panel == null || panel.isEmpty) {
    return item.displayTitle;
  }
  return '$panel · ${item.displayTitle}';
}

/// Print-friendly lab result line, e.g.
/// `Hemoglobin: 12.5 g/dL · Ref 12.0–15.0 · Normal`
@visibleForTesting
String clinicalLabResultPrintLine(
  AppLocalizations l10n,
  ClinicalLabOrderItem item, {
  required String pendingLabel,
}) {
  final String result = _labResultValueLabel(item, pendingLabel);
  final String? range = item.displayReferenceRange;
  final String? flag = item.effectiveResultFlag;
  return AppDisplay.joinNonEmpty(<String?>[
    '${item.displayTitle}: $result',
    if (_hasText(range)) '${l10n.labReportRangeLabel}: $range',
    if (_hasText(flag)) AppDisplay.apiLabel(flag!),
    if (_hasText(item.status)) AppDisplay.apiLabel(item.status!),
  ], separator: ' · ');
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
