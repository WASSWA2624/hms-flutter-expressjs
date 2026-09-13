/**
 * ThemeToggle - Toggle button for switching between light and dark themes
 * 
 * @component
 * @returns {JSX.Element} Rendered theme toggle button
 * 
 * @example
 * <ThemeToggle />
 */
'use client';

import React from 'react';
import styled from 'styled-components';
import { useTheme, useTranslation } from '@/hooks';

const StyledThemeToggle = styled.button`
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: ${props => props.theme.colors.backgroundSecondary};
  border: 1px solid ${props => props.theme.colors.border};
  border-radius: ${props => props.theme.borderRadius.full};
  padding: ${props => props.theme.spacing.xs};
  min-width: 40px;
  min-height: 40px;
  cursor: pointer;
  transition: all ${props => props.theme.transitions.normal};
  color: ${props => props.theme.colors.text};
  box-sizing: border-box;
  flex-shrink: 0;
  -webkit-tap-highlight-color: transparent;

  &:hover {
    background-color: ${props => props.theme.colors.backgroundTertiary};
    transform: scale(1.05);
  }

  &:active {
    transform: scale(0.95);
  }

  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
  }

  svg {
    width: 18px;
    height: 18px;
    transition: transform ${props => props.theme.transitions.normal};
    flex-shrink: 0;
  }

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    min-width: 44px;
    min-height: 44px;
    padding: ${props => props.theme.spacing.sm};

    svg {
      width: 20px;
      height: 20px;
    }
  }

  @media (max-width: 360px) {
    min-width: 36px;
    min-height: 36px;
    padding: 2px;

    svg {
      width: 16px;
      height: 16px;
    }
  }
`;

StyledThemeToggle.displayName = 'StyledThemeToggle';

const SunIcon = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    stroke="currentColor"
    aria-hidden="true"
  >
    <path
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={2}
      d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"
    />
  </svg>
);

const MoonIcon = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    stroke="currentColor"
    aria-hidden="true"
  >
    <path
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={2}
      d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"
    />
  </svg>
);

export const ThemeToggle = React.memo(() => {
  const { mode, toggleTheme } = useTheme();
  const { t } = useTranslation('common');

  return (
    <StyledThemeToggle
      onClick={toggleTheme}
      aria-label={mode === 'light' ? t('switchToDarkMode') : t('switchToLightMode')}
      type="button"
    >
      {mode === 'light' ? <MoonIcon /> : <SunIcon />}
    </StyledThemeToggle>
  );
});

ThemeToggle.displayName = 'ThemeToggle';

