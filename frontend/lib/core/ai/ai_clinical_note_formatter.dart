import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/ai/ai_models.dart';
import 'package:hosspi_hms/core/ai/ai_repository.dart';
import 'package:hosspi_hms/core/ai/ai_repository_impl.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/shared/components/app_speech_ai.dart';

final class AppClinicalNoteAiFormatResult {
  const AppClinicalNoteAiFormatResult({this.text, this.failure});

  final String? text;
  final AppFailure? failure;
}

/// Formats a clinical note draft via backend `clinical_note_format`.
typedef AppClinicalNoteAiFormatter =
    Future<AppClinicalNoteAiFormatResult> Function({
      required String text,
      required AppSpeechAiAbort abort,
      String? locale,
      String? hint,
    });

final aiClinicalNoteFormatterProvider = Provider<AppClinicalNoteAiFormatter?>((
  ref,
) {
  return createAiClinicalNoteFormatter(ref.watch(aiRepositoryProvider));
});

AppClinicalNoteAiFormatter createAiClinicalNoteFormatter(
  AiRepository repository,
) {
  return ({
    required String text,
    required AppSpeechAiAbort abort,
    String? locale,
    String? hint,
  }) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const AppClinicalNoteAiFormatResult();
    }

    final CancelToken cancelToken = CancelToken();
    abort.attach(() {
      cancelToken.cancel();
    });

    final Result<AiTaskResult> taskResult = await repository.runTask(
      'clinical_note_format',
      <String, Object?>{
        'text': trimmed,
        if (locale != null && locale.trim().isNotEmpty) 'locale': locale.trim(),
        if (hint != null && hint.trim().isNotEmpty) 'hint': hint.trim(),
      },
      cancelToken: cancelToken,
    );

    if (cancelToken.isCancelled) {
      return const AppClinicalNoteAiFormatResult();
    }

    return taskResult.when(
      success: (AiTaskResult result) {
        if (result.degraded) {
          return const AppClinicalNoteAiFormatResult();
        }
        final String? formatted = result.formattedText;
        if (formatted == null) {
          return const AppClinicalNoteAiFormatResult();
        }
        return AppClinicalNoteAiFormatResult(text: formatted);
      },
      failure: (AppFailure failure) =>
          AppClinicalNoteAiFormatResult(failure: failure),
    );
  };
}
