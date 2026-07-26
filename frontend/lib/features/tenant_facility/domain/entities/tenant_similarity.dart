import 'package:hosspi_hms/core/utils/app_slug.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

const int tenantSimilarityThreshold = 80;
const int tenantNameWeight = 30;
const int tenantSlugWeight = 25;
const int tenantEmailWeight = 15;
const int tenantPhoneWeight = 15;
const int tenantContactNameWeight = 8;
const int tenantCurrencyWeight = 4;
const int tenantFeeWeight = 3;

enum TenantFieldComparisonStatus { match, similar, different, missing }

final class TenantFieldComparison {
  const TenantFieldComparison({
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
  final TenantFieldComparisonStatus status;
}

final class TenantSimilarityMatch {
  const TenantSimilarityMatch({
    required this.tenant,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.exactSlugConflict = false,
    this.exactNameConflict = false,
    this.nameScore,
    this.slugScore,
    this.emailScore,
    this.phoneScore,
    this.contactNameScore,
    this.currencyScore,
    this.feeScore,
    this.fieldComparisons = const <TenantFieldComparison>[],
  });

  final TenantProfile tenant;
  final int score;
  final List<String> reasons;
  final bool isExact;
  final bool exactSlugConflict;
  final bool exactNameConflict;
  final int? nameScore;
  final int? slugScore;
  final int? emailScore;
  final int? phoneScore;
  final int? contactNameScore;
  final int? currencyScore;
  final int? feeScore;
  final List<TenantFieldComparison> fieldComparisons;
}

final class TenantDuplicateCheckResult {
  const TenantDuplicateCheckResult({
    this.exactNameConflict = false,
    this.exactSlugConflict = false,
    this.similarMatches = const <TenantSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final bool exactSlugConflict;
  final List<TenantSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict || exactSlugConflict;

  List<TenantSimilarityMatch> get nonExactSimilarMatches {
    return similarMatches
        .where((TenantSimilarityMatch match) => !match.isExact)
        .toList(growable: false);
  }

  List<TenantSimilarityMatch> get overridableMatches {
    return similarMatches
        .where((TenantSimilarityMatch match) => !match.exactSlugConflict)
        .toList(growable: false);
  }
}

String normalizeTenantName(String value) {
  return value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeTenantEmail(String? value) {
  return (value ?? '').trim().toLowerCase();
}

String normalizeTenantPhone(String? value) {
  return (value ?? '').replaceAll(RegExp(r'\D+'), '');
}

String normalizeTenantCurrency(String? value) {
  return (value ?? '').trim().toUpperCase();
}

double? normalizeTenantFee(String? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.replaceAll(',', '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

int compositeTenantSimilarityScore({
  int? nameScore,
  int? slugScore,
  int? emailScore,
  int? phoneScore,
  int? contactNameScore,
  int? currencyScore,
  int? feeScore,
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

  include(nameScore, tenantNameWeight);
  include(slugScore, tenantSlugWeight);
  include(emailScore, tenantEmailWeight);
  include(phoneScore, tenantPhoneWeight);
  include(contactNameScore, tenantContactNameWeight);
  include(currencyScore, tenantCurrencyWeight);
  include(feeScore, tenantFeeWeight);

  if (weightSum == 0) {
    return 0;
  }
  return (weightedTotal / weightSum).round();
}

TenantFieldComparisonStatus _comparisonStatus(
  int? score, {
  bool exact = false,
}) {
  if (exact || score == 100) {
    return TenantFieldComparisonStatus.match;
  }
  if (score == null) {
    return TenantFieldComparisonStatus.missing;
  }
  if (score >= tenantSimilarityThreshold) {
    return TenantFieldComparisonStatus.similar;
  }
  return TenantFieldComparisonStatus.different;
}

TenantFieldComparison _fieldComparison({
  required String field,
  String? inputValue,
  String? candidateValue,
  int? score,
  bool exact = false,
}) {
  return TenantFieldComparison(
    field: field,
    inputValue: inputValue?.trim().isEmpty == true ? null : inputValue?.trim(),
    candidateValue: candidateValue?.trim().isEmpty == true
        ? null
        : candidateValue?.trim(),
    score: score,
    status: _comparisonStatus(score, exact: exact),
  );
}

TenantDuplicateCheckResult checkTenantDuplicates({
  required String name,
  required String slug,
  required List<TenantProfile> existing,
  String? excludeTenantId,
  String? contactName,
  String? contactEmail,
  String? contactPhone,
  String? currency,
  String? standardConsultationFee,
}) {
  final String normalizedName = normalizeTenantName(name);
  final String normalizedSlug = slugify(slug.isEmpty ? name : slug);
  final String normalizedContactName = normalizeTenantName(contactName ?? '');
  final String normalizedEmail = normalizeTenantEmail(contactEmail);
  final String normalizedPhone = normalizeTenantPhone(contactPhone);
  final String normalizedCurrency = normalizeTenantCurrency(currency);
  final double? normalizedFee = normalizeTenantFee(standardConsultationFee);

  var exactNameConflict = false;
  var exactSlugConflict = false;
  final List<TenantSimilarityMatch> matches = <TenantSimilarityMatch>[];

  for (final TenantProfile tenant in existing) {
    if (excludeTenantId != null && tenant.id == excludeTenantId) {
      continue;
    }

    final String tenantName = normalizeTenantName(tenant.name);
    final String tenantSlug = slugify(tenant.slug ?? '');
    final String tenantContactName = normalizeTenantName(
      tenant.contactName ?? '',
    );
    final String tenantEmail = normalizeTenantEmail(tenant.contactEmail);
    final String tenantPhone = normalizeTenantPhone(tenant.contactPhone);
    final String tenantCurrency = normalizeTenantCurrency(tenant.currency);
    final double? tenantFee = normalizeTenantFee(
      tenant.standardConsultationFee,
    );

    final bool nameExact =
        normalizedName.isNotEmpty && tenantName == normalizedName;
    final bool slugExact =
        normalizedSlug.isNotEmpty && tenantSlug == normalizedSlug;
    final bool emailExact =
        normalizedEmail.isNotEmpty &&
        tenantEmail.isNotEmpty &&
        tenantEmail == normalizedEmail;
    final bool phoneExact =
        normalizedPhone.isNotEmpty &&
        tenantPhone.isNotEmpty &&
        tenantPhone == normalizedPhone;
    final bool contactNameExact =
        normalizedContactName.isNotEmpty &&
        tenantContactName.isNotEmpty &&
        tenantContactName == normalizedContactName;
    final bool currencyExact =
        normalizedCurrency.isNotEmpty &&
        tenantCurrency.isNotEmpty &&
        tenantCurrency == normalizedCurrency;
    final bool feeExact =
        normalizedFee != null && tenantFee != null && normalizedFee == tenantFee;

    int? nameScore;
    int? slugScore;
    int? emailScore;
    int? phoneScore;
    int? contactNameScore;
    int? currencyScore;
    int? feeScore;
    final List<String> reasons = <String>[];

    if (normalizedName.isNotEmpty && tenantName.isNotEmpty) {
      nameScore = nameExact
          ? 100
          : nameSimilarityScore(normalizedName, tenantName);
      if (nameExact || nameScore >= tenantSimilarityThreshold) {
        reasons.add('name');
      }
    }

    if (normalizedSlug.isNotEmpty && tenantSlug.isNotEmpty) {
      slugScore = slugExact
          ? 100
          : nameSimilarityScore(normalizedSlug, tenantSlug);
      if (slugExact || slugScore >= tenantSimilarityThreshold) {
        reasons.add('slug');
      }
    }

    if (normalizedEmail.isNotEmpty && tenantEmail.isNotEmpty) {
      emailScore = emailExact
          ? 100
          : nameSimilarityScore(normalizedEmail, tenantEmail);
      if (emailExact || emailScore >= tenantSimilarityThreshold) {
        reasons.add('email');
      }
    }

    if (normalizedPhone.isNotEmpty && tenantPhone.isNotEmpty) {
      phoneScore = phoneExact
          ? 100
          : nameSimilarityScore(normalizedPhone, tenantPhone);
      if (phoneExact || phoneScore >= tenantSimilarityThreshold) {
        reasons.add('phone');
      }
    }

    if (normalizedContactName.isNotEmpty && tenantContactName.isNotEmpty) {
      contactNameScore = contactNameExact
          ? 100
          : nameSimilarityScore(normalizedContactName, tenantContactName);
      if (contactNameExact ||
          contactNameScore >= tenantSimilarityThreshold) {
        reasons.add('contact_name');
      }
    }

    if (normalizedCurrency.isNotEmpty && tenantCurrency.isNotEmpty) {
      currencyScore = currencyExact ? 100 : 0;
      if (currencyExact) {
        reasons.add('currency');
      }
    }

    if (normalizedFee != null && tenantFee != null) {
      if (feeExact) {
        feeScore = 100;
        reasons.add('consultation_fee');
      } else {
        final double maxFee = [
          normalizedFee.abs(),
          tenantFee.abs(),
          1.0,
        ].fold<double>(0, (double best, double value) => value > best ? value : best);
        final double distance = (normalizedFee - tenantFee).abs();
        feeScore = (((maxFee - distance) / maxFee) * 100)
            .round()
            .clamp(0, 100);
        if (feeScore >= tenantSimilarityThreshold) {
          reasons.add('consultation_fee');
        }
      }
    }

    final int score = compositeTenantSimilarityScore(
      nameScore: nameScore,
      slugScore: slugScore,
      emailScore: emailScore,
      phoneScore: phoneScore,
      contactNameScore: contactNameScore,
      currencyScore: currencyScore,
      feeScore: feeScore,
    );

    final List<TenantFieldComparison> fieldComparisons =
        <TenantFieldComparison>[
          _fieldComparison(
            field: 'name',
            inputValue: name,
            candidateValue: tenant.name,
            score: nameScore,
            exact: nameExact,
          ),
          _fieldComparison(
            field: 'slug',
            inputValue: slug.isEmpty ? normalizedSlug : slug,
            candidateValue: tenant.slug,
            score: slugScore,
            exact: slugExact,
          ),
          _fieldComparison(
            field: 'contact_name',
            inputValue: contactName,
            candidateValue: tenant.contactName,
            score: contactNameScore,
            exact: contactNameExact,
          ),
          _fieldComparison(
            field: 'contact_phone',
            inputValue: contactPhone,
            candidateValue: tenant.contactPhone,
            score: phoneScore,
            exact: phoneExact,
          ),
          _fieldComparison(
            field: 'contact_email',
            inputValue: contactEmail,
            candidateValue: tenant.contactEmail,
            score: emailScore,
            exact: emailExact,
          ),
          _fieldComparison(
            field: 'currency',
            inputValue: currency,
            candidateValue: tenant.currency,
            score: currencyScore,
            exact: currencyExact,
          ),
          _fieldComparison(
            field: 'consultation_fee',
            inputValue: standardConsultationFee,
            candidateValue: tenant.standardConsultationFee,
            score: feeScore,
            exact: feeExact,
          ),
        ].where((TenantFieldComparison comparison) {
          return comparison.inputValue != null ||
              comparison.candidateValue != null;
        }).toList(growable: false);

    if (slugExact) {
      exactSlugConflict = true;
    }
    if (nameExact) {
      exactNameConflict = true;
    }

    final bool isExact = nameExact || slugExact;
    final bool strongIdentitySignal =
        (nameScore != null && nameScore >= tenantSimilarityThreshold) ||
        (slugScore != null && slugScore >= tenantSimilarityThreshold) ||
        (emailScore != null && emailScore >= tenantSimilarityThreshold) ||
        (phoneScore != null && phoneScore >= tenantSimilarityThreshold);
    final bool compositeSignal = score >= tenantSimilarityThreshold;

    if (!isExact && !strongIdentitySignal && !compositeSignal) {
      continue;
    }

    matches.add(
      TenantSimilarityMatch(
        tenant: tenant,
        score: score,
        reasons: reasons.isEmpty ? const <String>['name'] : reasons,
        isExact: isExact,
        exactSlugConflict: slugExact,
        exactNameConflict: nameExact,
        nameScore: nameScore,
        slugScore: slugScore,
        emailScore: emailScore,
        phoneScore: phoneScore,
        contactNameScore: contactNameScore,
        currencyScore: currencyScore,
        feeScore: feeScore,
        fieldComparisons: fieldComparisons,
      ),
    );
  }

  matches.sort(
    (TenantSimilarityMatch left, TenantSimilarityMatch right) =>
        right.score.compareTo(left.score),
  );

  return TenantDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    exactSlugConflict: exactSlugConflict,
    similarMatches: matches,
  );
}

int nameSimilarityScore(String left, String right) {
  if (left == right) {
    return 100;
  }
  if (left.isEmpty || right.isEmpty) {
    return 0;
  }

  final int distance = _levenshteinDistance(left, right);
  final int maxLength = left.length > right.length ? left.length : right.length;
  return (((maxLength - distance) / maxLength) * 100).round().clamp(0, 100);
}

int _levenshteinDistance(String left, String right) {
  if (left == right) {
    return 0;
  }
  if (left.isEmpty) {
    return right.length;
  }
  if (right.isEmpty) {
    return left.length;
  }

  final List<int> previous = List<int>.generate(
    right.length + 1,
    (int index) => index,
    growable: false,
  );
  final List<int> current = List<int>.filled(right.length + 1, 0);

  for (int i = 0; i < left.length; i++) {
    current[0] = i + 1;
    for (int j = 0; j < right.length; j++) {
      final int substitutionCost = left.codeUnitAt(i) == right.codeUnitAt(j)
          ? 0
          : 1;
      current[j + 1] = _min3(
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + substitutionCost,
      );
    }
    for (int j = 0; j <= right.length; j++) {
      previous[j] = current[j];
    }
  }

  return previous[right.length];
}

int _min3(int a, int b, int c) {
  return a < b ? (a < c ? a : c) : (b < c ? b : c);
}
