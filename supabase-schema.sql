-- ============================================
-- SUPABASE SCHEMA - Admin: ingt6359@gmail.com
-- ============================================

create table if not exists settings (
  id text primary key,
  timer_duration int default 10,
  app_title text default 'Webapp Sikho',
  theme_color_from text default '#4f46e5',
  theme_color_to text default '#7e22ce',
  ad_slot1 text default '',
  ad_slot2 text default ''
);

create table if not exists sliders (
  id uuid primary key default gen_random_uuid(),
  image_url text not null,
  link_url text default '',
  created_at timestamptz default now()
);

create table if not exists files (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  thumbnail_url text not null,
  description text not null,
  download_url text not null,
  download_url2 text default '',
  btn_name1 text default '',
  btn_name2 text default '',
  required_ads int default 5,
  screenshots jsonb default '[]'::jsonb,
  downloads int default 0,
  reviews jsonb default '[]'::jsonb,
  created_at timestamptz default now()
);

create or replace function increment_downloads(file_id uuid)
returns void language plpgsql security definer as $$
begin
  update files set downloads = downloads + 1 where id = file_id;
end; $$;

create or replace function upsert_review(
  file_id uuid, p_user_id text, p_user text, p_rating int, p_text text
) returns void language plpgsql security definer as $$
declare
  v_reviews jsonb;
  v_new jsonb;
  v_idx int;
begin
  select reviews into v_reviews from files where id = file_id for update;
  if v_reviews is null then v_reviews := '[]'::jsonb; end if;
  v_new := jsonb_build_object(
    'userId', p_user_id,
    'user', p_user,
    'rating', p_rating,
    'text', p_text,
    'timestamp', extract(epoch from now()) * 1000
  );
  select ordinality - 1 into v_idx
  from jsonb_array_elements(v_reviews) with ordinality
  where value->>'userId' = p_user_id limit 1;
  if v_idx is not null then
    v_reviews := jsonb_set(v_reviews, array[v_idx::text], v_new);
  else
    v_reviews := v_reviews || jsonb_build_array(v_new);
  end if;
  update files set reviews = v_reviews where id = file_id;
end; $$;

create or replace function delete_review(file_id uuid, p_user_id text)
returns void language plpgsql security definer as $$
declare v_reviews jsonb; v_new jsonb := '[]'::jsonb; elem jsonb;
begin
  select reviews into v_reviews from files where id = file_id for update;
  if v_reviews is null then return; end if;
  for elem in select * from jsonb_array_elements(v_reviews) loop
    if elem->>'userId' <> p_user_id then
      v_new := v_new || jsonb_build_array(elem);
    end if;
  end loop;
  update files set reviews = v_new where id = file_id;
end; $$;

grant execute on function increment_downloads(uuid) to anon, authenticated;
grant execute on function upsert_review(uuid, text, text, int, text) to anon, authenticated;
grant execute on function delete_review(uuid, text) to anon, authenticated;

alter table settings enable row level security;
drop policy if exists "settings_select" on settings;
drop policy if exists "settings_admin_write" on settings;
create policy "settings_select" on settings for select using (true);
create policy "settings_admin_write" on settings for all
  using (auth.jwt()->>'email' = 'ingt6359@gmail.com')
  with check (auth.jwt()->>'email' = 'ingt6359@gmail.com');

alter table sliders enable row level security;
drop policy if exists "sliders_select" on sliders;
drop policy if exists "sliders_admin_write" on sliders;
create policy "sliders_select" on sliders for select using (true);
create policy "sliders_admin_write" on sliders for all
  using (auth.jwt()->>'email' = 'ingt6359@gmail.com')
  with check (auth.jwt()->>'email' = 'ingt6359@gmail.com');

alter table files enable row level security;
drop policy if exists "files_select" on files;
drop policy if exists "files_admin_insert" on files;
drop policy if exists "files_admin_update" on files;
drop policy if exists "files_admin_delete" on files;
create policy "files_select" on files for select using (true);
create policy "files_admin_insert" on files for insert
  with check (auth.jwt()->>'email' = 'ingt6359@gmail.com');
create policy "files_admin_update" on files for update
  using (auth.jwt()->>'email' = 'ingt6359@gmail.com');
create policy "files_admin_delete" on files for delete
  using (auth.jwt()->>'email' = 'ingt6359@gmail.com');