-- ============================================
-- Reports Table Migration
-- 檢舉功能資料表
-- 日期: 2026/01
-- ============================================

-- 建立 reports 表
CREATE TABLE public.reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reporter_id UUID REFERENCES public.users(id) NOT NULL,
  record_id UUID REFERENCES public.records(id) ON DELETE CASCADE,
  ask_id UUID REFERENCES public.asks(id) ON DELETE CASCADE,
  reply_id UUID REFERENCES public.replies(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  reason_category TEXT NOT NULL CHECK (
    reason_category IN ('SPAM', 'INAPPROPRIATE', 'HARASSMENT', 'FALSE_INFO', 'OTHER')
  ),
  status TEXT DEFAULT 'PENDING' CHECK (
    status IN ('PENDING', 'REVIEWED', 'RESOLVED', 'DISMISSED')
  ),
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  reviewed_at TIMESTAMPTZ,
  
  CONSTRAINT report_target_check CHECK (
    (record_id IS NOT NULL AND ask_id IS NULL AND reply_id IS NULL) OR
    (record_id IS NULL AND ask_id IS NOT NULL AND reply_id IS NULL) OR
    (record_id IS NULL AND ask_id IS NULL AND reply_id IS NOT NULL)
  )
);

-- 防止重複檢舉索引
CREATE UNIQUE INDEX idx_reports_user_record ON public.reports (reporter_id, record_id) 
  WHERE record_id IS NOT NULL;
CREATE UNIQUE INDEX idx_reports_user_ask ON public.reports (reporter_id, ask_id) 
  WHERE ask_id IS NOT NULL;
CREATE UNIQUE INDEX idx_reports_user_reply ON public.reports (reporter_id, reply_id) 
  WHERE reply_id IS NOT NULL;

-- 優化索引
CREATE INDEX idx_reports_status ON public.reports (status);
CREATE INDEX idx_reports_created_at ON public.reports (created_at);
CREATE INDEX idx_reports_reporter_id ON public.reports (reporter_id);

-- 啟用 RLS
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- RLS 政策
CREATE POLICY "Users can view their own reports" 
  ON public.reports FOR SELECT 
  USING (auth.uid() = reporter_id);

CREATE POLICY "Users can insert reports" 
  ON public.reports FOR INSERT 
  WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Users can delete their own reports" 
  ON public.reports FOR DELETE 
  USING (auth.uid() = reporter_id);
