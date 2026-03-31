-- ============================================================
-- THE OPTIMIZED HUMAN - Inventory & Order Management Schema
-- Supabase Project: qrozjbmimzcwegzolptm.supabase.co
-- Run in Supabase SQL Editor (Settings > SQL Editor)
-- ============================================================

-- ============================================================
-- 1. PRODUCTS TABLE
-- Master catalog with stock levels, costs, reorder thresholds
-- ============================================================
create table products (
  id text primary key,                          -- matches shop.html product IDs (e.g., 'bpc', 'tb500')
  name text not null,
  content text not null,                        -- e.g., '10mg', '500mg', '60ml'
  form text not null,                           -- 'Lyophilized' or 'Liquid'
  category text not null,                       -- 'metabolic', 'recovery', 'longevity', 'cognitive', 'hormonal', 'aesthetic'
  cost_wholesale numeric(10,2) not null,        -- what TOH pays Ion Peptide
  sale_price numeric(10,2) not null,            -- DTC retail price on shop page
  badge text default '',                        -- 'Best Seller', 'Popular', 'New', or ''
  stock_on_hand integer not null default 0,     -- current vial count
  reorder_threshold integer not null default 5, -- alert when stock hits this
  reorder_qty integer not null default 20,      -- suggested reorder quantity
  is_active boolean default true,               -- false = hidden from shop
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Trigger to auto-update updated_at
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger products_updated_at
  before update on products
  for each row execute function update_updated_at();


-- ============================================================
-- 2. CUSTOMERS TABLE
-- Extends Supabase auth.users with order-relevant fields
-- ============================================================
create table customers (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users(id) on delete set null, -- nullable: DM/partner orders may not have an account
  first_name text,
  last_name text,
  email text not null,
  phone text,
  source text default 'direct',                -- 'direct', 'dm', 'partner', 'gym', 'ghl'
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create trigger customers_updated_at
  before update on customers
  for each row execute function update_updated_at();

create index idx_customers_email on customers(email);
create index idx_customers_auth on customers(auth_user_id);


-- ============================================================
-- 3. ORDERS TABLE
-- All orders from all channels
-- ============================================================
create type order_status as enum (
  'pending',        -- order created, not yet paid
  'paid',           -- payment confirmed
  'processing',     -- Amy is packing it
  'partial_shipped',-- some items shipped, some backordered
  'shipped',        -- all items shipped
  'delivered',      -- confirmed delivery
  'cancelled',      -- order cancelled
  'refunded'        -- refund issued
);

create type payment_status as enum (
  'unpaid',
  'paid',
  'partial',        -- split payment scenario
  'refunded'
);

create type order_channel as enum (
  'website',        -- shop.html checkout
  'dm',             -- Jay's DM orders
  'partner',        -- partner/wholesale order
  'gym',            -- gym partner order
  'ghl',            -- GHL pipeline close
  'manual'          -- catch-all
);

create table orders (
  id uuid primary key default gen_random_uuid(),
  order_number serial,                           -- human-readable TOH-1001, TOH-1002...
  customer_id uuid references customers(id),
  status order_status default 'pending',
  payment_status payment_status default 'unpaid',
  channel order_channel default 'manual',
  subtotal numeric(10,2) default 0,
  discount_amount numeric(10,2) default 0,
  shipping_cost numeric(10,2) default 0,
  total numeric(10,2) default 0,
  discount_code text,
  shipping_address text,
  tracking_number text,
  tracking_carrier text,                         -- 'usps', 'ups', 'fedex'
  notes text,                                    -- internal notes (Amy/Jay)
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  shipped_at timestamptz,
  paid_at timestamptz
);

create trigger orders_updated_at
  before update on orders
  for each row execute function update_updated_at();

-- Start order numbers at 1001
alter sequence orders_order_number_seq restart with 1001;

create index idx_orders_status on orders(status);
create index idx_orders_customer on orders(customer_id);
create index idx_orders_channel on orders(channel);


-- ============================================================
-- 4. ORDER ITEMS TABLE
-- Line-item level tracking (enables split shipments)
-- ============================================================
create type item_fulfillment as enum (
  'pending',
  'shipped',
  'backordered',
  'cancelled'
);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade,
  product_id text references products(id),
  quantity integer not null default 1,
  unit_price numeric(10,2) not null,             -- price at time of order (locks it in)
  fulfillment item_fulfillment default 'pending',
  tracking_number text,                          -- per-item tracking for split shipments
  notes text,
  created_at timestamptz default now()
);

create index idx_order_items_order on order_items(order_id);
create index idx_order_items_product on order_items(product_id);
create index idx_order_items_fulfillment on order_items(fulfillment);


-- ============================================================
-- 5. INVENTORY LOG TABLE
-- Audit trail: every stock change is tracked
-- ============================================================
create type inventory_action as enum (
  'sale',           -- sold to customer (decrements)
  'restock',        -- received from Ion Peptide (increments)
  'adjustment',     -- manual correction
  'return',         -- customer return (increments)
  'damage',         -- damaged/expired (decrements)
  'partner_sale'    -- sold to partner/wholesale (decrements)
);

create table inventory_log (
  id uuid primary key default gen_random_uuid(),
  product_id text references products(id),
  action inventory_action not null,
  quantity_change integer not null,              -- positive = add, negative = remove
  stock_after integer not null,                  -- stock level after this change
  reference_id uuid,                            -- order_id or null for adjustments
  notes text,
  created_by text,                              -- 'amy', 'jay', 'system', 'webhook'
  created_at timestamptz default now()
);

create index idx_inventory_log_product on inventory_log(product_id);
create index idx_inventory_log_action on inventory_log(action);


-- ============================================================
-- 6. ROW LEVEL SECURITY
-- ============================================================

-- Products: public read, admin write
alter table products enable row level security;

create policy "Anyone can read active products"
  on products for select
  using (is_active = true);

create policy "Service role can manage products"
  on products for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Customers: admin only
alter table customers enable row level security;

create policy "Service role manages customers"
  on customers for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Orders: admin only (customers see their own via admin dashboard, not direct DB)
alter table orders enable row level security;

create policy "Service role manages orders"
  on orders for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Order items: admin only
alter table order_items enable row level security;

create policy "Service role manages order items"
  on order_items for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Inventory log: admin only
alter table inventory_log enable row level security;

create policy "Service role manages inventory log"
  on inventory_log for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');


-- ============================================================
-- 7. STOCK DECREMENT FUNCTION
-- Call this when an order is confirmed to atomically reduce stock
-- ============================================================
create or replace function decrement_stock(
  p_product_id text,
  p_quantity integer,
  p_order_id uuid default null,
  p_action inventory_action default 'sale',
  p_created_by text default 'system'
)
returns integer as $$
declare
  v_new_stock integer;
begin
  update products
  set stock_on_hand = stock_on_hand - p_quantity
  where id = p_product_id
  returning stock_on_hand into v_new_stock;

  insert into inventory_log (product_id, action, quantity_change, stock_after, reference_id, created_by)
  values (p_product_id, p_action, -p_quantity, v_new_stock, p_order_id, p_created_by);

  return v_new_stock;
end;
$$ language plpgsql security definer;


-- ============================================================
-- 8. STOCK INCREMENT FUNCTION
-- Call this for restocks, returns, adjustments
-- ============================================================
create or replace function increment_stock(
  p_product_id text,
  p_quantity integer,
  p_action inventory_action default 'restock',
  p_notes text default null,
  p_created_by text default 'system'
)
returns integer as $$
declare
  v_new_stock integer;
begin
  update products
  set stock_on_hand = stock_on_hand + p_quantity
  where id = p_product_id
  returning stock_on_hand into v_new_stock;

  insert into inventory_log (product_id, action, quantity_change, stock_after, notes, created_by)
  values (p_product_id, p_action, p_quantity, v_new_stock, p_notes, p_created_by);

  return v_new_stock;
end;
$$ language plpgsql security definer;


-- ============================================================
-- 9. LOW STOCK VIEW
-- Dashboard reads this to show reorder alerts
-- ============================================================
create view low_stock_products as
select
  id,
  name,
  content,
  stock_on_hand,
  reorder_threshold,
  reorder_qty,
  cost_wholesale,
  (reorder_qty * cost_wholesale) as reorder_cost_estimate,
  case
    when stock_on_hand = 0 then 'OUT OF STOCK'
    when stock_on_hand <= reorder_threshold then 'LOW STOCK'
    else 'OK'
  end as stock_status
from products
where is_active = true
  and stock_on_hand <= reorder_threshold
order by stock_on_hand asc;


-- ============================================================
-- 10. NEEDS FULFILLMENT VIEW
-- Amy's primary working view
-- ============================================================
create view needs_fulfillment as
select
  o.id as order_id,
  o.order_number,
  c.first_name || ' ' || c.last_name as customer_name,
  c.email as customer_email,
  o.status,
  o.payment_status,
  o.channel,
  o.total,
  o.shipping_address,
  o.notes,
  o.created_at as order_date,
  json_agg(json_build_object(
    'product', p.name || ' ' || p.content,
    'quantity', oi.quantity,
    'fulfillment', oi.fulfillment,
    'in_stock', p.stock_on_hand >= oi.quantity
  )) as items
from orders o
join customers c on o.customer_id = c.id
join order_items oi on oi.order_id = o.id
join products p on oi.product_id = p.id
where o.status in ('paid', 'processing', 'partial_shipped')
  and o.payment_status = 'paid'
group by o.id, o.order_number, c.first_name, c.last_name, c.email,
         o.status, o.payment_status, o.channel, o.total,
         o.shipping_address, o.notes, o.created_at
order by o.created_at asc;


-- ============================================================
-- 11. SEED DATA - 17 Active SKUs with current inventory
-- ============================================================
insert into products (id, name, content, form, category, cost_wholesale, sale_price, badge, stock_on_hand, reorder_threshold, reorder_qty) values
  ('kpv',      'KPV',               '10mg',  'Lyophilized', 'recovery',  24.50, 49.99,  '',            4,  5, 20),
  ('ksptn',    'KSPTN',             '10mg',  'Lyophilized', 'hormonal',  19.50, 44.99,  '',            4,  5, 20),
  ('methblue', 'Methylene Blue 1%', '60ml',  'Liquid',      'cognitive', 12.00, 33.99,  '',            4,  5, 20),
  ('tesa',     'Tesamorelin',       '10mg',  'Lyophilized', 'metabolic', 34.98, 74.99,  '',            0,  5, 20),
  ('amino5',   '5-Amino-1MQ',       '20mg',  'Lyophilized', 'metabolic', 34.50, 79.99,  '',            5,  5, 20),
  ('selank',   'Selank (N-Acetyl)', '10mg',  'Lyophilized', 'cognitive', 24.98, 79.99,  '',            5,  5, 20),
  ('ta1',      'Thymosin Alpha-1',  '5mg',   'Lyophilized', 'hormonal',  21.00, 49.99,  '',            5,  5, 20),
  ('b12',      'B12 (Methylated)',   '10mg',  'Liquid',      'hormonal',  37.50, 67.99,  '',           10,  5, 20),
  ('glut',     'Glutathione',       '600mg', 'Lyophilized', 'hormonal',  19.50, 38.99,  '',           11,  5, 20),
  ('motsc',    'MOTS-c',            '10mg',  'Lyophilized', 'longevity', 19.00, 55.99,  '',           13,  5, 20),
  ('epi',      'Epithalon',         '10mg',  'Lyophilized', 'longevity', 17.50, 42.99,  '',           14,  5, 20),
  ('tb500',    'TB-500',            '10mg',  'Lyophilized', 'recovery',  24.50, 64.99,  'Best Seller', 8,  5, 20),
  ('nad',      'NAD+',              '500mg', 'Lyophilized', 'longevity', 22.50, 59.99,  'Popular',    18,  5, 20),
  ('ipa',      'Ipamorelin',        '10mg',  'Lyophilized', 'metabolic', 21.00, 59.99,  '',           20,  5, 20),
  ('bpc',      'BPC-157',           '10mg',  'Lyophilized', 'recovery',  19.98, 64.99,  'Best Seller',27,  5, 20),
  ('ghkcu',    'GHK-Cu',            '50mg',  'Lyophilized', 'aesthetic', 14.50, 54.99,  '',           28,  5, 20),
  ('glp3r',    'GLP-3R',            '10mg',  'Lyophilized', 'metabolic', 29.25, 89.99,  'New',        26,  5, 20);
