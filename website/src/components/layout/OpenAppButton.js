/**
 * OpenAppButton - Header call to action linking to the live application
 *
 * Sits in the header actions, immediately before the locale and theme
 * controls, so it is the last thing on the reading path across the bar and
 * the first thing the eye returns to. Below 640px it collapses to an icon
 * with an accessible label, keeping the header single-row on phones.
 *
 * @component
 * @param {Object} props
 * @param {string} props.href - Live application URL
 * @param {string} props.label - Visible label from 640px up
 * @returns {JSX.Element} Rendered call to action
 * @file src/components/layout/OpenAppButton.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';
import { Icon } from '@/components/ui';

const StyledOpenApp = styled.a`
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: ${props => props.theme.spacing.xs};
  flex-shrink: 0;
  white-space: nowrap;
  min-height: 36px;
  padding: 0 ${props => props.theme.spacing.sm};
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.primary};
  color: ${props => props.theme.colors.textInverse};
  border: 1px solid ${props => props.theme.colors.primary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  text-decoration: none;
  box-shadow: ${props => props.theme.shadows.sm};
  transition: background-color ${props => props.theme.transitions.fast},
              border-color ${props => props.theme.transitions.fast},
              transform ${props => props.theme.transitions.fast},
              box-shadow ${props => props.theme.transitions.fast};

  &:hover {
    background-color: ${props => props.theme.colors.primaryHover};
    border-color: ${props => props.theme.colors.primaryHover};
    box-shadow: ${props => props.theme.shadows.md};
    text-decoration: none;
    transform: translateY(-1px);
  }

  &:active {
    transform: translateY(0);
  }

  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
  }

  /* Tablet and up: room for the words */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    min-height: 40px;
    padding: 0 ${props => props.theme.spacing.md};
  }

  @media (min-width: ${props => props.theme.breakpoints.md}) {
    font-size: ${props => props.theme.typography.fontSize.md};
  }

  @media (prefers-reduced-motion: reduce) {
    transition: none;

    &:hover,
    &:active {
      transform: none;
    }
  }
`;

/* Hidden below 640px so the header stays one row on phones; the icon and the
   aria-label carry the meaning there. */
const StyledLabel = styled.span`
  display: none;

  @media (min-width: 640px) {
    display: inline;
  }
`;

StyledOpenApp.displayName = 'StyledOpenApp';
StyledLabel.displayName = 'StyledLabel';

export const OpenAppButton = React.memo(({ href, label }) => {
  return (
    <StyledOpenApp
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={label}
    >
      <StyledLabel>{label}</StyledLabel>
      <Icon name="arrowRight" size={16} />
    </StyledOpenApp>
  );
});

OpenAppButton.displayName = 'OpenAppButton';
