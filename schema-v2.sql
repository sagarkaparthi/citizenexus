-- ═══════════════════════════════════════════════════════════════
-- CITIZENNEXUS — SCHEMA v2 (ALL PHASES)
-- Supabase Auth + normalized tables + Row Level Security
-- Run AFTER schema.sql (or on a fresh project run schema.sql first).
-- Safe to re-run (idempotent).
-- ═══════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────
-- 0. PROFILES — links Supabase Auth users to app identity + role
-- ───────────────────────────────────────────────
create table if not exists profiles (
  auth_uid   uuid primary key references auth.users(id) on delete cascade,
  phone      text unique not null,
  role       text not null default 'customer',  -- customer|admin|manager|employee|hr|agent|distributor
  name       text,
  created_at timestamptz default now()
);

-- Helper functions (security definer = bypass RLS internally)
create or replace function my_phone() returns text
language sql stable security definer set search_path = public as
$$ select phone from profiles where auth_uid = auth.uid() $$;

create or replace function my_role() returns text
language sql stable security definer set search_path = public as
$$ select role from profiles where auth_uid = auth.uid() $$;

create or replace function is_staff() returns boolean
language sql stable security definer set search_path = public as
$$ select coalesce(
     (select role in ('admin','manager','employee','hr','agent','distributor')
        from profiles where auth_uid = auth.uid()), false) $$;

alter table profiles enable row level security;
drop policy if exists "profiles self select" on profiles;
create policy "profiles self select" on profiles for select
  to authenticated using (auth_uid = auth.uid() or is_staff());
drop policy if exists "profiles self insert" on profiles;
create policy "profiles self insert" on profiles for insert
  to authenticated with check (auth_uid = auth.uid());
drop policy if exists "profiles staff update" on profiles;
create policy "profiles staff update" on profiles for update
  to authenticated using (auth_uid = auth.uid() or is_staff());

-- ───────────────────────────────────────────────
-- 1. FULL-FIDELITY DATA COLUMNS
--    Each table stores the complete original app object in `data`
--    plus extracted columns for SQL querying. Nothing is lost.
-- ───────────────────────────────────────────────
alter table customers add column if not exists data jsonb;
alter table services  add column if not exists data jsonb;
alter table staff     add column if not exists data jsonb;
alter table tickets   add column if not exists data jsonb;
-- applications already has form_data jsonb

-- ───────────────────────────────────────────────
-- 2. RLS POLICIES — normalized tables go live
-- ───────────────────────────────────────────────

-- SERVICES: public catalog (read for everyone incl. logged-out), staff write
drop policy if exists "services public read" on services;
create policy "services public read" on services for select
  to anon, authenticated using (true);
drop policy if exists "services staff write" on services;
create policy "services staff write" on services for all
  to authenticated using (is_staff()) with check (is_staff());

-- CUSTOMERS: own row or staff
drop policy if exists "customers own or staff select" on customers;
create policy "customers own or staff select" on customers for select
  to authenticated using (phone = my_phone() or is_staff());
drop policy if exists "customers own or staff insert" on customers;
create policy "customers own or staff insert" on customers for insert
  to authenticated with check (phone = my_phone() or is_staff());
drop policy if exists "customers own or staff update" on customers;
create policy "customers own or staff update" on customers for update
  to authenticated using (phone = my_phone() or is_staff())
  with check (phone = my_phone() or is_staff());

-- APPLICATIONS: own rows or staff
drop policy if exists "apps own or staff select" on applications;
create policy "apps own or staff select" on applications for select
  to authenticated using (customer_phone = my_phone() or is_staff());
drop policy if exists "apps own or staff insert" on applications;
create policy "apps own or staff insert" on applications for insert
  to authenticated with check (customer_phone = my_phone() or is_staff());
drop policy if exists "apps own or staff update" on applications;
create policy "apps own or staff update" on applications for update
  to authenticated using (customer_phone = my_phone() or is_staff())
  with check (customer_phone = my_phone() or is_staff());

-- WALLET TRANSACTIONS: own or staff
drop policy if exists "wtx own or staff select" on wallet_transactions;
create policy "wtx own or staff select" on wallet_transactions for select
  to authenticated using (customer_phone = my_phone() or is_staff());
drop policy if exists "wtx own or staff insert" on wallet_transactions;
create policy "wtx own or staff insert" on wallet_transactions for insert
  to authenticated with check (customer_phone = my_phone() or is_staff());

-- STAFF table: staff only
drop policy if exists "staff staff all" on staff;
create policy "staff staff all" on staff for all
  to authenticated using (is_staff()) with check (is_staff());

-- TICKETS: staff only (internal)
drop policy if exists "tickets staff all" on tickets;
create policy "tickets staff all" on tickets for all
  to authenticated using (is_staff()) with check (is_staff());

-- AUDIT LOG: any authenticated writes, staff reads
drop policy if exists "audit auth insert" on audit_log;
create policy "audit auth insert" on audit_log for insert
  to authenticated with check (true);
drop policy if exists "audit staff select" on audit_log;
create policy "audit staff select" on audit_log for select
  to authenticated using (is_staff());

-- ───────────────────────────────────────────────
-- 3. APP_STATE — tighten Phase-1 open access
--    Anon may still READ (site settings load pre-login).
--    Writes now require login.
-- ───────────────────────────────────────────────
drop policy if exists "anon write app_state" on app_state;
drop policy if exists "anon update app_state" on app_state;
drop policy if exists "auth write app_state" on app_state;
create policy "auth write app_state" on app_state for insert
  to authenticated with check (true);
drop policy if exists "auth update app_state" on app_state;
create policy "auth update app_state" on app_state for update
  to authenticated using (true) with check (true);
-- keep: "anon read app_state" (from schema.sql)

-- Staff can delete rows they manage (catalog/staff/ticket removal sync)
drop policy if exists "services staff delete" on services;
drop policy if exists "staff staff delete" on staff;
drop policy if exists "tickets staff delete" on tickets;
-- (covered by FOR ALL policies above)

-- ═══════════════════════════════════════════════
-- 4. ADMIN BOOTSTRAP  ← run AFTER creating auth users (see README)
--    Dashboard → Authentication → Add user →
--      email: admin@staff.cnx.local   password: <your admin password>
--    Then run this block:
-- ═══════════════════════════════════════════════
insert into profiles (auth_uid, phone, role, name)
select id, '9916166996', 'admin', 'Super Admin'
from auth.users where email = 'admin@staff.cnx.local'
on conflict (auth_uid) do update set role = 'admin';

-- Repeat for other staff roles you use (uncomment + create the auth user first):
-- insert into profiles (auth_uid, phone, role, name)
-- select id, '9916166996', 'manager', 'Operations Head'
-- from auth.users where email = 'manager@staff.cnx.local'
-- on conflict (auth_uid) do update set role = 'manager';
