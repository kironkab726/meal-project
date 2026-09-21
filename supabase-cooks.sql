-- 냥빵이 요리 자랑 — Supabase 설정 (supabase-setup.sql 다음에 실행)
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 내용을 전부 붙여넣고 Run 을 누르세요.
-- 여러 번 실행해도 안전합니다.
--
-- 만드는 것
--   profiles      닉네임 (자랑 글에 이메일 대신 보여 줌)
--   cooks         완성한 요리 기록. is_public 이 true 면 "모두의 요리"에 자랑, false 면 나만 봄
--   cook_reports  신고. 서로 다른 사람 3명이 신고한 글은 자동으로 가려짐
--   cook-photos   요리 사진을 담는 Storage 버킷 (사진 한 장에 큰 사진 + 작은 사진 두 파일)
--
-- 운영자가 글을 지우려면: Table Editor → cooks 에서 그 줄을 지우고,
-- Storage → cook-photos 에서 photo_path 에 적힌 사진(과 이름 끝이 _s.jpg 인 작은 사진)을 지우면 돼요.


-- 1) 닉네임 ------------------------------------------------------------------
create table if not exists public.profiles (
  user_id    uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  nickname   text not null check (nickname ~ '^[가-힣A-Za-z0-9_]{2,12}$'),
  created_at timestamptz not null default now()
);

-- 대소문자만 다른 같은 닉네임도 막음
create unique index if not exists profiles_nickname_key on public.profiles (lower(nickname));


-- 2) 완성한 요리 ------------------------------------------------------------
create table if not exists public.cooks (
  id         bigint generated always as identity primary key,
  user_id    uuid not null default auth.uid() references public.profiles (user_id) on delete cascade,
  menu_id    bigint references public.menus (id) on delete set null,
  menu_name  text not null check (char_length(btrim(menu_name)) between 1 and 30),
  photo_path text check (photo_path is null or photo_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'),
  comment    text check (comment is null or char_length(comment) <= 100),
  is_public  boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists cooks_public_created_idx on public.cooks (created_at desc) where is_public;
create index if not exists cooks_user_created_idx on public.cooks (user_id, created_at desc);


-- 3) 신고 (한 사람이 한 글에 한 번) --------------------------------------------
create table if not exists public.cook_reports (
  cook_id    bigint not null references public.cooks (id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (cook_id, user_id)
);

-- 신고가 3개 이상인지 (신고한 사람은 숨기고 개수만 알려 줌)
create or replace function public.cook_is_hidden(p_cook_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select count(*) >= 3 from public.cook_reports where cook_id = p_cook_id
$$;

revoke all on function public.cook_is_hidden(bigint) from public;
grant execute on function public.cook_is_hidden(bigint) to anon, authenticated;


-- 4) 권한 -------------------------------------------------------------------
alter table public.profiles     enable row level security;
alter table public.cooks        enable row level security;
alter table public.cook_reports enable row level security;

revoke all on public.profiles, public.cooks, public.cook_reports from anon, authenticated;
grant select on public.profiles to anon, authenticated;
grant insert, update (nickname) on public.profiles to authenticated;
grant select on public.cooks to anon, authenticated;
grant insert, delete, update (is_public, comment) on public.cooks to authenticated;
grant select, insert on public.cook_reports to authenticated;

-- 닉네임: 누구나 읽기, 만들고 고치기는 본인 것만
drop policy if exists "nicknames are readable by everyone" on public.profiles;
create policy "nicknames are readable by everyone" on public.profiles
  for select to anon, authenticated
  using (true);

drop policy if exists "create own profile" on public.profiles;
create policy "create own profile" on public.profiles
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "rename own profile" on public.profiles;
create policy "rename own profile" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 요리: 공개 글은 누구나(신고로 가려진 글 빼고), 비공개 글은 본인만
drop policy if exists "public cooks are readable" on public.cooks;
create policy "public cooks are readable" on public.cooks
  for select to anon, authenticated
  using (is_public and not public.cook_is_hidden(id));

drop policy if exists "read own cooks" on public.cooks;
create policy "read own cooks" on public.cooks
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "add own cooks" on public.cooks;
create policy "add own cooks" on public.cooks
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and (photo_path is null or photo_path like (select auth.uid())::text || '/%')
  );

drop policy if exists "edit own cooks" on public.cooks;
create policy "edit own cooks" on public.cooks
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "remove own cooks" on public.cooks;
create policy "remove own cooks" on public.cooks
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 신고: 로그인한 사람이 남의 공개 글에만, 내가 한 신고만 볼 수 있음
drop policy if exists "report others' public cooks" on public.cook_reports;
create policy "report others' public cooks" on public.cook_reports
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.cooks c
      where c.id = cook_id and c.is_public and c.user_id <> (select auth.uid())
    )
  );

drop policy if exists "read own reports" on public.cook_reports;
create policy "read own reports" on public.cook_reports
  for select to authenticated
  using ((select auth.uid()) = user_id);


-- 5) 사진 저장소 --------------------------------------------------------------
-- 공개 버킷: 사진 주소를 아는 사람은 볼 수 있음 (주소에 무작위 글자가 들어가서 짐작할 수 없음)
-- 사진은 올리기 전에 브라우저에서 줄이고 JPEG로 다시 저장해서, 찍은 위치 같은 정보가 빠짐
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cook-photos', 'cook-photos', true, 1048576, array['image/jpeg'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 자기 폴더(사용자 번호 이름)에만 올리고 지울 수 있음. 지우기에는 읽기 권한도 필요함
drop policy if exists "upload own cook photos" on storage.objects;
create policy "upload own cook photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'cook-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "see own cook photo files" on storage.objects;
create policy "see own cook photo files" on storage.objects
  for select to authenticated
  using (bucket_id = 'cook-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "delete own cook photos" on storage.objects;
create policy "delete own cook photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'cook-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
