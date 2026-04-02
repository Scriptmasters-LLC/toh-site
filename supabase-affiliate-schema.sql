-- ============================================================
-- TOH AFFILIATE TRACKING SYSTEM - Supabase Schema
-- ============================================================
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- Project: qrozjbmimzcwegzolptm.supabase.co
-- ============================================================

-- 1. AFFILIATES TABLE
-- Stores affiliate accounts linked to Supabase auth users
-- ============================================================
CREATE TABLE IF NOT EXISTS affiliates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ref_code TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  email TEXT NOT NULL,
  commission_rate NUMERIC(5,2) NOT NULL DEFAULT 10.00, -- flat % on all sales
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','suspended','terminated')),
  payment_email TEXT, -- PayPal, Zelle, etc
  payment_method TEXT DEFAULT 'manual', -- manual, paypal, zelle, crypto
  payment_details JSONB DEFAULT '{}', -- flexible store for payment info
  total_clicks INTEGER DEFAULT 0,
  total_conversions INTEGER DEFAULT 0,
  total_revenue NUMERIC(12,2) DEFAULT 0.00,
  total_commission NUMERIC(12,2) DEFAULT 0.00,
  total_paid NUMERIC(12,2) DEFAULT 0.00,
  notes TEXT,
  applied_at TIMESTAMPTZ DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast ref_code lookups (every page load hits this)
CREATE INDEX IF NOT EXISTS idx_affiliates_ref_code ON affiliates(ref_code);
CREATE INDEX IF NOT EXISTS idx_affiliates_user_id ON affiliates(user_id);
CREATE INDEX IF NOT EXISTS idx_affiliates_status ON affiliates(status);

-- 2. REFERRAL CLICKS TABLE
-- Tracks every click on an affiliate link
-- ============================================================
CREATE TABLE IF NOT EXISTS referral_clicks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID REFERENCES affiliates(id) ON DELETE CASCADE,
  ref_code TEXT NOT NULL,
  landing_page TEXT,
  referrer_url TEXT,
  ip_hash TEXT, -- hashed IP for dedup, not raw IP
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clicks_affiliate ON referral_clicks(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_clicks_ref_code ON referral_clicks(ref_code);
CREATE INDEX IF NOT EXISTS idx_clicks_created ON referral_clicks(created_at);

-- 3. REFERRAL CONVERSIONS TABLE
-- Tracks completed sales attributed to affiliates
-- ============================================================
CREATE TABLE IF NOT EXISTS referral_conversions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID REFERENCES affiliates(id) ON DELETE CASCADE,
  ref_code TEXT NOT NULL,
  customer_email TEXT, -- the buyer
  order_items JSONB DEFAULT '[]', -- [{product_id, name, qty, price}]
  order_total NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  commission_rate NUMERIC(5,2) NOT NULL, -- snapshot at time of sale
  commission_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','paid','rejected')),
  paid_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conversions_affiliate ON referral_conversions(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_conversions_status ON referral_conversions(status);
CREATE INDEX IF NOT EXISTS idx_conversions_created ON referral_conversions(created_at);

-- 4. AFFILIATE PAYOUTS TABLE
-- Tracks payout batches to affiliates
-- ============================================================
CREATE TABLE IF NOT EXISTS affiliate_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID REFERENCES affiliates(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL,
  payment_method TEXT,
  payment_reference TEXT, -- transaction ID, Zelle confirmation, etc
  conversion_ids UUID[] DEFAULT '{}', -- which conversions this covers
  notes TEXT,
  paid_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payouts_affiliate ON affiliate_payouts(affiliate_id);

-- 5. ROW LEVEL SECURITY
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE affiliates ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_clicks ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_conversions ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_payouts ENABLE ROW LEVEL SECURITY;

-- AFFILIATES: users can read their own record
CREATE POLICY "affiliates_select_own" ON affiliates
  FOR SELECT USING (auth.uid() = user_id);

-- AFFILIATES: anon can look up ref_code for tracking (read-only, limited fields via function)
-- We handle this through an RPC function instead of a direct policy

-- AFFILIATES: users can update their own payment info
CREATE POLICY "affiliates_update_own" ON affiliates
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- AFFILIATES: anyone authenticated can insert (apply)
CREATE POLICY "affiliates_insert" ON affiliates
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- CLICKS: anon insert allowed (tracking happens before auth)
CREATE POLICY "clicks_insert_anon" ON referral_clicks
  FOR INSERT WITH CHECK (true);

-- CLICKS: affiliates can read their own clicks
CREATE POLICY "clicks_select_own" ON referral_clicks
  FOR SELECT USING (
    affiliate_id IN (SELECT id FROM affiliates WHERE user_id = auth.uid())
  );

-- CONVERSIONS: affiliates can read their own conversions
CREATE POLICY "conversions_select_own" ON referral_conversions
  FOR SELECT USING (
    affiliate_id IN (SELECT id FROM affiliates WHERE user_id = auth.uid())
  );

-- PAYOUTS: affiliates can read their own payouts
CREATE POLICY "payouts_select_own" ON affiliate_payouts
  FOR SELECT USING (
    affiliate_id IN (SELECT id FROM affiliates WHERE user_id = auth.uid())
  );

-- 6. RPC FUNCTIONS
-- ============================================================

-- Public function to validate a ref code (used by tracking JS)
CREATE OR REPLACE FUNCTION validate_ref_code(code TEXT)
RETURNS TABLE(affiliate_id UUID, is_valid BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT a.id, true
  FROM affiliates a
  WHERE a.ref_code = code AND a.status = 'active';
END;
$$;

-- Public function to log a click (called from anon context)
CREATE OR REPLACE FUNCTION log_referral_click(
  p_ref_code TEXT,
  p_landing_page TEXT DEFAULT NULL,
  p_referrer_url TEXT DEFAULT NULL,
  p_ip_hash TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_affiliate_id UUID;
BEGIN
  SELECT id INTO v_affiliate_id
  FROM affiliates
  WHERE ref_code = p_ref_code AND status = 'active';

  IF v_affiliate_id IS NULL THEN
    RETURN false;
  END IF;

  INSERT INTO referral_clicks (affiliate_id, ref_code, landing_page, referrer_url, ip_hash, user_agent)
  VALUES (v_affiliate_id, p_ref_code, p_landing_page, p_referrer_url, p_ip_hash, p_user_agent);

  UPDATE affiliates SET total_clicks = total_clicks + 1, updated_at = NOW()
  WHERE id = v_affiliate_id;

  RETURN true;
END;
$$;

-- Function to record a conversion (called by admin or checkout flow)
CREATE OR REPLACE FUNCTION record_conversion(
  p_ref_code TEXT,
  p_customer_email TEXT,
  p_order_items JSONB,
  p_order_total NUMERIC
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_affiliate_id UUID;
  v_commission_rate NUMERIC;
  v_commission_amount NUMERIC;
  v_conversion_id UUID;
BEGIN
  SELECT id, commission_rate INTO v_affiliate_id, v_commission_rate
  FROM affiliates
  WHERE ref_code = p_ref_code AND status = 'active';

  IF v_affiliate_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_commission_amount := ROUND(p_order_total * (v_commission_rate / 100), 2);

  INSERT INTO referral_conversions (
    affiliate_id, ref_code, customer_email, order_items,
    order_total, commission_rate, commission_amount
  )
  VALUES (
    v_affiliate_id, p_ref_code, p_customer_email, p_order_items,
    p_order_total, v_commission_rate, v_commission_amount
  )
  RETURNING id INTO v_conversion_id;

  UPDATE affiliates SET
    total_conversions = total_conversions + 1,
    total_revenue = total_revenue + p_order_total,
    total_commission = total_commission + v_commission_amount,
    updated_at = NOW()
  WHERE id = v_affiliate_id;

  RETURN v_conversion_id;
END;
$$;

-- Grant execute on public functions to anon and authenticated
GRANT EXECUTE ON FUNCTION validate_ref_code TO anon, authenticated;
GRANT EXECUTE ON FUNCTION log_referral_click TO anon, authenticated;
GRANT EXECUTE ON FUNCTION record_conversion TO authenticated;

-- 7. ADMIN ACCESS
-- ============================================================
-- For admin pages, you'll use the Supabase service_role key
-- (server-side or in a protected admin context) which bypasses RLS.
-- The admin HTML pages use a simple password gate + service_role key.
-- In production, replace with proper admin auth.

-- ============================================================
-- DONE. Run this entire script in Supabase SQL Editor.
-- Then deploy the JS tracking snippet and HTML pages.
-- ============================================================
