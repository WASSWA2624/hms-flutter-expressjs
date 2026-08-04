import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/printing/app_print_preview.dart';
import 'package:hosspi_hms/shared/printing/print_facility_sections.dart';
import 'package:hosspi_hms/shared/printing/print_form_template.dart';

/// Named reusable print documents built on the empty [PrintFormTemplate] chrome.
///
/// Use these instead of calling [printFormTemplateDocument] directly so each
/// product surface shares the same layout conventions (patient header, order
/// reference, signatures, footer).
enum PrintDocumentTemplateKind {
  /// Lab / radiology released results.
  clinicalResult,

  /// OPD, clinical, nursing, ICU, discharge, emergency visit/stay summaries.
  clinicalSummary,

  /// Billing invoices.
  invoice,

  /// Pharmacy medication instructions.
  medicationInstructions,

  /// Physiotherapy plans and session instructions.
  carePlan,

  /// Claims / authorization statements.
  claimStatement,

  /// Multi-page patient chart / registry report.
  patientChart,

  /// Biomedical assets and operational reports (no patient).
  registry,

  /// Mortuary case reports (deceased subject).
  mortuaryCase,
}

/// Typed print entry points that reuse the shared empty template chrome.
///
/// Every call opens [showAppPrintPreviewDialog] before printing unless
/// [showPreview] is false because the caller already embeds
/// [AppPrintPreviewPanel] / [AppPrintPreviewWorkspace].
abstract final class PrintDocumentTemplates {
  /// Clinical diagnostic result report (lab, radiology).
  static Future<void> clinicalResult({
    required WidgetRef ref,
    required BuildContext context,
    required String title,
    PrintFormPatientContext? patientContext,
    PrintFormContextReference? orderReference,
    String? subtitle,
    String? bodyHtml,
    List<PrintFormPage> pages = const <PrintFormPage>[],
    List<PrintFormMetadataItem> metadata = const <PrintFormMetadataItem>[],
    String? footerNote,
    PrintFormSignatures? signatures,
    bool includeSignatures = true,
    bool showPreview = true,
    String? previewDialogTitle,
    String? previewDialogBody,
    String? fallbackText,
    PrintFormBrandingOptions brandingOptions = PrintFormBrandingOptions.all,
  }) {
    return _print(
      kind: PrintDocumentTemplateKind.clinicalResult,
      ref: ref,
      context: context,
      title: title,
      subtitle: subtitle,
      bodyHtml: bodyHtml,
      pages: pages,
      metadata: metadata,
      patientContext: patientContext,
      contextReference: orderReference,
      signatures: signatures,
      includeSignatures: includeSignatures,
      footerNote: footerNote,
      showPreview: showPreview,
      previewDialogTitle: previewDialogTitle,
      previewDialogBody: previewDialogBody,
      fallbackText: fallbackText,
      brandingOptions: brandingOptions,
    );
  }

  /// Clinical/operational visit or stay summary.
  static Future<void> clinicalSummary({
    required WidgetRef ref,
    required BuildContext context,
    required String title,
    required PrintFormPatientContext patientContext,
    PrintFormContextReference? visitReference,
    String? subtitle,
    String? bodyHtml,
    List<PrintFormPage> pages = const <PrintFormPage>[],
    String? footerNote,
    PrintFormSignatures? signatures,
    bool includeSignatures = true,
    bool showPreview = true,
    String? previewDialogTitle,
    String? previewDialogBody,
    String? fallbackText,
    PrintFormBrandingOptions brandingOptions = PrintFormBrandingOptions.all,
  }) {
    return _print(
      kind: PrintDocumentTemplateKind.clinicalSummary,
      ref: ref,
      context: context,
      title: title,
      subtitle: subtitle,
      bodyHtml: bodyHtml,
      pages: pages,
      patientContext: patientContext,
      contextReference: visitReference,
      signatures: signatures,
      includeSignatures: includeSignatures,
      footerNote: footerNote,
      showPreview: showPreview,
      previewDialogTitle: previewDialogTitle,
      previewDialogBody: previewDialogBody,
      fallbackText: fallbackText,
      brandingOptions: brandingOptions,
    );
  }

  /// Billing invoice.
  static Future<void> invoice({
    required WidgetRef ref,
    required BuildContext context,
    required String title,
    required PrintFormPatientContext patientContext,
    required PrintFormContextReference invoiceReference,
    String? subtitle,
    required String bodyHtml,
    String? footerNote,
    bool includeSignatures = true,
    bool showPreview = true,
    String? previewDialogTitle,
    String? previewDialogBody,
    String? fallbackText,
  }) {
    return _print(
      kind: PrintDocumentTemplateKind.invoice,
      ref: ref,
      context: context,
      title: title,
      subtitle: subtitle,
      bodyHtml: bodyHtml,
      patientContext: patientContext,
      contextReference: invoiceReference,
      includeSignatures: includeSignatures,
      footerNote: footerNote,
      showPreview: showPreview,
      previewDialogTitle: previewDialogTitle,
      previewDialogBody: previewDialogBody,
      fallbackText: fallbackText,
    );
  }

  /// Pharmacy medication instructions.
  static Future<void> medicationInstructions({
    required WidgetRef ref,
    required BuildContext context,
    required String title,
    required PrintFormPatientContext patientContext,
    PrintFormContextReference? orderReference,
    required String bodyHtml,
    String? footerNote,
    bool includeSignatures = true,
    bool showPreview = true,
    String? previewDialogTitle,
    String? previewDialogBody,
    String? fallbackText,
    String Function()? bodyHtmlBuilder,
    Widget? previewSectionsExtra,
    Listenable? previewDocumentRevision,
    bool Function()? isPrintEnabled,
  }) {
    return _print(
      kind: PrintDocumentTemplateKind.medicationInstructions,
      ref: ref,
      context: context,
      title: title,
      bodyHtml: bodyHtml,
      patientContext: patientContext,
      contextReference: orderReference,
      includeSignatures: includeSignatures,
      footerNote: footerNote,
      showPreview: showPreview,
      previewDialogTitle: previewDialogTitle,
      previewDialogBody: previewDialogBody,
      fallbackText: fallbackText,
      bodyHtmlBuilder: bodyHtmlBuilder,
      previewSectionsExtra: previewSectionsExtra,
      previewDocumentRevision: previewDocumentRevision,
      isPrintEnabled: isPrintEnabled,
    );
  }

  /// Physiotherapy / rehab care plan.
  static Future<void> carePlan({
    required WidgetRef ref,
    required BuildContext context,
    required String title,
    required PrintFormPatientContext patientContext,
    PrintFormContextReference? referralReference,
    required String bodyHtml,
    String? footerNote,
    bool includeSignatures = true,
    bool showPreview = true,
    String? previewDialogTitle,
    String? previewDialogBody,
    String? fallbackText,
  }) {
    return _print(
      kind: PrintDocumentTemplateKind.carePlan,
      ref: ref,
      context: context,
      title: title,
      bodyHtml: bodyHtml,
      patientContext: patientContext,
      contextReference: referralReference,
      includeSignatures: includeSignatures,
      footerNote: footerNote,
      showPreview: showPreview,
      previewDialogTitle: previewDialogTitle,
      previewDialogBody: previewDialogBody,
      fallbackText: fallbackText,
    );
  }

  /// Claims / payer authorization statement.
  static Future<void> claimStatement({
    required WidgetRef ref,
    required BuildContext context,
    required String title,
    PrintFormPatientContext? patientContext,
    required PrintFormContextReference claimReference,
    required String bodyHtml,
    String? footerNote,
    bool includeSignatures = true,
    bool showPreview = true,
    String? previewDialogTitle,
    String? previewDialogBody,
    String? fallbackText,
  }) {
    return _print(
      kind: PrintDocumentTemplateKind.claimStatement,
      ref: ref,
      context: context,
      title: title,
      bodyHtml: bodyHtml,
      patientContext: patientContext,
      contextReference: claimReference,
      includeSignatures: includeSignatures,
      footerNote: footerNote,
      showPreview: showPreview,
      previewDialogTitle: previewDialogTitle,
      previewDialogBody: previewDialogBody,
      fallbackText: fallbackText,
    );
  }

  /// Multi-page patient chart.
  static Future<void> patientChart({
    required WidgetRef ref,
    required BuildContext context,
    required String title,
    required PrintFormPatientContext patientContext,
    String? subtitle,
    required List<PrintFormPage> pages,
    String? footerNote,
    bool includeSignatures = true,
    bool showPreview = true,
    String? previewDialogTitle,
    String? previewDialogBody,
    String? fallbackText,
    PrintFormBrandingOptions brandingOptions = PrintFormBrandingOptions.all,
  }) {
    return _print(
      kind: PrintDocumentTemplateKind.patientChart,
      ref: ref,
      context: context,
      title: title,
      subtitle: subtitle,
      pages: pages,
      patientContext: patientContext,
      includeSignatures: includeSignatures,
      footerNote: footerNote,
      showPreview: showPreview,
      previewDialogTitle: previewDialogTitle,
      previewDialogBody: previewDialogBody,
      fallbackText: fallbackText,
      brandingOptions: brandingOptions,
    );
  }

  /// Non-patient registry / operational record (assets, report catalog).
  static Future<void> registry({
    required WidgetRef ref,
    required BuildContext context,
    required String title,
    PrintFormContextReference? recordReference,
    String? subtitle,
    required String bodyHtml,
    String? footerNote,
    bool showPreview = true,
    String? previewDialogTitle,
    String? previewDialogBody,
    String? fallbackText,
  }) {
    return _print(
      kind: PrintDocumentTemplateKind.registry,
      ref: ref,
      context: context,
      title: title,
      subtitle: subtitle,
      bodyHtml: bodyHtml,
      contextReference: recordReference,
      includeSignatures: false,
      footerNote: footerNote,
      showPreview: showPreview,
      previewDialogTitle: previewDialogTitle,
      previewDialogBody: previewDialogBody,
      fallbackText: fallbackText,
    );
  }

  /// Mortuary case report.
  static Future<void> mortuaryCase({
    required WidgetRef ref,
    required BuildContext context,
    required String title,
    required PrintFormPatientContext deceasedContext,
    required PrintFormContextReference caseReference,
    required String bodyHtml,
    String? footerNote,
    bool includeSignatures = true,
    bool showPreview = true,
    String? previewDialogTitle,
    String? previewDialogBody,
    String? fallbackText,
  }) {
    return _print(
      kind: PrintDocumentTemplateKind.mortuaryCase,
      ref: ref,
      context: context,
      title: title,
      bodyHtml: bodyHtml,
      patientContext: deceasedContext,
      contextReference: caseReference,
      includeSignatures: includeSignatures,
      footerNote: footerNote,
      showPreview: showPreview,
      previewDialogTitle: previewDialogTitle,
      previewDialogBody: previewDialogBody,
      fallbackText: fallbackText,
    );
  }

  /// Builds the full print-template HTML for live previews.
  static String buildDocumentHtml({
    required PrintDocumentTemplateKind kind,
    required WidgetRef ref,
    required BuildContext context,
    required String title,
    String? subtitle,
    String? bodyHtml,
    List<PrintFormPage> pages = const <PrintFormPage>[],
    List<PrintFormMetadataItem> metadata = const <PrintFormMetadataItem>[],
    PrintFormPatientContext? patientContext,
    PrintFormContextReference? contextReference,
    PrintFormSignatures? signatures,
    bool includeSignatures = false,
    String? footerNote,
    PrintFormBrandingOptions brandingOptions = PrintFormBrandingOptions.all,
  }) {
    assert(
      bodyHtml != null || pages.isNotEmpty,
      'PrintDocumentTemplates.buildDocumentHtml requires bodyHtml or pages.',
    );
    return buildPrintFormTemplateHtml(
      ref: ref,
      context: context,
      title: title,
      subtitle: subtitle,
      bodyHtml: bodyHtml,
      pages: pages,
      metadata: metadata,
      patientContext: patientContext,
      contextReference: contextReference,
      signatures: signatures,
      includeSignatures: includeSignatures,
      footerNote:
          footerNote ?? 'Generated from ${displayName(kind).toLowerCase()}.',
      brandingOptions: brandingOptions,
    );
  }

  /// Empty body scaffold for a template kind (sample PDFs / previews).
  static String emptyBodyHtml({
    required PrintDocumentTemplateKind kind,
    required List<String> sectionTitles,
  }) {
    if (sectionTitles.isEmpty) {
      return PrintFormTemplate.section(
        title: _defaultSectionTitle(kind),
        bodyHtml:
            '<p class="print-template-empty">${PrintFormTemplate.escape(_emptyBodyHint(kind))}</p>',
      );
    }

    return sectionTitles
        .map(
          (String title) => PrintFormTemplate.section(
            title: title,
            bodyHtml:
                '<p class="print-template-empty">${PrintFormTemplate.escape(_emptyBodyHint(kind))}</p>',
          ),
        )
        .join();
  }

  static String displayName(PrintDocumentTemplateKind kind) {
    return switch (kind) {
      PrintDocumentTemplateKind.clinicalResult => 'Clinical result report',
      PrintDocumentTemplateKind.clinicalSummary => 'Clinical summary',
      PrintDocumentTemplateKind.invoice => 'Invoice',
      PrintDocumentTemplateKind.medicationInstructions =>
        'Medication instructions',
      PrintDocumentTemplateKind.carePlan => 'Care plan',
      PrintDocumentTemplateKind.claimStatement => 'Claim statement',
      PrintDocumentTemplateKind.patientChart => 'Patient chart',
      PrintDocumentTemplateKind.registry => 'Registry record',
      PrintDocumentTemplateKind.mortuaryCase => 'Mortuary case report',
    };
  }

  static String _defaultSectionTitle(PrintDocumentTemplateKind kind) {
    return switch (kind) {
      PrintDocumentTemplateKind.clinicalResult => 'Results',
      PrintDocumentTemplateKind.clinicalSummary => 'Summary',
      PrintDocumentTemplateKind.invoice => 'Line items',
      PrintDocumentTemplateKind.medicationInstructions => 'Medications',
      PrintDocumentTemplateKind.carePlan => 'Plan',
      PrintDocumentTemplateKind.claimStatement => 'Claim details',
      PrintDocumentTemplateKind.patientChart => 'Chart',
      PrintDocumentTemplateKind.registry => 'Record details',
      PrintDocumentTemplateKind.mortuaryCase => 'Case details',
    };
  }

  static String _emptyBodyHint(PrintDocumentTemplateKind kind) {
    return '${displayName(kind)} body content';
  }

  static Future<void> _print({
    required PrintDocumentTemplateKind kind,
    required WidgetRef ref,
    required BuildContext context,
    required String title,
    String? subtitle,
    String? bodyHtml,
    List<PrintFormPage> pages = const <PrintFormPage>[],
    List<PrintFormMetadataItem> metadata = const <PrintFormMetadataItem>[],
    PrintFormPatientContext? patientContext,
    PrintFormContextReference? contextReference,
    PrintFormSignatures? signatures,
    bool includeSignatures = false,
    String? footerNote,
    bool showPreview = true,
    String? previewDialogTitle,
    String? previewDialogBody,
    String? fallbackText,
    PrintFormBrandingOptions brandingOptions = PrintFormBrandingOptions.all,
    String Function()? bodyHtmlBuilder,
    Widget? previewSectionsExtra,
    Listenable? previewDocumentRevision,
    bool Function()? isPrintEnabled,
  }) async {
    assert(
      bodyHtml != null || pages.isNotEmpty || bodyHtmlBuilder != null,
      'PrintDocumentTemplates.${kind.name} requires bodyHtml, bodyHtmlBuilder, or pages.',
    );
    final String resolvedFooter =
        footerNote ?? 'Generated from ${displayName(kind).toLowerCase()}.';

    String? resolvedBodyHtml() => bodyHtmlBuilder?.call() ?? bodyHtml;

    Future<void> doPrint() {
      return printFormTemplateDocument(
        ref: ref,
        context: context,
        title: title,
        subtitle: subtitle,
        bodyHtml: resolvedBodyHtml(),
        pages: pages,
        metadata: metadata,
        patientContext: patientContext,
        contextReference: contextReference,
        signatures: signatures,
        includeSignatures: includeSignatures,
        footerNote: resolvedFooter,
        brandingOptions: brandingOptions,
      );
    }

    if (!showPreview) {
      // Caller must already embed AppPrintPreviewPanel / Workspace in its
      // own dialog. Never pass false from a flow that prints immediately.
      return doPrint();
    }

    // Prefer the fully-loaded facility branding so facility contacts, address,
    // type, and ID are available for the checkboxes and header. Falls back to
    // the sync snapshot so the preview never blocks forever.
    PrintFormTemplateContext branding;
    try {
      branding = await ref
          .read(printFormTemplateContextReadyProvider.future)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      branding = ref.read(printFormTemplateContextProvider);
    }
    if (!context.mounted) {
      return;
    }
    final PrintFormBranding facilitySectionBranding = effectivePrintBranding(
      appBranding: branding.appBranding,
      facilityBranding: branding.facilityBranding,
    );

    String htmlFor(PrintFormBrandingOptions options) {
      return buildDocumentHtml(
        kind: kind,
        ref: ref,
        context: context,
        title: title,
        subtitle: subtitle,
        bodyHtml: resolvedBodyHtml(),
        pages: pages,
        metadata: metadata,
        patientContext: patientContext,
        contextReference: contextReference,
        signatures: signatures,
        includeSignatures: includeSignatures,
        footerNote: resolvedFooter,
        brandingOptions: options,
      );
    }

    await showAppPrintPreviewDialog(
      context: context,
      title: previewDialogTitle ?? title,
      body: previewDialogBody ?? context.l10n.printPreviewDialogBody,
      documentHtml: htmlFor(brandingOptions),
      fallbackText: fallbackText ?? title,
      facilitySectionBranding: facilitySectionBranding,
      initialBrandingOptions: brandingOptions,
      documentHtmlBuilder: htmlFor,
      sectionsExtra: previewSectionsExtra,
      documentRevision: previewDocumentRevision,
      isPrintEnabled: isPrintEnabled,
      onPrint: doPrint,
      onPrintWithBranding: (PrintFormBrandingOptions options) {
        return printFormTemplateDocument(
          ref: ref,
          context: context,
          title: title,
          subtitle: subtitle,
          bodyHtml: resolvedBodyHtml(),
          pages: pages,
          metadata: metadata,
          patientContext: patientContext,
          contextReference: contextReference,
          signatures: signatures,
          includeSignatures: includeSignatures,
          footerNote: resolvedFooter,
          brandingOptions: options,
        );
      },
    );
  }
}
