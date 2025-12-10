const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');

// POST /points/:pointId/like - Like a point
router.post('/:pointId/like', async (req, res) => {
  const { pointId } = req.params;
  const { user_id } = req.body;

  if (!user_id) return res.status(400).json({ error: 'Missing user_id' });

  const { error } = await supabase
    .from('point_likes')
    .insert([{ point_id: pointId, user_id }]);

  if (error) {
    if (error.code === '23505') { // Unique violation
      return res.status(400).json({ error: 'Already liked' });
    }
    return res.status(500).json({ error: error.message });
  }

  // Optional: Increment cached count on points table
  // await supabase.rpc('increment_point_likes', { row_id: pointId });

  res.json({ success: true });
});

// POST /points/:pointId/unlike - Unlike a point
router.post('/:pointId/unlike', async (req, res) => {
  const { pointId } = req.params;
  const { user_id } = req.body;

  if (!user_id) return res.status(400).json({ error: 'Missing user_id' });

  const { error } = await supabase
    .from('point_likes')
    .delete()
    .match({ point_id: pointId, user_id });

  if (error) {
    return res.status(500).json({ error: error.message });
  }

  res.json({ success: true });
});

// POST /points/:pointId/comments - Add a comment
router.post('/:pointId/comments', async (req, res) => {
  const { pointId } = req.params;
  const { user_id, content } = req.body;

  if (!user_id || !content) return res.status(400).json({ error: 'Missing user_id or content' });

  const { data, error } = await supabase
    .from('point_comments')
    .insert([{ point_id: pointId, user_id, content }])
    .select()
    .single();

  if (error) {
    return res.status(500).json({ error: error.message });
  }

  res.status(201).json(data);
});

// GET /points/:pointId/comments - Get comments
router.get('/:pointId/comments', async (req, res) => {
  const { pointId } = req.params;

  const { data, error } = await supabase
    .from('point_comments')
    .select(`
      *,
      comment_likes (count)
    `)
    .eq('point_id', pointId)
    .order('created_at', { ascending: true });

  if (error) {
    return res.status(500).json({ error: error.message });
  }

  const formattedData = data.map(comment => ({
    ...comment,
    likes_count: comment.comment_likes?.[0]?.count || 0, // Use dynamic count or cached column
  }));

  res.json(formattedData);
});

module.exports = router;
