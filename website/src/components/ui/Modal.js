/**
 * Modal - Reusable modal component with overlay and close functionality
 * 
 * @component
 * @param {Object} props
 * @param {boolean} props.isOpen - Whether modal is open
 * @param {Function} props.onClose - Close handler
 * @param {string} props.title - Modal title
 * @param {React.ReactNode} props.children - Modal content
 * @returns {JSX.Element} Rendered modal
 * 
 * @example
 * <Modal isOpen={isOpen} onClose={() => setIsOpen(false)} title="Modal Title">
 *   <p>Modal content</p>
 * </Modal>
 */
'use client';

import React, { useEffect } from 'react';
import styled from 'styled-components';
import { useTranslation } from '@/hooks';

const StyledModalOverlay = styled.div.withConfig({
  shouldForwardProp: (prop) => prop !== 'isOpen',
})`
  /* Base styles - mobile-first */
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: ${props => props.theme.colors.overlay};
  backdrop-filter: blur(4px);
  -webkit-backdrop-filter: blur(4px);
  display: ${props => props.isOpen ? 'flex' : 'none'};
  align-items: center;
  justify-content: center;
  z-index: ${props => props.theme.zIndex.modalBackdrop};
  padding: ${props => props.theme.spacing.md};
  opacity: ${props => props.isOpen ? 1 : 0};
  animation: ${props => props.isOpen ? 'fadeIn' : 'fadeOut'} ${props => props.theme.transitions.normal} ease-out;
  transition: opacity ${props => props.theme.transitions.normal} ease-out;
  
  @keyframes fadeIn {
    from {
      opacity: 0;
      backdrop-filter: blur(0px);
      -webkit-backdrop-filter: blur(0px);
    }
    to {
      opacity: 1;
      backdrop-filter: blur(4px);
      -webkit-backdrop-filter: blur(4px);
    }
  }

  @keyframes fadeOut {
    from {
      opacity: 1;
      backdrop-filter: blur(4px);
      -webkit-backdrop-filter: blur(4px);
    }
    to {
      opacity: 0;
      backdrop-filter: blur(0px);
      -webkit-backdrop-filter: blur(0px);
    }
  }
`;

const StyledModalContent = styled.div.withConfig({
  shouldForwardProp: (prop) => prop !== 'isOpen',
})`
  /* Base styles - mobile-first */
  background-color: ${props => props.theme.colors.background};
  border-radius: ${props => props.theme.borderRadius.xl};
  box-shadow: ${props => props.theme.shadows.xl}, 0 0 0 1px ${props => props.theme.colors.borderLight};
  max-width: 95vw;
  max-height: 95vh;
  width: 100%;
  display: flex;
  flex-direction: column;
  z-index: ${props => props.theme.zIndex.modal};
  opacity: ${props => props.isOpen ? 1 : 0};
  transform: ${props => props.isOpen ? 'translateY(0) scale(1)' : 'translateY(20px) scale(0.95)'};
  animation: ${props => props.isOpen ? 'slideUp' : 'slideDown'} ${props => props.theme.transitions.normal} cubic-bezier(0.16, 1, 0.3, 1);
  transition: opacity ${props => props.theme.transitions.normal} cubic-bezier(0.16, 1, 0.3, 1),
              transform ${props => props.theme.transitions.normal} cubic-bezier(0.16, 1, 0.3, 1);
  overflow: hidden;

  @keyframes slideUp {
    from {
      transform: translateY(30px) scale(0.95);
      opacity: 0;
    }
    to {
      transform: translateY(0) scale(1);
      opacity: 1;
    }
  }

  @keyframes slideDown {
    from {
      transform: translateY(0) scale(1);
      opacity: 1;
    }
    to {
      transform: translateY(30px) scale(0.95);
      opacity: 0;
    }
  }

  /* Responsive - enhance for larger screens */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    max-width: 90vw;
    max-height: 90vh;
    border-radius: ${props => props.theme.borderRadius.xl};
  }

  @media (min-width: ${props => props.theme.breakpoints.md}) {
    max-width: 600px;
  }

  @media (min-width: ${props => props.theme.breakpoints.lg}) {
    max-width: 700px;
  }
`;

const StyledModalHeader = styled.div`
  /* Base styles - mobile-first */
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: ${props => props.theme.spacing.lg};
  border-bottom: 1px solid ${props => props.theme.colors.border};
  background-color: ${props => props.theme.colors.background};
  position: relative;

  /* Responsive - enhance for larger screens */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    padding: ${props => props.theme.spacing.xl};
  }
`;

const StyledModalTitle = styled.h2`
  /* Base styles - mobile-first */
  margin: 0;
  font-size: ${props => props.theme.typography.fontSize.xl};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  color: ${props => props.theme.colors.text};
  line-height: ${props => props.theme.typography.lineHeight.tight};
  letter-spacing: -0.01em;

  /* Responsive - enhance for larger screens */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    font-size: ${props => props.theme.typography.fontSize['2xl']};
  }
`;

const StyledCloseButton = styled.button.withConfig({
  shouldForwardProp: (prop) => prop !== 'absolute',
})`
  /* Base styles - mobile-first */
  background: ${props => props.theme.colors.backgroundSecondary};
  border: 1px solid ${props => props.theme.colors.border};
  font-size: ${props => props.theme.typography.fontSize['2xl']};
  color: ${props => props.theme.colors.textSecondary};
  cursor: pointer;
  padding: ${props => props.theme.spacing.sm};
  line-height: 1;
  border-radius: ${props => props.theme.borderRadius.md};
  transition: all ${props => props.theme.transitions.fast} cubic-bezier(0.4, 0, 0.2, 1);
  min-width: 44px;
  min-height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: ${props => props.theme.typography.fontWeight.medium};

  ${props => props.$absolute && `
    position: absolute;
    top: ${props.theme.spacing.lg};
    right: ${props.theme.spacing.lg};
    z-index: 1;
    box-shadow: ${props.theme.shadows.md};
  `}

  &:hover {
    background-color: ${props => props.theme.colors.backgroundTertiary};
    color: ${props => props.theme.colors.text};
    border-color: ${props => props.theme.colors.borderDark};
    transform: scale(1.05);
    box-shadow: ${props => props.theme.shadows.md};
  }

  &:active {
    transform: scale(0.95);
  }

  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
    box-shadow: 0 0 0 4px ${props => props.theme.colors.primary}20;
  }
`;

const StyledModalBody = styled.div`
  /* Base styles - mobile-first */
  padding: ${props => props.theme.spacing.lg};
  overflow-y: auto;
  flex: 1;
  background-color: ${props => props.theme.colors.background};
  
  /* Custom scrollbar styling */
  &::-webkit-scrollbar {
    width: 8px;
  }
  
  &::-webkit-scrollbar-track {
    background: ${props => props.theme.colors.backgroundSecondary};
  }
  
  &::-webkit-scrollbar-thumb {
    background: ${props => props.theme.colors.border};
    border-radius: ${props => props.theme.borderRadius.full};
  }
  
  &::-webkit-scrollbar-thumb:hover {
    background: ${props => props.theme.colors.borderDark};
  }

  /* Responsive - enhance for larger screens */
  @media (min-width: ${props => props.theme.breakpoints.sm}) {
    padding: ${props => props.theme.spacing.xl};
  }
`;

StyledModalOverlay.displayName = 'StyledModalOverlay';
StyledModalContent.displayName = 'StyledModalContent';
StyledModalHeader.displayName = 'StyledModalHeader';
StyledModalTitle.displayName = 'StyledModalTitle';
StyledCloseButton.displayName = 'StyledCloseButton';
StyledModalBody.displayName = 'StyledModalBody';

export const Modal = React.memo(({ isOpen, onClose, title, children, ...props }) => {
  const { t } = useTranslation('common');

  // Handle escape key
  useEffect(() => {
    const handleEscape = (e) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      // Prevent body scroll when modal is open
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = 'unset';
    };
  }, [isOpen, onClose]);

  // Focus trap (basic implementation)
  useEffect(() => {
    if (isOpen) {
      const modalContent = document.querySelector('[data-modal-content]');
      if (modalContent) {
        modalContent.focus();
      }
    }
  }, [isOpen]);

  const handleOverlayClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  if (!isOpen) return null;

  return (
    <StyledModalOverlay 
      isOpen={isOpen} 
      onClick={handleOverlayClick}
      aria-modal="true"
      role="dialog"
      aria-labelledby={title ? 'modal-title' : undefined}
    >
      <StyledModalContent 
        isOpen={isOpen}
        data-modal-content
        tabIndex={-1}
        {...props}
      >
        {title && (
          <StyledModalHeader>
            <StyledModalTitle id="modal-title">{title}</StyledModalTitle>
            <StyledCloseButton
              onClick={onClose}
              aria-label={t('closeModal')}
              type="button"
            >
              ×
            </StyledCloseButton>
          </StyledModalHeader>
        )}
        {!title && (
          <StyledCloseButton
            onClick={onClose}
            aria-label={t('closeModal')}
            type="button"
            $absolute
          >
            ×
          </StyledCloseButton>
        )}
        <StyledModalBody>{children}</StyledModalBody>
      </StyledModalContent>
    </StyledModalOverlay>
  );
});

Modal.displayName = 'Modal';

