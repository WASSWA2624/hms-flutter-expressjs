/**
 * Section - Page section wrapper with an optional eyebrow, title and intro
 *
 * @component
 * @param {Object} props
 * @param {string} [props.id] - Anchor id for in-page links
 * @param {string} [props.eyebrow] - Small label above the title
 * @param {string} [props.title] - Section heading
 * @param {string} [props.description] - Intro paragraph
 * @param {'default'|'alt'} [props.tone] - Background treatment
 * @param {'left'|'center'} [props.align] - Header alignment
 * @param {'h1'|'h2'} [props.headingLevel] - Rendered element for the title
 * @param {React.ReactNode} props.children - Section body
 * @returns {JSX.Element} Rendered section
 * @file src/components/ui/Section.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';

const StyledSection = styled.section.withConfig({
  shouldForwardProp: (prop) => prop !== '$tone',
})`
  background-color: ${props => props.$tone === 'alt'
    ? props.theme.colors.backgroundSecondary
    : props.theme.colors.background};
  border-top: 1px solid ${props => props.$tone === 'alt'
    ? props.theme.colors.borderLight
    : 'transparent'};
  border-bottom: 1px solid ${props => props.$tone === 'alt'
    ? props.theme.colors.borderLight
    : 'transparent'};
  scroll-margin-top: 72px;
`;

const StyledInner = styled.div`
  max-width: ${props => props.theme.breakpoints.lg};
  margin: 0 auto;
  /* Fluid gutters and vertical rhythm - no breakpoint jumps */
  padding: clamp(2.5rem, 6vw, 5.5rem) clamp(1rem, 5vw, 4rem);
`;

const StyledHeader = styled.div.withConfig({
  shouldForwardProp: (prop) => prop !== '$align',
})`
  margin-bottom: clamp(1.75rem, 3.5vw, 3rem);
  text-align: ${props => props.$align === 'center' ? 'center' : 'left'};
  ${props => props.$align === 'center' && `
    margin-left: auto;
    margin-right: auto;
    max-width: 68ch;
  `}
`;

const StyledEyebrow = styled.p`
  margin: 0 0 ${props => props.theme.spacing.sm} 0;
  color: ${props => props.theme.colors.primary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  letter-spacing: 0.1em;
  text-transform: uppercase;
`;

const StyledTitle = styled.h2`
  margin: 0 0 ${props => props.theme.spacing.md} 0;
  color: ${props => props.theme.colors.text};
  font-size: clamp(1.5rem, 1rem + 2.2vw, 2.5rem);
  font-weight: ${props => props.theme.typography.fontWeight.bold};
  line-height: 1.15;
  letter-spacing: -0.02em;
  text-wrap: balance;
  max-width: 24ch;

  ${props => props.$centered && 'max-width: none;'}
`;

const StyledDescription = styled.p`
  margin: 0;
  color: ${props => props.theme.colors.textSecondary};
  font-size: clamp(1rem, 0.94rem + 0.3vw, 1.2rem);
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
  max-width: 68ch;
  text-wrap: pretty;
`;

StyledSection.displayName = 'StyledSection';
StyledInner.displayName = 'StyledInner';
StyledHeader.displayName = 'StyledHeader';
StyledEyebrow.displayName = 'StyledEyebrow';
StyledTitle.displayName = 'StyledTitle';
StyledDescription.displayName = 'StyledDescription';

export const Section = React.memo(({
  id,
  eyebrow,
  title,
  description,
  tone = 'default',
  align = 'left',
  headingLevel = 'h2',
  children,
}) => {
  const headingId = id ? `${id}-heading` : undefined;

  return (
    <StyledSection id={id} $tone={tone} aria-labelledby={headingId}>
      <StyledInner>
        {(eyebrow || title || description) && (
          <StyledHeader $align={align}>
            {eyebrow && <StyledEyebrow>{eyebrow}</StyledEyebrow>}
            {title && <StyledTitle as={headingLevel} id={headingId}>{title}</StyledTitle>}
            {description && <StyledDescription>{description}</StyledDescription>}
          </StyledHeader>
        )}
        {children}
      </StyledInner>
    </StyledSection>
  );
});

Section.displayName = 'Section';
