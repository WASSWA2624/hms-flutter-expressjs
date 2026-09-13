/**
 * Card - Reusable card component with variants
 * 
 * @component
 * @param {Object} props
 * @param {string} props.variant - Card variant (default, elevated, outlined)
 * @param {boolean} props.hover - Enable hover effects
 * @param {React.ReactNode} props.children - Card content
 * @returns {JSX.Element} Rendered card
 * 
 * @example
 * <Card variant="elevated" hover>
 *   <h3>Card Title</h3>
 *   <p>Card content</p>
 * </Card>
 */
'use client';

import React from 'react';
import styled from 'styled-components';

const StyledCard = styled.div.withConfig({
  shouldForwardProp: (prop) => prop !== 'variant' && prop !== 'hover',
})`
  /* Base styles - mobile-first */
  background-color: ${props => props.theme.colors.background};
  border-radius: ${props => props.theme.borderRadius.lg};
  padding: ${props => props.theme.spacing.md};
  transition: all ${props => props.theme.transitions.normal};

  /* Variant styles */
  ${props => props.$variant === 'elevated' && `
    box-shadow: ${props.theme.shadows.md};
  `}

  ${props => props.$variant === 'outlined' && `
    border: 1px solid ${props.theme.colors.border};
    box-shadow: none;
  `}

  ${props => props.$variant === 'flat' && `
    background-color: ${props.theme.colors.backgroundSecondary};
    box-shadow: none;
  `}

  /* Hover effects */
  ${props => props.$hover && `
    &:hover {
      transform: translateY(-2px);
      box-shadow: ${props.theme.shadows.lg};
    }
  `}

  /* Responsive - enhance for larger screens */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    padding: ${props => props.theme.spacing.lg};
  }
`;

StyledCard.displayName = 'StyledCard';

export const Card = React.memo(({ 
  variant = 'elevated', 
  hover = false,
  children, 
  ...props 
}) => {
  return (
    <StyledCard
      $variant={variant}
      $hover={hover}
      {...props}
    >
      {children}
    </StyledCard>
  );
});

Card.displayName = 'Card';

