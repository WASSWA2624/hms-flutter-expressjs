/**
 * Contact API Route - Handle contact form submissions
 * 
 * @file src/app/api/contact/route.js
 */
import { NextResponse } from 'next/server';
import { CONTACT_EMAIL, DEFAULT_LOCALE, SUPPORTED_LOCALES } from '@/lib/constants';
import { createTransporter, fromAddress } from '@/lib/mailer';
import { formatTimestamp } from '@/lib/datetime';
import { getLocaleFromRequest, getServerTranslations } from '@/lib/i18n';

/**
 * Validate email format
 * 
 * @param {string} email - Email address to validate
 * @returns {boolean} True if email is valid, false otherwise
 */
function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

/**
 * Sanitize input string
 * 
 * @param {string} input - Input string to sanitize
 * @returns {string} Sanitized input string
 */
function sanitizeInput(input) {
  if (typeof input !== 'string') return '';
  return input.trim().replace(/[<>]/g, '');
}

/**
 * POST /api/contact - Handle contact form submission
 * 
 * @param {Request} request - Next.js request object
 * @returns {Promise<NextResponse>} JSON response with success or error
 */
export async function POST(request) {
  try {
    // Get locale from request for translations
    const locale = getLocaleFromRequest(request);
    const t = await getServerTranslations(locale, 'contact');
    
    const body = await request.json();
    const { name, email, message } = body;

    // Validate required fields
    if (!name || !email || !message) {
      return NextResponse.json(
        { error: t.apiErrors?.allFieldsRequired || 'All fields are required' },
        { status: 400 }
      );
    }

    // Sanitize inputs
    const sanitizedName = sanitizeInput(name);
    const sanitizedEmail = sanitizeInput(email);
    const sanitizedMessage = sanitizeInput(message);

    // Validate email format
    if (!validateEmail(sanitizedEmail)) {
      return NextResponse.json(
        { error: t.apiErrors?.invalidEmailFormat || 'Invalid email format' },
        { status: 400 }
      );
    }

    // Validate message length
    if (sanitizedMessage.length < 10) {
      return NextResponse.json(
        { error: t.apiErrors?.messageTooShort || 'Message must be at least 10 characters long' },
        { status: 400 }
      );
    }

    // Validate name length
    if (sanitizedName.length < 2) {
      return NextResponse.json(
        { error: t.apiErrors?.nameTooShort || 'Name must be at least 2 characters long' },
        { status: 400 }
      );
    }

    // Shared with /api/demo - see src/lib/mailer.js
    const transporter = createTransporter();

    if (!transporter) {
      // Development mode: log instead of sending
      console.log('Contact form submission (email not configured):', {
        name: sanitizedName,
        email: sanitizedEmail,
        message: sanitizedMessage,
        timestamp: formatTimestamp(),
      });
      
      // Return success even without email sending in development
      return NextResponse.json(
        { 
          message: 'Contact form submitted successfully (email not configured)',
          data: {
            name: sanitizedName,
            email: sanitizedEmail,
          }
        },
        { status: 200 }
      );
    }

    // Send email notification to site owner
    const fromEmail = fromAddress();
    
    try {
      await transporter.sendMail({
        from: fromEmail,
        to: CONTACT_EMAIL,
        replyTo: sanitizedEmail,
        subject: `Contact Form Submission from ${sanitizedName}`,
        text: `Name: ${sanitizedName}\nEmail: ${sanitizedEmail}\n\nMessage:\n${sanitizedMessage}`,
        html: `
          <h2>Contact Form Submission</h2>
          <p><strong>Name:</strong> ${sanitizedName.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</p>
          <p><strong>Email:</strong> <a href="mailto:${sanitizedEmail}">${sanitizedEmail.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</a></p>
          <p><strong>Message:</strong></p>
          <p>${sanitizedMessage.replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\n/g, '<br>')}</p>
        `,
      });

      // Optionally send confirmation email to user
      if (process.env.SEND_CONFIRMATION_EMAIL === 'true') {
        await transporter.sendMail({
          from: fromEmail,
          to: sanitizedEmail,
          subject: `Thank you for contacting ${process.env.NEXT_PUBLIC_APP_NAME || 'us'}`,
          text: `Dear ${sanitizedName},\n\nThank you for contacting us. We have received your message and will get back to you soon.\n\nBest regards,\n${process.env.NEXT_PUBLIC_APP_NAME || 'Team'}`,
          html: `
            <h2>Thank you for contacting us!</h2>
            <p>Dear ${sanitizedName},</p>
            <p>Thank you for contacting us. We have received your message and will get back to you soon.</p>
            <p>Best regards,<br>${process.env.NEXT_PUBLIC_APP_NAME || 'Team'}</p>
          `,
        });
      }
    } catch (emailError) {
      console.error('Error sending email:', emailError);
      // Still return success to user, but log the error
      // In production, you might want to store failed submissions in database
    }

    return NextResponse.json(
      { 
        message: 'Contact form submitted successfully',
        data: {
          name: sanitizedName,
          email: sanitizedEmail,
        }
      },
      { status: 200 }
    );
  } catch (error) {
    console.error('Error processing contact form:', error);
    // Get locale for error message translation
    const locale = getLocaleFromRequest(request);
    const t = await getServerTranslations(locale, 'contact').catch(() => ({}));
    
    return NextResponse.json(
      { error: t.apiErrors?.processingError || 'Failed to process contact form. Please try again later.' },
      { status: 500 }
    );
  }
}

