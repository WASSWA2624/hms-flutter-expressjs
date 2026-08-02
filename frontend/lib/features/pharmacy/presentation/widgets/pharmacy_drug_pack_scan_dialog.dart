import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/scan/scan.dart';

/// Assistive pack scan: barcode entry, multi-photo OCR, optional text parse.
/// Returns candidates or null when skipped/cancelled. Never persists images.
Future<DrugPackFieldCandidates?> showPharmacyDrugPackScanDialog(
  BuildContext context, {
  AppOcrService? ocrService,
  AppBarcodeDecoder? barcodeDecoder,
  DrugPackFieldParser? parser,
}) {
  return showAppDialog<DrugPackFieldCandidates?>(
    context: context,
    builder: (_) => _PharmacyDrugPackScanDialog(
      ocrService: ocrService ?? createAppOcrService(),
      barcodeDecoder: barcodeDecoder ?? const AppHeuristicBarcodeDecoder(),
      parser: parser ?? const DrugPackFieldParser(),
    ),
  );
}

class _SessionPhoto {
  _SessionPhoto({required this.bytes, this.mimeType});

  Uint8List bytes;
  String? mimeType;
}

class _PharmacyDrugPackScanDialog extends StatefulWidget {
  const _PharmacyDrugPackScanDialog({
    required this.ocrService,
    required this.barcodeDecoder,
    required this.parser,
  });

  final AppOcrService ocrService;
  final AppBarcodeDecoder barcodeDecoder;
  final DrugPackFieldParser parser;

  @override
  State<_PharmacyDrugPackScanDialog> createState() =>
      _PharmacyDrugPackScanDialogState();
}

class _PharmacyDrugPackScanDialogState
    extends State<_PharmacyDrugPackScanDialog> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _packTextController = TextEditingController();
  final List<_SessionPhoto> _photos = <_SessionPhoto>[];
  bool _busy = false;
  bool _photosNeedProcessing = false;
  int _lastProcessedPhotoCount = 0;
  String? _statusMessage;
  DrugPackFieldCandidates? _preview;

  @override
  void dispose() {
    _barcodeController.dispose();
    _packTextController.dispose();
    _photos.clear();
    super.dispose();
  }

  String? get _barcodeOrNull {
    final String code = _barcodeController.text.trim();
    return code.isEmpty ? null : code;
  }

  bool get _canProcessPhotos =>
      !_busy && _photos.isNotEmpty && _photosNeedProcessing;

  Future<void> _applyBarcode() async {
    final String? code = _barcodeOrNull;
    if (code == null) {
      return;
    }
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await _recomputeCandidates(
        preferBarcode: code,
        includePhotos: !_photosNeedProcessing && _photos.isNotEmpty,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _takePhoto() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final AppImageUploadPendingItem? item = await takeEphemeralImage(context);
      if (!mounted || item == null) {
        return;
      }
      setState(() {
        _photos.add(
          _SessionPhoto(
            bytes: Uint8List.fromList(item.bytes),
            mimeType: item.mimeType,
          ),
        );
        _photosNeedProcessing = true;
        _statusMessage = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.pharmacyDrugScanNoDataBody;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _uploadPhotos() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      // Multi-select first; crop/edit from the strip afterward so batch pick
      // is not blocked by per-file crop cancels.
      final List<AppImageUploadPendingItem> items =
          await uploadEphemeralImages(context, enableCrop: false);
      if (!mounted || items.isEmpty) {
        return;
      }
      setState(() {
        for (final AppImageUploadPendingItem item in items) {
          _photos.add(
            _SessionPhoto(
              bytes: Uint8List.fromList(item.bytes),
              mimeType: item.mimeType,
            ),
          );
        }
        _photosNeedProcessing = true;
        _statusMessage = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.pharmacyDrugScanNoDataBody;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _processAllPhotos() async {
    if (_photos.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _statusMessage = context.l10n.pharmacyDrugScanProcessingPhotosBody;
    });
    try {
      await _recomputeCandidates(includePhotos: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _photosNeedProcessing = false;
        _lastProcessedPhotoCount = _photos.length;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.pharmacyDrugScanNoDataBody;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reeditPhoto(int index) async {
    if (index < 0 || index >= _photos.length) {
      return;
    }
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final Uint8List? edited = await showAppImageCropDialog(
        context: context,
        imageBytes: _photos[index].bytes,
        showAspectPresets: true,
      );
      if (!mounted || edited == null) {
        return;
      }
      setState(() {
        _photos[index]
          ..bytes = edited
          ..mimeType = 'image/png';
        _photosNeedProcessing = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.pharmacyDrugScanNoDataBody;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= _photos.length) {
      return;
    }
    setState(() {
      _photos.removeAt(index);
      _photosNeedProcessing = _photos.isNotEmpty;
      if (_photos.isEmpty) {
        _lastProcessedPhotoCount = 0;
      }
      _statusMessage = null;
    });
  }

  void _clearPhotos() {
    setState(() {
      _photos.clear();
      _photosNeedProcessing = false;
      _lastProcessedPhotoCount = 0;
      _statusMessage = null;
    });
  }

  Future<void> _parsePackText() async {
    if (_packTextController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await _recomputeCandidates(
        includePhotos: !_photosNeedProcessing && _photos.isNotEmpty,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _recomputeCandidates({
    String? preferBarcode,
    bool includePhotos = false,
  }) async {
    DrugPackFieldCandidates? merged;
    final List<String> ocrChunks = <String>[];
    final List<String> ocrLines = <String>[];

    if (includePhotos) {
      for (final _SessionPhoto photo in _photos) {
        final AppBarcodeCaptureResult? barcode = await widget.barcodeDecoder
            .decodeFromImage(photo.bytes, mimeType: photo.mimeType);
        final AppOcrResult ocr = await widget.ocrService.recognize(
          photo.bytes,
          mimeType: photo.mimeType,
        );
        if (ocr.hasText) {
          ocrChunks.add(ocr.text);
          ocrLines.addAll(ocr.lines);
        }
        if (barcode?.code != null && _barcodeController.text.trim().isEmpty) {
          _barcodeController.text = barcode!.code;
        }
        final DrugPackFieldCandidates parsed = widget.parser.parse(
          barcode: barcode?.code ?? preferBarcode ?? _barcodeOrNull,
          ocrText: ocr.text,
          ocrLines: ocr.lines,
        );
        merged = merged == null ? parsed : merged.merge(parsed);
      }
    }

    final String packText = _packTextController.text.trim();
    final String combinedOcr = <String>[
      ...ocrChunks,
      if (packText.isNotEmpty) packText,
    ].join('\n').trim();

    if (combinedOcr.isNotEmpty ||
        preferBarcode != null ||
        _barcodeOrNull != null) {
      final DrugPackFieldCandidates fromText = widget.parser.parse(
        barcode: preferBarcode ?? _barcodeOrNull,
        ocrText: combinedOcr.isEmpty ? packText : combinedOcr,
        ocrLines: ocrLines,
      );
      merged = merged == null ? fromText : merged.merge(fromText);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      if (merged != null && merged.hasAnyIdentityField) {
        _preview = merged;
        _statusMessage = null;
      } else {
        _preview = null;
        final bool attempted = includePhotos ||
            packText.isNotEmpty ||
            preferBarcode != null ||
            _barcodeOrNull != null;
        if (attempted) {
          _statusMessage = context.l10n.pharmacyDrugScanNoDataBody;
        }
      }
    });
  }

  Widget _fieldSuffixAction({
    required String label,
    required IconData icon,
    required bool iconOnly,
    required VoidCallback? onPressed,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: 40,
        maxWidth: iconOnly ? 48 : 168,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: AppButton.secondary(
          label: label,
          leadingIcon: icon,
          iconOnly: iconOnly,
          dense: true,
          enabled: !_busy && onPressed != null,
          tooltip: label,
          onPressed: onPressed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DrugPackFieldCandidates? preview = _preview;
    final bool canPrefill =
        !_busy && preview != null && preview.hasAnyIdentityField;
    final double viewportWidth = MediaQuery.sizeOf(context).width;
    final bool compactFieldActions = viewportWidth < 600;
    final String? photoStatus = _photos.isEmpty
        ? null
        : _photosNeedProcessing
        ? l10n.pharmacyDrugPhotosReadyBody(_photos.length)
        : l10n.pharmacyDrugPhotosProcessedBody(_lastProcessedPhotoCount);

    return AppDialog(
      title: Text(l10n.pharmacyDrugScanPackTitle),
      icon: const Icon(Icons.document_scanner_outlined),
      scrollable: true,
      maxWidth: 640,
      closeEnabled: !_busy,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: _barcodeController,
            labelText: l10n.pharmacyDrugBarcodeLabel,
            helperText: l10n.pharmacyDrugBarcodeHelper,
            enabled: !_busy,
            suffixIcon: _fieldSuffixAction(
              label: l10n.pharmacyDrugBarcodeApplyAction,
              icon: Icons.qr_code_2_outlined,
              iconOnly: compactFieldActions,
              onPressed: _applyBarcode,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: <Widget>[
              AppButton.secondary(
                label: l10n.pharmacyDrugTakePackPhotoAction,
                leadingIcon: Icons.photo_camera_outlined,
                enabled: !_busy,
                onPressed: _takePhoto,
              ),
              AppButton.secondary(
                label: l10n.pharmacyDrugUploadPackPhotoAction,
                leadingIcon: Icons.upload_file_outlined,
                enabled: !_busy,
                onPressed: _uploadPhotos,
              ),
              if (_photos.isNotEmpty)
                AppButton.primary(
                  label: l10n.pharmacyDrugProcessPackPhotosAction,
                  leadingIcon: Icons.document_scanner_outlined,
                  enabled: _canProcessPhotos,
                  isLoading: _busy && _photosNeedProcessing,
                  onPressed: _processAllPhotos,
                ),
              if (_photos.isNotEmpty)
                AppButton.tertiary(
                  label: l10n.pharmacyDrugClearPackPhotosAction,
                  leadingIcon: Icons.delete_outline,
                  enabled: !_busy,
                  onPressed: _clearPhotos,
                ),
            ],
          ),
          if (_photos.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            if (photoStatus != null)
              Text(
                photoStatus,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            SizedBox(height: theme.spacing.sm),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, _) => SizedBox(width: theme.spacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  final _SessionPhoto photo = _photos[index];
                  return _PackPhotoThumb(
                    bytes: photo.bytes,
                    enabled: !_busy,
                    editLabel: l10n.pharmacyDrugEditPackPhotoAction,
                    removeLabel: l10n.pharmacyDrugRemovePackPhotoAction,
                    onEdit: () => _reeditPhoto(index),
                    onRemove: () => _removePhoto(index),
                  );
                },
              ),
            ),
          ],
          SizedBox(height: theme.spacing.md),
          AppTextField(
            controller: _packTextController,
            labelText: l10n.pharmacyDrugPackTextLabel,
            helperText: l10n.pharmacyDrugPackTextHelper,
            enabled: !_busy,
            maxLines: 5,
            minLines: 3,
            suffixIcon: _fieldSuffixAction(
              label: l10n.pharmacyDrugPastePackTextAction,
              icon: Icons.notes_outlined,
              iconOnly: compactFieldActions,
              onPressed: _parsePackText,
            ),
          ),
          if (_statusMessage != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              _statusMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _busy
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
            ),
          ],
          if (preview != null && preview.hasAnyIdentityField) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            AppFormInformationBanner(
              title: l10n.pharmacyDrugSuggestedBannerTitle,
              message: <String?>[
                preview.brandName,
                preview.genericName,
                preview.form,
                preview.strength,
                preview.code,
                preview.batchNumber,
              ]
                  .whereType<String>()
                  .where((String v) => v.trim().isNotEmpty)
                  .join(' · '),
              variant: AppFormInformationVariant.success,
            ),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.pharmacyDrugScanSkipAction,
          leadingIcon: Icons.skip_next_outlined,
          enabled: !_busy,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.pharmacyDrugScanApplyAction,
          leadingIcon: Icons.playlist_add_check_outlined,
          enabled: canPrefill,
          onPressed: () => Navigator.of(context).pop(preview),
        ),
      ],
    );
  }
}

class _PackPhotoThumb extends StatelessWidget {
  const _PackPhotoThumb({
    required this.bytes,
    required this.enabled,
    required this.editLabel,
    required this.removeLabel,
    required this.onEdit,
    required this.onRemove,
  });

  final Uint8List bytes;
  final bool enabled;
  final String editLabel;
  final String removeLabel;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 88,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(theme.radius.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onEdit : null,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: AppButton.tertiary(
              label: removeLabel,
              icon: Icons.close,
              iconOnly: true,
              dense: true,
              tooltip: removeLabel,
              onPressed: enabled ? onRemove : null,
            ),
          ),
          Positioned(
            bottom: 2,
            left: 2,
            child: AppButton.tertiary(
              label: editLabel,
              icon: Icons.crop_rotate,
              iconOnly: true,
              dense: true,
              tooltip: editLabel,
              onPressed: enabled ? onEdit : null,
            ),
          ),
        ],
      ),
    );
  }
}
