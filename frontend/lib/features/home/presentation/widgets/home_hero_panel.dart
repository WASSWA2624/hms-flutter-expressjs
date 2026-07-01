import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Role-aware facility / tenant context line for the home hero strip.
String homeDashboardContextLine({
  required AppRole role,
  required HomeDashboardContext context,
}) {
  final bool showFacility =
      role == AppRole.superAdmin || role == AppRole.tenantAdmin;
  final List<String> parts = <String>[
    if (showFacility && _hasText(context.facilityName)) context.facilityName!,
    if (showFacility && _hasText(context.facilityType))
      _formatToken(context.facilityType!),
    if (_hasText(context.tenantId)) 'Tenant ${context.tenantId}',
    if (_hasText(context.branchId)) 'Branch ${context.branchId}',
  ];

  if (parts.isEmpty) {
    return 'Dashboard context follows your assigned account scope.';
  }

  return parts.join(' | ');
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String _formatToken(String value) {
  return value
      .trim()
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

/// Hero context strip for role dashboards — hidden below md breakpoint.
class HomeHeroPanel extends StatelessWidget {
  const HomeHeroPanel({
    required this.subtitle,
    required this.contextLine,
    required this.generatedAt,
    required this.usesFallbackData,
    this.fullWidth = false,
    super.key,
  });

  final String subtitle;
  final String contextLine;
  final DateTime? generatedAt;
  final bool usesFallbackData;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    if (breakpoint.index < AppBreakpoint.md.index) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? generatedLabel = generatedAt == null
        ? null
        : 'Updated ${DateFormat('MMM d, HH:mm').format(generatedAt!.toLocal())}';

    return AppContentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: fullWidth
                    ? Text(subtitle, style: theme.textTheme.bodyLarge)
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Text(subtitle, style: theme.textTheme.bodyLarge),
                      ),
              ),
              if (generatedLabel != null || usesFallbackData) ...<Widget>[
                SizedBox(width: theme.spacing.md),
                AppWorkspaceStatusBadge(
                  status: AppWorkspaceStatus(
                    label: usesFallbackData
                        ? 'Profile view'
                        : generatedLabel ?? 'Live dashboard',
                    tone: usesFallbackData
                        ? AppWorkspaceStatusTone.info
                        : AppWorkspaceStatusTone.success,
                  ),
                ),
              ],
            ],
          ),
          if (contextLine.trim().isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            fullWidth
                ? Text(
                    contextLine,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Text(
                      contextLine,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}
