/**
 * RequestDemo - Two-field demo request, opened from any "Request a demo" button
 *
 * Asks for a phone number and an email address and nothing else. On submit it
 * posts to /api/demo, which emails the request to the team and - when the
 * WhatsApp Cloud API is configured - sends it over WhatsApp too. When it is
 * not, the browser opens a pre-filled wa.me message so the visitor delivers it
 * with one tap. Either way the request reaches both channels.
 *
 * Rendered once in the layout and driven by a context, so every button on the
 * page opens the same dialog rather than each carrying its own copy.
 *
 * @file src/components/common/RequestDemo.js
 */
'use client';

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
} from 'react';
import styled from 'styled-components';
import { Icon } from '@/components/ui';

const RequestDemoContext = createContext(null);

/**
 * Open the demo dialog from anywhere under the provider.
 *
 * @returns {{open: () => void}} Dialog controls
 */
export function useRequestDemo() {
  const context = useContext(RequestDemoContext);
  // A button rendered outside the provider should still be harmless.
  return context || { open: () => {} };
}

const StyledOverlay = styled.div`
  position: fixed;
  inset: 0;
  z-index: ${props => props.theme.zIndex.modal};
  display: flex;
  align-items: center;
  justify-content: center;
  padding: ${props => props.theme.spacing.md};
  background-color: rgba(4, 14, 28, 0.6);
  backdrop-filter: blur(4px);
  overscroll-behavior: contain;
`;

const StyledDialog = styled.div`
  width: min(100%, 440px);
  max-height: calc(100dvh - 2rem);
  overflow-y: auto;
  padding: clamp(1.5rem, 4vw, 2.25rem);
  border-radius: ${props => props.theme.borderRadius.xl};
  background-color: ${props => props.theme.colors.background};
  border: 1px solid ${props => props.theme.colors.border};
  box-shadow: ${props => props.theme.shadows.xl};
`;

const StyledDialogHead = styled.div`
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: ${props => props.theme.spacing.md};
  margin-bottom: ${props => props.theme.spacing.sm};
`;

const StyledTitle = styled.h2`
  margin: 0;
  color: ${props => props.theme.colors.text};
  font-size: clamp(1.25rem, 1.1rem + 0.6vw, 1.6rem);
  font-weight: ${props => props.theme.typography.fontWeight.bold};
  letter-spacing: -0.02em;
`;

const StyledClose = styled.button`
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  margin: -4px -4px 0 0;
  border: none;
  border-radius: ${props => props.theme.borderRadius.md};
  background: transparent;
  color: ${props => props.theme.colors.textTertiary};
  font-size: 1.35rem;
  line-height: 1;
  cursor: pointer;

  &:hover {
    background-color: ${props => props.theme.colors.backgroundSecondary};
    color: ${props => props.theme.colors.text};
  }

  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
  }
`;

const StyledLead = styled.p`
  margin: 0 0 ${props => props.theme.spacing.lg} 0;
  color: ${props => props.theme.colors.textSecondary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
`;

const StyledForm = styled.form`
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.md};
`;

const StyledField = styled.label`
  display: flex;
  flex-direction: column;
  gap: 6px;

  span {
    color: ${props => props.theme.colors.text};
    font-size: ${props => props.theme.typography.fontSize.sm};
    font-weight: ${props => props.theme.typography.fontWeight.semibold};
  }

  input {
    width: 100%;
    min-height: 48px;
    padding: 0 ${props => props.theme.spacing.md};
    border-radius: ${props => props.theme.borderRadius.md};
    border: 1px solid ${props => props.theme.colors.border};
    background-color: ${props => props.theme.colors.background};
    color: ${props => props.theme.colors.text};
    font-size: ${props => props.theme.typography.fontSize.md};
    font-family: inherit;

    &::placeholder {
      color: ${props => props.theme.colors.textTertiary};
    }

    &:focus-visible {
      outline: 2px solid ${props => props.theme.colors.primary};
      outline-offset: -1px;
      border-color: ${props => props.theme.colors.primary};
    }
  }
`;

const StyledSubmit = styled.button`
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: ${props => props.theme.spacing.xs};
  min-height: 50px;
  margin-top: ${props => props.theme.spacing.xs};
  border: 1px solid ${props => props.theme.colors.primary};
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.primary};
  color: ${props => props.theme.colors.textInverse};
  font-size: ${props => props.theme.typography.fontSize.md};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  font-family: inherit;
  cursor: pointer;
  transition: background-color ${props => props.theme.transitions.fast};

  &:hover:not(:disabled) {
    background-color: ${props => props.theme.colors.primaryHover};
  }

  &:disabled {
    opacity: 0.65;
    cursor: progress;
  }

  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
  }
`;

const StyledError = styled.p`
  margin: 0;
  padding: ${props => props.theme.spacing.sm} ${props => props.theme.spacing.md};
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.errorLight};
  color: ${props => props.theme.colors.error};
  font-size: ${props => props.theme.typography.fontSize.sm};
`;

const StyledDoneAction = styled.button`
  align-self: stretch;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 46px;
  margin-top: ${props => props.theme.spacing.xs};
  padding: 0 ${props => props.theme.spacing.xl};
  border: 1px solid ${props => props.theme.colors.border};
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: transparent;
  color: ${props => props.theme.colors.text};
  font-size: ${props => props.theme.typography.fontSize.md};
  font-weight: ${props => props.theme.typography.fontWeight.semibold};
  font-family: inherit;
  cursor: pointer;
  transition: border-color ${props => props.theme.transitions.fast},
              color ${props => props.theme.transitions.fast};

  &:hover {
    border-color: ${props => props.theme.colors.primary};
    color: ${props => props.theme.colors.primary};
  }

  &:focus-visible {
    outline: 2px solid ${props => props.theme.colors.primary};
    outline-offset: 2px;
  }
`;

/* The WhatsApp follow-up, shown only when a window actually opened. */
const StyledFollowUp = styled.p`
  margin: 0;
  padding: ${props => props.theme.spacing.sm} ${props => props.theme.spacing.md};
  border-radius: ${props => props.theme.borderRadius.md};
  background-color: ${props => props.theme.colors.backgroundSecondary};
  color: ${props => props.theme.colors.textSecondary};
  font-size: ${props => props.theme.typography.fontSize.sm};
  line-height: ${props => props.theme.typography.lineHeight.relaxed};
`;

const StyledDone = styled.div`
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: ${props => props.theme.spacing.md};
  text-align: center;

  p {
    margin: 0;
    color: ${props => props.theme.colors.textSecondary};
    line-height: ${props => props.theme.typography.lineHeight.relaxed};
  }
`;

const StyledDoneMark = styled.span`
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 56px;
  height: 56px;
  border-radius: ${props => props.theme.borderRadius.full};
  background-color: ${props => props.theme.colors.infoLight};
  color: ${props => props.theme.colors.primary};
`;

StyledOverlay.displayName = 'StyledOverlay';
StyledDialog.displayName = 'StyledDialog';
StyledDialogHead.displayName = 'StyledDialogHead';
StyledTitle.displayName = 'StyledTitle';
StyledClose.displayName = 'StyledClose';
StyledLead.displayName = 'StyledLead';
StyledForm.displayName = 'StyledForm';
StyledField.displayName = 'StyledField';
StyledSubmit.displayName = 'StyledSubmit';
StyledError.displayName = 'StyledError';
StyledDoneAction.displayName = 'StyledDoneAction';
StyledFollowUp.displayName = 'StyledFollowUp';
StyledDone.displayName = 'StyledDone';
StyledDoneMark.displayName = 'StyledDoneMark';

export function RequestDemoProvider({ children }) {
  const [isOpen, setIsOpen] = useState(false);
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState('idle'); // idle | sending | done
  const [error, setError] = useState('');
  const [whatsappOpened, setWhatsappOpened] = useState(false);
  const dialogRef = useRef(null);
  const firstFieldRef = useRef(null);
  const titleId = useId();

  const open = useCallback(() => {
    setError('');
    setStatus('idle');
    setWhatsappOpened(false);
    setIsOpen(true);
  }, []);

  const close = useCallback(() => setIsOpen(false), []);

  // Escape closes; focus moves into the dialog; the page behind stops scrolling.
  useEffect(() => {
    if (!isOpen) return undefined;

    const onKeyDown = (event) => {
      if (event.key === 'Escape') close();
    };
    document.addEventListener('keydown', onKeyDown);

    const previouslyFocused = document.activeElement;
    firstFieldRef.current?.focus();

    const { overflow } = document.body.style;
    document.body.style.overflow = 'hidden';

    return () => {
      document.removeEventListener('keydown', onKeyDown);
      document.body.style.overflow = overflow;
      if (previouslyFocused instanceof HTMLElement) previouslyFocused.focus();
    };
  }, [isOpen, close]);

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError('');
    setStatus('sending');

    try {
      const response = await fetch('/api/demo', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, email }),
      });
      const data = await response.json().catch(() => ({}));

      if (!response.ok) {
        setError(data?.error || 'Something went wrong. Please try again.');
        setStatus('idle');
        return;
      }

      // The email is already sent. If the server could not deliver the
      // WhatsApp message itself, hand the visitor a pre-filled one - opened
      // from inside the submit handler so it counts as a user gesture and is
      // not treated as a pop-up.
      if (!data?.whatsappSent && data?.whatsappUrl) {
        const opened = window.open(data.whatsappUrl, '_blank', 'noopener,noreferrer');
        // A blocked pop-up returns null; do not promise a tab that is not there.
        setWhatsappOpened(opened !== null);
      }

      setStatus('done');
      setPhone('');
      setEmail('');
    } catch {
      setError('Could not reach the server. Please try again.');
      setStatus('idle');
    }
  };

  const value = useMemo(() => ({ open }), [open]);

  return (
    <RequestDemoContext.Provider value={value}>
      {children}

      {isOpen && (
        <StyledOverlay
          role="presentation"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) close();
          }}
        >
          <StyledDialog
            ref={dialogRef}
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
          >
            <StyledDialogHead>
              <StyledTitle id={titleId}>
                {status === 'done' ? 'Request sent' : 'Request a demo'}
              </StyledTitle>
              <StyledClose type="button" onClick={close} aria-label="Close">
                ×
              </StyledClose>
            </StyledDialogHead>

            {status === 'done' ? (
              <StyledDone>
                <StyledDoneMark>
                  <Icon name="check" size={26} />
                </StyledDoneMark>
                <p>
                  Your request is with our team. We will be in touch within one
                  working day.
                </p>
                {whatsappOpened && (
                  <StyledFollowUp>
                    A WhatsApp message is waiting in the tab that just opened.
                    Press send there and we can reply straight away.
                  </StyledFollowUp>
                )}
                <StyledDoneAction type="button" onClick={close}>
                  Close
                </StyledDoneAction>
              </StyledDone>
            ) : (
              <>
                <StyledLead>
                  Two details and we will get back to you. No form to fill in, no
                  account needed.
                </StyledLead>

                <StyledForm onSubmit={handleSubmit} noValidate>
                  {error && <StyledError role="alert">{error}</StyledError>}

                  <StyledField>
                    <span>Phone number</span>
                    <input
                      ref={firstFieldRef}
                      type="tel"
                      name="phone"
                      inputMode="tel"
                      autoComplete="tel"
                      placeholder="+256 700 000000"
                      required
                      value={phone}
                      onChange={(event) => setPhone(event.target.value)}
                    />
                  </StyledField>

                  <StyledField>
                    <span>Email address</span>
                    <input
                      type="email"
                      name="email"
                      inputMode="email"
                      autoComplete="email"
                      placeholder="you@hospital.org"
                      required
                      value={email}
                      onChange={(event) => setEmail(event.target.value)}
                    />
                  </StyledField>

                  <StyledSubmit type="submit" disabled={status === 'sending'}>
                    {status === 'sending' ? 'Sending…' : 'Send request'}
                    {status !== 'sending' && <Icon name="arrowRight" size={18} />}
                  </StyledSubmit>

                </StyledForm>
              </>
            )}
          </StyledDialog>
        </StyledOverlay>
      )}
    </RequestDemoContext.Provider>
  );
}

RequestDemoProvider.displayName = 'RequestDemoProvider';
