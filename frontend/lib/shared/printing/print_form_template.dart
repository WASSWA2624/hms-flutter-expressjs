import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';

enum PrintFormBrandingKind { facility, app }

@immutable
final class PrintFormMetadataItem {
  const PrintFormMetadataItem({required this.label, required this.value});

  final String label;
  final String value;

  bool get hasValue => label.trim().isNotEmpty && value.trim().isNotEmpty;
}

@immutable
final class PrintFormPatientContext {
  const PrintFormPatientContext({
    required this.patientNameLabel,
    required this.patientName,
    this.patientIdLabel,
    this.patientId,
    this.encounterIdLabel,
    this.encounterId,
  });

  final String patientNameLabel;
  final String patientName;
  final String? patientIdLabel;
  final String? patientId;
  final String? encounterIdLabel;
  final String? encounterId;

  List<PrintFormMetadataItem> get items {
    return <PrintFormMetadataItem>[
          PrintFormMetadataItem(label: patientNameLabel, value: patientName),
          if (patientIdLabel != null && patientId != null)
            PrintFormMetadataItem(label: patientIdLabel!, value: patientId!),
          if (encounterIdLabel != null && encounterId != null)
            PrintFormMetadataItem(
              label: encounterIdLabel!,
              value: encounterId!,
            ),
        ]
        .where((PrintFormMetadataItem item) => item.hasValue)
        .toList(growable: false);
  }

  String inlineText() {
    return items
        .map((PrintFormMetadataItem item) => '${item.label}: ${item.value}')
        .join(', ');
  }

  bool get hasCompactHeader =>
      patientName.trim().isNotEmpty || (patientId?.trim().isNotEmpty ?? false);
}

@immutable
final class PrintFormContextReference {
  const PrintFormContextReference({required this.label, required this.value});

  final String label;
  final String value;

  bool get hasValue => label.trim().isNotEmpty && value.trim().isNotEmpty;
}

@immutable
final class PrintFormSignatures {
  const PrintFormSignatures({
    required this.printedByLabel,
    required this.verifiedByLabel,
    this.printedByName,
    this.verifiedByName,
    this.signatureStampLabel,
  });

  final String printedByLabel;
  final String verifiedByLabel;
  final String? printedByName;
  final String? verifiedByName;
  final String? signatureStampLabel;
}

@immutable
final class PrintFormBranding {
  const PrintFormBranding({
    required this.name,
    required this.kind,
    this.logoUrl,
    this.contacts = const <String>[],
    this.addressLines = const <String>[],
    this.details = const <String>[],
    this.isSubscribed = true,
  });

  final String name;
  final PrintFormBrandingKind kind;
  final String? logoUrl;
  final List<String> contacts;
  final List<String> addressLines;
  final List<String> details;
  final bool isSubscribed;

  bool get canBrandDocument => isSubscribed && name.trim().isNotEmpty;
}

@immutable
final class PrintFormPage {
  const PrintFormPage({required this.bodyHtml, this.title});

  final String bodyHtml;
  final String? title;
}

abstract final class PrintFormTemplate {
  static String build({
    required BuildContext context,
    required String title,
    required PrintFormBranding appBranding,
    PrintFormBranding? facilityBranding,
    String? subtitle,
    String? bodyHtml,
    List<PrintFormPage> pages = const <PrintFormPage>[],
    List<PrintFormMetadataItem> metadata = const <PrintFormMetadataItem>[],
    PrintFormPatientContext? patientContext,
    PrintFormContextReference? contextReference,
    PrintFormSignatures? signatures,
    DateTime? printedAt,
    String printedLabel = 'Printed',
    String printedOnLabel = 'Printed on',
    String printedAtLabel = 'Printed at',
    String? footerNote,
  }) {
    assert(
      bodyHtml != null || pages.isNotEmpty,
      'PrintFormTemplate requires bodyHtml or at least one page.',
    );

    final DateTime effectivePrintedAt = printedAt ?? DateTime.now();
    final PrintFormBranding branding =
        facilityBranding?.canBrandDocument == true
        ? facilityBranding!
        : appBranding;
    final bool useStandardLayout =
        patientContext != null ||
        contextReference != null ||
        signatures != null;
    final List<PrintFormMetadataItem> printedMetadata = <PrintFormMetadataItem>[
      PrintFormMetadataItem(
        label: printedLabel,
        value: AppFormatters.dateTime(
          effectivePrintedAt,
          Localizations.localeOf(context),
        ),
      ),
    ];
    final List<PrintFormMetadataItem> effectiveMetadata = useStandardLayout
        ? printedMetadata
        : <PrintFormMetadataItem>[
            ...printedMetadata,
            ...metadata,
          ].where((PrintFormMetadataItem item) => item.hasValue).toList();

    final List<PrintFormPage> sourcePages = pages.isEmpty
        ? <PrintFormPage>[PrintFormPage(bodyHtml: bodyHtml ?? '')]
        : pages;
    final List<PrintFormPage> effectivePages = sourcePages.length <= 1
        ? sourcePages
        : sourcePages.where(_hasRenderableContent).toList(growable: false);
    final int totalPages = effectivePages.length;
    final bool explicitPages = effectivePages.length > 1;
    final String renderedPages = effectivePages.asMap().entries.map((
      MapEntry<int, PrintFormPage> entry,
    ) {
      final int pageNumber = entry.key + 1;
      final PrintFormPage page = entry.value;
      return useStandardLayout
          ? _standardPage(
              context: context,
              branding: branding,
              title: page.title ?? title,
              subtitle: subtitle,
              patientContext: patientContext,
              contextReference: contextReference,
              printedAt: effectivePrintedAt,
              printedOnLabel: printedOnLabel,
              printedAtLabel: printedAtLabel,
              bodyHtml: page.bodyHtml,
              signatures: pageNumber == totalPages ? signatures : null,
              pageNumber: pageNumber,
              totalPages: totalPages,
              footerNote: footerNote,
              explicitPages: explicitPages,
            )
          : _legacyPage(
              branding: branding,
              title: page.title ?? title,
              subtitle: subtitle,
              metadata: effectiveMetadata,
              bodyHtml: page.bodyHtml,
              pageNumber: pageNumber,
              totalPages: totalPages,
              footerNote: footerNote,
              explicitPages: explicitPages,
              showHeader: pageNumber == 1,
              showMetadata: !explicitPages || pageNumber == 1,
            );
    }).join();

    return '''
${_style(explicitPages: explicitPages, useStandardLayout: useStandardLayout)}
<main class="print-template-document${explicitPages ? ' print-template-document--paged' : ''}">
$renderedPages
</main>
''';
  }

  static String section({
    required String title,
    required String bodyHtml,
    bool avoidPageBreak = false,
  }) {
    return '''
<section class="print-template-section${avoidPageBreak ? ' print-template-section--avoid-break' : ''}">
  <h2>${escape(title)}</h2>
  $bodyHtml
</section>
''';
  }

  static String keyValueGrid(Iterable<PrintFormMetadataItem> items) {
    final String rows = items
        .where((PrintFormMetadataItem item) => item.hasValue)
        .map((PrintFormMetadataItem item) {
          return '''
  <div class="print-template-kv-item">
    <dt>${escape(item.label)}</dt>
    <dd>${escape(item.value)}</dd>
  </div>
''';
        })
        .join();

    if (rows.isEmpty) {
      return '';
    }

    return '<dl class="print-template-kv">$rows</dl>';
  }

  static String signatures({
    required String printedByLabel,
    required String verifiedByLabel,
    String? printedByName,
    String? verifiedByName,
    String? signatureStampLabel,
  }) {
    return '''
<div class="print-template-signatures">
  ${_signatureBlock(printedByLabel, printedByName, signatureStampLabel)}
  ${_signatureBlock(verifiedByLabel, verifiedByName, signatureStampLabel)}
</div>
''';
  }

  static String unorderedList(
    Iterable<String> items, {
    required String emptyText,
  }) {
    final List<String> values = items
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (values.isEmpty) {
      return '<p class="print-template-empty">${escape(emptyText)}</p>';
    }

    return '''
<ul class="print-template-list">
  ${values.map((String value) => '<li>${escape(value)}</li>').join()}
</ul>
''';
  }

  static String table({
    required List<String> headers,
    required List<List<String>> rows,
    required String emptyText,
  }) {
    if (headers.isEmpty) {
      return '<p class="print-template-empty">${escape(emptyText)}</p>';
    }
    if (rows.isEmpty) {
      return '<p class="print-template-empty">${escape(emptyText)}</p>';
    }

    return '''
<table class="print-template-table">
  <thead>
    <tr>${headers.map((String header) => '<th>${escape(header)}</th>').join()}</tr>
  </thead>
  <tbody>
    ${rows.map((List<String> row) {
      return '<tr>${row.map((String cell) => '<td>${escape(cell)}</td>').join()}</tr>';
    }).join()}
  </tbody>
</table>
''';
  }

  static String escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _standardPage({
    required BuildContext context,
    required PrintFormBranding branding,
    required String title,
    required String? subtitle,
    required PrintFormPatientContext? patientContext,
    required PrintFormContextReference? contextReference,
    required DateTime printedAt,
    required String printedOnLabel,
    required String printedAtLabel,
    required String bodyHtml,
    required PrintFormSignatures? signatures,
    required int pageNumber,
    required int totalPages,
    required String? footerNote,
    required bool explicitPages,
  }) {
    final bool isFirstPage = pageNumber == 1;
    final String pageBody = '''
  ${isFirstPage ? _header(branding) : _compactHeader(patientContext)}
  ${isFirstPage ? _patientContextSection(patientContext) : ''}
  <section class="print-template-title print-template-title--standard">
    <h1>${escape(title)}</h1>
    ${_optionalText(subtitle, 'p', 'print-template-subtitle')}
    ${isFirstPage ? _titleMetaRow(context: context, contextReference: contextReference, printedAt: printedAt, printedOnLabel: printedOnLabel, printedAtLabel: printedAtLabel) : ''}
  </section>
  <section class="print-template-content">
    $bodyHtml
  </section>
''';
    final String pageFooter = '''
  <footer class="print-template-footer">
    <span>${escape(footerNote ?? '')}</span>
    <span>${explicitPages ? 'Page $pageNumber of $totalPages' : ''}</span>
  </footer>
''';

    if (signatures != null) {
      return '''
<article class="print-template-page print-template-page--anchored-footer">
  <div class="print-template-page-body">
$pageBody
  </div>
  <div class="print-template-page-bottom">
    ${_renderSignatures(signatures)}
$pageFooter
  </div>
</article>
''';
    }

    return '''
<article class="print-template-page">
$pageBody
$pageFooter
</article>
''';
  }

  static String _legacyPage({
    required PrintFormBranding branding,
    required String title,
    required String? subtitle,
    required List<PrintFormMetadataItem> metadata,
    required String bodyHtml,
    required int pageNumber,
    required int totalPages,
    required String? footerNote,
    required bool explicitPages,
    required bool showHeader,
    required bool showMetadata,
  }) {
    return '''
<article class="print-template-page">
  ${showHeader ? _header(branding) : ''}
  <section class="print-template-title">
    <div>
      <h1>${escape(title)}</h1>
      ${_optionalText(subtitle, 'p', 'print-template-subtitle')}
    </div>
    ${showMetadata ? _metadata(metadata) : ''}
  </section>
  <section class="print-template-content">
    $bodyHtml
  </section>
  <footer class="print-template-footer">
    <span>${escape(footerNote ?? '')}</span>
    <span>${explicitPages ? 'Page $pageNumber of $totalPages' : ''}</span>
  </footer>
</article>
''';
  }

  static String _patientContextSection(
    PrintFormPatientContext? patientContext,
  ) {
    if (patientContext == null) {
      return '';
    }

    final String inlineText = patientContext.inlineText().trim();
    if (inlineText.isEmpty) {
      return '';
    }

    return '''
<section class="print-template-patient-context">
  <p class="print-template-patient-inline">${escape(inlineText)}</p>
</section>
''';
  }

  static String _titleMetaRow({
    required BuildContext context,
    required PrintFormContextReference? contextReference,
    required DateTime printedAt,
    required String printedOnLabel,
    required String printedAtLabel,
  }) {
    final Locale locale = Localizations.localeOf(context);
    final List<String> parts = <String>[
      if (contextReference != null && contextReference.hasValue)
        '${contextReference.label}: ${contextReference.value}',
      '$printedOnLabel: ${AppFormatters.mediumDate(printedAt, locale)}',
      '$printedAtLabel: ${AppFormatters.time(printedAt, locale)}',
    ];

    return '''
<p class="print-template-title-meta">${escape(parts.join(', '))}</p>
''';
  }

  static String _compactHeader(PrintFormPatientContext? patientContext) {
    if (patientContext == null || !patientContext.hasCompactHeader) {
      return '';
    }

    final String name = patientContext.patientName.trim();
    final String? patientId = patientContext.patientId?.trim();
    return '''
<section class="print-template-compact-header">
  ${name.isEmpty ? '' : '<strong>${escape(name)}</strong>'}
  ${patientId == null || patientId.isEmpty ? '' : '<span>${escape(patientId)}</span>'}
</section>
''';
  }

  static String _renderSignatures(PrintFormSignatures value) {
    return PrintFormTemplate.signatures(
      printedByLabel: value.printedByLabel,
      verifiedByLabel: value.verifiedByLabel,
      printedByName: value.printedByName,
      verifiedByName: value.verifiedByName,
      signatureStampLabel: value.signatureStampLabel,
    );
  }

  static String _signatureBlock(
    String label,
    String? name,
    String? stampLabel,
  ) {
    final String normalizedName = name?.trim() ?? '';
    final String stampLine = stampLabel == null || stampLabel.trim().isEmpty
        ? '<div class="print-template-signature-stamp"></div>'
        : '<div class="print-template-signature-stamp">${escape(stampLabel.trim())}</div>';

    return '''
<div class="print-template-signature">
  <div class="print-template-signature-label">${escape(label)}</div>
  <div class="print-template-signature-name">${escape(normalizedName)}</div>
  $stampLine
</div>
''';
  }

  static String _header(PrintFormBranding branding) {
    final String? logoUrl = _normalizedImageUrl(branding.logoUrl);
    final List<String> contacts = _normalizedLines(branding.contacts);
    final List<String> addressLines = _normalizedLines(branding.addressLines);
    final List<String> details = _normalizedLines(branding.details);
    final String? addressLine = addressLines.isEmpty
        ? null
        : addressLines.join(', ');
    final String? contactLine = contacts.isEmpty ? null : contacts.join(', ');
    final List<String> secondaryLines = <String>[
      ?addressLine,
      ?contactLine,
      ...details,
    ];

    return '''
<header class="print-template-header">
  <div class="print-template-logo">
    ${logoUrl == null ? '<span>${escape(_initials(branding.name))}</span>' : '<img src="${escape(logoUrl)}" alt="${escape(branding.name)} logo">'}
  </div>
  <div class="print-template-brand">
    <strong>${escape(branding.name)}</strong>
    ${secondaryLines.map((String line) => '<span>${escape(line)}</span>').join()}
  </div>
</header>
''';
  }

  static String _metadata(List<PrintFormMetadataItem> metadata) {
    if (metadata.isEmpty) {
      return '';
    }

    return '''
<dl class="print-template-metadata">
  ${metadata.map((PrintFormMetadataItem item) {
      return '<div><dt>${escape(item.label)}</dt><dd>${escape(item.value)}</dd></div>';
    }).join()}
</dl>
''';
  }

  static String _optionalText(String? value, String tag, String className) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return '';
    }

    return '<$tag class="$className">${escape(normalized)}</$tag>';
  }

  static List<String> _normalizedLines(Iterable<String> values) {
    return values
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static String? _normalizedImageUrl(String? value) {
    final String? normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (normalized.startsWith('assets/') &&
        !normalized.startsWith('assets/assets/')) {
      return 'assets/$normalized';
    }

    return normalized;
  }

  static String _initials(String value) {
    final List<String> words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      return 'H';
    }
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }

    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }

  static String _style({
    required bool explicitPages,
    required bool useStandardLayout,
  }) {
    final String standardLayoutStyles = useStandardLayout
        ? '''
  .print-template-patient-context {
    margin-bottom: 4mm;
  }
  .print-template-patient-inline {
    color: #111827;
    font-size: 11px;
    font-weight: 700;
    margin: 0;
  }
  .print-template-title--standard {
    display: block;
    margin-bottom: 5mm;
  }
  .print-template-title--standard h1 {
    margin: 0 0 2mm;
  }
  .print-template-title-meta {
    color: #374151;
    font-size: 10.5px;
    font-weight: 700;
    margin: 0;
  }
  .print-template-compact-header {
    border-bottom: 1px solid #d1d5db;
    display: flex;
    flex-wrap: wrap;
    gap: 4mm;
    margin-bottom: 4mm;
    padding-bottom: 2mm;
  }
  .print-template-compact-header strong {
    font-size: 12px;
  }
  .print-template-compact-header span {
    color: #374151;
    font-size: 11px;
  }
  .print-template-page--anchored-footer {
    display: flex;
    flex-direction: column;
    min-height: 265mm;
  }
  .print-template-page-body {
    flex: 1 1 auto;
  }
  .print-template-page-bottom {
    break-inside: avoid;
    flex: 0 0 auto;
    margin-top: auto;
    page-break-inside: avoid;
  }
  .print-template-page-bottom .print-template-footer {
    margin-top: 4mm;
  }
  .print-template-signature-label {
    color: #4b5563;
    font-size: 9px;
    font-weight: 700;
    margin-bottom: 2mm;
    text-transform: uppercase;
  }
  .print-template-signature-name {
    font-weight: 700;
    margin-bottom: 10mm;
    min-height: 6mm;
  }
  .print-template-signature-stamp {
    border-top: 1px solid #111827;
    color: #6b7280;
    font-size: 9px;
    min-height: 14mm;
    padding-top: 2mm;
  }
  .print-template-signatures {
    break-inside: avoid;
    display: flex;
    flex-wrap: nowrap;
    gap: 20mm;
    margin-top: 0;
    page-break-inside: avoid;
  }
  .print-template-signatures .print-template-signature {
    display: flex;
    flex: 1 1 0;
    flex-direction: column;
    min-width: 0;
  }
'''
        : '';

    return '''
<style>
  @page {
    size: A4;
    margin: 14mm 14mm 18mm;
  }
  * { box-sizing: border-box; }
  html, body {
    margin: 0;
    padding: 0;
    color: #111827;
    background: #f3f4f6;
    font-family: Arial, Helvetica, sans-serif;
    font-size: 11px;
    line-height: 1.42;
  }
  .print-template-document {
    width: 210mm;
    margin: 0 auto;
  }
  .print-template-page {
    background: #fff;
    padding: 14mm 14mm 18mm;
  }
  .print-template-document--paged .print-template-page {
    break-after: page;
    page-break-after: always;
  }
  .print-template-document--paged .print-template-page:last-child {
    page-break-after: auto;
  }
  .print-template-header {
    display: grid;
    grid-template-columns: 22mm 1fr;
    gap: 5mm;
    align-items: center;
    border-bottom: 2px solid #111827;
    padding-bottom: 4mm;
    margin-bottom: 5mm;
  }
  .print-template-logo {
    width: 22mm;
    height: 22mm;
    border: 1px solid #9ca3af;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    color: #111827;
    font-size: 15px;
    font-weight: 800;
  }
  .print-template-logo img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    display: block;
  }
  .print-template-brand strong {
    display: block;
    font-size: 18px;
    line-height: 1.15;
    margin-bottom: 2mm;
  }
  .print-template-brand span {
    display: block;
    color: #374151;
    font-size: 10.5px;
  }
  .print-template-title {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(62mm, 78mm);
    gap: 8mm;
    align-items: start;
    margin-bottom: 5mm;
  }
  .print-template-title h1 {
    margin: 0;
    font-size: 22px;
    line-height: 1.15;
  }
  .print-template-subtitle {
    margin: 2mm 0 0;
    color: #374151;
  }
  .print-template-metadata {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 2mm 4mm;
    margin: 0;
  }
  .print-template-metadata div,
  .print-template-kv-item {
    border: 1px solid #d1d5db;
    padding: 2mm;
    min-width: 0;
  }
  .print-template-metadata dt,
  .print-template-kv dt {
    color: #4b5563;
    font-size: 9px;
    font-weight: 700;
    margin: 0 0 1mm;
    text-transform: uppercase;
  }
  .print-template-metadata dd,
  .print-template-kv dd {
    margin: 0;
    font-weight: 700;
    overflow-wrap: anywhere;
  }
  .print-template-content {
    padding-bottom: 8mm;
  }
  .print-template-section {
    margin: 0 0 5mm;
  }
  .print-template-section--avoid-break {
    break-inside: avoid;
    page-break-inside: avoid;
  }
  .print-template-section h2 {
    border-bottom: 1px solid #d1d5db;
    color: #111827;
    font-size: 13px;
    line-height: 1.25;
    margin: 0 0 2.5mm;
    padding-bottom: 1.5mm;
    text-transform: uppercase;
  }
  .print-template-kv {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 2mm;
    margin: 0;
  }
  .print-template-list {
    margin: 0;
    padding-left: 5mm;
  }
  .print-template-list li {
    margin-bottom: 1.4mm;
  }
  .print-template-table {
    border-collapse: collapse;
    width: 100%;
  }
  .print-template-table th,
  .print-template-table td {
    border: 1px solid #d1d5db;
    padding: 2mm;
    text-align: left;
    vertical-align: top;
  }
  .print-template-table th {
    background: #f3f4f6;
    font-weight: 800;
  }
  .print-template-empty {
    color: #6b7280;
    margin: 0;
  }
  .print-template-note {
    white-space: pre-wrap;
  }
  .print-template-signatures {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 16mm;
    margin-top: 18mm;
  }
  .print-template-signature {
    min-height: 10mm;
  }
  .print-template-footer {
    border-top: 1px solid #d1d5db;
    color: #374151;
    display: flex;
    justify-content: space-between;
    gap: 5mm;
    padding-top: 2mm;
    margin-top: 8mm;
    font-size: 10px;
  }
  $standardLayoutStyles
  @media screen {
    body { padding: 8mm 0; }
    .print-template-page {
      box-shadow: 0 8px 28px rgba(17, 24, 39, 0.12);
      margin-bottom: 8mm;
    }
  }
  @media print {
    html, body { background: #fff; }
    .print-template-document {
      width: auto;
      margin: 0;
    }
    .print-template-page {
      margin: 0;
      padding: 0;
      box-shadow: none;
    }
    .print-template-page--anchored-footer {
      min-height: 100%;
    }
  }
</style>
''';
  }

  static bool _hasRenderableContent(PrintFormPage page) {
    final String withoutStyle = page.bodyHtml.replaceAll(
      RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
      '',
    );
    final String withoutMarkup = withoutStyle
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();

    return withoutMarkup.isNotEmpty;
  }
}

String printHtmlEscape(String value) {
  return PrintFormTemplate.escape(value);
}
