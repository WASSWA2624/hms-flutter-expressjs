/**
 * Repair OPD encounters stuck on Payment due after Billing already PAID the
 * consultation invoice. Reuses syncConsultationBillingFromInvoicePayment.
 *
 * Usage:
 *   node scripts/repair-stuck-consultation-payment-due.js
 *   node scripts/repair-stuck-consultation-payment-due.js --dry-run
 */

require('module-alias/register');
const path = require('path');

try {
  const moduleAlias = require('module-alias');
  const BACKEND_ROOT = path.join(__dirname, '..');
  const prismaRuntimePath = path.join(
    BACKEND_ROOT,
    'node_modules',
    '@prisma',
    'client',
    'runtime'
  );

  moduleAlias.addAliases({
    '@app': path.join(BACKEND_ROOT, 'src', 'app'),
    '@lib': path.join(BACKEND_ROOT, 'src', 'lib'),
    '@config': path.join(BACKEND_ROOT, 'src', 'config'),
    '@middlewares': path.join(BACKEND_ROOT, 'src', 'middlewares'),
    '@logs': path.join(BACKEND_ROOT, 'logs'),
    '@websockets': path.join(BACKEND_ROOT, 'src', 'websockets'),
    '@modules': path.join(BACKEND_ROOT, 'src', 'modules'),
    '@prisma/client': path.join(BACKEND_ROOT, 'src', 'prisma', 'client.js'),
  });
  moduleAlias.addAlias('@prisma/client/runtime', prismaRuntimePath);
} catch (error) {
  console.error('Failed to register module aliases:', error);
  process.exit(1);
}

try {
  const { registerAllModuleAliases } = require('@lib/aliases');
  registerAllModuleAliases();
} catch (error) {
  console.warn('Failed to register module aliases:', error.message);
}

const prisma = require('@prisma/client');
const opdFlowService = require('@services/opd-flow/opd-flow.service');

const PAID_BILLING_STATUSES = new Set(['PAID', 'SETTLED', 'CLEARED']);
const PAID_PAYMENT_STATUSES = new Set([
  'COMPLETED',
  'PAID',
  'SUCCESS',
  'SUCCESSFUL',
  'APPROVED',
]);

const parseArgs = (argv = process.argv.slice(2)) => ({
  dryRun: argv.includes('--dry-run'),
});

const isConsultationUnpaidSnapshot = (consultation = {}) => {
  if (consultation.require_payment === false) return false;
  if (String(consultation.payment_status || '').toUpperCase() === 'NOT_REQUIRED') {
    return false;
  }
  if (consultation.is_paid === true) return false;
  return !PAID_PAYMENT_STATUSES.has(
    String(consultation.payment_status || '').toUpperCase()
  );
};

const main = async () => {
  const { dryRun } = parseArgs();
  const openEncounters = await prisma.encounter.findMany({
    where: {
      deleted_at: null,
      status: 'OPEN',
      encounter_type: { in: ['OPD', 'EMERGENCY'] },
    },
    select: {
      id: true,
      human_friendly_id: true,
      patient_id: true,
      extension_json: true,
      patient: {
        select: {
          first_name: true,
          last_name: true,
          human_friendly_id: true,
        },
      },
    },
  });

  const candidates = [];
  for (const encounter of openEncounters) {
    const flow = encounter.extension_json?.opd_flow || {};
    const consultation = flow.consultation || {};
    if (!isConsultationUnpaidSnapshot(consultation)) continue;
    if (!consultation.invoice_id) continue;
    candidates.push({
      encounterId: encounter.id,
      encounterDisplayId: encounter.human_friendly_id || encounter.id,
      patientName: `${encounter.patient?.first_name || ''} ${
        encounter.patient?.last_name || ''
      }`.trim(),
      patientDisplayId: encounter.patient?.human_friendly_id || null,
      invoiceId: consultation.invoice_id,
      stage: flow.stage,
    });
  }

  console.log(
    `[repair] scanned ${openEncounters.length} open encounters; ${candidates.length} unpaid consultation snapshots`
  );

  let repaired = 0;
  let skipped = 0;
  let failed = 0;

  for (const candidate of candidates) {
    const invoice = await prisma.invoice.findFirst({
      where: {
        deleted_at: null,
        OR: [
          { id: candidate.invoiceId },
          { human_friendly_id: String(candidate.invoiceId).toUpperCase() },
        ],
      },
      include: {
        payments: {
          where: { deleted_at: null },
          orderBy: { created_at: 'desc' },
        },
      },
    });

    if (!invoice) {
      skipped += 1;
      console.log(
        `[skip] ${candidate.encounterDisplayId} invoice missing (${candidate.invoiceId})`
      );
      continue;
    }

    const invoicePaid =
      PAID_BILLING_STATUSES.has(String(invoice.billing_status || '').toUpperCase()) ||
      PAID_BILLING_STATUSES.has(String(invoice.status || '').toUpperCase());
    if (!invoicePaid) {
      skipped += 1;
      console.log(
        `[skip] ${candidate.encounterDisplayId} invoice ${
          invoice.human_friendly_id || invoice.id
        } still ${invoice.billing_status}/${invoice.status}`
      );
      continue;
    }

    const payment =
      invoice.payments.find((entry) =>
        PAID_PAYMENT_STATUSES.has(String(entry.status || '').toUpperCase())
      ) || invoice.payments[0] || null;

    console.log(
      `[repair] ${candidate.patientName || 'Unknown'} ${
        candidate.patientDisplayId || ''
      } ${candidate.encounterDisplayId} ← ${
        invoice.human_friendly_id || invoice.id
      } (${dryRun ? 'dry-run' : 'apply'})`
    );

    if (dryRun) {
      repaired += 1;
      continue;
    }

    try {
      const snapshot = await opdFlowService.syncConsultationBillingFromInvoicePayment({
        invoiceId: invoice.id,
        payment,
        context: {
          user_id: null,
          tenant_id: invoice.tenant_id,
          facility_id: invoice.facility_id,
          source: 'REPAIR_STUCK_CONSULTATION_PAYMENT_DUE',
        },
      });
      if (!snapshot) {
        failed += 1;
        console.log(
          `[fail] ${candidate.encounterDisplayId} sync returned null`
        );
        continue;
      }
      repaired += 1;
      console.log(
        `[ok] ${candidate.encounterDisplayId} → ${
          snapshot.flow?.stage || snapshot.stage || 'updated'
        }`
      );
    } catch (error) {
      failed += 1;
      console.error(
        `[fail] ${candidate.encounterDisplayId}:`,
        error?.message || error
      );
    }
  }

  console.log(
    `[repair] done repaired=${repaired} skipped=${skipped} failed=${failed} dryRun=${dryRun}`
  );
  await prisma.$disconnect();
  process.exit(failed > 0 ? 1 : 0);
};

main().catch(async (error) => {
  console.error(error);
  try {
    await prisma.$disconnect();
  } catch (_err) {
    // ignore
  }
  process.exit(1);
});
