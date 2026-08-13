import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/ai/ai_models.dart';
import 'package:hosspi_hms/core/ai/ai_repository.dart';
import 'package:hosspi_hms/core/ai/ai_repository_impl.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/shared/components/app_image_transform.dart';
import 'package:hosspi_hms/shared/scan/scan.dart';

final drugPackAiMapperProvider = Provider<DrugPackAiMapper>((ref) {
  return DrugPackRemoteAiMapper(repository: ref.watch(aiRepositoryProvider));
});

/// Sends pack photos (and optional OCR text) to backend `drug_pack_extract`.
final class DrugPackRemoteAiMapper implements DrugPackAiMapper {
  DrugPackRemoteAiMapper({
    required AiRepository repository,
    this.maxImages = 4,
  }) : _repository = repository;

  final AiRepository _repository;
  final int maxImages;

  @override
  Future<DrugPackAiMapResult> map({
    required String rawText,
    String? barcode,
    List<String> ocrLines = const <String>[],
    List<DrugPackAiImage> images = const <DrugPackAiImage>[],
  }) async {
    final String ocrText = rawText.trim().isNotEmpty
        ? rawText.trim()
        : ocrLines
              .map((String line) => line.trim())
              .where((String line) => line.isNotEmpty)
              .join('\n');
    final List<Map<String, Object?>> encoded = images
        .take(maxImages)
        .map(_encodeImage)
        .where((Map<String, Object?> item) => item.isNotEmpty)
        .toList(growable: false);

    if (encoded.isEmpty && ocrText.isEmpty) {
      return const DrugPackAiMapResult.unavailable();
    }

    final CancelToken cancelToken = CancelToken();
    final Result<AiTaskResult> taskResult = await _repository.runTask(
      'drug_pack_extract',
      <String, Object?>{
        if (encoded.isNotEmpty) 'images': encoded,
        if (ocrText.isNotEmpty) 'ocr_text': ocrText,
        if (barcode != null && barcode.trim().isNotEmpty)
          'barcode': barcode.trim(),
      },
      cancelToken: cancelToken,
    );

    return taskResult.when(
      success: (AiTaskResult result) {
        if (result.degraded) {
          return const DrugPackAiMapResult.unavailable();
        }
        final DrugPackFieldCandidates candidates =
            DrugPackFieldCandidates.fromAiOutput(result.output);
        return DrugPackAiMapResult(candidates: candidates);
      },
      failure: (_) => const DrugPackAiMapResult.unavailable(),
    );
  }

  Map<String, Object?> _encodeImage(DrugPackAiImage image) {
    if (image.bytes.isEmpty) {
      return const <String, Object?>{};
    }
    final Uint8List compressed = encodeAppImageForAi(image.bytes);
    if (compressed.isEmpty) {
      return const <String, Object?>{};
    }
    return <String, Object?>{
      'mime_type': 'image/jpeg',
      'data': base64Encode(compressed),
    };
  }
}
