import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

final class SubscriptionHeaderButton extends StatelessWidget {
  const SubscriptionHeaderButton({
    required this.summary,
    required this.onPressed,
    super.key,
  });

  final TenantSubscriptionSummary summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool compact = breakpoint.isMobile;
    final _SubscriptionHeaderPresentation presentation =
        _SubscriptionHeaderPresentation.fromSummary(summary, l10n);

    final Widget content = compact
        ? Icon(presentation.icon, size: theme.appTokens.listIconSize)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(presentation.icon, size: theme.appTokens.listIconSize),
              SizedBox(width: theme.spacing.xs),
              Flexible(
                child: Text(
                  presentation.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: presentation.foreground,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      label: presentation.label,
      child: Tooltip(
        message: compact ? presentation.label : l10n.subscriptionHeaderTooltip,
        child: Material(
          color: presentation.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radius.sm),
            side: BorderSide(color: presentation.border),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(theme.radius.sm),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? theme.spacing.xs : theme.spacing.sm,
                vertical: theme.spacing.xs,
              ),
              child: IconTheme(
                data: IconThemeData(color: presentation.foreground),
                child: DefaultTextStyle(
                  style: TextStyle(color: presentation.foreground),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _SubscriptionHeaderPresentation {
  const _SubscriptionHeaderPresentation({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;

  factory _SubscriptionHeaderPresentation.fromSummary(
    TenantSubscriptionSummary summary,
    AppLocalizations l10n,
  ) {
    switch (summary.headerState) {
      case TenantSubscriptionHeaderState.active:
        return _SubscriptionHeaderPresentation(
          label: l10n.subscriptionHeaderActiveLabel,
          icon: Icons.verified_outlined,
          foreground: const Color(0xFF166534),
          background: const Color(0xFFDCFCE7),
          border: const Color(0xFF86EFAC),
        );
      case TenantSubscriptionHeaderState.expiringSoon:
        final int? days = summary.daysUntilExpiry;
        return _SubscriptionHeaderPresentation(
          label: days == null
              ? l10n.subscriptionHeaderExpiringSoonLabel
              : l10n.subscriptionHeaderExpiresInDaysLabel(days),
          icon: Icons.schedule_outlined,
          foreground: const Color(0xFFB45309),
          background: const Color(0xFFFFEDD5),
          border: const Color(0xFFFDBA74),
        );
      case TenantSubscriptionHeaderState.expired:
        return _SubscriptionHeaderPresentation(
          label: l10n.subscriptionHeaderExpiredLabel,
          icon: Icons.workspace_premium_outlined,
          foreground: const Color(0xFFB91C1C),
          background: const Color(0xFFFEE2E2),
          border: const Color(0xFFFCA5A5),
        );
      case TenantSubscriptionHeaderState.unknown:
        return _SubscriptionHeaderPresentation(
          label: l10n.subscriptionHeaderActiveLabel,
          icon: Icons.hourglass_empty_outlined,
          foreground: const Color(0xFF475569),
          background: const Color(0xFFF1F5F9),
          border: const Color(0xFFCBD5E1),
        );
    }
  }
}
