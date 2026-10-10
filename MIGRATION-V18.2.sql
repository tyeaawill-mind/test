-- mindRID V18.2: optional media cover preview metadata. Safe to run once or repeatedly.
alter table public.whisper_media add column if not exists is_preview boolean not null default false;
alter table public.whisper_media add column if not exists preview_mode text not null default 'small';
alter table public.whisper_media drop constraint if exists whisper_media_preview_mode_check;
alter table public.whisper_media add constraint whisper_media_preview_mode_check check (preview_mode in ('small','cover'));
