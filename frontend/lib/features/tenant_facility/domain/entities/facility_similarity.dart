import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int facilitySimilarityThreshold = tenantSimilarityThreshold;
const int facilityNameWeight = 35;
const int facilityTypeWeight = 12;
const int facilityStatusWeight = 8;
const int facilityEmailWeight = 15;
const int facilityPhoneWeight = 15;
const int facilityAddressWeight = 10;
const int facilityCityWeight = 3;
const int facilityCountryWeight = 2;

typedef FacilityFieldComparisonStatus = TenantFieldComparisonStatus;

final class FacilityFieldComparison {
  const FacilityFieldComparison({
    required this.field,
    this.inputValue,
    this.candidateValue,
    this.score,
    required this.status,
  });

  final String field;
  final String? inputValue;
  final String? candidateValue;
  final int? score;
  final FacilityFieldComparisonStatus status;
}

final class FacilitySimilarityProposedValues {
  const FacilitySimilarityProposedValues({
    required this.name,
    required this.type,
    required this.isActive,
    this.phone,
    this.email,
    this.addressLine1,
    this.city,
    this.country,
  });

  final String name;
  final FacilitySetupType type;
  final bool isActive;
  final String? phone;
  final String? email;
  final String? addressLine1;
  final String? city;
  final String? country;
}

final class FacilitySimilarityMatch {
  const FacilitySimilarityMatch({
    required this.facility,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.exactNameConflict = false,
    this.nameScore,
    this.typeScore,
    this.statusScore,
    this.emailScore,
    this.phoneScore,
    this.addressScore,
    this.cityScore,
    this.countryScore,
    this.fieldComparisons = const <FacilityFieldComparison>[],
  });

  final FacilityProfile facility;
  final int score;
  final List<String> reasons;
  final bool isExact;
  final bool exactNameConflict;
  final int? nameScore;
  final int? typeScore;
  final int? statusScore;
  final int? emailScore;
  final int? phoneScore;
  final int? addressScore;
  final int? cityScore;
  final int? countryScore;
  final List<FacilityFieldComparison> fieldComparisons;
}

final class FacilityDuplicateCheckResult {
  const FacilityDuplicateCheckResult({
    this.exactNameConflict = false,
    this.similarMatches = const <FacilitySimilarityMatch>[],
  });

  final bool exactNameConflict;
  final List<FacilitySimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict;

  List<FacilitySimilarityMatch> get nonExactSimilarMatches {
    return similarMatches
        .where((FacilitySimilarityMatch match) => !match.isExact)
        .toList(growable: false);
  }

  List<FacilitySimilarityMatch> get overridableMatches {
    return similarMatches
        .where((FacilitySimilarityMatch match) => !match.exactNameConflict)
        .toList(growable: false);
  }
}

String normalizeFacilityName(String value) => normalizeTenantName(value);

String normalizeFacilityEmail(String? value) => normalizeTenantEmail(value);

String normalizeFacilityPhone(String? value) => normalizeTenantPhone(value);

String normalizeFacilityAddress(String? value) => normalizeTenantName(value ?? '');

int compositeFacilitySimilarityScore({
  int? nameScore,
  int? typeScore,
  int? statusScore,
  int? emailScore,
  int? phoneScore,
  int? addressScore,
  int? cityScore,
  int? countryScore,
}) {
  var weightedTotal = 0;
  var weightSum = 0;

  void include(int? score, int weight) {
    if (score == null) {
      return;
    }
    weightedTotal += score * weight;
    weightSum += weight;
  }

  include(nameScore, facilityNameWeight);
  include(typeScore, facilityTypeWeight);
  include(statusScore, facilityStatusWeight);
  include(emailScore, facilityEmailWeight);
  include(phoneScore, facilityPhoneWeight);
  include(addressScore, facilityAddressWeight);
  include(cityScore, facilityCityWeight);
  include(countryScore, facilityCountryWeight);

  if (weightSum == 0) {
    return 0;
  }
  return (weightedTotal / weightSum).round();
}

FacilityFieldComparisonStatus _comparisonStatus(
  int? score, {
  bool exact = false,
}) {
  if (exact || score == 100) {
    return FacilityFieldComparisonStatus.match;
  }
  if (score == null) {
    return FacilityFieldComparisonStatus.missing;
  }
  if (score >= facilitySimilarityThreshold) {
    return FacilityFieldComparisonStatus.similar;
  }
  return FacilityFieldComparisonStatus.different;
}

FacilityFieldComparison _fieldComparison({
  required String field,
  String? inputValue,
  String? candidateValue,
  int? score,
  bool exact = false,
}) {
  return FacilityFieldComparison(
    field: field,
    inputValue: inputValue?.trim().isEmpty == true ? null : inputValue?.trim(),
    candidateValue: candidateValue?.trim().isEmpty == true
        ? null
        : candidateValue?.trim(),
    score: score,
    status: _comparisonStatus(score, exact: exact),
  );
}

bool facilityMatchesExcludeId(FacilityProfile facility, String? excludeId) {
  if (excludeId == null || excludeId.trim().isEmpty) {
    return false;
  }
  final String needle = excludeId.trim();
  return facility.id == needle ||
      facility.mutationId == needle ||
      (facility.resourceUuid != null && facility.resourceUuid == needle) ||
      (facility.displayId != null && facility.displayId == needle);
}

FacilityDuplicateCheckResult checkFacilityDuplicates({
  required String name,
  required FacilitySetupType type,
  required bool isActive,
  required List<FacilityProfile> existing,
  String? excludeFacilityId,
  FacilityProfile? excludeFacility,
  String? phone,
  String? email,
  String? addressLine1,
  String? city,
  String? country,
}) {
  final String normalizedName = normalizeFacilityName(name);
  final String normalizedPhone = normalizeFacilityPhone(phone);
  final String normalizedEmail = normalizeFacilityEmail(email);
  final String normalizedAddress = normalizeFacilityAddress(addressLine1);
  final String normalizedCity = normalizeFacilityAddress(city);
  final String normalizedCountry = normalizeFacilityAddress(country);
  var exactNameConflict = false;
  final List<FacilitySimilarityMatch> matches = <FacilitySimilarityMatch>[];

  for (final FacilityProfile facility in existing) {
    final bool excluded =
        facilityMatchesExcludeId(facility, excludeFacilityId) ||
        (excludeFacility != null &&
            (facility.id == excludeFacility.id ||
                facility.mutationId == excludeFacility.mutationId ||
                (excludeFacility.resourceUuid != null &&
                    facility.resourceUuid == excludeFacility.resourceUuid) ||
                (excludeFacility.displayId != null &&
                    facility.displayId == excludeFacility.displayId)));
    if (excluded) {
      continue;
    }

    final String facilityName = normalizeFacilityName(facility.name);
    final String facilityPhone = normalizeFacilityPhone(facility.phone);
    final String facilityEmail = normalizeFacilityEmail(facility.email);
    final String facilityAddress = normalizeFacilityAddress(
      facility.addressLine1,
    );
    final String facilityCity = normalizeFacilityAddress(facility.city);
    final String facilityCountry = normalizeFacilityAddress(facility.country);

    final bool nameExact =
        normalizedName.isNotEmpty && facilityName == normalizedName;
    final bool typeExact = facility.type == type;
    final bool statusExact = facility.isActive == isActive;
    final bool phoneExact =
        normalizedPhone.isNotEmpty &&
        facilityPhone.isNotEmpty &&
        facilityPhone == normalizedPhone;
    final bool emailExact =
        normalizedEmail.isNotEmpty &&
        facilityEmail.isNotEmpty &&
        facilityEmail == normalizedEmail;
    final bool addressExact =
        normalizedAddress.isNotEmpty &&
        facilityAddress.isNotEmpty &&
        facilityAddress == normalizedAddress;
    final bool cityExact =
        normalizedCity.isNotEmpty &&
        facilityCity.isNotEmpty &&
        facilityCity == normalizedCity;
    final bool countryExact =
        normalizedCountry.isNotEmpty &&
        facilityCountry.isNotEmpty &&
        facilityCountry == normalizedCountry;

    int? nameScore;
    int? typeScore;
    int? statusScore;
    int? emailScore;
    int? phoneScore;
    int? addressScore;
    int? cityScore;
    int? countryScore;
    final List<String> reasons = <String>[];

    if (normalizedName.isNotEmpty && facilityName.isNotEmpty) {
      nameScore = nameExact
          ? 100
          : nameSimilarityScore(normalizedName, facilityName);
      if (nameExact || nameScore >= facilitySimilarityThreshold) {
        reasons.add('name');
      }
    }

    typeScore = typeExact ? 100 : 0;
    if (typeExact) {
      reasons.add('facility_type');
    }

    statusScore = statusExact ? 100 : 0;
    if (statusExact) {
      reasons.add('status');
    }

    if (normalizedEmail.isNotEmpty && facilityEmail.isNotEmpty) {
      emailScore = emailExact
          ? 100
          : nameSimilarityScore(normalizedEmail, facilityEmail);
      if (emailExact || emailScore >= facilitySimilarityThreshold) {
        reasons.add('email');
      }
    }

    if (normalizedPhone.isNotEmpty && facilityPhone.isNotEmpty) {
      phoneScore = phoneExact
          ? 100
          : nameSimilarityScore(normalizedPhone, facilityPhone);
      if (phoneExact || phoneScore >= facilitySimilarityThreshold) {
        reasons.add('phone');
      }
    }

    if (normalizedAddress.isNotEmpty && facilityAddress.isNotEmpty) {
      addressScore = addressExact
          ? 100
          : nameSimilarityScore(normalizedAddress, facilityAddress);
      if (addressExact || addressScore >= facilitySimilarityThreshold) {
        reasons.add('address');
      }
    }

    if (normalizedCity.isNotEmpty && facilityCity.isNotEmpty) {
      cityScore = cityExact
          ? 100
          : nameSimilarityScore(normalizedCity, facilityCity);
      if (cityExact || cityScore >= facilitySimilarityThreshold) {
        reasons.add('city');
      }
    }

    if (normalizedCountry.isNotEmpty && facilityCountry.isNotEmpty) {
      countryScore = countryExact
          ? 100
          : nameSimilarityScore(normalizedCountry, facilityCountry);
      if (countryExact || countryScore >= facilitySimilarityThreshold) {
        reasons.add('country');
      }
    }

    final int score = compositeFacilitySimilarityScore(
      nameScore: nameScore,
      typeScore: typeScore,
      statusScore: statusScore,
      emailScore: emailScore,
      phoneScore: phoneScore,
      addressScore: addressScore,
      cityScore: cityScore,
      countryScore: countryScore,
    );

    final List<FacilityFieldComparison> fieldComparisons =
        <FacilityFieldComparison>[
          _fieldComparison(
            field: 'name',
            inputValue: name,
            candidateValue: facility.name,
            score: nameScore,
            exact: nameExact,
          ),
          _fieldComparison(
            field: 'facility_type',
            inputValue: type.name,
            candidateValue: facility.type.name,
            score: typeScore,
            exact: typeExact,
          ),
          _fieldComparison(
            field: 'status',
            inputValue: isActive ? 'active' : 'inactive',
            candidateValue: facility.isActive ? 'active' : 'inactive',
            score: statusScore,
            exact: statusExact,
          ),
          _fieldComparison(
            field: 'phone',
            inputValue: phone,
            candidateValue: facility.phone,
            score: phoneScore,
            exact: phoneExact,
          ),
          _fieldComparison(
            field: 'email',
            inputValue: email,
            candidateValue: facility.email,
            score: emailScore,
            exact: emailExact,
          ),
          _fieldComparison(
            field: 'address_line1',
            inputValue: addressLine1,
            candidateValue: facility.addressLine1,
            score: addressScore,
            exact: addressExact,
          ),
          _fieldComparison(
            field: 'city',
            inputValue: city,
            candidateValue: facility.city,
            score: cityScore,
            exact: cityExact,
          ),
          _fieldComparison(
            field: 'country',
            inputValue: country,
            candidateValue: facility.country,
            score: countryScore,
            exact: countryExact,
          ),
          _fieldComparison(
            field: 'display_id',
            candidateValue: facility.displayId ?? facility.id,
          ),
        ].where(
          (FacilityFieldComparison entry) =>
              entry.inputValue != null || entry.candidateValue != null,
        )
        .toList(growable: false);

    if (nameExact) {
      exactNameConflict = true;
    }

    final bool isExact = nameExact;
    final bool strongIdentitySignal =
        (nameScore != null && nameScore >= facilitySimilarityThreshold) ||
        (emailScore != null && emailScore >= facilitySimilarityThreshold) ||
        (phoneScore != null && phoneScore >= facilitySimilarityThreshold) ||
        (addressScore != null && addressScore >= facilitySimilarityThreshold);
    final bool compositeSignal = score >= facilitySimilarityThreshold;

    if (!isExact && !strongIdentitySignal && !compositeSignal) {
      continue;
    }

    matches.add(
      FacilitySimilarityMatch(
        facility: facility,
        score: score,
        reasons: reasons.isEmpty ? const <String>['name'] : reasons,
        isExact: isExact,
        exactNameConflict: nameExact,
        nameScore: nameScore,
        typeScore: typeScore,
        statusScore: statusScore,
        emailScore: emailScore,
        phoneScore: phoneScore,
        addressScore: addressScore,
        cityScore: cityScore,
        countryScore: countryScore,
        fieldComparisons: fieldComparisons,
      ),
    );
  }

  matches.sort(
    (FacilitySimilarityMatch left, FacilitySimilarityMatch right) =>
        right.score.compareTo(left.score),
  );

  return FacilityDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    similarMatches: matches,
  );
}
