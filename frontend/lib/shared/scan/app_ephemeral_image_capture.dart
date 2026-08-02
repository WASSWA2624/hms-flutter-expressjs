import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_image_crop_dialog.dart';
import 'package:hosspi_hms/shared/components/app_image_upload_field.dart';
import 'package:hosspi_hms/shared/scan/app_ephemeral_camera_stub.dart'
    if (dart.library.html) 'package:hosspi_hms/shared/scan/app_ephemeral_camera_web.dart'
    as camera;

/// Picks an image into memory only (camera/gallery/file). Caller must discard
/// bytes after parse — never upload to media APIs.
Future<AppImageUploadPendingItem?> captureEphemeralImage(
  BuildContext context, {
  bool enableCrop = true,
}) {
  return uploadEphemeralImage(context, enableCrop: enableCrop);
}

/// Gallery / file upload into memory, optionally through the crop editor.
Future<AppImageUploadPendingItem?> uploadEphemeralImage(
  BuildContext context, {
  bool enableCrop = true,
}) {
  return pickAppImageFile(
    context.l10n,
    context: context,
    enableCrop: enableCrop,
  );
}

/// Multi-select gallery / file upload into memory. Optionally crops each image.
Future<List<AppImageUploadPendingItem>> uploadEphemeralImages(
  BuildContext context, {
  bool enableCrop = true,
}) {
  return pickAppImageFiles(
    context.l10n,
    context: context,
    enableCrop: enableCrop,
  );
}

/// Camera-preferring capture into memory. Falls back to file upload when the
/// platform has no capture input. Optionally opens the crop editor.
Future<AppImageUploadPendingItem?> takeEphemeralImage(
  BuildContext context, {
  bool enableCrop = true,
}) async {
  final ({Uint8List bytes, String fileName, String? mimeType})? captured =
      await camera.pickEphemeralCameraImageBytes();
  if (captured == null) {
    if (!camera.ephemeralCameraCaptureSupported) {
      // Desktop / unsupported capture → shared file picker fallback.
      if (!context.mounted) {
        return null;
      }
      return uploadEphemeralImage(context, enableCrop: enableCrop);
    }
    return null;
  }
  if (!context.mounted) {
    return null;
  }

  Uint8List bytes = captured.bytes;
  String fileName = captured.fileName;
  String? mimeType = captured.mimeType;

  if (enableCrop) {
    final Uint8List? cropped = await showAppImageCropDialog(
      context: context,
      imageBytes: bytes,
      showAspectPresets: true,
    );
    if (cropped == null) {
      return null;
    }
    bytes = cropped;
    fileName = _ensureCroppedName(fileName);
    mimeType = 'image/png';
  }

  return AppImageUploadPendingItem(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
}

/// Convenience alias so pharmacy/peers share one entry point.
Future<List<Uint8List>> captureEphemeralImageBytes(
  BuildContext context, {
  bool enableCrop = true,
}) async {
  final AppImageUploadPendingItem? item = await captureEphemeralImage(
    context,
    enableCrop: enableCrop,
  );
  if (item == null) {
    return const <Uint8List>[];
  }
  return <Uint8List>[Uint8List.fromList(item.bytes)];
}

String _ensureCroppedName(String originalFileName) {
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
  final String withSuffix = stem.endsWith('-cropped') ? stem : '$stem-cropped';
  return '$withSuffix.png';
}
