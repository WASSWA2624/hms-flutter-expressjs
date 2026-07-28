import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Page-level titled section that uses [AppWorkspaceDetailPanel] chrome.
class AppScreenSection extends StatelessWidget {
  const AppScreenSection({
    required this.title,
    required this.body,
    required this.child,
    this.collapsible = true,
    this.initiallyExpanded = true,
    super.key,
  });

  final String title;
  final String body;
  final Widget child;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: title,
      description: body,
      collapsible: collapsible,
      initiallyExpanded: initiallyExpanded,
      child: child,
    );
  }
}
