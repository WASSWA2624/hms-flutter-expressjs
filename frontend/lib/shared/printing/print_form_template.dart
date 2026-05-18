import 'package:flutter/foundation.dart';
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
    DateTime? printedAt,
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
    final List<PrintFormMetadataItem> effectiveMetadata =
        <PrintFormMetadataItem>[
          PrintFormMetadataItem(
            label: 'Printed',
            value: AppFormatters.dateTime(
              effectivePrintedAt,
              Localizations.localeOf(context),
            ),
          ),
          ...metadata,
        ].where((PrintFormMetadataItem item) => item.hasValue).toList();

    final List<PrintFormPage> effectivePages = pages.isEmpty
        ? <PrintFormPage>[PrintFormPage(bodyHtml: bodyHtml ?? '')]
        : pages;
    final int totalPages = effectivePages.length;
    final bool explicitPages = effectivePages.length > 1;

    return '''
${_style(explicitPages: explicitPages)}
<main class="print-template-document${explicitPages ? ' print-template-document--paged' : ''}">
  ${effectivePages.asMap().entries.map((MapEntry<int, PrintFormPage> entry) {
      final int pageNumber = entry.key + 1;
      final PrintFormPage page = entry.value;
      return _page(
        branding: branding,
        title: page.title ?? title,
        subtitle: subtitle,
        metadata: effectiveMetadata,
        bodyHtml: page.bodyHtml,
        pageNumber: pageNumber,
        totalPages: totalPages,
        footerNote: footerNote,
        explicitPages: explicitPages,
      );
    }).join()}
</main>
''';
  }

  static String section({
    required String title,
    required String bodyHtml,
    bool avoidPageBreak = true,
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

  static String _page({
    required PrintFormBranding branding,
    required String title,
    required String? subtitle,
    required List<PrintFormMetadataItem> metadata,
    required String bodyHtml,
    required int pageNumber,
    required int totalPages,
    required String? footerNote,
    required bool explicitPages,
  }) {
    return '''
<article class="print-template-page">
  ${_header(branding)}
  <section class="print-template-title">
    <div>
      <h1>${escape(title)}</h1>
      ${_optionalText(subtitle, 'p', 'print-template-subtitle')}
    </div>
    ${_metadata(metadata)}
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

  static String _header(PrintFormBranding branding) {
    final String? logoUrl = _normalizedImageUrl(branding.logoUrl);
    final List<String> contacts = _normalizedLines(branding.contacts);
    final List<String> addressLines = _normalizedLines(branding.addressLines);
    final List<String> details = _normalizedLines(branding.details);
    final List<String> secondaryLines = <String>[
      ...contacts,
      ...addressLines,
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

  static String _style({required bool explicitPages}) {
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
    min-height: 297mm;
    background: #fff;
    padding: 14mm 14mm 18mm;
    position: relative;
  }
  .print-template-document--paged .print-template-page {
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
    border-top: 1px solid #111827;
    padding-top: 2mm;
    min-height: 10mm;
  }
  .print-template-footer {
    position: absolute;
    bottom: 7mm;
    left: 14mm;
    right: 14mm;
    border-top: 1px solid #d1d5db;
    color: #374151;
    display: flex;
    justify-content: space-between;
    gap: 5mm;
    padding-top: 2mm;
    font-size: 10px;
  }
  ${explicitPages ? '' : '.print-template-footer span:last-child::after { content: "Page " counter(page) " of " counter(pages); }'}
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
      min-height: auto;
      margin: 0;
      padding: 0;
      box-shadow: none;
    }
    ${explicitPages ? '' : '.print-template-footer { position: fixed; bottom: -11mm; left: 0; right: 0; }'}
  }
</style>
''';
  }
}

String printHtmlEscape(String value) {
  return PrintFormTemplate.escape(value);
}
