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
