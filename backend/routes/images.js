const express = require('express');
const router = express.Router();
const multer = require('multer');
const sharp = require('sharp');
const { PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const supabase = require('../config/supabase');
const r2 = require('../config/r2');

const upload = multer({ storage: multer.memoryStorage() });

// Helper to generate signed URL
async function generateSignedUrl(key) {
  const command = new GetObjectCommand({
    Bucket: process.env.R2_BUCKET_NAME,
    Key: key,
  });
  // URL expires in 1 hour
  return await getSignedUrl(r2, command, { expiresIn: 3600 });
}

// GET /points/:pointId/images - Get images for a point
router.get('/:pointId/images', async (req, res) => {
  const { pointId } = req.params;

  const { data: images, error } = await supabase
    .from('images')
    .select('*')
    .eq('point_id', pointId);

  if (error) {
    return res.status(500).json({ error: error.message });
  }

  // Generate signed URLs for each image
  const imagesWithUrls = await Promise.all(images.map(async (img) => {
    const signedImageUrl = await generateSignedUrl(img.image_url); // image_url stores the key
    const signedThumbnailUrl = img.thumbnail_url ? await generateSignedUrl(img.thumbnail_url) : null;
    return {
      ...img,
      signed_image_url: signedImageUrl,
      signed_thumbnail_url: signedThumbnailUrl,
    };
  }));

  res.json(imagesWithUrls);
});

// POST /points/:pointId/images - Upload image
router.post('/:pointId/images', upload.single('image_file'), async (req, res) => {
  const { pointId } = req.params;
  const { 
    uploader_id, 
    taken_at, 
    latitude, 
    longitude, 
    country, 
    administrative_area, 
    locality, 
    sub_locality, 
    thoroughfare, 
    sub_thoroughfare 
  } = req.body;
  const file = req.file;

  if (!file || !uploader_id) {
    return res.status(400).json({ error: 'Missing file or uploader_id' });
  }

  try {
    const timestamp = Date.now();
    const originalKey = `points/image/${pointId}/${timestamp}_original.jpg`;
    const thumbnailKey = `points/thumbnail/${pointId}/${timestamp}_thumb.jpg`;

    // 1. Process and Upload Thumbnail
    const thumbnailBuffer = await sharp(file.buffer)
      .resize(300, 300, { fit: 'cover' })
      .jpeg({ quality: 80 })
      .toBuffer();

    await r2.send(new PutObjectCommand({
      Bucket: process.env.R2_BUCKET_NAME,
      Key: thumbnailKey,
      Body: thumbnailBuffer,
      ContentType: 'image/jpeg',
    }));

    // 2. Process and Upload Original (Compressed)
    const originalBuffer = await sharp(file.buffer)
      .jpeg({ quality: 90 }) // Compress original slightly
      .toBuffer();

    await r2.send(new PutObjectCommand({
      Bucket: process.env.R2_BUCKET_NAME,
      Key: originalKey,
      Body: originalBuffer,
      ContentType: 'image/jpeg',
    }));

    // 3. Save Metadata to Supabase
    const { data, error } = await supabase
      .from('images')
      .insert([{
        point_id: pointId,
        uploader_id,
        image_url: originalKey,     // Store the Key
        thumbnail_url: thumbnailKey, // Store the Key
        taken_at: taken_at || new Date().toISOString(),
        latitude: latitude ? parseFloat(latitude) : null,
        longitude: longitude ? parseFloat(longitude) : null,
        country,
        administrative_area,
        locality,
        sub_locality,
        thoroughfare,
        sub_thoroughfare
      }])
      .select()
      .single();

    if (error) {
      throw error;
    }

    res.status(201).json(data);

  } catch (err) {
    console.error('Upload error:', err);
    res.status(500).json({ error: 'Failed to upload image' });
  }
});

module.exports = router;
