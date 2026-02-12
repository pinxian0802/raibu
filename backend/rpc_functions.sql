-- ============================================
-- Raibu PostGIS RPC 函數
-- 用於空間查詢和座標操作
-- 在 Supabase SQL Editor 執行此檔案
-- ============================================

-- 1. 建立 Ask 時寫入 PostGIS 座標
CREATE OR REPLACE FUNCTION create_ask(
  p_user_id UUID,
  p_lng DOUBLE PRECISION,
  p_lat DOUBLE PRECISION,
  p_radius_meters INTEGER,
  p_question TEXT
)
RETURNS UUID AS $$
DECLARE
  new_id UUID;
BEGIN
  INSERT INTO asks (user_id, center, radius_meters, question)
  VALUES (
    p_user_id,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326),
    p_radius_meters,
    p_question
  )
  RETURNING id INTO new_id;
  
  RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- 2. 更新圖片並寫入 PostGIS 座標
CREATE OR REPLACE FUNCTION update_image_with_location(
  p_image_id UUID,
  p_record_id UUID,
  p_lng DOUBLE PRECISION,
  p_lat DOUBLE PRECISION,
  p_captured_at TIMESTAMPTZ,
  p_display_order INTEGER,
  p_address TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  UPDATE image_media
  SET
    record_id = p_record_id,
    status = 'COMPLETED',
    location = CASE 
      WHEN p_lng IS NOT NULL AND p_lat IS NOT NULL 
      THEN ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)
      ELSE NULL
    END,
    captured_at = p_captured_at,
    display_order = p_display_order,
    address = p_address
  WHERE id = p_image_id;
END;
$$ LANGUAGE plpgsql;

-- 3. 取得地圖範圍內的紀錄圖片
CREATE OR REPLACE FUNCTION get_record_images_in_bounds(
  p_min_lng DOUBLE PRECISION,
  p_min_lat DOUBLE PRECISION,
  p_max_lng DOUBLE PRECISION,
  p_max_lat DOUBLE PRECISION
)
RETURNS TABLE (
  image_id UUID,
  record_id UUID,
  thumbnail_public_url TEXT,
  lng DOUBLE PRECISION,
  lat DOUBLE PRECISION,
  display_order INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    im.id AS image_id,
    im.record_id,
    im.thumbnail_public_url,
    ST_X(im.location) AS lng,
    ST_Y(im.location) AS lat,
    im.display_order
  FROM image_media im
  WHERE im.status = 'COMPLETED'
    AND im.record_id IS NOT NULL
    AND im.location IS NOT NULL
    AND ST_Within(
      im.location,
      ST_MakeEnvelope(p_min_lng, p_min_lat, p_max_lng, p_max_lat, 4326)
    );
END;
$$ LANGUAGE plpgsql;

-- 3b. 取得單一紀錄的圖片列表（含座標）
CREATE OR REPLACE FUNCTION get_record_images_with_location(
  p_record_id UUID
)
RETURNS TABLE (
  id UUID,
  original_public_url TEXT,
  thumbnail_public_url TEXT,
  lng DOUBLE PRECISION,
  lat DOUBLE PRECISION,
  captured_at TIMESTAMPTZ,
  display_order INTEGER,
  address TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    im.id,
    im.original_public_url,
    im.thumbnail_public_url,
    ST_X(im.location) AS lng,
    ST_Y(im.location) AS lat,
    im.captured_at,
    im.display_order,
    im.address
  FROM image_media im
  WHERE im.record_id = p_record_id
    AND im.status = 'COMPLETED'
  ORDER BY im.display_order;
END;
$$ LANGUAGE plpgsql;

-- 3c. 取得單一詢問的圖片列表（含座標）
CREATE OR REPLACE FUNCTION get_ask_images_with_location(
  p_ask_id UUID
)
RETURNS TABLE (
  id UUID,
  original_public_url TEXT,
  thumbnail_public_url TEXT,
  lng DOUBLE PRECISION,
  lat DOUBLE PRECISION,
  display_order INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    im.id,
    im.original_public_url,
    im.thumbnail_public_url,
    ST_X(im.location) AS lng,
    ST_Y(im.location) AS lat,
    im.display_order
  FROM image_media im
  WHERE im.ask_id = p_ask_id
    AND im.status = 'COMPLETED'
  ORDER BY im.display_order;
END;
$$ LANGUAGE plpgsql;

-- 3d. 取得單一回覆的圖片列表（含座標）
CREATE OR REPLACE FUNCTION get_reply_images_with_location(
  p_reply_id UUID
)
RETURNS TABLE (
  id UUID,
  original_public_url TEXT,
  thumbnail_public_url TEXT,
  lng DOUBLE PRECISION,
  lat DOUBLE PRECISION,
  display_order INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    im.id,
    im.original_public_url,
    im.thumbnail_public_url,
    ST_X(im.location) AS lng,
    ST_Y(im.location) AS lat,
    im.display_order
  FROM image_media im
  WHERE im.reply_id = p_reply_id
    AND im.status = 'COMPLETED'
  ORDER BY im.display_order;
END;
$$ LANGUAGE plpgsql;

-- 4. 取得地圖範圍內的詢問標點 (含 48 小時過濾)
CREATE OR REPLACE FUNCTION get_asks_in_bounds(
  p_min_lng DOUBLE PRECISION,
  p_min_lat DOUBLE PRECISION,
  p_max_lng DOUBLE PRECISION,
  p_max_lat DOUBLE PRECISION
)
RETURNS TABLE (
  id UUID,
  lng DOUBLE PRECISION,
  lat DOUBLE PRECISION,
  radius_meters INTEGER,
  question TEXT,
  status TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    ST_X(a.center) AS lng,
    ST_Y(a.center) AS lat,
    a.radius_meters,
    a.question,
    a.status,
    a.created_at
  FROM asks a
  WHERE a.created_at >= NOW() - INTERVAL '48 hours'
    AND ST_Within(
      a.center,
      ST_MakeEnvelope(p_min_lng, p_min_lat, p_max_lng, p_max_lat, 4326)
    );
END;
$$ LANGUAGE plpgsql;

-- 4b. 取得使用者的詢問標點 (含座標)
CREATE OR REPLACE FUNCTION get_user_asks_with_coords(
  p_user_id UUID
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  lng DOUBLE PRECISION,
  lat DOUBLE PRECISION,
  radius_meters INTEGER,
  question TEXT,
  main_image_url TEXT,
  status TEXT,
  like_count INTEGER,
  view_count INTEGER,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.user_id,
    ST_X(a.center) AS lng,
    ST_Y(a.center) AS lat,
    a.radius_meters,
    a.question,
    a.main_image_url,
    a.status,
    a.like_count,
    a.view_count,
    a.created_at,
    a.updated_at
  FROM asks a
  WHERE a.user_id = p_user_id
  ORDER BY a.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 4c. 取得單一詢問標點詳情 (含座標)
CREATE OR REPLACE FUNCTION get_ask_detail_with_coords(
  p_ask_id UUID
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  lng DOUBLE PRECISION,
  lat DOUBLE PRECISION,
  radius_meters INTEGER,
  question TEXT,
  main_image_url TEXT,
  status TEXT,
  like_count INTEGER,
  view_count INTEGER,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.user_id,
    ST_X(a.center) AS lng,
    ST_Y(a.center) AS lat,
    a.radius_meters,
    a.question,
    a.main_image_url,
    a.status,
    a.like_count,
    a.view_count,
    a.created_at,
    a.updated_at
  FROM asks a
  WHERE a.id = p_ask_id;
END;
$$ LANGUAGE plpgsql;

-- 5. 增加觀看次數
CREATE OR REPLACE FUNCTION increment_view_count(
  p_table TEXT,
  p_id UUID
)
RETURNS VOID AS $$
BEGIN
  EXECUTE format(
    'UPDATE %I SET view_count = view_count + 1 WHERE id = $1',
    p_table
  ) USING p_id;
END;
$$ LANGUAGE plpgsql;

-- 6. 增加愛心數
CREATE OR REPLACE FUNCTION increment_like_count(
  p_table TEXT,
  p_id UUID
)
RETURNS VOID AS $$
BEGIN
  EXECUTE format(
    'UPDATE %I SET like_count = like_count + 1 WHERE id = $1',
    p_table
  ) USING p_id;
END;
$$ LANGUAGE plpgsql;

-- 7. 減少愛心數
CREATE OR REPLACE FUNCTION decrement_like_count(
  p_table TEXT,
  p_id UUID
)
RETURNS VOID AS $$
BEGIN
  EXECUTE format(
    'UPDATE %I SET like_count = GREATEST(like_count - 1, 0) WHERE id = $1',
    p_table
  ) USING p_id;
END;
$$ LANGUAGE plpgsql;

-- 8. 判斷座標是否在詢問範圍內 (Geo-fencing)
CREATE OR REPLACE FUNCTION is_within_ask_radius(
  p_ask_id UUID,
  p_lng DOUBLE PRECISION,
  p_lat DOUBLE PRECISION,
  p_tolerance_meters INTEGER DEFAULT 30
)
RETURNS BOOLEAN AS $$
DECLARE
  ask_record RECORD;
  point_to_check GEOMETRY;
  distance_meters DOUBLE PRECISION;
BEGIN
  -- 取得 Ask 資料
  SELECT center, radius_meters INTO ask_record
  FROM asks WHERE id = p_ask_id;
  
  IF ask_record IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- 建立要檢查的點
  point_to_check := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326);
  
  -- 計算距離（公尺）
  distance_meters := ST_Distance(
    ask_record.center::geography,
    point_to_check::geography
  );
  
  -- 判斷是否在範圍內（含容許誤差）
  RETURN distance_meters <= (ask_record.radius_meters + p_tolerance_meters);
END;
$$ LANGUAGE plpgsql;

-- 9. 取得特定用戶的詢問列表（含座標）
CREATE OR REPLACE FUNCTION get_asks_for_user(
  p_user_id UUID
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  lng DOUBLE PRECISION,
  lat DOUBLE PRECISION,
  radius_meters INTEGER,
  question TEXT,
  main_image_url TEXT,
  status TEXT,
  like_count INTEGER,
  view_count INTEGER,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.user_id,
    ST_X(a.center) AS lng,
    ST_Y(a.center) AS lat,
    a.radius_meters,
    a.question,
    a.main_image_url,
    a.status,
    a.like_count,
    a.view_count,
    a.created_at,
    a.updated_at
  FROM asks a
  WHERE a.user_id = p_user_id
  ORDER BY a.created_at DESC;
END;
$$ LANGUAGE plpgsql;
