import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/role_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum RoleSimilarityAction { cancel, useExisting, proceed }

final class RoleSimilarityDialogResult {
  const RoleSimilarityDialogResult._({
    required this.action,
    this.selectedRole,
  });

  const RoleSimilarityDialogResult.cancel()
    : this._(action: RoleSimilarityAction.cancel);

  const RoleSimilarityDialogResult.proceed()
    : this._(action: RoleSimilarityAction.proceed);

  const RoleSimilarityDialogResult.useExisting(this.selectedRole)
    : action = RoleSimilarityAction.useExisting;

  final RoleSimilarityAction action;
  final RoleSimilarityMatch? selectedRole;
}

Future<RoleSimilarityDialogResult> showRoleSimilarityDialog(
  BuildContext context, {
  required RoleSimilarityProposedValues proposed,
  required List<RoleSimilarityMatch> matches,
  bool allowProceed = true,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<RoleSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (RoleSimilarityMatch match) => match.exactNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactNameConflict;
  final int overallScore = hasMatches
      ? visibleMatches
            .map((RoleSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b)
      : 0;

  return showAppDialog<RoleSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      return AppDialog(
        title: Text(
          hasExactNameConflict || hasMatches
              ? l10n.accessAdminSimilarRoleDialogTitle
              : l10n.accessAdminNoSimilarRoleDialogTitle,
        ),
        icon: Icon(
          hasExactNameConflict
              ? Icons.gpp_bad_outlined
              : hasMatches
              ? Icons.warning_amber_outlined
              : Icons.verified_outlined,
        ),
        scrollable: true,
        maxWidth: 820,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppFormInformationBanner(
              title: hasExactNameConflict
                  ? l10n.accessAdminRoleNameAlreadyInUse
                  : hasMatches
                  ? l10n.accessAdminSimilarRoleWarningTitle
                  : l10n.accessAdminNoSimilarRoleBannerTitle,
              message: hasExactNameConflict || hasMatches
                  ? l10n.accessAdminSimilarRoleWarningBody
                  : l10n.accessAdminNoSimilarRoleDialogBody,
              variant: hasExactNameConflict
                  ? AppFormInformationVariant.error
                  : hasMatches
                  ? AppFormInformationVariant.warning
                  : AppFormInformationVariant.success,
              icon: hasExactNameConflict
                  ? Icons.gpp_bad_outlined
                  : hasMatches
                  ? Icons.manage_search_outlined
                  : Icons.verified_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            AppSectionPanel(
              density: AppContentPanelDensity.compact,
              leadingIcon: Icons.edit_note_outlined,
              title: l10n.accessAdminSimilarRoleProposedHeading,
              trailing: Text(
                '$overallScore%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              children: <Widget>[
                Text(
                  '${l10n.accessAdminRoleNameLabel}: ${proposed.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  '${l10n.accessAdminRoleDisplayNameLabel}: ${proposed.displayName}',
                  style: theme.textTheme.bodyMedium,
                ),
                if ((proposed.description ?? '').trim().isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    '${l10n.accessAdminRoleDescriptionLabel}: ${proposed.description}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
            if (hasMatches) ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              Text(
                l10n.tenantFacilitySimilarTenantMatchesHeading,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              for (int index = 0; index < visibleMatches.length; index += 1) ...<
                Widget
              >[
                if (index > 0) SizedBox(height: theme.spacing.md),
                AppSectionPanel(
                  density: AppContentPanelDensity.compact,
                  leadingIcon: Icons.badge_outlined,
                  title: visibleMatches[index].role.title,
                  trailing: Text(
                    '${visibleMatches[index].score}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  children: <Widget>[
                    Text(
                      visibleMatches[index].role.effectiveDisplayId,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    AppButton.secondary(
                      label: l10n.accessAdminUseExistingRoleAction,
                      leadingIcon: Icons.open_in_new,
                      onPressed: () => Navigator.of(dialogContext).pop(
                        RoleSimilarityDialogResult.useExisting(
                          visibleMatches[index],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(
              const RoleSimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: hasMatches
                  ? l10n.accessAdminProceedCreateRoleAction
                  : l10n.accessAdminContinueCreateRoleAction,
              leadingIcon: hasMatches
                  ? Icons.add_moderator_outlined
                  : Icons.check_circle_outline,
              onPressed: () => Navigator.of(dialogContext).pop(
                const RoleSimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (RoleSimilarityDialogResult? value) =>
        value ?? const RoleSimilarityDialogResult.cancel(),
  );
}
