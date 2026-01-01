-- ============================================
-- Raibu Database Schema v3.1
-- 根據系統框架規格書設計
-- ============================================

-- 1. 啟用 PostGIS 擴展
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================
-- 2. 使用者記錄 (User Model)
-- ============================================
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name TEXT,
  avatar_url TEXT,
  total_views INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- 3. 紀錄標點主記錄 (Record Model)
-- ============================================
CREATE TABLE public.records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) NOT NULL,
  description TEXT NOT NULL,
  main_image_url TEXT,
  media_count INTEGER DEFAULT 0,
  like_count INTEGER DEFAULT 0,
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- 4. 詢問標點主記錄 (Ask Model)
-- ============================================
CREATE TABLE public.asks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) NOT NULL,
  center GEOMETRY(Point, 4326) NOT NULL,
  radius_meters INTEGER DEFAULT 500,
  question TEXT NOT NULL,
  main_image_url TEXT,
  status TEXT DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'RESOLVED')),
  like_count INTEGER DEFAULT 0,
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- 5. 回覆記錄 (Reply Model)  
-- ============================================
CREATE TABLE public.replies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  record_id UUID REFERENCES public.records(id) ON DELETE CASCADE,
  ask_id UUID REFERENCES public.asks(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) NOT NULL,
  content TEXT NOT NULL,
  is_onsite BOOLEAN DEFAULT FALSE,
  like_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT reply_target_check CHECK (
    (record_id IS NOT NULL AND ask_id IS NULL) OR 
    (record_id IS NULL AND ask_id IS NOT NULL)
  )
);

-- ============================================
-- 6. 圖片媒體記錄 (Image Media Model)
-- ============================================
CREATE TABLE public.image_media (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) NOT NULL,
  client_key TEXT,
  record_id UUID REFERENCES public.records(id) ON DELETE CASCADE,
  ask_id UUID REFERENCES public.asks(id) ON DELETE CASCADE,
  reply_id UUID REFERENCES public.replies(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETED')),
  original_public_url TEXT,
  thumbnail_public_url TEXT,
  location GEOMETRY(Point, 4326),
  captured_at TIMESTAMPTZ,
  uploaded_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  display_order INTEGER DEFAULT 0,
  address TEXT,
  CONSTRAINT image_parent_check CHECK (
    (record_id IS NOT NULL AND ask_id IS NULL AND reply_id IS NULL) OR
    (record_id IS NULL AND ask_id IS NOT NULL AND reply_id IS NULL) OR
    (record_id IS NULL AND ask_id IS NULL AND reply_id IS NOT NULL) OR
    (record_id IS NULL AND ask_id IS NULL AND reply_id IS NULL)
  )
);

-- ============================================
-- 7. 愛心記錄 (Like Model)
-- ============================================
CREATE TABLE public.likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) NOT NULL,
  record_id UUID REFERENCES public.records(id) ON DELETE CASCADE,
  ask_id UUID REFERENCES public.asks(id) ON DELETE CASCADE,
  reply_id UUID REFERENCES public.replies(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT like_target_check CHECK (
    (record_id IS NOT NULL AND ask_id IS NULL AND reply_id IS NULL) OR
    (record_id IS NULL AND ask_id IS NOT NULL AND reply_id IS NULL) OR
    (record_id IS NULL AND ask_id IS NULL AND reply_id IS NOT NULL)
  )
);

-- 唯一約束：防止重複點讚
CREATE UNIQUE INDEX idx_likes_user_record ON public.likes (user_id, record_id) WHERE record_id IS NOT NULL;
CREATE UNIQUE INDEX idx_likes_user_ask ON public.likes (user_id, ask_id) WHERE ask_id IS NOT NULL;
CREATE UNIQUE INDEX idx_likes_user_reply ON public.likes (user_id, reply_id) WHERE reply_id IS NOT NULL;

-- ============================================
-- 8. 清理日誌表 (Cleanup Logs Model)
-- ============================================
CREATE TABLE public.cleanup_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  deleted_image_id UUID NOT NULL,
  deleted_user_id UUID,
  client_key TEXT,
  reason TEXT,
  deleted_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- 9. 空間索引
-- ============================================
CREATE INDEX idx_images_location ON public.image_media USING GIST (location);
CREATE INDEX idx_asks_center ON public.asks USING GIST (center);

-- 其他常用索引
CREATE INDEX idx_image_media_record_id ON public.image_media (record_id);
CREATE INDEX idx_image_media_ask_id ON public.image_media (ask_id);
CREATE INDEX idx_image_media_reply_id ON public.image_media (reply_id);
CREATE INDEX idx_image_media_status ON public.image_media (status);
CREATE INDEX idx_image_media_uploaded_at ON public.image_media (uploaded_at);
CREATE INDEX idx_replies_record_id ON public.replies (record_id);
CREATE INDEX idx_replies_ask_id ON public.replies (ask_id);
CREATE INDEX idx_asks_created_at ON public.asks (created_at);

-- ============================================
-- 10. 啟用 Row Level Security (RLS)
-- ============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.image_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cleanup_logs ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 11. RLS 政策
-- ============================================

-- Users
CREATE POLICY "Users are viewable by everyone" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can update their own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

-- Records
CREATE POLICY "Records are viewable by everyone" ON public.records FOR SELECT USING (true);
CREATE POLICY "Users can insert their own records" ON public.records FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own records" ON public.records FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own records" ON public.records FOR DELETE USING (auth.uid() = user_id);

-- Asks
CREATE POLICY "Asks are viewable by everyone" ON public.asks FOR SELECT USING (true);
CREATE POLICY "Users can insert their own asks" ON public.asks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own asks" ON public.asks FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own asks" ON public.asks FOR DELETE USING (auth.uid() = user_id);

-- Replies
CREATE POLICY "Replies are viewable by everyone" ON public.replies FOR SELECT USING (true);
CREATE POLICY "Users can insert their own replies" ON public.replies FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own replies" ON public.replies FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own replies" ON public.replies FOR DELETE USING (auth.uid() = user_id);

-- Image Media
CREATE POLICY "Images are viewable by everyone" ON public.image_media FOR SELECT USING (true);
CREATE POLICY "Users can insert their own images" ON public.image_media FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own images" ON public.image_media FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own images" ON public.image_media FOR DELETE USING (auth.uid() = user_id);

-- Likes
CREATE POLICY "Likes are viewable by everyone" ON public.likes FOR SELECT USING (true);
CREATE POLICY "Users can insert their own likes" ON public.likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own likes" ON public.likes FOR DELETE USING (auth.uid() = user_id);

-- Cleanup Logs (僅管理員可存取)
CREATE POLICY "Only service role can access cleanup logs" ON public.cleanup_logs FOR ALL USING (false);

-- ============================================
-- 12. 啟用 Realtime
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.records;
ALTER PUBLICATION supabase_realtime ADD TABLE public.asks;
ALTER PUBLICATION supabase_realtime ADD TABLE public.replies;
ALTER PUBLICATION supabase_realtime ADD TABLE public.likes;
