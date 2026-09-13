/**
 * Shared SMTP transport for the site's API routes.
 *
 * Returns null when no credentials are configured, which callers treat as
 * "log it instead of sending" rather than as an error - the contact form and
 * the demo request both still succeed for the visitor in that case.
 *
 * @file src/lib/mailer.js
 */

import nodemailer from 'nodemailer';
import { CONTACT_EMAIL } from '@/lib/constants';

/**
 * Build a transporter from the environment.
 *
 * SMTP_HOST + SMTP_PORT take precedence; otherwise SMTP_USER + SMTP_PASS go
 * through a named service (Gmail by default).
 *
 * @returns {import('nodemailer').Transporter|null} Transport, or null when unconfigured
 */
export function createTransporter() {
  if (process.env.SMTP_HOST && process.env.SMTP_PORT) {
    return nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT, 10),
      secure: process.env.SMTP_SECURE === 'true' || process.env.SMTP_PORT === '465',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }

  if (process.env.SMTP_USER && process.env.SMTP_PASS) {
    return nodemailer.createTransport({
      service: process.env.SMTP_SERVICE || 'gmail',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }

  return null;
}

/**
 * The address mail is sent from.
 *
 * Gmail requires this to be the authenticated account or a verified alias, so
 * it follows SMTP_USER rather than the reply-to inbox.
 *
 * @returns {string} From address
 */
export function fromAddress() {
  return process.env.SMTP_FROM || process.env.SMTP_USER || CONTACT_EMAIL;
}
