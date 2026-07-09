import 'dart:async';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';

/// Shows a crop editor and returns cropped image bytes, or `null` if cancelled.
Future<Uint8List?> showAppImageCropDialog({
  required BuildContext context,
  required Uint8List imageBytes,
  double? aspectRatio = 1,
}) {
  return showAppDialog<Uint8List?>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => _AppImageCropDialog(
      imageBytes: imageBytes,
      aspectRatio: aspectRatio,
    ),
  );
}

class _AppImageCropDialog extends StatefulWidget {
  const _AppImageCropDialog({
    required this.imageBytes,
    this.aspectRatio,
  });

  final Uint8List imageBytes;
  final double? aspectRatio;

  @override
  State<_AppImageCropDialog> createState() => _AppImageCropDialogState();
}

class _AppImageCropDialogState extends State<_AppImageCropDialog> {
  final CropController _controller = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double? aspectRatio = widget.aspectRatio;

    return AppDialog(
      title: Text(l10n.appImageCropTitle),
      icon: const Icon(Icons.crop_outlined),
      pinActionsToBottom: true,
      maxWidth: 760,
      closeEnabled: !_isCropping,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.appImageCropBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          SizedBox(
            height: 420,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.radius.md),
              child: ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: Crop(
                  image: widget.imageBytes,
                  controller: _controller,
                  aspectRatio: aspectRatio,
                  interactive: true,
                  initialRectBuilder: aspectRatio == null
                      ? InitialRectBuilder.withSizeAndRatio(size: 0.9)
                      : InitialRectBuilder.withSizeAndRatio(
                          size: 0.9,
                          aspectRatio: aspectRatio,
                        ),
                  baseColor: colorScheme.surface,
                  maskColor: colorScheme.scrim.withValues(alpha: 0.45),
                  radius: theme.radius.sm,
                  scrollZoomSensitivity: 0.08,
                  onCropped: (CropResult result) {
                    if (!mounted) {
                      return;
                    }
                    switch (result) {
                      case CropSuccess(:final Uint8List croppedImage):
                        Navigator.of(context).pop(croppedImage);
                      case CropFailure():
                        setState(() {
                          _isCropping = false;
                        });
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          enabled: !_isCropping,
          onPressed: _isCropping
              ? null
              : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.appImageCropApplyAction,
          leadingIcon: Icons.check,
          isLoading: _isCropping,
          onPressed: _isCropping
              ? null
              : () {
                  setState(() {
                    _isCropping = true;
                  });
                  _controller.crop();
                },
        ),
      ],
    );
  }
}
