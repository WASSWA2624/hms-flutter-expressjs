import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_department.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class AccountsDepartmentRepository {
  Future<Result<AppPage<AccountsDepartment>>> listDepartments(
    AccountsDepartmentQuery query,
  );

  Future<Result<AccountsDepartment>> getDepartment(String humanFriendlyId);

  Future<Result<AccountsDepartment>> createDepartment(
    Map<String, Object?> payload,
  );

  Future<Result<AccountsDepartment>> updateDepartment(
    String humanFriendlyId,
    Map<String, Object?> payload,
  );

  Future<Result<AccountsDepartment>> applyAction(
    String humanFriendlyId,
    AccountsDepartmentAction action, {
    String? reason,
    int? version,
  });
}
