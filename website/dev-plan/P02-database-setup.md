# Phase 2: Database Setup & Core Infrastructure

## Overview
Set up MySQL database, Prisma schema, and core database utilities.

## Steps

### Step 2.1: Set Up MySQL Database
- [ ] Install MySQL (if not already installed)
- [ ] Create database: `CREATE DATABASE website_db;`
- [ ] Create database user and grant permissions
- [ ] Test database connection

### Step 2.2: Configure Prisma
- [x] Initialize Prisma: `npx prisma init`
- [x] Update `prisma/schema.prisma` with MySQL provider
- [x] Set `DATABASE_URL` in `.env` file
- [x] Test Prisma connection: `npx prisma db pull` (optional)

### Step 2.3: Create Prisma Schema - Core Models
- [x] Create `Product` model with all fields:
  - id, name, description, shortDescription, category, version, releaseDate, status, downloadUrl, createdAt, updatedAt
- [x] Create `ProductImage` model with relations
- [x] Create `ProductTag` model with relations
- [x] Create `ProductFeature` model with relations
- [x] Create `ProductTechnology` model with relations
- [x] Create `ProductStatus` enum (ACTIVE, ARCHIVED)
- [x] Define all foreign key relationships

### Step 2.4: Create Prisma Schema - User & Auth Models
- [x] Create `User` model (id, email, passwordHash, role, createdAt, updatedAt)
- [x] Create `UserRole` enum (ADMIN, USER)
- [x] Create `Session` model (optional, for custom session management)
- [x] Define relationships

### Step 2.5: Run Initial Migration
- [x] Generate migration: `npx prisma migrate dev --name init`
- [x] Review generated migration files
- [x] Apply migration to database
- [x] Verify tables created in database

### Step 2.6: Create Prisma Client Instance
- [x] Create `src/lib/prisma.js` file
- [x] Implement singleton pattern for Prisma client
- [x] Add connection error handling
- [x] Export prisma client instance
- [x] Test Prisma client connection

### Step 2.7: Create Seed Script
- [x] Create `prisma/seed.mjs` file (updated to ES modules)
- [x] Add seed data for initial admin user
- [x] Add seed data for sample products
- [x] Configure seed script in `package.json`
- [x] Run seed: `npx prisma db seed`
- [x] Verify seed data in database

## Completion Criteria
- ✅ Database created and accessible
- ✅ Prisma schema complete with all models
- ✅ Migrations applied successfully
- ✅ Prisma client working
- ✅ Seed data loaded

