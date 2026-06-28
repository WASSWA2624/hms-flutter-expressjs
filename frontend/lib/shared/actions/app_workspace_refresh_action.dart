import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';

/// Standard refresh control for workspace toolbars (right cluster).
class AppWorkspaceRefreshAction extends StatelessWidget {
  const AppWorkspaceRefreshAction({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: Icons.refresh,
      semanticLabel: label,
      tooltip: label,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}
