import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class AccountsRepository {
  Future<Result<AccountsWorkspaceOverview>> getWorkspace(
    AccountsWorkspaceQuery query,
  );

  Future<Result<AppPage<AccountsWorkItem>>> listWorkItems(
    AccountsWorkspaceQuery query,
  );

  Future<Result<AccountsMutationResult>> createJournal(
    AccountsJournalDraft draft,
  );

  Future<Result<AccountsMutationResult>> updateJournal(
    String journalId,
    AccountsJournalDraft draft,
  );

  Future<Result<AccountsMutationResult>> postJournal(
    String journalId, {
    String? notes,
  });

  Future<Result<AccountsMutationResult>> approveRequest(
    String approvalId, {
    String? notes,
  });

  Future<Result<AccountsMutationResult>> rejectRequest(
    String approvalId, {
    required String reason,
    String? notes,
  });

  Future<Result<AccountsMutationResult>> reverseJournal(
    String journalId, {
    required String reason,
    String? notes,
  });

  Future<Result<AccountsMutationResult>> voidJournal(
    String journalId, {
    required String reason,
    String? notes,
  });

  Future<Result<AppPage<AccountsGlAccount>>> listGlAccounts(
    AccountsGlQuery query, {
    String? facilityId,
  });

  Future<Result<AccountsGlLedger>> getAccountLedger(
    String accountId, {
    String? facilityId,
  });

  Future<Result<AppPage<AccountsPatientBalance>>> listPatientLedgers(
    AccountsPatientLedgerQuery query, {
    String? facilityId,
  });

  Future<Result<AccountsPatientLedger>> getPatientLedger(
    String patientIdentifier, {
    String? facilityId,
  });
}
