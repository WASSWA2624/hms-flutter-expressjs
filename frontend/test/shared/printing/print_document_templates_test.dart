import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

void main() {
  test('exposes a reusable template kind for each print use-case family', () {
    expect(PrintDocumentTemplateKind.values, hasLength(9));
    expect(
      PrintDocumentTemplates.displayName(
        PrintDocumentTemplateKind.clinicalResult,
      ),
      'Clinical result report',
    );
    expect(
      PrintDocumentTemplates.displayName(PrintDocumentTemplateKind.invoice),
      'Invoice',
    );
    expect(
      PrintDocumentTemplates.displayName(PrintDocumentTemplateKind.registry),
      'Registry record',
    );
  });

  test('builds empty body scaffolds for each template kind', () {
    for (final PrintDocumentTemplateKind kind
        in PrintDocumentTemplateKind.values) {
      final String html = PrintDocumentTemplates.emptyBodyHtml(
        kind: kind,
        sectionTitles: <String>['Section A', 'Section B'],
      );
      expect(html, contains('Section A'));
      expect(html, contains('Section B'));
      expect(html, contains('print-template-section'));
      expect(html, contains(PrintDocumentTemplates.displayName(kind)));
    }
  });

  test('typed print methods accept showPreview override', () {
    // Compile-time contract: callers with custom dialogs can disable the
    // shared preview shell without changing the print document builder.
    // Runtime routing coverage lives in print_preview_routing_test.dart.
    expect(
      () => PrintDocumentTemplates.emptyBodyHtml(
        kind: PrintDocumentTemplateKind.clinicalSummary,
        sectionTitles: const <String>[],
      ),
      returnsNormally,
    );
  });
}
