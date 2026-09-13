/**
 * Button - Reusable button component with variants and sizes
 * 
 * @component
 * @param {Object} props
 * @param {string} props.variant - Button variant (primary, secondary, danger)
 * @param {string} props.size - Button size (sm, md, lg)
 * @param {boolean} props.disabled - Disabled state
 * @param {Function} props.onClick - Click handler
 * @param {React.ReactNode} props.children - Button content
 * @returns {JSX.Element} Rendered button
 * 
 * @example
 * <Button variant="primary" size="md" onClick={handleClick}>
 *   Click Me
 * </Button>
 */
'use client';

import React from 'react';
import styled from 'styled-components';

const StyledButton = styled.button`
  /* Base styles - mobile-first */
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-weight: ${props => props.theme.typography.fontWeight.medium};
  border-radius: ${props => props.theme.borderRadius.md};
  transition: all ${props => props.theme.transitions.normal};
  cursor: pointer;
  border: 2px solid transparent;
  white-space: nowrap;
  user-select: none;

  /* Size variants - mobile-first */
  ${props => props.$size === 'sm' && `
    padding: ${props.theme.spacing.sm} ${props.theme.spacing.md};
    font-size: ${props.theme.typography.fontSize.sm};
    min-height: 44px;
    min-width: 44px;
  `}

  ${props => props.$size === 'md' && `
    padding: ${props.theme.spacing.md} ${props.theme.spacing.lg};
    font-size: ${props.theme.typography.fontSize.md};
    min-height: 44px;
    min-width: 44px;
  `}

  ${props => props.$size === 'lg' && `
    padding: ${props.theme.spacing.md} ${props.theme.spacing.lg};
    font-size: ${props.theme.typography.fontSize.md};
    min-height: 44px;
    min-width: 44px;
  `}

  /* Responsive - enhance for larger screens */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    ${props => props.$size === 'lg' && `
      padding: ${props.theme.spacing.lg} ${props.theme.spacing.xl};
      font-size: ${props.theme.typography.fontSize.lg};
      min-height: 48px;
    `}
  }

  /* Variant styles */
  ${props => props.$variant === 'primary' && `
    background-color: ${props.theme.colors.primary};
    color: ${props.theme.colors.textInverse};

    &:hover:not(:disabled) {
      background-color: ${props.theme.colors.primaryHover};
      transform: translateY(-1px);
      box-shadow: ${props.theme.shadows.md};
    }

    &:active:not(:disabled) {
      transform: translateY(0);
      box-shadow: ${props.theme.shadows.sm};
    }
  `}

  ${props => props.$variant === 'secondary' && `
    background-color: ${props.theme.colors.secondary};
    color: ${props.theme.colors.textInverse};

    &:hover:not(:disabled) {
      background-color: ${props.theme.colors.secondaryHover};
      transform: translateY(-1px);
      box-shadow: ${props.theme.shadows.md};
    }

    &:active:not(:disabled) {
      transform: translateY(0);
      box-shadow: ${props.theme.shadows.sm};
    }
  `}

  ${props => props.$variant === 'danger' && `
    background-color: ${props.theme.colors.error};
    color: ${props.theme.colors.textInverse};

    &:hover:not(:disabled) {
      background-color: ${props.theme.colors.errorLight};
      transform: translateY(-1px);
      box-shadow: ${props.theme.shadows.md};
    }

    &:active:not(:disabled) {
      transform: translateY(0);
      box-shadow: ${props.theme.shadows.sm};
    }
  `}

  ${props => props.$variant === 'outline' && `
    background-color: transparent;
    color: ${props.theme.colors.primary};
    border-color: ${props.theme.colors.primary};

    &:hover:not(:disabled) {
      background-color: ${props.theme.colors.primary};
      color: ${props.theme.colors.textInverse};
    }
  `}

  ${props => props.$variant === 'ghost' && `
    background-color: transparent;
    color: ${props.theme.colors.text};

    &:hover:not(:disabled) {
      background-color: ${props.theme.colors.backgroundSecondary};
    }
  `}

  /* Disabled state */
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    transform: none !important;
  }

  /* Focus state */
  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
  }

`;

StyledButton.displayName = 'StyledButton';

export const Button = React.memo(({ 
  variant = 'primary', 
  size = 'md',
  disabled = false, 
  onClick, 
  children, 
  ...props 
}) => {
  return (
    <StyledButton
      $variant={variant}
      $size={size}
      disabled={disabled}
      onClick={onClick}
      aria-label={props['aria-label']}
      {...props}
    >
      {children}
    </StyledButton>
  );
});

Button.displayName = 'Button';

