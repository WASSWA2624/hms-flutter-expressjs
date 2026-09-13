/**
 * RequestDemoButton - Opens the demo request dialog
 *
 * Three sizes so the same action can be the header's compact button, the
 * hero's primary call to action, and the closing one, without each caller
 * restyling a button.
 *
 * @component
 * @param {Object} props
 * @param {'sm'|'md'|'lg'} [props.size] - Visual weight
 * @param {'solid'|'outline'} [props.variant] - Fill treatment
 * @param {string} [props.children] - Label
 * @returns {JSX.Element} Rendered button
 * @file src/components/common/RequestDemoButton.js
 */
'use client';

import React from 'react';
import styled, { css } from 'styled-components';
import { Icon } from '@/components/ui';
import { useRequestDemo } from './RequestDemo';

const SIZES = {
  sm: css`
    min-height: 36px;
    padding: 0 ${props => props.theme.spacing.sm};
    font-size: ${props => props.theme.typography.fontSize.sm};

    @media (min-width: ${props => props.theme.breakpoints.sm}) {
      min-height: 40px;
      padding: 0 ${props => props.theme.spacing.md};
    }
  `,
  md: css`
    min-height: 44px;
    padding: 0 ${props => props.theme.spacing.lg};
    font-size: ${props => props.theme.typography.fontSize.md};
  `,
  lg: css`
    min-height: 52px;
    padding: 0 ${props => props.theme.spacing.xl};
    font-size: ${props => props.theme.typography.fontSize.md};
  `,
};

const StyledButton = styled.button.withConfig({
  shouldForwardProp: (prop) => prop !== '$size' && prop !== '$variant',
})`
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: ${props => props.theme.spacing.xs};
  flex-shrink: 0;
  white-space: nowrap;
  border-radius: ${props => props.theme.borderRadius.md};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  font-family: inherit;
  cursor: pointer;
  transition: background-color ${props => props.theme.transitions.fast},
              border-color ${props => props.theme.transitions.fast},
              color ${props => props.theme.transitions.fast},
              transform ${props => props.theme.transitions.fast},
              box-shadow ${props => props.theme.transitions.fast};

  ${props => SIZES[props.$size] || SIZES.md}

  ${props => props.$variant === 'outline'
    ? css`
        background-color: transparent;
        color: ${p => p.theme.colors.text};
        border: 1px solid ${p => p.theme.colors.border};

        &:hover {
          border-color: ${p => p.theme.colors.primary};
          color: ${p => p.theme.colors.primary};
        }
      `
    : css`
        background-color: ${p => p.theme.colors.primary};
        color: ${p => p.theme.colors.textInverse};
        border: 1px solid ${p => p.theme.colors.primary};
        box-shadow: ${p => p.theme.shadows.sm};

        &:hover {
          background-color: ${p => p.theme.colors.primaryHover};
          border-color: ${p => p.theme.colors.primaryHover};
          box-shadow: ${p => p.theme.shadows.md};
        }
      `}

  &:hover {
    transform: translateY(-1px);
  }

  &:active {
    transform: translateY(0);
  }

  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
  }

  @media (prefers-reduced-motion: reduce) {
    transition: none;

    &:hover,
    &:active {
      transform: none;
    }
  }
`;

/* Hidden on the narrowest screens in the header; the icon carries the meaning. */
const StyledLabel = styled.span`
  ${props => props.$hideOnMobile && `
    display: none;

    @media (min-width: 420px) {
      display: inline;
    }
  `}
`;

StyledButton.displayName = 'StyledRequestDemoButton';
StyledLabel.displayName = 'StyledRequestDemoLabel';

export const RequestDemoButton = React.memo(({
  size = 'md',
  variant = 'solid',
  hideLabelOnMobile = false,
  children = 'Request a demo',
}) => {
  const { open } = useRequestDemo();

  return (
    <StyledButton
      type="button"
      onClick={open}
      $size={size}
      $variant={variant}
      aria-haspopup="dialog"
      aria-label={children}
    >
      <StyledLabel $hideOnMobile={hideLabelOnMobile}>{children}</StyledLabel>
      <Icon name="sparkle" size={size === 'sm' ? 16 : 18} />
    </StyledButton>
  );
});

RequestDemoButton.displayName = 'RequestDemoButton';
