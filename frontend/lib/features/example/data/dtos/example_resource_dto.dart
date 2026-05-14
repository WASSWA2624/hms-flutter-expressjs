import 'package:hosspi_hms/features/example/domain/entities/example_resource.dart';

final class ExampleResourceDto {
  const ExampleResourceDto({required this.id, required this.title});

  factory ExampleResourceDto.fromResponseData(Object? data) {
    if (data is! Map<String, Object?>) {
      throw const FormatException('Invalid example resource payload.');
    }

    return ExampleResourceDto.fromJson(data);
  }

  factory ExampleResourceDto.fromJson(Map<String, Object?> json) {
    return ExampleResourceDto(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
    );
  }

  final String id;
  final String title;

  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'title': title};
  }

  ExampleResource toEntity() {
    return ExampleResource(id: id, title: title);
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];

    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Invalid example resource payload.');
    }

    return value.trim();
  }
}
