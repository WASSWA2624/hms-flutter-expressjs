import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';

/// Shows a crop editor and returns cropped image bytes, or `null` if cancelled.
///
/// Pass [aspectRatio] as `null` for free-form cropping (any size/ratio).
/// When [showAspectPresets] is true, the user can switch between Free and
/// common locked ratios.
Future<Uint8List?> showAppImageCropDialog({
  required BuildContext context,
  required Uint8List imageBytes,
  double? aspectRatio = 1,
  bool showAspectPresets = false,
}) {
  return showAppDialog<Uint8List?>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => _AppImageCropDialog(
      imageBytes: imageBytes,
      initialAspectRatio: aspectRatio,
      showAspectPresets: showAspectPresets || aspectRatio == null,
    ),
  );
}

class _AppImageCropDialog extends StatefulWidget {
  const _AppImageCropDialog({
    required this.imageBytes,
    required this.initialAspectRatio,
    required this.showAspectPresets,
  });

  final Uint8List imageBytes;
  final double? initialAspectRatio;
  final bool showAspectPresets;

  @override
  State<_AppImageCropDialog> createState() => _AppImageCropDialogState();
}

class _AppImageCropDialogState extends State<_AppImageCropDialog> {
  late CropController _controller;
  late double? _aspectRatio;
  bool _isCropping = false;
  int _cropViewGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = CropController();
    _aspectRatio = widget.initialAspectRatio;
  }

  void _setAspectRatio(double? next) {
    if (_isCropping || _aspectRatio == next) {
      return;
    }
    setState(() {
      _aspectRatio = next;
      _cropViewGeneration += 1;
      _controller = CropController();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double? aspectRatio = _aspectRatio;
    final double cropHeight = math.min(
      460,
      math.max(240, MediaQuery.sizeOf(context).height * 0.48),
    );

    return AppDialog(
      title: Text(l10n.appImageCropTitle),
      icon: const Icon(Icons.crop_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 800,
      closeEnabled: !_isCropping,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            aspectRatio == null
                ? l10n.appImageCropFreeformBody
                : l10n.appImageCropBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (widget.showAspectPresets) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                _AspectPresetChip(
                  label: l10n.appImageCropAspectFree,
                  selected: aspectRatio == null,
                  enabled: !_isCropping,
                  onSelected: () => _setAspectRatio(null),
                ),
                _AspectPresetChip(
                  label: l10n.appImageCropAspectSquare,
                  selected: aspectRatio == 1,
                  enabled: !_isCropping,
                  onSelected: () => _setAspectRatio(1),
                ),
                _AspectPresetChip(
                  label: l10n.appImageCropAspectFourThree,
                  selected: aspectRatio == 4 / 3,
                  enabled: !_isCropping,
                  onSelected: () => _setAspectRatio(4 / 3),
                ),
                _AspectPresetChip(
                  label: l10n.appImageCropAspectSixteenNine,
                  selected: aspectRatio == 16 / 9,
                  enabled: !_isCropping,
                  onSelected: () => _setAspectRatio(16 / 9),
                ),
              ],
            ),
          ],
          SizedBox(height: theme.spacing.md),
          SizedBox(
            height: cropHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.radius.md),
              child: ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: Crop(
                  key: ValueKey<int>(_cropViewGeneration),
                  image: widget.imageBytes,
                  controller: _controller,
                  aspectRatio: aspectRatio,
                  interactive: true,
                  // Near-full image so the whole photo is visible first.
                  initialRectBuilder: aspectRatio == null
                      ? InitialRectBuilder.withSizeAndRatio(size: 0.98)
                      : InitialRectBuilder.withSizeAndRatio(
                          size: 0.98,
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
          onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
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

class _AspectPresetChip extends StatelessWidget {
  const _AspectPresetChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onSelected() : null,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.primary,
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected ? colorScheme.primary : colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}
