/**
 * Email notification utility
 *
 * Uses SMTP when configured and nodemailer is available.
 * Falls back to no-op delivery (returns false) when unavailable.
 */

const env = require('@config/env');
const { logger } = require('@lib/logging');

let transporter = null;
let nodemailerRef = null;

const STORAGE = {
  UNKNOWN: 'unknown',
  SMTP: 'smtp',
  SKIPPED: 'skipped',
};

const DEFAULT_SENDER_NAME =
  String(env.APP_DISPLAY_NAME || 'Hospital Management System').trim() ||
  'Hospital Management System';

const maskEmail = (value) => {
  const raw = String(value || '').trim();
  if (!raw.includes('@')) return '***';
  const [local, domain] = raw.split('@');
  if (!local) return `***@${domain}`;
  const prefix = local.slice(0, 2);
  return `${prefix}***@${domain}`;
};

const extractEmailAddress = (value) => {
  const input = String(value || '').trim();
  if (!input) return null;

  const bracketMatch = input.match(/<([^>]+)>/);
  const candidate = bracketMatch ? bracketMatch[1].trim() : input.replace(/^"+|"+$/g, '');
  if (!candidate.includes('@')) return null;
  return candidate;
};

const resolveConfiguredNoReplyAddress = () => {
  const explicit = extractEmailAddress(env.SMTP_NO_REPLY_ADDRESS);
  return explicit || null;
};

const resolveDerivedNoReplyAddress = () => {
  const source =
    extractEmailAddress(env.SMTP_FROM) ||
    extractEmailAddress(env.SMTP_USER) ||
    null;
  if (!source) return null;

  const domain = source.split('@')[1];
  if (!domain) return null;
  return `no-reply@${domain}`;
};

const resolveFromHeader = () => {
  const senderName = String(env.SMTP_FROM_NAME || DEFAULT_SENDER_NAME).trim() || DEFAULT_SENDER_NAME;
  const noReplyAddress = resolveConfiguredNoReplyAddress() || resolveDerivedNoReplyAddress();
  if (noReplyAddress) {
    return `"${senderName.replace(/"/g, '')}" <${noReplyAddress}>`;
  }

  const smtpUserAddress = extractEmailAddress(env.SMTP_USER);
  if (smtpUserAddress) {
    return `"${senderName.replace(/"/g, '')}" <${smtpUserAddress}>`;
  }

  return null;
};

const resolveReplyToHeader = () => {
  const explicitReplyTo = extractEmailAddress(env.SMTP_REPLY_TO);
  if (explicitReplyTo) return explicitReplyTo;

  const noReplyAddress = resolveConfiguredNoReplyAddress() || resolveDerivedNoReplyAddress();
  return noReplyAddress || undefined;
};

const resolveEnvelopeFrom = () =>
  resolveConfiguredNoReplyAddress() ||
  resolveDerivedNoReplyAddress() ||
  extractEmailAddress(env.SMTP_USER) ||
  undefined;

const normalizeRecipients = (value) => {
  const candidates = Array.isArray(value) ? value : [value];
  return candidates.map((item) => String(item || '').trim()).filter(Boolean);
};

const canUseSmtp = () =>
  Boolean(
    env.SMTP_HOST &&
      env.SMTP_PORT &&
      env.SMTP_USER &&
      env.SMTP_PASS &&
      (env.SMTP_FROM || env.SMTP_NO_REPLY_ADDRESS || env.SMTP_USER)
  );

const getNodemailer = () => {
  if (nodemailerRef !== null) {
    return nodemailerRef;
  }

  try {
    // Optional dependency in local setups. Keep graceful no-op behavior when unavailable.
    nodemailerRef = require('nodemailer');
  } catch {
    nodemailerRef = false;
  }

  return nodemailerRef;
};

const getTransporter = () => {
  if (transporter) {
    return transporter;
  }

  const nodemailer = getNodemailer();
  if (!nodemailer) {
    return null;
  }

  transporter = nodemailer.createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: Number(env.SMTP_PORT) === 465,
    auth: {
      user: env.SMTP_USER,
      pass: env.SMTP_PASS,
    },
  });

  return transporter;
};

/**
 * Send email.
 *
 * @param {Object} data - Email payload
 * @param {string|string[]} data.to - Recipient(s)
 * @param {string} data.subject - Email subject
 * @param {string} [data.text] - Plain text body
 * @param {string} [data.html] - HTML body
 * @param {Array<Object>} [data.attachments] - Optional file/CID attachments
 * @returns {Promise<{ sent: boolean, provider: string }>}
 */
const sendEmail = async (data) => {
  const recipients = normalizeRecipients(data?.to);
  const subject = data?.subject;
  const text = data?.text;
  const html = data?.html;
  const attachments = Array.isArray(data?.attachments) ? data.attachments : undefined;

  if (recipients.length === 0 || !subject || (!text && !html)) {
    return { sent: false, provider: STORAGE.SKIPPED };
  }

  if (!canUseSmtp()) {
    logger.warn('SMTP not configured; email delivery skipped.', {
      recipient: recipients.map(maskEmail),
      subject,
    });
    return { sent: false, provider: STORAGE.SKIPPED };
  }

  const smtpTransporter = getTransporter();
  if (!smtpTransporter) {
    logger.warn('nodemailer missing; email delivery skipped.', {
      recipient: recipients.map(maskEmail),
      subject,
    });
    return { sent: false, provider: STORAGE.SKIPPED };
  }

  try {
    const fromHeader = resolveFromHeader();
    if (!fromHeader) {
      logger.warn('No valid sender identity configured; email delivery skipped.', {
        recipient: recipients.map(maskEmail),
        subject,
      });
      return { sent: false, provider: STORAGE.SKIPPED };
    }

    const envelopeFrom = resolveEnvelopeFrom();

    await smtpTransporter.sendMail({
      from: fromHeader,
      replyTo: resolveReplyToHeader(),
      to: recipients,
      envelope: envelopeFrom
        ? {
            from: envelopeFrom,
            to: recipients,
          }
        : undefined,
      subject,
      text,
      html,
      attachments,
      headers: {
        'Auto-Submitted': 'auto-generated',
        'X-Auto-Response-Suppress': 'All',
        Precedence: 'bulk',
      },
    });

    return { sent: true, provider: STORAGE.SMTP };
  } catch (error) {
    logger.error('Email delivery failed.', {
      recipient: recipients.map(maskEmail),
      subject,
      error: error?.message || 'unknown_error',
    });

    return { sent: false, provider: STORAGE.UNKNOWN };
  }
};

module.exports = {
  sendEmail,
};
