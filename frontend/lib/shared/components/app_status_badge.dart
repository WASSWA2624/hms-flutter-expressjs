import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Status badge with localized label + non-color cue (icon).
///
/// Prefer this over color-only chips in worklists and detail panels.
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    required this.label,
    this.tone = AppWorkspaceStatusTone.neutral,
    this.icon,
    super.key,
  });

  AppStatusBadge.fromStatus(AppWorkspaceStatus status, {Key? key})
    : this(label: status.label, tone: status.tone, icon: status.icon, key: key);

  final String label;
  final AppWorkspaceStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(label: label, tone: tone, icon: icon),
    );
  }
}
