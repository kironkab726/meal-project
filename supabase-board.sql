-- 냥셰프 메뉴 건의함 — Supabase 설정 (supabase-setup.sql 다음에 실행)
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 내용을 전부 붙여넣고 Run 을 누르세요.
-- 여러 번 실행해도 안전합니다.


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

drop policy if exists "signed-in users read requests" on public.menu_requests;
create policy "signed-in users read requests" on public.menu_requests
  for select to authenticated
  using (true);

drop policy if exists "add own requests" on public.menu_requests;
create policy "add own requests" on public.menu_requests
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "remove own requests" on public.menu_requests;
create policy "remove own requests" on public.menu_requests
  for delete to authenticated
  using ((select auth.uid()) = user_id);
