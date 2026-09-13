/**
 * ContactForm - Contact form component with validation
 * 
 * @component
 * @returns {JSX.Element} Rendered contact form
 * @file src/components/common/ContactForm.js
 */
'use client';

import React, { useState } from 'react';
import styled from 'styled-components';
import { Card } from '@/components/ui';
import { Input } from '@/components/ui';
import { Button } from '@/components/ui';
import { useTranslation } from '@/hooks';

const StyledForm = styled.form`
  max-width: 600px;
  margin: 0 auto;
`;

const StyledCard = styled(Card)`
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.lg};
`;

const StyledFormGroup = styled.div`
  display: flex;
  flex-direction: column;
  gap: ${props => props.theme.spacing.sm};
`;

const StyledLabel = styled.label`
  font-size: ${props => props.theme.typography.fontSize.md};
  font-weight: ${props => props.theme.typography.fontWeight.medium};
  color: ${props => props.theme.colors.text};
`;

const StyledTextarea = styled.textarea`
  width: 100%;
  font-family: ${props => props.theme.typography.fontFamily.sans};
  color: ${props => props.theme.colors.text};
  background-color: ${props => props.theme.colors.background};
  border: 2px solid ${props => props.$error ? props.theme.colors.error : props.theme.colors.border};
  border-radius: ${props => props.theme.borderRadius.md};
  padding: ${props => props.theme.spacing.md};
  font-size: ${props => props.theme.typography.fontSize.md};
  min-height: 120px;
  resize: vertical;
  transition: all ${props => props.theme.transitions.fast};
  outline: none;

  &:focus {
    border-color: ${props => props.$error ? props.theme.colors.error : props.theme.colors.primary};
    box-shadow: 0 0 0 3px ${props => props.$error 
      ? props.theme.colors.errorLight + '40' 
      : props.theme.colors.primaryLight + '40'};
  }

  &:hover:not(:disabled):not(:focus) {
    border-color: ${props => props.$error ? props.theme.colors.error : props.theme.colors.borderDark};
  }

  &::placeholder {
    color: ${props => props.theme.colors.textTertiary};
  }

  ${props => props.$error && `
    color: ${props.theme.colors.error};
  `}
`;

const StyledError = styled.span`
  color: ${props => props.theme.colors.error};
  font-size: ${props => props.theme.typography.fontSize.sm};
  margin-top: ${props => props.theme.spacing.xs};
`;

const StyledSuccess = styled.div`
  background-color: ${props => props.theme.colors.successLight};
  color: ${props => props.theme.colors.success};
  padding: ${props => props.theme.spacing.md};
  border-radius: ${props => props.theme.borderRadius.md};
  text-align: center;
  font-weight: ${props => props.theme.typography.fontWeight.medium};
`;

const StyledErrorMsg = styled.div`
  background-color: ${props => props.theme.colors.errorLight};
  color: ${props => props.theme.colors.error};
  padding: ${props => props.theme.spacing.md};
  border-radius: ${props => props.theme.borderRadius.md};
  text-align: center;
  font-weight: ${props => props.theme.typography.fontWeight.medium};
`;

const StyledButtonWrapper = styled.div`
  display: flex;
  justify-content: flex-end;
  margin-top: ${props => props.theme.spacing.md};
`;

StyledForm.displayName = 'StyledForm';
StyledCard.displayName = 'StyledCard';
StyledFormGroup.displayName = 'StyledFormGroup';
StyledLabel.displayName = 'StyledLabel';
StyledTextarea.displayName = 'StyledTextarea';
StyledError.displayName = 'StyledError';
StyledSuccess.displayName = 'StyledSuccess';
StyledErrorMsg.displayName = 'StyledErrorMsg';
StyledButtonWrapper.displayName = 'StyledButtonWrapper';

export const ContactForm = React.memo(() => {
  const { t } = useTranslation('contact');
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    message: '',
  });
  const [errors, setErrors] = useState({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitStatus, setSubmitStatus] = useState(null);

  const validateEmail = (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const validateForm = () => {
    const newErrors = {};

    if (!formData.name.trim()) {
      newErrors.name = t('required') || 'Name is required';
    }

    if (!formData.email.trim()) {
      newErrors.email = t('required') || 'Email is required';
    } else if (!validateEmail(formData.email)) {
      newErrors.email = t('invalidEmail');
    }

    if (!formData.message.trim()) {
      newErrors.message = t('required') || 'Message is required';
    } else if (formData.message.trim().length < 10) {
      newErrors.message = t('messageTooShort') || 'Message must be at least 10 characters long';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value,
    }));
    // Clear error for this field when user starts typing
    if (errors[name]) {
      setErrors(prev => ({
        ...prev,
        [name]: '',
      }));
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitStatus(null);

    if (!validateForm()) {
      return;
    }

    setIsSubmitting(true);

    try {
      const response = await fetch('/api/contact', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(formData),
      });

      const data = await response.json();

      if (response.ok) {
        setSubmitStatus('success');
        setFormData({ name: '', email: '', message: '' });
        setErrors({});
        // Clear success message after 5 seconds
        setTimeout(() => setSubmitStatus(null), 5000);
      } else {
        setSubmitStatus('error');
        setErrors({ submit: data.error || t('error') });
      }
    } catch (error) {
      console.error('Error submitting form:', error);
      setSubmitStatus('error');
      setErrors({ submit: t('networkError') || 'Network error. Please try again later.' });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <StyledForm onSubmit={handleSubmit} noValidate>
      <StyledCard variant="elevated">
        {submitStatus === 'success' && (
          <StyledSuccess>
            {t('success')}
          </StyledSuccess>
        )}

        {submitStatus === 'error' && errors.submit && (
          <StyledErrorMsg>{errors.submit}</StyledErrorMsg>
        )}

        <StyledFormGroup>
          <StyledLabel htmlFor="name">
            {t('name')} <span aria-label="required">*</span>
          </StyledLabel>
          <Input
            type="text"
            id="name"
            name="name"
            value={formData.name}
            onChange={handleChange}
            placeholder={t('namePlaceholder') || 'Your name'}
            error={!!errors.name}
            aria-required="true"
            aria-invalid={!!errors.name}
            aria-describedby={errors.name ? 'name-error' : undefined}
          />
          {errors.name && (
            <StyledError id="name-error" role="alert">
              {errors.name}
            </StyledError>
          )}
        </StyledFormGroup>

        <StyledFormGroup>
          <StyledLabel htmlFor="email">
            {t('email')} <span aria-label="required">*</span>
          </StyledLabel>
          <Input
            type="email"
            id="email"
            name="email"
            value={formData.email}
            onChange={handleChange}
            placeholder={t('emailPlaceholder') || 'your.email@example.com'}
            error={!!errors.email}
            aria-required="true"
            aria-invalid={!!errors.email}
            aria-describedby={errors.email ? 'email-error' : undefined}
          />
          {errors.email && (
            <StyledError id="email-error" role="alert">
              {errors.email}
            </StyledError>
          )}
        </StyledFormGroup>

        <StyledFormGroup>
          <StyledLabel htmlFor="message">
            {t('message')} <span aria-label="required">*</span>
          </StyledLabel>
          <StyledTextarea
            id="message"
            name="message"
            value={formData.message}
            onChange={handleChange}
            placeholder={t('messagePlaceholder') || 'Your message...'}
            $error={!!errors.message}
            aria-required="true"
            aria-invalid={!!errors.message}
            aria-describedby={errors.message ? 'message-error' : undefined}
          />
          {errors.message && (
            <StyledError id="message-error" role="alert">
              {errors.message}
            </StyledError>
          )}
        </StyledFormGroup>

        <StyledButtonWrapper>
          <Button
            type="submit"
            variant="primary"
            size="lg"
            disabled={isSubmitting}
          >
            {isSubmitting ? t('sending') : t('send')}
          </Button>
        </StyledButtonWrapper>
      </StyledCard>
    </StyledForm>
  );
});

ContactForm.displayName = 'ContactForm';

