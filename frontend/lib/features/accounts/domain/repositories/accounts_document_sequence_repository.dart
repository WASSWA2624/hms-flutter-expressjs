import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_document_sequence.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class AccountsDocumentSequenceRepository {
  Future<Result<AppPage<AccountsDocumentSequence>>> listDocumentSequences(
    AccountsDocumentSequenceQuery query,
  );

  Future<Result<AccountsDocumentSequence>> getDocumentSequence(
    String humanFriendlyId,
  );

  Future<Result<AccountsDocumentSequence>> createDocumentSequence(
    Map<String, Object?> payload,
  );

  Future<Result<AccountsDocumentSequence>> updateDocumentSequence(
    String humanFriendlyId,
    Map<String, Object?> payload,
  );

  Future<Result<AccountsDocumentSequence>> applyAction(
    String humanFriendlyId,
    AccountsDocumentSequenceAction action, {
    String? reason,
    int? version,
  });
}
