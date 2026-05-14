import 'package:flutter_template/core/errors/result.dart';
import 'package:flutter_template/features/example/domain/entities/example_resource.dart';

abstract interface class ExampleResourceRepository {
  Future<Result<ExampleResource>> fetchById(String id);
}
