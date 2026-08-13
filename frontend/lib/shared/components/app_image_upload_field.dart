import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/utils/app_media_url.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_image_crop_dialog.dart';

/// Single or multi-image upload field with a tile grid.
///
/// Helper text sits above the tiles. Each image shows an X remove control.
/// An empty add tile appears while under [maxFiles]. Tapping an image opens a
/// preview; tapping the add tile calls [onChoose].
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
    this.onRemovePendingAt,
    this.onRemoveExistingAt,
    this.existingImageUrl,
    this.existingImageUrls = const <String>[],
    this.placeholderIcon = Icons.add_photo_alternate_outlined,
    this.previewSize = 96,
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
  final List<String> existingImageUrls;
  final VoidCallback onChoose;
  final VoidCallback? onClear;
  final ValueChanged<int>? onRemovePendingAt;
  final ValueChanged<int>? onRemoveExistingAt;
  final IconData placeholderIcon;
  final double previewSize;
  final int maxFiles;

  List<String> get _resolvedExistingUrls {
    final List<String> urls = <String>[
      for (final String url in existingImageUrls)
        if (url.trim().isNotEmpty) url.trim(),
    ];
    final String? single = existingImageUrl?.trim();
    if (single != null &&
        single.isNotEmpty &&
        !urls.contains(single) &&
        pendingItems.isEmpty) {
      urls.insert(0, single);
    }
    return urls;
  }

  String? _mediaUrl(BuildContext context, String? raw) {
    final Uri apiBaseUrl = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(appConfigProvider).apiBaseUrl;
    return resolveAppMediaUrl(raw, apiBaseUrl);
  }

  int get _filledCount => pendingItems.length + _resolvedExistingUrls.length;

  bool get _canChooseMore => _filledCount < maxFiles;

  Future<void> _previewImage(
    BuildContext context, {
    String? imageUrl,
    List<int>? bytes,
  }) {
    return showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppLocalizations l10n = dialogContext.l10n;
        final ThemeData theme = Theme.of(dialogContext);
        final ColorScheme colorScheme = theme.colorScheme;
        final bool hasBytes = bytes != null && bytes.isNotEmpty;
        final bool hasUrl = imageUrl != null && imageUrl.trim().isNotEmpty;

        return AppDialog(
          title: Text(l10n.appImageUploadPreviewTitle),
          icon: const Icon(Icons.image_outlined),
          maxWidth: 720,
          scrollable: true,
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.55,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(theme.radius.md),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(theme.radius.md),
                child: Center(
                  child: hasBytes
                      ? Image.memory(
                          Uint8List.fromList(bytes),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        )
                      : hasUrl
                      ? Image.network(
                          _mediaUrl(dialogContext, imageUrl) ?? imageUrl.trim(),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.broken_image_outlined,
                            color: colorScheme.onSurfaceVariant,
                            size: 48,
                          ),
                        )
                      : Icon(
                          Icons.image_not_supported_outlined,
                          color: colorScheme.onSurfaceVariant,
                          size: 48,
                        ),
                ),
              ),
            ),
          ),
          actions: <Widget>[
            AppButton.primary(
              label: l10n.commonCloseActionLabel,
              leadingIcon: Icons.close,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  void _removePending(int index) {
    if (onRemovePendingAt != null) {
      onRemovePendingAt!(index);
      return;
    }
    onClear?.call();
  }

  void _removeExisting(int index) {
    if (onRemoveExistingAt != null) {
      onRemoveExistingAt!(index);
      return;
    }
    onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final List<String> existingUrls = _resolvedExistingUrls;
    final String? singlePendingName = pendingItems.length == 1
        ? pendingItems.first.fileName
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            border: theme.borders.all(color: theme.borders.inputIdle),
            borderRadius: BorderRadius.circular(theme.radius.md),
            color: colorScheme.surfaceContainerLowest,
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.sm,
                  children: <Widget>[
                    for (int i = 0; i < existingUrls.length; i++)
                      _ImagePreviewTile(
                        imageUrl: _mediaUrl(context, existingUrls[i]),
                        placeholderIcon: placeholderIcon,
                        size: previewSize,
                        removeTooltip: removeLabel,
                        onTap: () => _previewImage(
                          context,
                          imageUrl: _mediaUrl(context, existingUrls[i]),
                        ),
                        onRemove: enabled ? () => _removeExisting(i) : null,
                      ),
                    for (int i = 0; i < pendingItems.length; i++)
                      _ImagePreviewTile(
                        pendingBytes: pendingItems[i].bytes,
                        placeholderIcon: placeholderIcon,
                        size: previewSize,
                        removeTooltip: removeLabel,
                        onTap: () => _previewImage(
                          context,
                          bytes: pendingItems[i].bytes,
                        ),
                        onRemove: enabled ? () => _removePending(i) : null,
                      ),
                    if (enabled && _canChooseMore)
                      _ImagePreviewTile(
                        placeholderIcon: Icons.add,
                        size: previewSize,
                        isAddTile: true,
                        addTooltip: chooseLabel,
                        onTap: onChoose,
                      ),
                  ],
                ),
                if (singlePendingName != null) ...<Widget>[
                  SizedBox(height: theme.spacing.sm),
                  Text(
                    singlePendingName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (!enabled && _filledCount == 0) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    l10n.appImageUploadEmptyLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
    this.onRemove,
    this.removeTooltip,
    this.addTooltip,
    this.isAddTile = false,
  });

  final String? imageUrl;
  final List<int>? pendingBytes;
  final IconData placeholderIcon;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final String? removeTooltip;
  final String? addTooltip;
  final bool isAddTile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool hasBytes = pendingBytes != null && pendingBytes!.isNotEmpty;
    final bool hasUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final bool hasImage = hasBytes || hasUrl;

    final Widget content;
    if (hasBytes) {
      content = Image.memory(
        Uint8List.fromList(pendingBytes!),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    } else if (hasUrl) {
      content = Image.network(
        imageUrl!.trim(),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => Icon(
          Icons.broken_image_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(placeholderIcon, color: colorScheme.primary, size: size * 0.34),
          if (isAddTile) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                addTooltip ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
            ),
          ],
        ],
      );
    }

    final Widget tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radius.md),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isAddTile
                ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(theme.radius.md),
            border: theme.borders.all(color: theme.borders.inputIdle),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.radius.md),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                content,
                if (hasImage && onRemove != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Tooltip(
                      message: removeTooltip ?? '',
                      child: Material(
                        color: colorScheme.surface.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onRemove,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (isAddTile && addTooltip != null && addTooltip!.isNotEmpty) {
      return Tooltip(message: addTooltip!, child: tile);
    }
    return tile;
  }
}

/// Picks an image from disk and optionally opens the crop editor.
///
/// Defaults to free-form cropping (static full image + movable crop box).
/// When [showCropAspectPresets] is true (default for free-form), the crop
/// dialog offers Free / 1:1 / 4:3 / 16:9 presets that only lock the box ratio.
Future<AppImageUploadPendingItem?> pickAppImageFile(
  AppLocalizations l10n, {
  required BuildContext context,
  List<String> extensions = const <String>['jpg', 'jpeg', 'png', 'webp'],
  String typeGroupLabel = 'image',
  bool enableCrop = true,
  double? cropAspectRatio,
  bool? showCropAspectPresets,
  String? preferredFileName,
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
  String fileName = preferredFileName?.trim().isNotEmpty == true
      ? preferredFileName!.trim()
      : file.name;
  String? mimeType = file.mimeType;

  if (enableCrop && context.mounted) {
    final Uint8List? croppedBytes = await showAppImageCropDialog(
      context: context,
      imageBytes: Uint8List.fromList(bytes),
      aspectRatio: cropAspectRatio,
      showAspectPresets: showCropAspectPresets ?? cropAspectRatio == null,
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

/// Picks one or more images from disk into memory. Optionally crops each file
/// through the shared crop editor. Never uploads to media APIs.
Future<List<AppImageUploadPendingItem>> pickAppImageFiles(
  AppLocalizations l10n, {
  required BuildContext context,
  List<String> extensions = const <String>['jpg', 'jpeg', 'png', 'webp'],
  String typeGroupLabel = 'image',
  bool enableCrop = true,
  double? cropAspectRatio,
  bool? showCropAspectPresets,
}) async {
  final XTypeGroup typeGroup = XTypeGroup(
    label: typeGroupLabel,
    extensions: extensions,
  );
  final List<XFile> files = await openFiles(
    acceptedTypeGroups: <XTypeGroup>[typeGroup],
  );
  if (files.isEmpty) {
    return const <AppImageUploadPendingItem>[];
  }

  final List<AppImageUploadPendingItem> items = <AppImageUploadPendingItem>[];
  for (final XFile file in files) {
    if (!context.mounted) {
      break;
    }
    List<int> bytes = await file.readAsBytes();
    String fileName = file.name;
    String? mimeType = file.mimeType;

    if (enableCrop && context.mounted) {
      final Uint8List? croppedBytes = await showAppImageCropDialog(
        context: context,
        imageBytes: Uint8List.fromList(bytes),
        aspectRatio: cropAspectRatio,
        showAspectPresets: showCropAspectPresets ?? cropAspectRatio == null,
      );
      if (croppedBytes == null) {
        // User skipped this image; continue with remaining selections.
        continue;
      }
      bytes = croppedBytes;
      fileName = _croppedFileName(fileName);
      mimeType = 'image/png';
    }

    items.add(
      AppImageUploadPendingItem(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      ),
    );
  }
  return items;
}

String _croppedFileName(String originalFileName) {
  final int dotIndex = originalFileName.lastIndexOf('.');
  final String baseName = dotIndex > 0
      ? originalFileName.substring(0, dotIndex)
      : originalFileName;
  final String sanitized = baseName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._-]'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final String stem = sanitized.isEmpty ? 'image' : sanitized;
  final String withSuffix = stem.endsWith('-logo') || stem.endsWith('-cropped')
      ? stem
      : '$stem-cropped';
  // Keep basename short for cross-OS filesystem safety (≤ 64 incl. extension).
  const int maxBasename = 64;
  const String extension = '.png';
  const int maxStem = maxBasename - extension.length;
  final String clipped = withSuffix.length <= maxStem
      ? withSuffix
      : withSuffix.substring(0, maxStem).replaceAll(RegExp(r'-$'), '');
  return '$clipped$extension';
}
