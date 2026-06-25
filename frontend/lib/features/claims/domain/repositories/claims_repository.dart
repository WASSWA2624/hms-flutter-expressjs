import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class ClaimsRepository {
  Future<Result<AppPage<ClaimsQueueItem>>> listQueue(ClaimsQueueQuery query);

  Future<Result<ClaimsQueueDetail>> getDetail(ClaimsQueueItem item);

  Future<Result<ClaimsReferenceData>> loadReferenceData();

  /// Loads authoritative summary counts from the backend `claims-workspace`
  /// aggregator so summary cards reflect the full scope rather than the loaded
  /// queue page.
  Future<Result<ClaimsWorkspaceSummary>> loadWorkspaceSummary();

  Future<Result<PreAuthorizationRecord>> requestPreAuthorization(
    Map<String, Object?> payload,
  );

  Future<Result<PreAuthorizationRecord>> updatePreAuthorization(
    String authorizationId,
    Map<String, Object?> payload,
  );

  Future<Result<InsuranceClaimRecord>> prepareClaim(
    Map<String, Object?> payload,
  );

  Future<Result<InsuranceClaimRecord>> submitClaim(
    String claimId,
    Map<String, Object?> payload,
  );

  Future<Result<InsuranceClaimRecord>> reconcileClaim(
    String claimId,
    Map<String, Object?> payload,
  );

  Future<Result<AppPage<PreAuthorizationRecord>>>
  listPreAuthorizationsForContext({
    String? patientId,
    String? admissionId,
    String? encounterId,
    int limit = 20,
  });
}
