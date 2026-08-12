import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/ai/ai_models.dart';
import 'package:hosspi_hms/core/ai/ai_remote_data_source.dart';
import 'package:hosspi_hms/core/ai/ai_repository.dart';
import 'package:hosspi_hms/core/ai/ai_repository_impl.dart';
import 'package:hosspi_hms/core/ai/ai_speech_formatter.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/network/api_result.dart';
import 'package:hosspi_hms/shared/components/app_speech_ai.dart';

final class _FakeAiRemoteDataSource implements AiRemoteDataSource {
  _FakeAiRemoteDataSource({
    this.statusResult,
    this.taskResult,
  });

  ApiResult<AiStatus>? statusResult;
  ApiResult<AiTaskResult>? taskResult;
  int statusCalls = 0;
  int taskCalls = 0;
  String? lastTaskKey;
  Map<String, Object?>? lastBody;

  @override
  Future<ApiResult<AiStatus>> status({cancelToken}) async {
    statusCalls += 1;
    return statusResult ??
        const Result.success(
          AiStatus(
            enabled: true,
            provider: 'ollama',
            model: 'llama3.2:3b',
            ready: true,
          ),
        );
  }

  @override
  Future<ApiResult<AiTaskResult>> runTask(
    String taskKey,
    Map<String, Object?> body, {
    cancelToken,
  }) async {
    taskCalls += 1;
    lastTaskKey = taskKey;
    lastBody = body;
    return taskResult ??
        Result.success(
          AiTaskResult(
            taskKey: taskKey,
            output: const <String, Object?>{'formatted_text': 'ok', 'mode': 'text'},
            degraded: false,
            model: 'llama3.2:3b',
            provider: 'ollama',
          ),
        );
  }
}

void main() {
  test('status is cached and runTask posts speech_format', () async {
    final _FakeAiRemoteDataSource remote = _FakeAiRemoteDataSource();
    final AiRepository repository = AiRepositoryImpl(
      remoteDataSource: remote,
      statusCacheTtl: const Duration(seconds: 30),
    );

    await repository.status();
    await repository.status();
    expect(remote.statusCalls, 1);

    final result = await repository.runTask('speech_format', <String, Object?>{
      'transcript': 'hello',
      'mode': 'text',
    });
    expect(result.isSuccess, isTrue);
    expect(remote.lastTaskKey, 'speech_format');
    expect(remote.lastBody?['transcript'], 'hello');
  });

  test('formatter skips the task when AI is not ready', () async {
    final _FakeAiRemoteDataSource remote = _FakeAiRemoteDataSource(
      statusResult: const Result.success(
        AiStatus(
          enabled: true,
          provider: 'ollama',
          model: 'llama3.2:3b',
          ready: false,
        ),
      ),
    );
    final formatter = createAiSpeechFormatter(
      AiRepositoryImpl(remoteDataSource: remote),
    );

    final String? formatted = await formatter(
      transcript: 'hello',
      mode: 'text',
      abort: AppSpeechAiAbort(),
    );

    expect(formatted, isNull);
    expect(remote.taskCalls, 0);
  });

  test('formatter returns null when the task is degraded', () async {
    final _FakeAiRemoteDataSource remote = _FakeAiRemoteDataSource(
      taskResult: const Result.success(
        AiTaskResult(
          taskKey: 'speech_format',
          output: <String, Object?>{
            'formatted_text': 'hello',
            'mode': 'text',
          },
          degraded: true,
        ),
      ),
    );
    final formatter = createAiSpeechFormatter(
      AiRepositoryImpl(remoteDataSource: remote),
    );

    final String? formatted = await formatter(
      transcript: 'hello',
      mode: 'text',
      abort: AppSpeechAiAbort(),
    );

    expect(formatted, isNull);
  });

  test('formatter returns formatted_text when the provider succeeds', () async {
    final _FakeAiRemoteDataSource remote = _FakeAiRemoteDataSource(
      taskResult: const Result.success(
        AiTaskResult(
          taskKey: 'speech_format',
          output: <String, Object?>{
            'formatted_text': 'name@hospital.com',
            'mode': 'email',
          },
          degraded: false,
          model: 'llama3.2:3b',
          provider: 'ollama',
        ),
      ),
    );
    final formatter = createAiSpeechFormatter(
      AiRepositoryImpl(remoteDataSource: remote),
    );

    final String? formatted = await formatter(
      transcript: 'name at hospital dot com',
      mode: 'email',
      abort: AppSpeechAiAbort(),
    );

    expect(formatted, 'name@hospital.com');
    expect(remote.lastTaskKey, 'speech_format');
    expect(remote.lastBody?['mode'], 'email');
  });

  test('runTask rejects a blank task key', () async {
    final AiRepository repository = AiRepositoryImpl(
      remoteDataSource: _FakeAiRemoteDataSource(),
    );
    final Result<AiTaskResult> result = await repository.runTask(
      '  ',
      const <String, Object?>{},
    );
    expect(result.isFailure, isTrue);
    result.when(
      success: (_) => fail('expected validation failure'),
      failure: (AppFailure failure) {
        expect(failure.category, AppFailureCategory.validation);
      },
    );
  });
}
