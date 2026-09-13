/**
 * Header - Main header component with logo and navigation
 * 
 * Layout component that persists across route navigation.
 * Fully responsive design optimized for all screen sizes (320px to 1920px+).
 * Includes logo, navigation menu, user menu, locale switcher, and theme toggle.
 * 
 * @component
 * @returns {React.ReactElement} Header component
 */
'use client';

import React from 'react';
import Link from 'next/link';
import Image from 'next/image';
import styled from 'styled-components';
import { Navigation } from './Navigation';
import { OpenAppButton } from './OpenAppButton';
import { ThemeToggle, LocaleSwitcher, RequestDemoButton } from '@/components/common';
import { useTranslation } from '@/hooks';
import { APP_NAME, APP_LOGIN_URL } from '@/lib/constants';

const StyledHeader = styled.header`
  background-color: ${props => props.theme.colors.background};
  border-bottom: 1px solid ${props => props.theme.colors.border};
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  width: 100%;
  z-index: ${props => props.theme.zIndex.sticky};
  transition: background-color ${props => props.theme.transitions.normal},
              border-color ${props => props.theme.transitions.normal};
  box-shadow: ${props => props.theme.shadows.sm};
`;

const StyledHeaderContainer = styled.div`
  /* Mobile-first base styles (320px+) */
  width: 100%;
  max-width: ${props => props.theme.breakpoints.lg};
  margin: 0 auto;
  padding: ${props => props.theme.spacing.xs} ${props => props.theme.spacing.sm};
  display: grid;
  grid-template-columns: auto 1fr auto;
  grid-template-areas: 'logo nav actions';
  align-items: center;
  gap: ${props => props.theme.spacing.xs};
  min-height: 44px;
  box-sizing: border-box;
  position: relative;

  /* Small mobile (360px+) */
  @media (min-width: 360px) {
    padding: ${props => props.theme.spacing.xs} ${props => props.theme.spacing.md};
    gap: ${props => props.theme.spacing.sm};
    min-height: 48px;
  }

  /* Tablet and up (768px+) */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    padding: ${props => props.theme.spacing.sm} ${props => props.theme.spacing.lg};
    gap: ${props => props.theme.spacing.md};
    min-height: 52px;
  }

  /* Desktop (1024px+) */
  @media (min-width: ${props => props.theme.breakpoints.md}) {
    padding: ${props => props.theme.spacing.sm} ${props => props.theme.spacing.xl};
    gap: ${props => props.theme.spacing.lg};
    min-height: 56px;
  }

  /* Large desktop (1440px+) */
  @media (min-width: ${props => props.theme.breakpoints.lg}) {
    padding: ${props => props.theme.spacing.md} ${props => props.theme.spacing.xxl};
    gap: ${props => props.theme.spacing.xl};
    min-height: 60px;
  }

  /* Extra large desktop (1920px+) */
  @media (min-width: ${props => props.theme.breakpoints.xl}) {
    padding: ${props => props.theme.spacing.md} ${props => props.theme.spacing.xxl};
    gap: ${props => props.theme.spacing.xl};
    min-height: 64px;
  }
`;

const StyledLogo = styled.div`
  grid-area: logo;
  display: flex;
  align-items: center;
  flex-shrink: 0;
  flex-grow: 0;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
  z-index: ${props => props.theme.zIndex.sticky};

  /* Ensure logo doesn't shrink too much on very small screens */
  @media (max-width: 360px) {
    min-width: 80px;
  }
`;

const StyledLogoImageContainer = styled.div`
  display: flex;
  align-items: center;
  flex-shrink: 0;
  overflow: hidden;
  height: clamp(24px, 4vw, 40px);
  width: auto;
  max-width: 100%;
  transition: transform ${props => props.theme.transitions.fast},
              filter ${props => props.theme.transitions.fast};

  img {
    height: 100%;
    width: auto;
    max-width: 100%;
    object-fit: contain;
    display: block;
    transition: transform ${props => props.theme.transitions.fast},
                filter ${props => props.theme.transitions.fast};
  }

  /* Small mobile (360px+) */
  @media (min-width: 360px) {
    height: clamp(28px, 3.5vw, 40px);
  }

  /* Tablet and up (768px+) */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    height: clamp(32px, 3vw, 40px);
  }

  /* Desktop (1024px+) */
  @media (min-width: ${props => props.theme.breakpoints.md}) {
    height: clamp(36px, 2.5vw, 40px);
  }

  /* Large desktop (1440px+) */
  @media (min-width: ${props => props.theme.breakpoints.lg}) {
    height: clamp(38px, 2vw, 40px);
  }
`;

const StyledLogoLink = styled(Link)`
  display: flex;
  align-items: center;
  gap: ${props => props.theme.spacing.xs};
  text-decoration: none;
  transition: all ${props => props.theme.transitions.fast};
  border-radius: ${props => props.theme.borderRadius.md};
  padding: 2px;
  min-width: 0;
  flex-shrink: 0;
  overflow: hidden;
  max-width: 100%;
  box-sizing: border-box;
  min-height: 40px;
  justify-content: flex-start;

  /* Small mobile (360px+) */
  @media (min-width: 360px) {
    gap: ${props => props.theme.spacing.xs};
    padding: ${props => props.theme.spacing.xs};
    min-height: 44px;
  }

  /* Tablet and up (768px+) */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    gap: ${props => props.theme.spacing.sm};
    padding: ${props => props.theme.spacing.xs};
  }

  /* Desktop (1024px+) */
  @media (min-width: ${props => props.theme.breakpoints.md}) {
    gap: ${props => props.theme.spacing.md};
    padding: ${props => props.theme.spacing.sm};
  }

  &:hover {
    text-decoration: none;
    transform: translateY(-1px);
    
    ${StyledLogoImageContainer} {
      transform: scale(1.05);
      filter: brightness(1.1);
    }
  }

  &:active {
    transform: translateY(0);
  }

  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
    border-radius: ${props => props.theme.borderRadius.sm};
  }
`;

/* Intentionally a span, not a heading: the page's own <h1> must win */
const StyledAppName = styled.span`
  display: none;
  flex-direction: column;
  line-height: 1.05;
  white-space: nowrap;
  min-width: 0;

  /* The name is short, so show it from small phones up */
  @media (min-width: 380px) {
    display: flex;
  }

  strong {
    color: ${props => props.theme.colors.primary};
    font-size: clamp(1rem, 0.9rem + 0.7vw, 1.35rem);
    font-weight: ${props => props.theme.typography.fontWeight.bold};
    letter-spacing: 0.01em;
    transition: color ${props => props.theme.transitions.fast};
  }

  span {
    color: ${props => props.theme.colors.textTertiary};
    font-size: clamp(0.6rem, 0.55rem + 0.2vw, 0.72rem);
    font-weight: ${props => props.theme.typography.fontWeight.semibold};
    letter-spacing: 0.14em;
    text-transform: uppercase;
  }

  ${StyledLogoLink}:hover & strong {
    color: ${props => props.theme.colors.primaryHover};
  }
`;

const StyledNavigationWrapper = styled.div`
  grid-area: nav;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 1;
  flex-grow: 1;
  min-width: 0;
  overflow: visible;
  position: relative;
  z-index: ${props => props.theme.zIndex.dropdown};

  /* Ensure navigation doesn't cause overflow on very small screens */
  @media (max-width: 360px) {
    min-width: 0;
    flex-basis: 0;
  }
`;

/*
 * Reading order across the bar is logo -> nav -> call to action -> utilities.
 * The call to action sits ahead of the locale and theme controls so it lands
 * at the end of the scan and stays adjacent to the navigation it follows from,
 * rather than being pushed to the far corner behind two icon buttons.
 */
const StyledHeaderActions = styled.div`
  grid-area: actions;
  display: flex;
  align-items: center;
  gap: ${props => props.theme.spacing.xs};
  flex-shrink: 0;
  flex-grow: 0;
  position: relative;
  z-index: ${props => props.theme.zIndex.dropdown};
  min-width: 0;
  overflow: visible;
  isolation: isolate;

  /* Small mobile (360px+) */
  @media (min-width: 360px) {
    gap: ${props => props.theme.spacing.sm};
  }

  /* Tablet and up (768px+) */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    gap: ${props => props.theme.spacing.md};
  }

  /* Very small screens - reduce gap */
  @media (max-width: 360px) {
    gap: 2px;
  }

  /* Ensure all action items are visible and properly sized */
  > * {
    flex-shrink: 0;
    flex-grow: 0;
    min-width: 0;
  }

  /* Prevent action items from overflowing on very small screens */
  @media (max-width: 360px) {
    flex-wrap: nowrap;
    justify-content: flex-end;
  }
`;

/*
 * The demo request is the conversion action, so it leads the actions cluster.
 * Held back until 768px: below that the bar already carries a logo, a menu
 * button, the app link and two utility controls, and the hero's copy of this
 * button is one scroll-free glance away.
 */
const StyledDemoAction = styled.div`
  display: none;

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    display: inline-flex;
  }
`;

/* Locale and theme read as one utility cluster, kept tighter than the gap
   separating them from the call to action. */
const StyledUtilityActions = styled.div`
  display: flex;
  align-items: center;
  gap: 2px;
  flex-shrink: 0;

  @media (min-width: 360px) {
    gap: ${props => props.theme.spacing.xs};
  }

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    gap: ${props => props.theme.spacing.sm};
  }
`;

StyledHeader.displayName = 'StyledHeader';
StyledHeaderContainer.displayName = 'StyledHeaderContainer';
StyledLogo.displayName = 'StyledLogo';
StyledLogoLink.displayName = 'StyledLogoLink';
StyledLogoImageContainer.displayName = 'StyledLogoImageContainer';
StyledAppName.displayName = 'StyledAppName';
StyledNavigationWrapper.displayName = 'StyledNavigationWrapper';
StyledHeaderActions.displayName = 'StyledHeaderActions';
StyledDemoAction.displayName = 'StyledDemoAction';
StyledUtilityActions.displayName = 'StyledUtilityActions';

export const Header = React.memo(() => {
  const { t: tNav } = useTranslation('navigation');

  return (
    <StyledHeader role="banner">
      <StyledHeaderContainer>
        <StyledLogo>
          <StyledLogoLink href="/" aria-label={`${APP_NAME} - ${tNav('nav.home') || 'Home'}`}>
            <StyledLogoImageContainer>
              <Image
                src="/logos/icon-64.png"
                alt={APP_NAME}
                width={64}
                height={64}
                priority
                style={{ width: 'auto', height: '100%' }}
              />
            </StyledLogoImageContainer>
            <StyledAppName>
              <strong>HOSSPI</strong>
              <span>Hospital Management</span>
            </StyledAppName>
          </StyledLogoLink>
        </StyledLogo>
        <StyledNavigationWrapper>
          <Navigation />
        </StyledNavigationWrapper>
        <StyledHeaderActions>
          <StyledDemoAction>
            <RequestDemoButton size="sm">
              {tNav('nav.requestDemo') || 'Request a demo'}
            </RequestDemoButton>
          </StyledDemoAction>
          <OpenAppButton href={APP_LOGIN_URL} label={tNav('nav.openApp') || 'Open the app'} />
          <StyledUtilityActions>
            <LocaleSwitcher />
            <ThemeToggle />
          </StyledUtilityActions>
        </StyledHeaderActions>
      </StyledHeaderContainer>
    </StyledHeader>
  );
});

Header.displayName = 'Header';
