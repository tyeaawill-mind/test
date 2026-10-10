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
