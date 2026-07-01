#!/usr/bin/env node
/**
 * End-to-end onboarding verification:
 * register -> verify email -> activate -> login (with trial subscription).
 */

require('module-alias/register');
const path = require('path');
const moduleAlias = require('module-alias');
const BACKEND_ROOT = path.join(__dirname, '..');

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
  path.join(BACKEND_ROOT, 'node_modules', '@prisma', 'client', 'runtime'),
);
const { registerAllModuleAliases } = require('@lib/aliases');
registerAllModuleAliases();

const capturedEmails = [];

const patchSendEmail = () => {
  const notifications = require('@lib/notifications');
  notifications.sendEmail = async (payload) => {
    capturedEmails.push(payload);
    return { sent: true, provider: 'e2e-mock' };
  };
};

const extractVerificationCode = (payload) => {
  const text = String(payload?.text || payload?.html || '');
  const match = text.match(/\b(\d{6})\b/);
  return match ? match[1] : null;
};

const main = async () => {
  patchSendEmail();

  const prisma = require('@prisma/client');
  const authService = require('@services/auth/auth.service');
  const accessAdminWorkspaceService = require('@services/access-admin-workspace/access-admin-workspace.service');

  const suffix = Date.now();
  const email = `e2e-onboard-${suffix}@example.com`;
  const password = 'Password123!';
  const phone = '256701234567';

  console.log(`[e2e] registering ${email}`);

  await authService.register({
    email,
    password,
    tenant_name: `E2E Org ${suffix}`,
    facility_name: `E2E Facility ${suffix}`,
    admin_name: 'E2E Admin',
    facility_type: 'CLINIC',
    phone,
    ip_address: '127.0.0.1',
    user_agent: 'onboarding-e2e',
    request_context: { locale: 'en' },
  });

  const verificationEmail = capturedEmails.at(-1);
  const code = extractVerificationCode(verificationEmail);
  if (!code) {
    throw new Error('Verification code was not captured from registration email.');
  }

  console.log('[e2e] verifying email');
  const verifyResult = await authService.verifyEmail({ token: code, email });
  if (!verifyResult.awaiting_platform_approval) {
    throw new Error('Expected awaiting_platform_approval after email verification.');
  }

  const user = await prisma.user.findFirst({
    where: { email, deleted_at: null },
    include: { tenant: true },
  });
  if (!user?.email_verified_at) {
    throw new Error('email_verified_at was not set.');
  }
  if (user.status !== 'PENDING') {
    throw new Error(`Expected PENDING after verify, got ${user.status}`);
  }

  console.log('[e2e] login blocked before activation');
  let blocked = false;
  try {
    await authService.login({ email, password });
  } catch (error) {
    blocked = error?.messageKey === 'errors.auth.account_pending_approval';
  }
  if (!blocked) {
    throw new Error('Login should be blocked with account_pending_approval.');
  }

  console.log('[e2e] activating registration');
  await accessAdminWorkspaceService.activateRegistration(
    user.id,
    { id: 'e2e-super-admin', roles: ['SUPER_ADMIN'] },
    '127.0.0.1'
  );

  const activated = await prisma.user.findFirst({ where: { id: user.id } });
  if (activated?.status !== 'ACTIVE') {
    throw new Error(`Expected ACTIVE after activation, got ${activated?.status}`);
  }

  const subscription = await prisma.subscription.findFirst({
    where: {
      tenant_id: user.tenant_id,
      deleted_at: null,
      status: 'TRIAL',
    },
  });
  if (!subscription) {
    throw new Error('TRIAL subscription was not provisioned.');
  }

  console.log('[e2e] logging in after activation');
  const loginResult = await authService.login({ email, password });
  if (!loginResult?.access_token) {
    throw new Error('Login did not return an access token.');
  }
  if (!Array.isArray(loginResult.user?.module_entitlements)) {
    throw new Error('Login user payload is missing module_entitlements.');
  }

  console.log('[e2e] onboarding flow passed');
  console.log(JSON.stringify({
    email,
    tenant_id: user.tenant_id,
    subscription_status: subscription.status,
    entitlement_count: loginResult.user.module_entitlements.length,
  }, null, 2));

  await prisma.$disconnect();
};

main().catch(async (error) => {
  console.error('[e2e] failed:', error?.message || error);
  try {
    const prisma = require('@prisma/client');
    await prisma.$disconnect();
  } catch {
    // ignore
  }
  process.exit(1);
});
