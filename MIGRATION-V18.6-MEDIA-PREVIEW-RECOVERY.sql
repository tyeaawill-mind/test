-- mindRID V18.6 recovery migration: align live whisper_media schema with app expectations.
-- Run against the EXISTING mindRID Supabase project after backup. Idempotent.
BEGIN;
DO $$ BEGIN
  IF to_regclass('public.whisper_media') IS NULL THEN
    RAISE EXCEPTION 'public.whisper_media is missing; stop and restore the baseline schema first';
  END IF;
END $$;
ALTER TABLE public.whisper_media ADD COLUMN IF NOT EXISTS is_preview boolean;
ALTER TABLE public.whisper_media ADD COLUMN IF NOT EXISTS preview_mode text;
UPDATE public.whisper_media SET is_preview = false WHERE is_preview IS NULL;
UPDATE public.whisper_media SET preview_mode = 'small' WHERE preview_mode IS NULL;
ALTER TABLE public.whisper_media ALTER COLUMN is_preview SET DEFAULT false;
ALTER TABLE public.whisper_media ALTER COLUMN is_preview SET NOT NULL;
ALTER TABLE public.whisper_media ALTER COLUMN preview_mode SET DEFAULT 'small';
ALTER TABLE public.whisper_media ALTER COLUMN preview_mode SET NOT NULL;
ALTER TABLE public.whisper_media DROP CONSTRAINT IF EXISTS whisper_media_preview_mode_check;
ALTER TABLE public.whisper_media ADD CONSTRAINT whisper_media_preview_mode_check CHECK (preview_mode IN ('small','cover'));
COMMIT;
NOTIFY pgrst, 'reload schema';
