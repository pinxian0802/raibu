-- Update get_record_images_in_bounds to include created_at (mapped from uploaded_at)
-- This is required for sorting images by date in the cluster bottom sheet.

CREATE OR REPLACE FUNCTION get_record_images_in_bounds(
  p_min_lng FLOAT,
  p_min_lat FLOAT,
  p_max_lng FLOAT,
  p_max_lat FLOAT
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
    AND im.location && ST_MakeEnvelope(p_min_lng, p_min_lat, p_max_lng, p_max_lat, 4326);
END;
$$;
