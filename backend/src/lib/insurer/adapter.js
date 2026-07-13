/**
 * Insurer adapter interface + registry (stub + generic REST placeholder).
 *
 * @module lib/insurer/adapter
 */

const createStubAdapter = (config = {}) => {
  const forceReject = Boolean(config.forceReject);

  return {
    name: 'STUB',
    async checkEligibility({ memberId, coveragePlan }) {
      const active = !forceReject && Boolean(memberId);
      return {
        eligible: active,
        status: active ? 'ACTIVE' : 'REJECTED',
        memberId: memberId || null,
        coveragePlanId: coveragePlan?.id || null,
        coveragePercentage: coveragePlan?.coverage_percentage ?? 0,
        message: active
          ? 'Stub eligibility verified'
          : 'Stub eligibility rejected',
        raw: { adapter: 'STUB' },
      };
    },

    async authorize({ memberId, amount, reason }) {
      if (forceReject) {
        return {
          approved: false,
          status: 'DENIED',
          approvedAmount: '0.00',
          reference: null,
          message: 'Stub authorization denied',
        };
      }
      return {
        approved: true,
        status: 'APPROVED',
        approvedAmount: amount != null ? String(amount) : null,
        reference: `STUB-AUTH-${Date.now()}`,
        reason: reason || null,
        memberId: memberId || null,
        message: 'Stub authorization approved',
      };
    },

    async submitClaim({ claim, invoice }) {
      if (forceReject) {
        return {
          accepted: false,
          status: 'REJECTED',
          payerReference: null,
          message: 'Stub claim rejected',
        };
      }
      return {
        accepted: true,
        status: 'SUBMITTED',
        payerReference:
          claim?.payer_reference || `STUB-CLM-${invoice?.id || Date.now()}`,
        message: 'Stub claim accepted',
      };
    },

    async getClaimStatus({ payerReference }) {
      return {
        status: 'PAID',
        payerReference: payerReference || null,
        settlementAmount: null,
        message: 'Stub claim paid',
      };
    },

    async parseWebhook(payload = {}) {
      return {
        event: payload.event || 'claim.status',
        status: payload.status || 'PAID',
        payerReference: payload.payer_reference || payload.payerReference || null,
        settlementAmount: payload.settlement_amount || payload.settlementAmount || null,
        raw: payload,
      };
    },
  };
};

const createGenericRestAdapter = (config = {}) => {
  // Placeholder for real HTTP payer integrations; falls back to stub behavior.
  const stub = createStubAdapter(config);
  return {
    ...stub,
    name: 'GENERIC_REST',
    async checkEligibility(args) {
      const result = await stub.checkEligibility(args);
      return {
        ...result,
        message: result.eligible
          ? 'Generic REST adapter (stubbed) eligibility verified'
          : result.message,
        raw: { ...(result.raw || {}), adapter: 'GENERIC_REST', baseUrl: config.baseUrl || null },
      };
    },
  };
};

const getInsurerAdapter = (integration = {}) => {
  const type = String(integration.adapter_type || integration.adapterType || 'STUB')
    .trim()
    .toUpperCase();
  const config = {
    ...(integration.config_json && typeof integration.config_json === 'object'
      ? integration.config_json
      : {}),
    baseUrl: integration.base_url || integration.baseUrl || null,
    forceReject: Boolean(integration.forceReject),
  };

  if (type === 'GENERIC_REST') {
    return createGenericRestAdapter(config);
  }
  return createStubAdapter(config);
};

module.exports = {
  getInsurerAdapter,
  createStubAdapter,
  createGenericRestAdapter,
};
