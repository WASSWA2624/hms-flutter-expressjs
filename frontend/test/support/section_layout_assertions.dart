import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/layout/app_screen_section.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Returns true when [widget] is titled section chrome per billing-and-sections rules.
bool isTitledSectionWidget(Widget widget) {
  if (widget is AppScreenSection) {
    return true;
  }
  if (widget is AppWorkspaceDetailPanel) {
    return true;
  }
  if (widget is AppSectionPanel) {
    return widget.title?.trim().isNotEmpty == true;
  }
  return false;
}

/// Asserts no titled section contains another titled section in its subtree.
void expectFlatSections(WidgetTester tester, {Finder? root}) {
  final Finder scope = root ?? find.byType(MaterialApp);
  expect(scope, findsOneWidget);

  final List<Element> sections = <Element>[];
  void collectSections(Element element) {
    if (isTitledSectionWidget(element.widget)) {
      sections.add(element);
    }
    element.visitChildren(collectSections);
  }

  final Element rootElement = tester.element(scope);
  collectSections(rootElement);

  for (final Element section in sections) {
    final List<Element> nested = <Element>[];
    void findNested(Element element) {
      if (element != section && isTitledSectionWidget(element.widget)) {
        nested.add(element);
      }
      element.visitChildren(findNested);
    }

    section.visitChildren(findNested);
    expect(
      nested,
      isEmpty,
      reason:
          'Section ${section.widget.runtimeType} must not contain nested sections '
          '(found ${nested.length}).',
    );
  }
}

/// Counts titled section widgets under [root].
int countTitledSections(WidgetTester tester, {Finder? root}) {
  final Finder scope = root ?? find.byType(MaterialApp);
  int count = 0;
  void visitor(Element element) {
    if (isTitledSectionWidget(element.widget)) {
      count += 1;
    }
    element.visitChildren(visitor);
  }

  tester.element(scope).visitChildren(visitor);
  return count;
}
