/**
 * PlatformGrid - The platforms the application runs on
 *
 * Replaces the pill strip that used to sit under the hero and the one-line
 * note on the guide. Each platform gets a card of its own, so the answer to
 * "will it run on what we already have?" is a glance rather than a sentence.
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, name: string, detail: string, icon: string}>} props.platforms
 * @param {string} [props.note] - Optional line under the grid
 * @returns {JSX.Element} Rendered platform grid
 * @file src/components/marketing/PlatformGrid.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';
import { Icon } from '@/components/ui';

/*
 * Five platforms across on a wide canvas, so the set reads as one row and the
 * count is obvious without counting. Two up on phones keeps the cards from
 * becoming letterbox strips.
 */
const StyledGrid = styled.ul`
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: clamp(0.75rem, 1.6vw, 1.25rem);

  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  @media (min-width: ${props => props.theme.breakpoints.md}) {
    grid-template-columns: repeat(5, minmax(0, 1fr));
  }
`;

const StyledItem = styled.li`
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: ${props => props.theme.spacing.sm};
  padding: clamp(1rem, 2.2vw, 1.6rem);
  border: 1px solid ${props => props.theme.colors.borderLight};
  border-radius: ${props => props.theme.borderRadius.lg};
  background-color: ${props => props.theme.colors.background};
  transition: border-color ${props => props.theme.transitions.fast},
              transform ${props => props.theme.transitions.fast},
              box-shadow ${props => props.theme.transitions.fast};

  /* A thin brand edge that fills in on hover - enough motion to feel alive,
     not enough to distract from the copy. */
  &::after {
    content: '';
    position: absolute;
    inset: auto 0 0 0;
    height: 2px;
    background-color: ${props => props.theme.colors.primary};
    transform: scaleX(0);
    transform-origin: left;
    transition: transform ${props => props.theme.transitions.normal};
  }

  &:hover {
    border-color: ${props => props.theme.colors.border};
    transform: translateY(-2px);
    box-shadow: ${props => props.theme.shadows.md};
  }

  &:hover::after {
    transform: scaleX(1);
  }

  @media (prefers-reduced-motion: reduce) {
    transition: none;

    &:hover {
      transform: none;
    }

    &::after {
      transition: none;
    }
  }
`;

const StyledIconWrap = styled.span`
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.infoLight};
  color: ${props => props.theme.colors.primary};
`;

const StyledName = styled.strong`
  display: block;
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.lg};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  letter-spacing: -0.01em;
  line-height: 1.2;
`;

const StyledDetail = styled.span`
  display: block;
  margin-top: 2px;
  color: ${props => props.theme.colors.textSecondary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.normal};
`;

const StyledNote = styled.p`
  margin: clamp(1.25rem, 2.5vw, 2rem) 0 0 0;
  color: ${props => props.theme.colors.textTertiary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
`;

StyledGrid.displayName = 'StyledPlatformGrid';
StyledItem.displayName = 'StyledPlatformItem';
StyledIconWrap.displayName = 'StyledPlatformIconWrap';
StyledName.displayName = 'StyledPlatformName';
StyledDetail.displayName = 'StyledPlatformDetail';
StyledNote.displayName = 'StyledPlatformNote';

export const PlatformGrid = React.memo(({ platforms = [], note }) => {
  return (
    <>
      <StyledGrid>
        {platforms.map((platform) => (
          <StyledItem key={platform.id}>
            <StyledIconWrap>
              <Icon name={platform.icon} size={22} />
            </StyledIconWrap>
            <span>
              <StyledName>{platform.name}</StyledName>
              <StyledDetail>{platform.detail}</StyledDetail>
            </span>
          </StyledItem>
        ))}
      </StyledGrid>
      {note && <StyledNote>{note}</StyledNote>}
    </>
  );
});

PlatformGrid.displayName = 'PlatformGrid';
