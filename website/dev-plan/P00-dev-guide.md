# Phase 0: Development Guide

**Source of Truth**: All rules and standards are defined in `.cursor/rules/`. This guide provides quick reference and templates that align with those rules.

## Quick Start

1. **Read Rules First**: Review `.cursor/rules/index.mdc` to understand the rule structure
2. **Follow Phases**: Complete phases in `dev-plan/` in chronological order
3. **Reference Rules**: Always check `.cursor/rules/` for detailed requirements
4. **Use Templates**: Use templates below (which match `.cursor/rules/` exactly)

## Component Template

**Source**: `.cursor/rules/components.mdc` and `.cursor/rules/styled-components.mdc`

```javascript
/**
 * Component description
 * @param {Object} props
 * @param {string} props.variant - Component variant (optional)
 * @param {boolean} props.disabled - Disabled state (optional)
 * @param {React.ReactNode} props.children - Component content
 */
'use client'; // Only if needed (interactivity, hooks, browser APIs)

import React from 'react';
import styled from 'styled-components';
import { theme } from '@/styles/theme';

const StyledComponentName = styled.element`
  /* Base styles - mobile-first */
  padding: ${props => props.theme.spacing.md};
  color: ${props => props.theme.colors.text.primary};
  background-color: ${props => props.theme.colors.background.primary};
  border-radius: ${props => props.theme.borderRadius.md};
  transition: all ${props => props.theme.transition.duration} ${props => props.theme.transition.timing};
  
  /* Responsive - enhance for larger screens */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    padding: ${props => props.theme.spacing.lg};
  }
  
  @media (min-width: ${props => props.theme.breakpoints.md}) {
    padding: ${props => props.theme.spacing.xl};
  }
  
  /* Variants */
  ${props => props.variant === 'primary' && `
    background-color: ${props.theme.colors.primary};
    color: ${props.theme.colors.text.onPrimary};
  `}
  
  ${props => props.variant === 'secondary' && `
    background-color: ${props.theme.colors.secondary};
    color: ${props.theme.colors.text.onSecondary};
  `}
  
  /* States */
  &:active {
    transform: translateY(0);
  }
  
  &:hover {
    opacity: 0.9;
    transform: translateY(-2px);
  }
  
  &:focus {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
  }
  
  &:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    pointer-events: none;
  }
`;

export const ComponentName = React.memo(({ 
  variant = 'default', 
  disabled = false, 
  onClick, 
  children, 
  ...props 
}) => {
  return (
    <StyledComponentName
      variant={variant}
      disabled={disabled}
      onClick={onClick}
      aria-label={props['aria-label']}
      {...props}
    >
      {children}
    </StyledComponentName>
  );
});

ComponentName.displayName = 'ComponentName';
```

**Note**: Use `React.memo` for layout components (Header, Footer, Navigation) to prevent re-renders on navigation. See `.cursor/rules/components.mdc` for details.

## Server Component Template

**Source**: `.cursor/rules/nextjs.mdc`

```javascript
/**
 * Page/Component Name - Description
 * Server Component that fetches data from database
 */
import { prisma } from '@/lib/prisma';
import { Component } from '@/components/...';

export default async function PageName() {
  try {
    const data = await prisma.model.findMany({
      select: {
        // Select only needed fields
      },
      where: {
        // Filter conditions
      },
    });
    
    return (
      <div>
        <Component data={data} />
      </div>
    );
  } catch (error) {
    console.error('Error:', error);
    return <div>Error loading data</div>;
  }
}
```

## API Route Template

**Source**: `.cursor/rules/api-routes.mdc` and `.cursor/rules/nextjs.mdc`

```javascript
/**
 * Route Name API Route
 * Handles [GET/POST/PUT/DELETE] requests for [resource]
 */
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { verifyAuth } from '@/lib/auth'; // If protected

export async function GET(request) {
  try {
    const { searchParams } = new URL(request.url);
    
    const data = await prisma.model.findMany({
      // Query options
    });
    
    return NextResponse.json({ data }, { status: 200 });
  } catch (error) {
    console.error('API Error:', error);
    return NextResponse.json(
      { error: 'Failed to fetch data' },
      { status: 500 }
    );
  }
}

export async function POST(request) {
  try {
    const session = await verifyAuth(request);
    if (!session) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }
    
    const body = await request.json();
    
    const data = await prisma.model.create({
      data: {
        // Data fields
      },
    });
    
    return NextResponse.json({ data }, { status: 201 });
  } catch (error) {
    console.error('API Error:', error);
    return NextResponse.json(
      { error: 'Failed to create data' },
      { status: 500 }
    );
  }
}
```

## Prisma Query Template

**Source**: `.cursor/rules/prisma.mdc`

```javascript
/**
 * Function Name - Description
 * @param {string} id - Resource ID
 * @returns {Promise<Object>} Resource data
 */
import { prisma } from '@/lib/prisma';

export async function getResource(id) {
  try {
    const resource = await prisma.model.findUnique({
      where: { id },
      select: {
        // Select only needed fields
        id: true,
        name: true,
      },
      include: {
        // Include relations if needed
        relation: true,
      },
    });
    
    if (!resource) {
      throw new Error('Resource not found');
    }
    
    return resource;
  } catch (error) {
    console.error('Database error:', error);
    throw error;
  }
}
```

## Import Order

**Source**: `.cursor/rules/project-structure.mdc` (Section 7)

```javascript
// 1. React and Next.js imports
import React from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { NextResponse } from 'next/server';

// 2. Third-party libraries
import styled from 'styled-components';

// 3. Internal components (from barrel exports)
import { Button, Card } from '@/components/ui';
import { Header, Footer } from '@/components/layout';
import { ProductCard } from '@/components/products';

// 4. Custom hooks
import { useAuth, useTheme } from '@/hooks';

// 5. Utilities and helpers
import { formatDate } from '@/lib/utils';
import { prisma } from '@/lib/prisma';
import { verifyAuth } from '@/lib/auth';

// 6. Constants and configuration
import { API_ENDPOINTS, APP_NAME } from '@/lib/constants';

// 7. Styles and theme
import { theme } from '@/styles/theme';
```

## Naming Conventions

**Source**: `.cursor/rules/project-structure.mdc` (Section 6) and `.cursor/rules/code-style.mdc`

| Type | Convention | Example |
|------|------------|---------|
| Component File | PascalCase | `ProductCard.js` |
| Component Name | PascalCase | `ProductCard` |
| Styled Component | `Styled` + PascalCase | `StyledProductCard` |
| Utility Function | camelCase | `formatDate` |
| Constant | UPPER_SNAKE_CASE | `API_ENDPOINTS` |
| Hook | `use` + camelCase | `useAuth` |
| Page File | lowercase | `page.js` |
| API Route | lowercase | `route.js` |

## Theme Usage

**Source**: `.cursor/rules/theme.mdc` and `.cursor/rules/styled-components.mdc`

```javascript
// ✅ CORRECT - Always use theme
color: ${props => props.theme.colors.text.primary};
padding: ${props => props.theme.spacing.md};
@media (min-width: ${props => props.theme.breakpoints.md}) { }

// ❌ WRONG - Never hardcode
color: #000000;
padding: 16px;
@media (min-width: 768px) { }
```

## Constants Usage

**Source**: `.cursor/rules/constants.mdc`

```javascript
// ✅ CORRECT
import { APP_NAME, NAVIGATION_LINKS } from '@/lib/constants';

// ❌ WRONG - Never hardcode app values
const appName = 'My App';
```

## Server vs Client Components

**Source**: `.cursor/rules/nextjs.mdc` (Section 1)

- **Server Component** (default): No `'use client'`, can use async/await, fetch data
- **Client Component**: Add `'use client'` when you need:
  - useState, useEffect, other hooks
  - onClick, onChange, event handlers
  - Browser APIs (window, document)
  - Context API

## Verification Checklist

**Source**: `.cursor/rules/reusability.mdc` and `.cursor/rules/components.mdc`

Before marking any feature complete:

### Component Checklist
- [ ] Follows exact template structure from `.cursor/rules/components.mdc`
- [ ] Uses theme variables (no hardcoded values) - see `.cursor/rules/theme.mdc`
- [ ] Has complete JSDoc documentation
- [ ] Follows naming conventions from `.cursor/rules/project-structure.mdc`
- [ ] Uses barrel exports - see `.cursor/rules/project-structure.mdc`
- [ ] Error handling implemented (try/catch for async)
- [ ] Responsive (mobile-first) - see `.cursor/rules/responsive.mdc`
- [ ] Accessible (ARIA, semantic HTML) - see `.cursor/rules/accessibility.mdc`
- [ ] Server/Client Component correctly marked - see `.cursor/rules/nextjs.mdc`
- [ ] Imports in correct order - see `.cursor/rules/project-structure.mdc`
- [ ] Layout components use `React.memo` - see `.cursor/rules/components.mdc`
- [ ] Constants from `@/lib/constants` - see `.cursor/rules/constants.mdc`

### API Route Checklist
- [ ] Follows template from `.cursor/rules/api-routes.mdc`
- [ ] All async operations wrapped in try/catch
- [ ] Proper HTTP status codes (200, 201, 400, 401, 404, 500)
- [ ] Input validation and sanitization
- [ ] Authentication checks for protected routes

### Database Query Checklist
- [ ] Follows template from `.cursor/rules/prisma.mdc`
- [ ] Uses Prisma client from `@/lib/prisma` (singleton)
- [ ] Uses `select` to fetch only needed fields
- [ ] Uses `include` for relations when needed
- [ ] Error handling with try/catch

## File Locations

**Source**: `.cursor/rules/project-structure.mdc`

All source code is in `src/` directory:
- **Components**: `src/components/[category]/ComponentName.js`
- **Pages**: `src/app/[route]/page.js`
- **API Routes**: `src/app/api/[route]/route.js`
- **Utilities**: `src/lib/utilityName.js`
- **Constants**: `src/lib/constants.js`
- **Theme**: `src/styles/theme.js`
- **Prisma**: `src/lib/prisma.js`

Root level directories:
- **Prisma Config**: `prisma/schema.prisma`
- **Public Assets**: `public/[folder]/`

## Common Mistakes to Avoid

❌ **Hardcoded values** - Always use theme (`.cursor/rules/theme.mdc`)
❌ **Missing error handling** - Always use try/catch (`.cursor/rules/reusability.mdc`)
❌ **No JSDoc** - Always document (`.cursor/rules/components.mdc`)
❌ **Wrong import order** - Follow strict order (`.cursor/rules/project-structure.mdc`)
❌ **No barrel exports** - Always export from index.js (`.cursor/rules/project-structure.mdc`)
❌ **Duplication** - Reuse existing components (`.cursor/rules/reusability.mdc`)
❌ **Missing 'use client'** - Mark Client Components (`.cursor/rules/nextjs.mdc`)
❌ **Hardcoded breakpoints** - Use theme breakpoints (`.cursor/rules/theme.mdc`)
❌ **Hardcoded app values** - Use constants (`.cursor/rules/constants.mdc`)

## Rule Files Reference

All rules are in `.cursor/rules/`:
- `index.mdc` - Overview and rule structure
- `project-structure.mdc` - Directory organization, imports, file naming
- `components.mdc` - Component structure and patterns
- `styled-components.mdc` - Styled Components rules
- `nextjs.mdc` - Next.js App Router rules
- `prisma.mdc` - Database and Prisma rules
- `api-routes.mdc` - API route patterns
- `constants.mdc` - Constants and configuration
- `theme.mdc` - Theme and styling rules
- `code-style.mdc` - JavaScript style and naming
- `reusability.mdc` - Reusability and uniformity
- `performance.mdc` - Performance optimization
- `responsive.mdc` - Responsive design
- `accessibility.mdc` - Accessibility requirements
- `security.mdc` - Security rules
- `quality.mdc` - Code quality

**Always refer to `.cursor/rules/` for the complete, authoritative rules.**

