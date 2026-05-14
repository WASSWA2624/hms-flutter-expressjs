typedef JsonMap = Map<String, Object?>;

typedef ApiDataDecoder<T> = T Function(Object? data);

final class ApiResponseEnvelope<T> {
  const ApiResponseEnvelope({
    required this.success,
    required this.data,
    this.meta,
  });

  final bool success;
  final T data;
  final JsonMap? meta;

  static T decodeData<T>(
    Object? responseData, {
    required ApiDataDecoder<T> decoder,
  }) {
    return ApiResponseEnvelope<T>.fromResponseData(
      responseData,
      decoder: decoder,
    ).data;
  }

  factory ApiResponseEnvelope.fromResponseData(
    Object? responseData, {
    required ApiDataDecoder<T> decoder,
  }) {
    if (responseData is! JsonMap) {
      throw const FormatException('Expected an API response object.');
    }

    final Object? successValue = responseData['success'];
    if (successValue is! bool) {
      throw const FormatException('Expected an API success flag.');
    }
    if (!successValue) {
      throw const FormatException('Expected a successful API response.');
    }
    if (!responseData.containsKey('data')) {
      throw const FormatException('Expected API response data.');
    }

    final Object? metaValue = responseData['meta'];
    return ApiResponseEnvelope<T>(
      success: successValue,
      data: decoder(responseData['data']),
      meta: metaValue is JsonMap ? metaValue : null,
    );
  }
}
