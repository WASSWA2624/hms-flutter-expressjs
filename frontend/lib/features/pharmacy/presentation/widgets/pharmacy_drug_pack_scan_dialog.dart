import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/scan/scan.dart';
import 'package:intl/intl.dart';

/// Assistive pack scan: barcode, multi-photo OCR/AI, raw text parse.
/// Returns candidates or null when skipped/cancelled. Never persists images.
Future<DrugPackFieldCandidates?> showPharmacyDrugPackScanDialog(
  BuildContext context, {
  AppOcrService? ocrService,
  AppBarcodeDecoder? barcodeDecoder,
  DrugPackFieldParser? parser,
  DrugPackAiMapper? aiMapper,
  DrugPackBarcodeLookup? barcodeLookup,
  List<Uint8List>? seedPhotos,
}) {
  return showAppDialog<DrugPackFieldCandidates?>(
    context: context,
    builder: (_) => _PharmacyDrugPackScanDialog(
      ocrService: ocrService ?? createAppOcrService(),
      barcodeDecoder: barcodeDecoder ?? const AppHeuristicBarcodeDecoder(),
      parser: parser ?? const DrugPackFieldParser(),
      aiMapper: aiMapper ?? createDefaultDrugPackAiMapper(),
      barcodeLookup: barcodeLookup ?? createDefaultDrugPackBarcodeLookup(),
      seedPhotos: seedPhotos,
    ),
  );
}

enum _PhotoEngine { ocr, ai }

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
    required this.aiMapper,
    required this.barcodeLookup,
    this.seedPhotos,
  });

  final AppOcrService ocrService;
  final AppBarcodeDecoder barcodeDecoder;
  final DrugPackFieldParser parser;
  final DrugPackAiMapper aiMapper;
  final DrugPackBarcodeLookup barcodeLookup;
  final List<Uint8List>? seedPhotos;

  @override
  State<_PharmacyDrugPackScanDialog> createState() =>
      _PharmacyDrugPackScanDialogState();
}

class _PharmacyDrugPackScanDialogState
    extends State<_PharmacyDrugPackScanDialog> {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _packTextController = TextEditingController();
  final TextEditingController _genericController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _formController = TextEditingController();
  final TextEditingController _strengthController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _manufacturedController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final List<_SessionPhoto> _photos = <_SessionPhoto>[];

  bool _busy = false;
  bool _photosNeedProcessing = false;
  bool _hasSuggestions = false;
  int _lastProcessedPhotoCount = 0;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final List<Uint8List>? seeds = widget.seedPhotos;
    if (seeds != null && seeds.isNotEmpty) {
      for (final Uint8List bytes in seeds) {
        _photos.add(_SessionPhoto(bytes: bytes, mimeType: 'image/png'));
      }
      _photosNeedProcessing = true;
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _packTextController.dispose();
    _genericController.dispose();
    _brandController.dispose();
    _formController.dispose();
    _strengthController.dispose();
    _codeController.dispose();
    _batchController.dispose();
    _manufacturedController.dispose();
    _expiryController.dispose();
    _photos.clear();
    super.dispose();
  }

  String? get _barcodeOrNull {
    final String code = _barcodeController.text.trim();
    return code.isEmpty ? null : code;
  }

  bool get _canProcessPhotos => !_busy && _photos.isNotEmpty;

  DrugPackFieldCandidates _candidatesFromEditors() {
    return DrugPackFieldCandidates(
      genericName: _emptyToNull(_genericController.text),
      brandName: _emptyToNull(_brandController.text),
      form: _emptyToNull(_formController.text),
      strength: _emptyToNull(_strengthController.text),
      code: _emptyToNull(_codeController.text),
      batchNumber: _emptyToNull(_batchController.text),
      manufacturedAt: _parseDate(_manufacturedController.text),
      expiryDate: _parseDate(_expiryController.text),
      barcode: _barcodeOrNull,
      rawText: _emptyToNull(_packTextController.text),
    );
  }

  bool get _canPrefill {
    if (_busy) {
      return false;
    }
    return _candidatesFromEditors().hasAnyIdentityField;
  }

  void _seedEditors(DrugPackFieldCandidates candidates) {
    _genericController.text = candidates.genericName?.trim() ?? '';
    _brandController.text = candidates.brandName?.trim() ?? '';
    _formController.text = candidates.form?.trim() ?? '';
    _strengthController.text = candidates.strength?.trim() ?? '';
    _codeController.text = candidates.code?.trim() ?? '';
    _batchController.text = candidates.batchNumber?.trim() ?? '';
    _manufacturedController.text = candidates.manufacturedAt == null
        ? ''
        : _dateFormat.format(candidates.manufacturedAt!);
    _expiryController.text = candidates.expiryDate == null
        ? ''
        : _dateFormat.format(candidates.expiryDate!);
    _hasSuggestions = candidates.hasAnyIdentityField;
  }

  void _clearEditors() {
    _genericController.clear();
    _brandController.clear();
    _formController.clear();
    _strengthController.clear();
    _codeController.clear();
    _batchController.clear();
    _manufacturedController.clear();
    _expiryController.clear();
    _hasSuggestions = false;
  }

  static String? _emptyToNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _parseDate(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(trimmed);
  }

  Future<void> _applyBarcode() async {
    final String? code = _barcodeOrNull;
    if (code == null) {
      return;
    }
    setState(() {
      _busy = true;
      _statusMessage = context.l10n.pharmacyDrugBarcodeLookupBusyBody;
    });
    try {
      await _mapBarcode(code);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _mapBarcode(String code) async {
    DrugPackFieldCandidates parsed = widget.parser.parse(
      barcode: code,
      ocrText: _packTextController.text,
    );
    bool lookupMiss = false;
    try {
      final DrugPackFieldCandidates? lookedUp = await widget.barcodeLookup
          .lookup(code);
      if (lookedUp != null && lookedUp.hasAnyIdentityField) {
        parsed = parsed.merge(lookedUp);
      } else if (!parsed.hasAnyIdentityField) {
        lookupMiss = true;
      }
    } catch (_) {
      // Soft-fail lookup; keep parser result.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      if (parsed.hasAnyIdentityField) {
        _seedEditors(parsed);
        _statusMessage = null;
      } else {
        _codeController.text = code;
        _hasSuggestions = true;
        _statusMessage = lookupMiss
            ? context.l10n.pharmacyDrugBarcodeLookupMissBody
            : null;
      }
    });
  }

  Future<void> _scanBarcode() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final AppLocalizations l10n = context.l10n;
      String? code = await scanLiveBarcode(
        context: context,
        title: l10n.pharmacyDrugScanBarcodeTitle,
        body: l10n.pharmacyDrugScanBarcodeBody,
        closeLabel: l10n.commonCancelActionLabel,
        unavailableBody: l10n.pharmacyDrugScanBarcodeUnavailableBody,
      );
      if (!mounted) {
        return;
      }

      if (code == null || code.trim().isEmpty) {
        // Fallback: still-image capture + decode (desktop / no BarcodeDetector).
        final AppImageUploadPendingItem? item = await takeEphemeralImage(
          context,
          enableCrop: false,
          allowFileFallback: true,
          liveCameraTitle: l10n.pharmacyDrugCameraCaptureTitle,
          liveCameraCaptureLabel: l10n.pharmacyDrugCameraCaptureAction,
          liveCameraCloseLabel: l10n.commonCancelActionLabel,
        );
        if (!mounted || item == null) {
          return;
        }
        final Uint8List bytes = Uint8List.fromList(item.bytes);
        AppBarcodeCaptureResult? decoded = await widget.barcodeDecoder
            .decodeFromImage(bytes, mimeType: item.mimeType);
        if (decoded == null) {
          final AppOcrResult ocr = await widget.ocrService.recognize(
            bytes,
            mimeType: item.mimeType,
          );
          if (widget.barcodeDecoder is AppHeuristicBarcodeDecoder) {
            decoded = (widget.barcodeDecoder as AppHeuristicBarcodeDecoder)
                .decodeFromText(ocr.text);
          }
        }
        if (!mounted) {
          return;
        }
        if (decoded == null || decoded.code.trim().isEmpty) {
          setState(() {
            _statusMessage = l10n.pharmacyDrugScanBarcodeEmptyBody;
          });
          return;
        }
        code = decoded.code.trim();
      }

      _barcodeController.text = code.trim();
      setState(() {
        _statusMessage = l10n.pharmacyDrugBarcodeLookupBusyBody;
      });
      await _mapBarcode(code.trim());
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.pharmacyDrugScanBarcodeEmptyBody;
        });
      }
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
      final AppLocalizations l10n = context.l10n;
      final AppImageUploadPendingItem? item = await takeEphemeralImage(
        context,
        liveCameraTitle: l10n.pharmacyDrugCameraCaptureTitle,
        liveCameraCaptureLabel: l10n.pharmacyDrugCameraCaptureAction,
        liveCameraCloseLabel: l10n.commonCancelActionLabel,
      );
      if (!mounted) {
        return;
      }
      if (item == null) {
        setState(() {
          _statusMessage = l10n.pharmacyDrugCameraUnavailableBody;
        });
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
          _statusMessage = context.l10n.pharmacyDrugCameraUnavailableBody;
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

  Future<void> _processPhotos(_PhotoEngine engine) async {
    if (_photos.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _statusMessage = engine == _PhotoEngine.ai
          ? context.l10n.pharmacyDrugScanProcessingAiBody
          : context.l10n.pharmacyDrugScanProcessingPhotosBody;
    });
    try {
      final ({List<String> chunks, List<String> lines, DrugPackFieldCandidates? merged})
      ocrPass = await _runOcrAcrossPhotos();
      DrugPackFieldCandidates? merged = ocrPass.merged;

      if (engine == _PhotoEngine.ai) {
        final DrugPackAiMapResult ai = await widget.aiMapper.map(
          rawText: <String>[
            ...ocrPass.chunks,
            if (_packTextController.text.trim().isNotEmpty)
              _packTextController.text.trim(),
          ].join('\n'),
          barcode: _barcodeOrNull,
          ocrLines: ocrPass.lines,
        );
        if (!mounted) {
          return;
        }
        if (ai.unavailable) {
          setState(() {
            _statusMessage = ai.message?.trim().isNotEmpty == true
                ? ai.message
                : context.l10n.pharmacyDrugScanAiUnavailableBody;
          });
          // Fall back to OCR merge already computed.
        } else if (ai.hasCandidates) {
          merged = merged == null
              ? ai.candidates
              : merged.merge(ai.candidates!);
        }
      }

      final String packText = _packTextController.text.trim();
      if (packText.isNotEmpty || _barcodeOrNull != null) {
        final DrugPackFieldCandidates fromText = widget.parser.parse(
          barcode: _barcodeOrNull,
          ocrText: <String>[
            ...ocrPass.chunks,
            if (packText.isNotEmpty) packText,
          ].join('\n'),
          ocrLines: ocrPass.lines,
        );
        merged = merged == null ? fromText : merged.merge(fromText);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _photosNeedProcessing = false;
        _lastProcessedPhotoCount = _photos.length;
        if (merged != null && merged.hasAnyIdentityField) {
          _seedEditors(merged);
          if (_statusMessage == context.l10n.pharmacyDrugScanAiUnavailableBody ||
              (_statusMessage?.contains('AI') ?? false)) {
            // Keep AI-unavailable notice if set above.
          } else {
            _statusMessage = null;
          }
        } else {
          _clearEditors();
          _statusMessage ??= context.l10n.pharmacyDrugScanNoDataBody;
        }
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

  Future<
    ({
      List<String> chunks,
      List<String> lines,
      DrugPackFieldCandidates? merged,
    })
  >
  _runOcrAcrossPhotos() async {
    DrugPackFieldCandidates? merged;
    final List<String> chunks = <String>[];
    final List<String> lines = <String>[];
    for (final _SessionPhoto photo in _photos) {
      final AppBarcodeCaptureResult? barcode = await widget.barcodeDecoder
          .decodeFromImage(photo.bytes, mimeType: photo.mimeType);
      final AppOcrResult ocr = await widget.ocrService.recognize(
        photo.bytes,
        mimeType: photo.mimeType,
      );
      if (ocr.hasText) {
        chunks.add(ocr.text);
        lines.addAll(ocr.lines);
      }
      if (barcode?.code != null && _barcodeController.text.trim().isEmpty) {
        _barcodeController.text = barcode!.code;
      }
      final DrugPackFieldCandidates parsed = widget.parser.parse(
        barcode: barcode?.code ?? _barcodeOrNull,
        ocrText: ocr.text,
        ocrLines: ocr.lines,
      );
      merged = merged == null ? parsed : merged.merge(parsed);
    }
    return (chunks: chunks, lines: lines, merged: merged);
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

  Future<void> _parsePackText({required bool useAi}) async {
    if (_packTextController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _statusMessage = useAi
          ? context.l10n.pharmacyDrugScanProcessingAiBody
          : null;
    });
    try {
      final String packText = _packTextController.text.trim();
      DrugPackFieldCandidates merged = widget.parser.parse(
        barcode: _barcodeOrNull,
        ocrText: packText,
      );
      if (useAi) {
        final DrugPackAiMapResult ai = await widget.aiMapper.map(
          rawText: packText,
          barcode: _barcodeOrNull,
        );
        if (!mounted) {
          return;
        }
        if (ai.unavailable) {
          setState(() {
            _statusMessage = ai.message?.trim().isNotEmpty == true
                ? ai.message
                : context.l10n.pharmacyDrugScanAiUnavailableBody;
          });
        } else if (ai.hasCandidates) {
          merged = merged.merge(ai.candidates!);
          _statusMessage = null;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        if (merged.hasAnyIdentityField) {
          _seedEditors(merged);
          _statusMessage ??= null;
        } else {
          _clearEditors();
          _statusMessage ??= context.l10n.pharmacyDrugScanNoDataBody;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
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

  Widget _suggestedRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required AppLocalizations l10n,
    required ThemeData theme,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.sm),
            child: Icon(icon, size: theme.appTokens.listIconSize),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: AppTextField(
              controller: controller,
              labelText: label,
              hintText: l10n.pharmacyDrugSuggestedEditableHint,
              enabled: !_busy,
              onChanged: (_) => setState(() {
                _hasSuggestions = _candidatesFromEditors().hasAnyIdentityField;
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
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
            enableSpeechToText: false,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppSpeechToTextButton(
                  controller: _barcodeController,
                  enabled: !_busy,
                  dense: true,
                ),
                _fieldSuffixAction(
                  label: l10n.pharmacyDrugBarcodeApplyAction,
                  icon: Icons.qr_code_2_outlined,
                  iconOnly: compactFieldActions,
                  onPressed: _applyBarcode,
                ),
              ],
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
              AppButton.secondary(
                label: l10n.pharmacyDrugScanBarcodeAction,
                leadingIcon: Icons.qr_code_scanner_outlined,
                enabled: !_busy,
                onPressed: _scanBarcode,
              ),
            ],
          ),
          if (_photos.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(theme.radius.md),
                border: Border.all(color: colors.outlineVariant),
                color: colors.surfaceContainerLowest,
              ),
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            l10n.pharmacyDrugPhotosSectionTitle,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        AppButton.tertiary(
                          label: l10n.pharmacyDrugClearPackPhotosAction,
                          icon: Icons.delete_outline,
                          iconOnly: true,
                          dense: true,
                          enabled: !_busy,
                          tooltip: l10n.pharmacyDrugClearPackPhotosAction,
                          onPressed: _clearPhotos,
                        ),
                      ],
                    ),
                    if (photoStatus != null) ...<Widget>[
                      SizedBox(height: theme.spacing.xs),
                      Text(
                        photoStatus,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    SizedBox(height: theme.spacing.sm),
                    SizedBox(
                      height: 88,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(width: theme.spacing.sm),
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
                ),
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                AppButton.primary(
                  label: l10n.pharmacyDrugProcessPackPhotosOcrAction,
                  leadingIcon: Icons.document_scanner_outlined,
                  enabled: _canProcessPhotos,
                  isLoading: _busy && _photos.isNotEmpty,
                  onPressed: () => _processPhotos(_PhotoEngine.ocr),
                ),
                AppButton.secondary(
                  label: l10n.pharmacyDrugProcessPackPhotosAiAction,
                  leadingIcon: Icons.auto_awesome,
                  enabled: _canProcessPhotos,
                  onPressed: () => _processPhotos(_PhotoEngine.ai),
                ),
              ],
            ),
          ],
          SizedBox(height: theme.spacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.pharmacyDrugPackTextSectionTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              AppButton.secondary(
                label: l10n.pharmacyDrugPastePackTextAction,
                leadingIcon: Icons.notes_outlined,
                dense: true,
                enabled: !_busy,
                onPressed: () => _parsePackText(useAi: false),
              ),
              SizedBox(width: theme.spacing.xs),
              AppButton.tertiary(
                label: l10n.pharmacyDrugProcessPackPhotosAiAction,
                leadingIcon: Icons.auto_awesome,
                dense: true,
                iconOnly: compactFieldActions,
                enabled: !_busy,
                tooltip: l10n.pharmacyDrugProcessPackPhotosAiAction,
                onPressed: () => _parsePackText(useAi: true),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          AppTextField(
            controller: _packTextController,
            labelText: l10n.pharmacyDrugPackTextLabel,
            helperText: l10n.pharmacyDrugPackTextHelper,
            enabled: !_busy,
            maxLines: 5,
            minLines: 3,
          ),
          if (_statusMessage != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              _statusMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _busy ? colors.onSurfaceVariant : colors.error,
              ),
            ),
          ],
          if (_hasSuggestions) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(theme.radius.md),
                border: Border.all(
                  color: colors.tertiary.withValues(alpha: 0.55),
                ),
                color: colors.tertiaryContainer.withValues(alpha: 0.28),
              ),
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.pharmacyDrugScanSuggestedTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      l10n.pharmacyDrugScanSuggestedBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: theme.spacing.md),
                    _suggestedRow(
                      icon: Icons.science_outlined,
                      label: l10n.pharmacyDrugGenericNameLabel,
                      controller: _genericController,
                      l10n: l10n,
                      theme: theme,
                    ),
                    _suggestedRow(
                      icon: Icons.sell_outlined,
                      label: l10n.pharmacyDrugBrandNameLabel,
                      controller: _brandController,
                      l10n: l10n,
                      theme: theme,
                    ),
                    _suggestedRow(
                      icon: Icons.medication_outlined,
                      label: l10n.pharmacyDrugFormLabel,
                      controller: _formController,
                      l10n: l10n,
                      theme: theme,
                    ),
                    _suggestedRow(
                      icon: Icons.straighten,
                      label: l10n.pharmacyDrugStrengthLabel,
                      controller: _strengthController,
                      l10n: l10n,
                      theme: theme,
                    ),
                    _suggestedRow(
                      icon: Icons.tag,
                      label: l10n.pharmacyDrugCodeLabel,
                      controller: _codeController,
                      l10n: l10n,
                      theme: theme,
                    ),
                    _suggestedRow(
                      icon: Icons.qr_code_2_outlined,
                      label: l10n.pharmacyBatchNumberLabel,
                      controller: _batchController,
                      l10n: l10n,
                      theme: theme,
                    ),
                    _suggestedRow(
                      icon: Icons.precision_manufacturing_outlined,
                      label: l10n.pharmacyManufacturingDateLabel,
                      controller: _manufacturedController,
                      l10n: l10n,
                      theme: theme,
                    ),
                    _suggestedRow(
                      icon: Icons.event_outlined,
                      label: l10n.pharmacyExpiryDateLabel,
                      controller: _expiryController,
                      l10n: l10n,
                      theme: theme,
                    ),
                  ],
                ),
              ),
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
          enabled: _canPrefill,
          onPressed: () => Navigator.of(context).pop(_candidatesFromEditors()),
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
