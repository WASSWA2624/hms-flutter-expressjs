import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class FacilityLogoUploadField extends StatelessWidget {
  const FacilityLogoUploadField({
    required this.label,
    required this.helperText,
    required this.chooseLabel,
    required this.removeLabel,
    required this.enabled,
    required this.existingLogoUrl,
    required this.pendingFileName,
    required this.pendingBytes,
    required this.onChoose,
    required this.onClear,
    super.key,
  });

  final String label;
  final String helperText;
  final String chooseLabel;
  final String removeLabel;
  final bool enabled;
  final String? existingLogoUrl;
  final String? pendingFileName;
  final List<int>? pendingBytes;
  final VoidCallback onChoose;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasPendingLogo =
        pendingBytes != null && pendingBytes!.isNotEmpty;
    final String? previewUrl = hasPendingLogo ? null : existingLogoUrl?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _LogoPreview(imageUrl: previewUrl, pendingBytes: pendingBytes),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  AppButton.secondary(
                    label: chooseLabel,
                    leadingIcon: Icons.image_outlined,
                    enabled: enabled,
                    onPressed: enabled ? onChoose : null,
                  ),
                  if (hasPendingLogo || (previewUrl?.isNotEmpty ?? false))
                    AppButton.tertiary(
                      label: removeLabel,
                      leadingIcon: Icons.close,
                      enabled: enabled,
                      onPressed: enabled ? onClear : null,
                    ),
                  if (pendingFileName != null)
                    Text(pendingFileName!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.imageUrl, required this.pendingBytes});

  final String? imageUrl;
  final List<int>? pendingBytes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget child;

    if (pendingBytes != null && pendingBytes!.isNotEmpty) {
      child = Image.memory(
        Uint8List.fromList(pendingBytes!),
        fit: BoxFit.cover,
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.broken_image_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      child = Icon(
        Icons.local_hospital_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.radius.md),
      child: Container(
        width: 72,
        height: 72,
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

Future<FacilityLogoPickResult?> pickFacilityLogoFile(
  AppLocalizations l10n,
) async {
  const XTypeGroup typeGroup = XTypeGroup(
    label: 'facility-logo',
    extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
  );
  final XFile? file = await openFile(
    acceptedTypeGroups: <XTypeGroup>[typeGroup],
  );
  if (file == null) {
    return null;
  }

  return FacilityLogoPickResult(
    fileName: file.name,
    bytes: await file.readAsBytes(),
    mimeType: file.mimeType,
  );
}

final class FacilityLogoPickResult {
  const FacilityLogoPickResult({
    required this.fileName,
    required this.bytes,
    this.mimeType,
  });

  final String fileName;
  final List<int> bytes;
  final String? mimeType;
}
