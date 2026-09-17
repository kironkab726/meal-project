-- 오늘 뭐 먹지 — Supabase 설정
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 내용을 전부 붙여넣고 Run 을 누르세요.
-- 여러 번 실행해도 안전합니다 (이미 있는 테이블과 메뉴는 건너뜁니다).


-- 1) 메뉴 목록 ------------------------------------------------------------
-- 메뉴 추가/삭제는 Table Editor → menus 에서 하면 됩니다.
create table if not exists public.menus (
  id         bigint generated always as identity primary key,
  meal       text not null,   -- 아침 / 점심 / 저녁
  category   text not null,   -- 한식, 중식 ...
  name       text not null,   -- 메뉴 이름
  photo      text,            -- 위키미디어 공용 사진 파일명 (없으면 비워두기)
  created_at timestamptz not null default now(),
  unique (meal, name)
);


-- 2) 추천 기록 (로그인한 사람마다 따로) -------------------------------------
create table if not exists public.picks (
  id         bigint generated always as identity primary key,
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  menu_id    bigint references public.menus (id) on delete set null,
  meal       text not null,
  category   text not null,
  menu_name  text not null,
  created_at timestamptz not null default now()
);

create index if not exists picks_user_created_idx on public.picks (user_id, created_at desc);


-- 3) 좋아요 / 별로예요 (사람 × 메뉴마다 하나) --------------------------------
create table if not exists public.reactions (
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  menu_id    bigint not null references public.menus (id) on delete cascade,
  reaction   text not null check (reaction in ('like', 'dislike')),
  updated_at timestamptz not null default now(),
  primary key (user_id, menu_id)
);


-- 4) 권한: 메뉴는 누구나 읽기만, 기록과 좋아요는 본인 것만 ---------------------
alter table public.menus     enable row level security;
alter table public.picks     enable row level security;
alter table public.reactions enable row level security;

grant select on public.menus to anon, authenticated;
grant select, insert on public.picks to authenticated;
grant select, insert, update, delete on public.reactions to authenticated;

drop policy if exists "menus are readable by everyone" on public.menus;
create policy "menus are readable by everyone" on public.menus
  for select to anon, authenticated
  using (true);

drop policy if exists "read own picks" on public.picks;
create policy "read own picks" on public.picks
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "add own picks" on public.picks;
create policy "add own picks" on public.picks
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "read own reactions" on public.reactions;
create policy "read own reactions" on public.reactions
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "add own reactions" on public.reactions;
create policy "add own reactions" on public.reactions
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "change own reactions" on public.reactions;
create policy "change own reactions" on public.reactions
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "remove own reactions" on public.reactions;
create policy "remove own reactions" on public.reactions
  for delete to authenticated
  using ((select auth.uid()) = user_id);


-- 5) 처음 메뉴 99개 넣기 ------------------------------------------------------
insert into public.menus (meal, category, name, photo) values
  -- 아침
  ('아침', '한식', '누룽지', 'Korean.food-Nurungji-01.jpg'),
  ('아침', '한식', '전복죽', 'Korean_abalone_porridge-Jeonbokjuk-01A.jpg'),
  ('아침', '한식', '간장계란밥', 'Ganjang-gyeran-bap_3.jpg'),
  ('아침', '한식', '계란말이', 'Gyeran-mari.jpg'),
  ('아침', '한식', '미역국', 'Miyeok-guk.jpg'),
  ('아침', '한식', '황태해장국', 'Hwangtae-haejang-guk.jpg'),
  ('아침', '한식', '떡국', 'Tteokguk.jpg'),
  ('아침', '양식', '토스트', 'Butter_Toast.jpg'),
  ('아침', '양식', '프렌치토스트', 'FrenchToast.JPG'),
  ('아침', '양식', '팬케이크', 'Blueberry_pancakes_(3).jpg'),
  ('아침', '양식', '오믈렛', 'FoodOmelete.jpg'),
  ('아침', '양식', '에그 베네딕트', 'Traditional_Eggs_Benedict.jpg'),
  ('아침', '양식', '베이글', 'Bagel.jpg'),
  ('아침', '양식', '크루아상', 'APileOfCroissants.jpg'),
  ('아침', '양식', '스크램블 에그', 'Scrambed_eggs.jpg'),
  ('아침', '간편식', '시리얼', 'NCI_Visuals_Food_Meal_Breakfast.jpg'),
  ('아침', '간편식', '오트밀', 'Oatmeal_porridge_1-minute_with_additional_ingredients.jpg'),
  ('아침', '간편식', '요거트 그래놀라', 'Yogurt,_fruit,_granola_bowl_(34999358091).jpg'),
  ('아침', '간편식', '삶은 달걀', 'Boiled_Egg_-_Crossection.jpg'),
  ('아침', '간편식', '군고구마', 'Gun-goguma.jpg'),
  ('아침', '간편식', '주먹밥', 'Jumeok-bap.jpg'),

  -- 점심
  ('점심', '한식', '김치찌개', 'Korean_stew_dish_-_Kimchi-jjigae_Kimchi_Stew_2019_(01).jpg'),
  ('점심', '한식', '된장찌개', 'Doenjang_jjigae.jpg'),
  ('점심', '한식', '제육볶음', '제육_볶음.jpg'),
  ('점심', '한식', '비빔밥', 'Dolsot-bibimbap.jpg'),
  ('점심', '한식', '순대국', 'Sundae-guk.jpg'),
  ('점심', '한식', '갈비탕', 'Galbitang_갈비탕_beeniru.jpg'),
  ('점심', '한식', '냉면', 'Dongmu_Bapsang_02.jpg'),
  ('점심', '한식', '삼계탕', 'Samgye-tang_2.jpg'),
  ('점심', '한식', '뚝배기 불고기', 'Bulgogi_2.jpg'),
  ('점심', '한식', '부대찌개', 'Budae_jjigae_(28587380901).jpg'),
  ('점심', '한식', '닭갈비', 'Korean_cuisine-Dakgalbi-01.jpg'),
  ('점심', '한식', '콩나물국밥', 'Kongnamul_gukbap_20230408_003.jpg'),
  ('점심', '중식', '짜장면', 'Jajangmyeon.jpg'),
  ('점심', '중식', '짬뽕', 'Jjampong.JPG'),
  ('점심', '중식', '볶음밥', 'Koh_Mak,_Thailand,_Fried_rice_with_seafood,_Thai_fried_rice.jpg'),
  ('점심', '중식', '탕수육', 'Tangsuyuk_(Korean_Chinese_sweet_and_sour_pork).jpg'),
  ('점심', '중식', '마파두부밥', 'Chen_Mapo_Tofu.jpg'),
  ('점심', '중식', '잡채밥', 'Korean_cuisine_japchae.jpg'),
  ('점심', '중식', '마라탕', 'Malatang_from_South_Korea.jpg'),
  ('점심', '일식', '초밥', 'Sushi_platter.jpg'),
  ('점심', '일식', '돈카츠', 'Tonkatsu_of_Kimukatsu.jpg'),
  ('점심', '일식', '라멘', 'Shoyu_ramen,_at_Kasukabe_Station_(2014.05.05)_1.jpg'),
  ('점심', '일식', '우동', 'Kakeudon.jpg'),
  ('점심', '일식', '규동', 'Gyuu-don_003.jpg'),
  ('점심', '일식', '회덮밥', 'Korean_cuisine-Salmon_hoedeopbap-01.jpg'),
  ('점심', '일식', '소바', 'Zaru_soba_by_spinachdip.jpg'),
  ('점심', '양식', '파스타', 'Spaghetti_Bolognese.jpg'),
  ('점심', '양식', '햄버거', 'RedDot_Burger.jpg'),
  ('점심', '양식', '리조또', 'Risotto_Alla_Marinara.jpg'),
  ('점심', '양식', '샌드위치', 'Bologna_sandwich.jpg'),
  ('점심', '양식', '피자', 'Pizza-3007395.jpg'),
  ('점심', '양식', '샐러드', 'Salad_platter.jpg'),
  ('점심', '분식', '떡볶이', 'Tteokbokki.JPG'),
  ('점심', '분식', '김밥', 'Gimbap_(pixabay).jpg'),
  ('점심', '분식', '라볶이', 'Ra-bokki.jpg'),
  ('점심', '분식', '쫄면', 'Jjolmyeon_2.jpg'),
  ('점심', '분식', '만두', '만두.jpg'),
  ('점심', '분식', '칼국수', 'Haemul-kal-guksu.jpg'),
  ('점심', '분식', '잔치국수', 'Janchiguksu.jpg'),
  ('점심', '아시안', '쌀국수', 'Bowl_of_Meatball_pho.jpg'),
  ('점심', '아시안', '팟타이', 'Phat_Thai_kung_Chang_Khien_street_stall.jpg'),
  ('점심', '아시안', '카레', 'Beef_curry_rice_003.jpg'),
  ('점심', '아시안', '분짜', 'Bun_cha.jpg'),
  ('점심', '아시안', '나시고렝', 'Nasi_goreng_indonesia.jpg'),

  -- 저녁
  ('저녁', '고기', '삼겹살', 'Korean.cuisine-Samgyeopsal-01.jpg'),
  ('저녁', '고기', '갈비', 'Korean.food-Galbi-03.jpg'),
  ('저녁', '고기', '곱창', 'Korean.food-Gobchang.bokkem-01.jpg'),
  ('저녁', '고기', '양꼬치', 'Spicy_lamb_skewers_@_Tian_Tian_Wang_@_Paris_(34591424026).jpg'),
  ('저녁', '고기', '차돌박이', 'Chadolbagi-gui.jpg'),
  ('저녁', '고기', '치킨', 'Korean_fried_chicken_3_banban.jpg'),
  ('저녁', '한식', '보쌈', 'KOCIS_BOSSAM,_napa_wraps_with_pork_(4618280268).jpg'),
  ('저녁', '한식', '족발', 'Korean_food-Jokbal-01.jpg'),
  ('저녁', '한식', '감자탕', 'Gamja-tang_5.jpg'),
  ('저녁', '한식', '닭볶음탕', 'Korean.food-Dakbokemtang-01.jpg'),
  ('저녁', '한식', '찜닭', 'Korean.cuisine-Andong.jjimdalk-01.jpg'),
  ('저녁', '한식', '파전', 'Korean_pancake-Pajeon-06.jpg'),
  ('저녁', '한식', '아귀찜', 'Korean.food-Agu.jjim-01.jpg'),
  ('저녁', '한식', '김치찜', '김치찜.jpg'),
  ('저녁', '중식', '마라샹궈', 'Ma_La_Xiang_Guo.jpg'),
  ('저녁', '중식', '훠궈', 'Hot_Pot.jpg'),
  ('저녁', '중식', '깐풍기', 'Kkanpunggi.jpg'),
  ('저녁', '중식', '양장피', 'Yangjangpi.jpg'),
  ('저녁', '중식', '딤섬', 'Dim_sum.jpg'),
  ('저녁', '일식', '샤브샤브', 'Shabu-shabu-01.jpg'),
  ('저녁', '일식', '스키야키', 'Sukiyaki_01.jpg'),
  ('저녁', '일식', '모둠 사시미', 'Sashimi_combo_(30122297838).jpg'),
  ('저녁', '일식', '오코노미야키', 'Okonomiyaki_001.jpg'),
  ('저녁', '일식', '야키토리', 'Cooking_yakitori.jpg'),
  ('저녁', '일식', '텐동', 'Tendon_by_udono_in_Tokyo.jpg'),
  ('저녁', '양식', '스테이크', 'Beef_fillet_steak_with_mushrooms.jpg'),
  ('저녁', '양식', '감바스', 'Gambas_al_ajillo.jpg'),
  ('저녁', '양식', '라자냐', 'Lasagna_with_minced_meat,_Brisbane.jpg'),
  ('저녁', '양식', '피시 앤 칩스', 'Fish_and_chips_blackpool.jpg'),
  ('저녁', '가볍게', '월남쌈', 'Sommerrolle_mit_Hoisin-Sauce_170305_AW.jpg'),
  ('저녁', '가볍게', '포케', 'Ahi_tuna_Poke.jpeg'),
  ('저녁', '가볍게', '두부조림', 'Dubu-jorim.jpg'),
  ('저녁', '가볍게', '도토리묵무침', 'Korean_acorn_jelly-Dotorimuk-04.jpg'),
  ('저녁', '가볍게', '닭가슴살 샐러드', 'Chicken_breast_with_salad_of_mixed_greens,_tomato,_bell_peppers,_and_green_olives_-_Massachusetts.jpg')
on conflict (meal, name) do nothing;
