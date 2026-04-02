# TOH Affiliate System - Deployment Guide

## What's In This Package

| File | Purpose |
|------|---------|
| `supabase-affiliate-schema.sql` | Database tables, indexes, RLS policies, and RPC functions |
| `toh-affiliate.js` | Tracking snippet (add to every page on the site) |
| `affiliate-dashboard.html` | Affiliate portal (login, stats, referral links, payouts) |
| `affiliate-admin.html` | Admin panel (manage affiliates, record sales, process payouts) |
| `affiliate-signup.html` | Public landing page explaining the program + CTA to apply |

## Deployment Steps

### Step 1: Run the SQL Schema

1. Go to Supabase Dashboard > SQL Editor
2. Paste the entire contents of `supabase-affiliate-schema.sql`
3. Click "Run"
4. Verify tables were created: check Database > Tables for `affiliates`, `referral_clicks`, `referral_conversions`, `affiliate_payouts`

### Step 2: Configure API Keys

**In `toh-affiliate.js`:**
- Replace `YOUR_ANON_KEY_HERE` with your Supabase anon/public key

**In `affiliate-dashboard.html`:**
- Replace `YOUR_ANON_KEY_HERE` with your Supabase anon/public key
- Update `SITE_URL` if different from `https://theoptimizedhumanproject.com`

**In `affiliate-admin.html`:**
- Replace `YOUR_SERVICE_ROLE_KEY_HERE` with your Supabase service_role key
- Replace `CHANGE_THIS_PASSWORD` with a real admin password
- **IMPORTANT:** The service_role key bypasses RLS. Keep this page protected.

### Step 3: Deploy Files to GitHub Pages

Upload these files to the `damon-imp/toh-site` repo:

```
toh-affiliate.js          -> root of repo
affiliate-dashboard.html  -> root of repo  
affiliate-admin.html      -> root of repo
affiliate-signup.html     -> root of repo
```

### Step 4: Add Tracking Snippet to All Pages

Add this line to every HTML page on the site, right before the closing `</body>` tag:

```html
<script src="toh-affiliate.js"></script>
```

Pages to update:
- index.html
- shop.html
- protocols.html
- assessment.html
- calculator.html
- cart.html
- about.html
- partners.html
- contact.html
- coa.html

### Step 5: Add Nav Link (Optional)

Add an "Affiliates" link to the site navigation on relevant pages:

```html
<a href="affiliate-signup.html">Affiliates</a>
```

### Step 6: Wire Into Checkout Flow

When you process an order (currently manual invoicing), check for affiliate attribution.

**Option A: Automatic (if checkout JS exists)**
In your cart/checkout JavaScript, before or after the order is submitted:

```javascript
if (TOH_Affiliate.hasAttribution()) {
  const refCode = TOH_Affiliate.getRefCode();
  // Include refCode in the order data sent to your backend/invoice
  // When payment is confirmed, use admin panel to record the conversion
}
```

**Option B: Manual (current flow)**
When processing a manual invoice:
1. Check if the customer's order has a `toh_ref` cookie value (ask them or check the order notes)
2. Go to affiliate-admin.html > "Record Sale" tab
3. Enter the ref code, customer email, and order total
4. Click "Record Conversion"

### Step 7: Test the Flow

1. Create a test affiliate account (sign up via affiliate-dashboard.html)
2. Go to affiliate-admin.html and approve the account
3. Copy the referral link from the dashboard
4. Open an incognito window and visit the link
5. Verify the click is logged (check affiliate dashboard stats)
6. Record a test conversion via admin panel
7. Verify it shows up in both admin and affiliate dashboards

---

## How It All Connects

```
Visitor clicks affiliate link (?ref=CODE)
        |
   toh-affiliate.js validates code via Supabase RPC
        |
   Stores ref code in 30-day cookie (toh_ref)
        |
   Logs click in referral_clicks table
        |
   Cleans URL (removes ?ref= parameter)
        |
   Visitor browses, adds to cart, submits order
        |
   At checkout: TOH_Affiliate.getRefCode() returns the code
        |
   You process the invoice, confirm payment
        |
   Admin records conversion via affiliate-admin.html
        |
   Affiliate sees it in their dashboard
        |
   Monthly: Admin processes payout via admin panel
```

## Commission Logic

- Default rate: 10% flat on all sales
- Rate is per-affiliate and adjustable from admin panel
- Commission is calculated at time of conversion recording (snapshots the rate)
- Conversions start as "pending" until approved
- Payouts mark conversions as "paid"
- Minimum payout: $50 (enforced by policy, not by code)

## Security Notes

- `affiliate-admin.html` uses the Supabase service_role key (bypasses RLS)
  - Password-gated but NOT production-secure as a standalone page
  - For production: move admin operations to a Supabase Edge Function or server
  - At minimum: use a strong password and don't share the URL publicly
- `affiliate-dashboard.html` uses the anon key with RLS - affiliates only see their own data
- `toh-affiliate.js` uses anon key - can only validate codes and log clicks
- No raw IPs are stored (privacy by design)
- Customer emails are partially masked in affiliate dashboard view

## Future Enhancements (When Volume Justifies)

- Automated conversion recording via payment webhook (when you have a live payment processor)
- Tiered commission rates based on volume (the schema supports per-affiliate rates already)
- Affiliate leaderboard / top performers
- Automated monthly payout emails
- Sub-affiliate / MLM tracking (if you ever want two-tier commissions)
- Move admin operations to Supabase Edge Functions for better security
