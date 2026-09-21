-- 냥빵이 회원 탈퇴 — Supabase 설정 (다른 SQL 파일들 다음에 실행)
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 내용을 전부 붙여넣고 Run 을 누르세요.
-- 여러 번 실행해도 안전합니다.
--
-- 로그인한 사람이 사이트의 "내 계정 → 회원 탈퇴"를 누르면 부르는 함수예요.
-- 부른 사람 "자기 계정"만 지울 수 있고, 계정이 지워지면 연결된 기록이 함께 지워져요
-- (추천 기록, 좋아요/별로예요, 메뉴 건의, 닉네임, 요리 기록, 신고 — 모두 on delete cascade).
-- 요리 사진 파일은 SQL로 지울 수 없어서, 사이트가 이 함수를 부르기 전에 먼저 지워요 (common.js).
--
-- Security Advisor 가 이 함수에 "Signed-In Users Can Execute SECURITY DEFINER Function" 경고를 띄우는데,
-- 로그인한 사람이 자기 계정을 지우려면 꼭 필요한 권한이라 그대로 둬도 돼요.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception '로그인한 사람만 탈퇴할 수 있어요' using errcode = '42501';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

-- 로그인하지 않은 사람은 부를 수 없게
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
