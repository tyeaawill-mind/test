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
