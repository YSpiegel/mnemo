-- Run this once in Supabase: SQL Editor → New query → paste → Run.
-- It creates the Mnemo MVP data model, helper functions, and row-level security.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.spaces (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  description text not null default '',
  invite_code text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.space_members (
  space_id uuid not null references public.spaces(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner', 'member')) default 'member',
  joined_at timestamptz not null default now(),
  primary key (space_id, user_id)
);

create table if not exists public.field_definitions (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 80),
  position integer not null check (position >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (space_id, position)
);

create table if not exists public.cards (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  values jsonb not null default '{}'::jsonb,
  created_by uuid not null references public.profiles(id),
  last_edited_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.study_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  card_id uuid not null references public.cards(id) on delete cascade,
  result text not null check (result in ('got_it', 'need_practice')),
  created_at timestamptz not null default now()
);

create index if not exists cards_space_id_idx on public.cards(space_id);
create index if not exists field_definitions_space_id_idx on public.field_definitions(space_id, position);
create index if not exists space_members_user_id_idx on public.space_members(user_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists spaces_set_updated_at on public.spaces;
create trigger spaces_set_updated_at before update on public.spaces for each row execute function public.set_updated_at();
drop trigger if exists fields_set_updated_at on public.field_definitions;
create trigger fields_set_updated_at before update on public.field_definitions for each row execute function public.set_updated_at();
drop trigger if exists cards_set_updated_at on public.cards;
create trigger cards_set_updated_at before update on public.cards for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.is_space_member(p_space_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.space_members where space_id = p_space_id and user_id = auth.uid());
$$;

create or replace function public.is_space_owner(p_space_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.space_members where space_id = p_space_id and user_id = auth.uid() and role = 'owner');
$$;

create or replace function public.shares_space_with(p_user_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_user_id = auth.uid() or exists (
    select 1 from public.space_members mine join public.space_members theirs using (space_id)
    where mine.user_id = auth.uid() and theirs.user_id = p_user_id
  );
$$;

alter table public.profiles enable row level security;
alter table public.spaces enable row level security;
alter table public.space_members enable row level security;
alter table public.field_definitions enable row level security;
alter table public.cards enable row level security;
alter table public.study_results enable row level security;

drop policy if exists "profiles visible to collaborators" on public.profiles;
create policy "profiles visible to collaborators" on public.profiles for select using (public.shares_space_with(id));
drop policy if exists "users update their profile" on public.profiles;
create policy "users update their profile" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "members read spaces" on public.spaces;
create policy "members read spaces" on public.spaces for select using (public.is_space_member(id));
drop policy if exists "owners update spaces" on public.spaces;
create policy "owners update spaces" on public.spaces for update using (public.is_space_owner(id));
drop policy if exists "owners delete spaces" on public.spaces;
create policy "owners delete spaces" on public.spaces for delete using (public.is_space_owner(id));

drop policy if exists "members read memberships" on public.space_members;
create policy "members read memberships" on public.space_members for select using (public.is_space_member(space_id));
drop policy if exists "owners remove members" on public.space_members;
create policy "owners remove members" on public.space_members for delete using (public.is_space_owner(space_id) and user_id <> auth.uid());

drop policy if exists "members read fields" on public.field_definitions;
create policy "members read fields" on public.field_definitions for select using (public.is_space_member(space_id));
drop policy if exists "owners manage fields" on public.field_definitions;
create policy "owners manage fields" on public.field_definitions for all using (public.is_space_owner(space_id)) with check (public.is_space_owner(space_id));

drop policy if exists "members read cards" on public.cards;
create policy "members read cards" on public.cards for select using (public.is_space_member(space_id));
drop policy if exists "members create cards" on public.cards;
create policy "members create cards" on public.cards for insert with check (public.is_space_member(space_id) and created_by = auth.uid() and last_edited_by = auth.uid());
drop policy if exists "members update cards" on public.cards;
create policy "members update cards" on public.cards for update using (public.is_space_member(space_id)) with check (public.is_space_member(space_id) and last_edited_by = auth.uid());
drop policy if exists "members delete cards" on public.cards;
create policy "members delete cards" on public.cards for delete using (public.is_space_member(space_id));

drop policy if exists "users manage their study feedback" on public.study_results;
create policy "users manage their study feedback" on public.study_results for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.create_space(p_name text, p_description text, p_fields jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_space_id uuid := gen_random_uuid(); v_field jsonb; v_index integer := 0; v_code text;
begin
  if auth.uid() is null then raise exception 'You must be signed in'; end if;
  if jsonb_array_length(p_fields) < 2 or jsonb_array_length(p_fields) > 8 then raise exception 'A space needs between 2 and 8 fields'; end if;
  loop
    v_code := upper(substr(regexp_replace(p_name, '[^A-Za-z]', '', 'g') || 'MNEMO', 1, 4)) || '-' || lpad((floor(random() * 10000))::text, 4, '0');
    exit when not exists (select 1 from public.spaces where invite_code = v_code);
  end loop;
  insert into public.spaces (id, owner_id, name, description, invite_code) values (v_space_id, auth.uid(), trim(p_name), coalesce(trim(p_description), ''), v_code);
  insert into public.space_members (space_id, user_id, role) values (v_space_id, auth.uid(), 'owner');
  for v_field in select * from jsonb_array_elements(p_fields) loop
    insert into public.field_definitions (space_id, title, position) values (v_space_id, trim(v_field #>> '{}'), v_index);
    v_index := v_index + 1;
  end loop;
  return v_space_id;
end;
$$;

create or replace function public.join_space_by_code(p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_space_id uuid;
begin
  select id into v_space_id from public.spaces where invite_code = upper(trim(p_code));
  if v_space_id is null then raise exception 'Invalid invite code'; end if;
  insert into public.space_members (space_id, user_id, role) values (v_space_id, auth.uid(), 'member') on conflict do nothing;
  return v_space_id;
end;
$$;

create or replace function public.save_fields(p_space_id uuid, p_fields jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_field jsonb; v_keep_ids uuid[]; v_position integer := 0; v_id uuid;
begin
  if not public.is_space_owner(p_space_id) then raise exception 'Only the owner can change fields'; end if;
  if jsonb_array_length(p_fields) < 2 or jsonb_array_length(p_fields) > 8 then raise exception 'A space needs between 2 and 8 fields'; end if;
  select coalesce(array_agg((item ->> 'id')::uuid), '{}') into v_keep_ids from jsonb_array_elements(p_fields) item where item ? 'id';
  update public.cards set values = values - coalesce((select array_agg(id::text) from public.field_definitions where space_id = p_space_id and not (id = any(v_keep_ids))), '{}');
  delete from public.field_definitions where space_id = p_space_id and not (id = any(v_keep_ids));
  for v_field in select * from jsonb_array_elements(p_fields) loop
    v_id := coalesce(nullif(v_field ->> 'id', '')::uuid, gen_random_uuid());
    insert into public.field_definitions (id, space_id, title, position) values (v_id, p_space_id, trim(v_field ->> 'title'), v_position)
    on conflict (id) do update set title = excluded.title, position = excluded.position;
    v_position := v_position + 1;
  end loop;
end;
$$;

grant usage on schema public to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select, update, delete on public.spaces to authenticated;
grant select, delete on public.space_members to authenticated;
grant select, insert, update, delete on public.field_definitions to authenticated;
grant select, insert, update, delete on public.cards to authenticated;
grant select, insert, update, delete on public.study_results to authenticated;
grant execute on function public.create_space(text, text, jsonb), public.join_space_by_code(text), public.save_fields(uuid, jsonb) to authenticated;
