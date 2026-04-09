-- =====================================================
-- Migration: Fix reports table FK cascade behaviour
-- Problem: ON DELETE CASCADE on reply_id/record_id/ask_id
--          caused report row to be deleted when content
--          was removed by admin, preventing status update.
-- Fix: Change to ON DELETE SET NULL so report is kept
--      as audit trail even after content is removed.
-- Date: 2026-04-03
-- =====================================================

-- Drop old FK constraints
ALTER TABLE public.reports
  DROP CONSTRAINT IF EXISTS reports_record_id_fkey,
  DROP CONSTRAINT IF EXISTS reports_ask_id_fkey,
  DROP CONSTRAINT IF EXISTS reports_reply_id_fkey;

-- Re-add with ON DELETE SET NULL
ALTER TABLE public.reports
  ADD CONSTRAINT reports_record_id_fkey
    FOREIGN KEY (record_id) REFERENCES public.records(id) ON DELETE SET NULL,
  ADD CONSTRAINT reports_ask_id_fkey
    FOREIGN KEY (ask_id) REFERENCES public.asks(id) ON DELETE SET NULL,
  ADD CONSTRAINT reports_reply_id_fkey
    FOREIGN KEY (reply_id) REFERENCES public.replies(id) ON DELETE SET NULL;

-- Note: After this migration the CONSTRAINT report_target_check will need
-- to allow nulls in all three columns (when content was deleted by admin).
-- Drop and recreate the constraint to allow all-null state:
ALTER TABLE public.reports
  DROP CONSTRAINT IF EXISTS report_target_check;

ALTER TABLE public.reports
  ADD CONSTRAINT report_target_check CHECK (
    -- At least one target was set originally (not enforced after deletion)
    -- This constraint is relaxed to allow nulls when content was deleted
    (record_id IS NOT NULL) OR (ask_id IS NOT NULL) OR (reply_id IS NOT NULL)
    OR (record_id IS NULL AND ask_id IS NULL AND reply_id IS NULL)  -- allow all-null (content deleted)
  );
