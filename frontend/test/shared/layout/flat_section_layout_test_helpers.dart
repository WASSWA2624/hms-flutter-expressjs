import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/layout/app_screen_section.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Whether [widget] is titled section chrome per billing-and-sections rules.
bool isTitledSectionWidget(Widget widget) {
  if (widget is AppScreenSection) {
    return true;
  }
  if (widget is AppWorkspaceDetailPanel) {
    return widget.title?.trim().isNotEmpty == true;
  }
  if (widget is AppSectionPanel) {
    return widget.title?.trim().isNotEmpty == true;
  }
  return false;
}

/// Asserts no titled section widget contains another titled section descendant.
void expectFlatTitledSectionLayout(
  WidgetTester tester, {
  Finder? scope,
  String? contextLabel,
}) {
  final Finder root = scope ?? find.byType(MaterialApp);
  expect(root, findsWidgets);

  final List<Element> sectionRoots = <Element>[];
  for (final Element element in tester.elementList(root)) {
    if (isTitledSectionWidget(element.widget)) {
      sectionRoots.add(element);
    }
  }

  for (final Element sectionRoot in sectionRoots) {
    final List<Widget> nested = <Widget>[];
    void visit(Element node) {
      node.visitChildElements((Element child) {
        if (child == sectionRoot) {
          visit(child);
          return;
        }
        if (isTitledSectionWidget(child.widget)) {
          nested.add(child.widget);
        }
        visit(child);
      });
    }
    visit(sectionRoot);

    if (nested.isNotEmpty) {
      final String prefix =
          contextLabel == null ? '' : '$contextLabel: ';
      fail(
        '${prefix}Nested titled section(s) ${nested.map((Widget w) => w.runtimeType).join(', ')} '
        'inside ${sectionRoot.widget.runtimeType}',
      );
    }
  }
}
