/**
 * LocaleSwitcher Component
 * 
 * Component for switching between supported locales.
 * @file src/components/common/LocaleSwitcher.js
 */

'use client';

import React from 'react';
import styled from 'styled-components';
import { useTranslation } from '@/hooks';
import { SUPPORTED_LOCALES, LOCALE_NAMES } from '@/lib/constants';
import { theme } from '@/styles/theme';

// Container for chevron and select
const StyledSelectWrapper = styled.div`
  position: relative;
  display: inline-flex;
  align-items: center;
  min-width: 0;
`;

const StyledSelect = styled.select`
  padding: ${props => props.theme.spacing.xs};
  border: 1px solid ${props => props.theme.colors.border};
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.background};
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.xs};
  cursor: pointer;
  transition: all ${props => props.theme.transitions.fast};
  min-width: 40px;
  min-height: 40px;
  flex-shrink: 0;
  max-width: 120px;
  position: relative;
  z-index: 1;
  box-sizing: border-box;
  padding-right: 2em; /* Space for chevron */
  -webkit-appearance: none;
  -moz-appearance: none;
  appearance: none;
  -webkit-tap-highlight-color: transparent;

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    font-size: ${props => props.theme.typography.fontSize.sm};
    padding: ${props => props.theme.spacing.sm} ${props => props.theme.spacing.md};
    padding-right: 2.2em;
    max-width: 150px;
    min-width: 44px;
    min-height: 44px;
  }

  @media (max-width: ${props => props.theme.breakpoints.sm}) {
    min-width: 36px;
    min-height: 36px;
    max-width: 80px;
  }

  @media (max-width: 360px) {
    min-width: 32px;
    min-height: 32px;
    max-width: 75px;
    padding: 2px ${props => props.theme.spacing.xs};
    padding-right: 1.6em;
  }
  
  &:hover {
    border-color: ${props => props.theme.colors.primary};
  }
  
  &:focus {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
    z-index: ${props => props.theme.zIndex.modal};
  }
  
  option {
    background-color: ${props => props.theme.colors.background};
    color: ${props => props.theme.colors.text};
  }
`;

StyledSelect.displayName = 'StyledSelect';

// Chevron Icon
const Chevron = styled.span`
  pointer-events: none;
  position: absolute;
  right: 0.85em;
  top: 50%;
  transform: translateY(-50%);
  color: ${props => props.theme.colors.textSecondary || '#666'};
  width: 1.1em;
  height: 1.1em;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2;

  @media (max-width: 360px) {
    right: 0.45em;
    width: 1em;
    height: 1em;
  }
`;

/**
 * Locale Switcher Component
 * @param {Object} props
 * @param {string} props.className - Additional CSS class
 */
export const LocaleSwitcher = React.memo(({ className, ...props }) => {
  const { locale, changeLocale } = useTranslation();
  const { t } = useTranslation('common');
  
  const handleChange = (e) => {
    const newLocale = e.target.value;
    if (newLocale !== locale) {
      changeLocale(newLocale);
    }
  };
  
  return (
    <StyledSelectWrapper className={className}>
      <StyledSelect
        value={locale}
        onChange={handleChange}
        aria-label={t('selectLanguage') || 'Select language'}
        {...props}
      >
        {SUPPORTED_LOCALES.map((loc) => (
          <option key={loc} value={loc}>
            {LOCALE_NAMES[loc]}
          </option>
        ))}
      </StyledSelect>
      <Chevron aria-hidden="true">
        {/* Chevron Down SVG */}
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none"
          xmlns="http://www.w3.org/2000/svg" style={{ display: 'block', width: '100%', height: '100%' }}>
          <path d="M4.646 6.646a.5.5 0 0 1 .708 0L8 9.293l2.646-2.647a.5.5 0 0 1 .708.708l-3 3a.5.5 0 0 1-.708 0l-3-3a.5.5 0 0 1 0-.708z"
            fill="currentColor" />
        </svg>
      </Chevron>
    </StyledSelectWrapper>
  );
});

LocaleSwitcher.displayName = 'LocaleSwitcher';

