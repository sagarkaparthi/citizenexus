-- ═══════════════════════════════════════════════════════════════
-- CITIZENNEXUS — SUPABASE SCHEMA v1.1 (MIGRATION-SAFE)
-- Handles projects that already have older tables: every column is
-- added with ALTER TABLE ... ADD COLUMN IF NOT EXISTS, so this runs
-- cleanly on both fresh AND previously-used databases. No data loss.
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────
-- 1. APP STATE MIRROR (powers the sync layer)
-- ───────────────────────────────────────────────
create table if not exists app_state (
  key         text primary key,
  value       jsonb not null,
  updated_at  timestamptz not null default now()
);
alter table app_state add column if not exists value jsonb;
alter table app_state add column if not exists updated_at timestamptz default now();

create or replace function touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists app_state_touch on app_state;
create trigger app_state_touch
  before update on app_state
  for each row execute function touch_updated_at();

alter table app_state enable row level security;
drop policy if exists "anon read app_state" on app_state;
create policy "anon read app_state" on app_state for select to anon using (true);
drop policy if exists "anon write app_state" on app_state;
create policy "anon write app_state" on app_state for insert to anon with check (true);
drop policy if exists "anon update app_state" on app_state;
create policy "anon update app_state" on app_state for update to anon using (true) with check (true);

-- ───────────────────────────────────────────────
-- 2. CUSTOMERS
-- ───────────────────────────────────────────────
create table if not exists customers (
  id uuid primary key default gen_random_uuid()
);
alter table customers add column if not exists name         text;
alter table customers add column if not exists phone        text;
alter table customers add column if not exists email        text;
alter table customers add column if not exists aadhaar      text;
alter table customers add column if not exists password     text;
alter table customers add column if not exists wallet       numeric(12,2) default 0;
alter table customers add column if not exists loyalty_pts  integer default 0;
alter table customers add column if not exists address      text;
alter table customers add column if not exists data         jsonb;
alter table customers add column if not exists created_at   timestamptz default now();
create unique index if not exists uq_customers_phone on customers(phone);

-- ───────────────────────────────────────────────
-- 3. SERVICES
-- ───────────────────────────────────────────────
create table if not exists services (
  id text primary key
);
alter table services add column if not exists name            text;
alter table services add column if not exists code            text;
alter table services add column if not exists icon            text;
alter table services add column if not exists category        text;
alter table services add column if not exists govt_fee        numeric(12,2) default 0;
alter table services add column if not exists svc_charge      numeric(12,2) default 0;
alter table services add column if not exists processing_days integer default 7;
alter table services add column if not exists enabled         boolean default true;
alter table services add column if not exists data            jsonb;
alter table services add column if not exists created_at      timestamptz default now();

-- ───────────────────────────────────────────────
-- 4. APPLICATIONS
-- ───────────────────────────────────────────────
create table if not exists applications (
  track_id text primary key
);
alter table applications add column if not exists service_id        text;
alter table applications add column if not exists service_name      text;
alter table applications add column if not exists customer_phone    text;
alter table applications add column if not exists customer_name     text;
alter table applications add column if not exists status            text default 'Pending';
alter table applications add column if not exists form_data         jsonb;
alter table applications add column if not exists price             numeric(12,2);
alter table applications add column if not exists charge            numeric(12,2);
alter table applications add column if not exists final_paid        numeric(12,2);
alter table applications add column if not exists payment_ref       text;
alter table applications add column if not exists payment_method    text;
alter table applications add column if not exists remarks           text;
alter table applications add column if not exists correction_reason text;
alter table applications add column if not exists assigned_to       text;
alter table applications add column if not exists submitted_at      timestamptz default now();
alter table applications add column if not exists expected_date     timestamptz;
alter table applications add column if not exists updated_at        timestamptz default now();

-- ───────────────────────────────────────────────
-- 5. WALLET TRANSACTIONS
-- ───────────────────────────────────────────────
create table if not exists wallet_transactions (
  id uuid primary key default gen_random_uuid()
);
alter table wallet_transactions add column if not exists customer_phone text;
alter table wallet_transactions add column if not exists type           text;
alter table wallet_transactions add column if not exists amount         numeric(12,2);
alter table wallet_transactions add column if not exists ref            text;
alter table wallet_transactions add column if not exists note           text;
alter table wallet_transactions add column if not exists created_at     timestamptz default now();

-- ───────────────────────────────────────────────
-- 6. STAFF
-- ───────────────────────────────────────────────
create table if not exists staff (
  uid text primary key
);
alter table staff add column if not exists name        text;
alter table staff add column if not exists phone       text;
alter table staff add column if not exists email       text;
alter table staff add column if not exists role        text;
alter table staff add column if not exists dept        text;
alter table staff add column if not exists designation text;
alter table staff add column if not exists password    text;
alter table staff add column if not exists status      text default 'pending_admin_approval';
alter table staff add column if not exists created_by  text;
alter table staff add column if not exists data        jsonb;
alter table staff add column if not exists created_at  timestamptz default now();
create unique index if not exists uq_staff_phone_role on staff(phone, role);

-- ───────────────────────────────────────────────
-- 7. TICKETS
-- ───────────────────────────────────────────────
create table if not exists tickets (
  ticket_id text primary key
);
alter table tickets add column if not exists category     text;
alter table tickets add column if not exists priority     text default 'Medium';
alter table tickets add column if not exists subject      text;
alter table tickets add column if not exists description  text;
alter table tickets add column if not exists created_by   text;
alter table tickets add column if not exists role         text;
alter table tickets add column if not exists assigned_to  text default 'admin';
alter table tickets add column if not exists status       text default 'open';
alter table tickets add column if not exists admin_reply  text;
alter table tickets add column if not exists sla_deadline timestamptz;
alter table tickets add column if not exists data         jsonb;
alter table tickets add column if not exists created_at   timestamptz default now();

-- ───────────────────────────────────────────────
-- 8. AUDIT LOG
-- ───────────────────────────────────────────────
create table if not exists audit_log (
  id bigint generated always as identity primary key
);
alter table audit_log add column if not exists action     text;
alter table audit_log add column if not exists detail     text;
alter table audit_log add column if not exists level      text default 'info';
alter table audit_log add column if not exists actor      text;
alter table audit_log add column if not exists created_at timestamptz default now();

-- ───────────────────────────────────────────────
-- 9. RLS ON (policies come in schema-v2.sql)
-- ───────────────────────────────────────────────
alter table customers            enable row level security;
alter table services             enable row level security;
alter table applications         enable row level security;
alter table wallet_transactions  enable row level security;
alter table staff                enable row level security;
alter table tickets              enable row level security;
alter table audit_log            enable row level security;

-- ───────────────────────────────────────────────
-- 10. INDEXES (now guaranteed to have their columns)
-- ───────────────────────────────────────────────
create index if not exists idx_apps_phone  on applications(customer_phone);
create index if not exists idx_apps_status on applications(status);
create index if not exists idx_wtx_phone   on wallet_transactions(customer_phone);

-- ═══════════════════════════════════════════════
-- OPTIONAL — CLEAN RESET (only if you want to wipe old test data
-- and start completely fresh; uncomment, run alone, then run the
-- whole file again):
-- drop table if exists applications, customers, services, staff,
--   tickets, wallet_transactions, audit_log, app_state cascade;
-- ═══════════════════════════════════════════════
