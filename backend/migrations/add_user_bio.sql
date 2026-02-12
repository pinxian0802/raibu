-- Migration: Add bio field to users table
-- Date: 2026-02-10

-- Add bio column to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bio TEXT;

-- Add comment
COMMENT ON COLUMN public.users.bio IS 'User biography/description';
