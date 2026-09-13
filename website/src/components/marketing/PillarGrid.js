/**
 * PillarGrid - Icon-led statements (mission, vision, values, principles)
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, icon: string, title: string, body: string}>} props.pillars
 * @param {'card'|'plain'} [props.variant] - Visual treatment
 * @returns {JSX.Element} Rendered pillar grid
 * @file src/components/marketing/PillarGrid.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';
import { Icon } from '@/components/ui';

const StyledGrid = styled.ul`
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 280px), 1fr));
  gap: clamp(1rem, 2vw, 1.75rem);
`;

const StyledItem = styled.li.withConfig({
  shouldForwardProp: (prop) => prop !== '$variant',
})`
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.sm};

  ${props => props.$variant === 'card' && `
    padding: ${props.theme.spacing.lg};
    background-color: ${props.theme.colors.background};
    border: 1px solid ${props.theme.colors.border};
    border-radius: ${props.theme.borderRadius.lg};
    transition: border-color ${props.theme.transitions.fast},
                box-shadow ${props.theme.transitions.fast};

    &:hover {
      border-color: ${props.theme.colors.primaryLight};
      box-shadow: ${props.theme.shadows.md};
    }
  `}
`;

const StyledIconWrap = styled.span`
  width: 46px;
  height: 46px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.infoLight};
  color: ${props => props.theme.colors.primary};
`;

const StyledTitle = styled.h3`
  margin: 0;
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.lg};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
`;

const StyledBody = styled.p`
  margin: 0;
  color: ${props => props.theme.colors.textSecondary};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
  text-wrap: pretty;
`;

StyledGrid.displayName = 'StyledGrid';
StyledItem.displayName = 'StyledItem';
StyledIconWrap.displayName = 'StyledIconWrap';
StyledTitle.displayName = 'StyledTitle';
StyledBody.displayName = 'StyledBody';

export const PillarGrid = React.memo(({ pillars = [], variant = 'card' }) => {
  return (
    <StyledGrid>
      {pillars.map((pillar) => (
        <StyledItem key={pillar.id} $variant={variant}>
          <StyledIconWrap>
            <Icon name={pillar.icon} size={23} />
          </StyledIconWrap>
          <StyledTitle>{pillar.title}</StyledTitle>
          <StyledBody>{pillar.body}</StyledBody>
        </StyledItem>
      ))}
    </StyledGrid>
  );
});

PillarGrid.displayName = 'PillarGrid';
