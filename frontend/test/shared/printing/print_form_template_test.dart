import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

void main() {
  testWidgets('falls back to app branding when facility is unavailable', (
    tester,
  ) async {
    late String html;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            html = PrintFormTemplate.build(
              context: context,
              title: 'Patient statement',
              appBranding: const PrintFormBranding(
                name: 'HOSSPI',
                kind: PrintFormBrandingKind.app,
                logoUrl: 'assets/logos/logo.png',
                contacts: <String>['Email: admin@example.com'],
              ),
              facilityBranding: const PrintFormBranding(
                name: 'Inactive Facility',
                kind: PrintFormBrandingKind.facility,
                isSubscribed: false,
              ),
              bodyHtml: '<p>Body</p>',
              printedAt: DateTime.utc(2026, 1, 2, 3, 4),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(html, contains('HOSSPI'));
    expect(html, contains('Email: admin@example.com'));
    expect(html, isNot(contains('Inactive Facility')));
    expect(html, contains('Patient statement'));
    expect(
      html,
      isNot(
        contains(
          '<main class="print-template-document print-template-document--paged">',
        ),
      ),
    );
    expect(html, isNot(contains('counter(pages)')));
  });

  testWidgets('renders explicit multi-page numbering', (tester) async {
    late String html;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            html = PrintFormTemplate.build(
              context: context,
              title: 'Patient report',
              appBranding: const PrintFormBranding(
                name: 'HOSSPI',
                kind: PrintFormBrandingKind.app,
              ),
              facilityBranding: const PrintFormBranding(
                name: 'Subscribed Facility',
                kind: PrintFormBrandingKind.facility,
              ),
              pages: const <PrintFormPage>[
                PrintFormPage(bodyHtml: '<p>First</p>'),
                PrintFormPage(bodyHtml: '<p>Second</p>'),
              ],
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(html, contains('Subscribed Facility'));
    expect(html, contains('Page 1 of 2'));
    expect(html, contains('Page 2 of 2'));
  });

  testWidgets('drops empty explicit pages instead of printing blanks', (
    tester,
  ) async {
    late String html;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            html = PrintFormTemplate.build(
              context: context,
              title: 'Consultation summary',
              appBranding: const PrintFormBranding(
                name: 'HOSSPI',
                kind: PrintFormBrandingKind.app,
              ),
              pages: const <PrintFormPage>[
                PrintFormPage(bodyHtml: '<p>Clinical notes</p>'),
                PrintFormPage(bodyHtml: '<style>.x{color:red;}</style>'),
              ],
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(html, contains('Clinical notes'));
    expect(html, isNot(contains('Page 1 of 2')));
    expect(html, isNot(contains('Page 2 of 2')));
  });
}
