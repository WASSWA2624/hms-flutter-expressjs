/**
 * ContactChannels - Ways to reach the team
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, icon: string, title: string, description: string, value: string, href?: string, secondary?: {label: string, href: string}}>} props.channels
 * @returns {JSX.Element} Rendered channel grid
 * @file src/components/marketing/ContactChannels.js
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
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr));
  gap: clamp(1rem, 2vw, 1.5rem);
`;

const StyledItem = styled.li`
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.sm};
  padding: ${props => props.theme.spacing.lg};
  background-color: ${props => props.theme.colors.background};
  border: 1px solid ${props => props.theme.colors.border};
  border-radius: ${props => props.theme.borderRadius.lg};
  transition: border-color ${props => props.theme.transitions.fast},
              box-shadow ${props => props.theme.transitions.fast};

  &:hover {
    border-color: ${props => props.theme.colors.primaryLight};
    box-shadow: ${props => props.theme.shadows.sm};
  }
`;

const StyledIconWrap = styled.span`
  width: 42px;
  height: 42px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.infoLight};
  color: ${props => props.theme.colors.primary};
`;

const StyledTitle = styled.h3`
  margin: 0;
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.lg};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
`;

const StyledDescription = styled.p`
  margin: 0;
  color: ${props => props.theme.colors.textSecondary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
`;

const StyledValues = styled.div`
  margin-top: auto;
  padding-top: ${props => props.theme.spacing.sm};
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.xs};
  align-items: flex-start;
`;

const StyledValue = styled.a`
  color: ${props => props.theme.colors.primary};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  text-decoration: none;
  word-break: break-word;

  &:hover {
    text-decoration: underline;
  }

  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
    border-radius: ${props => props.theme.borderRadius.sm};
  }
`;

const StyledPlain = styled.p`
  margin: 0;
  color: ${props => props.theme.colors.text};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
`;

StyledGrid.displayName = 'StyledGrid';
StyledItem.displayName = 'StyledItem';
StyledIconWrap.displayName = 'StyledIconWrap';
StyledTitle.displayName = 'StyledTitle';
StyledDescription.displayName = 'StyledDescription';
StyledValues.displayName = 'StyledValues';
StyledValue.displayName = 'StyledValue';
StyledPlain.displayName = 'StyledPlain';

export const ContactChannels = React.memo(({ channels = [] }) => {
  return (
    <StyledGrid>
      {channels.map((channel) => (
        <StyledItem key={channel.id}>
          <StyledIconWrap>
            <Icon name={channel.icon} size={21} />
          </StyledIconWrap>
          <StyledTitle>{channel.title}</StyledTitle>
          <StyledDescription>{channel.description}</StyledDescription>
          <StyledValues>
            {channel.href ? (
              <StyledValue
                href={channel.href}
                {...(channel.external
                  ? { target: '_blank', rel: 'noopener noreferrer' }
                  : {})}
              >
                {channel.value}
              </StyledValue>
            ) : (
              <StyledPlain>{channel.value}</StyledPlain>
            )}
            {channel.secondary && (
              <StyledValue
                href={channel.secondary.href}
                target="_blank"
                rel="noopener noreferrer"
              >
                {channel.secondary.label}
              </StyledValue>
            )}
          </StyledValues>
        </StyledItem>
      ))}
    </StyledGrid>
  );
});

ContactChannels.displayName = 'ContactChannels';
