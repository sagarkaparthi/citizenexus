// api/create-order.js — Vercel serverless function
// Creates a Razorpay order server-side. The key SECRET never touches the browser.
// Env vars required (Vercel → Project → Settings → Environment Variables):
//   RAZORPAY_KEY_ID     (rzp_test_... or rzp_live_...)
//   RAZORPAY_KEY_SECRET

module.exports = async function handler(req, res) {
  // CORS for same-origin only; block other origins
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });

  const key = process.env.RAZORPAY_KEY_ID;
  const secret = process.env.RAZORPAY_KEY_SECRET;
  if (!key || !secret) {
    return res.status(500).json({ error: 'Razorpay not configured on server' });
  }

  const body = req.body || {};
  const amount = Math.round(Number(body.amount));       // paise
  const receipt = String(body.receipt || 'CNX-' + Date.now()).slice(0, 40);
  const notes = (body.notes && typeof body.notes === 'object') ? body.notes : {};

  // ₹1 minimum, ₹5,00,000 ceiling — sanity bounds
  if (!amount || isNaN(amount) || amount < 100 || amount > 50000000) {
    return res.status(400).json({ error: 'Invalid amount' });
  }

  try {
    const r = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Basic ' + Buffer.from(key + ':' + secret).toString('base64')
      },
      body: JSON.stringify({ amount, currency: 'INR', receipt, notes })
    });
    const data = await r.json();
    if (!r.ok) {
      const msg = (data && data.error && data.error.description) || 'Order creation failed';
      return res.status(502).json({ error: msg });
    }
    return res.status(200).json({ order_id: data.id, amount: data.amount, key_id: key });
  } catch (e) {
    return res.status(500).json({ error: 'Payment gateway unreachable' });
  }
};
