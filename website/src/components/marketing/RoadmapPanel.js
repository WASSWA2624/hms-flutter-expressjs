/**
 * RoadmapPanel - Modules not yet available to users
 *
 * Keeps unreleased work visibly separate from what ships today.
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, title: string, status: string, items: string[]}>} props.groups
 * @returns {JSX.Element} Rendered roadmap panel
 * @file src/components/marketing/RoadmapPanel.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';

const StyledGrid = styled.div`
  display: grid;
  grid-template-columns: 1fr;
  gap: ${props => props.theme.spacing.lg};

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    grid-template-columns: repeat(2, 1fr);
  }
`;

const StyledGroup = styled.div`
  padding: ${props => props.theme.spacing.lg};
  border: 1px dashed ${props => props.theme.colors.borderDark};
  border-radius: ${props => props.theme.borderRadius.lg};
  background-color: ${props => props.theme.colors.background};
`;

const StyledHeader = styled.div`
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: ${props => props.theme.spacing.sm};
  margin-bottom: ${props => props.theme.spacing.md};
`;

const StyledTitle = styled.h3`
  margin: 0;
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.lg};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
`;

const StyledStatus = styled.span`
  padding: 2px ${props => props.theme.spacing.sm};
  border-radius: ${props => props.theme.borderRadius.full};
  background-color: ${props => props.theme.colors.warningLight};
  color: ${props => props.theme.colors.warning};
  font-size: ${props => props.theme.typography.fontSize.xs};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  white-space: nowrap;
`;

const StyledList = styled.ul`
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-wrap: wrap;
  gap: ${props => props.theme.spacing.xs};
`;

const StyledItem = styled.li`
  padding: ${props => props.theme.spacing.xs} ${props => props.theme.spacing.sm};
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.backgroundSecondary};
  color: ${props => props.theme.colors.textSecondary};
  font-size: ${props => props.theme.typography.fontSize.sm};
`;

StyledGrid.displayName = 'StyledGrid';
StyledGroup.displayName = 'StyledGroup';
StyledHeader.displayName = 'StyledHeader';
StyledTitle.displayName = 'StyledTitle';
StyledStatus.displayName = 'StyledStatus';
StyledList.displayName = 'StyledList';
StyledItem.displayName = 'StyledItem';

export const RoadmapPanel = React.memo(({ groups = [] }) => {
  return (
    <StyledGrid>
      {groups.map((group) => (
        <StyledGroup key={group.id}>
          <StyledHeader>
            <StyledTitle>{group.title}</StyledTitle>
            <StyledStatus>{group.status}</StyledStatus>
          </StyledHeader>
          <StyledList>
            {group.items.map((item) => (
              <StyledItem key={item}>{item}</StyledItem>
            ))}
          </StyledList>
        </StyledGroup>
      ))}
    </StyledGrid>
  );
});

RoadmapPanel.displayName = 'RoadmapPanel';
