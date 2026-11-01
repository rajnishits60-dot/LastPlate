# SurplusLink Website

SurplusLink is a responsive food-rescue web app connecting food donors with NGOs.

## Included
- `index.html` — complete website (HTML, CSS and JavaScript)
- `schema.sql` — Supabase database schema, Row Level Security policies, pickup-code verification function and realtime setup

## 1. Create the Supabase backend
1. Create a project at https://supabase.com/.
2. Open **SQL Editor** in your Supabase dashboard.
3. Paste the full contents of `schema.sql` and run it.
4. In **Project Settings → API**, copy the Project URL and the `anon` / publishable public key.

## 2. Connect the website to Supabase
1. Open `index.html` in VS Code.
2. Near the top of the script, find:

   ```js
   const CFG={url:"PASTE_SUPABASE_URL",key:"PASTE_SUPABASE_ANON_KEY"};
   ```

3. Replace the placeholders with your Supabase Project URL and public anon/publishable key. Keep the quotation marks.
4. Save the file.

Do not put a Supabase `service_role` or secret key in the website. The browser must only use the public anon/publishable key.

## 3. Create the first admin
1. Open the website and create an account.
2. Choose **Admin** during registration.
3. Confirm the email if Supabase email confirmation is enabled, then sign in.
4. In Supabase **SQL Editor**, run the following query after replacing the email:

   ```sql
   update profiles
   set status = 'approved'
   where id = (select id from auth.users where email = 'YOUR_ADMIN_EMAIL');
   ```

5. Sign out and sign in again. The admin panel can then approve donor and NGO registrations.

## 4. Run locally
You can open `index.html` directly, or use the VS Code Live Server extension:
1. Open this folder in VS Code.
2. Right-click `index.html`.
3. Select **Open with Live Server**.

Use `http://localhost` / HTTPS for browser geolocation. The live map and location sharing require the user to grant location permission.

## 5. Deploy online
This is a static website. You can deploy the folder (or its contents) to Netlify, Vercel, or GitHub Pages after completing the Supabase configuration. Keep `index.html` and `schema.sql` together in your project for future maintenance.

## Main features in this version
- Donor, NGO and admin registration/sign-in
- Admin approval and rejection of accounts
- Donor food listing and food-safety time-window estimate
- NGO matching based on distance, estimated travel time and capacity
- Pickup requests, accept/reject and pickup history
- Live map/location sharing during active pickups
- QR code and six-digit pickup verification
- Realtime request/profile refresh
- Admin dashboard for meals rescued, food diverted and requests

## Important notes
- The food-safety calculation is a basic estimate, not a food-safety certification. Use local food-safety guidance and inspect food before donation.
- Estimated road distance and arrival time are approximations; the current implementation uses straight-line distance with a multiplier.
- Supabase email confirmation, authentication settings and database policies must be configured correctly for your deployment.
- Never share the donor pickup code publicly; share it only at handover.
