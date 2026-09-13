/**
 * ChipList - Compact icon-led list of short labels
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, icon?: string, label: string}>} props.items
 * @returns {JSX.Element} Rendered chip list
 * @file src/components/marketing/ChipList.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';
import { Icon } from '@/components/ui';

const StyledList = styled.ul`
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-wrap: wrap;
  gap: ${props => props.theme.spacing.sm};
`;

const StyledItem = styled.li`
  display: inline-flex;
  align-items: center;
  gap: ${props => props.theme.spacing.sm};
  padding: ${props => props.theme.spacing.sm} ${props => props.theme.spacing.md};
  border: 1px solid ${props => props.theme.colors.border};
  border-radius: ${props => props.theme.borderRadius.full};
  background-color: ${props => props.theme.colors.background};
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.sm};

  svg {
    color: ${props => props.theme.colors.primary};
    flex-shrink: 0;
  }
`;

StyledList.displayName = 'StyledList';
StyledItem.displayName = 'StyledItem';

export const ChipList = React.memo(({ items = [] }) => {
  return (
    <StyledList>
      {items.map((item) => (
        <StyledItem key={item.id}>
          {item.icon && <Icon name={item.icon} size={17} />}
          {item.label}
        </StyledItem>
      ))}
    </StyledList>
  );
});

ChipList.displayName = 'ChipList';
