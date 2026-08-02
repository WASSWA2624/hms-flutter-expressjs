import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_image_upload_field.dart';

/// Picks an image into memory only (camera/gallery/file). Caller must discard
/// bytes after parse — never upload to media APIs.
Future<AppImageUploadPendingItem?> captureEphemeralImage(
  BuildContext context, {
  bool enableCrop = false,
}) {
  return pickAppImageFile(
    context.l10n,
    context: context,
    enableCrop: enableCrop,
  );
}

/// Convenience alias so pharmacy/peers share one entry point.
Future<List<Uint8List>> captureEphemeralImageBytes(
  BuildContext context, {
  bool enableCrop = false,
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
