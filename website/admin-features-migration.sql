-- Jawlah admin additions: customer accounts, inquiries, site settings and brand uploads.
-- Run this once in Supabase Dashboard → SQL Editor after supabase-schema.sql.

create table if not exists public.customer_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  created_at timestamptz not null default now()
);
alter table public.customer_accounts enable row level security;
drop policy if exists "Customers read own account or admins read all" on public.customer_accounts;
create policy "Customers read own account or admins read all"
  on public.customer_accounts for select to authenticated
  using (user_id = (select auth.uid()) or public.is_jawlah_admin());
grant select on public.customer_accounts to authenticated;

-- Allow an authenticated manager to identify admin accounts and keep them out of the customer list.
drop policy if exists "Admins can read all admin memberships" on public.admin_users;
create policy "Admins can read all admin memberships"
  on public.admin_users for select to authenticated
  using (public.is_jawlah_admin());

create or replace function public.capture_customer_account()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is not null then
    insert into public.customer_accounts (user_id, email)
    values (new.id, lower(new.email))
    on conflict (user_id) do update set email = excluded.email;
  end if;
  return new;
end;
$$;
revoke all on function public.capture_customer_account() from public, anon, authenticated;
drop trigger if exists jawlah_capture_customer_account on auth.users;
create trigger jawlah_capture_customer_account
  after insert or update of email on auth.users
  for each row execute function public.capture_customer_account();

-- Backfill accounts that already exist so the dashboard can list them.
insert into public.customer_accounts (user_id, email, created_at)
select id, lower(email), coalesce(created_at, now())
from auth.users
where email is not null
on conflict (user_id) do update set email = excluded.email;

create table if not exists public.customer_inquiries (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid references auth.users(id) on delete set null,
  name text not null check (length(name) between 1 and 150),
  phone text not null check (length(phone) between 3 and 40),
  email text,
  note text not null default '' check (length(note) <= 3000),
  property_id text not null,
  property_title text not null,
  units integer not null default 1 check (units > 0),
  estimated_total numeric(14,2) not null default 0 check (estimated_total >= 0),
  created_at timestamptz not null default now()
);
create index if not exists customer_inquiries_created_idx
  on public.customer_inquiries (created_at desc);
alter table public.customer_inquiries enable row level security;
drop policy if exists "Public can submit property inquiries" on public.customer_inquiries;
create policy "Public can submit property inquiries"
  on public.customer_inquiries for insert to anon, authenticated
  with check (
    (customer_user_id is null or customer_user_id = (select auth.uid()))
    and length(trim(name)) > 0
    and length(trim(phone)) >= 3
  );
drop policy if exists "Admins can read inquiries" on public.customer_inquiries;
create policy "Admins can read inquiries"
  on public.customer_inquiries for select to authenticated
  using (public.is_jawlah_admin());
drop policy if exists "Admins can delete inquiries" on public.customer_inquiries;
create policy "Admins can delete inquiries"
  on public.customer_inquiries for delete to authenticated
  using (public.is_jawlah_admin());
grant insert on public.customer_inquiries to anon, authenticated;
grant select, delete on public.customer_inquiries to authenticated;

create table if not exists public.site_settings (
  id smallint primary key default 1 check (id = 1),
  logo_url text,
  home_hero_url text,
  contact_phone text not null default '',
  social_links jsonb not null default '{}'::jsonb,
  nav_links jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.site_settings enable row level security;
drop policy if exists "Public can read site settings" on public.site_settings;
create policy "Public can read site settings"
  on public.site_settings for select to anon, authenticated using (true);
drop policy if exists "Admins can insert site settings" on public.site_settings;
create policy "Admins can insert site settings"
  on public.site_settings for insert to authenticated with check (public.is_jawlah_admin());
drop policy if exists "Admins can update site settings" on public.site_settings;
create policy "Admins can update site settings"
  on public.site_settings for update to authenticated
  using (public.is_jawlah_admin()) with check (public.is_jawlah_admin());
grant select on public.site_settings to anon, authenticated;
grant insert, update on public.site_settings to authenticated;
insert into public.site_settings (id) values (1) on conflict (id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('site-assets', 'site-assets', true, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "Public can view site assets" on storage.objects;
create policy "Public can view site assets"
  on storage.objects for select to anon, authenticated using (bucket_id = 'site-assets');
drop policy if exists "Admins can upload site assets" on storage.objects;
create policy "Admins can upload site assets"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'site-assets' and public.is_jawlah_admin());
drop policy if exists "Admins can update site assets" on storage.objects;
create policy "Admins can update site assets"
  on storage.objects for update to authenticated
  using (bucket_id = 'site-assets' and public.is_jawlah_admin())
  with check (bucket_id = 'site-assets' and public.is_jawlah_admin());
drop policy if exists "Admins can delete site assets" on storage.objects;
create policy "Admins can delete site assets"
  on storage.objects for delete to authenticated
  using (bucket_id = 'site-assets' and public.is_jawlah_admin());
