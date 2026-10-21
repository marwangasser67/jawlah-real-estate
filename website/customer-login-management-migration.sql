-- Jawlah customer last-login tracking and dashboard list deletion.
-- Run once in Supabase Dashboard → SQL Editor after the existing admin-features migration.

alter table public.customer_accounts
  add column if not exists last_login_at timestamptz;

create or replace function public.record_customer_login()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.customer_accounts
  set last_login_at = now()
  where user_id = auth.uid();

  if not found then
    insert into public.customer_accounts (user_id, email, last_login_at)
    select id, lower(email), now()
    from auth.users
    where id = auth.uid()
      and email is not null
    on conflict (user_id) do update
      set email = excluded.email,
          last_login_at = excluded.last_login_at;
  end if;
end;
$$;

revoke all on function public.record_customer_login() from public, anon;
grant execute on function public.record_customer_login() to authenticated;

drop policy if exists "Admins can delete customer accounts" on public.customer_accounts;
create policy "Admins can delete customer accounts"
  on public.customer_accounts
  for delete to authenticated
  using (public.is_jawlah_admin());
grant delete on public.customer_accounts to authenticated;
