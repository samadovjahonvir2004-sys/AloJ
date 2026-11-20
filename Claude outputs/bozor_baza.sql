-- AloJ Bozor: database schema (run once in Supabase SQL Editor)

create table if not exists public.listings (
  id           bigint generated always as identity primary key,
  owner        uuid not null default auth.uid(),
  tg_id        bigint,
  tg_name      text,
  title        text not null check (char_length(title) between 3 and 90),
  description  text check (char_length(description) <= 3000),
  price        numeric(14,2) not null check (price >= 0),
  currency     text not null default 'UZS' check (currency in ('UZS','USD')),
  category     text not null,
  city         text not null,
  condition    text not null default 'used' check (condition in ('new','used')),
  photos       text[] not null default '{}',
  status       text not null default 'active' check (status in ('active','sold','hidden','blocked')),
  top_until    timestamptz,
  views        integer not null default 0,
  reports      integer not null default 0,
  created_at   timestamptz not null default now()
);
create index if not exists listings_feed on public.listings (status, top_until desc nulls last, created_at desc);
create index if not exists listings_cat on public.listings (category, status, created_at desc);
create index if not exists listings_owner on public.listings (owner);

alter table public.listings enable row level security;

drop policy if exists "read active" on public.listings;
create policy "read active" on public.listings for select
  using (status in ('active','sold') or owner = auth.uid());
drop policy if exists "insert own" on public.listings;
create policy "insert own" on public.listings for insert to authenticated
  with check (owner = auth.uid() and status = 'active' and top_until is null and views = 0 and reports = 0);
drop policy if exists "update own" on public.listings;
create policy "update own" on public.listings for update to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid() and status <> 'blocked');
drop policy if exists "delete own" on public.listings;
create policy "delete own" on public.listings for delete to authenticated using (owner = auth.uid());

-- owners must not raise TOP/views/reports themselves; free limit: 2 active listings
create or replace function public.listings_guard() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if current_user not in ('postgres','service_role','supabase_admin') then
    if tg_op = 'INSERT' then
      if (select count(*) from listings where owner = new.owner and status = 'active') >= 2 then
        raise exception 'FREE_LIMIT';
      end if;
    else
      new.top_until := old.top_until;
      new.views := old.views;
      new.reports := old.reports;
      new.owner := old.owner;
      new.created_at := old.created_at;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists listings_guard on public.listings;
create trigger listings_guard before insert or update on public.listings
  for each row execute function public.listings_guard();

-- public counters without giving update rights
create or replace function public.listing_viewed(lid bigint) returns void language sql security definer set search_path = public as $$
  update listings set views = views + 1 where id = lid and status = 'active';
$$;
create table if not exists public.reports (
  id bigint generated always as identity primary key,
  listing_id bigint references public.listings(id) on delete cascade,
  reporter uuid not null default auth.uid(),
  reason text,
  created_at timestamptz not null default now(),
  unique (listing_id, reporter)
);
alter table public.reports enable row level security;
drop policy if exists "report" on public.reports;
create policy "report" on public.reports for insert to authenticated with check (reporter = auth.uid());
create or replace function public.reports_count() returns trigger language plpgsql security definer set search_path = public as $$
begin
  update listings set reports = reports + 1,
    status = case when reports + 1 >= 5 then 'hidden' else status end
  where id = new.listing_id;
  return new;
end $$;
drop trigger if exists reports_count on public.reports;
create trigger reports_count after insert on public.reports for each row execute function public.reports_count();

create table if not exists public.favorites (
  owner uuid not null default auth.uid(),
  listing_id bigint references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner, listing_id)
);
alter table public.favorites enable row level security;
drop policy if exists "own favs" on public.favorites;
create policy "own favs" on public.favorites for all to authenticated using (owner = auth.uid()) with check (owner = auth.uid());

-- banners (managed by you in the dashboard)
create table if not exists public.banners (
  id bigint generated always as identity primary key,
  title text not null,
  subtitle text,
  image_url text,
  link text,
  active boolean not null default true,
  sort integer not null default 0,
  until timestamptz
);
alter table public.banners enable row level security;
drop policy if exists "read banners" on public.banners;
create policy "read banners" on public.banners for select using (active and (until is null or until > now()));

-- status change through RPC (Android's HttpURLConnection has no PATCH)
create or replace function public.listing_set_status(lid bigint, st text) returns void language sql security invoker set search_path = public as $$
  update listings set status = st where id = lid and owner = auth.uid() and st in ('active','sold','hidden');
$$;

grant usage on schema public to anon, authenticated;
grant select on public.listings, public.banners to anon, authenticated;
grant insert, update, delete on public.listings to authenticated;
grant insert on public.reports to authenticated;
grant select, insert, delete on public.favorites to authenticated;
grant execute on function public.listing_viewed(bigint) to anon, authenticated;
grant execute on function public.listing_set_status(bigint, text) to authenticated;

-- photos: public bucket, each user writes only into his own folder
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 1048576, array['image/jpeg','image/webp'])
on conflict (id) do nothing;
drop policy if exists "upload own photos" on storage.objects;
create policy "upload own photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "delete own photos" on storage.objects;
create policy "delete own photos" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

insert into public.banners (title, subtitle, sort)
select * from (values ('AloJ Bozor ochildi!', 'Birinchi 2 ta e''lon bepul', 0),
                      ('Bu yerda sizning reklamangiz', 'Reklama uchun: AloJ', 1)) v
where not exists (select 1 from public.banners);
