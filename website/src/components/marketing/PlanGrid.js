/**
 * PlanGrid - Subscription package cards
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, name: string, summary: string, includes: string[], highlight?: boolean}>} props.plans
 * @param {string} [props.note] - Footnote shown under the grid
 * @param {string} [props.highlightLabel] - Badge text for the highlighted plan
 * @returns {JSX.Element} Rendered plan grid
 * @file src/components/marketing/PlanGrid.js
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
  /* Wraps naturally from one column up to five, no cramped middle sizes */
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr));
  gap: clamp(1rem, 1.6vw, 1.5rem);
  align-items: stretch;
`;

const StyledPlan = styled.li.withConfig({
  shouldForwardProp: (prop) => prop !== '$highlight',
})`
  position: relative;
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.sm};
  padding: ${props => props.theme.spacing.lg};
  background-color: ${props => props.theme.colors.background};
  border: 1px solid ${props => props.$highlight
    ? props.theme.colors.primary
    : props.theme.colors.border};
  border-width: ${props => props.$highlight ? '2px' : '1px'};
  border-radius: ${props => props.theme.borderRadius.lg};
  box-shadow: ${props => props.$highlight ? props.theme.shadows.lg : 'none'};
`;

const StyledBadge = styled.span`
  position: absolute;
  top: 0;
  left: ${props => props.theme.spacing.lg};
  transform: translateY(-50%);
  padding: 2px ${props => props.theme.spacing.sm};
  border-radius: ${props => props.theme.borderRadius.full};
  background-color: ${props => props.theme.colors.primary};
  color: ${props => props.theme.colors.textInverse};
  font-size: ${props => props.theme.typography.fontSize.xs};
  font-weight: ${props => props.theme.typography.fontWeight.bold};
  letter-spacing: 0.06em;
  text-transform: uppercase;
  white-space: nowrap;
`;

const StyledName = styled.h3`
  margin: 0;
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.xl};
  font-weight: ${props => props.theme.typography.fontWeight.bold};
`;

const StyledSummary = styled.p`
  margin: 0;
  color: ${props => props.theme.colors.textSecondary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
  min-height: 3em;
`;

const StyledIncludes = styled.ul`
  list-style: none;
  margin: ${props => props.theme.spacing.xs} 0 0 0;
  padding: ${props => props.theme.spacing.md} 0 0 0;
  border-top: 1px solid ${props => props.theme.colors.borderLight};
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.xs};
`;

const StyledInclude = styled.li`
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: start;
  gap: ${props => props.theme.spacing.sm};
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.normal};

  svg {
    margin-top: 2px;
    color: ${props => props.theme.colors.success};
    flex-shrink: 0;
  }
`;

const StyledNote = styled.p`
  margin: ${props => props.theme.spacing.lg} 0 0 0;
  color: ${props => props.theme.colors.textTertiary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
`;

StyledGrid.displayName = 'StyledGrid';
StyledPlan.displayName = 'StyledPlan';
StyledBadge.displayName = 'StyledBadge';
StyledName.displayName = 'StyledName';
StyledSummary.displayName = 'StyledSummary';
StyledIncludes.displayName = 'StyledIncludes';
StyledInclude.displayName = 'StyledInclude';
StyledNote.displayName = 'StyledNote';

export const PlanGrid = React.memo(({ plans = [], note, highlightLabel = 'Most complete' }) => {
  return (
    <>
      <StyledGrid>
        {plans.map((plan) => (
          <StyledPlan key={plan.id} $highlight={plan.highlight}>
            {plan.highlight && <StyledBadge>{highlightLabel}</StyledBadge>}
            <StyledName>{plan.name}</StyledName>
            <StyledSummary>{plan.summary}</StyledSummary>
            <StyledIncludes>
              {plan.includes.map((item) => (
                <StyledInclude key={item}>
                  <Icon name="check" size={15} />
                  <span>{item}</span>
                </StyledInclude>
              ))}
            </StyledIncludes>
          </StyledPlan>
        ))}
      </StyledGrid>
      {note && <StyledNote>{note}</StyledNote>}
    </>
  );
});

PlanGrid.displayName = 'PlanGrid';
