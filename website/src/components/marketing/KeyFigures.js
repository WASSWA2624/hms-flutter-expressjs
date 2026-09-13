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

const StyledFigure = styled.div`
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: ${props => props.theme.spacing.xs};
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

  @media (min-width: ${props => props.theme.breakpoints.md}) {
    font-size: ${props => props.theme.typography.fontSize['4xl']};
  }
`;

const StyledLabel = styled.dd`
  margin: 0;
  color: ${props => props.theme.colors.textSecondary};
  font-size: ${props => props.theme.typography.fontSize.sm};
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
