/**
 * sendEmail helper tests
 */

const buildEnv = (overrides = {}) => ({
  APP_DISPLAY_NAME: 'Hospital Management System',
  SMTP_HOST: null,
  SMTP_PORT: null,
  SMTP_USER: null,
  SMTP_PASS: null,
  SMTP_FROM: null,
  SMTP_FROM_NAME: null,
  SMTP_REPLY_TO: null,
  SMTP_NO_REPLY_ADDRESS: null,
  ...overrides,
});

const loadSendEmail = ({ envOverrides = {}, nodemailerFactory } = {}) => {
  jest.resetModules();

  const logger = {
    warn: jest.fn(),
    error: jest.fn(),
  };

  jest.doMock('@config/env', () => buildEnv(envOverrides));
  jest.doMock('@lib/logging', () => ({ logger }));

  if (nodemailerFactory) {
    jest.doMock('nodemailer', nodemailerFactory);
  }

  const { sendEmail } = require('@lib/notifications/sendEmail');
  return { sendEmail, logger };
};

describe('sendEmail helper', () => {
  afterEach(() => {
    jest.clearAllMocks();
    jest.resetModules();
  });

  it('skips delivery when SMTP is not configured', async () => {
    const { sendEmail, logger } = loadSendEmail();

    const result = await sendEmail({
      to: 'patient@example.com',
      subject: 'Test subject',
      text: 'Test body',
    });

    expect(result).toEqual({ sent: false, provider: 'skipped' });
    expect(logger.warn).toHaveBeenCalledWith('SMTP not configured; email delivery skipped.', {
      recipient: ['pa***@example.com'],
      subject: 'Test subject',
    });
  });

  it('skips delivery when nodemailer is unavailable', async () => {
    const { sendEmail, logger } = loadSendEmail({
      envOverrides: {
        SMTP_HOST: 'smtp.example.com',
        SMTP_PORT: 587,
        SMTP_USER: 'mailer@example.com',
        SMTP_PASS: 'secret',
        SMTP_FROM: '"Mailer" <mailer@example.com>',
      },
      nodemailerFactory: () => {
        throw new Error('nodemailer missing');
      },
    });

    const result = await sendEmail({
      to: 'patient@example.com',
      subject: 'Test subject',
      text: 'Test body',
    });

    expect(result).toEqual({ sent: false, provider: 'skipped' });
    expect(logger.warn).toHaveBeenCalledWith('nodemailer missing; email delivery skipped.', {
      recipient: ['pa***@example.com'],
      subject: 'Test subject',
    });
  });

  it('sends email through SMTP when configuration and dependency are available', async () => {
    const sendMail = jest.fn().mockResolvedValue({ messageId: 'mock-message-id' });
    const createTransport = jest.fn(() => ({ sendMail }));

    const { sendEmail, logger } = loadSendEmail({
      envOverrides: {
        APP_DISPLAY_NAME: 'HMS',
        SMTP_HOST: 'smtp.example.com',
        SMTP_PORT: 587,
        SMTP_USER: 'mailer@example.com',
        SMTP_PASS: 'secret',
        SMTP_FROM_NAME: 'HMS Mailer',
        SMTP_FROM: '"HMS Team" <team@example.com>',
        SMTP_REPLY_TO: 'support@example.com',
        SMTP_NO_REPLY_ADDRESS: 'no-reply@example.com',
      },
      nodemailerFactory: () => ({ createTransport }),
    });

    const result = await sendEmail({
      to: ['patient@example.com'],
      subject: 'Subject line',
      text: 'Body text',
    });

    expect(result).toEqual({ sent: true, provider: 'smtp' });
    expect(createTransport).toHaveBeenCalledWith({
      host: 'smtp.example.com',
      port: 587,
      secure: false,
      auth: {
        user: 'mailer@example.com',
        pass: 'secret',
      },
    });
    expect(sendMail).toHaveBeenCalledWith(
      expect.objectContaining({
        from: '"HMS Mailer" <no-reply@example.com>',
        replyTo: 'support@example.com',
        to: ['patient@example.com'],
        envelope: {
          from: 'no-reply@example.com',
          to: ['patient@example.com'],
        },
        subject: 'Subject line',
        text: 'Body text',
      })
    );
    expect(logger.error).not.toHaveBeenCalled();
  });
});
