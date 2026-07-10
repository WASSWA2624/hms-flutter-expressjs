import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_image_crop_dialog.dart';

/// Single or multi-image upload field with square preview tiles.
///
/// [maxFiles] defaults to `1`. Pending selections are shown before upload.
/// Use [pickAppImageFile] to pick (and optionally crop) images for this field.
class AppImageUploadField extends StatelessWidget {
  const AppImageUploadField({
    required this.label,
    required this.helperText,
    required this.chooseLabel,
    required this.removeLabel,
    required this.enabled,
    required this.pendingItems,
    required this.onChoose,
    this.onClear,
    this.existingImageUrl,
    this.placeholderIcon = Icons.add,
    this.previewSize = 88,
    this.maxFiles = 1,
    super.key,
  });

  final String label;
  final String helperText;
  final String chooseLabel;
  final String removeLabel;
  final bool enabled;
  final List<AppImageUploadPendingItem> pendingItems;
  final String? existingImageUrl;
  final VoidCallback onChoose;
  final VoidCallback? onClear;
  final IconData placeholderIcon;
  final double previewSize;
  final int maxFiles;

  bool get _hasPending => pendingItems.isNotEmpty;
  bool get _canChooseMore => pendingItems.length < maxFiles;
  String? get _singlePendingName =>
      pendingItems.length == 1 ? pendingItems.first.fileName : null;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? previewUrl = _hasPending ? null : existingImageUrl?.trim();
    final List<int>? previewBytes = _hasPending && pendingItems.length == 1
        ? pendingItems.first.bytes
        : null;
    final bool hasImage =
        _hasPending || (previewUrl != null && previewUrl.isNotEmpty);

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
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(theme.radius.md),
            color: colorScheme.surfaceContainerLowest,
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Row(
              children: <Widget>[
                if (maxFiles == 1)
                  _ImagePreviewTile(
                    imageUrl: previewUrl,
                    pendingBytes: previewBytes,
                    placeholderIcon: placeholderIcon,
                    size: previewSize,
                    onTap: enabled && _canChooseMore ? onChoose : null,
                  )
                else
                  Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.sm,
                    children: <Widget>[
                      for (final AppImageUploadPendingItem item in pendingItems)
                        _ImagePreviewTile(
                          pendingBytes: item.bytes,
                          placeholderIcon: placeholderIcon,
                          size: previewSize,
                        ),
                      if (_canChooseMore)
                        _ImagePreviewTile(
                          placeholderIcon: placeholderIcon,
                          size: previewSize,
                          onTap: enabled ? onChoose : null,
                        ),
                    ],
                  ),
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        helperText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: theme.spacing.sm),
                      Wrap(
                        spacing: theme.spacing.xs,
                        runSpacing: theme.spacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          AppButton.secondary(
                            label: chooseLabel,
                            leadingIcon: Icons.image_outlined,
                            enabled: enabled && _canChooseMore,
                            onPressed: enabled && _canChooseMore
                                ? onChoose
                                : null,
                          ),
                          if (hasImage && onClear != null)
                            AppButton.tertiary(
                              label: removeLabel,
                              leadingIcon: Icons.close,
                              enabled: enabled,
                              onPressed: enabled ? onClear : null,
                            ),
                        ],
                      ),
                      if (_singlePendingName != null) ...<Widget>[
                        SizedBox(height: theme.spacing.xs),
                        Text(
                          _singlePendingName!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class AppImageUploadPendingItem {
  const AppImageUploadPendingItem({
    required this.fileName,
    required this.bytes,
    this.mimeType,
  });

  final String fileName;
  final List<int> bytes;
  final String? mimeType;
}

class _ImagePreviewTile extends StatelessWidget {
  const _ImagePreviewTile({
    this.imageUrl,
    this.pendingBytes,
    required this.placeholderIcon,
    required this.size,
    this.onTap,
  });

  final String? imageUrl;
  final List<int>? pendingBytes;
  final IconData placeholderIcon;
  final double size;
  final VoidCallback? onTap;

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
      child = Icon(placeholderIcon, color: theme.colorScheme.onSurfaceVariant);
    }

    final Widget tile = ClipRRect(
      borderRadius: BorderRadius.circular(theme.radius.md),
      child: Container(
        width: size,
        height: size,
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: child,
      ),
    );

    if (onTap == null) {
      return tile;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radius.md),
        child: tile,
      ),
    );
  }
}

/// Picks an image from disk and optionally opens the crop editor.
Future<AppImageUploadPendingItem?> pickAppImageFile(
  AppLocalizations l10n, {
  required BuildContext context,
  List<String> extensions = const <String>['jpg', 'jpeg', 'png', 'webp'],
  String typeGroupLabel = 'image',
  bool enableCrop = true,
  double? cropAspectRatio = 1,
}) async {
  final XTypeGroup typeGroup = XTypeGroup(
    label: typeGroupLabel,
    extensions: extensions,
  );
  final XFile? file = await openFile(
    acceptedTypeGroups: <XTypeGroup>[typeGroup],
  );
  if (file == null) {
    return null;
  }

  List<int> bytes = await file.readAsBytes();
  String fileName = file.name;
  String? mimeType = file.mimeType;

  if (enableCrop && context.mounted) {
    final Uint8List? croppedBytes = await showAppImageCropDialog(
      context: context,
      imageBytes: Uint8List.fromList(bytes),
      aspectRatio: cropAspectRatio,
    );
    if (croppedBytes == null) {
      return null;
    }
    bytes = croppedBytes;
    fileName = _croppedFileName(fileName);
    mimeType = 'image/png';
  }

  return AppImageUploadPendingItem(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
}

String _croppedFileName(String originalFileName) {
  final int dotIndex = originalFileName.lastIndexOf('.');
  final String baseName = dotIndex > 0
      ? originalFileName.substring(0, dotIndex)
      : originalFileName;
  return '$baseName-cropped.png';
}
