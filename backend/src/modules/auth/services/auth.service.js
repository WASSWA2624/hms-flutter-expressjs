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

const APP_DISPLAY_NAME =
  String(env.APP_DISPLAY_NAME || 'Hospital Management System').trim() ||
  'Hospital Management System';
const EMAIL_LOGO_CID = 'hms-app-logo';
const EMAIL_LOGO_PATHS = [
  path.resolve(__dirname, '../../../../../hms-frontend/public/logo.png'),
  path.resolve(__dirname, '../../../../../hms-frontend/assets/logo.png'),
  path.resolve(__dirname, '../../../../public/logo.png'),
];

const toNormalizedString = (value) => String(value || '').trim();

const uniqueValues = (values = []) => Array.from(new Set(values.filter(Boolean)));

const resolveDirectPermissionNames = (user = {}) => uniqueValues(
  (Array.isArray(user.permissions) ? user.permissions : [])
    .flatMap((entry) => {
      if (!entry) return [];
      if (typeof entry === 'string') return [toNormalizedString(entry)];
      const permission = entry.permission && typeof entry.permission === 'object'
        ? entry.permission
        : entry;
      return [
        toNormalizedString(permission.name),
        toNormalizedString(permission.code),
        toNormalizedString(entry.permission_name),
      ];
    })
    .filter(Boolean)
);

const resolveRolePermissionNames = (user = {}) => uniqueValues(
  (Array.isArray(user.roles) ? user.roles : [])
    .flatMap((roleEntry) => {
      const permissions = Array.isArray(roleEntry?.role?.permissions)
        ? roleEntry.role.permissions
        : Array.isArray(roleEntry?.permissions)
          ? roleEntry.permissions
          : [];

      return permissions.flatMap((permissionEntry) => {
        if (!permissionEntry) return [];
        if (typeof permissionEntry === 'string') return [toNormalizedString(permissionEntry)];
        const permission = permissionEntry.permission && typeof permissionEntry.permission === 'object'
          ? permissionEntry.permission
          : permissionEntry;
        return [
          toNormalizedString(permission.name),
          toNormalizedString(permission.code),
          toNormalizedString(permissionEntry.permission_name),
        ];
      });
    })
    .filter(Boolean)
);

const buildAuthUserPayload = (user = {}) => {
  const { password_hash, permissions, ...userData } = user;
  const directPermissions = resolveDirectPermissionNames(user);
  const rolePermissions = resolveRolePermissionNames(user);

  return {
    ...userData,
    permissions: directPermissions,
    permission_names: directPermissions,
    role_permissions: rolePermissions,
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
    .flatMap((entry) => [
      toNormalizedString(entry?.role?.name),
      toNormalizedString(entry?.name),
      toNormalizedString(entry?.role_name),
    ])
    .filter(Boolean)
);

const formatExpiryCountdown = (expiresAt) => {
  const remainingSeconds = Math.max(
    0,
    Math.ceil((expiresAt.getTime() - Date.now()) / 1000)
  );
  const minutes = Math.floor(remainingSeconds / 60);
  const seconds = remainingSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, '0')}`;
};

const formatExpiryDateTime = (expiresAt, locale) => {
  try {
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
};

const buildVerificationEmailMessage = ({
  email,
  adminName,
  facilityName,
  code,
  plainPassword,
  expiresAt,
  locale,
}) => {
  const resolvedLocale = resolveLocale(locale);
  const resolvedExpiresAt =
    resolveExpiryDate(expiresAt) ||
    new Date(Date.now() + EMAIL_VERIFICATION_EXPIRY_MINUTES * 60 * 1000);
  const expiryCountdown = formatExpiryCountdown(resolvedExpiresAt);
  const expiryAtFormatted = formatExpiryDateTime(resolvedExpiresAt, resolvedLocale);
  const safeAdminName = String(adminName || 'there').trim() || 'there';
  const safeFacilityName = String(facilityName || 'your facility').trim() || 'your facility';
  const passwordLine = plainPassword
    ? `${translate('messages.auth.email_verification.password_notice', resolvedLocale)} ${plainPassword}\n`
    : '';
  const subject = translate('messages.auth.email_verification.subject', resolvedLocale, {
    app_name: APP_DISPLAY_NAME,
  });
  const preheader = translate('messages.auth.email_verification.preheader', resolvedLocale, {
    app_name: APP_DISPLAY_NAME,
  });
  const greeting = translate('messages.auth.email_verification.greeting', resolvedLocale, {
    name: safeAdminName,
  });
  const intro = translate('messages.auth.email_verification.intro', resolvedLocale, {
    facility: safeFacilityName,
    app_name: APP_DISPLAY_NAME,
  });
  const codeLabel = translate('messages.auth.email_verification.code_label', resolvedLocale);
  const expiryLine = translate('messages.auth.email_verification.code_expiry', resolvedLocale, {
    countdown: expiryCountdown,
    minutes: EMAIL_VERIFICATION_EXPIRY_MINUTES,
  });
  const expiryAtLine = translate('messages.auth.email_verification.code_expiry_at', resolvedLocale, {
    expires_at: expiryAtFormatted,
  });
  const ignoreLine = translate('messages.auth.email_verification.ignore', resolvedLocale);
  const noReplyLine = translate('messages.auth.email_verification.no_reply', resolvedLocale);
  const signature = translate('messages.auth.email_verification.signature', resolvedLocale, {
    app_name: APP_DISPLAY_NAME,
  });
  const logoAlt = translate('messages.auth.email_verification.logo_alt', resolvedLocale, {
    app_name: APP_DISPLAY_NAME,
  });
  const { logoSrc, attachments } = resolveEmailLogoAsset();

  const text =
    `${subject}\n\n` +
    `${greeting} ${intro}\n\n` +
    `${codeLabel}: ${code}\n` +
    `${expiryLine}\n` +
    `${expiryAtLine}\n\n` +
    `${ignoreLine}\n` +
    `${noReplyLine}\n\n` +
    passwordLine +
    `${signature}`;

  const safeGreeting = escapeHtml(greeting);
  const safeIntro = escapeHtml(intro);
  const safeRegistrationMessage = `${safeGreeting} ${safeIntro}`;
  const safeCodeLabel = escapeHtml(codeLabel);
  const safeExpiryLine = escapeHtml(expiryLine);
  const safeExpiryAtLine = escapeHtml(expiryAtLine);
  const safeIgnoreLine = escapeHtml(ignoreLine);
  const safeNoReplyLine = escapeHtml(noReplyLine);
  const safeSignature = escapeHtml(signature);
  const safeSignatureHtml = safeSignature.replace(/\n/g, '<br />');
  const safeLogoAlt = escapeHtml(logoAlt);
  const safeLogoSrc = logoSrc ? escapeHtml(logoSrc) : '';
  const logoHeaderCell = logoSrc
    ? `<td style="padding:0 16px 0 0;vertical-align:middle;width:64px;">
        <img src="${safeLogoSrc}" alt="${safeLogoAlt}" width="52" height="52" style="display:block;width:52px;height:52px;border:0;outline:none;text-decoration:none;background:#ffffff;border-radius:12px;padding:4px;" />
      </td>`
    : '';
  const safeCode = escapeHtml(code);
  const htmlPasswordLine = plainPassword
    ? `<p style="margin:0 0 20px;font-size:13px;line-height:20px;color:#b45309;background:#fff8eb;border:1px solid #fcd34d;border-radius:10px;padding:12px 14px;"><strong>${escapeHtml(translate('messages.auth.email_verification.password_notice', resolvedLocale))}</strong> <code style="font-family:Consolas,Monaco,'Courier New',monospace;">${escapeHtml(plainPassword)}</code></p>`
    : '';

  const html = `<!doctype html>
<html lang="${escapeHtml(resolvedLocale)}">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:0;background:#f2f5fb;">
  <div style="display:none!important;opacity:0;color:transparent;height:0;width:0;overflow:hidden;visibility:hidden;mso-hide:all;">
    ${escapeHtml(preheader)}
  </div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#f2f5fb;padding:28px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:620px;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #dbe4f3;">
          <tr>
            <td style="padding:26px 28px;background:linear-gradient(120deg,#0a66c2,#0b88e6);">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  ${logoHeaderCell}
                  <td style="vertical-align:middle;">
                    <h1 style="margin:0;color:#ffffff;font-size:24px;line-height:1.3;font-weight:700;font-family:'Segoe UI',Tahoma,Arial,sans-serif;">${escapeHtml(APP_DISPLAY_NAME)}</h1>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:28px;font-family:'Segoe UI',Tahoma,Arial,sans-serif;color:#0f172a;">
              <p style="margin:0 0 18px;font-size:15px;line-height:24px;color:#1e293b;">${safeRegistrationMessage}</p>
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 20px;background:#eff6ff;border:1px solid #bfdbfe;border-radius:12px;">
                <tr>
                  <td style="padding:14px 16px 6px;font-size:13px;line-height:18px;color:#1d4ed8;font-weight:600;text-transform:uppercase;letter-spacing:0.05em;">
                    ${safeCodeLabel}
                  </td>
                </tr>
                <tr>
                  <td style="padding:0 16px 8px;font-family:Consolas,Monaco,'Courier New',monospace;font-size:32px;line-height:38px;font-weight:700;color:#0f172a;letter-spacing:0.08em;">
                    ${safeCode}
                  </td>
                </tr>
                <tr>
                  <td style="padding:0 16px 4px;font-size:13px;line-height:20px;color:#334155;">
                    ${safeExpiryLine}
                  </td>
                </tr>
                <tr>
                  <td style="padding:0 16px 14px;font-size:12px;line-height:18px;color:#475569;">
                    ${safeExpiryAtLine}
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 8px;font-size:13px;line-height:20px;color:#475569;">${safeIgnoreLine}</p>
              <p style="margin:0 0 20px;font-size:13px;line-height:20px;color:#64748b;">${safeNoReplyLine}</p>
              ${htmlPasswordLine}
              <p style="margin:0;font-size:14px;line-height:22px;color:#0f172a;">${safeSignatureHtml}</p>
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
  adminName,
  facilityName,
  code,
  plainPassword,
  expiresAt,
  locale,
}) => {
  const includePassword = Boolean(env.ALLOW_PLAINTEXT_PASSWORD_EMAIL);
  const payload = buildVerificationEmailMessage({
    email,
    adminName,
    facilityName,
    code,
    plainPassword: includePassword ? plainPassword : null,
    expiresAt,
    locale,
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
  expiresAt,
  locale,
}) => {
  const resolvedLocale = resolveLocale(locale);
  const link = buildResetPasswordLink(resetToken, email);
  const expiryDate =
    resolveExpiryDate(expiresAt) ||
    new Date(Date.now() + PASSWORD_RESET_EXPIRY_HOURS * 60 * 60 * 1000);
  const expiresAtLabel = formatExpiryDateTime(expiryDate, resolvedLocale);
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
  const text = [
    subject,
    '',
    intro,
    '',
    `${actionLabel}: ${link}`,
    '',
    `${fallbackLabel}: ${link}`,
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

const ensureEmailDelivered = (deliveryResult, context) => {
  if (deliveryResult?.sent) {
    return;
  }

  throw new HttpError('errors.auth.email_delivery_unavailable', 503, [
    {
      context: context || 'verification_email',
      provider: deliveryResult?.provider || 'unknown',
    },
  ]);
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
  const deliveryResult = await sendVerificationEmail({
    email: normalizedEmail,
    adminName: resolveAdminDisplayName(user, admin_name),
    facilityName: user.facility?.name || user.tenant?.name || facility_name,
    code: verification.code,
    plainPassword: null,
    expiresAt: verification.expiresAt,
    locale: request_context?.locale,
  });
  ensureEmailDelivered(deliveryResult, 'register_existing_email');

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

  if (users.length === 0) {
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
  for (const user of users) {
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
  const active_count = users.filter((user) => user.status === 'ACTIVE').length;
  const pending_count = users.filter((user) => user.status === 'PENDING').length;
  const suspended_count = users.filter((user) => user.status === 'SUSPENDED').length;
  const inactive_count = users.filter((user) => user.status === 'INACTIVE').length;

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
      throw new HttpError('errors.auth.invalid_credentials', 401);
    }

    const activeUsers = users.filter((candidate) => candidate.status === 'ACTIVE');
    const pendingUsers = users.filter((candidate) => candidate.status === 'PENDING');
    const suspendedUsers = users.filter((candidate) => candidate.status === 'SUSPENDED');

    if (activeUsers.length > 1) {
      // Multiple active users found - tenant selection required
      throw new HttpError('errors.auth.multiple_tenants', 400);
    }

    if (activeUsers.length === 1) {
      user = await authRepository.findUserById(activeUsers[0].id);
    } else if (pendingUsers.length > 0) {
      throw new HttpError('errors.auth.account_pending', 403, [{
        reason: 'email_verification_required',
        identifier_type: email ? 'email' : 'phone',
      }]);
    } else if (suspendedUsers.length > 0) {
      throw new HttpError('errors.auth.account_suspended', 403);
    } else {
      throw new HttpError('errors.auth.account_inactive', 403);
    }
  }

  if (!user) {
    throw new HttpError('errors.auth.invalid_credentials', 401);
  }

  // Check if user is active
  if (user.status !== 'ACTIVE') {
    const errorKey = resolveAccountStatusErrorKey(user.status);
    const details = user.status === 'PENDING'
      ? [{
          reason: 'email_verification_required',
          identifier_type: email ? 'email' : 'phone',
          email: user.email || email || null,
        }]
      : [];
    throw new HttpError(errorKey, 403, details);
  }

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
    throw new HttpError('errors.auth.invalid_credentials', 401);
  }

  // Get user's accessible facilities
  const facilities = await authRepository.getUserFacilities(user.id, user.tenant_id);
  const hasMultipleFacilities = facilities.length > 1;

  // Require explicit selection for multi-facility users unless facility_id is provided.
  let selectedFacilityId = facility_id || null;
  if (selectedFacilityId && facilities.length > 0) {
    const hasAccess = facilities.some(f => f.id === selectedFacilityId);
    if (!hasAccess) {
      // Log unauthorized facility access attempt
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
  } else if (!selectedFacilityId && facilities.length === 1) {
    // Auto-select if only one facility
    selectedFacilityId = facilities[0].id;
  } else if (!selectedFacilityId && facilities.length === 0 && user.facility_id) {
    // Fallback for legacy records where role-derived facilities are unavailable.
    selectedFacilityId = user.facility_id;
  }

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

  // Generate tokens
  const roleNames = getRoleNames(user);
  const accessToken = generateToken({
    userId: user.id,
    tenantId: user.tenant_id,
    facilityId: selectedFacilityId,
    email: user.email,
    roles: roleNames,
    permissions: resolveDirectPermissionNames(user),
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
    user: buildAuthUserPayload(user),
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

  // Create verification code + link tokens (same 15 minute expiry window).
  const verification = await createEmailVerificationTokens(user.id);

  const deliveryResult = await sendVerificationEmail({
    email: normalizedEmail,
    adminName: admin_name,
    facilityName: facility_name,
    code: verification.code,
    plainPassword: password,
    expiresAt: verification.expiresAt,
    locale: request_context?.locale,
  });
  ensureEmailDelivered(deliveryResult, 'register_new_user');

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
  if (session.user.status !== 'ACTIVE') {
    throw new HttpError(resolveAccountStatusErrorKey(session.user.status), 403);
  }

  // Revoke old session
  await authRepository.revokeSession(session.id);

  // Generate new tokens
  const accessToken = generateToken({
    userId: session.user.id,
    tenantId: session.user.tenant_id,
    facilityId: session.user.facility_id,
    email: session.user.email,
    roles: session.user.roles?.map(ur => ur.role.name) || [],
    permissions: resolveDirectPermissionNames(session.user),
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
    refresh_token: newRefreshToken
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

  return buildAuthUserPayload(user);
};

/**
 * Verify email with token
 *
 * @param {Object} data - Verification data
 * @param {string} data.token - Verification token
 * @param {string} [data.email] - User email (optional)
 * @returns {Promise<Object>} Success message
 */
const verifyEmail = async (data) => {
  const { token, email } = data;
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

  // Mark token as used
  await authRepository.markTokenAsUsed(verificationToken.id);
  // Invalidate any other active email verification token for this user.
  await authRepository.deleteExpiredTokens(
    verificationToken.user_id,
    EMAIL_VERIFICATION_TOKEN_TYPE
  );

  if (!alreadyActive) {
    // Update user status to ACTIVE for first-time verification.
    await authRepository.updateUserStatus(verificationToken.user_id, 'ACTIVE');
  }

  try {
    await authRepository.updateRegistrationFollowUpStatus(verificationToken.user_id, 'ACTIVE');
  } catch {
    // Tracking is best-effort and must not block email verification.
  }

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

  return {
    message: 'messages.auth.email_verified.success',
    already_active: alreadyActive,
    next_path: '/login',
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
    const deliveryResult = await sendVerificationEmail({
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
    });
    ensureEmailDelivered(deliveryResult, 'resend_verification');
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

  // Don't reveal if user exists or not (security best practice)
  if (!user) {
    return { message: 'messages.auth.password_reset.email_sent' };
  }

  // Delete old password reset tokens
  await authRepository.deleteExpiredTokens(user.id, PASSWORD_RESET_TOKEN_TYPE);

  // Generate reset token
  const token = crypto.randomBytes(32).toString('hex');
  const tokenHash = hashToken(token);

  // Create token
  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + PASSWORD_RESET_EXPIRY_HOURS);

  await authRepository.createVerificationToken({
    user_id: user.id,
    token_hash: tokenHash,
    type: PASSWORD_RESET_TOKEN_TYPE,
    expires_at: expiresAt
  });

  const deliveryResult = await sendPasswordResetEmail({
    email: user.email,
    resetToken: token,
    expiresAt,
    locale: request_context?.locale,
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
  const { token, new_password } = data;

  // Hash token
  const tokenHash = hashToken(token);

  // Find token
  const resetToken = await authRepository.findVerificationToken(
    tokenHash,
    PASSWORD_RESET_TOKEN_TYPE
  );

  if (!resetToken) {
    throw new HttpError('errors.auth.token_invalid', 400);
  }

  // Hash new password
  const new_password_hash = await hashPassword(new_password);

  // Update password
  await authRepository.updateUserPassword(resetToken.user_id, new_password_hash);

  // Mark token as used
  await authRepository.markTokenAsUsed(resetToken.id);

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
    details: { sessions_revoked: true }
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
  getMe
};
