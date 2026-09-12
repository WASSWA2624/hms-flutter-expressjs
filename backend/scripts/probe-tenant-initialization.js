#!/usr/bin/env node
/**
 * Development probe: what does creating a tenant actually write?
 *
 * Drives the real creation paths - self-serve registration, platform-admin
 * tenant create, facility create, registration approval, and the first HR
 * workspace read - and reports the per-table row counts each one leaves behind.
 * Supports step 04 of the Fairbanks fixes.
 *
 * This script WRITES (it creates throwaway tenants), so it refuses to run
 * against production through the shared demo-safety guard.
 *
 * Usage:
 *   node scripts/probe-tenant-initialization.js
 *   node scripts/probe-tenant-initialization.js --json
 */

require('module-alias/register');

const path = require('path');

const BACKEND_ROOT = path.join(__dirname, '..');

try {
  const moduleAlias = require('module-alias');
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
  moduleAlias.addAlias(
    '@prisma/client/runtime',
    path.join(BACKEND_ROOT, 'node_modules', '@prisma', 'client', 'runtime')
  );
} catch (error) {
  console.error('Failed to register probe aliases:', error);
  process.exit(1);
}

const { registerAllModuleAliases } = require('@lib/aliases');

registerAllModuleAliases();

const prisma = require('@prisma/client');
const { assertDemoTaskAllowed } = require('./demo-safety');

/** Tenant-scoped tables scanned for every snapshot; filled in at startup. */
const MODELS = [];

/** Emails the probe intercepted instead of sending. */
const capturedEmails = [];

/** Silence the verification email so the probe never sends mail. */
const muteEmail = () => {
  const notifications = require('@lib/notifications');
  notifications.sendEmail = async (payload) => {
    capturedEmails.push(payload);
    return { sent: true, provider: 'probe-mock' };
  };
};

const extractVerificationCode = (payload) => {
  const match = String(payload?.text || payload?.html || '').match(/\b(\d{6})\b/);
  return match ? match[1] : null;
};

const tenantScopedModels = () => {
  const { Prisma } = require('.prisma/client');
  return Prisma.dmmf.datamodel.models
    .filter((model) => model.fields.some((field) => field.name === 'tenant_id'))
    .map((model) => model.name)
    .filter((name) => name !== 'tenant')
    .filter((name) => typeof prisma[name]?.count === 'function')
    .sort();
};

/** Row counts for one tenant across every tenant-scoped table (non-zero only). */
const snapshot = async (tenantId) => {
  const counts = {};

  for (const model of MODELS) {
    const total = await prisma[model].count({ where: { tenant_id: tenantId } });
    if (total > 0) counts[model] = total;
  }

  const derived = {
    'user_profile*': await prisma.user_profile.count({
      where: { user: { tenant_id: tenantId } },
    }),
    'verification_token*': await prisma.verification_token.count({
      where: { user: { tenant_id: tenantId } },
    }),
    'module_subscription*': await prisma.module_subscription.count({
      where: { subscription: { tenant_id: tenantId } },
    }),
  };

  for (const [table, total] of Object.entries(derived)) {
    if (total > 0) counts[table] = total;
  }

  return counts;
};

const diff = (before, after) => {
  const delta = {};
  const tables = new Set([...Object.keys(before), ...Object.keys(after)]);

  for (const table of tables) {
    const change = (after[table] || 0) - (before[table] || 0);
    if (change !== 0) delta[table] = change;
  }

  return delta;
};

const main = async () => {
  const safety = assertDemoTaskAllowed('tenant initialization probe');
  if (!safety.allowed) {
    console.error(
      'Refusing to run the tenant initialization probe: it creates throwaway '
      + 'tenants and must never touch a production database.'
    );
    process.exitCode = 1;
    return;
  }

  muteEmail();
  MODELS.push(...tenantScopedModels());

  const authService = require('@services/auth/auth.service');
  const tenantService = require('@services/tenant/tenant.service');
  const facilityService = require('@services/facility/facility.service');
  const accessAdminWorkspaceService = require('@services/access-admin-workspace/access-admin-workspace.service');
  const hrWorkspaceService = require('@services/hr-workspace/hr-workspace.service');

  const suffix = Date.now();
  const stages = [];
  const record = (stage, counts, delta) => stages.push({ stage, counts, delta });

  // --- Path A1: self-serve registration ----------------------------------
  const email = `probe-tenant-${suffix}@example.com`;

  await authService.register({
    email,
    password: 'Password123!',
    tenant_name: `Probe Org ${suffix}`,
    facility_name: `Probe Facility ${suffix}`,
    admin_name: 'Probe Admin',
    facility_type: 'CLINIC',
    phone: '256700000000',
    ip_address: '127.0.0.1',
    user_agent: 'tenant-initialization-probe',
    request_context: { locale: 'en' },
  });

  const registered = await prisma.user.findFirst({
    where: { email, deleted_at: null },
    select: { id: true, tenant_id: true, facility_id: true },
  });
  const afterRegister = await snapshot(registered.tenant_id);
  record('A1_self_serve_registration', afterRegister, afterRegister);

  // --- Path A1b: email verification (approval requires a verified email) --
  const code = extractVerificationCode(capturedEmails.at(-1));
  if (!code) {
    throw new Error('Verification code was not captured from the registration email.');
  }
  await authService.verifyEmail({ token: code, email });
  const afterVerify = await snapshot(registered.tenant_id);
  record('A1b_email_verified', afterVerify, diff(afterRegister, afterVerify));

  // --- Path A2: platform approval (provisions the trial subscription) -----
  const platformAdmin = await prisma.user.findFirst({
    where: {
      deleted_at: null,
      status: 'ACTIVE',
      roles: {
        some: { deleted_at: null, role: { name: 'PLATFORM_ADMIN', deleted_at: null } },
      },
    },
    select: { id: true },
  });

  let afterApproval = afterVerify;
  if (platformAdmin) {
    await accessAdminWorkspaceService.approveRegistration(
      registered.id,
      { id: platformAdmin.id, roles: ['PLATFORM_ADMIN'] },
      '127.0.0.1'
    );
    afterApproval = await snapshot(registered.tenant_id);
    record('A2_registration_approved', afterApproval, diff(afterVerify, afterApproval));
  } else {
    record('A2_registration_approved', afterVerify, { _skipped: 'no PLATFORM_ADMIN user' });
  }

  // --- Path A3: first HR workspace read (lazy default bootstrap) ----------
  await hrWorkspaceService
    .getReferenceData({
      tenant_id: registered.tenant_id,
      facility_id: registered.facility_id,
    })
    .catch((error) => {
      console.warn(`HR reference-data probe failed: ${error.message}`);
    });
  const afterHrRead = await snapshot(registered.tenant_id);
  record('A3_first_hr_workspace_read', afterHrRead, diff(afterApproval, afterHrRead));

  // --- Path B1: platform-admin tenant create ------------------------------
  const adminContext = {
    permissions: ['platform:admin'],
    user_id: platformAdmin?.id || null,
  };
  const adminTenant = await tenantService.createTenant(
    {
      name: `Probe Admin Org ${suffix}`,
      slug: `probe-admin-org-${suffix}`,
      is_active: true,
      // The self-serve probe tenant above is a near-name match; this probe
      // deliberately wants both, so acknowledge the similarity warning.
      confirm_similar: true,
    },
    adminContext
  );
  const afterAdminCreate = await snapshot(adminTenant.id);
  record('B1_platform_admin_tenant_create', afterAdminCreate, afterAdminCreate);

  // --- Path C1: additional facility create --------------------------------
  await facilityService.createFacility(
    {
      tenant_id: adminTenant.id,
      name: `Probe Extra Facility ${suffix}`,
      facility_type: 'CLINIC',
      is_active: true,
    },
    { ...adminContext, tenant_id: adminTenant.id }
  );
  const afterFacilityCreate = await snapshot(adminTenant.id);
  record(
    'C1_additional_facility_create',
    afterFacilityCreate,
    diff(afterAdminCreate, afterFacilityCreate)
  );

  const report = {
    measured_at: new Date().toISOString(),
    node_env: process.env.NODE_ENV || 'development',
    registration_tenant_id: registered.tenant_id,
    admin_tenant_id: adminTenant.id,
    stages,
  };

  if (process.argv.includes('--json')) {
    console.log(JSON.stringify(report, null, 2));
    return;
  }

  for (const entry of stages) {
    console.log(`\n### ${entry.stage}`);
    console.log(`    cumulative : ${JSON.stringify(entry.counts)}`);
    console.log(`    delta      : ${JSON.stringify(entry.delta)}`);
  }
  console.log(`\nregistration tenant : ${report.registration_tenant_id}`);
  console.log(`admin tenant        : ${report.admin_tenant_id}`);
};

main()
  .catch((error) => {
    console.error(`Probe failed: ${error.message}`);
    console.error(error.stack);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect().catch(() => {});
  });
