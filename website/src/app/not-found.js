/**
 * 404 Not Found Page
 * 
 * Custom 404 page for when routes are not found
 * @file src/app/not-found.js
 */
'use client';

import Link from 'next/link';
import styled from 'styled-components';
import { theme } from '@/styles/theme';
import { Button } from '@/components/ui';
import { APP_NAME } from '@/lib/constants';
import { useTranslation } from '@/hooks';

const StyledNotFound = styled.main`
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: ${props => props.theme.spacing.xl};
  text-align: center;
  background-color: ${props => props.theme.colors.background};
`;

const StyledTitle = styled.h1`
  font-size: ${props => props.theme.typography.fontSize['6xl']};
  font-weight: ${props => props.theme.typography.fontWeight.bold};
  color: ${props => props.theme.colors.text};
  margin: 0 0 ${props => props.theme.spacing.md} 0;
  line-height: ${props => props.theme.typography.lineHeight.tight};

  @media (max-width: ${props => props.theme.breakpoints.sm}) {
    font-size: ${props => props.theme.typography.fontSize['4xl']};
  }
`;

const StyledSubtitle = styled.p`
  font-size: ${props => props.theme.typography.fontSize.xl};
  color: ${props => props.theme.colors.textSecondary};
  margin: 0 0 ${props => props.theme.spacing.xl} 0;
  max-width: 600px;
`;

const StyledActions = styled.div`
  display: flex;
  gap: ${props => props.theme.spacing.md};
  flex-wrap: wrap;
  justify-content: center;
`;

const StyledLink = styled(Link)`
  text-decoration: none;
`;

StyledNotFound.displayName = 'StyledNotFound';
StyledTitle.displayName = 'StyledTitle';
StyledSubtitle.displayName = 'StyledSubtitle';
StyledActions.displayName = 'StyledActions';
StyledLink.displayName = 'StyledLink';

export default function NotFound() {
  const { t } = useTranslation('common');
  
  return (
    <StyledNotFound>
      <StyledTitle>404</StyledTitle>
      <StyledSubtitle>
        {t('pageNotFoundMessage')}
      </StyledSubtitle>
      <StyledActions>
        <StyledLink href="/">
          <Button variant="primary" size="lg">
            {t('goHome')}
          </Button>
        </StyledLink>
        <StyledLink href="/contact">
          <Button variant="outline" size="lg">
            {t('contactUs')}
          </Button>
        </StyledLink>
      </StyledActions>
    </StyledNotFound>
  );
}

