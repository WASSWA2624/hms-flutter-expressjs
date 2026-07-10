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
/// Flow: crop → preview → confirm. The full image stays fixed (no pan/zoom).
/// The user moves and resizes the crop rectangle over it. Pass [aspectRatio]
/// as `null` (default) for free-form cropping. When [showAspectPresets] is
/// true, Free / 1:1 / 4:3 / 16:9 shortcuts are offered; presets only lock the
/// rectangle ratio.
Future<Uint8List?> showAppImageCropDialog({
  required BuildContext context,
  required Uint8List imageBytes,
  double? aspectRatio,
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
  static const double _minCropSide = 32;
  static const double _edgeHitSize = 22;

  late CropController _controller;
  late double? _aspectRatio;
  bool _isCropping = false;
  int _cropViewGeneration = 0;
  Uint8List? _previewBytes;
  Rect? _cropViewportRect;
  Rect? _imageViewportRect;

  bool get _showingPreview => _previewBytes != null;

  @override
  void initState() {
    super.initState();
    _controller = CropController();
    _aspectRatio = widget.initialAspectRatio;
  }

  void _resetCropSession() {
    _cropViewGeneration += 1;
    _controller = CropController();
    _cropViewportRect = null;
    _imageViewportRect = null;
  }

  void _setAspectRatio(double? next) {
    if (_isCropping || _showingPreview || _aspectRatio == next) {
      return;
    }
    setState(() {
      _aspectRatio = next;
      _resetCropSession();
    });
  }

  void _returnToCrop() {
    if (_isCropping) {
      return;
    }
    setState(() {
      _previewBytes = null;
      _resetCropSession();
    });
  }

  MouseCursor _cursorForCorner(EdgeAlignment alignment) {
    return switch (alignment) {
      EdgeAlignment.topLeft || EdgeAlignment.bottomRight =>
        SystemMouseCursors.resizeUpLeftDownRight,
      EdgeAlignment.topRight || EdgeAlignment.bottomLeft =>
        SystemMouseCursors.resizeUpRightDownLeft,
    };
  }

  void _onCropMoved(Rect viewportRect, Rect _) {
    if (!mounted) {
      return;
    }
    setState(() {
      _cropViewportRect = viewportRect;
    });
  }

  void _onImageMoved(Rect imageRect) {
    if (!mounted) {
      return;
    }
    setState(() {
      _imageViewportRect = imageRect;
    });
  }

  void _resizeFromEdge(_CropEdge edge, Offset delta) {
    final Rect? crop = _cropViewportRect;
    if (crop == null) {
      return;
    }
    final Rect bounds = _imageViewportRect ?? crop;
    late final Rect next;
    switch (edge) {
      case _CropEdge.top:
        next = Rect.fromLTRB(
          crop.left,
          (crop.top + delta.dy).clamp(bounds.top, crop.bottom - _minCropSide),
          crop.right,
          crop.bottom,
        );
      case _CropEdge.bottom:
        next = Rect.fromLTRB(
          crop.left,
          crop.top,
          crop.right,
          (crop.bottom + delta.dy).clamp(crop.top + _minCropSide, bounds.bottom),
        );
      case _CropEdge.left:
        next = Rect.fromLTRB(
          (crop.left + delta.dx).clamp(bounds.left, crop.right - _minCropSide),
          crop.top,
          crop.right,
          crop.bottom,
        );
      case _CropEdge.right:
        next = Rect.fromLTRB(
          crop.left,
          crop.top,
          (crop.right + delta.dx).clamp(crop.left + _minCropSide, bounds.right),
          crop.bottom,
        );
    }
    _controller.cropRect = next;
  }

  List<Widget> _buildEdgeHandles(ColorScheme colorScheme) {
    final Rect? crop = _cropViewportRect;
    if (crop == null || _aspectRatio != null) {
      return const <Widget>[];
    }

    Widget handle({
      required double left,
      required double top,
      required MouseCursor cursor,
      required _CropEdge edge,
      required bool horizontalBar,
    }) {
      return Positioned(
        left: left,
        top: top,
        child: MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (DragUpdateDetails details) {
              _resizeFromEdge(edge, details.delta);
            },
            child: SizedBox(
              width: horizontalBar ? 36 : _edgeHitSize,
              height: horizontalBar ? _edgeHitSize : 36,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colorScheme.outlineVariant),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.18),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: horizontalBar ? 22 : 6,
                    height: horizontalBar ? 6 : 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return <Widget>[
      handle(
        left: crop.center.dx - 18,
        top: crop.top - (_edgeHitSize / 2),
        cursor: SystemMouseCursors.resizeUpDown,
        edge: _CropEdge.top,
        horizontalBar: true,
      ),
      handle(
        left: crop.center.dx - 18,
        top: crop.bottom - (_edgeHitSize / 2),
        cursor: SystemMouseCursors.resizeUpDown,
        edge: _CropEdge.bottom,
        horizontalBar: true,
      ),
      handle(
        left: crop.left - (_edgeHitSize / 2),
        top: crop.center.dy - 18,
        cursor: SystemMouseCursors.resizeLeftRight,
        edge: _CropEdge.left,
        horizontalBar: false,
      ),
      handle(
        left: crop.right - (_edgeHitSize / 2),
        top: crop.center.dy - 18,
        cursor: SystemMouseCursors.resizeLeftRight,
        edge: _CropEdge.right,
        horizontalBar: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double? aspectRatio = _aspectRatio;
    final bool showingPreview = _showingPreview;
    final Uint8List? previewBytes = _previewBytes;
    final double cropHeight = math.min(
      460,
      math.max(240, MediaQuery.sizeOf(context).height * 0.48),
    );

    return AppDialog(
      title: Text(
        showingPreview ? l10n.appImageCropPreviewTitle : l10n.appImageCropTitle,
      ),
      icon: Icon(
        showingPreview ? Icons.image_outlined : Icons.crop_outlined,
      ),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 800,
      closeEnabled: !_isCropping,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            showingPreview
                ? l10n.appImageCropPreviewBody
                : (aspectRatio == null
                      ? l10n.appImageCropFreeformBody
                      : l10n.appImageCropBody),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (!showingPreview && widget.showAspectPresets) ...<Widget>[
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
                child: showingPreview && previewBytes != null
                    ? Center(
                        child: Image.memory(
                          previewBytes,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Crop(
                            key: ValueKey<int>(_cropViewGeneration),
                            image: widget.imageBytes,
                            controller: _controller,
                            aspectRatio: aspectRatio,
                            initialRectBuilder: aspectRatio == null
                                ? InitialRectBuilder.withSizeAndRatio(
                                    size: 0.92,
                                  )
                                : InitialRectBuilder.withSizeAndRatio(
                                    size: 0.92,
                                    aspectRatio: aspectRatio,
                                  ),
                            baseColor: colorScheme.surface,
                            maskColor: colorScheme.scrim.withValues(
                              alpha: 0.45,
                            ),
                            radius: theme.radius.sm,
                            onMoved: _onCropMoved,
                            onImageMoved: _onImageMoved,
                            cornerDotBuilder:
                                (double size, EdgeAlignment alignment) {
                              return MouseRegion(
                                cursor: _cursorForCorner(alignment),
                                child: DotControl(
                                  color: colorScheme.surface,
                                ),
                              );
                            },
                            onCropped: (CropResult result) {
                              if (!mounted) {
                                return;
                              }
                              switch (result) {
                                case CropSuccess(
                                  :final Uint8List croppedImage,
                                ):
                                  setState(() {
                                    _isCropping = false;
                                    _previewBytes = croppedImage;
                                  });
                                case CropFailure():
                                  setState(() {
                                    _isCropping = false;
                                  });
                              }
                            },
                          ),
                          ..._buildEdgeHandles(colorScheme),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
      actions: showingPreview
          ? <Widget>[
              AppButton.tertiary(
                label: l10n.commonCancelActionLabel,
                leadingIcon: Icons.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
              AppButton.secondary(
                label: l10n.appImageCropRecropAction,
                leadingIcon: Icons.crop_outlined,
                onPressed: _returnToCrop,
              ),
              AppButton.primary(
                label: l10n.appImageCropConfirmAction,
                leadingIcon: Icons.check,
                onPressed: () => Navigator.of(context).pop(previewBytes),
              ),
            ]
          : <Widget>[
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
                leadingIcon: Icons.preview_outlined,
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

enum _CropEdge { top, right, bottom, left }

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
