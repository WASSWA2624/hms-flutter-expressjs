/**
 * ThemeProviderWrapper - Client component wrapper for ThemeProvider and GlobalStyles
 * 
 * This wrapper is needed because layout.js is a Server Component and cannot
 * directly use styled-components. This component handles both ThemeProvider
 * and GlobalStyles in a client component context.
 * 
 * @component
 */
'use client';

import React from 'react';
import { ThemeProvider } from './ThemeProvider';
import { GlobalStyles } from '@/styles/globals';

export const ThemeProviderWrapper = React.memo(({ children }) => {
  try {
    return (
      <ThemeProvider>
        <GlobalStyles />
        {children}
      </ThemeProvider>
    );
  } catch(e) {
    console.error('[DEBUG] ThemeProviderWrapper: Render error', e);
    // Fallback: render without theme to avoid breaking the app
    return <>{children}</>;
  }
});

ThemeProviderWrapper.displayName = 'ThemeProviderWrapper';

