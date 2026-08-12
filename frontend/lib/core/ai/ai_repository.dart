import 'package:dio/dio.dart';
import 'package:hosspi_hms/core/ai/ai_models.dart';
import 'package:hosspi_hms/core/errors/result.dart';

abstract interface class AiRepository {
  Future<Result<AiStatus>> status({CancelToken? cancelToken});

  Future<Result<AiTaskResult>> runTask(
    String taskKey,
    Map<String, Object?> body, {
    CancelToken? cancelToken,
  });
}
