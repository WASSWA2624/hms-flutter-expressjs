/**
 * MarketingHero - Landing page hero for HOSSPI HMS
 *
 * Shows the product wordmark, headline, summary, primary calls to action, and
 * the platforms the application ships on.
 *
 * @component
 * @param {Object} props
 * @param {string} props.title - Headline
 * @param {string} props.subtitle - Supporting paragraph
 * @param {string} props.appUrl - Link to the live application
 * @param {string} props.primaryLabel - Primary CTA label
 * @param {string} props.secondaryLabel - Secondary CTA label
 * @param {string} props.secondaryHref - Secondary CTA destination
 * @param {Array<{id: string, name: string, detail: string}>} props.platforms
 * @param {string} [props.platformsLabel] - Label above the platform list
 * @returns {JSX.Element} Rendered hero
 * @file src/components/marketing/MarketingHero.js
 */
'use client';

import React from 'react';
import Link from 'next/link';
import Image from 'next/image';
import styled from 'styled-components';
import { Icon } from '@/components/ui';

const StyledHero = styled.section`
  position: relative;
  overflow: hidden;
  background:
    radial-gradient(
      circle at 15% 15%,
      ${props => props.theme.colors.backgroundTertiary} 0%,
      transparent 55%
    ),
    linear-gradient(
      160deg,
      ${props => props.theme.colors.backgroundSecondary} 0%,
      ${props => props.theme.colors.background} 60%
    );
  border-bottom: 1px solid ${props => props.theme.colors.borderLight};
`;

const StyledInner = styled.div`
  max-width: ${props => props.theme.breakpoints.lg};
  margin: 0 auto;
  padding: clamp(3rem, 8vw, 7rem) clamp(1rem, 5vw, 4rem);
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: clamp(1rem, 2.2vw, 1.75rem);
`;

const StyledLogo = styled.div`
  width: clamp(72px, 12vw, 112px);
  filter: drop-shadow(0 12px 28px rgba(0, 121, 253, 0.24));

  img {
    width: 100%;
    height: auto;
    display: block;
  }
`;

const StyledEyebrow = styled.p`
  margin: 0;
  color: ${props => props.theme.colors.primary};
  font-size: clamp(0.72rem, 0.68rem + 0.2vw, 0.85rem);
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  letter-spacing: 0.16em;
  text-transform: uppercase;
`;

const StyledTitle = styled.h1`
  margin: 0;
  max-width: 20ch;
  color: ${props => props.theme.colors.text};
  font-size: clamp(2rem, 1.1rem + 4vw, 4rem);
  font-weight: ${props => props.theme.typography.fontWeight.bold};
  line-height: 1.06;
  letter-spacing: -0.03em;
  text-wrap: balance;
`;

const StyledSubtitle = styled.p`
  margin: 0;
  max-width: 60ch;
  color: ${props => props.theme.colors.textSecondary};
  font-size: clamp(1.02rem, 0.95rem + 0.5vw, 1.3rem);
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
  text-wrap: pretty;
`;

const StyledActions = styled.div`
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: ${props => props.theme.spacing.md};
  margin-top: ${props => props.theme.spacing.xs};
`;

const buttonBase = props => `
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: ${props.theme.spacing.xs};
  min-height: 48px;
  padding: ${props.theme.spacing.sm} ${props.theme.spacing.xl};
  border-radius: ${props.theme.borderRadius.md};
  font-size: ${props.theme.typography.fontSize.md};
  font-weight: ${props.theme.typography.fontWeight.semibold};
  text-decoration: none;
  transition: background-color ${props.theme.transitions.fast},
              border-color ${props.theme.transitions.fast},
              transform ${props.theme.transitions.fast};

  &:hover {
    text-decoration: none;
    transform: translateY(-1px);
  }

  &:focus-visible {
    outline: 2px solid ${props.theme.colors.primary};
    outline-offset: 3px;
  }

  @media (prefers-reduced-motion: reduce) {
    transition: none;

    &:hover {
      transform: none;
    }
  }
`;

const StyledPrimaryAction = styled.a`
  ${props => buttonBase(props)}
  background-color: ${props => props.theme.colors.primary};
  color: ${props => props.theme.colors.textInverse};
  border: 1px solid ${props => props.theme.colors.primary};
  box-shadow: ${props => props.theme.shadows.md};

  &:hover {
    background-color: ${props => props.theme.colors.primaryHover};
    border-color: ${props => props.theme.colors.primaryHover};
  }
`;

const StyledSecondaryAction = styled(Link)`
  ${props => buttonBase(props)}
  background-color: ${props => props.theme.colors.background};
  color: ${props => props.theme.colors.text};
  border: 1px solid ${props => props.theme.colors.border};

  &:hover {
    border-color: ${props => props.theme.colors.primary};
    color: ${props => props.theme.colors.primary};
  }
`;

const StyledPlatforms = styled.div`
  margin-top: ${props => props.theme.spacing.lg};
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: ${props => props.theme.spacing.sm};
`;

const StyledPlatformsLabel = styled.p`
  margin: 0;
  color: ${props => props.theme.colors.textTertiary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  letter-spacing: 0.08em;
  text-transform: uppercase;
`;

const StyledPlatformList = styled.ul`
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: ${props => props.theme.spacing.sm};
`;

const StyledPlatform = styled.li`
  display: flex;
  align-items: center;
  gap: ${props => props.theme.spacing.sm};
  padding: ${props => props.theme.spacing.xs} ${props => props.theme.spacing.md};
  border: 1px solid ${props => props.theme.colors.border};
  border-radius: ${props => props.theme.borderRadius.full};
  background-color: ${props => props.theme.colors.background};
  color: ${props => props.theme.colors.primary};
  transition: border-color ${props => props.theme.transitions.fast};

  &:hover {
    border-color: ${props => props.theme.colors.primaryLight};
  }

  div {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    line-height: 1.25;
  }

  strong {
    color: ${props => props.theme.colors.text};
    font-size: ${props => props.theme.typography.fontSize.sm};
    font-weight: ${props => props.theme.typography.fontWeight.semibold};
  }

  span {
    color: ${props => props.theme.colors.textTertiary};
    font-size: ${props => props.theme.typography.fontSize.xs};
  }
`;

StyledHero.displayName = 'StyledHero';
StyledInner.displayName = 'StyledInner';
StyledLogo.displayName = 'StyledLogo';
StyledEyebrow.displayName = 'StyledEyebrow';
StyledTitle.displayName = 'StyledTitle';
StyledSubtitle.displayName = 'StyledSubtitle';
StyledActions.displayName = 'StyledActions';
StyledPrimaryAction.displayName = 'StyledPrimaryAction';
StyledSecondaryAction.displayName = 'StyledSecondaryAction';
StyledPlatforms.displayName = 'StyledPlatforms';
StyledPlatformsLabel.displayName = 'StyledPlatformsLabel';
StyledPlatformList.displayName = 'StyledPlatformList';
StyledPlatform.displayName = 'StyledPlatform';

export const MarketingHero = React.memo(({
  eyebrow,
  title,
  subtitle,
  appUrl,
  primaryLabel,
  secondaryLabel,
  secondaryHref,
  platforms = [],
  platformsLabel = 'Available on',
}) => {
  return (
    <StyledHero>
      <StyledInner>
        <StyledLogo>
          <Image
            src="/logos/icon-256.png"
            alt="HOSSPI"
            width={256}
            height={256}
            priority
          />
        </StyledLogo>

        {eyebrow && <StyledEyebrow>{eyebrow}</StyledEyebrow>}
        <StyledTitle>{title}</StyledTitle>
        <StyledSubtitle>{subtitle}</StyledSubtitle>

        <StyledActions>
          <StyledPrimaryAction href={appUrl} target="_blank" rel="noopener noreferrer">
            {primaryLabel}
            <Icon name="arrowRight" size={18} />
          </StyledPrimaryAction>
          <StyledSecondaryAction href={secondaryHref}>
            {secondaryLabel}
          </StyledSecondaryAction>
        </StyledActions>

        {platforms.length > 0 && (
          <StyledPlatforms>
            <StyledPlatformsLabel>{platformsLabel}</StyledPlatformsLabel>
            <StyledPlatformList>
              {platforms.map((platform) => (
                <StyledPlatform key={platform.id}>
                  <Icon name={platform.icon} size={18} />
                  <div>
                    <strong>{platform.name}</strong>
                    <span>{platform.detail}</span>
                  </div>
                </StyledPlatform>
              ))}
            </StyledPlatformList>
          </StyledPlatforms>
        )}
      </StyledInner>
    </StyledHero>
  );
});

MarketingHero.displayName = 'MarketingHero';
