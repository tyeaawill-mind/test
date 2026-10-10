-- mindRID V0.2 FINAL Supabase schema
-- Purpose: public social Whispers with private identity verification.
-- Run this in Supabase SQL Editor.
-- This script is designed to be safe to re-run.
--
-- IMPORTANT:
-- 1) The browser app must use only the Supabase publishable key.
-- 2) Never expose a Supabase secret/service-role key.
-- 3) Private identification is intentionally kept in a separate table.
-- 4) New app code should NOT put private identification in auth metadata.

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- ============================================================
-- TABLES
-- ============================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

-- V7 profile fields must exist before any RLS/storage policy or function
-- references them. This also makes upgrades from older schemas safe.
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists location_country text;
alter table public.profiles add column if not exists location_city text;
alter table public.profiles add column if not exists background text;
alter table public.profiles add column if not exists interests text[] not null default '{}';
alter table public.profiles add column if not exists avatar_path text;
alter table public.profiles add column if not exists background_path text;
alter table public.profiles add column if not exists theme_key text not null default 'auto' check (theme_key in ('auto','sky','lavender','mint','sunset','mono'));
alter table public.profiles add column if not exists last_whisper_vibe text;
alter table public.profiles add column if not exists is_deactivated boolean not null default false;
alter table public.profiles drop constraint if exists profiles_theme_key_check;
alter table public.profiles add constraint profiles_theme_key_check check (theme_key in ('auto','sky','lavender','mint','sunset','mono'));

create table if not exists public.private_identity (
  user_id uuid primary key references auth.users(id) on delete cascade,
  identification text not null check (char_length(identification) between 1 and 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.whispers (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 10000),
  identity_mode text not null default 'anonymous'
    check (identity_mode in ('real','anonymous')),
  visibility text not null default 'private'
    check (visibility in ('private','selected','public')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.whisper_recipients (
  whisper_id uuid not null references public.whispers(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  primary key (whisper_id, recipient_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  whisper_id uuid not null references public.whispers(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 3000),
  parent_comment_id uuid references public.comments(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  whisper_id uuid references public.whispers(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  reason text not null check (char_length(reason) between 1 and 1000),
  created_at timestamptz not null default now(),
  check (
    (whisper_id is not null and comment_id is null)
    or
    (whisper_id is null and comment_id is not null)
  )
);

create table if not exists public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- ============================================================
-- PRIVATE MESSAGING
-- One-to-one conversations. Membership is enforced by RLS; the
-- start-conversation RPC creates both membership rows atomically.
-- ============================================================

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (conversation_id,user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 5000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.mindrid_is_conversation_member(cid uuid, viewer uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists (select 1 from public.conversation_members cm where cm.conversation_id=cid and cm.user_id=viewer);
$$;

create or replace function public.mindrid_start_conversation(recipient uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  me uuid := auth.uid();
  existing uuid;
  cid uuid;
begin
  if me is null then raise exception 'Authentication required.'; end if;
  if recipient is null or recipient=me then raise exception 'Invalid recipient.'; end if;
  if not exists (select 1 from auth.users where id=recipient) then raise exception 'Recipient not found.'; end if;
  if exists (select 1 from public.blocks where (blocker_id=me and blocked_id=recipient) or (blocker_id=recipient and blocked_id=me)) then raise exception 'This conversation is unavailable.'; end if;
  select c.id into existing
  from public.conversations c
  where (select count(*) from public.conversation_members cm where cm.conversation_id=c.id)=2
    and exists (select 1 from public.conversation_members cm where cm.conversation_id=c.id and cm.user_id=me)
    and exists (select 1 from public.conversation_members cm where cm.conversation_id=c.id and cm.user_id=recipient)
  order by c.updated_at desc limit 1;
  if existing is not null then return existing; end if;
  insert into public.conversations default values returning id into cid;
  insert into public.conversation_members(conversation_id,user_id) values (cid,me),(cid,recipient);
  return cid;
end;
$$;

revoke execute on function public.mindrid_start_conversation(uuid) from public, anon;
grant execute on function public.mindrid_start_conversation(uuid) to authenticated;

-- ============================================================
-- HELPER FUNCTIONS
-- SECURITY DEFINER functions are used to avoid circular RLS
-- evaluation between whispers and whisper_recipients.
-- ============================================================

create or replace function public.mindrid_is_blocked(
  viewer uuid,
  owner uuid
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.blocks b
    where
      (b.blocker_id = viewer and b.blocked_id = owner)
      or
      (b.blocker_id = owner and b.blocked_id = viewer)
  );
$$;

create or replace function public.mindrid_can_view_whisper(
  whisper_author uuid,
  whisper_visibility text,
  whisper_id uuid,
  viewer uuid
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    case
      when viewer is null then
        whisper_visibility = 'public'
        and exists (select 1 from public.profiles p where p.id=whisper_author and p.is_deactivated=false)
      else
        whisper_author = viewer
        or (
          not public.mindrid_is_blocked(viewer, whisper_author)
          and exists (select 1 from public.profiles p where p.id=whisper_author and p.is_deactivated=false)
          and (
            whisper_visibility = 'public'
            or (
              whisper_visibility = 'selected'
              and exists (
                select 1
                from public.whisper_recipients r
                where r.whisper_id = mindrid_can_view_whisper.whisper_id
                  and r.recipient_id = viewer
              )
            )
          )
        )
    end;
$$;

create or replace function public.mindrid_can_comment(
  target_whisper uuid,
  viewer uuid
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.whispers w
    where w.id = target_whisper
      and public.mindrid_can_view_whisper(w.author_id, w.visibility, w.id, viewer)
      and w.visibility in ('public','selected')
  );
$$;

create or replace function public.mindrid_can_report_whisper(
  target_whisper uuid,
  reporter uuid
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.whispers w
    where w.id = target_whisper
      and w.author_id <> reporter
      and public.mindrid_can_view_whisper(w.author_id, w.visibility, w.id, reporter)
  );
$$;

create or replace function public.mindrid_can_report_comment(
  target_comment uuid,
  reporter uuid
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.comments c
    where c.id = target_comment
      and c.author_id <> reporter
      and public.mindrid_can_comment(c.whisper_id, reporter)
  );
$$;

revoke all on function public.mindrid_is_blocked(uuid, uuid) from public;
revoke all on function public.mindrid_can_view_whisper(uuid, text, uuid, uuid) from public;
revoke all on function public.mindrid_can_comment(uuid, uuid) from public;
revoke all on function public.mindrid_can_report_whisper(uuid, uuid) from public;
revoke all on function public.mindrid_can_report_comment(uuid, uuid) from public;

grant execute on function public.mindrid_is_blocked(uuid, uuid) to authenticated;
grant execute on function public.mindrid_can_view_whisper(uuid, text, uuid, uuid) to authenticated;
grant execute on function public.mindrid_can_comment(uuid, uuid) to authenticated;
grant execute on function public.mindrid_can_report_whisper(uuid, uuid) to authenticated;
grant execute on function public.mindrid_can_report_comment(uuid, uuid) to authenticated;

-- ============================================================
-- RLS
-- ============================================================

alter table public.profiles enable row level security;
alter table public.private_identity enable row level security;
alter table public.whispers enable row level security;
alter table public.whisper_recipients enable row level security;
alter table public.comments enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;

-- Profiles
drop policy if exists profiles_select_public on public.profiles;
drop policy if exists profiles_insert_own on public.profiles;
drop policy if exists profiles_update_own on public.profiles;
drop policy if exists profiles_select_public on public.profiles;
create policy profiles_select_public
  on public.profiles for select
  using (is_deactivated=false or id=auth.uid());
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own
  on public.profiles for insert
  with check (id = auth.uid());
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- Private identity: owner only.
drop policy if exists private_identity_select_own on public.private_identity;
drop policy if exists private_identity_insert_own on public.private_identity;
drop policy if exists private_identity_update_own on public.private_identity;
drop policy if exists private_identity_delete_own on public.private_identity;
drop policy if exists private_identity_select_own on public.private_identity;
create policy private_identity_select_own
  on public.private_identity for select
  using (user_id = auth.uid());
drop policy if exists private_identity_insert_own on public.private_identity;
create policy private_identity_insert_own
  on public.private_identity for insert
  with check (user_id = auth.uid());
drop policy if exists private_identity_update_own on public.private_identity;
create policy private_identity_update_own
  on public.private_identity for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
drop policy if exists private_identity_delete_own on public.private_identity;
create policy private_identity_delete_own
  on public.private_identity for delete
  using (user_id = auth.uid());

-- Whispers
drop policy if exists whispers_select_own_or_public on public.whispers;
drop policy if exists whispers_insert_own on public.whispers;
drop policy if exists whispers_update_own on public.whispers;
drop policy if exists whispers_delete_own on public.whispers;

drop policy if exists whispers_select_visible on public.whispers;
create policy whispers_select_visible
  on public.whispers for select
  using (
    public.mindrid_can_view_whisper(author_id, visibility, id, auth.uid())
  );

drop policy if exists whispers_insert_own on public.whispers;
create policy whispers_insert_own
  on public.whispers for insert
  with check (author_id = auth.uid());

drop policy if exists whispers_update_own on public.whispers;
create policy whispers_update_own
  on public.whispers for update
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

drop policy if exists whispers_delete_own on public.whispers;
create policy whispers_delete_own
  on public.whispers for delete
  using (author_id = auth.uid());

-- Selected recipients
drop policy if exists whisper_recipients_select_related on public.whisper_recipients;
drop policy if exists whisper_recipients_insert_owner on public.whisper_recipients;
drop policy if exists whisper_recipients_delete_owner on public.whisper_recipients;

drop policy if exists whisper_recipients_select_related on public.whisper_recipients;
create policy whisper_recipients_select_related
  on public.whisper_recipients for select
  using (
    recipient_id = auth.uid()
    or exists (
      select 1
      from public.whispers w
      where w.id = whisper_id
        and w.author_id = auth.uid()
    )
  );

drop policy if exists whisper_recipients_insert_owner on public.whisper_recipients;
create policy whisper_recipients_insert_owner
  on public.whisper_recipients for insert
  with check (
    exists (
      select 1
      from public.whispers w
      where w.id = whisper_id
        and w.author_id = auth.uid()
    )
  );

drop policy if exists whisper_recipients_delete_owner on public.whisper_recipients;
create policy whisper_recipients_delete_owner
  on public.whisper_recipients for delete
  using (
    exists (
      select 1
      from public.whispers w
      where w.id = whisper_id
        and w.author_id = auth.uid()
    )
  );

-- Comments/replies
drop policy if exists comments_select_visible on public.comments;
drop policy if exists comments_insert_signed_in_visible on public.comments;
drop policy if exists comments_update_own on public.comments;
drop policy if exists comments_delete_own on public.comments;

drop policy if exists comments_select_visible on public.comments;
create policy comments_select_visible
  on public.comments for select
  using (
    public.mindrid_can_comment(whisper_id, auth.uid())
  );

drop policy if exists comments_insert_signed_in_visible on public.comments;
create policy comments_insert_signed_in_visible
  on public.comments for insert
  with check (
    author_id = auth.uid()
    and public.mindrid_can_comment(whisper_id, auth.uid())
  );

drop policy if exists comments_update_own on public.comments;
create policy comments_update_own
  on public.comments for update
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

drop policy if exists comments_delete_own on public.comments;
create policy comments_delete_own
  on public.comments for delete
  using (author_id = auth.uid());

-- Reports: reporters can create reports; they cannot read the report queue.
drop policy if exists reports_insert_own_visible_target on public.reports;
drop policy if exists reports_select_own on public.reports;
drop policy if exists reports_delete_own on public.reports;

drop policy if exists reports_insert_own_visible_target on public.reports;
create policy reports_insert_own_visible_target
  on public.reports for insert
  with check (
    reporter_id = auth.uid()
    and (
      (whisper_id is not null and public.mindrid_can_report_whisper(whisper_id, auth.uid()))
      or
      (comment_id is not null and public.mindrid_can_report_comment(comment_id, auth.uid()))
    )
  );

drop policy if exists reports_select_own on public.reports;
create policy reports_select_own
  on public.reports for select
  using (reporter_id = auth.uid());

drop policy if exists reports_delete_own on public.reports;
create policy reports_delete_own
  on public.reports for delete
  using (reporter_id = auth.uid());

-- Blocks
drop policy if exists blocks_select_own on public.blocks;
drop policy if exists blocks_insert_own on public.blocks;
drop policy if exists blocks_delete_own on public.blocks;

drop policy if exists blocks_select_own on public.blocks;
create policy blocks_select_own
  on public.blocks for select
  using (blocker_id = auth.uid());

drop policy if exists blocks_insert_own on public.blocks;
create policy blocks_insert_own
  on public.blocks for insert
  with check (blocker_id = auth.uid());

drop policy if exists blocks_delete_own on public.blocks;
create policy blocks_delete_own
  on public.blocks for delete
  using (blocker_id = auth.uid());

-- ============================================================
-- PROFILE CREATION
-- This trigger creates only the public profile.
-- It intentionally does NOT read private identification.
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    nullif(new.raw_user_meta_data->>'username',''),
    nullif(new.raw_user_meta_data->>'display_name','')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();

-- ============================================================
-- INDEXES
-- ============================================================

create index if not exists whispers_public_created_idx
  on public.whispers (visibility, created_at desc);

create index if not exists whispers_author_created_idx
  on public.whispers (author_id, created_at desc);

create index if not exists whisper_recipients_recipient_idx
  on public.whisper_recipients (recipient_id, whisper_id);

create index if not exists comments_whisper_created_idx
  on public.comments (whisper_id, created_at asc);

create index if not exists comments_author_idx
  on public.comments (author_id, created_at desc);

create index if not exists reports_whisper_idx
  on public.reports (whisper_id)
  where whisper_id is not null;

create index if not exists reports_comment_idx
  on public.reports (comment_id)
  where comment_id is not null;

create index if not exists blocks_blocked_idx
  on public.blocks (blocked_id, blocker_id);

-- ============================================================
-- NOTE ABOUT EXISTING AUTH METADATA
-- ============================================================
-- This final schema deliberately does NOT copy or delete
-- private_identification from auth.users metadata.
--
-- If the earlier prototype stored private_identification in
-- auth metadata for test accounts, do NOT try to migrate it
-- automatically with this schema. We will handle any existing
-- test-account migration explicitly, after inspecting what is
-- actually present.

-- ============================================================
-- RELIABILITY EXTENSION: reactions, saves and media
-- ============================================================

alter table public.whispers drop constraint if exists whispers_body_check;
alter table public.whispers add constraint whispers_body_check check (char_length(body) between 0 and 10000);
alter table public.comments drop constraint if exists comments_body_check;
alter table public.comments add constraint comments_body_check check (char_length(body) between 0 and 3000);
alter table public.whispers alter column body set default '';
alter table public.comments alter column body set default '';

alter table public.whispers add column if not exists updated_at timestamptz not null default now();
alter table public.comments add column if not exists updated_at timestamptz not null default now();

create table if not exists public.likes (
  whisper_id uuid not null references public.whispers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (whisper_id, user_id)
);

create table if not exists public.saves (
  whisper_id uuid not null references public.whispers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (whisper_id, user_id)
);

create table if not exists public.whisper_media (
  id uuid primary key default gen_random_uuid(),
  whisper_id uuid not null references public.whispers(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  public_url text,
  mime_type text not null,
  file_name text not null,
  file_size bigint not null check (file_size > 0 and file_size <= 52428800),
  is_preview boolean not null default false,
  preview_mode text not null default 'small' check (preview_mode in ('small','cover')),
  created_at timestamptz not null default now()
);

create table if not exists public.comment_media (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.comments(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  public_url text,
  mime_type text not null,
  file_name text not null,
  file_size bigint not null check (file_size > 0 and file_size <= 52428800),
  created_at timestamptz not null default now()
);

alter table public.likes enable row level security;
alter table public.saves enable row level security;
alter table public.whisper_media enable row level security;
alter table public.comment_media enable row level security;

drop policy if exists likes_select_visible on public.likes;
drop policy if exists likes_insert_own on public.likes;
drop policy if exists likes_delete_own on public.likes;
create policy likes_select_visible on public.likes for select using (
  exists (select 1 from public.whispers w where w.id=whisper_id and public.mindrid_can_view_whisper(w.author_id,w.visibility,w.id,auth.uid()))
);
create policy likes_insert_own on public.likes for insert with check (
  user_id=auth.uid() and exists (select 1 from public.whispers w where w.id=whisper_id and public.mindrid_can_view_whisper(w.author_id,w.visibility,w.id,auth.uid()))
);
create policy likes_delete_own on public.likes for delete using (user_id=auth.uid());

drop policy if exists saves_select_own on public.saves;
drop policy if exists saves_insert_own on public.saves;
drop policy if exists saves_delete_own on public.saves;
create policy saves_select_own on public.saves for select using (user_id=auth.uid());
create policy saves_insert_own on public.saves for insert with check (user_id=auth.uid());
create policy saves_delete_own on public.saves for delete using (user_id=auth.uid());
grant select,insert,delete on public.saves to authenticated;

drop policy if exists whisper_media_select_visible on public.whisper_media;
drop policy if exists whisper_media_insert_own on public.whisper_media;
drop policy if exists whisper_media_delete_own on public.whisper_media;
create policy whisper_media_select_visible on public.whisper_media for select using (
  exists (select 1 from public.whispers w where w.id=whisper_id and public.mindrid_can_view_whisper(w.author_id,w.visibility,w.id,auth.uid()))
);
create policy whisper_media_insert_own on public.whisper_media for insert with check (
  author_id=auth.uid() and exists (select 1 from public.whispers w where w.id=whisper_id and w.author_id=auth.uid())
);
create policy whisper_media_delete_own on public.whisper_media for delete using (author_id=auth.uid());

drop policy if exists comment_media_select_visible on public.comment_media;
drop policy if exists comment_media_insert_own on public.comment_media;
drop policy if exists comment_media_delete_own on public.comment_media;
create policy comment_media_select_visible on public.comment_media for select using (
  exists (select 1 from public.comments c where c.id=comment_id and public.mindrid_can_comment(c.whisper_id,auth.uid()))
);
create policy comment_media_insert_own on public.comment_media for insert with check (
  author_id=auth.uid() and exists (select 1 from public.comments c where c.id=comment_id and c.author_id=auth.uid())
);
create policy comment_media_delete_own on public.comment_media for delete using (author_id=auth.uid());

-- Private media bucket. The application generates access URLs only after
-- the database visibility rules permit the media row to be read.
insert into storage.buckets (id,name,public)
values ('mindrid-media','mindrid-media',false)
on conflict (id) do update set public=false;

drop policy if exists mindrid_media_storage_select on storage.objects;
drop policy if exists mindrid_media_storage_insert on storage.objects;
drop policy if exists mindrid_media_storage_update on storage.objects;
drop policy if exists mindrid_media_storage_delete on storage.objects;

drop policy if exists mindrid_media_storage_select on storage.objects;
create policy mindrid_media_storage_select on storage.objects for select using (
  bucket_id='mindrid-media' and (
    (storage.foldername(name))[1]=auth.uid()::text
    or exists (select 1 from public.profiles p where (p.avatar_path=name or p.background_path=name) and p.is_deactivated=false)
    or exists (
      select 1 from public.whisper_media wm
      join public.whispers w on w.id=wm.whisper_id
      where wm.storage_path=name and public.mindrid_can_view_whisper(w.author_id,w.visibility,w.id,auth.uid())
    )
    or exists (
      select 1 from public.comment_media cm
      join public.comments c on c.id=cm.comment_id
      where cm.storage_path=name and public.mindrid_can_comment(c.whisper_id,auth.uid())
    )
  )
);
drop policy if exists mindrid_media_storage_insert on storage.objects;
create policy mindrid_media_storage_insert on storage.objects for insert with check (
  bucket_id='mindrid-media' and (storage.foldername(name))[1]=auth.uid()::text
);
drop policy if exists mindrid_media_storage_update on storage.objects;
create policy mindrid_media_storage_update on storage.objects for update using (
  bucket_id='mindrid-media' and (storage.foldername(name))[1]=auth.uid()::text
) with check (
  bucket_id='mindrid-media' and (storage.foldername(name))[1]=auth.uid()::text
);
drop policy if exists mindrid_media_storage_delete on storage.objects;
create policy mindrid_media_storage_delete on storage.objects for delete using (
  bucket_id='mindrid-media' and (storage.foldername(name))[1]=auth.uid()::text
);

-- Private messaging RLS and indexes
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

drop policy if exists conversations_select_member on public.conversations;
create policy conversations_select_member on public.conversations for select using (public.mindrid_is_conversation_member(id,auth.uid()));

drop policy if exists conversation_members_select_member on public.conversation_members;
create policy conversation_members_select_member on public.conversation_members for select using (public.mindrid_is_conversation_member(conversation_id,auth.uid()));

drop policy if exists messages_select_member on public.messages;
drop policy if exists messages_insert_member on public.messages;
drop policy if exists messages_update_own on public.messages;
drop policy if exists messages_delete_own on public.messages;
create policy messages_select_member on public.messages for select using (public.mindrid_is_conversation_member(conversation_id,auth.uid()));
create policy messages_insert_member on public.messages for insert with check (sender_id=auth.uid() and public.mindrid_is_conversation_member(conversation_id,auth.uid()));
create policy messages_update_own on public.messages for update using (sender_id=auth.uid()) with check (sender_id=auth.uid() and public.mindrid_is_conversation_member(conversation_id,auth.uid()));
create policy messages_delete_own on public.messages for delete using (sender_id=auth.uid());

grant select on public.conversations,public.conversation_members,public.messages to authenticated;
grant insert,update,delete on public.messages to authenticated;

create index if not exists conversation_members_user_idx on public.conversation_members (user_id, conversation_id);
create index if not exists messages_conversation_idx on public.messages (conversation_id, created_at asc);

create or replace function public.mindrid_touch_conversation()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  update public.conversations set updated_at=now(), last_message_at=new.created_at where id=new.conversation_id;
  return new;
end;
$$;
drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation after insert on public.messages for each row execute procedure public.mindrid_touch_conversation();

create index if not exists likes_whisper_idx on public.likes (whisper_id, created_at desc);
create index if not exists saves_user_idx on public.saves (user_id, created_at desc);
create index if not exists whisper_media_whisper_idx on public.whisper_media (whisper_id, created_at asc);
create index if not exists comment_media_comment_idx on public.comment_media (comment_id, created_at asc);

-- Automatic updated_at maintenance.
create or replace function public.mindrid_touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at=now(); return new; end;
$$;
drop trigger if exists whispers_touch_updated_at on public.whispers;
create trigger whispers_touch_updated_at before update on public.whispers for each row execute procedure public.mindrid_touch_updated_at();
drop trigger if exists comments_touch_updated_at on public.comments;
create trigger comments_touch_updated_at before update on public.comments for each row execute procedure public.mindrid_touch_updated_at();

-- Ask PostgREST to reload the schema cache immediately after this script.
notify pgrst, 'reload schema';

-- ============================================================
-- COMMENT REACTIONS (LIKE / DISLIKE)
-- One reaction per user per reply; changing reaction replaces the prior one.
-- ============================================================
create table if not exists public.comment_reactions (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check (reaction in ('like','dislike')),
  created_at timestamptz not null default now(),
  primary key (comment_id,user_id)
);

alter table public.comment_reactions enable row level security;
drop policy if exists comment_reactions_select_visible on public.comment_reactions;
drop policy if exists comment_reactions_insert_own on public.comment_reactions;
drop policy if exists comment_reactions_update_own on public.comment_reactions;
drop policy if exists comment_reactions_delete_own on public.comment_reactions;
create policy comment_reactions_select_visible on public.comment_reactions for select using (
  exists (select 1 from public.comments c where c.id=comment_id and public.mindrid_can_comment(c.whisper_id,auth.uid()))
);
create policy comment_reactions_insert_own on public.comment_reactions for insert with check (
  user_id=auth.uid() and exists (select 1 from public.comments c where c.id=comment_id and public.mindrid_can_comment(c.whisper_id,auth.uid()))
);
create policy comment_reactions_update_own on public.comment_reactions for update using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy comment_reactions_delete_own on public.comment_reactions for delete using (user_id=auth.uid());
grant select,insert,update,delete on public.comment_reactions to authenticated;
create index if not exists comment_reactions_comment_idx on public.comment_reactions (comment_id,reaction);

notify pgrst, 'reload schema';

-- ============================================================
-- V7 SOCIAL / DISCOVERY LAYER
-- ============================================================
create table if not exists public.connections (
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (requester_id,addressee_id),
  check (requester_id <> addressee_id)
);

create table if not exists public.follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id,following_id),
  check (follower_id <> following_id)
);

create table if not exists public.whisper_history (
  user_id uuid not null references auth.users(id) on delete cascade,
  whisper_id uuid not null references public.whispers(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (user_id,whisper_id)
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 100),
  description text not null default '' check (char_length(description) <= 1000),
  location_country text,
  location_city text,
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  created_at timestamptz not null default now(),
  primary key (group_id,user_id)
);

create table if not exists public.whisper_tags (
  whisper_id uuid not null references public.whispers(id) on delete cascade,
  tag_type text not null check (tag_type in ('location','feeling','idea','vibe','topic','experience','mood','interest','person')),
  tag_value text not null check (char_length(tag_value) between 1 and 100),
  primary key (whisper_id,tag_type,tag_value)
);
alter table public.whisper_tags drop constraint if exists whisper_tags_tag_type_check;
alter table public.whisper_tags add constraint whisper_tags_tag_type_check check (tag_type in ('location','feeling','idea','vibe','topic','experience','mood','interest','person'));

create table if not exists public.circle_messages (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.groups(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 5000),
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  kind text not null check (char_length(kind) between 1 and 60),
  target_type text,
  target_id uuid,
  message text not null check (char_length(message) between 1 and 500),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.connections enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.whisper_tags enable row level security;
alter table public.notifications enable row level security;

-- Public profile fields are already covered by profiles_select_public.
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update using (id=auth.uid()) with check (id=auth.uid());

drop policy if exists connections_select_related on public.connections;
drop policy if exists connections_insert_own on public.connections;
drop policy if exists connections_update_related on public.connections;
drop policy if exists connections_delete_related on public.connections;
create policy connections_select_related on public.connections for select using (requester_id=auth.uid() or addressee_id=auth.uid());
create policy connections_insert_own on public.connections for insert with check (requester_id=auth.uid());
create policy connections_update_related on public.connections for update using (requester_id=auth.uid() or addressee_id=auth.uid()) with check (requester_id=auth.uid() or addressee_id=auth.uid());
create policy connections_delete_related on public.connections for delete using (requester_id=auth.uid() or addressee_id=auth.uid());

alter table public.follows enable row level security;
alter table public.whisper_history enable row level security;

drop policy if exists follows_select_related on public.follows;
drop policy if exists follows_insert_own on public.follows;
drop policy if exists follows_delete_own on public.follows;
create policy follows_select_related on public.follows for select
  using (follower_id=auth.uid() or following_id=auth.uid());
create policy follows_insert_own on public.follows for insert
  with check (follower_id=auth.uid() and follower_id<>following_id and not public.mindrid_is_blocked(auth.uid(),following_id) and exists(select 1 from public.profiles p where p.id=following_id and p.is_deactivated=false));
create policy follows_delete_own on public.follows for delete
  using (follower_id=auth.uid());

drop policy if exists whisper_history_select_own on public.whisper_history;
drop policy if exists whisper_history_insert_own on public.whisper_history;
drop policy if exists whisper_history_update_own on public.whisper_history;
drop policy if exists whisper_history_delete_own on public.whisper_history;
create policy whisper_history_select_own on public.whisper_history for select using (user_id=auth.uid());
create policy whisper_history_insert_own on public.whisper_history for insert with check (user_id=auth.uid());
create policy whisper_history_update_own on public.whisper_history for update using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy whisper_history_delete_own on public.whisper_history for delete using (user_id=auth.uid());

drop policy if exists groups_select_public on public.groups;
drop policy if exists groups_insert_own on public.groups;
drop policy if exists groups_update_own on public.groups;
drop policy if exists groups_delete_own on public.groups;
create policy groups_select_public on public.groups for select using (true);
create policy groups_insert_own on public.groups for insert with check (owner_id=auth.uid());
create policy groups_update_own on public.groups for update using (owner_id=auth.uid()) with check (owner_id=auth.uid());
create policy groups_delete_own on public.groups for delete using (owner_id=auth.uid());

drop policy if exists group_members_select_related on public.group_members;
drop policy if exists group_members_insert_self_or_owner on public.group_members;
drop policy if exists group_members_delete_self_or_owner on public.group_members;
create policy group_members_select_related on public.group_members for select using (auth.uid() is not null);
create policy group_members_insert_self_or_owner on public.group_members for insert with check (user_id=auth.uid() or exists(select 1 from public.groups g where g.id=group_id and g.owner_id=auth.uid()));
create policy group_members_delete_self_or_owner on public.group_members for delete using (user_id=auth.uid() or exists(select 1 from public.groups g where g.id=group_id and g.owner_id=auth.uid()));

drop policy if exists circle_messages_select_member on public.circle_messages;
drop policy if exists circle_messages_insert_member on public.circle_messages;
create policy circle_messages_select_member on public.circle_messages for select using (exists(select 1 from public.group_members gm where gm.group_id=circle_id and gm.user_id=auth.uid()));
create policy circle_messages_insert_member on public.circle_messages for insert with check (sender_id=auth.uid() and exists(select 1 from public.group_members gm where gm.group_id=circle_id and gm.user_id=auth.uid()));

drop policy if exists whisper_tags_select_visible on public.whisper_tags;
drop policy if exists whisper_tags_insert_owner on public.whisper_tags;
drop policy if exists whisper_tags_delete_owner on public.whisper_tags;
create policy whisper_tags_select_visible on public.whisper_tags for select using (exists(select 1 from public.whispers w where w.id=whisper_id and public.mindrid_can_view_whisper(w.author_id,w.visibility,w.id,auth.uid())));
create policy whisper_tags_insert_owner on public.whisper_tags for insert with check (exists(select 1 from public.whispers w where w.id=whisper_id and w.author_id=auth.uid()));
create policy whisper_tags_delete_owner on public.whisper_tags for delete using (exists(select 1 from public.whispers w where w.id=whisper_id and w.author_id=auth.uid()));

drop policy if exists notifications_select_own on public.notifications;
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_select_own on public.notifications for select using (recipient_id=auth.uid());
create policy notifications_update_own on public.notifications for update using (recipient_id=auth.uid()) with check (recipient_id=auth.uid());

create or replace function public.mindrid_notify(recipient uuid, actor uuid, k text, tt text, tid uuid, msg text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if recipient is null or actor is null or recipient=actor then return; end if;
  insert into public.notifications(recipient_id,actor_id,kind,target_type,target_id,message)
  values(recipient,actor,k,tt,tid,msg);
end;
$$;
revoke all on function public.mindrid_notify(uuid,uuid,text,text,uuid,text) from public,anon,authenticated;

drop function if exists public.mindrid_connection_request(uuid);
create or replace function public.mindrid_connection_request(target uuid)
returns void language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); existing public.connections;
begin
 if me is null then raise exception 'Authentication required.'; end if;
 if target is null or target=me then raise exception 'Invalid connection target.'; end if;
 if exists (select 1 from public.blocks where (blocker_id=me and blocked_id=target) or (blocker_id=target and blocked_id=me)) then raise exception 'This connection is unavailable.'; end if;
 select * into existing from public.connections where requester_id=me and addressee_id=target;
 if existing.requester_id is not null then
   if existing.status='declined' then update public.connections set status='pending',updated_at=now() where requester_id=me and addressee_id=target;
   else return; end if;
 else
   select * into existing from public.connections where requester_id=target and addressee_id=me;
   if existing.requester_id is not null and existing.status='pending' then
      update public.connections set status='accepted',updated_at=now() where requester_id=target and addressee_id=me;
      insert into public.notifications(recipient_id,actor_id,kind,target_type,target_id,message) values(target,me,'connection_accepted','profile',me,'Your connection request was accepted.');
      return;
   end if;
   insert into public.connections(requester_id,addressee_id,status) values(me,target,'pending');
 end if;
 insert into public.notifications(recipient_id,actor_id,kind,target_type,target_id,message) values(target,me,'connection_request','profile',me,'You received a connection request.');
end;
$$;
grant execute on function public.mindrid_connection_request(uuid) to authenticated;

create or replace function public.mindrid_accept_connection(requester uuid)
returns void language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid();
begin
 if me is null then raise exception 'Authentication required.'; end if;
 update public.connections set status='accepted',updated_at=now() where requester_id=requester and addressee_id=me and status='pending';
 if not found then raise exception 'Connection request not found.'; end if;
 insert into public.notifications(recipient_id,actor_id,kind,target_type,target_id,message) values(requester,me,'connection_accepted','profile',me,'Your connection request was accepted.');
end;
$$;
grant execute on function public.mindrid_accept_connection(uuid) to authenticated;

create or replace function public.mindrid_disconnect(target uuid)
returns void language sql security definer set search_path=public as $$
 delete from public.connections where (requester_id=auth.uid() and addressee_id=target) or (requester_id=target and addressee_id=auth.uid());
$$;
grant execute on function public.mindrid_disconnect(uuid) to authenticated;

create or replace function public.mindrid_mark_notifications_read()
returns void language sql security definer set search_path=public as $$
 update public.notifications set is_read=true where recipient_id=auth.uid();
$$;
grant execute on function public.mindrid_mark_notifications_read() to authenticated;

create or replace function public.mindrid_deactivate_account()
returns void language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); begin if me is null then raise exception 'Authentication required.'; end if; update public.profiles set is_deactivated=true where id=me; end; $$;
grant execute on function public.mindrid_deactivate_account() to authenticated;

create or replace function public.mindrid_reactivate_account()
returns void language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); begin if me is null then raise exception 'Authentication required.'; end if; update public.profiles set is_deactivated=false where id=me; end; $$;
grant execute on function public.mindrid_reactivate_account() to authenticated;

create or replace function public.mindrid_delete_account()
returns void language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); begin if me is null then raise exception 'Authentication required.'; end if; delete from storage.objects where bucket_id='mindrid-media' and (storage.foldername(name))[1]=me::text; delete from auth.users where id=me; end; $$;
grant execute on function public.mindrid_delete_account() to authenticated;

create or replace function public.mindrid_follow_counts(target uuid)
returns table(followers bigint, following bigint)
language sql
stable
security definer
set search_path=public
as $$
  select
    (select count(*) from public.follows where following_id=target),
    (select count(*) from public.follows where follower_id=target);
$$;
revoke all on function public.mindrid_follow_counts(uuid) from public;
grant execute on function public.mindrid_follow_counts(uuid) to anon, authenticated;

create or replace function public.mindrid_create_group(group_name text, group_description text, country text, city text)
returns uuid language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); gid uuid; begin if me is null then raise exception 'Authentication required.'; end if; insert into public.groups(owner_id,name,description,location_country,location_city) values(me,trim(group_name),coalesce(group_description,''),nullif(trim(country),''),nullif(trim(city),'')) returning id into gid; insert into public.group_members(group_id,user_id,role) values(gid,me,'owner'); return gid; end; $$;
grant execute on function public.mindrid_create_group(text,text,text,text) to authenticated;

create or replace function public.mindrid_join_group(gid uuid)
returns void language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null then raise exception 'Authentication required.'; end if; if not exists(select 1 from public.groups where id=gid) then raise exception 'Group not found.'; end if; insert into public.group_members(group_id,user_id) values(gid,auth.uid()) on conflict do nothing; end; $$;
grant execute on function public.mindrid_join_group(uuid) to authenticated;

create or replace function public.mindrid_leave_group(gid uuid)
returns void language sql security definer set search_path=public as $$ delete from public.group_members where group_id=gid and user_id=auth.uid() and role<>'owner'; $$;
grant execute on function public.mindrid_leave_group(uuid) to authenticated;

create or replace function public.mindrid_follow_notification() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.follower_id<>new.following_id then
    perform public.mindrid_notify(new.following_id,new.follower_id,'follow','profile',new.follower_id,'Someone followed you.');
  end if;
  return new;
end;
$$;
drop trigger if exists follows_notify on public.follows;
create trigger follows_notify after insert on public.follows for each row execute procedure public.mindrid_follow_notification();

-- Notification triggers.
create or replace function public.mindrid_comment_notification() returns trigger language plpgsql security definer set search_path=public as $$ declare owner uuid; begin select author_id into owner from public.whispers where id=new.whisper_id; perform public.mindrid_notify(owner,new.author_id,'reply','whisper',new.whisper_id,'Someone replied to your Whisper.'); return new; end; $$;
drop trigger if exists comments_notify on public.comments; create trigger comments_notify after insert on public.comments for each row execute procedure public.mindrid_comment_notification();
create or replace function public.mindrid_like_notification() returns trigger language plpgsql security definer set search_path=public as $$ declare owner uuid; begin select author_id into owner from public.whispers where id=new.whisper_id; perform public.mindrid_notify(owner,new.user_id,'like','whisper',new.whisper_id,'Someone liked your Whisper.'); return new; end; $$;
drop trigger if exists likes_notify on public.likes; create trigger likes_notify after insert on public.likes for each row execute procedure public.mindrid_like_notification();
create or replace function public.mindrid_reaction_notification() returns trigger language plpgsql security definer set search_path=public as $$ declare owner uuid; begin select author_id into owner from public.comments where id=new.comment_id; perform public.mindrid_notify(owner,new.user_id,'comment_reaction','comment',new.comment_id,'Someone reacted to your reply.'); return new; end; $$;
drop trigger if exists comment_reactions_notify on public.comment_reactions; create trigger comment_reactions_notify after insert on public.comment_reactions for each row execute procedure public.mindrid_reaction_notification();
create or replace function public.mindrid_message_notification() returns trigger language plpgsql security definer set search_path=public as $$ declare recipient uuid; begin for recipient in select user_id from public.conversation_members where conversation_id=new.conversation_id and user_id<>new.sender_id loop perform public.mindrid_notify(recipient,new.sender_id,'message','conversation',new.conversation_id,'You received a private message.'); end loop; return new; end; $$;
drop trigger if exists messages_notify on public.messages; create trigger messages_notify after insert on public.messages for each row execute procedure public.mindrid_message_notification();

create index if not exists follows_following_idx on public.follows(following_id,created_at desc);
create index if not exists follows_follower_idx on public.follows(follower_id,created_at desc);
create index if not exists whisper_history_user_idx on public.whisper_history(user_id,viewed_at desc);
create index if not exists whisper_history_whisper_idx on public.whisper_history(whisper_id,viewed_at desc);

create index if not exists profiles_location_idx on public.profiles(location_country,location_city);
create index if not exists connections_addressee_idx on public.connections(addressee_id,status);
create index if not exists connections_requester_idx on public.connections(requester_id,status);
create index if not exists group_members_user_idx on public.group_members(user_id,group_id);
create index if not exists whisper_tags_value_idx on public.whisper_tags(tag_type,tag_value);
create index if not exists circle_messages_circle_idx on public.circle_messages(circle_id,created_at desc);
create index if not exists notifications_recipient_idx on public.notifications(recipient_id,is_read,created_at desc);
create index if not exists profiles_username_trgm_idx on public.profiles using gin (username gin_trgm_ops);
create index if not exists profiles_display_name_trgm_idx on public.profiles using gin (display_name gin_trgm_ops);
create index if not exists profiles_city_trgm_idx on public.profiles using gin (location_city gin_trgm_ops);
create index if not exists groups_name_trgm_idx on public.groups using gin (name gin_trgm_ops);
create index if not exists groups_description_trgm_idx on public.groups using gin (description gin_trgm_ops);
create index if not exists whispers_body_trgm_idx on public.whispers using gin (body gin_trgm_ops);
create index if not exists whisper_tags_value_trgm_idx on public.whisper_tags using gin (tag_value gin_trgm_ops);

grant select,update on public.profiles to authenticated;
grant select,insert,update,delete on public.connections to authenticated;
grant select,insert,update,delete on public.groups,public.group_members to authenticated;
grant select,insert,delete on public.whisper_tags to authenticated;
grant select,insert on public.circle_messages to authenticated;
grant select,update on public.notifications to authenticated;
notify pgrst,'reload schema';


-- V8 realtime delivery: notifications should arrive without requiring a page refresh.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='circle_messages') then
    alter publication supabase_realtime add table public.circle_messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
exception when undefined_object then
  null;
end $$;

-- V8: keep notification rows protected; realtime only exposes rows permitted by RLS.
alter table public.notifications enable row level security;


-- V17 Thought Development links
create table if not exists public.whisper_links (
  source_whisper_id uuid not null references public.whispers(id) on delete cascade,
  target_whisper_id uuid not null references public.whispers(id) on delete cascade,
  link_type text not null check (link_type in ('development','changed')),
  created_at timestamptz not null default now(),
  primary key (source_whisper_id,target_whisper_id,link_type),
  check (source_whisper_id<>target_whisper_id)
);

alter table public.whisper_links enable row level security;
drop policy if exists whisper_links_select_visible on public.whisper_links;
drop policy if exists whisper_links_insert_own on public.whisper_links;
drop policy if exists whisper_links_delete_own on public.whisper_links;
create policy whisper_links_select_visible on public.whisper_links for select using (
  exists (select 1 from public.whispers s where s.id=source_whisper_id and public.mindrid_can_view_whisper(s.author_id,s.visibility,s.id,auth.uid()))
  and exists (select 1 from public.whispers t where t.id=target_whisper_id and public.mindrid_can_view_whisper(t.author_id,t.visibility,t.id,auth.uid()))
);
create policy whisper_links_insert_own on public.whisper_links for insert with check (
  exists (select 1 from public.whispers s where s.id=source_whisper_id and public.mindrid_can_view_whisper(s.author_id,s.visibility,s.id,auth.uid()))
  and exists (select 1 from public.whispers t where t.id=target_whisper_id and t.author_id=auth.uid())
);
create policy whisper_links_delete_own on public.whisper_links for delete using (
  exists (select 1 from public.whispers s where s.id=source_whisper_id and public.mindrid_can_view_whisper(s.author_id,s.visibility,s.id,auth.uid()))
  and exists (select 1 from public.whispers t where t.id=target_whisper_id and t.author_id=auth.uid())
);
create index if not exists whisper_links_source_idx on public.whisper_links(source_whisper_id,created_at desc);
create index if not exists whisper_links_target_idx on public.whisper_links(target_whisper_id,created_at desc);
grant select,insert,delete on public.whisper_links to authenticated;

-- V17.1 recommendation feedback
create table if not exists public.recommendation_feedback (
  user_id uuid not null references auth.users(id) on delete cascade,
  whisper_id uuid not null references public.whispers(id) on delete cascade,
  feedback_type text not null check (feedback_type in ('more','less','not_relevant','already_seen')),
  created_at timestamptz not null default now(),
  primary key (user_id, whisper_id, feedback_type)
);
alter table public.recommendation_feedback enable row level security;
drop policy if exists recommendation_feedback_select_own on public.recommendation_feedback;
drop policy if exists recommendation_feedback_insert_own on public.recommendation_feedback;
drop policy if exists recommendation_feedback_update_own on public.recommendation_feedback;
drop policy if exists recommendation_feedback_delete_own on public.recommendation_feedback;
create policy recommendation_feedback_select_own on public.recommendation_feedback for select using (user_id = auth.uid());
create policy recommendation_feedback_insert_own on public.recommendation_feedback for insert with check (user_id = auth.uid());
create policy recommendation_feedback_update_own on public.recommendation_feedback for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy recommendation_feedback_delete_own on public.recommendation_feedback for delete using (user_id = auth.uid());
create index if not exists recommendation_feedback_user_idx on public.recommendation_feedback(user_id,created_at desc);
grant select,insert,update,delete on public.recommendation_feedback to authenticated;

-- V17.1 recommendation feedback
create table if not exists public.recommendation_feedback (
  user_id uuid not null references auth.users(id) on delete cascade,
  whisper_id uuid not null references public.whispers(id) on delete cascade,
  feedback_type text not null check (feedback_type in ('more','less','not_relevant','already_seen')),
  created_at timestamptz not null default now(),
  primary key (user_id, whisper_id, feedback_type)
);
alter table public.recommendation_feedback enable row level security;
drop policy if exists recommendation_feedback_select_own on public.recommendation_feedback;
drop policy if exists recommendation_feedback_insert_own on public.recommendation_feedback;
drop policy if exists recommendation_feedback_update_own on public.recommendation_feedback;
drop policy if exists recommendation_feedback_delete_own on public.recommendation_feedback;
create policy recommendation_feedback_select_own on public.recommendation_feedback for select using (user_id = auth.uid());
create policy recommendation_feedback_insert_own on public.recommendation_feedback for insert with check (user_id = auth.uid());
create policy recommendation_feedback_update_own on public.recommendation_feedback for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy recommendation_feedback_delete_own on public.recommendation_feedback for delete using (user_id = auth.uid());
create index if not exists recommendation_feedback_user_idx on public.recommendation_feedback(user_id,created_at desc);
grant select,insert,update,delete on public.recommendation_feedback to authenticated;
-- mindRID V18.1: Follow a reflection discussion and receive notifications for new replies.
-- Run once in Supabase SQL Editor after the existing V17 migration/schema is installed.
create table if not exists public.whisper_subscriptions (
  user_id uuid not null references auth.users(id) on delete cascade,
  whisper_id uuid not null references public.whispers(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, whisper_id)
);

alter table public.whisper_subscriptions enable row level security;
drop policy if exists whisper_subscriptions_select_own on public.whisper_subscriptions;
drop policy if exists whisper_subscriptions_insert_own on public.whisper_subscriptions;
drop policy if exists whisper_subscriptions_delete_own on public.whisper_subscriptions;
create policy whisper_subscriptions_select_own on public.whisper_subscriptions
  for select to authenticated using (user_id = auth.uid());
create policy whisper_subscriptions_insert_own on public.whisper_subscriptions
  for insert to authenticated with check (
    user_id = auth.uid() and exists (
      select 1 from public.whispers w
      where w.id = whisper_id and public.mindrid_can_view_whisper(w.author_id, w.visibility, w.id, auth.uid())
    )
  );
create policy whisper_subscriptions_delete_own on public.whisper_subscriptions
  for delete to authenticated using (user_id = auth.uid());
grant select, insert, delete on public.whisper_subscriptions to authenticated;
create index if not exists whisper_subscriptions_whisper_idx on public.whisper_subscriptions(whisper_id, created_at desc);

create or replace function public.mindrid_notify_discussion_subscribers()
returns trigger language plpgsql security definer set search_path = public as $$
declare owner_id uuid;
        sub record;
begin
  select author_id into owner_id from public.whispers where id = new.whisper_id;
  for sub in
    select s.user_id from public.whisper_subscriptions s
    join public.whispers w on w.id = s.whisper_id
    where s.whisper_id = new.whisper_id and s.user_id <> new.author_id and s.user_id <> owner_id
      and public.mindrid_can_view_whisper(w.author_id, w.visibility, w.id, s.user_id)
  loop
    insert into public.notifications(recipient_id, actor_id, kind, target_type, target_id, message)
    values(sub.user_id, new.author_id, 'discussion_reply', 'whisper', new.whisper_id,
      'A discussion you follow has a new reply.');
  end loop;
  return new;
end;
$$;
drop trigger if exists comments_notify_discussion_subscribers on public.comments;
create trigger comments_notify_discussion_subscribers after insert on public.comments
  for each row execute procedure public.mindrid_notify_discussion_subscribers();
