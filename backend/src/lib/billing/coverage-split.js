/**
 * Co-pay / insurer share calculation for priced lines.
 *
 * @module lib/billing/coverage-split
 */

const { toDecimalNumber, toMoneyString } = require('./price-resolver');

const roundMoney = (value) => Math.round(toDecimalNumber(value) * 100) / 100;

const normalizeCopayType = (value) => {
  const token = String(value || '')
    .trim()
    .toUpperCase();
  if (token === 'FIXED' || token === 'PERCENT') return token;
  return 'NONE';
};

/**
 * Split a line total into patient vs insurer shares.
 *
 * @param {Object} options
 * @param {number|string} options.lineTotal
 * @param {number|string|null} [options.coveragePercentage] - 0–100 from coverage_plan
 * @param {'NONE'|'FIXED'|'PERCENT'} [options.copayType]
 * @param {number|string|null} [options.copayValue]
 * @param {boolean} [options.insured]
 * @param {number|string|null} [options.preAuthRemainingAmount] - caps insurer share
 * @returns {{ lineTotal: string, patientShare: string, insurerShare: string, copayAmount: string }}
 */
const splitLineCoverage = (options = {}) => {
  const lineTotal = roundMoney(options.lineTotal);
  const insured = Boolean(options.insured);
  if (!insured || lineTotal <= 0) {
    return {
      lineTotal: toMoneyString(lineTotal),
      patientShare: toMoneyString(lineTotal),
      insurerShare: toMoneyString(0),
      copayAmount: toMoneyString(0),
    };
  }

  const coveragePct = Math.min(
    100,
    Math.max(0, toDecimalNumber(options.coveragePercentage ?? 0))
  );
  const coveredBase = roundMoney((lineTotal * coveragePct) / 100);
  const uncovered = roundMoney(lineTotal - coveredBase);

  const copayType = normalizeCopayType(options.copayType);
  const copayValue = toDecimalNumber(options.copayValue);
  let copayAmount = 0;
  if (copayType === 'FIXED') {
    copayAmount = roundMoney(Math.min(coveredBase, Math.max(0, copayValue)));
  } else if (copayType === 'PERCENT') {
    copayAmount = roundMoney(
      (coveredBase * Math.min(100, Math.max(0, copayValue))) / 100
    );
  }

  let insurerShare = roundMoney(Math.max(0, coveredBase - copayAmount));
  let patientShare = roundMoney(uncovered + copayAmount);

  // Pre-auth approved remaining must constrain insurer share (excess → patient).
  if (
    options.preAuthRemainingAmount !== undefined &&
    options.preAuthRemainingAmount !== null &&
    options.preAuthRemainingAmount !== ''
  ) {
    const cap = roundMoney(
      Math.max(0, toDecimalNumber(options.preAuthRemainingAmount))
    );
    if (insurerShare > cap) {
      const excess = roundMoney(insurerShare - cap);
      insurerShare = cap;
      patientShare = roundMoney(patientShare + excess);
    }
  }

  return {
    lineTotal: toMoneyString(lineTotal),
    patientShare: toMoneyString(patientShare),
    insurerShare: toMoneyString(insurerShare),
    copayAmount: toMoneyString(copayAmount),
  };
};

/**
 * Apply coverage split across priced line items.
 *
 * When `payerContext.preAuthRemainingAmount` is set, insurer share is capped
 * sequentially across lines so the total never exceeds the pre-auth remaining.
 *
 * @param {Array<Object>} lineItems
 * @param {Object} payerContext
 * @returns {Array<Object>}
 */
const applyCoverageSplitToLineItems = (lineItems = [], payerContext = {}) => {
  const insured =
    Boolean(payerContext.insured) ||
    String(payerContext.paymentMode || '').toUpperCase() === 'INSURANCE';

  let remainingCap =
    payerContext.preAuthRemainingAmount === undefined ||
    payerContext.preAuthRemainingAmount === null ||
    payerContext.preAuthRemainingAmount === ''
      ? null
      : roundMoney(
          Math.max(0, toDecimalNumber(payerContext.preAuthRemainingAmount))
        );

  return (Array.isArray(lineItems) ? lineItems : []).map((item) => {
    const quantity = Math.max(1, Number(item.quantity) || 1);
    const unitPrice = toDecimalNumber(item.unit_price ?? item.unitPrice ?? 0);
    const lineTotal = roundMoney(
      toDecimalNumber(item.line_total ?? item.lineTotal ?? unitPrice * quantity)
    );

    const isExcluded = Boolean(item.is_excluded ?? item.isExcluded);
    const coveragePercentage = isExcluded
      ? 0
      : item.coverage_percentage ??
        item.coveragePercentage ??
        payerContext.coveragePercentage;
    const copayType =
      item.copay_type || item.copayType || payerContext.copayType || 'NONE';
    const copayValue =
      item.copay_value ?? item.copayValue ?? payerContext.copayValue;

    const split = splitLineCoverage({
      lineTotal,
      insured: insured && !isExcluded,
      coveragePercentage,
      copayType,
      copayValue,
      preAuthRemainingAmount: remainingCap,
    });

    if (remainingCap != null && insured && !isExcluded) {
      remainingCap = roundMoney(
        Math.max(0, remainingCap - toDecimalNumber(split.insurerShare))
      );
    }

    return {
      ...item,
      quantity,
      unit_price: item.unit_price ?? item.unitPrice ?? toMoneyString(unitPrice),
      line_total: split.lineTotal,
      patient_share: split.patientShare,
      insurer_share: split.insurerShare,
      copay_amount: split.copayAmount,
      payment_mode: insured ? 'INSURANCE' : 'SELF_PAY',
      coverage_plan_id:
        item.coverage_plan_id ||
        item.coveragePlanId ||
        payerContext.coveragePlanId ||
        null,
      insurance_company_id:
        item.insurance_company_id ||
        item.insuranceCompanyId ||
        payerContext.insuranceCompanyId ||
        null,
      scheme_offer_id: item.scheme_offer_id || item.schemeOfferId || null,
      requires_pre_auth: Boolean(
        item.requires_pre_auth ?? item.requiresPreAuth ?? false
      ),
      is_excluded: isExcluded,
    };
  });
};

/**
 * Summarize shares across lines.
 *
 * @param {Array<Object>} lineItems
 * @returns {{ total: string, patientShare: string, insurerShare: string, copayAmount: string }}
 */
const summarizeCoverageShares = (lineItems = []) => {
  const totals = (Array.isArray(lineItems) ? lineItems : []).reduce(
    (acc, item) => {
      acc.total += toDecimalNumber(item.line_total);
      acc.patientShare += toDecimalNumber(item.patient_share);
      acc.insurerShare += toDecimalNumber(item.insurer_share);
      acc.copayAmount += toDecimalNumber(item.copay_amount);
      return acc;
    },
    { total: 0, patientShare: 0, insurerShare: 0, copayAmount: 0 }
  );

  return {
    total: toMoneyString(roundMoney(totals.total)),
    patientShare: toMoneyString(roundMoney(totals.patientShare)),
    insurerShare: toMoneyString(roundMoney(totals.insurerShare)),
    copayAmount: toMoneyString(roundMoney(totals.copayAmount)),
  };
};

module.exports = {
  splitLineCoverage,
  applyCoverageSplitToLineItems,
  summarizeCoverageShares,
  normalizeCopayType,
  roundMoney,
};
