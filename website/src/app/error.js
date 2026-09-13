/**
 * Global Error Boundary
 * 
 * Global error boundary for the entire application
 * @file src/app/error.js
 */
'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import styled from 'styled-components';
import { Button } from '@/components/ui';
import { APP_NAME } from '@/lib/constants';
import { useTranslation } from '@/hooks';

const StyledError = styled.main`
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
  font-size: ${props => props.theme.typography.fontSize['4xl']};
  font-weight: ${props => props.theme.typography.fontWeight.bold};
  color: ${props => props.theme.colors.text};
  margin: 0 0 ${props => props.theme.spacing.md} 0;
  line-height: ${props => props.theme.typography.lineHeight.tight};

  @media (max-width: ${props => props.theme.breakpoints.sm}) {
    font-size: ${props => props.theme.typography.fontSize['3xl']};
  }
`;

const StyledMessage = styled.p`
  font-size: ${props => props.theme.typography.fontSize.lg};
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

StyledError.displayName = 'StyledError';
StyledTitle.displayName = 'StyledTitle';
StyledMessage.displayName = 'StyledMessage';
StyledActions.displayName = 'StyledActions';
StyledLink.displayName = 'StyledLink';

export default function GlobalError({ error, reset }) {
  const { t } = useTranslation('common');
  
  useEffect(() => {
    // Log error to error reporting service in production
    console.error('Global error:', error);
  }, [error]);

  return (
    <StyledError>
      <StyledTitle>{t('somethingWentWrong')}</StyledTitle>
      <StyledMessage>
        {t('errorMessage')}
      </StyledMessage>
      <StyledActions>
        <Button variant="primary" size="lg" onClick={reset}>
          {t('tryAgain')}
        </Button>
        <StyledLink href="/">
          <Button variant="outline" size="lg">
            {t('goHome')}
          </Button>
        </StyledLink>
      </StyledActions>
    </StyledError>
  );
}

