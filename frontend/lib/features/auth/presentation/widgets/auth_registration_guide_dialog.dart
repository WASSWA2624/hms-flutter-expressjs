import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Opens onboarding steps for facility self-registration.
Future<void> showAuthRegistrationGuideDialog(BuildContext context) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => const AuthRegistrationGuideDialog(),
  );
}

class AuthRegistrationGuideDialog extends StatelessWidget {
  const AuthRegistrationGuideDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.authRegistrationGuideTitle),
      scrollable: true,
      pinActionsToBottom: true,
      initialMaximized: true,
      maxWidth: 640,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.authRegistrationGuideIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          SizedBox(height: theme.spacing.xl),
          _GuideStep(
            step: 1,
            title: l10n.authRegistrationGuideStepCreateTitle,
            body: l10n.authRegistrationGuideStepCreateBody,
            icon: Icons.person_add_alt_1_rounded,
          ),
          SizedBox(height: theme.spacing.lg),
          _GuideStep(
            step: 2,
            title: l10n.authRegistrationGuideStepVerifyTitle,
            body: l10n.authRegistrationGuideStepVerifyBody,
            icon: Icons.mark_email_read_outlined,
          ),
          SizedBox(height: theme.spacing.lg),
          _GuideStep(
            step: 3,
            title: l10n.authRegistrationGuideStepApproveTitle,
            body: l10n.authRegistrationGuideStepApproveBody,
            icon: Icons.verified_user_outlined,
          ),
          SizedBox(height: theme.spacing.lg),
          _GuideStep(
            step: 4,
            title: l10n.authRegistrationGuideStepSignInTitle,
            body: l10n.authRegistrationGuideStepSignInBody,
            icon: Icons.login_rounded,
          ),
        ],
      ),
      actions: <Widget>[
        // Dialog footers go icon-only below lg; this guide is the entry point
        // for people who do not have an account yet, so keep the wording.
        AppActionLabelScope(
          showLabels: true,
          forceIconOnly: false,
          dense: true,
          child: AppButton.primary(
            label: l10n.commonCloseActionLabel,
            leadingIcon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.step,
    required this.title,
    required this.body,
    required this.icon,
  });

  final int step;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 18,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Text(
            '$step',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
        ),
        SizedBox(width: theme.spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 18, color: colors.primary),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
