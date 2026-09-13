/**
 * FeatureGrid - Value proposition cards
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, title: string, body: string}>} props.features
 * @returns {JSX.Element} Rendered feature grid
 * @file src/components/marketing/FeatureGrid.js
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
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 300px), 1fr));
  gap: clamp(1rem, 2vw, 1.75rem);
`;

const StyledItem = styled.li`
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.sm};
  padding: ${props => props.theme.spacing.lg};
  background-color: ${props => props.theme.colors.background};
  border: 1px solid ${props => props.theme.colors.border};
  border-radius: ${props => props.theme.borderRadius.lg};
  transition: border-color ${props => props.theme.transitions.fast},
              box-shadow ${props => props.theme.transitions.fast};

  &:hover {
    border-color: ${props => props.theme.colors.primaryLight};
    box-shadow: ${props => props.theme.shadows.md};
  }
`;

const StyledMarker = styled.span`
  width: 44px;
  height: 44px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.infoLight};
  color: ${props => props.theme.colors.primary};
  transition: background-color ${props => props.theme.transitions.fast},
              color ${props => props.theme.transitions.fast};

  li:hover & {
    background-color: ${props => props.theme.colors.primary};
    color: ${props => props.theme.colors.textInverse};
  }
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
`;

StyledGrid.displayName = 'StyledGrid';
StyledItem.displayName = 'StyledItem';
StyledMarker.displayName = 'StyledMarker';
StyledTitle.displayName = 'StyledTitle';
StyledBody.displayName = 'StyledBody';

export const FeatureGrid = React.memo(({ features = [] }) => {
  return (
    <StyledGrid>
      {features.map((feature) => (
        <StyledItem key={feature.id}>
          <StyledMarker>
            <Icon name={feature.icon} size={22} />
          </StyledMarker>
          <StyledTitle>{feature.title}</StyledTitle>
          <StyledBody>{feature.body}</StyledBody>
        </StyledItem>
      ))}
    </StyledGrid>
  );
});

FeatureGrid.displayName = 'FeatureGrid';
