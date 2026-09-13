/**
 * CallToAction - Closing conversion band
 *
 * @component
 * @param {Object} props
 * @param {string} props.title - Headline
 * @param {string} props.body - Supporting line
 * @param {string} props.appUrl - Link to the live application
 * @param {string} props.primaryLabel - App link label
 * @param {string} [props.demoLabel] - Demo request button label
 * @param {string} props.secondaryLabel - Secondary CTA label
 * @param {string} props.secondaryHref - Secondary CTA destination
 * @returns {JSX.Element} Rendered call to action
 * @file src/components/marketing/CallToAction.js
 */
'use client';

import React from 'react';
import Link from 'next/link';
import styled from 'styled-components';
import { Icon } from '@/components/ui';
import { useRequestDemo } from '@/components/common';

const StyledBand = styled.section`
  background: linear-gradient(
    135deg,
    ${props => props.theme.colors.primary} 0%,
    ${props => props.theme.colors.primaryDark} 100%
  );
  color: ${props => props.theme.colors.textInverse};
`;

const StyledInner = styled.div`
  max-width: ${props => props.theme.breakpoints.lg};
  margin: 0 auto;
  padding: ${props => props.theme.spacing.xxl} ${props => props.theme.spacing.md};
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: ${props => props.theme.spacing.md};

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    padding: ${props => props.theme.spacing.xxl} ${props => props.theme.spacing.lg};
  }
`;

const StyledTitle = styled.h2`
  margin: 0;
  color: ${props => props.theme.colors.textInverse};
  font-size: ${props => props.theme.typography.fontSize['2xl']};
  font-weight: ${props => props.theme.typography.fontWeight.bold};
  line-height: ${props => props.theme.typography.lineHeight.tight};

  @media (min-width: ${props => props.theme.breakpoints.md}) {
    font-size: ${props => props.theme.typography.fontSize['3xl']};
  }
`;

const StyledBody = styled.p`
  margin: 0;
  max-width: 60ch;
  font-size: ${props => props.theme.typography.fontSize.lg};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
  opacity: 0.92;
`;

const StyledActions = styled.div`
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: ${props => props.theme.spacing.md};
  margin-top: ${props => props.theme.spacing.sm};
`;

const actionBase = props => `
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: ${props.theme.spacing.xs};
  min-height: 48px;
  padding: ${props.theme.spacing.sm} ${props.theme.spacing.xl};
  border-radius: ${props.theme.borderRadius.md};
  font-weight: ${props.theme.typography.fontWeight.semibold};
  text-decoration: none;
  transition: background-color ${props.theme.transitions.fast},
              color ${props.theme.transitions.fast};

  &:hover {
    text-decoration: none;
  }

  &:focus-visible {
    outline: 2px solid ${props.theme.colors.textInverse};
    outline-offset: 3px;
  }
`;

const StyledPrimary = styled.button`
  ${props => actionBase(props)}
  background-color: ${props => props.theme.colors.textInverse};
  color: ${props => props.theme.colors.primary};
  border: none;
  font-family: inherit;
  cursor: pointer;

  &:hover {
    background-color: ${props => props.theme.colors.backgroundSecondary};
  }
`;

const StyledAppLink = styled.a`
  ${props => actionBase(props)}
  border: 1px solid rgba(255, 255, 255, 0.6);
  color: ${props => props.theme.colors.textInverse};

  &:hover {
    background-color: rgba(255, 255, 255, 0.14);
  }
`;

const StyledSecondary = styled(Link)`
  ${props => actionBase(props)}
  border: 1px solid rgba(255, 255, 255, 0.6);
  color: ${props => props.theme.colors.textInverse};

  &:hover {
    background-color: rgba(255, 255, 255, 0.14);
  }
`;

StyledBand.displayName = 'StyledBand';
StyledInner.displayName = 'StyledInner';
StyledTitle.displayName = 'StyledTitle';
StyledBody.displayName = 'StyledBody';
StyledActions.displayName = 'StyledActions';
StyledPrimary.displayName = 'StyledPrimary';
StyledAppLink.displayName = 'StyledAppLink';
StyledSecondary.displayName = 'StyledSecondary';

export const CallToAction = React.memo(({
  title,
  body,
  appUrl,
  primaryLabel,
  secondaryLabel,
  secondaryHref,
  demoLabel = 'Request a demo',
}) => {
  const { open } = useRequestDemo();

  return (
    <StyledBand>
      <StyledInner>
        <StyledTitle>{title}</StyledTitle>
        <StyledBody>{body}</StyledBody>
        <StyledActions>
          <StyledPrimary type="button" onClick={open} aria-haspopup="dialog">
            {demoLabel}
            <Icon name="arrowRight" size={18} />
          </StyledPrimary>
          <StyledAppLink href={appUrl} target="_blank" rel="noopener noreferrer">
            {primaryLabel}
          </StyledAppLink>
          <StyledSecondary href={secondaryHref}>{secondaryLabel}</StyledSecondary>
        </StyledActions>
      </StyledInner>
    </StyledBand>
  );
});

CallToAction.displayName = 'CallToAction';
