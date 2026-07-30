import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_collapsible_section.dart';

/// Whether [widget] is titled section chrome per billing-and-sections rules.
bool isTitledSectionWidget(Widget widget) {
  if (widget is AppCollapsibleSection) {
    return widget.title?.trim().isNotEmpty == true ||
        widget.titleWidget != null;
  }
  // Convenience wrappers (AppFormSection / AppSectionPanel) build
  // AppCollapsibleSection at runtime — count the built section only.
  return false;
}

/// Walks [root] and fails when any section contains a nested section.
void assertFlatSections(Element root) {
  void walk(Element element, {required bool insideSection}) {
    final Widget widget = element.widget;
    final bool isSection = isTitledSectionWidget(widget);
    if (isSection && insideSection) {
      fail('Nested titled section detected: $widget');
    }
    final bool nowInsideSection = insideSection || isSection;
    element.visitChildren(
      (Element child) => walk(child, insideSection: nowInsideSection),
    );
  }

  walk(root, insideSection: false);
}

/// Asserts no section-in-section nesting under [tester]'s root widget.
void expectFlatSections(WidgetTester tester) {
  assertFlatSections(tester.binding.rootElement!);
}
