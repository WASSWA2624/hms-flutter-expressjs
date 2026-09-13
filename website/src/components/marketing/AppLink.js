/**
 * AppLink - Prominent callout linking to the live HOSSPI HMS application
 *
 * @component
 * @param {Object} props
 * @param {string} props.href - Application URL
 * @param {string} props.label - Link label
 * @param {string} [props.note] - Optional supporting line
 * @returns {JSX.Element} Rendered callout
 * @file src/components/docs/AppLink.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';
import { Icon } from '@/components/ui';

const StyledCallout = styled.div`
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: ${props => props.theme.spacing.md};
  padding: ${props => props.theme.spacing.lg};
  border: 1px solid ${props => props.theme.colors.border};
  border-left: 4px solid ${props => props.theme.colors.primary};
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.backgroundSecondary};

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
  }
`;

const StyledNote = styled.p`
  margin: 0;
  color: ${props => props.theme.colors.textSecondary};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
`;

const StyledLink = styled.a`
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  gap: ${props => props.theme.spacing.xs};
  padding: ${props => props.theme.spacing.sm} ${props => props.theme.spacing.lg};
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.primary};
  color: ${props => props.theme.colors.textInverse};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  text-decoration: none;
  transition: background-color ${props => props.theme.transitions.fast};

  &:hover {
    background-color: ${props => props.theme.colors.primaryHover};
    text-decoration: none;
  }

  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
  }
`;

StyledCallout.displayName = 'StyledCallout';
StyledNote.displayName = 'StyledNote';
StyledLink.displayName = 'StyledAppLink';

export const AppLink = React.memo(({ href, label, note }) => {
  return (
    <StyledCallout>
      {note && <StyledNote>{note}</StyledNote>}
      <StyledLink href={href} target="_blank" rel="noopener noreferrer">
        {label}
        <Icon name="external" size={17} />
      </StyledLink>
    </StyledCallout>
  );
});

AppLink.displayName = 'AppLink';
