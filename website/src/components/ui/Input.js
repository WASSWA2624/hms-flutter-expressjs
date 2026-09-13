/**
 * Input - Reusable input component with variants and states
 * 
 * @component
 * @param {Object} props
 * @param {string} props.type - Input type (text, email, password, etc.)
 * @param {string} props.variant - Input variant (default, outlined)
 * @param {boolean} props.error - Error state
 * @param {string} props.size - Input size (sm, md, lg)
 * @param {string} props.value - Input value
 * @param {Function} props.onChange - Change handler
 * @param {string} props.placeholder - Placeholder text
 * @returns {JSX.Element} Rendered input
 * 
 * @example
 * <Input 
 *   type="email" 
 *   placeholder="Enter email"
 *   value={email}
 *   onChange={(e) => setEmail(e.target.value)}
 * />
 */
'use client';

import React from 'react';
import styled from 'styled-components';

const StyledInput = styled.input.withConfig({
  shouldForwardProp: (prop) => prop !== 'error' && prop !== 'variant' && prop !== 'size',
})`
  /* Base styles - mobile-first */
  width: 100%;
  font-family: ${props => props.theme.typography.fontFamily.sans};
  color: ${props => props.theme.colors.text};
  background-color: ${props => props.theme.colors.background};
  border: 2px solid ${props => props.$error ? props.theme.colors.error : props.theme.colors.border};
  border-radius: ${props => props.theme.borderRadius.md};
  transition: all ${props => props.theme.transitions.fast};
  outline: none;

  /* Size variants - mobile-first */
  ${props => props.$size === 'sm' && `
    padding: ${props.theme.spacing.sm} ${props.theme.spacing.md};
    font-size: ${props.theme.typography.fontSize.sm};
    min-height: 44px;
  `}

  ${props => props.$size === 'md' && `
    padding: ${props.theme.spacing.md};
    font-size: ${props.theme.typography.fontSize.md};
    min-height: 44px;
  `}

  ${props => props.$size === 'lg' && `
    padding: ${props.theme.spacing.md};
    font-size: ${props.theme.typography.fontSize.md};
    min-height: 44px;
  `}

  /* Responsive - enhance for larger screens */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    ${props => props.$size === 'lg' && `
      padding: ${props.theme.spacing.lg};
      font-size: ${props.theme.typography.fontSize.lg};
      min-height: 48px;
    `}
  }

  /* Variant styles */
  ${props => props.$variant === 'outlined' && `
    background-color: transparent;
    border-width: 2px;
  `}

  /* States */
  &:focus {
    border-color: ${props => props.$error ? props.theme.colors.error : props.theme.colors.primary};
    box-shadow: 0 0 0 3px ${props => props.$error 
      ? props.theme.colors.errorLight + '40' 
      : props.theme.colors.primaryLight + '40'};
  }

  &:hover:not(:disabled):not(:focus) {
    border-color: ${props => props.$error ? props.theme.colors.error : props.theme.colors.borderDark};
  }

  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    background-color: ${props => props.theme.colors.backgroundSecondary};
  }

  &::placeholder {
    color: ${props => props.theme.colors.textTertiary};
  }

  /* Error state */
  ${props => props.$error && `
    color: ${props.theme.colors.error};
  `}

`;

StyledInput.displayName = 'StyledInput';

export const Input = React.memo(({ 
  type = 'text',
  variant = 'default',
  error = false,
  size = 'md',
  value,
  onChange,
  placeholder,
  ...props 
}) => {
  return (
    <StyledInput
      type={type}
      $variant={variant}
      $error={error}
      $size={size}
      value={value}
      onChange={onChange}
      placeholder={placeholder}
      aria-label={props['aria-label']}
      {...props}
    />
  );
});

Input.displayName = 'Input';

