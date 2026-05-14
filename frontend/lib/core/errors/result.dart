import 'package:flutter_template/core/errors/app_failure.dart';

sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = ResultSuccess<T>;

  const factory Result.failure(AppFailure failure) = ResultFailure<T>;

  bool get isSuccess => this is ResultSuccess<T>;

  bool get isFailure => this is ResultFailure<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(AppFailure failure) failure,
  }) {
    return switch (this) {
      ResultSuccess<T>(value: final value) => success(value),
      ResultFailure<T>(failure: final mappedFailure) => failure(mappedFailure),
    };
  }

  Result<R> map<R>(R Function(T value) mapper) {
    return when(
      success: (value) => Result<R>.success(mapper(value)),
      failure: (mappedFailure) => Result<R>.failure(mappedFailure),
    );
  }
}

final class ResultSuccess<T> extends Result<T> {
  const ResultSuccess(this.value);

  final T value;
}

final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);

  final AppFailure failure;
}
