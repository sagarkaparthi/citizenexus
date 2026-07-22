# CitizenNexus — FULL STACK, ALL PHASES (Vercel + Supabase)

Complete build: frontend + real backend + authentication + row-level security.

## Architecture

| Layer | Technology | What it does |
|---|---|---|
| Frontend | Single-file `index.html` on Vercel | All portals (customer/admin/staff), UI uplift |
| Auth | Supabase Auth | Real accounts. Customer email = `<phone>@cnx.local`, staff = `<role>@staff.cnx.local` |
| Database | Supabase Postgres, normalized tables | `customers`, `applications`, `services`, `tickets`, `staff`, `wallet_transactions`, `audit_log` |
| Security | Row Level Security | Customers see ONLY their rows. Staff roles see everything. Enforced by the database, not the browser |
| Fallback | localStorage | Unconfigured/offline → app still fully works locally |

**How sync works:** the app's storage writes are intercepted and decomposed into
normalized table rows (e.g. each application → one row in `applications` with
queryable columns + full-fidelity `form_data` JSON). On login, cloud rows are
pulled and reassembled. Cloud wins on conflicts; local-only extras are kept.

---

## SETUP (one-time, ~20 minutes)

### 1. Supabase project
1. <https://supabase.com> → New project → region `ap-south-1` (Mumbai).
2. **SQL Editor** → run `supabase/schema.sql` (base tables) → then run `supabase/schema-v2.sql` (auth + RLS). Both say "Success".

### 2. Auth settings
1. **Authentication → Providers → Email**: turn **OFF** "Confirm email"
   (accounts use synthetic `@cnx.local` addresses — no real inbox exists).
2. **Authentication → Users → Add user**:
   - email `admin@staff.cnx.local`, password = your real admin password → Create.
   - (Optional) repeat for `manager@`, `employee@`, `hr@`, `agent@staff.cnx.local` with those roles' passwords.
3. **SQL Editor** → re-run the "ADMIN BOOTSTRAP" block at the bottom of
   `schema-v2.sql` (it links the auth user to the admin role). Uncomment the
   extra role blocks for any staff users you created.

### 3. Configure the app
Open `index.html`, search `PASTE_YOUR`, paste your **Project URL** and **anon key**
(Settings → API). Save.

### 4. Deploy to Vercel
Drag the folder onto <https://vercel.com/new>, or push to GitHub and import.
No build command, no output directory. Live in ~1 minute.

---

## What each phase gave you (all included)

**Phase 1 — cloud persistence**
- All app data mirrored to Postgres, survives browser clears, syncs across devices.

**Phase 2 — real backend**
- Signup creates a genuine Supabase Auth account (password held by Auth, hashed
  with bcrypt — no more plaintext).
- Login establishes a database session; on a fresh device, your account and
  applications download automatically.
- Normalized tables you can query with SQL: *"SELECT count(*) FROM applications
  WHERE status='Pending'"* just works in the Supabase dashboard.
- **Row Level Security**: a customer physically cannot read another customer's
  rows — the database refuses, regardless of what the browser does. Staff roles
  (via `profiles.role`) see everything.
- Services catalog is public-read (pre-login browsing works); writes need staff.

## Verifying it works
1. Deploy, open the site, open DevTools console → `[CNX] Connected.`
2. Sign up as a customer → Supabase → Authentication → Users: new `<phone>@cnx.local` user appears.
3. Table Editor → `customers`, `profiles`: rows exist.
4. Submit an application → `applications` table: row appears with status/price columns filled.
5. Open the site in a different browser → log in → your applications load from the cloud.

## Honest remaining limits
- **Legacy hardcoded staff passwords** still exist inside the JS for local
  fallback. Cloud RLS protects the data, but rotate those and prefer the
  Supabase-created staff users. Ask me to strip the hardcoded fallback when
  you confirm cloud login works.
- **Uploaded documents** (photos/ID proofs) currently live inside application
  JSON as base64. Fine at small scale; the right next step is Supabase Storage
  buckets. Say the word.
- **Tickets are staff-only** by policy; customer-side ticket sync stays local.

## Costs
Free on both platforms at your scale (Supabase free: 500MB DB, 50k monthly
active auth users; Vercel Hobby: 100GB bandwidth).

## Admin login (app UI)
Staff Login → Admin → phone `9916166996` / your admin password.


---

## PAYMENTS — Real Razorpay Integration

The app ships with a **mock payment** for testing. To accept real money:

### 1. Razorpay account
1. Sign up at <https://razorpay.com> → complete KYC (PAN, bank account; takes 1-2 days for live mode).
2. Dashboard → **Settings → API Keys** → Generate keys. You get:
   - **Key ID** (`rzp_test_...` for testing, `rzp_live_...` after KYC) — public, safe in frontend
   - **Key Secret** — server-only, never in the browser

### 2. Server config (Vercel)
Vercel → your project → **Settings → Environment Variables**, add:
| Name | Value |
|---|---|
| `RAZORPAY_KEY_ID` | rzp_test_xxxxx |
| `RAZORPAY_KEY_SECRET` | your secret |

Redeploy after saving (env vars need a fresh deploy).

### 3. Frontend config
In `index.html`, search `PASTE_RAZORPAY` and set:
```js
var RAZORPAY_KEY_ID = "rzp_test_xxxxx";   // same Key ID as above
```

### 4. Test it
Use test mode first (`rzp_test_` keys). Razorpay test cards: `4111 1111 1111 1111`,
any future expiry, any CVV. Test UPI: `success@razorpay`.
Console shows `[PAY] Live Razorpay mode active.` when configured.

### How the flow works (and why it's secure)
1. Customer clicks Pay → browser asks `/api/create-order` (serverless) → order created with your **secret** on the server.
2. Razorpay Checkout opens (UPI / cards / netbanking / wallets — all automatic).
3. On success, the browser sends the payment proof to `/api/verify-payment`, which recomputes the HMAC-SHA256 signature **server-side**. A tampered browser cannot fake this.
4. Only after verification does the application get finalized with the real payment ID.

Mock mode remains as automatic fallback when no key is configured — dev/testing keeps working offline.

### Fees (check current rates at razorpay.com/pricing)
Standard plan: ~2% per transaction on cards/netbanking; UPI is typically lower or zero. No setup or monthly fee.

### Not included yet (say the word)
- **Webhooks** (`payment.captured` server push) — sturdier than browser-side confirmation if the customer closes the tab mid-payment.
- **Refund API** — the admin panel's Refund button is currently record-keeping only.
- **Settlement reconciliation** reports.


---

## Staff Logins (updated)

Only the **Admin** login is built in:

| Role | User ID / Phone | Password |
|---|---|---|
| **Admin** | 9916166996 | admin@123 |

**Change this before going live** (it's a documented default).

All other roles — Manager, Employee, HR, Agent, Distributor — no longer have
demo logins. They authenticate against **real accounts** you create from inside
the app:
- **HR / Manager / Employee** → added via the admin panel (stored in `hr_users`).
- **Agents** → added via the Distributor panel or admin (stored in `jc_agents`).
- **Distributors** → added via the admin panel (stored in `jc_distributors`).

Each of those accounts sets its own password at creation (minimum 6 characters).
