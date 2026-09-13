/**
 * Footer - Minimal site footer
 *
 * A single bar with the copyright, the main navigation links, and a link to
 * the HOSSPI application. Layout component that persists across routes.
 *
 * @component
 * @returns {React.ReactElement} Footer component
 */
'use client';

import React from 'react';
import Link from 'next/link';
import styled from 'styled-components';
import { COMPANY_NAME, FOOTER_NAV_LINKS, APP_LOGIN_URL } from '@/lib/constants';
import { useTranslation } from '@/hooks';

const StyledFooter = styled.footer`
  background-color: ${props => props.theme.colors.background};
  border-top: 1px solid ${props => props.theme.colors.border};
  margin-top: ${props => props.theme.spacing.xxl};
  transition: background-color ${props => props.theme.transitions.normal},
              border-color ${props => props.theme.transitions.normal};
`;

const StyledFooterContainer = styled.div`
  max-width: ${props => props.theme.breakpoints.lg};
  margin: 0 auto;
  padding: ${props => props.theme.spacing.lg} ${props => props.theme.spacing.md};
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: ${props => props.theme.spacing.md};
  text-align: center;

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    flex-direction: row;
    justify-content: space-between;
    padding: ${props => props.theme.spacing.lg};
    text-align: left;
  }

  @media (min-width: ${props => props.theme.breakpoints.md}) {
    padding: ${props => props.theme.spacing.lg} ${props => props.theme.spacing.xl};
  }
`;

const StyledCopyright = styled.p`
  margin: 0;
  color: ${props => props.theme.colors.textTertiary};
  font-size: ${props => props.theme.typography.fontSize.sm};
`;

const StyledFooterNav = styled.nav`
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  justify-content: center;
  gap: ${props => props.theme.spacing.md};
`;

const linkStyles = props => `
  color: ${props.theme.colors.textSecondary};
  font-size: ${props.theme.typography.fontSize.sm};
  text-decoration: none;
  transition: color ${props.theme.transitions.fast};

  &:hover {
    color: ${props.theme.colors.primary};
    text-decoration: underline;
  }

  &:focus-visible {
    outline: 2px solid ${props.theme.colors.primary};
    outline-offset: 2px;
    border-radius: ${props.theme.borderRadius.sm};
  }
`;

const StyledFooterLink = styled(Link)`
  ${props => linkStyles(props)}
`;

const StyledAppLink = styled.a`
  ${props => linkStyles(props)}
  color: ${props => props.theme.colors.primary};
  font-weight: ${props => props.theme.typography.fontWeight.medium};
`;

StyledFooter.displayName = 'StyledFooter';
StyledFooterContainer.displayName = 'StyledFooterContainer';
StyledCopyright.displayName = 'StyledCopyright';
StyledFooterNav.displayName = 'StyledFooterNav';
StyledFooterLink.displayName = 'StyledFooterLink';
StyledAppLink.displayName = 'StyledAppLink';

export const Footer = React.memo(() => {
  const { t } = useTranslation('common');
  const { t: tNav } = useTranslation('navigation');
  const year = new Date().getFullYear();

  return (
    <StyledFooter role="contentinfo">
      <StyledFooterContainer>
        <StyledCopyright>
          {t('copyright', { year, company: COMPANY_NAME })}
        </StyledCopyright>

        <StyledFooterNav aria-label={tNav('nav.footerNavigation') || 'Footer navigation'}>
          {FOOTER_NAV_LINKS.map((link) => (
            <StyledFooterLink key={link.href} href={link.href}>
              {link.labelKey ? tNav(link.labelKey) : link.label}
            </StyledFooterLink>
          ))}
          <StyledAppLink
            href={APP_LOGIN_URL}
            target="_blank"
            rel="noopener noreferrer"
          >
            {t('openApp')}
          </StyledAppLink>
        </StyledFooterNav>
      </StyledFooterContainer>
    </StyledFooter>
  );
});

Footer.displayName = 'Footer';
