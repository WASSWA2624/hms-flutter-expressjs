/**
 * FaqList - Common questions, expandable
 *
 * Uses native details/summary so it works without JavaScript and stays
 * accessible to screen readers and keyboard users.
 *
 * @component
 * @param {Object} props
 * @param {Array<{id: string, question: string, answer: string}>} props.faqs
 * @returns {JSX.Element} Rendered FAQ list
 * @file src/components/marketing/FaqList.js
 */
'use client';

import React from 'react';
import styled from 'styled-components';

const StyledList = styled.div`
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.sm};
  max-width: 80ch;
`;

const StyledItem = styled.details`
  border: 1px solid ${props => props.theme.colors.border};
  border-radius: ${props => props.theme.borderRadius.lg};
  background-color: ${props => props.theme.colors.background};
  overflow: hidden;
  transition: border-color ${props => props.theme.transitions.fast};

  &[open] {
    border-color: ${props => props.theme.colors.primaryLight};
  }

  &:hover {
    border-color: ${props => props.theme.colors.borderDark};
  }
`;

const StyledQuestion = styled.summary`
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: ${props => props.theme.spacing.md};
  padding: ${props => props.theme.spacing.md} ${props => props.theme.spacing.lg};
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.md};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  cursor: pointer;
  list-style: none;
  min-height: 56px;

  &::-webkit-details-marker {
    display: none;
  }

  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: -2px;
  }

  &::after {
    content: '+';
    flex-shrink: 0;
    color: ${props => props.theme.colors.primary};
    font-size: ${props => props.theme.typography.fontSize.xl};
    font-weight: ${props => props.theme.typography.fontWeight.normal};
    line-height: 1;
  }

  details[open] &::after {
    content: '−';
  }
`;

const StyledAnswer = styled.p`
  margin: 0;
  padding: 0 ${props => props.theme.spacing.lg} ${props => props.theme.spacing.lg};
  color: ${props => props.theme.colors.textSecondary};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
  max-width: 70ch;
`;

StyledList.displayName = 'StyledList';
StyledItem.displayName = 'StyledItem';
StyledQuestion.displayName = 'StyledQuestion';
StyledAnswer.displayName = 'StyledAnswer';

export const FaqList = React.memo(({ faqs = [] }) => {
  return (
    <StyledList>
      {faqs.map((faq) => (
        <StyledItem key={faq.id} name="faq">
          <StyledQuestion>{faq.question}</StyledQuestion>
          <StyledAnswer>{faq.answer}</StyledAnswer>
        </StyledItem>
      ))}
    </StyledList>
  );
});

FaqList.displayName = 'FaqList';
