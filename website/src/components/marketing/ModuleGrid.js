/**
 * ModuleGrid - Grid of HOSSPI HMS core module groups
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, title: string, description: string, items: string[]}>} props.modules
 * @returns {JSX.Element} Rendered module grid
 * @file src/components/docs/ModuleGrid.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';
import { Card, Icon } from '@/components/ui';

const StyledGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 310px), 1fr));
  gap: clamp(1rem, 2vw, 1.75rem);
`;

const StyledCard = styled(Card)`
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.sm};
  border: 1px solid ${props => props.theme.colors.border};
  height: 100%;
`;

const StyledHeading = styled.div`
  display: flex;
  align-items: center;
  gap: ${props => props.theme.spacing.sm};
`;

const StyledIconWrap = styled.span`
  flex-shrink: 0;
  width: 40px;
  height: 40px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.infoLight};
  color: ${props => props.theme.colors.primary};
`;

const StyledTitle = styled.h3`
  font-size: ${props => props.theme.typography.fontSize.lg};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  color: ${props => props.theme.colors.text};
  margin: 0;
`;

const StyledDescription = styled.p`
  color: ${props => props.theme.colors.textSecondary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
  margin: 0;
`;

const StyledList = styled.ul`
  list-style: none;
  margin: ${props => props.theme.spacing.xs} 0 0 0;
  padding: 0;
  display: flex;
  flex-wrap: wrap;
  gap: ${props => props.theme.spacing.xs};
`;

const StyledItem = styled.li`
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.normal};
  background-color: ${props => props.theme.colors.backgroundSecondary};
  border-radius: ${props => props.theme.borderRadius.md};
  padding: ${props => props.theme.spacing.xs} ${props => props.theme.spacing.sm};
`;

StyledGrid.displayName = 'StyledGrid';
StyledCard.displayName = 'StyledModuleCard';
StyledHeading.displayName = 'StyledHeading';
StyledIconWrap.displayName = 'StyledIconWrap';
StyledTitle.displayName = 'StyledTitle';
StyledDescription.displayName = 'StyledDescription';
StyledList.displayName = 'StyledList';
StyledItem.displayName = 'StyledItem';

export const ModuleGrid = React.memo(({ modules = [] }) => {
  return (
    <StyledGrid>
      {modules.map((module) => (
        <StyledCard key={module.id} variant="default">
          <StyledHeading>
            <StyledIconWrap>
              <Icon name={module.icon} size={21} />
            </StyledIconWrap>
            <StyledTitle>{module.title}</StyledTitle>
          </StyledHeading>
          <StyledDescription>{module.description}</StyledDescription>
          <StyledList>
            {module.items.map((item) => (
              <StyledItem key={item}>{item}</StyledItem>
            ))}
          </StyledList>
        </StyledCard>
      ))}
    </StyledGrid>
  );
});

ModuleGrid.displayName = 'ModuleGrid';
