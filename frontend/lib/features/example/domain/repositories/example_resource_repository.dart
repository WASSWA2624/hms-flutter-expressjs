import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/example/domain/entities/example_resource.dart';

abstract interface class ExampleResourceRepository {
  Future<Result<ExampleResource>> fetchById(String id);
}
