-- Drop the Accounts & Finance currency registry.
--
-- Currency handling stays with the existing tenant/facility default currency
-- (`frontend/lib/shared/components/app_currency.dart`,
-- `frontend/lib/core/currency/`) instead of a dedicated Setup & Controls tab,
-- so the registry table and its indexes are removed again.
--
-- `20260813230000_accounts_currency_rate` is kept in history so databases that
-- already applied it stay consistent; this migration reverses it.

DROP TABLE IF EXISTS `accounts_currency_rate`;
