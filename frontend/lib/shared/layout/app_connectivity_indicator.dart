import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';

/// Network-style online/offline indicator for the app shell header.
class AppConnectivityIndicator extends StatelessWidget {
  const AppConnectivityIndicator({
    required this.status,
    required this.onlineLabel,
    required this.offlineLabel,
    super.key,
  });

  final AppConnectivityStatus status;
  final String onlineLabel;
  final String offlineLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isOnline = status.isOnline;
    final Color iconColor = isOnline
        ? theme.statusColors.success
        : theme.statusColors.error;
    final String label = isOnline ? onlineLabel : offlineLabel;
    final IconData icon = isOnline ? Icons.wifi : Icons.wifi_off_outlined;

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.xs),
          child: Icon(
            icon,
            size: theme.appTokens.listIconSize,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
