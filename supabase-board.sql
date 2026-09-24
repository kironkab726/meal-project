-- 냥빵이 메뉴 건의함 — Supabase 설정 (supabase-setup.sql 다음에 실행)
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 내용을 전부 붙여넣고 Run 을 누르세요.
-- 여러 번 실행해도 안전합니다.
--
-- 운영자가 건의를 지우려면: Table Editor → menu_requests 에서 그 줄을 지우면 신고 기록도 함께 지워져요.


-- 1) 건의 글 ---------------------------------------------------------------
create table if not exists public.menu_requests (
  id         bigint generated always as identity primary key,
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  menu_name  text not null check (char_length(btrim(menu_name)) between 1 and 30),
  meal       text not null check (meal in ('아침', '점심', '저녁')),
  created_at timestamptz not null default now()
);

create index if not exists menu_requests_created_idx on public.menu_requests (created_at desc);


-- 2) 권한: 로그인한 사람만 읽기/쓰기, 지우기는 본인 글만 ------------------------
alter table public.menu_requests enable row level security;

revoke all on public.menu_requests from anon;
grant select, insert, delete on public.menu_requests to authenticated;

-- 읽기 규칙("signed-in users read requests")은 신고 함수가 있어야 해서 아래 3)에서 만듦

-- 쓰기는 본인 이름으로만, 24시간에 10개까지 (도배 막기)
drop policy if exists "add own requests" on public.menu_requests;
create policy "add own requests" on public.menu_requests
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and (
      select count(*) from public.menu_requests r
      where r.user_id = (select auth.uid()) and r.created_at > now() - interval '1 day'
    ) < 10
  );

drop policy if exists "remove own requests" on public.menu_requests;
create policy "remove own requests" on public.menu_requests
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 3) 신고 (한 사람이 한 건의에 한 번, 2026-09-25 추가) ---------------------------
-- 서로 다른 사람 3명이 신고한 건의는 쓴 사람 말고는 아무에게도 안 보임
-- 구글 플레이 정책: 이용자가 올린 글은 앱 안에서 신고할 수 있어야 함
create table if not exists public.request_reports (
  request_id bigint not null references public.menu_requests (id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (request_id, user_id)
);

-- 신고가 3개 이상인지 (권한 규칙 안에서만 쓰는 함수라 API로 부를 수 없는 private 스키마에 둠)
create schema if not exists private;
grant usage on schema private to anon, authenticated;

create or replace function private.request_is_hidden(p_request_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select count(*) >= 3 from public.request_reports where request_id = p_request_id
$$;

revoke all on function private.request_is_hidden(bigint) from public;
grant execute on function private.request_is_hidden(bigint) to authenticated;

alter table public.request_reports enable row level security;
revoke all on public.request_reports from anon, authenticated;
grant select, insert on public.request_reports to authenticated;

-- 건의 읽기 규칙을 바꿈: 내 건의는 늘, 남의 건의는 신고로 가려지지 않은 것만
drop policy if exists "signed-in users read requests" on public.menu_requests;
create policy "signed-in users read requests" on public.menu_requests
  for select to authenticated
  using ((select auth.uid()) = user_id or not private.request_is_hidden(id));

-- 신고: 로그인한 사람이 남의 건의에만, 내가 한 신고만 볼 수 있음
drop policy if exists "report others' requests" on public.request_reports;
create policy "report others' requests" on public.request_reports
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.menu_requests r
      where r.id = request_id and r.user_id <> (select auth.uid())
    )
  );

drop policy if exists "read own request reports" on public.request_reports;
create policy "read own request reports" on public.request_reports
  for select to authenticated
  using ((select auth.uid()) = user_id);
