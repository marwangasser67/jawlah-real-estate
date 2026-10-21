-- Jawlah website: secure property catalogue and image storage.
-- Run in Supabase Dashboard → SQL Editor → New query → Run.

create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  property_type text not null check (property_type in ('شقة', 'فيلا', 'أرض')),
  deal_type text not null default 'للبيع' check (deal_type in ('للبيع', 'للإيجار')),
  city text not null,
  district text not null default '',
  price_sar numeric(14,2) not null default 0 check (price_sar >= 0),
  available_units integer not null default 0 check (available_units >= 0),
  sold_percent integer not null default 0 check (sold_percent between 0 and 100),
  area_sqm numeric(10,2) not null default 0 check (area_sqm >= 0),
  bedrooms integer,
  bathrooms integer,
  description text not null default '',
  cover_image_url text,
  gallery_urls jsonb not null default '[]'::jsonb,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  map_x numeric(5,2) not null default 50 check (map_x between 0 and 100),
  map_y numeric(5,2) not null default 50 check (map_y between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists properties_public_status_created_idx
  on public.properties (status, created_at desc);
create index if not exists properties_type_city_idx
  on public.properties (property_type, city);

create or replace function public.set_property_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists properties_set_updated_at on public.properties;
create trigger properties_set_updated_at
before update on public.properties
for each row execute function public.set_property_updated_at();

alter table public.admin_users enable row level security;
alter table public.properties enable row level security;

create or replace function public.is_jawlah_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid());
$$;
revoke all on function public.is_jawlah_admin() from public;
grant execute on function public.is_jawlah_admin() to anon, authenticated;

drop policy if exists "Admins can read their own membership" on public.admin_users;
create policy "Admins can read their own membership"
  on public.admin_users for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "Public can read published properties" on public.properties;
create policy "Public can read published properties"
  on public.properties for select to anon, authenticated
  using (
    status = 'published'
    or public.is_jawlah_admin()
  );

drop policy if exists "Admins can insert properties" on public.properties;
create policy "Admins can insert properties"
  on public.properties for insert to authenticated
  with check (public.is_jawlah_admin());

drop policy if exists "Admins can update properties" on public.properties;
create policy "Admins can update properties"
  on public.properties for update to authenticated
  using (public.is_jawlah_admin())
  with check (public.is_jawlah_admin());

drop policy if exists "Admins can delete properties" on public.properties;
create policy "Admins can delete properties"
  on public.properties for delete to authenticated
  using (public.is_jawlah_admin());

grant select on public.properties to anon, authenticated;
grant insert, update, delete on public.properties to authenticated;
grant select on public.admin_users to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('property-images', 'property-images', true, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public;

drop policy if exists "Public can view property images" on storage.objects;
create policy "Public can view property images"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'property-images');

drop policy if exists "Admins can upload property images" on storage.objects;
create policy "Admins can upload property images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'property-images'
    and public.is_jawlah_admin()
  );

drop policy if exists "Admins can update property images" on storage.objects;
create policy "Admins can update property images"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'property-images'
    and public.is_jawlah_admin()
  )
  with check (
    bucket_id = 'property-images'
    and public.is_jawlah_admin()
  );

drop policy if exists "Admins can delete property images" on storage.objects;
create policy "Admins can delete property images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'property-images'
    and public.is_jawlah_admin()
  );

-- After creating the manager in Authentication → Users, enable access like this:
-- Replace the email, then run this statement in the SQL Editor.
-- insert into public.admin_users (user_id)
-- select id from auth.users where lower(email) = lower('admin@example.com')
-- on conflict (user_id) do nothing;
