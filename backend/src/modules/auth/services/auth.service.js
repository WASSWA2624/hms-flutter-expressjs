/**
 * Auth service
 *
 * @module modules/auth/services
 * @description Business logic for authentication operations.
 */

const authRepository = require('@repositories/auth/auth.repository');
const { hashPassword, comparePassword } = require('@lib/crypto');
const { generateToken, generateRefreshToken } = require('@lib/jwt');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { translate, resolveLocale } = require('@lib/i18n');
const { sendEmail } = require('@lib/notifications');
const { logger } = require('@lib/logging');
const { resolveTenantModuleEntitlements } = require('@lib/subscriptions/tenant-entitlements');
const {
  resolvePlatformAdminContact,
  resolveTenantSubscriptionSummary,
} = require('@lib/subscriptions/tenant-subscription-summary');
const {
  resolveOrgAdminContacts,
} = require('@lib/authorization/org-admin-contacts');
const {
  resolveEffectiveAccess,
} = require('@lib/authorization/effective-access');
const env = require('@config/env');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const EMAIL_VERIFICATION_TOKEN_TYPE = 'EMAIL_VERIFICATION';
const PHONE_VERIFICATION_TOKEN_TYPE = 'PHONE_VERIFICATION';
const PASSWORD_RESET_TOKEN_TYPE = 'PASSWORD_RESET';
const EMAIL_VERIFICATION_EXPIRY_MINUTES = 15;
const PASSWORD_RESET_EXPIRY_HOURS = 1;
const MAX_LOCATION_LENGTH = 255;
const MAX_INTERESTS_LENGTH = 2000;

const hashToken = (value) =>
  crypto.createHash('sha256').update(String(value || '')).digest('hex');

const resolveSessionExpiryDate = () =>
  new Date(Date.now() + Number(env.AUTH_SESSION_TTL_DAYS || 7) * 24 * 60 * 60 * 1000);

const resolveAccountStatusErrorKey = (status) => {
  if (status === 'PENDING') return 'errors.auth.account_pending';
  if (status === 'SUSPENDED') return 'errors.auth.account_suspended';
  return 'errors.auth.account_inactive';
};

const isEmailVerified = (user = {}) => Boolean(user.email_verified_at);

const resolvePendingAccountError = async (user = {}) => {
  if (!isEmailVerified(user)) {
    return {
      messageKey: 'errors.auth.email_verification_required',
      details: [{
        reason: 'email_verification_required',
        identifier_type: user.email ? 'email' : 'phone',
        email: user.email || null,
      }],
    };
  }

  const contactsPayload = await resolvePlatformAdminContactsForAuth();
  return {
    messageKey: 'errors.auth.account_pending_approval',
    details: [{
      reason: 'platform_approval_required',
      email: user.email || null,
      phone: user.phone || null,
      ...contactsPayload,
    }],
  };
};

const assertUserCanAuthenticate = async (user = {}) => {
  if (user.status === 'ACTIVE') {
    return;
  }

  if (user.status === 'PENDING') {
    const pending = await resolvePendingAccountError(user);
    throw new HttpError(pending.messageKey, 403, pending.details);
  }

  throw new HttpError(resolveAccountStatusErrorKey(user.status), 403);
};

/**
 * Resolve platform admin contact(s) for auth messaging (login / verify).
 * Prefers live PLATFORM_ADMIN users, then env support contact.
 */
const resolvePlatformAdminContactsForAuth = async () => {
  const primary = resolvePlatformAdminContact();
  let contacts = [];
  try {
    const org = await resolveOrgAdminContacts({
      tenantId: null,
      facilityId: null,
    });
    contacts = Array.isArray(org.platform_admins) ? org.platform_admins : [];
  } catch (error) {
    logger.warn('Failed to resolve platform admin contacts for auth messaging.', {
      error: error?.message || String(error),
    });
  }

  const normalized = contacts
    .map((entry) => ({
      full_name: String(entry?.full_name || '').trim() || null,
      email: String(entry?.email || '').trim() || null,
      phone: String(entry?.phone || '').trim() || null,
    }))
    .filter((entry) => entry.email || entry.phone);

  if (normalized.length === 0 && (primary?.email || primary?.phone)) {
    normalized.push({
      full_name: null,
      email: primary.email || null,
      phone: primary.phone || null,
    });
  }

  return {
    platform_admin_contact: {
      email: primary?.email || normalized[0]?.email || null,
      phone: primary?.phone || normalized[0]?.phone || null,
    },
    platform_admin_contacts: normalized,
  };
};

const isSoftDeletedRecord = (record) => Boolean(record?.deleted_at);

const buildOrganizationDeactivatedError = (scope = 'tenant') => {
  const isFacility = scope === 'facility';
  return {
    messageKey: isFacility
      ? 'errors.auth.facility_deactivated'
      : 'errors.auth.tenant_deactivated',
    details: [
      {
        reason: isFacility ? 'facility_soft_deleted' : 'tenant_soft_deleted',
        platform_admin_contact: resolvePlatformAdminContact(),
      },
    ],
  };
};

/**
 * Soft-deleted tenants remain in DB but must not authenticate.
 * Permanently deleted tenants/users are absent and resolve as not found.
 */
const assertTenantAllowsLogin = (user = {}) => {
  const tenant = user.tenant;
  if (tenant === null && user.tenant_id) {
    throw new HttpError('errors.auth.user_not_found', 401);
  }
  if (isSoftDeletedRecord(tenant)) {
    const deactivated = buildOrganizationDeactivatedError('tenant');
    throw new HttpError(deactivated.messageKey, 403, deactivated.details);
  }
};

const assertFacilityAllowsLogin = (
  user = {},
  {
    selectedFacilityId = null,
    accessibleFacilities = [],
  } = {}
) => {
  const accessibleIds = new Set(
    (Array.isArray(accessibleFacilities) ? accessibleFacilities : [])
      .map((facility) => facility?.id)
      .filter(Boolean)
  );

  if (selectedFacilityId && accessibleIds.has(selectedFacilityId)) {
    return;
  }

  if (
    selectedFacilityId &&
    user.facility?.id === selectedFacilityId &&
    isSoftDeletedRecord(user.facility)
  ) {
    const deactivated = buildOrganizationDeactivatedError('facility');
    throw new HttpError(deactivated.messageKey, 403, deactivated.details);
  }

  if (
    !selectedFacilityId &&
    accessibleIds.size === 0 &&
    user.facility_id &&
    isSoftDeletedRecord(user.facility)
  ) {
    const deactivated = buildOrganizationDeactivatedError('facility');
    throw new HttpError(deactivated.messageKey, 403, deactivated.details);
  }
};

const APP_DISPLAY_NAME =
  String(env.APP_DISPLAY_NAME || 'Hospital Management System').trim() ||
  'Hospital Management System';
const VERIFICATION_EMAIL_APP_NAME = 'HOSSPI HMS';
const EMAIL_LOGO_CID = 'hms-app-logo';
const EMAIL_LOGO_PATHS = [
  path.resolve(__dirname, '../../../../../frontend/assets/logos/logo.png'),
  path.resolve(__dirname, '../../../../../frontend/web/favicon.png'),
  path.resolve(__dirname, '../../../../../hms-frontend/public/logo.png'),
  path.resolve(__dirname, '../../../../../hms-frontend/assets/logo.png'),
  path.resolve(__dirname, '../../../../public/logo.png'),
];

const toNormalizedString = (value) => String(value || '').trim();

const uniqueValues = (values = []) => Array.from(new Set(values.filter(Boolean)));

const buildAuthUserPayload = (user = {}, moduleEntitlements = null) => {
  const { password_hash, permissions, ...userData } = user;
  const access = resolveEffectiveAccess(user, {
    moduleEntitlements,
    // Grant union only here; plan gate applied in enrich when entitlements load.
    applyPlanGate: moduleEntitlements != null,
    applyAssignedModuleGate: true,
  });

  return {
    ...userData,
    permissions: access.permissions,
    permission_names: access.permissions,
    direct_permissions: access.direct_permissions,
    role_permissions: access.role_permissions,
    module_permissions: access.module_permissions,
    assigned_modules: access.assigned_modules,
  };
};

const enrichAuthUserPayload = async (user = {}) => {
  if (!user?.tenant_id) {
    return buildAuthUserPayload(user);
  }

  const [module_entitlements, subscription_summary, orgAdminContacts] =
    await Promise.all([
      resolveTenantModuleEntitlements(user.tenant_id),
      resolveTenantSubscriptionSummary(user.tenant_id),
      resolveOrgAdminContacts({
        tenantId: user.tenant_id,
        facilityId: user.facility_id || null,
      }),
    ]);

  const base = buildAuthUserPayload(user, module_entitlements);

  return {
    ...base,
    module_entitlements,
    subscription_summary,
    platform_admin_contact: resolvePlatformAdminContact(),
    platform_admin_contacts: orgAdminContacts.platform_admins,
    tenant_admin_contacts: orgAdminContacts.tenant_admins,
    facility_admin_contacts: orgAdminContacts.facility_admins,
  };
};

const getBaseAppUrl = (requestContext = {}) => {
  const requestOrigin = String(requestContext.origin || '').trim();

  if (env.NODE_ENV !== 'production' && requestOrigin) {
    try {
      const originUrl = new URL(requestOrigin);
      if (originUrl.protocol === 'http:' || originUrl.protocol === 'https:') {
        return originUrl.origin.replace(/\/+$/, '');
      }
    } catch {
      // Fall back to the configured public URL.
    }
  }

  return String(env.APP_PUBLIC_URL || '').replace(/\/+$/, '');
};

const buildResetPasswordLink = (token, email) =>
  `${getBaseAppUrl()}/reset-password?token=${encodeURIComponent(token)}&email=${encodeURIComponent(email)}`;

const buildLoginLink = () => `${getBaseAppUrl()}/login`;

const createEmailVerificationTokens = async (userId) => {
  await authRepository.deleteExpiredTokens(userId, EMAIL_VERIFICATION_TOKEN_TYPE);

  const code = crypto.randomInt(0, 1000000).toString().padStart(6, '0');
  const expiresAt = new Date(Date.now() + EMAIL_VERIFICATION_EXPIRY_MINUTES * 60 * 1000);

  await authRepository.createVerificationToken({
    user_id: userId,
    token_hash: hashToken(code),
    type: EMAIL_VERIFICATION_TOKEN_TYPE,
    expires_at: expiresAt,
  });

  return { code, expiresAt };
};

const createPasswordResetTokens = async (userId) => {
  await authRepository.deleteExpiredTokens(userId, PASSWORD_RESET_TOKEN_TYPE);

  const linkToken = crypto.randomBytes(32).toString('hex');
  const code = crypto.randomInt(0, 1000000).toString().padStart(6, '0');
  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + PASSWORD_RESET_EXPIRY_HOURS);

  await authRepository.createVerificationToken({
    user_id: userId,
    token_hash: hashToken(linkToken),
    type: PASSWORD_RESET_TOKEN_TYPE,
    expires_at: expiresAt,
  });

  await authRepository.createVerificationToken({
    user_id: userId,
    token_hash: hashToken(code),
    type: PASSWORD_RESET_TOKEN_TYPE,
    expires_at: expiresAt,
  });

  return { linkToken, code, expiresAt };
};

const escapeHtml = (value) =>
  String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const resolveEmailLogoAsset = () => {
  const logoPath = EMAIL_LOGO_PATHS.find((candidatePath) => {
    try {
      return fs.existsSync(candidatePath) && fs.statSync(candidatePath).isFile();
    } catch {
      return false;
    }
  });

  if (!logoPath) {
    return { logoSrc: null, attachments: [] };
  }

  return {
    logoSrc: `cid:${EMAIL_LOGO_CID}`,
    attachments: [
      {
        filename: path.basename(logoPath),
        path: logoPath,
        cid: EMAIL_LOGO_CID,
        contentDisposition: 'inline',
      },
    ],
  };
};

const resolveExpiryDate = (value) => {
  const candidate = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(candidate.getTime())) {
    return null;
  }
  return candidate;
};

const getRoleNames = (user = {}) => uniqueValues(
  (Array.isArray(user.roles) ? user.roles : [])
    .flatMap((entry) => {
      if (!entry) return [];
      if (typeof entry === 'string') {
        return [toNormalizedString(entry).toUpperCase()];
      }
      return [
        toNormalizedString(entry?.role?.name),
        toNormalizedString(entry?.name),
        toNormalizedString(entry?.role_name),
      ]
        .filter(Boolean)
        .map((value) => value.toUpperCase());
    })
    .filter(Boolean)
);

const formatExpiryDateTime = (expiresAt, locale, timeZone) => {
  const resolvedTimeZone =
    typeof timeZone === 'string' ? timeZone.trim().slice(0, 64) : '';
  try {
    return new Intl.DateTimeFormat(locale || 'en', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      second: '2-digit',
      timeZoneName: 'short',
      ...(resolvedTimeZone ? { timeZone: resolvedTimeZone } : {}),
    }).format(expiresAt);
  } catch {
    try {
      // Invalid client timezone — fall back to locale defaults (no forced zone).
      return new Intl.DateTimeFormat(locale || 'en', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
        second: '2-digit',
        timeZoneName: 'short',
      }).format(expiresAt);
    } catch {
      return expiresAt.toISOString();
    }
  }
};

const buildVerificationEmailMessage = ({
  code,
  expiresAt,
  locale,
  timeZone,
}) => {
  const resolvedLocale = resolveLocale(locale);
  const expiryDate =
    resolveExpiryDate(expiresAt) ||
    new Date(Date.now() + EMAIL_VERIFICATION_EXPIRY_MINUTES * 60 * 1000);
  const expiresAtLabel = formatExpiryDateTime(
    expiryDate,
    resolvedLocale,
    timeZone
  );
  const subject = translate('messages.auth.email_verification.subject', resolvedLocale, {
    app_name: VERIFICATION_EMAIL_APP_NAME,
  });
  const preheader = translate('messages.auth.email_verification.preheader', resolvedLocale, {
    code,
  });
  const expiryLine = translate('messages.auth.email_verification.expires_at', resolvedLocale, {
    minutes: EMAIL_VERIFICATION_EXPIRY_MINUTES,
    expires_at: expiresAtLabel,
  });
  const { logoSrc, attachments } = resolveEmailLogoAsset();

  const text = [
    subject,
    '',
    code,
    expiryLine,
  ].join('\n');

  const safeExpiryLine = escapeHtml(expiryLine);
  const safeCode = escapeHtml(code);
  const safeLogoSrc = logoSrc ? escapeHtml(logoSrc) : '';
  const logoHeaderCell = logoSrc
    ? `<td style="padding:0 8px 0 0;vertical-align:middle;width:34px;">
        <img src="${safeLogoSrc}" alt="${escapeHtml(`${VERIFICATION_EMAIL_APP_NAME} logo`)}" width="28" height="28" style="display:block;width:28px;height:28px;border:0;outline:none;text-decoration:none;background:#ffffff;" />
      </td>`
    : '';

  const html = `<!doctype html>
<html lang="${escapeHtml(resolvedLocale)}">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:0;background:#f5f7fb;">
  <div style="display:none!important;opacity:0;color:transparent;height:0;width:0;overflow:hidden;visibility:hidden;mso-hide:all;">
    ${escapeHtml(preheader)}
  </div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#f5f7fb;padding:12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:360px;background:#ffffff;border:1px solid #dbe4f3;">
          <tr>
            <td align="center" style="padding:16px 18px 14px;font-family:'Segoe UI',Tahoma,Arial,sans-serif;color:#0f172a;">
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin:0 0 12px;">
                <tr>
                  ${logoHeaderCell}
                  <td style="vertical-align:middle;">
                    <h1 style="margin:0;font-size:18px;line-height:24px;font-weight:700;color:#0f172a;">${escapeHtml(VERIFICATION_EMAIL_APP_NAME)}</h1>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 10px;font-family:Consolas,Monaco,'Courier New',monospace;font-size:30px;line-height:34px;font-weight:700;color:#0f172a;letter-spacing:0.16em;">${safeCode}</p>
              <p style="margin:0;font-size:12px;line-height:16px;color:#64748b;">${safeExpiryLine}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  return { subject, text, html, attachments };
};

const sendVerificationEmail = async ({
  email,
  code,
  expiresAt,
  locale,
  timeZone,
}) => {
  const payload = buildVerificationEmailMessage({
    code,
    expiresAt,
    locale,
    timeZone,
  });

  return sendEmail({
    to: email,
    subject: payload.subject,
    text: payload.text,
    html: payload.html,
    attachments: payload.attachments,
  });
};

const sendPasswordResetEmail = async ({
  email,
  resetToken,
  resetCode,
  expiresAt,
  locale,
  timeZone,
}) => {
  const resolvedLocale = resolveLocale(locale);
  const link = buildResetPasswordLink(resetToken, email);
  const expiryDate =
    resolveExpiryDate(expiresAt) ||
    new Date(Date.now() + PASSWORD_RESET_EXPIRY_HOURS * 60 * 60 * 1000);
  const expiresAtLabel = formatExpiryDateTime(
    expiryDate,
    resolvedLocale,
    timeZone
  );
  const subject = translate('messages.auth.password_reset.subject', resolvedLocale, {
    app_name: APP_DISPLAY_NAME,
  });
  const preheader = translate('messages.auth.password_reset.preheader', resolvedLocale, {
    app_name: APP_DISPLAY_NAME,
  });
  const title = translate('messages.auth.password_reset.title', resolvedLocale);
  const intro = translate('messages.auth.password_reset.intro', resolvedLocale, {
    app_name: APP_DISPLAY_NAME,
  });
  const actionLabel = translate('messages.auth.password_reset.action', resolvedLocale);
  const fallbackLabel = translate('messages.auth.password_reset.fallback', resolvedLocale);
  const codeIntro = translate('messages.auth.password_reset.code_intro', resolvedLocale);
  const expiryLine = translate('messages.auth.password_reset.expires_at', resolvedLocale, {
    expires_at: expiresAtLabel,
  });
  const ignoreLine = translate('messages.auth.password_reset.ignore', resolvedLocale);
  const signature = translate('messages.auth.password_reset.signature', resolvedLocale, {
    app_name: APP_DISPLAY_NAME,
  });
  const logoAlt = translate('messages.auth.password_reset.logo_alt', resolvedLocale, {
    app_name: APP_DISPLAY_NAME,
  });
  const { logoSrc, attachments } = resolveEmailLogoAsset();
  const safeCode = escapeHtml(resetCode);
  const text = [
    subject,
    '',
    intro,
    '',
    `${actionLabel}: ${link}`,
    '',
    `${fallbackLabel}: ${link}`,
    '',
    codeIntro,
    resetCode,
    '',
    expiryLine,
    '',
    ignoreLine,
    '',
    signature,
  ].join('\n');
  const html = `<!doctype html>
<html lang="${escapeHtml(resolvedLocale)}">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${escapeHtml(subject)}</title>
</head>
<body style="font-family:Segoe UI,Tahoma,Arial,sans-serif;background:#f4f7fb;padding:20px;">
  <div style="display:none!important;opacity:0;color:transparent;height:0;width:0;overflow:hidden;visibility:hidden;mso-hide:all;">
    ${escapeHtml(preheader)}
  </div>
  <div style="max-width:640px;margin:0 auto;background:#ffffff;border:1px solid #dbe4f3;border-radius:12px;padding:24px;">
    <div style="display:flex;align-items:center;gap:14px;margin-bottom:16px;">
      ${logoSrc
        ? `<img src="${escapeHtml(logoSrc)}" alt="${escapeHtml(logoAlt)}" width="44" height="44" style="display:block;width:44px;height:44px;border:0;border-radius:10px;background:#ffffff;padding:4px;" />`
        : ''}
      <div>
        <p style="margin:0 0 4px;font-size:12px;letter-spacing:0.08em;text-transform:uppercase;color:#64748b;">${escapeHtml(APP_DISPLAY_NAME)}</p>
        <h1 style="margin:0;font-size:22px;color:#0f172a;">${escapeHtml(title)}</h1>
      </div>
    </div>
    <p style="margin:0 0 14px;color:#1e293b;line-height:1.5;">${escapeHtml(intro)}</p>
    <p style="margin:0 0 16px;">
      <a href="${escapeHtml(link)}" style="display:inline-block;background:#0b88e6;color:#ffffff;text-decoration:none;padding:10px 16px;border-radius:8px;font-weight:700;">${escapeHtml(actionLabel)}</a>
    </p>
    <p style="margin:0 0 10px;color:#334155;word-break:break-word;">
      ${escapeHtml(fallbackLabel)}<br />
      <a href="${escapeHtml(link)}" style="color:#0b66c3;word-break:break-word;">${escapeHtml(link)}</a>
    </p>
    <p style="margin:0 0 8px;color:#334155;font-size:14px;line-height:1.5;">${escapeHtml(codeIntro)}</p>
    <p style="margin:0 0 16px;font-family:Consolas,Monaco,'Courier New',monospace;font-size:28px;line-height:32px;font-weight:700;color:#0f172a;letter-spacing:0.16em;">${safeCode}</p>
    <p style="margin:0 0 10px;color:#475569;font-size:13px;">${escapeHtml(expiryLine)}</p>
    <p style="margin:0 0 18px;color:#475569;font-size:13px;">${escapeHtml(ignoreLine)}</p>
    <p style="margin:0;color:#0f172a;white-space:pre-line;">${escapeHtml(signature)}</p>
  </div>
</body>
</html>`;

  return sendEmail({
    to: email,
    subject,
    text,
    html,
    attachments,
  });
};

/**
 * Build the post-verification “awaiting approval” email.
 *
 * Sent after a new tenant verifies their email and before platform approval
 * unlocks login.
 *
 * @param {Object} params
 * @param {string} [params.locale]
 * @param {{ email?: string|null, phone?: string|null }} [params.platformAdminContact]
 * @returns {{ subject: string, text: string, html: string, attachments: Array }}
 */
const buildAwaitingApprovalEmailMessage = ({
  locale,
  platformAdminContact = {},
} = {}) => {
  const resolvedLocale = resolveLocale(locale);
  const loginLink = buildLoginLink();
  const adminEmail = toNormalizedString(platformAdminContact?.email) || null;
  const adminPhone = toNormalizedString(platformAdminContact?.phone) || null;
  const subject = translate(
    'messages.auth.awaiting_approval.subject',
    resolvedLocale,
    { app_name: APP_DISPLAY_NAME }
  );
  const preheader = translate(
    'messages.auth.awaiting_approval.preheader',
    resolvedLocale
  );
  const title = translate(
    'messages.auth.awaiting_approval.title',
    resolvedLocale
  );
  const intro = translate(
    'messages.auth.awaiting_approval.intro',
    resolvedLocale,
    { app_name: APP_DISPLAY_NAME }
  );
  const nextStepsTitle = translate(
    'messages.auth.awaiting_approval.next_steps_title',
    resolvedLocale
  );
  const stepLogin = translate(
    'messages.auth.awaiting_approval.step_login',
    resolvedLocale
  );
  const stepWait = translate(
    'messages.auth.awaiting_approval.step_wait',
    resolvedLocale
  );
  const stepDemo = translate(
    'messages.auth.awaiting_approval.step_demo',
    resolvedLocale
  );
  const loginAction = translate(
    'messages.auth.awaiting_approval.login_action',
    resolvedLocale
  );
  const contactIntro = translate(
    'messages.auth.awaiting_approval.contact_intro',
    resolvedLocale
  );
  const signature = translate(
    'messages.auth.awaiting_approval.signature',
    resolvedLocale,
    { app_name: APP_DISPLAY_NAME }
  );
  const logoAlt = translate(
    'messages.auth.awaiting_approval.logo_alt',
    resolvedLocale,
    { app_name: APP_DISPLAY_NAME }
  );
  const { logoSrc, attachments } = resolveEmailLogoAsset();

  const contactLines = [];
  if (adminEmail) {
    contactLines.push(
      translate('messages.auth.awaiting_approval.contact_email', resolvedLocale, {
        email: adminEmail,
      })
    );
  }
  if (adminPhone) {
    contactLines.push(
      translate('messages.auth.awaiting_approval.contact_phone', resolvedLocale, {
        phone: adminPhone,
      })
    );
  }

  const textParts = [
    subject,
    '',
    intro,
    '',
    nextStepsTitle,
    `1. ${stepLogin}`,
    loginLink,
    `2. ${stepWait}`,
    `3. ${stepDemo}`,
  ];
  if (contactLines.length > 0) {
    textParts.push('', contactIntro, ...contactLines);
  }
  textParts.push('', signature);

  const contactHtml = contactLines.length
    ? `<p style="margin:0 0 8px;color:#334155;font-size:14px;line-height:1.5;">${escapeHtml(contactIntro)}</p>
       <ul style="margin:0 0 16px;padding-left:18px;color:#334155;font-size:14px;line-height:1.5;">
         ${contactLines
           .map((line) => `<li>${escapeHtml(line)}</li>`)
           .join('')}
       </ul>`
    : '';

  const html = `<!doctype html>
<html lang="${escapeHtml(resolvedLocale)}">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${escapeHtml(subject)}</title>
</head>
<body style="font-family:Segoe UI,Tahoma,Arial,sans-serif;background:#f4f7fb;padding:20px;">
  <div style="display:none!important;opacity:0;color:transparent;height:0;width:0;overflow:hidden;visibility:hidden;mso-hide:all;">
    ${escapeHtml(preheader)}
  </div>
  <div style="max-width:640px;margin:0 auto;background:#ffffff;border:1px solid #dbe4f3;border-radius:12px;padding:24px;">
    <div style="display:flex;align-items:center;gap:14px;margin-bottom:16px;">
      ${logoSrc
        ? `<img src="${escapeHtml(logoSrc)}" alt="${escapeHtml(logoAlt)}" width="44" height="44" style="display:block;width:44px;height:44px;border:0;border-radius:10px;background:#ffffff;padding:4px;" />`
        : ''}
      <div>
        <p style="margin:0 0 4px;font-size:12px;letter-spacing:0.08em;text-transform:uppercase;color:#64748b;">${escapeHtml(APP_DISPLAY_NAME)}</p>
        <h1 style="margin:0;font-size:22px;color:#0f172a;">${escapeHtml(title)}</h1>
      </div>
    </div>
    <p style="margin:0 0 14px;color:#1e293b;line-height:1.5;">${escapeHtml(intro)}</p>
    <p style="margin:0 0 8px;color:#0f172a;font-weight:700;">${escapeHtml(nextStepsTitle)}</p>
    <ol style="margin:0 0 16px;padding-left:18px;color:#334155;font-size:14px;line-height:1.5;">
      <li style="margin-bottom:8px;">
        ${escapeHtml(stepLogin)}
        <div style="margin-top:8px;">
          <a href="${escapeHtml(loginLink)}" style="display:inline-block;background:#0b88e6;color:#ffffff;text-decoration:none;padding:10px 16px;border-radius:8px;font-weight:700;">${escapeHtml(loginAction)}</a>
        </div>
        <div style="margin-top:8px;word-break:break-word;">
          <a href="${escapeHtml(loginLink)}" style="color:#0b66c3;word-break:break-word;">${escapeHtml(loginLink)}</a>
        </div>
      </li>
      <li style="margin-bottom:8px;">${escapeHtml(stepWait)}</li>
      <li>${escapeHtml(stepDemo)}</li>
    </ol>
    ${contactHtml}
    <p style="margin:0;color:#0f172a;white-space:pre-line;">${escapeHtml(signature)}</p>
  </div>
</body>
</html>`;

  return {
    subject,
    text: textParts.join('\n'),
    html,
    attachments,
  };
};

/**
 * Send the post-verification awaiting-approval email (best effort).
 *
 * @param {Object} params
 * @param {string} params.email
 * @param {string} [params.locale]
 * @param {{ email?: string|null, phone?: string|null }} [params.platformAdminContact]
 * @returns {Promise<{ sent?: boolean, provider?: string }|null>}
 */
const sendAwaitingApprovalEmail = async ({
  email,
  locale,
  platformAdminContact,
}) => {
  const payload = buildAwaitingApprovalEmailMessage({
    locale,
    platformAdminContact,
  });

  return sendEmail({
    to: email,
    subject: payload.subject,
    text: payload.text,
    html: payload.html,
    attachments: payload.attachments,
  });
};

/**
 * Build the post-activation account-approved email.
 *
 * @param {Object} params
 * @param {string} [params.locale]
 * @param {string} [params.adminName]
 * @param {string} [params.facilityName]
 * @returns {{ subject: string, text: string, html: string, attachments: Array }}
 */
const buildAccountApprovedEmailMessage = ({
  locale,
  adminName,
  facilityName,
} = {}) => {
  const resolvedLocale = resolveLocale(locale);
  const loginLink = buildLoginLink();
  const resolvedAdminName = toNormalizedString(adminName) || 'Admin';
  const resolvedFacilityName =
    toNormalizedString(facilityName) || 'your facility';
  const subject = translate(
    'messages.auth.account_approved.subject',
    resolvedLocale,
    { app_name: APP_DISPLAY_NAME }
  );
  const preheader = translate(
    'messages.auth.account_approved.preheader',
    resolvedLocale,
    { facility_name: resolvedFacilityName }
  );
  const title = translate(
    'messages.auth.account_approved.title',
    resolvedLocale
  );
  const intro = translate(
    'messages.auth.account_approved.intro',
    resolvedLocale,
    {
      app_name: APP_DISPLAY_NAME,
      admin_name: resolvedAdminName,
      facility_name: resolvedFacilityName,
    }
  );
  const nextStepsTitle = translate(
    'messages.auth.account_approved.next_steps_title',
    resolvedLocale
  );
  const stepLogin = translate(
    'messages.auth.account_approved.step_login',
    resolvedLocale
  );
  const stepWorkspace = translate(
    'messages.auth.account_approved.step_workspace',
    resolvedLocale
  );
  const stepTeam = translate(
    'messages.auth.account_approved.step_team',
    resolvedLocale
  );
  const loginAction = translate(
    'messages.auth.account_approved.login_action',
    resolvedLocale
  );
  const signature = translate(
    'messages.auth.account_approved.signature',
    resolvedLocale,
    { app_name: APP_DISPLAY_NAME }
  );
  const logoAlt = translate(
    'messages.auth.account_approved.logo_alt',
    resolvedLocale,
    { app_name: APP_DISPLAY_NAME }
  );
  const { logoSrc, attachments } = resolveEmailLogoAsset();

  const text = [
    subject,
    '',
    intro,
    '',
    nextStepsTitle,
    `1. ${stepLogin}`,
    loginLink,
    `2. ${stepWorkspace}`,
    `3. ${stepTeam}`,
    '',
    signature,
  ].join('\n');

  const html = `<!doctype html>
<html lang="${escapeHtml(resolvedLocale)}">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${escapeHtml(subject)}</title>
</head>
<body style="font-family:Segoe UI,Tahoma,Arial,sans-serif;background:#f4f7fb;padding:20px;">
  <div style="display:none!important;opacity:0;color:transparent;height:0;width:0;overflow:hidden;visibility:hidden;mso-hide:all;">
    ${escapeHtml(preheader)}
  </div>
  <div style="max-width:640px;margin:0 auto;background:#ffffff;border:1px solid #dbe4f3;border-radius:12px;padding:24px;">
    <div style="display:flex;align-items:center;gap:14px;margin-bottom:16px;">
      ${logoSrc
        ? `<img src="${escapeHtml(logoSrc)}" alt="${escapeHtml(logoAlt)}" width="44" height="44" style="display:block;width:44px;height:44px;border:0;border-radius:10px;background:#ffffff;padding:4px;" />`
        : ''}
      <div>
        <p style="margin:0 0 4px;font-size:12px;letter-spacing:0.08em;text-transform:uppercase;color:#64748b;">${escapeHtml(APP_DISPLAY_NAME)}</p>
        <h1 style="margin:0;font-size:22px;color:#0f172a;">${escapeHtml(title)}</h1>
      </div>
    </div>
    <p style="margin:0 0 14px;color:#1e293b;line-height:1.5;">${escapeHtml(intro)}</p>
    <p style="margin:0 0 8px;color:#0f172a;font-weight:700;">${escapeHtml(nextStepsTitle)}</p>
    <ol style="margin:0 0 16px;padding-left:18px;color:#334155;font-size:14px;line-height:1.5;">
      <li style="margin-bottom:8px;">
        ${escapeHtml(stepLogin)}
        <div style="margin-top:8px;">
          <a href="${escapeHtml(loginLink)}" style="display:inline-block;background:#0b88e6;color:#ffffff;text-decoration:none;padding:10px 16px;border-radius:8px;font-weight:700;">${escapeHtml(loginAction)}</a>
        </div>
        <div style="margin-top:8px;word-break:break-all;">
          <a href="${escapeHtml(loginLink)}" style="color:#0b66c3;word-break:break-word;">${escapeHtml(loginLink)}</a>
        </div>
      </li>
      <li style="margin-bottom:8px;">${escapeHtml(stepWorkspace)}</li>
      <li>${escapeHtml(stepTeam)}</li>
    </ol>
    <p style="margin:0;color:#0f172a;white-space:pre-line;">${escapeHtml(signature)}</p>
  </div>
</body>
</html>`;

  return {
    subject,
    text,
    html,
    attachments,
  };
};

/**
 * Notify the registering tenant admin that platform approval succeeded.
 * Best-effort — callers should not block activation on delivery.
 *
 * @param {Object} params
 * @param {string} params.email
 * @param {string} [params.locale]
 * @param {string} [params.adminName]
 * @param {string} [params.facilityName]
 * @returns {Promise<{ sent?: boolean, provider?: string }|null>}
 */
const sendAccountApprovedEmail = async ({
  email,
  locale,
  adminName,
  facilityName,
}) => {
  const payload = buildAccountApprovedEmailMessage({
    locale,
    adminName,
    facilityName,
  });

  return sendEmail({
    to: email,
    subject: payload.subject,
    text: payload.text,
    html: payload.html,
    attachments: payload.attachments,
  });
};

const ensureEmailDelivered = (deliveryResult, context, options = {}) => {
  if (deliveryResult?.sent) {
    return;
  }

  // Local setups often have SMTP misconfigured; do not block registration/resend
  // in development so facility bootstrap remains testable.
  if (env.NODE_ENV === 'development') {
    logger.warn('Email delivery unavailable; continuing auth flow in development.', {
      context: context || 'verification_email',
      provider: deliveryResult?.provider || 'unknown',
      verification_code: options.code || undefined,
    });
    return;
  }

  throw new HttpError('errors.auth.email_delivery_unavailable', 503, [
    {
      context: context || 'verification_email',
      provider: deliveryResult?.provider || 'unknown',
    },
  ]);
};

/**
 * Deliver an auth email without letting SMTP latency hang the HTTP response in
 * development. Production still awaits delivery and enforces ensureEmailDelivered.
 */
const deliverAuthEmail = async (sendPromise, context, options = {}) => {
  if (env.NODE_ENV === 'development') {
    logger.warn('Auth email delivery queued; continuing auth flow in development.', {
      context: context || 'verification_email',
      verification_code: options.code || undefined,
    });

    void Promise.resolve(sendPromise)
      .then((deliveryResult) => {
        ensureEmailDelivered(deliveryResult, context, options);
      })
      .catch((error) => {
        logger.warn('Background auth email delivery failed in development.', {
          context: context || 'verification_email',
          error: error?.message || 'unknown_error',
          verification_code: options.code || undefined,
        });
      });
    return;
  }

  const deliveryResult = await sendPromise;
  ensureEmailDelivered(deliveryResult, context, options);
};

const resolveAdminDisplayName = (user, fallbackName) => {
  const first = String(user?.profile?.first_name || '').trim();
  const last = String(user?.profile?.last_name || '').trim();
  const fullName = `${first} ${last}`.trim();
  if (fullName) return fullName;

  const fallback = String(fallbackName || '').trim();
  if (fallback) return fallback;

  if (user?.email && user.email.includes('@')) {
    return user.email.split('@')[0];
  }

  return 'Admin';
};

const normalizeComparableText = (value) =>
  String(value || '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();

const normalizeComparableEnum = (value) =>
  String(value || '')
    .trim()
    .toUpperCase();

const normalizeOptionalText = (value, maxLength) => {
  if (value === undefined || value === null) return null;
  const normalized = String(value).trim();
  if (!normalized) return null;
  if (typeof maxLength === 'number' && maxLength > 0) {
    return normalized.slice(0, maxLength);
  }
  return normalized;
};

const normalizeCommaSeparatedInterests = (value) => {
  const normalized = normalizeOptionalText(value, MAX_INTERESTS_LENGTH * 2);
  if (!normalized) return null;

  const normalizedDelimiters = normalized
    .replace(/[\r\n;|]+/g, ',')
    .replace(/\s+/g, ' ');

  const items = normalizedDelimiters
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

  if (items.length === 0) return null;
  return items.join(', ').slice(0, MAX_INTERESTS_LENGTH);
};

const normalizeLocaleValue = (value) => {
  const normalized = normalizeOptionalText(value, 64);
  if (!normalized) return null;
  const primary = normalized.split(',')[0]?.trim();
  return primary ? primary.slice(0, 32) : null;
};

const extractUtmContext = (referer) => {
  const normalizedReferer = normalizeOptionalText(referer, 2048);
  if (!normalizedReferer) return {};

  try {
    const parsed = new URL(normalizedReferer);
    return {
      utm_source: normalizeOptionalText(parsed.searchParams.get('utm_source'), 255),
      utm_medium: normalizeOptionalText(parsed.searchParams.get('utm_medium'), 255),
      utm_campaign: normalizeOptionalText(parsed.searchParams.get('utm_campaign'), 255),
      utm_term: normalizeOptionalText(parsed.searchParams.get('utm_term'), 255),
      utm_content: normalizeOptionalText(parsed.searchParams.get('utm_content'), 255),
      referer_host: normalizeOptionalText(parsed.host, 255),
      referer_path: normalizeOptionalText(parsed.pathname, 255),
    };
  } catch {
    return {};
  }
};

const compactObject = (value) => {
  if (!value || typeof value !== 'object') return null;
  const compacted = Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined && item !== null && item !== '')
  );
  return Object.keys(compacted).length > 0 ? compacted : null;
};

const persistRegistrationFollowUp = async ({
  user,
  normalizedEmail,
  phone,
  admin_name,
  facility_name,
  facility_type,
  location,
  interests,
  request_context,
  facility_details_differ,
  account_already_active,
  existing_email,
  registration_attempt_increment = 1,
}) => {
  if (!user?.id || !normalizedEmail) return;

  const utmContext = extractUtmContext(request_context?.referer);
  const followUpMetadata = compactObject({
    existing_email: existing_email ? true : undefined,
    account_already_active: account_already_active ? true : undefined,
    facility_details_differ: facility_details_differ ? true : undefined,
    registration_channel: normalizeOptionalText(request_context?.origin, 255),
    device_hints: compactObject({
      sec_ch_ua: normalizeOptionalText(request_context?.sec_ch_ua, 255),
      sec_ch_ua_mobile: normalizeOptionalText(request_context?.sec_ch_ua_mobile, 32),
    }),
    utm: compactObject({
      source: utmContext.utm_source,
      medium: utmContext.utm_medium,
      campaign: utmContext.utm_campaign,
      term: utmContext.utm_term,
      content: utmContext.utm_content,
    }),
  });

  try {
    await authRepository.upsertRegistrationFollowUp({
      user_id: user.id,
      tenant_id: user.tenant_id || null,
      facility_id: user.facility_id || null,
      email: normalizedEmail,
      phone: normalizeOptionalText(phone || user.phone, 40),
      admin_name: normalizeOptionalText(
        admin_name || resolveAdminDisplayName(user, admin_name),
        255
      ),
      facility_name: normalizeOptionalText(
        facility_name || user?.facility?.name || user?.tenant?.name,
        255
      ),
      facility_type: normalizeComparableEnum(
        facility_type || user?.facility?.facility_type || ''
      ) || null,
      location: normalizeOptionalText(location, MAX_LOCATION_LENGTH),
      interests: normalizeCommaSeparatedInterests(interests),
      account_status: user.status || 'PENDING',
      locale: normalizeLocaleValue(request_context?.locale),
      timezone: normalizeOptionalText(request_context?.timezone, 64),
      ip_address: normalizeOptionalText(request_context?.ip_address, 45),
      user_agent: normalizeOptionalText(request_context?.user_agent, 255),
      device_platform: normalizeOptionalText(request_context?.platform, 64),
      referral_source: normalizeOptionalText(
        request_context?.referer || request_context?.origin || utmContext.referer_host,
        255
      ),
      campaign: normalizeOptionalText(utmContext.utm_campaign, 255),
      follow_up_metadata: followUpMetadata,
      registration_attempt_increment,
    });
  } catch {
    // Tracking is best-effort and must not block registration.
  }
};

const hasFacilityDetailsDifference = (user, facility_name, facility_type) => {
  const incomingName = normalizeComparableText(facility_name);
  const incomingType = normalizeComparableEnum(facility_type);

  const existingName = normalizeComparableText(
    user?.facility?.name || user?.tenant?.name || ''
  );
  const existingType = normalizeComparableEnum(user?.facility?.facility_type || '');

  const nameDiffers = Boolean(incomingName && existingName && incomingName !== existingName);
  const typeDiffers = Boolean(incomingType && existingType && incomingType !== existingType);

  return nameDiffers || typeDiffers;
};

const buildRegisterResponse = (
  user,
  normalizedEmail,
  verification = {},
  flow = 'NEW_REGISTRATION',
  nextPath = '/login'
) => {
  const { password_hash: _, ...userData } = user;
  return {
    user: userData,
    flow,
    next_path: nextPath,
    verification: {
      email: normalizedEmail,
      expires_in_minutes: EMAIL_VERIFICATION_EXPIRY_MINUTES,
      ...verification,
    },
  };
};

const handleExistingEmailRegistration = async ({
  user,
  normalizedEmail,
  admin_name,
  facility_name,
  facility_type,
  location,
  interests,
  accountAlreadyActive,
  ip_address,
  user_agent,
  request_context,
}) => {
  const nextPath = '/login';
  const facilityDetailsDiffer = hasFacilityDetailsDifference(
    user,
    facility_name,
    facility_type
  );
  const verification = await createEmailVerificationTokens(user.id);
  await deliverAuthEmail(
    sendVerificationEmail({
      email: normalizedEmail,
      adminName: resolveAdminDisplayName(user, admin_name),
      facilityName: user.facility?.name || user.tenant?.name || facility_name,
      code: verification.code,
      plainPassword: null,
      expiresAt: verification.expiresAt,
      locale: request_context?.locale,
      timeZone: request_context?.timezone,
    }),
    'register_existing_email',
    { code: verification.code }
  );

  await persistRegistrationFollowUp({
    user,
    normalizedEmail,
    phone: user.phone,
    admin_name,
    facility_name: user.facility?.name || user.tenant?.name || facility_name,
    facility_type: user.facility?.facility_type || facility_type || 'OTHER',
    location,
    interests,
    request_context: {
      ...request_context,
      ip_address,
      user_agent,
    },
    facility_details_differ: facilityDetailsDiffer,
    account_already_active: Boolean(accountAlreadyActive),
    existing_email: true,
    registration_attempt_increment: 1,
  });

  await createAuditLog({
    action: 'USER_REGISTERED_EXISTING_EMAIL',
    entity: 'user',
    entity_id: user.id,
    user_id: user.id,
    tenant_id: user.tenant_id,
    facility_id: user.facility_id,
    ip_address,
    user_agent,
    details: {
      email: normalizedEmail,
      verification_expires_in_minutes: EMAIL_VERIFICATION_EXPIRY_MINUTES,
      email_already_used: true,
      account_already_active: Boolean(accountAlreadyActive),
      verification_resent: true,
      facility_details_differ: facilityDetailsDiffer,
    },
  });

  return buildRegisterResponse(
    user,
    normalizedEmail,
    {
      email_already_used: true,
      account_already_active: Boolean(accountAlreadyActive),
      facility_details_differ: facilityDetailsDiffer,
    },
    accountAlreadyActive ? 'EXISTING_ACTIVE_ACCOUNT' : 'EXISTING_PENDING_ACCOUNT',
    nextPath
  );
};

/**
 * Identify users by identifier (email or phone)
 * Returns list of tenants the user belongs to (without password verification)
 *
 * @param {Object} data - Identify data
 * @param {string} data.identifier - User email or phone
 * @returns {Promise<Object>} List of users with tenant info
 */
const identify = async (data) => {
  const { identifier } = data;

  // Find all users with matching identifier
  const users = await authRepository.findUsersByIdentifier(identifier);
  // Soft-deleted orgs are not selectable; permanently deleted rows are already absent.
  const liveUsers = users.filter((user) => !isSoftDeletedRecord(user.tenant));

  if (liveUsers.length === 0) {
    // Don't reveal if user exists (security best practice)
    return {
      users: [],
      summary: {
        active_count: 0,
        pending_count: 0,
        suspended_count: 0,
        inactive_count: 0,
        has_active: false,
        has_pending: false,
      },
    };
  }

  const statusRank = {
    ACTIVE: 4,
    PENDING: 3,
    SUSPENDED: 2,
    INACTIVE: 1,
  };

  const tenantMap = new Map();
  for (const user of liveUsers) {
    const tenantId = user.tenant_id;
    if (!tenantId) continue;

    const nextEntry = {
      tenant_id: tenantId,
      tenant_name: user.tenant?.name || '',
      tenant_slug: user.tenant?.slug || null,
      status: user.status || 'INACTIVE',
    };

    const current = tenantMap.get(tenantId);
    if (!current || (statusRank[nextEntry.status] || 0) > (statusRank[current.status] || 0)) {
      tenantMap.set(tenantId, nextEntry);
    }
  }

  const uniqueTenants = Array.from(tenantMap.values());
  const active_count = liveUsers.filter((user) => user.status === 'ACTIVE').length;
  const pending_count = liveUsers.filter((user) => user.status === 'PENDING').length;
  const suspended_count = liveUsers.filter((user) => user.status === 'SUSPENDED').length;
  const inactive_count = liveUsers.filter((user) => user.status === 'INACTIVE').length;

  return {
    users: uniqueTenants,
    summary: {
      active_count,
      pending_count,
      suspended_count,
      inactive_count,
      has_active: active_count > 0,
      has_pending: pending_count > 0,
    },
  };
};

/**
 * Login user
 *
 * @param {Object} data - Login data
 * @param {string} [data.email] - User email
 * @param {string} [data.phone] - User phone number (digits only)
 * @param {string} data.password - User password
 * @param {string} [data.tenant_id] - Tenant ID (optional if single user found)
 * @param {string} [data.facility_id] - Facility ID (optional)
 * @param {string} [data.ip_address] - IP address
 * @param {string} [data.user_agent] - User agent
 * @returns {Promise<Object>} Access token, refresh token, user data, and facility info
 */
const login = async (data) => {
  const {
    email,
    phone,
    password,
    tenant_id,
    facility_id,
    ip_address,
    user_agent
  } = data;

  let user;

  if (tenant_id) {
    // Validate tenant_id format (basic UUID check)
    if (!/^[a-f0-9-]+$/i.test(tenant_id)) {
      // Log suspicious activity
      await createAuditLog({
        action: 'LOGIN_INVALID_TENANT',
        entity: 'user',
        entity_id: 'unknown',
        user_id: null,
        tenant_id: null,
        facility_id: null,
        ip_address,
        user_agent,
        details: { suspicious: true, tenant_id }
      });
      throw new HttpError('errors.auth.invalid_credentials', 401);
    }

    // Find user by email/phone and tenant
    user = email
      ? await authRepository.findUserByEmailAndTenant(email, tenant_id)
      : await authRepository.findUserByPhoneAndTenant(phone, tenant_id);
  } else {
    // If no tenant_id provided, find user by identifier only
    // This assumes single user (should be handled by identify endpoint first)
    const identifier = email || phone;
    const users = await authRepository.findUsersByIdentifier(identifier);

    if (users.length === 0) {
      throw new HttpError('errors.auth.user_not_found', 401);
    }

    const liveUsers = users.filter((candidate) => !isSoftDeletedRecord(candidate.tenant));
    const deactivatedUsers = users.filter((candidate) =>
      isSoftDeletedRecord(candidate.tenant)
    );

    if (liveUsers.length === 0 && deactivatedUsers.length > 0) {
      const deactivated = buildOrganizationDeactivatedError('tenant');
      throw new HttpError(deactivated.messageKey, 403, deactivated.details);
    }

    const activeUsers = liveUsers.filter((candidate) => candidate.status === 'ACTIVE');
    const pendingUsers = liveUsers.filter((candidate) => candidate.status === 'PENDING');
    const suspendedUsers = liveUsers.filter((candidate) => candidate.status === 'SUSPENDED');

    if (activeUsers.length > 1) {
      // Multiple active users found - tenant selection required
      throw new HttpError('errors.auth.multiple_tenants', 400);
    }

    if (activeUsers.length === 1) {
      user = await authRepository.findUserById(activeUsers[0].id);
    } else if (pendingUsers.length > 0) {
      const pending = await resolvePendingAccountError(pendingUsers[0]);
      throw new HttpError(pending.messageKey, 403, pending.details);
    } else if (suspendedUsers.length > 0) {
      throw new HttpError('errors.auth.account_suspended', 403);
    } else {
      throw new HttpError('errors.auth.account_inactive', 403);
    }
  }

  if (!user) {
    throw new HttpError('errors.auth.user_not_found', 401);
  }

  // Check if user is active
  await assertUserCanAuthenticate(user);
  assertTenantAllowsLogin(user);

  // Verify password
  const isPasswordValid = await comparePassword(password, user.password_hash);
  if (!isPasswordValid) {
    // Log failed login attempt
    await createAuditLog({
      action: 'LOGIN_FAILED_INVALID_PASSWORD',
      entity: 'user',
      entity_id: user.id,
      user_id: user.id,
      tenant_id: user.tenant_id,
      facility_id: null,
      ip_address,
      user_agent,
      details: { reason: 'invalid_password' }
    });
    throw new HttpError('errors.auth.wrong_password', 401);
  }

  // Get user's accessible facilities
  const facilities = await authRepository.getUserFacilities(user.id, user.tenant_id);
  const hasMultipleFacilities = facilities.length > 1;

  // Require explicit selection for multi-facility users unless facility_id is provided.
  let selectedFacilityId = facility_id || null;
  if (!selectedFacilityId && facilities.length === 1) {
    selectedFacilityId = facilities[0].id;
  } else if (!selectedFacilityId && facilities.length === 0 && user.facility_id) {
    assertFacilityAllowsLogin(user, {
      selectedFacilityId: null,
      accessibleFacilities: facilities,
    });
    // Fallback for legacy records where role-derived facilities are unavailable.
    selectedFacilityId = user.facility_id;
  }

  if (selectedFacilityId) {
    const hasAccess = facilities.some((entry) => entry.id === selectedFacilityId);
    if (!hasAccess) {
      assertFacilityAllowsLogin(user, {
        selectedFacilityId,
        accessibleFacilities: facilities,
      });
      const legacyFallbackAllowed =
        facilities.length === 0 &&
        user.facility_id === selectedFacilityId &&
        !isSoftDeletedRecord(user.facility);
      if (!legacyFallbackAllowed) {
        await createAuditLog({
          action: 'LOGIN_FAILED_FACILITY_ACCESS',
          entity: 'user',
          entity_id: user.id,
          user_id: user.id,
          tenant_id: user.tenant_id,
          facility_id: null,
          ip_address,
          user_agent,
          details: { reason: 'unauthorized_facility', requested_facility_id: selectedFacilityId }
        });
        throw new HttpError('errors.auth.unauthorized_facility', 403);
      }
    }
  }

  assertFacilityAllowsLogin(user, {
    selectedFacilityId,
    accessibleFacilities: facilities,
  });

  // If multiple facilities and none selected, return facility selection requirement
  if (hasMultipleFacilities && !selectedFacilityId) {
    return {
      requires_facility_selection: true,
      facilities: facilities.map(f => ({
        id: f.id,
        name: f.name,
        facility_type: f.facility_type
      })),
      tenant_id: user.tenant_id
    };
  }

  // Generate tokens — plan modules gate effective rights in the JWT.
  const roleNames = getRoleNames(user);
  const enrichedUser = await enrichAuthUserPayload({
    ...user,
    facility_id: selectedFacilityId || user.facility_id,
  });
  const accessToken = generateToken({
    userId: user.id,
    tenantId: user.tenant_id,
    facilityId: selectedFacilityId,
    email: user.email,
    roles: roleNames,
    permissions: enrichedUser.permissions,
  });

  const refreshToken = generateRefreshToken();
  const refreshTokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');

  // Create session
  const expiresAt = resolveSessionExpiryDate();

  const session = await authRepository.createSession({
    user_id: user.id,
    refresh_token_hash: refreshTokenHash,
    ip_address,
    user_agent,
    expires_at: expiresAt
  });

  // Create audit log
  await createAuditLog({
    action: 'USER_LOGIN',
    entity: 'user',
    entity_id: user.id,
    user_id: user.id,
    tenant_id: user.tenant_id,
    facility_id: selectedFacilityId,
    ip_address,
    user_agent,
    details: {
      session_id: session.id,
      session_expires_at: expiresAt.toISOString(),
    }
  });

  // Return response without sensitive data
  return {
    access_token: accessToken,
    refresh_token: refreshToken,
    user: enrichedUser,
    requires_facility_selection: false
  };
};

/**
 * Register facility owner (self-serve onboarding)
 *
 * @param {Object} data - Registration data
 * @param {string} data.email - User email
 * @param {string} data.password - User password
 * @param {string} data.facility_name - Facility/business name
 * @param {string} data.admin_name - Admin display name
 * @param {string} data.facility_type - Facility type enum
 * @param {string} [data.phone] - User phone
 * @param {string} [data.location] - User-provided location text
 * @param {string} [data.interests] - User-provided interests text
 * @param {string} [data.ip_address] - IP address
 * @param {string} [data.user_agent] - User agent
 * @param {Object} [data.request_context] - Request metadata (locale/timezone/platform/origin)
 * @returns {Promise<Object>} Created user data (tenant admin)
 */
const register = async (data) => {
  const {
    email,
    password,
    facility_name,
    tenant_name,
    admin_name,
    facility_type,
    phone,
    location,
    interests,
    ip_address,
    user_agent,
    request_context,
  } = data;

  const normalizedEmail = String(email || '').trim().toLowerCase();

  const existingUser = await authRepository.findUserByEmail(normalizedEmail);
  if (existingUser) {
    if (existingUser.status === 'PENDING') {
      return handleExistingEmailRegistration({
        user: existingUser,
        normalizedEmail,
        admin_name,
        facility_name,
        facility_type,
        accountAlreadyActive: false,
        ip_address,
        user_agent,
        location,
        interests,
        request_context,
      });
    }

    if (existingUser.status === 'ACTIVE') {
      return handleExistingEmailRegistration({
        user: existingUser,
        normalizedEmail,
        admin_name,
        facility_name,
        facility_type,
        accountAlreadyActive: true,
        ip_address,
        user_agent,
        location,
        interests,
        request_context,
      });
    }

    throw new HttpError(resolveAccountStatusErrorKey(existingUser.status), 403);
  }

  // Hash password
  const password_hash = await hashPassword(password);

  let user;
  try {
    // Bootstrap tenant/facility and create owner user with TENANT_ADMIN role in one transaction.
    user = await authRepository.registerFacilityOwner({
      email: normalizedEmail,
      phone,
      password_hash,
      facility_name,
      tenant_name: tenant_name || facility_name,
      admin_name,
      facility_type,
      status: 'PENDING',
    });
  } catch (error) {
    const isDuplicateEmail =
      error instanceof HttpError &&
      error.statusCode === 409 &&
      error.messageKey === 'errors.auth.user_exists';

    if (!isDuplicateEmail) {
      throw error;
    }

    const racedUser = await authRepository.findUserByEmail(normalizedEmail);
    if (racedUser?.status === 'PENDING' || racedUser?.status === 'ACTIVE') {
      return handleExistingEmailRegistration({
        user: racedUser,
        normalizedEmail,
        admin_name,
        facility_name,
        facility_type,
        accountAlreadyActive: racedUser.status === 'ACTIVE',
        ip_address,
        user_agent,
        location,
        interests,
        request_context,
      });
    }

    throw error;
  }
  if (!user) {
    throw new HttpError('errors.database.unexpected', 500);
  }

  // Create a verification code for the email verification form.
  const verification = await createEmailVerificationTokens(user.id);

  await deliverAuthEmail(
    sendVerificationEmail({
      email: normalizedEmail,
      adminName: admin_name,
      facilityName: facility_name,
      code: verification.code,
      plainPassword: password,
      expiresAt: verification.expiresAt,
      locale: request_context?.locale,
      timeZone: request_context?.timezone,
    }),
    'register_new_user',
    { code: verification.code }
  );

  await persistRegistrationFollowUp({
    user,
    normalizedEmail,
    phone,
    admin_name,
    facility_name,
    facility_type,
    location,
    interests,
    request_context: {
      ...request_context,
      ip_address,
      user_agent,
    },
    existing_email: false,
    registration_attempt_increment: 1,
  });

  // Create audit log
  await createAuditLog({
    action: 'USER_REGISTERED',
    entity: 'user',
    entity_id: user.id,
    user_id: user.id,
    tenant_id: user.tenant_id,
    facility_id: user.facility_id,
    ip_address,
    user_agent,
    details: {
      email: normalizedEmail,
      phone,
      facility_name,
      facility_type,
      admin_name,
      role: 'TENANT_ADMIN',
      self_serve: true,
      verification_expires_in_minutes: EMAIL_VERIFICATION_EXPIRY_MINUTES,
    }
  });

  return buildRegisterResponse(user, normalizedEmail, {}, 'NEW_REGISTRATION', '/login');
};

/**
 * Refresh access token
 *
 * @param {Object} data - Refresh data
 * @param {string} data.refresh_token - Refresh token
 * @param {string} [data.ip_address] - IP address
 * @param {string} [data.user_agent] - User agent
 * @returns {Promise<Object>} New access token and refresh token
 */
const refresh = async (data) => {
  const { refresh_token, ip_address, user_agent } = data;

  // Hash refresh token
  const refreshTokenHash = crypto.createHash('sha256').update(refresh_token).digest('hex');

  // Find session by refresh token with validation
  const session = await authRepository.findSessionByRefreshToken(refreshTokenHash);
  if (!session) {
    throw new HttpError('errors.auth.refresh_token_invalid', 401);
  }

  // Validate session is not expired
  if (session.expires_at && new Date() > new Date(session.expires_at)) {
    await authRepository.revokeSession(session.id);
    throw new HttpError('errors.auth.session_expired', 401);
  }

  // Validate session is not revoked
  if (session.revoked_at) {
    throw new HttpError('errors.auth.session_revoked', 401);
  }

  // Check if user is active
  await assertUserCanAuthenticate(session.user);
  assertTenantAllowsLogin(session.user);
  assertFacilityAllowsLogin(session.user, {
    selectedFacilityId: session.user.facility_id || null,
    accessibleFacilities: session.user.facility && !isSoftDeletedRecord(session.user.facility)
      ? [session.user.facility]
      : [],
  });

  // Revoke old session
  await authRepository.revokeSession(session.id);

  // Generate new tokens — plan modules gate effective rights in the JWT.
  const enrichedUser = await enrichAuthUserPayload(session.user);
  const accessToken = generateToken({
    userId: session.user.id,
    tenantId: session.user.tenant_id,
    facilityId: session.user.facility_id,
    email: session.user.email,
    roles: session.user.roles?.map(ur => ur.role.name) || [],
    permissions: enrichedUser.permissions,
  });

  const newRefreshToken = generateRefreshToken();
  const newRefreshTokenHash = crypto.createHash('sha256').update(newRefreshToken).digest('hex');

  // Create new session
  const expiresAt = resolveSessionExpiryDate();

  const newSession = await authRepository.createSession({
    user_id: session.user.id,
    refresh_token_hash: newRefreshTokenHash,
    ip_address,
    user_agent,
    expires_at: expiresAt
  });

  // Create audit log
  await createAuditLog({
    action: 'TOKEN_REFRESHED',
    entity: 'user_session',
    entity_id: newSession.id,
    user_id: session.user.id,
    tenant_id: session.user.tenant_id,
    facility_id: session.user.facility_id,
    ip_address,
    user_agent,
    details: {
      old_session_id: session.id,
      session_expires_at: expiresAt.toISOString(),
    }
  });

  return {
    access_token: accessToken,
    refresh_token: newRefreshToken,
    user: enrichedUser,
  };
};

/**
 * Logout user
 *
 * @param {Object} data - Logout data
 * @param {string} data.user_id - User ID
 * @param {string} [data.refresh_token] - Refresh token (optional, for single session logout)
 * @param {string} [data.ip_address] - IP address
 * @param {string} [data.user_agent] - User agent
 * @returns {Promise<Object>} Logout result
 */
const logout = async (data) => {
  const { user_id, refresh_token, ip_address, user_agent } = data;

  if (refresh_token) {
    // Logout single session
    const refreshTokenHash = crypto.createHash('sha256').update(refresh_token).digest('hex');
    const session = await authRepository.findSessionByRefreshToken(refreshTokenHash);
    
    if (session) {
      await authRepository.revokeSession(session.id);
      
      // Create audit log
      await createAuditLog({
        action: 'USER_LOGOUT',
        entity: 'user_session',
        entity_id: session.id,
        user_id,
        tenant_id: session.user.tenant_id,
        facility_id: session.user.facility_id,
        ip_address,
        user_agent,
        details: { type: 'single_session' }
      });
    }
  } else {
    // Logout all sessions
    await authRepository.revokeAllUserSessions(user_id);
    
    // Get user for audit log
    const user = await authRepository.findUserById(user_id);
    
    // Create audit log
    await createAuditLog({
      action: 'USER_LOGOUT_ALL',
      entity: 'user',
      entity_id: user_id,
      user_id,
      tenant_id: user?.tenant_id,
      facility_id: user?.facility_id,
      ip_address,
      user_agent,
      details: { type: 'all_sessions' }
    });
  }

  return { message: 'messages.auth.logout.success' };
};

/**
 * Change password (authenticated user)
 *
 * @param {Object} data - Change password data
 * @param {string} data.user_id - User ID
 * @param {string} data.old_password - Current password
 * @param {string} data.new_password - New password
 * @param {string} [data.ip_address] - IP address
 * @param {string} [data.user_agent] - User agent
 * @returns {Promise<Object>} Success message
 */
const changePassword = async (data) => {
  const { user_id, old_password, new_password, ip_address, user_agent } = data;

  // Get user
  const user = await authRepository.findUserById(user_id);
  if (!user) {
    throw new HttpError('errors.auth.user_not_found', 404);
  }

  // Verify old password
  const isPasswordValid = await comparePassword(old_password, user.password_hash);
  if (!isPasswordValid) {
    throw new HttpError('errors.auth.password_incorrect', 401);
  }

  // Hash new password
  const new_password_hash = await hashPassword(new_password);

  // Update password
  await authRepository.updateUserPassword(user_id, new_password_hash);

  // Revoke all sessions (force re-login)
  await authRepository.revokeAllUserSessions(user_id);

  // Create audit log
  await createAuditLog({
    action: 'PASSWORD_CHANGED',
    entity: 'user',
    entity_id: user_id,
    user_id,
    tenant_id: user.tenant_id,
    facility_id: user.facility_id,
    ip_address,
    user_agent,
    details: { sessions_revoked: true }
  });

  return { message: 'messages.auth.password_changed.success' };
};

/**
 * Get current user info
 *
 * @param {string} userId - User ID
 * @returns {Promise<Object>} User data
 */
const getMe = async (userId) => {
  const user = await authRepository.findUserById(userId);
  if (!user) {
    throw new HttpError('errors.auth.user_not_found', 404);
  }

  return enrichAuthUserPayload(user);
};

/**
 * Verify email with token
 *
 * @param {Object} data - Verification data
 * @param {string} data.token - Verification token
 * @param {string} [data.email] - User email (optional)
 * @param {Object} [data.request_context] - Request metadata (locale/origin)
 * @returns {Promise<Object>} Success message
 */
const verifyEmail = async (data) => {
  const { token, email, request_context } = data;
  const normalizedEmail = email ? String(email).trim().toLowerCase() : null;

  // Hash token
  const tokenHash = hashToken(token);

  // Find token
  const verificationToken = await authRepository.findVerificationToken(
    tokenHash,
    EMAIL_VERIFICATION_TOKEN_TYPE
  );

  if (!verificationToken) {
    throw new HttpError('errors.auth.token_invalid', 400);
  }

  // If email provided, verify it matches
  if (normalizedEmail && verificationToken.user.email !== normalizedEmail) {
    throw new HttpError('errors.auth.token_invalid', 400);
  }

  const alreadyActive = verificationToken.user.status === 'ACTIVE';
  const emailAlreadyVerified = isEmailVerified(verificationToken.user);
  const shouldSendAwaitingApprovalEmail = !alreadyActive && !emailAlreadyVerified;

  // Commit verification before consuming the token so a later failure can still
  // be recovered with the same code if markEmailVerified did not persist.
  if (shouldSendAwaitingApprovalEmail) {
    await authRepository.markEmailVerified(verificationToken.user_id);
  }

  // Ensure the approval queue row exists even when register-time tracking failed.
  await persistRegistrationFollowUp({
    user: {
      ...verificationToken.user,
      status: alreadyActive ? 'ACTIVE' : 'PENDING',
      email_verified_at:
        verificationToken.user.email_verified_at ||
        (shouldSendAwaitingApprovalEmail ? new Date() : null),
    },
    normalizedEmail: verificationToken.user.email,
    phone: verificationToken.user.phone,
    admin_name: resolveAdminDisplayName(verificationToken.user),
    facility_name:
      verificationToken.user.facility?.name ||
      verificationToken.user.tenant?.name ||
      null,
    facility_type: verificationToken.user.facility?.facility_type || null,
    registration_attempt_increment: 0,
  });

  await authRepository.markTokenAsUsed(verificationToken.id);
  // Invalidate any other active email verification token for this user.
  await authRepository.deleteExpiredTokens(
    verificationToken.user_id,
    EMAIL_VERIFICATION_TOKEN_TYPE
  );

  // Create audit log
  await createAuditLog({
    action: alreadyActive ? 'EMAIL_VERIFIED_ALREADY_ACTIVE' : 'EMAIL_VERIFIED',
    entity: 'user',
    entity_id: verificationToken.user_id,
    user_id: verificationToken.user_id,
    tenant_id: verificationToken.user.tenant_id,
    facility_id: verificationToken.user.facility_id,
    details: { email: verificationToken.user.email }
  });

  const contactsPayload = await resolvePlatformAdminContactsForAuth();

  // Verification is already committed; never block the HTTP response on SMTP.
  if (shouldSendAwaitingApprovalEmail && verificationToken.user.email) {
    void sendAwaitingApprovalEmail({
      email: verificationToken.user.email,
      locale: request_context?.locale,
      platformAdminContact: contactsPayload.platform_admin_contact,
    })
      .then((deliveryResult) => {
        if (!deliveryResult?.sent) {
          logger.warn('Awaiting-approval email was not delivered.', {
            context: 'verify_email_awaiting_approval',
            email: verificationToken.user.email,
            provider: deliveryResult?.provider || null,
          });
        }
      })
      .catch((error) => {
        logger.warn('Awaiting-approval email send failed.', {
          context: 'verify_email_awaiting_approval',
          email: verificationToken.user.email,
          error: error?.message || String(error),
        });
      });
  }

  if (alreadyActive) {
    return {
      message: 'messages.auth.email_verified.success',
      already_active: true,
      awaiting_platform_approval: false,
      next_path: '/login',
    };
  }

  return {
    message: 'messages.auth.email_verified.awaiting_approval',
    already_active: false,
    awaiting_platform_approval: true,
    next_path: '/login',
    ...contactsPayload,
  };
};

/**
 * Verify phone with token
 *
 * @param {Object} data - Verification data
 * @param {string} data.token - Verification token
 * @param {string} data.phone - User phone
 * @returns {Promise<Object>} Success message
 */
const verifyPhone = async (data) => {
  const { token, phone } = data;

  // Hash token
  const tokenHash = hashToken(token);

  // Find token
  const verificationToken = await authRepository.findVerificationToken(
    tokenHash,
    PHONE_VERIFICATION_TOKEN_TYPE
  );

  if (!verificationToken) {
    throw new HttpError('errors.auth.token_invalid', 400);
  }

  // Verify phone matches
  if (verificationToken.user.phone !== phone) {
    throw new HttpError('errors.auth.token_invalid', 400);
  }

  // Mark token as used
  await authRepository.markTokenAsUsed(verificationToken.id);

  // Create audit log
  await createAuditLog({
    action: 'PHONE_VERIFIED',
    entity: 'user',
    entity_id: verificationToken.user_id,
    user_id: verificationToken.user_id,
    tenant_id: verificationToken.user.tenant_id,
    facility_id: verificationToken.user.facility_id,
    details: { phone: verificationToken.user.phone }
  });

  return {
    message: 'messages.auth.phone_verified.success',
    next_path: '/login',
  };
};

/**
 * Resend verification email or SMS
 *
 * @param {Object} data - Resend data
 * @param {string} [data.email] - User email
 * @param {string} [data.phone] - User phone
 * @param {string} data.type - Verification type (email or phone)
 * @returns {Promise<Object>} Success message
 */
const resendVerification = async (data) => {
  const { email, phone, type, request_context } = data;

  let user;
  let tokenType;
  let identifier;
  let normalizedEmail = null;
  let normalizedPhone = null;

  if (type === 'email') {
    if (!email) {
      throw new HttpError('errors.validation.email.required', 400);
    }
    normalizedEmail = String(email).trim().toLowerCase();
    user = await authRepository.findUserByEmail(normalizedEmail);
    tokenType = EMAIL_VERIFICATION_TOKEN_TYPE;
    identifier = normalizedEmail;
  } else if (type === 'phone') {
    if (!phone) {
      throw new HttpError('errors.validation.phone.required', 400);
    }
    normalizedPhone = String(phone).replace(/[^\d]/g, '');
    user = await authRepository.findUserByPhone(normalizedPhone);
    tokenType = PHONE_VERIFICATION_TOKEN_TYPE;
    identifier = normalizedPhone;
  }

  if (!user) {
    throw new HttpError('errors.auth.user_not_found', 404);
  }

  // Allow email verification resend even for ACTIVE users so duplicate-registration
  // flows can proceed with the same "check email and continue" path.
  if (user.status === 'ACTIVE' && type !== 'email') {
    throw new HttpError('errors.auth.already_verified', 400);
  }

  if (type === 'email') {
    const tokens = await createEmailVerificationTokens(user.id);
    await deliverAuthEmail(
      sendVerificationEmail({
        email: normalizedEmail || user.email,
        adminName:
          user.profile?.first_name ||
          user.profile?.last_name ||
          user.email ||
          'Admin',
        facilityName: user.facility?.name || user.tenant?.name || 'your facility',
        code: tokens.code,
        plainPassword: null,
        expiresAt: tokens.expiresAt,
        locale: request_context?.locale,
        timeZone: request_context?.timezone,
      }),
      'resend_verification',
      { code: tokens.code }
    );
  } else {
    await authRepository.deleteExpiredTokens(user.id, tokenType);
    const token = crypto.randomInt(0, 1000000).toString().padStart(6, '0');
    const expiresAt = new Date(Date.now() + EMAIL_VERIFICATION_EXPIRY_MINUTES * 60 * 1000);

    await authRepository.createVerificationToken({
      user_id: user.id,
      token_hash: hashToken(token),
      type: tokenType,
      expires_at: expiresAt,
    });
  }

  // Create audit log
  await createAuditLog({
    action: 'VERIFICATION_RESENT',
    entity: 'user',
    entity_id: user.id,
    user_id: user.id,
    tenant_id: user.tenant_id,
    facility_id: user.facility_id,
    details: { type, identifier }
  });

  return { message: 'messages.auth.verification_sent.success' };
};

/**
 * Send forgot password email
 *
 * @param {Object} data - Forgot password data
 * @param {string} data.email - User email
 * @param {string} data.tenant_id - Tenant ID
 * @returns {Promise<Object>} Success message
 */
const forgotPassword = async (data) => {
  const { email, tenant_id, request_context } = data;

  // Find user
  const user = await authRepository.findUserByEmailAndTenant(email, tenant_id);

  if (!user) {
    throw new HttpError('errors.auth.user_not_found', 401);
  }

  // Delete old password reset tokens
  await authRepository.deleteExpiredTokens(user.id, PASSWORD_RESET_TOKEN_TYPE);

  const { linkToken, code, expiresAt } = await createPasswordResetTokens(user.id);

  const deliveryResult = await sendPasswordResetEmail({
    email: user.email,
    resetToken: linkToken,
    resetCode: code,
    expiresAt,
    locale: request_context?.locale,
    timeZone: request_context?.timezone,
  });

  // Keep response generic to avoid account enumeration side effects,
  // but still emit a warning for operational visibility.
  if (!deliveryResult?.sent) {
    logger.warn('Password reset email was not delivered', {
      provider: deliveryResult?.provider || 'unknown',
      tenant_id: user.tenant_id,
      user_id: user.id,
    });
  }

  // Create audit log
  await createAuditLog({
    action: 'PASSWORD_RESET_REQUESTED',
    entity: 'user',
    entity_id: user.id,
    user_id: user.id,
    tenant_id: user.tenant_id,
    facility_id: user.facility_id,
    details: { email }
  });

  return { message: 'messages.auth.password_reset.email_sent' };
};

/**
 * Reset password with token
 *
 * @param {Object} data - Reset password data
 * @param {string} data.token - Reset token
 * @param {string} data.new_password - New password
 * @returns {Promise<Object>} Success message
 */
const resetPassword = async (data) => {
  const { token, code, email, new_password } = data;
  const credential = String(token || code || '').trim();

  if (!credential) {
    throw new HttpError('errors.auth.token_invalid', 400);
  }

  // Hash token or code
  const tokenHash = hashToken(credential);

  // Find token
  const resetToken = await authRepository.findVerificationToken(
    tokenHash,
    PASSWORD_RESET_TOKEN_TYPE
  );

  if (!resetToken) {
    throw new HttpError('errors.auth.token_invalid', 400);
  }

  if (code && email) {
    const normalizedEmail = String(email).trim().toLowerCase();
    if (resetToken.user.email !== normalizedEmail) {
      throw new HttpError('errors.auth.token_invalid', 400);
    }
  }

  // Hash new password
  const new_password_hash = await hashPassword(new_password);

  // Update password
  await authRepository.updateUserPassword(resetToken.user_id, new_password_hash);

  // Invalidate all password reset tokens for this user
  await authRepository.deleteExpiredTokens(resetToken.user_id, PASSWORD_RESET_TOKEN_TYPE);

  // Revoke all sessions (force re-login)
  await authRepository.revokeAllUserSessions(resetToken.user_id);

  // Create audit log
  await createAuditLog({
    action: 'PASSWORD_RESET',
    entity: 'user',
    entity_id: resetToken.user_id,
    user_id: resetToken.user_id,
    tenant_id: resetToken.user.tenant_id,
    facility_id: resetToken.user.facility_id,
    details: { sessions_revoked: true, used_code: Boolean(code) }
  });

  return { message: 'messages.auth.password_reset.success' };
};

module.exports = {
  identify,
  login,
  register,
  verifyEmail,
  verifyPhone,
  resendVerification,
  forgotPassword,
  resetPassword,
  changePassword,
  refresh,
  logout,
  getMe,
  sendAccountApprovedEmail,
};
