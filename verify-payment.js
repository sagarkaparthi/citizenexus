// api/verify-payment.js — Vercel serverless function
// Verifies the Razorpay payment signature server-side (HMAC-SHA256).
// This is the step that makes the payment trustworthy — the browser cannot fake it.

const crypto = require('crypto');

module.exports = function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });

  const secret = process.env.RAZORPAY_KEY_SECRET;
  const b = req.body || {};
  const orderId = b.razorpay_order_id;
  const paymentId = b.razorpay_payment_id;
  const signature = b.razorpay_signature;

  if (!secret || !orderId || !paymentId || !signature) {
    return res.status(400).json({ verified: false, error: 'Missing fields' });
  }

  try {
    const expected = crypto
      .createHmac('sha256', secret)
      .update(orderId + '|' + paymentId)
      .digest('hex');
    const ok =
      expected.length === signature.length &&
      crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
    return res.status(200).json({ verified: !!ok });
  } catch (e) {
    return res.status(200).json({ verified: false });
  }
};
