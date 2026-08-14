# Hospital Management System (HMS) Backend API

A comprehensive backend API for a modern, modular Hospital Management System built with Node.js, Express.js, and Prisma.

## Overview

This backend provides RESTful APIs for managing clinical, operational, and administrative hospital workflows with a modular, multi-tenant architecture. It supports module-based subscriptions, customization requests, and flexible payments for both local and international deployments, while maintaining strict MVC patterns and clear separation of concerns.

## Core Capabilities

- Modular HMS modules (clinical, diagnostics, pharmacy, inventory, HR, billing)
- Multi-tenant support for multiple hospitals/branches
- Role-based access control (RBAC) and audit logging
- Subscription, per-module billing, and perpetual licensing options
- Multi-currency payments with local and international providers
- Customization and integration request workflows

## Technology Stack

- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: MySQL
- **ORM**: Prisma
- **Authentication**: JWT
- **Validation**: Zod
- **Real-time**: WebSockets (ws)

## Non-negotiable project rules (quick)

- **Module system**: CommonJS only (`require`/`module.exports`) — no ESM `import`/`export`
- **Architecture**: Route → Controller → Service → Repository → Prisma (no skipped layers)
- **Versioning**: All API module endpoints are under `/api/v1/*`
- **Health endpoints**: `GET /health`, `GET /ready`, `GET /live` (unversioned)
- **Validation**: Zod schemas only (no inline/manual validation)
- **Responses**: Use standardized response helpers from `src/lib/response/`

## Project Structure

The project follows a strict MVC architecture with modules organized by business domain. See `.cursor/rules/project-structure.mdc` for detailed structure.

## Getting Started

### Prerequisites

- Node.js (v18 or higher)
- MySQL database
- npm or yarn

### Installation

#### Manual Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```
3. Review the tracked `env.template.txt` placeholders and update the values you will need locally (see `dev-plan/P000_setup.md` for the authoritative list).
4. Copy `env.template.txt` to `.env.development` and configure it. `src/config/env.js` loads
   `.env.development` automatically whenever `NODE_ENV` is `development` (the default when
   `NODE_ENV` isn't set at all, which is the normal case on a local machine):

   **Bash/Unix:**
   ```bash
   cp env.template.txt .env.development
   ```

   **PowerShell:**
   ```powershell
   Copy-Item env.template.txt .env.development
   ```

   **Cross-platform (Node.js):**
   ```bash
   node -e "require('fs').copyFileSync('env.template.txt', '.env.development')"
   ```
5. Update `.env.development` with your database credentials and other required variables.
   - Do **not** commit `.env.development` (already covered by `.gitignore`)
   - A legacy single `.env` file still works as a fallback if `.env.development` /
     `.env.production` aren't present, but new setups should use the split files above.
6. Run Prisma migrations:
   ```bash
   npx prisma migrate dev
   ```
7. Generate the Prisma client package:
   ```bash
   npm run prisma:generate
   ```
   This writes the runtime client to `node_modules/.prisma/client`.
8. (Optional) Create the default single-hospital demo accounts:
   ```bash
   npm run setup:accounts
   ```
   This creates default accounts for all user types. See `scripts/README.md` for details.

### Development

Start the development server with auto-reload:
```bash
npm run dev
```

### Mobile / LAN Access

To access the API from phones/tablets on the same network:

1. Set `HOST="0.0.0.0"` in `.env.development`.
2. Keep `ALLOW_PRIVATE_NETWORK_ORIGINS="true"` for local development.
3. Add your frontend origin(s) to `CORS_ORIGINS` (for example `http://192.168.1.15:8081`).
4. Start the backend and use one of the printed `LAN access URLs`.
5. Ensure your frontend API base URL points to the backend LAN IP, not `localhost`.

### Production

`npm start` and `npm run prestart` now set `NODE_ENV=production` for you (via `cross-env`), which
makes `src/config/env.js` load `.env.production` instead of `.env.development`:

```bash
npm start
```

For reverse-proxy deployments such as `api.hosspi.com` behind Nginx, `.env.production` should set:

- `NODE_ENV="production"`
- `HOST="127.0.0.1"` so Node only listens locally
- `TRUST_PROXY="1"` so Express honors forwarded IP/protocol headers correctly
- `CORS_ORIGINS` to your HTTPS frontend origins
- `APP_PUBLIC_URL` to your public frontend URL, for example `https://www.hosspi.com`
- Run `npm ci --omit=dev`, `npm run prisma:generate`, and `npx prisma migrate deploy` before starting the service
- Keep `@prisma/client` installed in production; the backend runtime loads the generated client from `node_modules/.prisma/client`

### Deploying to cPanel

The backend can run on cPanel's "Setup Node.js App" (Passenger). Environment variables are split
so the same codebase behaves correctly on your machine and on the server:

1. On the cPanel "Setup Node.js App" screen, set **Application mode** to **Production**. cPanel
   injects `NODE_ENV=production` for the app process based on this setting, which is what makes
   `src/config/env.js` pick `.env.production`.
2. Copy `.env.production.example` to `.env.production`, fill in the real production values
   (database credentials, `JWT_SECRET`, `CSRF_SECRET`, `CORS_ORIGINS`, `APP_PUBLIC_URL`, etc.),
   and upload the resulting `.env.production` file to the backend's directory on the server (via
   cPanel File Manager or SFTP). **Never commit `.env.production`** - it is already excluded by
   `.gitignore` (`.env.*`).
3. cPanel's Node.js Selector assigns and injects its own `PORT` for the app - the `PORT` value in
   `.env.production` is only a fallback for manual (non-Passenger) runs.
4. Run the install/build steps from the cPanel "Setup Node.js App" terminal (or SSH, if
   available): `npm ci --omit=dev`, then `npm run prisma:generate`. If `NODE_ENV` isn't already
   exported in that shell, force the right file explicitly instead of relying on the default:
   ```bash
   ENV_FILE=.env.production npx prisma migrate deploy
   ```
5. Restart the Node.js app from the cPanel UI after uploading a new `.env.production` or
   deploying new code - Passenger does not pick up file changes automatically.
6. Confirm the deployed database name/user/password in `.env.production` matches the database
   created via cPanel's MySQL Database Wizard exactly (cPanel typically prefixes both the
   database name and username with your cPanel account name).

Deployment templates are available in [`../deploy`](../deploy).

## Import aliases

This repo uses runtime aliases (via `module-alias`) like `@lib/*`, `@config/*`, `@services/<module>/*`. These must be registered at the very top of `src/server.js` (per `.cursor/rules/import-aliases.mdc`).

## API Endpoints

All endpoints are prefixed with `/api/v1/`. See `.cursor/rules/api.mdc` for complete endpoint documentation.

### Health Check Endpoints

The following health check endpoints are available at the root level (not under `/api/v1/`):

- `GET /health` - Application health status (returns 200 if healthy, 503 if unhealthy)
- `GET /ready` - Readiness check (returns 200 if ready to serve traffic, 503 if not ready)
- `GET /live` - Liveness check (returns 200 if application process is alive)

These endpoints are public and do not require authentication. They are used for monitoring and container orchestration.

## Scripts

Utility scripts are located in the `scripts/` directory. See `scripts/README.md` for detailed documentation.

### Setup Default Accounts

Create one default demo account for each user type in the seeded `DemoCare General Hospital` workspace (PLATFORM_ADMIN, TENANT_ADMIN, DOCTOR, NURSE, OPERATIONS, HR, BIOMED, HOUSE_KEEPER, etc.):

```bash
npm run setup:accounts
```

**⚠️ Security Note**: All accounts are created with a default password. Change passwords immediately after first login!

For more information, see `scripts/README.md`.

## Testing

Run the complete backend delivery gate (lint, tests, and OpenAPI contract
validation):
```bash
npm run validate:delivery
```

This gate targets the cross-cutting response, scope, offline, realtime, public
identifier, and health contracts used by CI. Run `npm run validate` for the full
backend regression suite, or `npm test` when only Jest is required during local
iteration.

## Project Rules

This project follows strict architectural and coding standards defined in `.cursor/rules/`. Key rules include:

- **MVC architecture**: Route → Controller → Service → Repository → Prisma
- **Module system**: CommonJS only (`require`/`module.exports`)
- **Import aliases**: All imports use aliases (no relative imports across modules)
- **Validation**: Zod schemas for all request inputs
- **Authentication**: JWT with RBAC (Role-Based Access Control)
- **Database**: Prisma ORM with MySQL, soft deletes for all resources
- **Audit logging**: All mutations create audit logs (non-blocking)
- **Response format**: Standardized JSON responses with consistent structure
- **Health checks**: Health, readiness, and liveness endpoints for monitoring
- **Error handling**: Centralized error middleware with sanitized logging
- **Rate limiting**: Configurable rate limits per endpoint/user
- **CORS**: Environment-aware CORS configuration

See `.cursor/rules/index.mdc` for the complete list of 24 rule files covering all aspects of the project.

## License

ISC

