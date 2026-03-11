-- Update get_record_images_in_bounds to support optional time filtering
-- Parameters p_start_date and p_end_date are optional (NULL = no filter)

CREATE OR REPLACE FUNCTION get_record_images_in_bounds(
  p_min_lng FLOAT,
  p_min_lat FLOAT,
  p_max_lng FLOAT,
  p_max_lat FLOAT,
  p_start_date TIMESTAMPTZ DEFAULT NULL,
  p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  image_id UUID,
  record_id UUID,
  thumbnail_public_url TEXT,
  lat FLOAT,
  lng FLOAT,
  display_order INTEGER,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    im.id AS image_id,
    im.record_id,
    im.thumbnail_public_url,
    ST_Y(im.location::geometry) AS lat,
    ST_X(im.location::geometry) AS lng,
    im.display_order,
    im.uploaded_at AS created_at
  FROM
    image_media im
  WHERE
    im.status = 'COMPLETED'
    AND im.record_id IS NOT NULL
    AND im.location && ST_MakeEnvelope(p_min_lng, p_min_lat, p_max_lng, p_max_lat, 4326)
    AND (p_start_date IS NULL OR im.uploaded_at >= p_start_date)
    AND (p_end_date IS NULL OR im.uploaded_at <= p_end_date);
END;
$$;

-- Update get_asks_in_bounds to support optional time filtering
-- Removes hardcoded 48-hour filter; time range is now controlled by caller

CREATE OR REPLACE FUNCTION get_asks_in_bounds(
  p_min_lng FLOAT,
  p_min_lat FLOAT,
  p_max_lng FLOAT,
  p_max_lat FLOAT,
  p_start_date TIMESTAMPTZ DEFAULT NULL,
  p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  lng FLOAT,
  lat FLOAT,
  radius_meters INTEGER,
  title TEXT,
  question TEXT,
  main_image_url TEXT,
  author_avatar_url TEXT,
  status TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    ST_X(a.center::geometry) AS lng,
    ST_Y(a.center::geometry) AS lat,
    a.radius_meters,
    a.title,
    a.question,
    a.main_image_url,
    u.avatar_url AS author_avatar_url,
    a.status,
    a.created_at
  FROM asks a
  LEFT JOIN users u ON u.id = a.user_id
  WHERE
    a.center && ST_MakeEnvelope(p_min_lng, p_min_lat, p_max_lng, p_max_lat, 4326)
    AND (p_start_date IS NULL OR a.created_at >= p_start_date)
    AND (p_end_date IS NULL OR a.created_at <= p_end_date);
END;
$$;
