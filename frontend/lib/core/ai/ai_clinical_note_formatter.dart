import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/ai/ai_models.dart';
import 'package:hosspi_hms/core/ai/ai_repository.dart';
import 'package:hosspi_hms/core/ai/ai_repository_impl.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/shared/components/app_speech_ai.dart';

/// Formats a clinical note draft via backend `clinical_note_format`.
typedef AppClinicalNoteAiFormatter =
    Future<String?> Function({
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
      return null;
    }

    final CancelToken cancelToken = CancelToken();
    abort.attach(() {
      cancelToken.cancel();
    });

    // Soft status gate: only skip when the backend explicitly reports disabled.
    // A stale ready:false cache or a transient status failure must not block
    // the actual format call (local models can take 30–90s).
    repository.invalidateStatusCache();
    final Result<AiStatus> statusResult = await repository.status(
      cancelToken: cancelToken,
      forceRefresh: true,
    );
    final bool explicitlyDisabled = statusResult.when(
      success: (AiStatus status) => !status.enabled,
      failure: (_) => false,
    );
    if (explicitlyDisabled || cancelToken.isCancelled) {
      return null;
    }

    final Result<AiTaskResult> taskResult = await repository.runTask(
      'clinical_note_format',
      <String, Object?>{
        'text': trimmed,
        if (locale != null && locale.trim().isNotEmpty) 'locale': locale.trim(),
        if (hint != null && hint.trim().isNotEmpty) 'hint': hint.trim(),
      },
      cancelToken: cancelToken,
    );

    return taskResult.when(
      success: (AiTaskResult result) {
        if (result.degraded) {
          return null;
        }
        return result.formattedText;
      },
      failure: (_) => null,
    );
  };
}
