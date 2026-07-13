/**
 * Multi-tier price book resolver.
 *
 * Resolution order (highest wins):
 * 1. item + facility + payment mode + coverage plan
 * 2. item + facility + payment mode + insurer
 * 3. item + facility + payment mode (self-pay)
 * 4. catalog / facility offering fallback
 *
 * @module lib/billing/price-resolver
 */

const prisma = require('@prisma/client');

const toDecimalNumber = (value) => {
  const num = Number(value);
  return Number.isFinite(num) ? num : 0;
};

const toMoneyString = (value) => toDecimalNumber(value).toFixed(2);

const normalizeBillingEntity = (value) => {
  const token = String(value || '')
    .trim()
    .toUpperCase();
  return token === 'PHARMACY' ? 'PHARMACY' : 'FACILITY';
};

const normalizePaymentMode = (value) => {
  const token = String(value || '')
    .trim()
    .toUpperCase();
  return token === 'INSURANCE' ? 'INSURANCE' : 'SELF_PAY';
};

const normalizeCatalogType = (value) => {
  const token = String(value || '')
    .trim()
    .toUpperCase();
  const allowed = new Set([
    'DRUG',
    'LAB_TEST',
    'LAB_PANEL',
    'RADIOLOGY_TEST',
    'CONSULTATION',
    'SERVICE',
  ]);
  return allowed.has(token) ? token : null;
};

const isEffectiveAt = (entry, at = new Date()) => {
  if (!entry) return false;
  if (entry.is_active === false) return false;
  if (entry.deleted_at) return false;
  const from = entry.effective_from ? new Date(entry.effective_from) : null;
  const to = entry.effective_to ? new Date(entry.effective_to) : null;
  if (from && from > at) return false;
  if (to && to < at) return false;
  return true;
};

const scoreEntry = (entry, ctx) => {
  let score = 0;
  if (entry.facility_id && ctx.facilityId && entry.facility_id === ctx.facilityId) {
    score += 100;
  } else if (!entry.facility_id) {
    score += 10;
  } else {
    return -1;
  }

  if (entry.payment_mode === ctx.paymentMode) {
    score += 50;
  } else {
    return -1;
  }

  if (entry.billing_entity === ctx.billingEntity) {
    score += 20;
  } else {
    return -1;
  }

  if (ctx.coveragePlanId && entry.coverage_plan_id === ctx.coveragePlanId) {
    score += 40;
  } else if (entry.coverage_plan_id) {
    return -1;
  }

  const insurerKey = String(ctx.insurerKey || '')
    .trim()
    .toLowerCase();
  const entryInsurer = String(entry.insurer_key || '')
    .trim()
    .toLowerCase();
  if (insurerKey && entryInsurer && entryInsurer === insurerKey) {
    score += 30;
  } else if (entryInsurer) {
    return -1;
  }

  return score;
};

const resolveCatalogFallback = async ({
  catalogType,
  catalogItemId,
  tenantId,
  facilityId,
  billingEntity,
}) => {
  if (!catalogType || !catalogItemId || !tenantId) {
    return null;
  }

  if (catalogType === 'LAB_TEST') {
    if (facilityId) {
      const offering = await prisma.facility_lab_test_offering.findFirst({
        where: {
          deleted_at: null,
          is_active: true,
          facility_id: facilityId,
          lab_test_id: catalogItemId,
        },
        select: { unit_price: true, currency: true },
      });
      if (offering?.unit_price != null && toDecimalNumber(offering.unit_price) > 0) {
        return {
          unitPrice: toMoneyString(offering.unit_price),
          currency: offering.currency || null,
          source: 'FACILITY_OFFERING',
        };
      }
    }
    const test = await prisma.lab_test.findFirst({
      where: { id: catalogItemId, tenant_id: tenantId, deleted_at: null },
      select: { unit_price: true, currency: true },
    });
    if (test?.unit_price != null && toDecimalNumber(test.unit_price) > 0) {
      return {
        unitPrice: toMoneyString(test.unit_price),
        currency: test.currency || null,
        source: 'CATALOG',
      };
    }
  }

  if (catalogType === 'LAB_PANEL') {
    if (facilityId) {
      const offering = await prisma.facility_lab_panel_offering.findFirst({
        where: {
          deleted_at: null,
          is_active: true,
          facility_id: facilityId,
          lab_panel_id: catalogItemId,
        },
        select: { unit_price: true, currency: true },
      });
      if (offering?.unit_price != null && toDecimalNumber(offering.unit_price) > 0) {
        return {
          unitPrice: toMoneyString(offering.unit_price),
          currency: offering.currency || null,
          source: 'FACILITY_OFFERING',
        };
      }
    }
    const panel = await prisma.lab_panel.findFirst({
      where: { id: catalogItemId, tenant_id: tenantId, deleted_at: null },
      select: { unit_price: true, currency: true },
    });
    if (panel?.unit_price != null && toDecimalNumber(panel.unit_price) > 0) {
      return {
        unitPrice: toMoneyString(panel.unit_price),
        currency: panel.currency || null,
        source: 'CATALOG',
      };
    }
  }

  if (catalogType === 'RADIOLOGY_TEST') {
    if (facilityId) {
      const offering = await prisma.facility_radiology_test_offering.findFirst({
        where: {
          deleted_at: null,
          is_active: true,
          facility_id: facilityId,
          radiology_test_id: catalogItemId,
        },
        select: { unit_price: true, currency: true },
      });
      if (offering?.unit_price != null && toDecimalNumber(offering.unit_price) > 0) {
        return {
          unitPrice: toMoneyString(offering.unit_price),
          currency: offering.currency || null,
          source: 'FACILITY_OFFERING',
        };
      }
    }
    const test = await prisma.radiology_test.findFirst({
      where: { id: catalogItemId, tenant_id: tenantId, deleted_at: null },
      select: { unit_price: true, currency: true },
    });
    if (test?.unit_price != null && toDecimalNumber(test.unit_price) > 0) {
      return {
        unitPrice: toMoneyString(test.unit_price),
        currency: test.currency || null,
        source: 'CATALOG',
      };
    }
  }

  if (catalogType === 'DRUG') {
    if (billingEntity === 'FACILITY' && facilityId) {
      const offering = await prisma.facility_pharmacy_offering.findFirst({
        where: {
          deleted_at: null,
          is_active: true,
          facility_id: facilityId,
          drug_id: catalogItemId,
        },
        select: { unit_price: true, currency: true },
      });
      if (offering?.unit_price != null && toDecimalNumber(offering.unit_price) > 0) {
        return {
          unitPrice: toMoneyString(offering.unit_price),
          currency: offering.currency || null,
          source: 'FACILITY_OFFERING',
          priceSource: 'FACILITY',
        };
      }
    }
    const drug = await prisma.drug.findFirst({
      where: { id: catalogItemId, tenant_id: tenantId, deleted_at: null },
      select: { unit_price: true, currency: true },
    });
    if (drug?.unit_price != null && toDecimalNumber(drug.unit_price) > 0) {
      return {
        unitPrice: toMoneyString(drug.unit_price),
        currency: drug.currency || null,
        source: 'CATALOG',
        priceSource: billingEntity === 'PHARMACY' ? 'PHARMACY' : 'FACILITY',
      };
    }
  }

  return null;
};

/**
 * Resolve a single catalog item price for the given payer / entity context.
 *
 * @param {Object} options
 * @returns {Promise<Object>}
 */
const resolveUnitPrice = async (options = {}) => {
  const catalogType = normalizeCatalogType(options.catalogType);
  const catalogItemId = String(options.catalogItemId || '').trim();
  const tenantId = String(options.tenantId || '').trim();
  const facilityId = options.facilityId ? String(options.facilityId).trim() : null;
  const paymentMode = normalizePaymentMode(options.paymentMode);
  const billingEntity = normalizeBillingEntity(
    options.billingEntity || options.priceSource
  );
  const coveragePlanId = options.coveragePlanId
    ? String(options.coveragePlanId).trim()
    : null;
  const insurerKey = options.insurerKey ? String(options.insurerKey).trim() : null;
  const at = options.at instanceof Date ? options.at : new Date();

  if (!catalogType || !catalogItemId || !tenantId) {
    return {
      unitPrice: null,
      currency: options.currency || null,
      priceBookEntryId: null,
      paymentMode,
      billingEntity,
      coveragePlanId,
      source: 'UNRESOLVED',
    };
  }

  const facilityClause = facilityId
    ? [{ facility_id: facilityId }, { facility_id: null }]
    : [{ facility_id: null }];

  const candidates = await prisma.price_book_entry.findMany({
    where: {
      deleted_at: null,
      is_active: true,
      tenant_id: tenantId,
      catalog_type: catalogType,
      catalog_item_id: catalogItemId,
      payment_mode: paymentMode,
      billing_entity: billingEntity,
      OR: facilityClause,
    },
  });

  const scoped = candidates.filter((entry) => isEffectiveAt(entry, at));
  const ctx = {
    facilityId,
    paymentMode,
    billingEntity,
    coveragePlanId,
    insurerKey,
  };

  let best = null;
  let bestScore = -1;
  for (const entry of scoped) {
    const score = scoreEntry(entry, ctx);
    if (score > bestScore) {
      bestScore = score;
      best = entry;
    }
  }

  if (best && toDecimalNumber(best.unit_price) > 0) {
    return {
      unitPrice: toMoneyString(best.unit_price),
      currency: best.currency || options.currency || null,
      priceBookEntryId: best.id,
      paymentMode,
      billingEntity,
      coveragePlanId: best.coverage_plan_id || coveragePlanId,
      insurerKey: best.insurer_key || insurerKey,
      source: 'PRICE_BOOK',
      priceSource: billingEntity,
      catalogType,
      catalogItemId,
    };
  }

  const fallback = await resolveCatalogFallback({
    catalogType,
    catalogItemId,
    tenantId,
    facilityId,
    billingEntity,
  });

  if (fallback) {
    return {
      unitPrice: fallback.unitPrice,
      currency: fallback.currency || options.currency || null,
      priceBookEntryId: null,
      paymentMode,
      billingEntity,
      coveragePlanId,
      insurerKey,
      source: fallback.source,
      priceSource: fallback.priceSource || billingEntity,
      catalogType,
      catalogItemId,
    };
  }

  return {
    unitPrice: null,
    currency: options.currency || null,
    priceBookEntryId: null,
    paymentMode,
    billingEntity,
    coveragePlanId,
    insurerKey,
    source: 'UNRESOLVED',
    priceSource: billingEntity,
    catalogType,
    catalogItemId,
  };
};

/**
 * Resolve many line items in parallel.
 *
 * @param {Object} options
 * @param {Array<Object>} options.items
 * @returns {Promise<Array<Object>>}
 */
const resolveUnitPrices = async (options = {}) => {
  const items = Array.isArray(options.items) ? options.items : [];
  return Promise.all(
    items.map((item) =>
      resolveUnitPrice({
        ...options,
        catalogType: item.catalogType || item.catalog_type,
        catalogItemId: item.catalogItemId || item.catalog_item_id || item.id,
        billingEntity: item.billingEntity || item.billing_entity || item.price_source,
        currency: item.currency || options.currency,
      })
    )
  );
};

module.exports = {
  resolveUnitPrice,
  resolveUnitPrices,
  normalizeBillingEntity,
  normalizePaymentMode,
  normalizeCatalogType,
  toMoneyString,
  toDecimalNumber,
};
