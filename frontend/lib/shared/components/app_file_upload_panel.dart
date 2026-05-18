import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class AppFileUploadPanel extends StatelessWidget {
  const AppFileUploadPanel({
    required this.title,
    required this.emptyDescription,
    required this.chooseLabel,
    required this.clearLabel,
    required this.fileNames,
    required this.onChoose,
    required this.onClear,
    this.leadingIcon = Icons.upload_file_outlined,
    this.chooseIcon = Icons.attach_file_outlined,
    this.clearIcon = Icons.close,
    this.enabled = true,
    this.isLoading = false,
    this.tone = AppWorkspaceStatusTone.neutral,
    super.key,
  });

  final String title;
  final String emptyDescription;
  final String chooseLabel;
  final String clearLabel;
  final List<String> fileNames;
  final VoidCallback onChoose;
  final VoidCallback onClear;
  final IconData leadingIcon;
  final IconData chooseIcon;
  final IconData clearIcon;
  final bool enabled;
  final bool isLoading;
  final AppWorkspaceStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String description = fileNames.isEmpty
        ? emptyDescription
        : fileNames.join(', ');
    final bool canInteract = enabled && !isLoading;

    return AppSectionPanel(
      title: title,
      description: description,
      leadingIcon: leadingIcon,
      tone: tone,
      children: <Widget>[
        Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            AppButton.secondary(
              label: chooseLabel,
              leadingIcon: chooseIcon,
              isLoading: isLoading,
              enabled: enabled,
              onPressed: canInteract ? onChoose : null,
            ),
            if (fileNames.isNotEmpty)
              AppButton.tertiary(
                label: clearLabel,
                leadingIcon: clearIcon,
                enabled: canInteract,
                onPressed: canInteract ? onClear : null,
              ),
          ],
        ),
      ],
    );
  }
}
