/**
 * WhatsApp delivery for demo requests.
 *
 * A website cannot send a WhatsApp message on a visitor's behalf: WhatsApp
 * only accepts business-initiated messages through the Meta Cloud API, with a
 * registered sender and (outside a 24-hour customer service window) an
 * approved template. So this module does two things:
 *
 *   - server side, it posts through the Cloud API when WHATSAPP_TOKEN and
 *     WHATSAPP_PHONE_NUMBER_ID are configured, delivering the request without
 *     the visitor doing anything;
 *   - when they are not, the caller falls back to handing the browser a wa.me
 *     deep link with the message pre-filled, which the visitor sends with one
 *     tap from their own WhatsApp.
 *
 * Either way the request reaches the same number. Only the first is silent.
 *
 * @file src/lib/whatsapp.js
 */

const GRAPH_VERSION = 'v21.0';

/**
 * Whether server-side WhatsApp delivery is configured.
 *
 * @returns {boolean} True when the Cloud API credentials are present
 */
export function canSendWhatsApp() {
  return Boolean(process.env.WHATSAPP_TOKEN && process.env.WHATSAPP_PHONE_NUMBER_ID);
}

/**
 * Send a plain text WhatsApp message through the Meta Cloud API.
 *
 * Never throws - a failure here must not fail the visitor's request, because
 * the email has already gone out and the deep link still works.
 *
 * @param {string} to - Recipient in E.164 without the leading plus
 * @param {string} body - Message text
 * @returns {Promise<{sent: boolean, reason?: string}>} Delivery outcome
 */
export async function sendWhatsAppText(to, body) {
  if (!canSendWhatsApp()) {
    return { sent: false, reason: 'not-configured' };
  }

  try {
    const response = await fetch(
      `https://graph.facebook.com/${GRAPH_VERSION}/${process.env.WHATSAPP_PHONE_NUMBER_ID}/messages`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.WHATSAPP_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to,
          type: 'text',
          text: { preview_url: false, body },
        }),
      }
    );

    if (!response.ok) {
      const detail = await response.text();
      return { sent: false, reason: `http-${response.status}: ${detail.slice(0, 200)}` };
    }

    return { sent: true };
  } catch (error) {
    return { sent: false, reason: error?.message || 'request-failed' };
  }
}
