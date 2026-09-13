/**
 * RoleGrid - Default roles shipped with the system
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, name: string, scope: string}>} props.roles
 * @param {string} [props.note] - Footnote shown under the grid
 * @returns {JSX.Element} Rendered role grid
 * @file src/components/marketing/RoleGrid.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';
import { Icon } from '@/components/ui';

const StyledGrid = styled.dl`
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: 1fr;
  gap: ${props => props.theme.spacing.md};

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    grid-template-columns: repeat(2, 1fr);
  }

  @media (min-width: ${props => props.theme.breakpoints.md}) {
    grid-template-columns: repeat(3, 1fr);
  }
`;

const StyledRole = styled.div`
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: start;
  gap: ${props => props.theme.spacing.md};
  padding: ${props => props.theme.spacing.md};
  border: 1px solid ${props => props.theme.colors.borderLight};
  border-radius: ${props => props.theme.borderRadius.lg};
  background-color: ${props => props.theme.colors.background};
  transition: border-color ${props => props.theme.transitions.fast};

  &:hover {
    border-color: ${props => props.theme.colors.primaryLight};
  }
`;

const StyledIconWrap = styled.span`
  grid-row: span 2;
  width: 40px;
  height: 40px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.backgroundSecondary};
  color: ${props => props.theme.colors.primary};
`;

const StyledName = styled.dt`
  color: ${props => props.theme.colors.text};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  margin-bottom: ${props => props.theme.spacing.xs};
`;

const StyledScope = styled.dd`
  margin: 0;
  color: ${props => props.theme.colors.textSecondary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
`;

const StyledNote = styled.p`
  margin: ${props => props.theme.spacing.lg} 0 0 0;
  color: ${props => props.theme.colors.textTertiary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
`;

StyledGrid.displayName = 'StyledGrid';
StyledRole.displayName = 'StyledRole';
StyledIconWrap.displayName = 'StyledIconWrap';
StyledName.displayName = 'StyledName';
StyledScope.displayName = 'StyledScope';
StyledNote.displayName = 'StyledNote';

export const RoleGrid = React.memo(({ roles = [], note }) => {
  return (
    <>
      <StyledGrid>
        {roles.map((role) => (
          <StyledRole key={role.id}>
            <StyledIconWrap>
              <Icon name={role.icon} size={20} />
            </StyledIconWrap>
            <StyledName>{role.name}</StyledName>
            <StyledScope>{role.scope}</StyledScope>
          </StyledRole>
        ))}
      </StyledGrid>
      {note && <StyledNote>{note}</StyledNote>}
    </>
  );
});

RoleGrid.displayName = 'RoleGrid';
