# Jawlah Real Estate v0.3.0 – Phone OTP and official logo

This is an Arabic RTL Android Flutter demo application for **جولة العقارية**.

## v0.3.0 changes
- Official Jawlah Arabic symbol based on the provided company logo is bundled in \`assets/branding/jawlah_launcher.png\`; GitHub Actions generates Android launcher icons from it.
- Android app label becomes **جولة العقارية** instead of \`jawlah_real_estate\`.
- Phone number is now the only visible account creation/sign-in method. Email/password screens removed.
- A new user enters a phone number, receives a real SMS OTP and verifies to create a Supabase Auth user. Returning users sign in with another SMS OTP.
- Saudi local and international numbers normalize to E.164; +20 and other valid international numbers also supported. SMS delivery depends on provider coverage.
- OTP resend has a UI countdown; sensitive session tokens are stored using \`flutter_secure_storage\`. Session is checked on restart. Log out deletes local tokens.
- Guest browsing and demo listings are retained.

## SMS requirements – not active until configured by the company
1. Create/select a Supabase project **owned by the company** and enable Authentication > Phone.
2. Configure a supported real SMS service provider (e.g. Twilio) with Saudi/Egypt delivery permission and SMS billing as applicable. Configure abuse/rate limits, templates, and allowed markets.
3. In repository Settings > Secrets and variables > Actions, set \`SUPABASE_URL\` and \`SUPABASE_ANON_KEY\`. Use ONLY the public project/publishable key. Do NOT place service-role keys, SMS provider credentials or private API secrets in a mobile APK.
4. Re-run GitHub Actions. Test a real owned mobile number from end to end, wrong/expired code rejection, resend, logout, and reconnect before providing the app to a customer.
5. Review RLS, privacy/consent, SMS abuse and security before launch.

The APK will compile even without these secrets, but **real SMS and account creation will not work** until Supabase and an SMS provider are configured. Test as a guest in that case. No hardcoded/demo OTP bypass exists.

## Android GitHub Actions
Actions > Build Jawlah Android APK > latest successful run > artifact \`jawlah-v0.3.0-phone-otp-logo-apk\`. Download ZIP, extract \`app-debug.apk\`, install on Android.

Debug APK signing keys may differ between GitHub runners. If Android reports app signature conflict, back up local data, uninstall the previous debug app and then install this new build.

## Demo disclaimer
Properties, images, places and prices are illustrative—not confirmed Jawlah offers. Real booking, admin, live property database and actual notifications are not implemented yet.


## v0.4.0 responsive redesign (demo)

Main browsing experience is now in `lib/luxury_shell.dart`: polished black/gold home, responsive listing cards, category exploration, live search, advanced city/type/price/area/bedroom filters, sortable results, save favorites, three-property comparison, viewed history, mathematical payment calculator, local draft viewing calendar, local owner preview, and official website handoff. All property content remains demo-only. Draft viewings are saved to the Android device; they are **not** submitted to the real estate company. Phone authentication continues to require a configured Supabase project and SMS provider.

## v0.5.0 — Live admin catalog sync
- Published property data loads from `https://jawlah-real-estate-5sz9.hatchable.site/api/catalog`.
- Prices, categories, rooms, area, real images, full photo galleries and descriptions are supplied by the owner-controlled admin dashboard.
- Draft and archived property records remain private. CRM and financial data NEVER appear in the public catalog.
- Refresh on opening app, resuming from background, switching to Home/Search, and tapping Refresh. Graceful empty and network-error states.
- Real-time edits do NOT require a new APK release once the API can be reached.
- **Important:** The Hatchable project currently has personal/private visibility, which blocks anonymous mobile users before the public catalog route runs. The owner must go to Hatchable project Settings and set visibility to Public. The dashboard's HTML page remains protected by `pages/index.js: access='admin'`; all `/api/admin/*` routes remain `access='admin'`.
- In the admin panel, property status **جاهز للعرض** is required for appearance in the APK. Images have a stable gated /api/catalog-image/:id redirect that checks the property's published state before serving.
- Requests/appointments still save locally on-device; backend CRM integration is a separate future feature.

## v0.6.0 — Owner-managed customer app content
- The customer app reads property data, images, custom sections and approved homepage settings from the public read-only `/api/catalog` route hosted by Hatchable.
- New admin-only section: **تخصيص تطبيق العملاء**, editing app/hero copy, featured property background image, a public announcement, published promotions, dynamic property categories, comparison/calculator/viewing/owner-submission visibility, and contact buttons.
- Owners can add custom home sections, linked to approved property pages, and reorder or hide them without shipping a new APK.
- Personal customer and financial data is never present in the public catalog and all admin endpoints stay `access='admin'`.
- A separate Android admin launcher is built with `flutter build apk --target lib/admin_main.dart` using the workflow `admin-apk.yml`; package ID `sa.jawlah.admin` allows side-by-side installation with the customer app. It uses Android Chrome Custom Tabs (browser login, not storing passwords inside the APK) plus an external Chrome fallback.
- **Required configuration:** Hatchable project visibility is currently private/personal and MUST be changed by the owner to Public via Hatchable Settings to make the customer-facing catalog accessible to guest devices. The dashboard page itself is protected by admin-only route `pages/index.js` and the internal API endpoints are gated.
- Content updates are live when the user refreshes the app. Entirely new native app flows or screen layouts beyond supplied content blocks still require a new Flutter release.
- Customer viewing form and owner-submission form are still **local-only**; they do not create leads or send data to the company's back office.
