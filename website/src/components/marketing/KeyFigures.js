/**
 * KeyFigures - Headline numbers strip
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, value: string, label: string}>} props.figures
 * @returns {JSX.Element} Rendered figures strip
 * @file src/components/marketing/KeyFigures.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';
import { Icon } from '@/components/ui';

const StyledList = styled.dl`
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: ${props => props.theme.spacing.lg};

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    grid-template-columns: repeat(4, 1fr);
  }
`;

/*
 * Hairline rules between the figures, so the strip reads as one measured set
 * rather than four floating numbers. Drawn per item rather than as borders on
 * the grid, so the first item in each row never carries a leading rule.
 */
const StyledFigure = styled.div`
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: ${props => props.theme.spacing.xs};

  &:not(:nth-child(2n + 1))::before {
    content: '';
    position: absolute;
    left: calc(${props => props.theme.spacing.lg} / -2);
    top: 8%;
    bottom: 8%;
    width: 1px;
    background-color: ${props => props.theme.colors.borderLight};
  }

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    &:not(:nth-child(2n + 1))::before {
      content: none;
    }

    &:not(:first-child)::before {
      content: '';
      position: absolute;
      left: calc(${props => props.theme.spacing.lg} / -2);
      top: 8%;
      bottom: 8%;
      width: 1px;
      background-color: ${props => props.theme.colors.borderLight};
    }
  }
`;

const StyledIconWrap = styled.span`
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  margin-bottom: ${props => props.theme.spacing.xs};
  border-radius: ${props => props.theme.borderRadius.full};
  background-color: ${props => props.theme.colors.background};
  border: 1px solid ${props => props.theme.colors.border};
  color: ${props => props.theme.colors.primary};
`;

const StyledValue = styled.dt`
  color: ${props => props.theme.colors.primary};
  font-size: ${props => props.theme.typography.fontSize['3xl']};
  font-weight: ${props => props.theme.typography.fontWeight.bold};
  line-height: ${props => props.theme.typography.lineHeight.tight};
  /* Tabular figures so 26 and 25 sit on the same rhythm as 5 and 1. */
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.02em;

  @media (min-width: ${props => props.theme.breakpoints.md}) {
    font-size: ${props => props.theme.typography.fontSize['4xl']};
  }
`;

const StyledLabel = styled.dd`
  margin: 0;
  max-width: 18ch;
  color: ${props => props.theme.colors.textSecondary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.normal};
  text-wrap: balance;
`;

StyledList.displayName = 'StyledList';
StyledFigure.displayName = 'StyledFigure';
StyledIconWrap.displayName = 'StyledIconWrap';
StyledValue.displayName = 'StyledValue';
StyledLabel.displayName = 'StyledLabel';

export const KeyFigures = React.memo(({ figures = [] }) => {
  return (
    <StyledList>
      {figures.map((figure) => (
        <StyledFigure key={figure.id}>
          <StyledIconWrap>
            <Icon name={figure.icon} size={20} />
          </StyledIconWrap>
          <StyledValue>{figure.value}</StyledValue>
          <StyledLabel>{figure.label}</StyledLabel>
        </StyledFigure>
      ))}
    </StyledList>
  );
});

KeyFigures.displayName = 'KeyFigures';
