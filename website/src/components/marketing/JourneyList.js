/**
 * JourneyList - How care moves through the system
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, title: string, summary: string}>} props.journeys
 * @returns {JSX.Element} Rendered journey list
 * @file src/components/marketing/JourneyList.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';
import { Icon } from '@/components/ui';

const StyledList = styled.ol`
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: 1fr;
  gap: ${props => props.theme.spacing.md};
  counter-reset: journey;

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    grid-template-columns: repeat(2, 1fr);
    gap: ${props => props.theme.spacing.lg};
  }
`;

const StyledItem = styled.li`
  counter-increment: journey;
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: start;
  gap: ${props => props.theme.spacing.md};
  padding: ${props => props.theme.spacing.lg};
  border-radius: ${props => props.theme.borderRadius.lg};
  background-color: ${props => props.theme.colors.background};
  border: 1px solid ${props => props.theme.colors.borderLight};
  transition: border-color ${props => props.theme.transitions.fast},
              box-shadow ${props => props.theme.transitions.fast};

  &:hover {
    border-color: ${props => props.theme.colors.borderDark};
    box-shadow: ${props => props.theme.shadows.sm};
  }

`;

const StyledStep = styled.span`
  position: relative;
  flex-shrink: 0;
  width: 44px;
  height: 44px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: ${props => props.theme.borderRadius.full};
  background-color: ${props => props.theme.colors.infoLight};
  color: ${props => props.theme.colors.primary};

  /* Step number sits on the badge so the sequence still reads at a glance */
  &::after {
    content: counter(journey);
    position: absolute;
    top: -4px;
    right: -4px;
    min-width: 18px;
    height: 18px;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0 4px;
    border-radius: ${props => props.theme.borderRadius.full};
    background-color: ${props => props.theme.colors.primary};
    color: ${props => props.theme.colors.textInverse};
    font-size: 10px;
    font-weight: ${props => props.theme.typography.fontWeight.bold};
    font-variant-numeric: tabular-nums;
    line-height: 1;
  }
`;

const StyledBody = styled.div`
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.xs};
`;

const StyledTitle = styled.h3`
  margin: 0;
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.lg};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
`;

const StyledSummary = styled.p`
  margin: 0;
  color: ${props => props.theme.colors.textSecondary};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
`;

StyledList.displayName = 'StyledList';
StyledItem.displayName = 'StyledItem';
StyledStep.displayName = 'StyledStep';
StyledBody.displayName = 'StyledBody';
StyledTitle.displayName = 'StyledTitle';
StyledSummary.displayName = 'StyledSummary';

export const JourneyList = React.memo(({ journeys = [] }) => {
  return (
    <StyledList>
      {journeys.map((journey) => (
        <StyledItem key={journey.id}>
          <StyledStep>
            <Icon name={journey.icon} size={21} />
          </StyledStep>
          <StyledBody>
            <StyledTitle>{journey.title}</StyledTitle>
            <StyledSummary>{journey.summary}</StyledSummary>
          </StyledBody>
        </StyledItem>
      ))}
    </StyledList>
  );
});

JourneyList.displayName = 'JourneyList';
