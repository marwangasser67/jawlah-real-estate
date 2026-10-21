# Jawlah Real Estate Website

Responsive Arabic RTL real-estate website and admin dashboard for Jawlah.

## Source files
- `index.html` — page structure and Arabic copy
- `styles.css` — responsive layout and visual styling
- `app.js` — navigation, filters, map markers, property galleries, unit selector, and interest form
- `admin.html`, `admin.css`, `admin.js` — protected property management dashboard (Supabase Auth required)
- `supabase-config.js` — project URL and public publishable key configuration
- `supabase-schema.sql` — database tables, storage bucket and Row Level Security policies
- `ADMIN_SETUP_AR.md` — Arabic setup instructions for the Supabase project
- `assets/` — Jawlah logo and property photography

## Run locally
Open `index.html` in a modern browser. No build tools or external libraries are required.

## Notes
- Until Supabase is configured, the website shows clearly marked demonstration listings and the admin page displays setup instructions.
- After applying the SQL and setting a publishable key, published property records load from Supabase; the admin can create, edit, publish, archive or delete records and upload photos.
- Never add a Supabase `service_role` or secret key to this public website repository.
- The property interest form still uses demonstration behavior; it does not yet save customer inquiries in Supabase.
- The Flutter Android app remains in the repository root under `lib/` and is not connected to this Supabase database in this update.
