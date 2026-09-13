# Phase 4: Theme System & Styling Foundation

## Overview
Set up the theme system, global styles, and base UI components.

## Steps

### Step 4.1: Create Theme Configuration
- [x] Create `src/styles/theme.js` file
- [x] **Follow exact structure** from `.cursor/rules/theme.mdc` and `P00-dev-guide.md` theme template
- [x] Define color palette (primary, secondary, background, text, etc.)
- [x] Define spacing scale (xs: '0.25rem', sm: '0.5rem', md: '1rem', lg: '1.5rem', xl: '2rem')
- [x] Define breakpoints (xs: '320px', sm: '768px', md: '1024px', lg: '1440px', xl: '1920px')
- [x] Define typography (fontFamily, fontSize, lineHeight)
- [x] Define border radius values (consistent across app)
- [x] Define shadow values (consistent across app)
- [x] Export theme object as named export: `export const theme = { ... }`
- [x] **CRITICAL**: All values must be in theme - no hardcoded values anywhere in app

### Step 4.2: Create Theme Provider Component
- [x] Create `src/components/common/ThemeProvider.js` as Client Component (`'use client'`)
- [x] Import `ThemeProvider` from `styled-components`
- [x] Implement ThemeProvider wrapper component
- [x] Add dark/light mode support with state management
- [x] Add theme persistence (localStorage or cookies)
- [x] Add system preference detection using `window.matchMedia`
- [x] Export ThemeProvider component
- [x] Update `src/app/layout.js` to wrap with ThemeProvider

### Step 4.3: Create Global Styles
- [x] Create `src/styles/globals.js` or add to root layout
- [x] Add CSS reset or normalize
- [x] Define base typography styles
- [x] Define base spacing utilities
- [x] Add global focus styles
- [x] Add scrollbar styling (optional)

### Step 4.4: Create Base UI Components - Button
- [x] **Use exact template** from `.cursor/rules/components.mdc` and `P00-dev-guide.md` Component Template
- [x] Create `src/components/ui/Button.js` as Client Component (`'use client'` - buttons are typically interactive)
- [x] Create `StyledButton` with theme integration (follow styled-components rules)
- [x] Use theme variables for all styling (colors, spacing, breakpoints)
- [x] Add variants (primary, secondary, danger) using props
- [x] Add size variants (sm, md, lg) using props
- [x] Add disabled state styling
- [x] Add hover and focus states (accessibility requirement)
- [x] Make button responsive using theme breakpoints (mobile-first)
- [x] Add complete JSDoc documentation following template
- [x] Export from `src/components/ui/index.js` (barrel export)

### Step 4.5: Create Base UI Components - Card
- [x] Create `src/components/ui/Card.js`
- [x] Create `StyledCard` with theme integration
- [x] Add card variants if needed
- [x] Add hover effects
- [x] Make card responsive
- [x] Add JSDoc documentation

### Step 4.6: Create Base UI Components - Input
- [x] Create `src/components/ui/Input.js`
- [x] Create `StyledInput` with theme integration
- [x] Add input variants (text, email, password, etc.)
- [x] Add error state styling
- [x] Add focus states
- [x] Make input responsive
- [x] Add JSDoc documentation

### Step 4.7: Create Base UI Components - Modal
- [x] Create `src/components/ui/Modal.js`
- [x] Create `StyledModal` with theme integration
- [x] Add overlay/backdrop
- [x] Add open/close functionality
- [x] Add close button
- [x] Add keyboard escape handling
- [x] Add focus trap for accessibility
- [x] Make modal responsive

### Step 4.8: Create UI Components Barrel Export
- [x] Create `src/components/ui/index.js`
- [x] Export all UI components
- [x] Test imports work correctly

### Step 4.9: Create Theme Toggle Component
- [x] Create `src/components/common/ThemeToggle.js` as Client Component (`'use client'`)
- [x] Create `StyledThemeToggle` with theme integration
- [x] Add theme toggle button/switch
- [x] Implement theme switching logic using context or props
- [x] Add icon for light/dark mode
- [x] Add smooth transition
- [x] Add to Header component

### Step 4.10: Style Layout Components with Theme
- [x] Update Header component: Create `StyledHeader` with theme
- [x] Update Navigation component: Create `StyledNavigation` with theme
- [x] Update Mobile Menu: Create `StyledMobileMenu` with theme and responsive breakpoints
- [x] Convert Footer component to Client Component: Add `'use client'` directive to `src/components/layout/Footer.js` (required for styled-components in Next.js App Router)
- [x] Update Footer component: Create `StyledFooter` with theme
- [x] Make all layout components responsive using theme breakpoints
- [x] Add sticky header behavior
- [x] Add smooth scroll behavior to navigation

## Completion Criteria
- ✅ Theme configuration complete with all values
- ✅ ThemeProvider working with dark/light mode and integrated in root layout
- ✅ Global styles applied
- ✅ Base UI components created (Button, Card, Input, Modal) with `Styled` prefix
- ✅ Theme toggle functional and added to header
- ✅ Layout components (Header, Footer, Navigation) styled with theme
- ✅ All components use theme variables (no hardcoded values)
- ✅ All components follow styled-components naming convention (`Styled` prefix)

