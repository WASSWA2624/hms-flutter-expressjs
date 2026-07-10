import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/subscriptions/subscription_plan_theme.dart';
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
        _SubscriptionHeaderPresentation.fromSummary(summary, l10n, theme);

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
    ThemeData theme,
  ) {
    final bool noPaidSubscription =
        summary.headerState == TenantSubscriptionHeaderState.unknown ||
        !_hasText(summary.subscriptionId) ||
        !_hasText(summary.tierCode) ||
        SubscriptionPlanTheme.isFreeTier(summary.tierCode);

    final SubscriptionPlanTheme planTheme = noPaidSubscription
        ? SubscriptionPlanTheme.resolve(theme, 'FREE')
        : SubscriptionPlanTheme.resolve(theme, summary.tierCode);

    switch (summary.headerState) {
      case TenantSubscriptionHeaderState.active:
        if (noPaidSubscription) {
          return _SubscriptionHeaderPresentation(
            label: l10n.subscriptionHeaderFreeLabel,
            icon: Icons.workspace_premium_outlined,
            foreground: planTheme.foreground,
            background: planTheme.background,
            border: planTheme.border,
          );
        }
        return _SubscriptionHeaderPresentation(
          label: l10n.subscriptionHeaderActiveLabel,
          icon: Icons.verified_outlined,
          foreground: planTheme.foreground,
          background: planTheme.background,
          border: planTheme.border,
        );
      case TenantSubscriptionHeaderState.expiringSoon:
        final int? days = summary.daysUntilExpiry;
        return _SubscriptionHeaderPresentation(
          label: days == null
              ? l10n.subscriptionHeaderExpiringSoonLabel
              : l10n.subscriptionHeaderExpiresInDaysLabel(days),
          icon: Icons.schedule_outlined,
          foreground: planTheme.foreground,
          background: planTheme.background,
          border: planTheme.border,
        );
      case TenantSubscriptionHeaderState.expired:
        return _SubscriptionHeaderPresentation(
          label: l10n.subscriptionHeaderExpiredLabel,
          icon: Icons.workspace_premium_outlined,
          foreground: theme.statusColors.error,
          background: theme.statusColors.errorContainer,
          border: theme.statusColors.error.withValues(alpha: 0.45),
        );
      case TenantSubscriptionHeaderState.unknown:
        final SubscriptionPlanTheme freeTheme = SubscriptionPlanTheme.resolve(
          theme,
          'FREE',
        );
        return _SubscriptionHeaderPresentation(
          label: l10n.subscriptionHeaderFreeLabel,
          icon: Icons.workspace_premium_outlined,
          foreground: freeTheme.foreground,
          background: freeTheme.background,
          border: freeTheme.border,
        );
    }
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
