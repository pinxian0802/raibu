-- ============================================
-- 新增用戶封鎖欄位
-- 日期: 2026/03
-- ============================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS banned_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ban_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_users_is_banned ON public.users (is_banned) WHERE is_banned = TRUE;
