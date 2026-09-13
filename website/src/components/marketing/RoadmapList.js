/**
 * RoadmapList - Capabilities planned for future releases
 *
 * Presented plainly as upcoming so nothing here reads as available today.
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, title: string}>} props.items
 * @param {string} [props.note] - Footnote under the list
 * @returns {JSX.Element} Rendered roadmap list
 * @file src/components/marketing/RoadmapList.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';

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
  gap: ${props => props.theme.spacing.xs};
  padding: ${props => props.theme.spacing.sm} ${props => props.theme.spacing.md};
  border: 1px dashed ${props => props.theme.colors.borderDark};
  border-radius: ${props => props.theme.borderRadius.full};
  color: ${props => props.theme.colors.textSecondary};
  font-size: ${props => props.theme.typography.fontSize.sm};

  &::before {
    content: '';
    width: 6px;
    height: 6px;
    border-radius: ${props => props.theme.borderRadius.full};
    background-color: ${props => props.theme.colors.primaryLight};
    flex-shrink: 0;
  }
`;

const StyledNote = styled.p`
  margin: ${props => props.theme.spacing.lg} 0 0 0;
  color: ${props => props.theme.colors.textTertiary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
`;

StyledList.displayName = 'StyledList';
StyledItem.displayName = 'StyledItem';
StyledNote.displayName = 'StyledNote';

export const RoadmapList = React.memo(({ items = [], note }) => {
  return (
    <>
      <StyledList>
        {items.map((item) => (
          <StyledItem key={item.id}>{item.title}</StyledItem>
        ))}
      </StyledList>
      {note && <StyledNote>{note}</StyledNote>}
    </>
  );
});

RoadmapList.displayName = 'RoadmapList';
