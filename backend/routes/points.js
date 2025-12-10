const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');

// GET /points - List points with filters
router.get('/', async (req, res) => {
  const { lat_min, lat_max, lng_min, lng_max } = req.query;

  let query = supabase
    .from('points')
    .select(`
      *,
      images (thumbnail_url),
      point_likes (count),
      point_comments (count)
    `);

  if (lat_min && lat_max && lng_min && lng_max) {
    query = query
      .gte('lat', lat_min)
      .lte('lat', lat_max)
      .gte('lng', lng_min)
      .lte('lng', lng_max);
  }

  const { data, error } = await query;

  if (error) {
    return res.status(500).json({ error: error.message });
  }

  // Format response to include counts and first thumbnail
  const formattedData = data.map(point => ({
    ...point,
    thumbnail_url: point.images?.[0]?.thumbnail_url || null,
    likes_count: point.point_likes?.[0]?.count || 0,
    comments_count: point.point_comments?.[0]?.count || 0,
  }));

  res.json(formattedData);
});

// GET /points/:pointId - Get point details
router.get('/:pointId', async (req, res) => {
  const { pointId } = req.params;

  const { data, error } = await supabase
    .from('points')
    .select(`
      *,
      images (*),
      point_likes (count),
      point_comments (count)
    `)
    .eq('id', pointId)
    .single();

  if (error) {
    return res.status(404).json({ error: 'Point not found' });
  }

  const formattedData = {
    ...data,
    likes_count: data.point_likes?.[0]?.count || 0,
    comments_count: data.point_comments?.[0]?.count || 0,
  };

  res.json(formattedData);
});

// POST /points - Create a new point
router.post('/', async (req, res) => {
  const { title, description, lat, lng, user_id } = req.body;

  // TODO: Verify user_id matches the authenticated user token
  
  if (!title || !lat || !lng || !user_id) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const { data, error } = await supabase
    .from('points')
    .insert([{ title, description, lat, lng, user_id }])
    .select()
    .single();

  if (error) {
    return res.status(500).json({ error: error.message });
  }

  res.status(201).json(data);
});

module.exports = router;
