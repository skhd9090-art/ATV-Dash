# Crypto Wall — TV & Mobile Realtime Dashboard

Realtime multi-screen crypto trading dashboard designed for synchronized display between an Android TV browser and a mobile/desktop browser. Both devices use the **exact same UI and exact same URL**. Changes to watchlist symbols, visible TradingView charts, candle intervals, and column layouts synchronize instantly across devices via Supabase.

---

## Architecture & Features

- **Binance WebSocket Feed:** Streamlines live tick-by-tick prices and 24h percentage changes directly from Binance public feeds (`wss://stream.binance.com:9443`).
- **Interactive TradingView Embeds:** Dynamically loaded dark-mode candlestick charts supporting custom intervals (`1m`, `5m`, `15m`, `30m`, `1h`, `4h`, `1D`, `1W`).
- **Real-Time Device Synchronization:**
  - **Supabase Realtime Broadcast:** Delivers millisecond-level state sync across open browsers.
  - **PostgreSQL Persistence:** Backed by Supabase database RPCs (`save_dashboard_state` and `get_dashboard_state`).
  - **Loop & Race Condition Prevention:** Timestamped updates (Last-Write-Wins), defensive execution blocks (`try...finally`), and unique client IDs ensure updates never trigger infinite synchronization loops.
  - **Wake & Reconnect Handling:** Re-fetches the latest dashboard state upon channel reconnection, network online events, and tab visibility changes (crucial for TV and mobile screen wake-ups).
- **Security & Key Separation:**
  - Keeps the Supabase publishable/anon key in `supabase-config.js` (safe for client-side code).
  - Keeps the private **Room Key** out of public GitHub code by supporting URL hash parameter pairing (`#key=...&room=...`) and persistent browser `localStorage`.
  - Built-in Pairing & Key Generator modal with 1-click pairing link generator.
- **TV Display Mode:** Fullscreen, edge-to-edge layout optimized for Android TV remote navigation and large screens.

---

## Quick Setup Guide

### 1. Configure Supabase

1. Log in or create a free account at [supabase.com](https://supabase.com).
2. Create a new project (e.g. `crypto-wall`).
3. In the left navigation bar, open **SQL Editor**, click **New query**, paste the entire contents of [`supabase-schema.sql`](./supabase-schema.sql), and click **Run**.
4. In your Supabase project dashboard, navigate to **Project Settings** > **API**:
   - Copy the **Project URL** (e.g. `https://your-project-id.supabase.co`).
   - Copy the **Project API Keys** > `anon` / `public` key (or modern Publishable Key).
   - ⚠️ **NEVER use or expose the `service_role` or secret key in frontend code.**

### 2. Configure `supabase-config.js`

Edit [`supabase-config.js`](./supabase-config.js):
```javascript
window.CRYPTO_WALL_CONFIG = {
  url: "https://YOUR_PROJECT_ID.supabase.co",
  anonKey: "YOUR_SUPABASE_ANON_KEY",
  dashboardId: "living-room-crypto-wall",
  // Leave empty or placeholder if you want to pair privately via URL hash/localStorage
  roomKey: "",
  clientId: "browser"
};
```

### 3. Deploy to GitHub Pages

1. Commit and push the repository files to GitHub:
   ```bash
   git add .
   git commit -m "Deploy Crypto Wall Dashboard"
   git push origin main
   ```
2. In your GitHub repository:
   - Go to **Settings** > **Pages**.
   - Under **Build and deployment** > **Source**, choose **Deploy from a branch**.
   - Select branch **`main`** and folder **`/ (root)`**, then click **Save**.
3. GitHub Pages will build and publish your site at:
   `https://<your-github-username>.github.io/<repo-name>/`

---

## Device Pairing (Phone & Android TV)

Because GitHub Pages repositories are often public, **never hardcode your private room key into git history**. Instead, use the built-in Pairing system:

1. Open the dashboard on your phone or computer.
2. In the right sidebar under **DEVICE / SYNC**, click **🔗 Pairing & Keys**.
3. Click **🎲 Gen** to generate a secure random 32-character Room Key (must be ≥ 20 characters).
4. Click **Save & Connect**.
5. Click **📋 Copy Pairing URL**. This copies a URL formatted with a secure URL fragment:
   `https://<your-username>.github.io/<repo>/#room=living-room-crypto-wall&key=room_XXXXX`
   *(URL fragments `#...` are processed strictly client-side by the browser and are never transmitted to GitHub servers or logged).*
6. Open that exact URL on your Android TV browser once:
   - The key is automatically saved into the TV browser's `localStorage`.
   - Both devices are now securely paired and synchronizing in real time!

---

## Security Review & Authentication Options

### Current Architecture (Room-Key RPC Isolation)
- `crypto_wall_rooms` has PostgreSQL Row Level Security (RLS) enabled and **all table permissions revoked from `anon` and `authenticated`**.
- Direct table reads/writes are completely blocked.
- State can only be read or written via the two `SECURITY DEFINER` functions:
  - `get_dashboard_state(p_dashboard_id, p_room_key)`
  - `save_dashboard_state(p_dashboard_id, p_room_key, p_state)`
- Both functions strictly require a valid `room_key` of at least 20 characters matching the row.
- Storing the `room_key` in the browser URL hash (`#key=...`) or `localStorage` keeps it private and completely out of GitHub source code.

### Optional: Full Supabase User Authentication (Auth + RLS)
If you require formal multi-user isolation with login credentials:
1. Enable Email/Password or Magic Link auth in **Supabase Auth Settings**.
2. Add a `user_id uuid references auth.users(id) default auth.uid()` column to `crypto_wall_rooms`.
3. Add RLS policies:
   ```sql
   create policy "Users manage own dashboard"
     on public.crypto_wall_rooms
     for all
     using (auth.uid() = user_id)
     with check (auth.uid() = user_id);
   ```
4. Authenticate users via `supabaseClient.auth.signInWithPassword()` or magic links.
*(Note: Typing passwords on Android TV remotes can be tedious, which is why the URL hash / pairing key method is typically preferred for TV companion displays).*
