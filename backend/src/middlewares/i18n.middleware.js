/**
 * i18n Middleware
 *
 * Detects locale and attaches it to request/response context.
 */

const { getLocale, getDirection } = require('@lib/i18n');
const { logger } = require('@lib/logging');
const { DEFAULT_LOCALE } = require('@config/constants');

/**
 * Attach locale and direction to request/response.
 *
 * @returns {Function} Express middleware
 */
const i18nMiddleware = () => {
  return (req, res, next) => {
    const locale = getLocale(req);
    const direction = getDirection(locale);

    req.locale = locale;
    req.localeDirection = direction;
    res.locals.locale = locale;
    res.locals.direction = direction;

    if (locale !== DEFAULT_LOCALE) {
      logger.info('Non-default locale detected', { locale });
    }

    next();
  };
};

module.exports = i18nMiddleware;
