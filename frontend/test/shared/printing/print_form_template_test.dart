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
              patientContext: const PrintFormPatientContext(
                patientNameLabel: 'Patient name',
                patientName: 'Jane Doe',
                patientIdLabel: 'Patient ID',
                patientId: 'PAT0000001',
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
    expect(_occurrences(html, '<strong>Subscribed Facility</strong>'), 1);
    expect(html, contains('Jane Doe'));
    expect(html, contains('PAT0000001'));
    expect(html, contains('print-template-compact-header'));
    expect(html, contains('Page 1 of 2'));
    expect(html, contains('Page 2 of 2'));
  });

  testWidgets('renders signatures only on the last page', (tester) async {
    late String html;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            html = PrintFormTemplate.build(
              context: context,
              title: 'Laboratory result report',
              appBranding: const PrintFormBranding(
                name: 'HOSSPI',
                kind: PrintFormBrandingKind.app,
              ),
              patientContext: const PrintFormPatientContext(
                patientNameLabel: 'Patient name',
                patientName: 'Joshua Evans',
                patientIdLabel: 'Patient ID',
                patientId: 'PAT0000002',
                encounterIdLabel: 'Encounter ID',
                encounterId: 'ENC0000002',
              ),
              contextReference: const PrintFormContextReference(
                label: 'Lab order',
                value: 'LAB0000006',
              ),
              signatures: const PrintFormSignatures(
                printedByLabel: 'Printed by',
                verifiedByLabel: 'Verified by',
                printedByName: 'Lab Tech',
                signatureStampLabel: 'Signature / stamp',
              ),
              printedAt: DateTime(2026, 7, 4, 16, 1),
              pages: const <PrintFormPage>[
                PrintFormPage(bodyHtml: '<p>First page</p>'),
                PrintFormPage(bodyHtml: '<p>Second page</p>'),
              ],
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(html, contains('print-template-patient-inline'));
    expect(html, contains('Patient name: Joshua Evans'));
    expect(html, contains('print-template-title-meta'));
    expect(html, contains('Lab order: LAB0000006'));
    expect(html, contains('Printed on:'));
    expect(html, contains('Printed at:'));
    expect(html, isNot(contains('<div class="print-template-kv-item">')));
    expect(html, contains('Printed by'));
    expect(html, contains('Lab Tech'));
    expect(_occurrences(html, '<div class="print-template-signatures">'), 1);
  });

  testWidgets('renders facility header with address before contacts', (
    tester,
  ) async {
    late String html;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            html = PrintFormTemplate.build(
              context: context,
              title: 'Laboratory result report',
              appBranding: const PrintFormBranding(
                name: 'HOSSPI',
                kind: PrintFormBrandingKind.app,
              ),
              facilityBranding: const PrintFormBranding(
                name: 'DemoCare General Hospital',
                kind: PrintFormBrandingKind.facility,
                contacts: <String>[
                  'Phone: +2567001000',
                  'Email: info@democare.ug',
                ],
                addressLines: <String>[
                  '1 Demo Hospital Avenue, Kampala, Uganda',
                ],
              ),
              patientContext: const PrintFormPatientContext(
                patientNameLabel: 'Patient name',
                patientName: 'Joshua Suuna',
              ),
              bodyHtml: '<p>Results</p>',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(html, contains('DemoCare General Hospital'));
    expect(html, contains('1 Demo Hospital Avenue, Kampala, Uganda'));
    expect(html, contains('Phone: +2567001000, Email: info@democare.ug'));
    expect(html, isNot(contains('Type:')));
    expect(html, isNot(contains('Tenant:')));
  });

  testWidgets('anchors signature footer and reserves name space', (
    tester,
  ) async {
    late String html;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            html = PrintFormTemplate.build(
              context: context,
              title: 'Laboratory result report',
              appBranding: const PrintFormBranding(
                name: 'HOSSPI',
                kind: PrintFormBrandingKind.app,
              ),
              patientContext: const PrintFormPatientContext(
                patientNameLabel: 'Patient name',
                patientName: 'Joshua Suuna',
              ),
              signatures: const PrintFormSignatures(
                printedByLabel: 'Printed by',
                verifiedByLabel: 'Verified by',
                printedByName: 'Platform Demo',
                signatureStampLabel: 'Signature / stamp',
              ),
              footerNote: 'Generated from laboratory workflow data.',
              bodyHtml: '<p>Short results</p>',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(html, contains('print-template-page--anchored-footer'));
    expect(html, contains('print-template-page-bottom'));
    expect(
      _occurrences(html, '<div class="print-template-signature-name">'),
      2,
    );
    expect(
      html,
      contains(
        '<div class="print-template-signature-name">Platform Demo</div>',
      ),
    );
    expect(html, contains('<div class="print-template-signature-name"></div>'));
    expect(html, contains('Generated from laboratory workflow data.'));
  });

  testWidgets('renders signature name slots when both names are empty', (
    tester,
  ) async {
    late String html;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            html = PrintFormTemplate.build(
              context: context,
              title: 'Laboratory result report',
              appBranding: const PrintFormBranding(
                name: 'HOSSPI',
                kind: PrintFormBrandingKind.app,
              ),
              signatures: const PrintFormSignatures(
                printedByLabel: 'Printed by',
                verifiedByLabel: 'Verified by',
                signatureStampLabel: 'Signature / stamp',
              ),
              bodyHtml: '<p>Short results</p>',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      _occurrences(html, '<div class="print-template-signature-name"></div>'),
      2,
    );
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

int _occurrences(String source, String pattern) {
  return pattern.allMatches(source).length;
}
