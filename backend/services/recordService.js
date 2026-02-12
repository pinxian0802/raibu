/**
 * 紀錄模式 Service 層
 * 處理紀錄標點的業務邏輯
 */
const supabase = require('../config/supabase');
const { Errors } = require('../utils/errorCodes');
const { isValidCoordinate } = require('../utils/geo');
const { deleteObjects } = require('../utils/r2Helpers');
const { log } = require('../utils/logger');

class RecordService {
  /**
   * 建立紀錄標點
   * @param {string} userId - 使用者 ID
   * @param {string} description - 描述
   * @param {Array} images - 圖片陣列
   * @returns {Promise<Object>} 建立的紀錄
   */
  async createRecord(userId, description, images) {
    // 驗證
    this._validateCreateInput(description, images);

    // 驗證 upload_id 歸屬（安全性檢查）
    await this._verifyImageOwnership(userId, images);

    // 建立 Record 記錄
    const record = await this._insertRecord(userId, description, images);

    // 更新所有圖片的狀態和關聯
    await this._updateImagesForRecord(record.id, images);

    return {
      id: record.id,
      user_id: record.user_id,
      description: record.description,
      main_image_url: record.main_image_url,
      media_count: record.media_count,
      like_count: record.like_count || 0,
      view_count: record.view_count || 0,
      created_at: record.created_at,
      updated_at: record.updated_at,
    };
  }

  /**
   * 取得地圖範圍內的紀錄圖片
   * @param {Object} bounds - { minLat, maxLat, minLng, maxLng }
   * @returns {Promise<Array>} 圖片陣列
   */
  async getMapRecords(bounds) {
    const { minLat, maxLat, minLng, maxLng } = bounds;

    // 使用 RPC 進行空間查詢
    const { data, error } = await supabase.rpc('get_record_images_in_bounds', {
      p_min_lng: parseFloat(minLng),
      p_min_lat: parseFloat(minLat),
      p_max_lng: parseFloat(maxLng),
      p_max_lat: parseFloat(maxLat),
    });

    if (error) {
      // 如果 RPC 不存在，使用基本查詢
      console.warn('RPC not available, using basic query');
      const { data: images, error: queryError } = await supabase
        .from('image_media')
        .select('id, record_id, thumbnail_public_url, display_order, uploaded_at')
        .eq('status', 'COMPLETED')
        .not('record_id', 'is', null);

      if (queryError) throw Errors.internal('查詢失敗');

      return (images || []).map(img => ({
        image_id: img.id,
        record_id: img.record_id,
        thumbnail_public_url: img.thumbnail_public_url,
        display_order: img.display_order,
        created_at: img.uploaded_at
      }));
    }

    return data || [];
  }

  /**
   * 取得紀錄詳情
   * @param {string} recordId - 紀錄 ID
   * @param {string|null} currentUserId - 當前用戶 ID（可選）
   * @returns {Promise<Object>} 紀錄詳情
   */
  async getRecordDetail(recordId, currentUserId = null) {
    // 取得 Record
    const { data: record, error: recordError } = await supabase
      .from('records')
      .select(`
        *,
        users:user_id (id, display_name, avatar_url)
      `)
      .eq('id', recordId)
      .single();

    if (recordError || !record) {
      throw Errors.notFound('找不到此紀錄');
    }

    // 取得關聯圖片
    const images = await this._getRecordImages(recordId);

    // 檢查當前用戶是否已點讚
    const userHasLiked = await this._checkUserLiked(recordId, currentUserId, 'record');

    // 增加觀看次數
    await this._incrementViewCount('records', recordId);

    return {
      id: record.id,
      user_id: record.user_id,
      description: record.description,
      main_image_url: record.main_image_url,
      media_count: record.media_count || 0,
      like_count: record.like_count || 0,
      view_count: record.view_count || 0,
      created_at: record.created_at,
      updated_at: record.updated_at,
      author: record.users,
      images: images,
      user_has_liked: userHasLiked,
    };
  }

  /**
   * 編輯紀錄標點
   * @param {string} recordId - 紀錄 ID
   * @param {string} userId - 用戶 ID
   * @param {Object} updateData - { description, sortedImages }
   * @returns {Promise<Object>} 更新結果
   */
  async updateRecord(recordId, userId, updateData) {
    const { description, sortedImages } = updateData;

    // 驗證擁有權
    await this._verifyOwnership(recordId, userId);

    // 更新描述（如果提供）
    if (description !== undefined) {
      await supabase
        .from('records')
        .update({ description, updated_at: new Date().toISOString() })
        .eq('id', recordId);
    }

    // 處理圖片同步
    if (sortedImages && Array.isArray(sortedImages)) {
      await this._syncImages(recordId, userId, sortedImages);
    }

    return { success: true };
  }

  /**
   * 刪除紀錄標點
   * @param {string} recordId - 紀錄 ID
   * @param {string} userId - 用戶 ID
   * @returns {Promise<Object>} 刪除結果
   */
  async deleteRecord(recordId, userId) {
    // 驗證擁有權
    await this._verifyOwnership(recordId, userId);

    // 取得關聯圖片用於清理 R2
    const { data: images } = await supabase
      .from('image_media')
      .select('original_public_url, thumbnail_public_url')
      .eq('record_id', recordId);

    const keysToDelete = (images || []).flatMap(img =>
      [img.original_public_url, img.thumbnail_public_url].filter(Boolean)
    );

    // 刪除 Record
    const { error: deleteError } = await supabase
      .from('records')
      .delete()
      .eq('id', recordId);

    if (deleteError) {
      throw Errors.internal('刪除失敗');
    }

    // 異步刪除 R2 檔案
    if (keysToDelete.length > 0) {
      deleteObjects(keysToDelete).catch(err => {
        console.error('Failed to delete R2 objects:', err);
      });
    }

    return { success: true };
  }

  // ==================== Private Methods ====================

  /**
   * 驗證建立紀錄的輸入
   */
  _validateCreateInput(description, images) {
    if (!description || typeof description !== 'string') {
      throw Errors.invalidArgument('description 為必填欄位');
    }

    if (!images || !Array.isArray(images) || images.length === 0) {
      throw Errors.invalidArgument('至少需要一張圖片');
    }

    if (images.length > 10) {
      throw Errors.resourceExhausted('紀錄模式最多 10 張圖片', { limit: 10 });
    }

    // 驗證所有圖片都有 GPS 資訊
    for (const img of images) {
      if (!img.location || !isValidCoordinate(img.location.lat, img.location.lng)) {
        throw Errors.invalidArgument('紀錄模式所有圖片都必須包含有效的 GPS 座標');
      }
    }
  }

  /**
   * 驗證圖片歸屬權
   */
  async _verifyImageOwnership(userId, images) {
    const uploadIds = images.map(img => img.upload_id);
    const { data: pendingImages, error: checkError } = await supabase
      .from('image_media')
      .select('id')
      .in('id', uploadIds)
      .eq('user_id', userId)
      .eq('status', 'PENDING');

    if (checkError) {
      throw Errors.internal('驗證圖片失敗');
    }

    if (!pendingImages || pendingImages.length !== uploadIds.length) {
      throw Errors.permissionDenied('部分圖片不屬於當前用戶或狀態不正確');
    }
  }

  /**
   * 插入紀錄
   */
  async _insertRecord(userId, description, images) {
    const firstImage = images.find(img => img.display_order === 0) || images[0];

    const { data: record, error: recordError } = await supabase
      .from('records')
      .insert({
        user_id: userId,
        description,
        main_image_url: firstImage.thumbnail_public_url || null,
        media_count: images.length,
      })
      .select()
      .single();

    if (recordError) {
      console.error('Failed to create record:', recordError);
      throw Errors.internal('建立紀錄失敗');
    }

    return record;
  }

  /**
   * 更新圖片狀態和關聯
   */
  async _updateImagesForRecord(recordId, images) {
    for (const img of images) {
      const { lat, lng } = img.location;

      log.db.query('update', 'image_media', {
        upload_id: img.upload_id,
        lat,
        lng,
        address: img.address,
      });

      // 使用 RPC 呼叫來更新 PostGIS 欄位
      const { error: updateError } = await supabase.rpc('update_image_with_location', {
        p_image_id: img.upload_id,
        p_record_id: recordId,
        p_lng: lng,
        p_lat: lat,
        p_captured_at: img.captured_at || null,
        p_display_order: img.display_order || 0,
        p_address: img.address || null,
      });

      if (updateError) {
        log.db.error('update_image_with_location', 'image_media', updateError);
        log.warn('Falling back to basic update WITHOUT location');

        // 基本更新（不含 PostGIS location）
        await supabase
          .from('image_media')
          .update({
            record_id: recordId,
            status: 'COMPLETED',
            captured_at: img.captured_at || null,
            display_order: img.display_order || 0,
            address: img.address || null,
          })
          .eq('id', img.upload_id);
      } else {
        log.debug('Successfully updated image with location via RPC');
      }
    }
  }

  /**
   * 取得紀錄的圖片（含座標）
   */
  async _getRecordImages(recordId) {
    const { data: imagesWithLocation, error: rpcError } = await supabase.rpc(
      'get_record_images_with_location',
      { p_record_id: recordId }
    );

    if (rpcError) {
      log.warn('RPC get_record_images_with_location not available, using basic query');
      const { data: basicImages } = await supabase
        .from('image_media')
        .select('id, original_public_url, thumbnail_public_url, captured_at, display_order')
        .eq('record_id', recordId)
        .eq('status', 'COMPLETED')
        .order('display_order');
      return basicImages || [];
    }

    return (imagesWithLocation || []).map(img => ({
      id: img.id,
      original_public_url: img.original_public_url,
      thumbnail_public_url: img.thumbnail_public_url,
      captured_at: img.captured_at,
      display_order: img.display_order,
      address: img.address || null,
      location: (img.lng !== null && img.lat !== null)
        ? { lng: img.lng, lat: img.lat }
        : null,
    }));
  }

  /**
   * 檢查用戶是否已點讚
   */
  async _checkUserLiked(targetId, userId, type) {
    if (!userId) return false;

    const column = type === 'record' ? 'record_id' : 'ask_id';
    const { data: like } = await supabase
      .from('likes')
      .select('id')
      .eq(column, targetId)
      .eq('user_id', userId)
      .single();

    return !!like;
  }

  /**
   * 增加觀看次數
   */
  async _incrementViewCount(table, id) {
    const { error: viewError } = await supabase.rpc('increment_view_count', {
      p_table: table,
      p_id: id,
    });

    if (viewError) {
      console.warn('Failed to increment view count:', viewError);
    }
  }

  /**
   * 驗證擁有權
   */
  async _verifyOwnership(recordId, userId) {
    const { data: record, error: recordError } = await supabase
      .from('records')
      .select('user_id')
      .eq('id', recordId)
      .single();

    if (recordError || !record) {
      throw Errors.notFound('找不到此紀錄');
    }

    if (record.user_id !== userId) {
      throw Errors.permissionDenied('您無權操作此紀錄');
    }
  }

  /**
   * 同步圖片（Snapshot Sync）
   */
  async _syncImages(recordId, userId, sortedImages) {
    // 1. 取得現有圖片
    const { data: currentImages } = await supabase
      .from('image_media')
      .select('id, original_public_url, thumbnail_public_url')
      .eq('record_id', recordId);

    const currentImageIds = new Set((currentImages || []).map(img => img.id));
    const existingImageIds = new Set();

    // 2. 分類圖片
    for (const img of sortedImages) {
      if (img.type === 'EXISTING') {
        existingImageIds.add(img.image_id);
      }
    }

    // 3. 刪除移除的圖片
    const toDelete = [...currentImageIds].filter(id => !existingImageIds.has(id));

    if (toDelete.length > 0) {
      const imagesToDelete = currentImages.filter(img => toDelete.includes(img.id));
      const keysToDelete = imagesToDelete.flatMap(img =>
        [img.original_public_url, img.thumbnail_public_url].filter(Boolean)
      );

      await supabase.from('image_media').delete().in('id', toDelete);

      deleteObjects(keysToDelete).catch(err => {
        console.error('Failed to delete R2 objects:', err);
      });
    }

    // 4. 處理新增圖片
    for (const img of sortedImages) {
      if (img.type === 'NEW') {
        await supabase
          .from('image_media')
          .update({
            record_id: recordId,
            status: 'COMPLETED',
          })
          .eq('id', img.upload_id)
          .eq('user_id', userId)
          .eq('status', 'PENDING');
      }
    }

    // 5. 更新所有圖片順序
    for (let i = 0; i < sortedImages.length; i++) {
      const img = sortedImages[i];
      const imageId = img.type === 'EXISTING' ? img.image_id : img.upload_id;

      await supabase
        .from('image_media')
        .update({ display_order: i })
        .eq('id', imageId);
    }

    // 6. 更新首圖和圖片數量
    const firstImage = sortedImages[0];
    let mainImageUrl = null;

    if (firstImage) {
      const imageId = firstImage.type === 'EXISTING' ? firstImage.image_id : firstImage.upload_id;
      const { data: firstImg } = await supabase
        .from('image_media')
        .select('thumbnail_public_url')
        .eq('id', imageId)
        .single();
      mainImageUrl = firstImg?.thumbnail_public_url;
    }

    await supabase
      .from('records')
      .update({
        main_image_url: mainImageUrl,
        media_count: sortedImages.length,
        updated_at: new Date().toISOString(),
      })
      .eq('id', recordId);
  }
}

module.exports = new RecordService();
