# Jawlah Real Estate — Android-only cloud build starter

This is an **initial runnable prototype**, not a complete production app. It supports Arabic RTL, demo listings, search/type filters, property details, Supabase property reads, and email authentication after configuration.

## From Android Chrome
1. Create a free GitHub repository, e.g. `jawlah-real-estate`.
2. Upload `pubspec.yaml`, `lib/main.dart`, `supabase/schema.sql`, and `.github/workflows/android-apk.yml` preserving folders. GitHub mobile web may be easier in **Desktop site** mode.
3. Go to [supabase.com](https://supabase.com), create a project, open SQL Editor and run `supabase/schema.sql`.
4. In Supabase Project Settings / API (or Connect), find **Project URL** and **publishable/anon public key**. Never use the service_role or secret key in the mobile app.
5. In GitHub repository **Settings → Secrets and variables → Actions**, add repository secrets `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
6. In GitHub **Actions → Build Android APK → Run workflow**. The workflow also runs on pushes to main.
7. When the workflow succeeds, open its run → **Artifacts → jawlah-debug-apk**, download the ZIP, extract it on Android, and install `app-debug.apk` (allow installation from that source if prompted).
8. If Android warns about an unknown developer, that is expected for an unsigned-for-release debug test APK. Do not distribute this as a Play Store production release.

## Important
- `flutter create` in CI generates Android scaffolding, so the ZIP includes only custom source/configuration.
- No iOS binary is built by this workflow. iOS needs a separate macOS signing/build workflow and Apple developer provisioning.
- The demo record is fictional. Replace it with company-approved listings.
- Current SQL grants public read only for published listings. No mobile client writes are allowed for properties.
- Admin dashboard, favorites, appointments, push notifications, real listing images, payment integrations, production release signing and store deployment are **not implemented yet**.
