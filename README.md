# Jawlah Real Estate — Black & Gold Android demo

Arabic RTL Flutter app for Jawlah Real Estate. Version 0.2.0.

## Screens
- Cinematic welcome
- Email/password login, registration and password reset (Supabase only when configured)
- Phone code request and verification (Supabase Auth + SMS provider must be enabled)
- Dark/gold browsing home, search, city/type filters
- Property details, local favorites, empty notifications, profile, guest access

## Important truthfulness & limitations
Listings, property descriptions, photographs, prices, locations and amounts in the app are **illustrative demo content**, not verified company property offers. A styled Flutter UI is not a screenshot-perfect copy of generated marketing mockups. The company emblem is temporarily represented by text and a building icon, not the source vector logo. Google and Apple sign-in have NOT been implemented. Real appointments, messaging inbox, admin panel, property database, and persistent user sessions are not yet implemented. Website button opens https://www.jawlahre.sa.

## Android-only GitHub build
1. Open GitHub **Actions > Build Jawlah Android APK**.
2. Open the latest successful workflow run for the most recent commit.
3. Open **Artifacts > jawlah-luxury-android-apk** and download the ZIP.
4. Extract ZIP on Android and install `app-debug.apk`.
5. If Android reports a signing conflict, back up any data you need, uninstall the previous Jawlah debug app on your own Android device and install the new APK. Installing a debug APK is for testing only.

## Enable actual Supabase Auth
Create a Supabase project and enable the desired methods under Authentication.
- On GitHub repository, **Settings > Secrets and variables > Actions**, define `SUPABASE_URL` and `SUPABASE_ANON_KEY` with the public URL and publishable/anon key.
- Do **not** use the service_role or secret key in the mobile application.
- For phone OTP, enable Phone authentication and configure a real SMS sender in Supabase. It is not enabled merely by creating a UI.
- Rerun workflow manually after setting secrets.
- Email login and registration use Supabase HTTPS Auth endpoints. Sessions are kept in memory for this demo and are not persisted securely yet.

For store distribution, use a stable signing key, add secure auth session management, replace the placeholder listings with verified company content, and complete QA and legal/privacy review.
