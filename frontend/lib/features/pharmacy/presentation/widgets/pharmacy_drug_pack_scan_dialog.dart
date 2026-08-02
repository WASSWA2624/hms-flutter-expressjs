import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/scan/scan.dart';

/// Assistive pack scan: barcode-first, OCR photo fallback. Returns candidates
/// or null when skipped/cancelled. Never persists images.
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
  bool _busy = false;
  String? _statusMessage;
  DrugPackFieldCandidates? _preview;

  @override
  void dispose() {
    _barcodeController.dispose();
    _packTextController.dispose();
    super.dispose();
  }

  Future<void> _applyBarcode() async {
    final String code = _barcodeController.text.trim();
    if (code.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final DrugPackFieldCandidates parsed = widget.parser.parse(
        barcode: code,
        ocrText: _packTextController.text,
      );
      setState(() {
        _preview = parsed;
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _statusMessage = context.l10n.pharmacyDrugScanNoDataBody;
      });
    }
  }

  Future<void> _capturePhoto() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    Uint8List? bytes;
    String? mimeType;
    try {
      final item = await captureEphemeralImage(context, enableCrop: false);
      if (item == null) {
        setState(() => _busy = false);
        return;
      }
      bytes = Uint8List.fromList(item.bytes);
      mimeType = item.mimeType;

      AppBarcodeCaptureResult? barcode;
      if (widget.barcodeDecoder is AppHeuristicBarcodeDecoder) {
        barcode = await widget.barcodeDecoder.decodeFromImage(
          bytes,
          mimeType: mimeType,
        );
      } else {
        barcode = await widget.barcodeDecoder.decodeFromImage(
          bytes,
          mimeType: mimeType,
        );
      }

      final AppOcrResult ocr = await widget.ocrService.recognize(
        bytes,
        mimeType: mimeType,
      );
      if (ocr.hasText && _packTextController.text.trim().isEmpty) {
        _packTextController.text = ocr.text;
      } else if (ocr.hasText) {
        _packTextController.text =
            '${_packTextController.text.trim()}\n${ocr.text}'.trim();
      }

      final String? barcodeCode =
          barcode?.code ??
          (widget.barcodeDecoder is AppHeuristicBarcodeDecoder
              ? (widget.barcodeDecoder as AppHeuristicBarcodeDecoder)
                    .decodeFromText(_packTextController.text)
                    ?.code
              : null) ??
          (_barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim());
      if (barcodeCode != null && _barcodeController.text.trim().isEmpty) {
        _barcodeController.text = barcodeCode;
      }

      final DrugPackFieldCandidates parsed = widget.parser.parse(
        barcode: barcodeCode,
        ocrText: _packTextController.text,
        ocrLines: ocr.lines,
      );
      setState(() {
        _preview = parsed.hasAnyIdentityField ? parsed : _preview;
        _busy = false;
        if (!parsed.hasAnyIdentityField) {
          _statusMessage = context.l10n.pharmacyDrugScanNoDataBody;
        }
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _statusMessage = context.l10n.pharmacyDrugScanNoDataBody;
      });
    } finally {
      // Drop ephemeral buffers explicitly.
      bytes = null;
    }
  }

  void _parsePackText() {
    final DrugPackFieldCandidates parsed = widget.parser.parse(
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      ocrText: _packTextController.text,
    );
    setState(() {
      _preview = parsed.hasAnyIdentityField ? parsed : null;
      _statusMessage = parsed.hasAnyIdentityField
          ? null
          : context.l10n.pharmacyDrugScanNoDataBody;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DrugPackFieldCandidates? preview = _preview;

    return AppDialog(
      title: Text(l10n.pharmacyDrugScanPackTitle),
      icon: const Icon(Icons.qr_code_scanner_outlined),
      scrollable: true,
      maxWidth: 640,
      closeEnabled: !_busy,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.pharmacyDrugScanPackBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppTextField(
              controller: _barcodeController,
              labelText: l10n.pharmacyDrugBarcodeLabel,
              enabled: !_busy,
            ),
            right: AppButton.secondary(
              label: l10n.pharmacyDrugBarcodeApplyAction,
              leadingIcon: Icons.qr_code_2_outlined,
              enabled: !_busy,
              onPressed: _applyBarcode,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: <Widget>[
              AppButton.secondary(
                label: l10n.pharmacyDrugCapturePackPhotoAction,
                leadingIcon: Icons.photo_camera_outlined,
                enabled: !_busy,
                isLoading: _busy,
                onPressed: _capturePhoto,
              ),
              AppButton.tertiary(
                label: l10n.pharmacyDrugPastePackTextAction,
                leadingIcon: Icons.content_paste_outlined,
                enabled: !_busy,
                onPressed: _parsePackText,
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          AppTextField(
            controller: _packTextController,
            labelText: l10n.pharmacyDrugPackTextLabel,
            enabled: !_busy,
            maxLines: 6,
            minLines: 3,
            onChanged: (_) {},
          ),
          if (_statusMessage != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              _statusMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
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
              ].whereType<String>().where((String v) => v.trim().isNotEmpty).join(' · '),
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
          enabled: !_busy && preview != null && preview.hasAnyIdentityField,
          onPressed: () => Navigator.of(context).pop(preview),
        ),
      ],
    );
  }
}
