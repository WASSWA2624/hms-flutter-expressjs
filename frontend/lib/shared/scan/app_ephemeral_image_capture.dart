import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_image_crop_dialog.dart';
import 'package:hosspi_hms/shared/components/app_image_upload_field.dart';
import 'package:hosspi_hms/shared/scan/app_ephemeral_camera_stub.dart'
    if (dart.library.html) 'package:hosspi_hms/shared/scan/app_ephemeral_camera_web.dart'
    as camera;
import 'package:hosspi_hms/shared/scan/app_live_camera.dart' as live_camera;

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

/// Camera-preferring capture into memory.
///
/// Prefers a live MediaStream viewfinder when available, then the platform
/// capture input. When [allowFileFallback] is false (Take photo), unsupported
/// platforms return null instead of silently opening the gallery picker.
Future<AppImageUploadPendingItem?> takeEphemeralImage(
  BuildContext context, {
  bool enableCrop = true,
  bool allowFileFallback = false,
  String? liveCameraTitle,
  String? liveCameraCaptureLabel,
  String? liveCameraCloseLabel,
}) async {
  Uint8List? bytes;
  String fileName = 'pack-photo.jpg';
  String? mimeType = 'image/jpeg';

  if (live_camera.liveCameraCaptureSupported && context.mounted) {
    bytes = await live_camera.captureLiveCameraFrame(
      context: context,
      title: liveCameraTitle ?? 'Take pack photo',
      captureLabel: liveCameraCaptureLabel ?? 'Capture',
      closeLabel: liveCameraCloseLabel ?? 'Cancel',
    );
  }

  if (bytes == null) {
    final ({Uint8List bytes, String fileName, String? mimeType})? captured =
        await camera.pickEphemeralCameraImageBytes();
    if (captured != null) {
      bytes = captured.bytes;
      fileName = captured.fileName;
      mimeType = captured.mimeType;
    }
  }

  if (bytes == null) {
    if (allowFileFallback && !camera.ephemeralCameraCaptureSupported) {
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
