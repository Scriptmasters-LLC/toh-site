-- ============================================================
-- ADMIN WHITELIST + UPDATED RLS POLICIES
-- Run AFTER toh_inventory_schema.sql
-- ============================================================

-- 1. Admin whitelist table
create table admin_users (
  id uuid primary key references auth.users(id) on delete cascade,
  role text default 'admin',  -- 'admin' or 'viewer' (future use)
  created_at timestamptz default now()
);

alter table admin_users enable row level security;

-- Only service_role can manage the whitelist itself
create policy "Service role manages admin list"
  on admin_users for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Helper function: is this user an admin?
create or replace function is_admin()
returns boolean as $$
begin
  return exists (select 1 from admin_users where id = auth.uid());
end;
$$ language plpgsql security definer;

-- 2. Drop old service_role-only policies and replace with admin-aware ones

-- PRODUCTS: public read (already exists), admin write
drop policy if exists "Service role can manage products" on products;
create policy "Admins can manage products"
  on products for all
  using (is_admin())
  with check (is_admin());

-- CUSTOMERS: admin only
drop policy if exists "Service role manages customers" on customers;
create policy "Admins can manage customers"
  on customers for all
  using (is_admin())
  with check (is_admin());

-- ORDERS: admin only
drop policy if exists "Service role manages orders" on orders;
create policy "Admins can manage orders"
  on orders for all
  using (is_admin())
  with check (is_admin());

-- ORDER ITEMS: admin only
drop policy if exists "Service role manages order items" on order_items;
create policy "Admins can manage order items"
  on order_items for all
  using (is_admin())
  with check (is_admin());

-- INVENTORY LOG: admin only
drop policy if exists "Service role manages inventory log" on inventory_log;
create policy "Admins can manage inventory log"
  on inventory_log for all
  using (is_admin())
  with check (is_admin());

-- 3. Grant execute on stock functions to authenticated users (admins use these)
grant execute on function decrement_stock to authenticated;
grant execute on function increment_stock to authenticated;

-- ============================================================
-- AFTER RUNNING THIS:
-- Add Amy and Jay's user IDs to admin_users.
-- Find their IDs in Supabase: Authentication > Users > click user > copy UUID
-- Then run:
--
-- insert into admin_users (id) values
--   ('PASTE_AMY_UUID_HERE'),
--   ('PASTE_JAY_UUID_HERE');
--
-- Also add your own (Damon) if you want admin access:
--   insert into admin_users (id) values ('PASTE_DAMON_UUID_HERE');
-- ============================================================
