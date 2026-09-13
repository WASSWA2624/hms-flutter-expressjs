/**
 * useTheme Hook
 * 
 * Custom hook for accessing theme context.
 * Provides theme mode, toggle, and set functions.
 * 
 * @file src/hooks/useTheme.js
 */
'use client';

import { useThemeMode } from '@/components/common/ThemeProvider';

/**
 * Hook to access theme context
 * @returns {Object} Theme context with mode, toggleTheme, and setTheme
 */
export function useTheme() {
  return useThemeMode();
}

