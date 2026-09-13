# Phase 1: Project Setup & Foundation

## Overview
Set up the Next.js 16 project with all necessary dependencies and configuration files.

## Steps

### Step 1.1: Initialize Next.js Project
- [x] Create Next.js 16 app with App Router: `npx create-next-app@latest` (will install Next.js 16.1.1+)
- [x] **Important**: Select "No" for TypeScript, "No" for ESLint (we'll configure custom), "No" for Tailwind CSS
- [x] Configure project name: `website` (or your preferred name)
- [x] Verify project structure is created correctly
- [x] Test that dev server runs: `npm run dev`
- [x] **Read `.cursor/rules/index.mdc` and `dev-plan/P00-dev-guide.md`** before proceeding

### Step 1.2: Install Core Dependencies
- [x] Install styled-components: `npm install styled-components`
- [x] Install Prisma and client: `npm install prisma @prisma/client`
- [x] Install bcryptjs: `npm install bcryptjs`
- [x] Install next-auth (optional): `npm install next-auth`
- [x] **Note**: Next.js 16 has native styled-components support via compiler option (no babel plugin needed)

### Step 1.3: Configure Next.js
- [x] Create/update `next.config.js` with styled-components compiler support:
  ```javascript
  /** @type {import('next').NextConfig} */
  const nextConfig = {
    compiler: {
      styledComponents: true,
    },
  };
  module.exports = nextConfig;
  ```
- [x] Configure path aliases in `jsconfig.json`:
  ```json
  {
    "compilerOptions": {
      "baseUrl": ".",
      "paths": {
        "@/*": ["./src/*"]
      }
    }
  }
  ```
- [x] **Important**: This configures `@/` to point to `src/` directory
- [x] Set up environment variables structure (`.env.example`) with all required variables
- [x] Create `.env.local` file (add to `.gitignore`)

### Step 1.4: Set Up Project Structure
- [x] Create `src/` directory (source code root)
- [x] Create `src/app/` directory structure (layout.js, page.js)
- [x] Create `src/components/` directory with subdirectories (layout, ui, features, common)
- [x] Create `src/lib/` directory for utilities
- [x] Create `src/styles/` directory
- [x] Create `prisma/` directory at root level
- [x] Create `public/` subdirectories at root level (images, icons, fonts, uploads, downloads)
- [x] **Verify**: All source code in `src/`, Prisma and public at root

### Step 1.5: Configure Development Tools
- [x] Set up ESLint configuration
- [x] Set up Prettier configuration (optional)
- [x] Create `.gitignore` file
- [x] Create `README.md` with setup instructions
- [x] Verify all configurations work

### Step 1.6: Initialize Git Repository
- [x] Initialize git repository: `git init`
- [ ] Create initial commit with project setup
- [x] Set up `.gitignore` properly

## Completion Criteria
- ✅ Next.js project runs without errors
- ✅ All dependencies installed
- ✅ Project structure matches requirements
- ✅ Configuration files in place
- ✅ Git repository initialized

