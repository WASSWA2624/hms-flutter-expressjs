import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/example/data/dtos/example_resource_dto.dart';

void main() {
  group('ExampleResourceDto', () {
    test('maps validated JSON into a domain entity', () {
      final dto = ExampleResourceDto.fromJson(<String, Object?>{
        'id': ' example-1 ',
        'title': ' Example resource ',
      });

      final entity = dto.toEntity();

      expect(entity.id, 'example-1');
      expect(entity.title, 'Example resource');
      expect(dto.toJson(), <String, Object?>{
        'id': 'example-1',
        'title': 'Example resource',
      });
    });

    test('rejects missing required fields', () {
      expect(
        () => ExampleResourceDto.fromJson(<String, Object?>{'id': 'example-1'}),
        throwsFormatException,
      );
    });
  });
}
