/**
 * ThemeProvider - Provides theme context to the application
 * 
 * Wraps the app with styled-components ThemeProvider and manages
 * dark/light mode state with persistence.
 * 
 * @component
 */
'use client';

import React, { createContext, useContext, useState, useEffect, useLayoutEffect } from 'react';
import { ThemeProvider as StyledThemeProvider } from 'styled-components';
import { theme } from '@/styles/theme';

// useLayoutEffect warns during SSR; fall back to useEffect on the server
const useIsomorphicLayoutEffect = typeof window !== 'undefined' ? useLayoutEffect : useEffect;

const ThemeContext = createContext({
  mode: 'light',
  toggleTheme: () => {},
  setTheme: () => {},
});

export const useThemeMode = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useThemeMode must be used within ThemeProvider');
  }
  return context;
};

const getThemeColors = (mode) => {
  return mode === 'dark' ? theme.colorsDark : theme.colors;
};

const getInitialTheme = () => {
  if (typeof window === 'undefined') {
    return 'light';
  }
  
  // Check localStorage first
  const stored = localStorage.getItem('theme');
  if (stored === 'light' || stored === 'dark') {
    return stored;
  }
  
  // Check system preference
  if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
    return 'dark';
  }
  
  return 'light';
};

export const ThemeProvider = ({ children }) => {
  // The first client render must match the server render ('light'), otherwise
  // React reports a hydration mismatch. Reading localStorage or data-theme here
  // would resolve to 'dark' on the client while the server rendered 'light'.
  const [mode, setMode] = useState('light');
  const [mounted, setMounted] = useState(false);

  // Layout effect: applies the stored/system theme after hydration but before
  // the browser paints, so there is no visible flash of the light theme.
  useIsomorphicLayoutEffect(() => {
    setMounted(true);
    const initialTheme = getInitialTheme();
    setMode(initialTheme);
  }, []);

  useEffect(() => {
    if (!mounted || typeof window === 'undefined') return;
    
    // Save to localStorage
    localStorage.setItem('theme', mode);
    
    // Update document class for CSS-based dark mode (optional)
    document.documentElement.setAttribute('data-theme', mode);
  }, [mode, mounted]);

  // Listen for system theme changes
  useEffect(() => {
    if (!mounted || typeof window === 'undefined') return;
    
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = (e) => {
      // Only auto-switch if user hasn't manually set a preference
      const stored = localStorage.getItem('theme');
      if (!stored || stored === 'system') {
        setMode(e.matches ? 'dark' : 'light');
      }
    };
    
    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, [mounted]);

  const toggleTheme = () => {
    setMode((prev) => (prev === 'light' ? 'dark' : 'light'));
  };

  const setTheme = (newMode) => {
    if (newMode === 'light' || newMode === 'dark') {
      setMode(newMode);
    }
  };

  // Always provide theme, even during SSR (use light theme as default)
  // This ensures GlobalStyles and other styled components can access theme
  const themeColors = getThemeColors(mode);
  const currentTheme = {
    ...theme,
    colors: themeColors,
    mode,
  };

  return (
    <ThemeContext.Provider value={{ mode, toggleTheme, setTheme }}>
      <StyledThemeProvider theme={currentTheme}>
        {children}
      </StyledThemeProvider>
    </ThemeContext.Provider>
  );
};

