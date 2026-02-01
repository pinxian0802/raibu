/**
 * 詢問模式 Service 層
 * 處理詢問標點的業務邏輯
 */
const supabase = require('../config/supabase');
const { Errors } = require('../utils/errorCodes');
const { isValidCoordinate } = require('../utils/geo');
const { deleteObjects } = require('../utils/r2Helpers');
const { log } = require('../utils/logger');

class AskService {
  /**
   * 建立詢問標點
   * @param {string} userId - 使用者 ID
   * @param {Object} data - { center, radiusMeters, question, images }
   * @returns {Promise<Object>} 建立的詢問
   */
  async createAsk(userId, data) {
    const { center, radiusMeters, question, images } = data;

    // 驗證
    this._validateCreateInput(center, question, images);

    // 驗證圖片歸屬
    if (images && images.length > 0) {
      await this._verifyImageOwnership(userId, images);
    }

    // 建立 Ask
    const askId = await this._insertAsk(userId, center, radiusMeters, question);

    // 關聯圖片
    let mainImageUrl = null;
    if (images && images.length > 0) {
      mainImageUrl = await this._linkImages(askId, images);
    }

    // 取得完整的 Ask 資料回傳
    const { data: createdAsk, error: fetchError } = await supabase
      .from('asks')
      .select('*')
      .eq('id', askId)
      .single();

    if (fetchError || !createdAsk) {
      throw Errors.internal('取得建立的詢問失敗');
    }

    return {
      id: createdAsk.id,
      user_id: createdAsk.user_id,
      question: createdAsk.question,
      center,
      radius_meters: createdAsk.radius_meters,
      main_image_url: mainImageUrl,
      status: createdAsk.status,
      like_count: createdAsk.like_count || 0,
      view_count: createdAsk.view_count || 0,
      created_at: createdAsk.created_at,
      updated_at: createdAsk.updated_at,
    };
  }

  /**
   * 取得地圖範圍內的詢問標點
   * @param {Object} bounds - { minLat, maxLat, minLng, maxLng }
   * @returns {Promise<Array>} 詢問陣列
   */
  async getMapAsks(bounds) {
    const { minLat, maxLat, minLng, maxLng } = bounds;

    // 使用 RPC 進行空間查詢 + 48 小時過濾
    const { data, error } = await supabase.rpc('get_asks_in_bounds', {
      p_min_lng: parseFloat(minLng),
      p_min_lat: parseFloat(minLat),
      p_max_lng: parseFloat(maxLng),
      p_max_lat: parseFloat(maxLat),
    });

    if (error) {
      console.warn('RPC not available, using basic query');
      const cutoffTime = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();

      const { data: asks, error: queryError } = await supabase
        .from('asks')
        .select('id, question, radius_meters, status, created_at')
        .gte('created_at', cutoffTime)
        .order('created_at', { ascending: false });

      if (queryError) throw Errors.internal('查詢失敗');
      return [];
    }

    return (data || []).map(ask => ({
      id: ask.id,
      center: {
        lat: ask.lat,
        lng: ask.lng,
      },
      radius_meters: ask.radius_meters,
      question: ask.question,
      status: ask.status,
      created_at: ask.created_at,
    }));
  }

  /**
   * 取得詢問詳情
   * @param {string} askId - 詢問 ID
   * @param {string|null} currentUserId - 當前用戶 ID
   * @returns {Promise<Object>} 詢問詳情
   */
  async getAskDetail(askId, currentUserId = null) {
    // 使用 RPC 取得包含座標的詢問資料
    const { data: askWithCoords, error: rpcError } = await supabase.rpc('get_ask_detail_with_coords', {
      p_ask_id: askId,
    });

    let ask;
    let center = null;

    if (rpcError || !askWithCoords || askWithCoords.length === 0) {
      console.warn('RPC not available, using basic query');
      const { data: basicAsk, error: basicError } = await supabase
        .from('asks')
        .select(`
          *,
          users:user_id (id, display_name, avatar_url)
        `)
        .eq('id', askId)
        .single();

      if (basicError || !basicAsk) {
        throw Errors.notFound('找不到此詢問');
      }

      ask = basicAsk;
      center = { lat: 0, lng: 0 };
    } else {
      const askData = askWithCoords[0];
      center = {
        lat: askData.lat,
        lng: askData.lng,
      };

      const { data: userData } = await supabase
        .from('users')
        .select('id, display_name, avatar_url')
        .eq('id', askData.user_id)
        .single();

      ask = {
        ...askData,
        users: userData,
      };
    }

    // 取得關聯圖片
    const images = await this._getAskImages(askId);

    // 檢查是否已點讚
    const userHasLiked = await this._checkUserLiked(askId, currentUserId);

    return {
      id: ask.id,
      user_id: ask.user_id,
      center: center,
      radius_meters: ask.radius_meters,
      question: ask.question,
      main_image_url: ask.main_image_url,
      status: ask.status,
      like_count: ask.like_count || 0,
      view_count: ask.view_count || 0,
      created_at: ask.created_at,
      updated_at: ask.updated_at,
      author: ask.users,
      images: images,
      user_has_liked: userHasLiked,
    };
  }

  /**
   * 編輯詢問標點
   * @param {string} askId - 詢問 ID
   * @param {string} userId - 用戶 ID
   * @param {Object} updateData - { question, status, sortedImages }
   * @returns {Promise<Object>} 更新結果
   */
  async updateAsk(askId, userId, updateData) {
    const { question, status, sortedImages } = updateData;

    // 驗證擁有權
    await this._verifyOwnership(askId, userId);

    // 更新基本欄位
    const updates = { updated_at: new Date().toISOString() };
    if (question !== undefined) updates.question = question;
    if (status !== undefined && ['ACTIVE', 'RESOLVED'].includes(status)) {
      updates.status = status;
    }

    await supabase.from('asks').update(updates).eq('id', askId);

    // 處理圖片同步
    if (sortedImages && Array.isArray(sortedImages)) {
      await this._syncImages(askId, userId, sortedImages);
    }

    return { success: true };
  }

  /**
   * 刪除詢問標點
   * @param {string} askId - 詢問 ID
   * @param {string} userId - 用戶 ID
   * @returns {Promise<Object>} 刪除結果
   */
  async deleteAsk(askId, userId) {
    // 驗證擁有權
    await this._verifyOwnership(askId, userId);

    // 取得圖片 URLs 用於 R2 清理
    const { data: images } = await supabase
      .from('image_media')
      .select('original_public_url, thumbnail_public_url')
      .eq('ask_id', askId);

    const keysToDelete = (images || []).flatMap(img =>
      [img.original_public_url, img.thumbnail_public_url].filter(Boolean)
    );

    // 刪除
    await supabase.from('asks').delete().eq('id', askId);

    // 異步清理 R2
    if (keysToDelete.length > 0) {
      deleteObjects(keysToDelete).catch(console.error);
    }

    return { success: true };
  }

  // ==================== Private Methods ====================

  /**
   * 驗證建立詢問的輸入
   */
  _validateCreateInput(center, question, images) {
    if (!center || !isValidCoordinate(center.lat, center.lng)) {
      throw Errors.invalidArgument('需要提供有效的中心座標');
    }

    if (!question || typeof question !== 'string') {
      throw Errors.invalidArgument('question 為必填欄位');
    }

    if (images && images.length > 5) {
      throw Errors.resourceExhausted('詢問模式最多 5 張圖片', { limit: 5 });
    }
  }

  /**
   * 驗證圖片歸屬權
   */
  async _verifyImageOwnership(userId, images) {
    const uploadIds = images.map(img => img.upload_id);
    const { data: pendingImages } = await supabase
      .from('image_media')
      .select('id')
      .in('id', uploadIds)
      .eq('user_id', userId)
      .eq('status', 'PENDING');

    if (!pendingImages || pendingImages.length !== uploadIds.length) {
      throw Errors.permissionDenied('部分圖片不屬於當前用戶');
    }
  }

  /**
   * 插入詢問
   */
  async _insertAsk(userId, center, radiusMeters, question) {
    const { data: ask, error: askError } = await supabase.rpc('create_ask', {
      p_user_id: userId,
      p_lng: center.lng,
      p_lat: center.lat,
      p_radius_meters: radiusMeters || 500,
      p_question: question,
    });

    if (askError) {
      console.warn('RPC not available, using raw SQL');
      const { data, error } = await supabase
        .from('asks')
        .insert({
          user_id: userId,
          radius_meters: radiusMeters || 500,
          question,
        })
        .select('id')
        .single();

      if (error) throw Errors.internal('建立詢問失敗');
      return data.id;
    }

    return ask;
  }

  /**
   * 關聯圖片到詢問
   */
  async _linkImages(askId, images) {
    let mainImageUrl = null;

    for (const img of images) {
      await supabase
        .from('image_media')
        .update({
          ask_id: askId,
          status: 'COMPLETED',
          display_order: img.display_order || 0,
        })
        .eq('id', img.upload_id);
    }

    // 取得首圖 URL
    const firstImage = images.find(img => img.display_order === 0) || images[0];
    const { data: imgData } = await supabase
      .from('image_media')
      .select('thumbnail_public_url')
      .eq('id', firstImage.upload_id)
      .single();
    mainImageUrl = imgData?.thumbnail_public_url;

    // 更新 main_image_url
    await supabase
      .from('asks')
      .update({ main_image_url: mainImageUrl })
      .eq('id', askId);

    return mainImageUrl;
  }

  /**
   * 取得詢問的圖片
   */
  async _getAskImages(askId) {
    const { data: imagesWithLocation, error: imgRpcError } = await supabase.rpc('get_ask_images_with_location', {
      p_ask_id: askId
    });

    if (imgRpcError) {
      console.warn('RPC get_ask_images_with_location not available, using basic query');
      const { data: basicImages } = await supabase
        .from('image_media')
        .select('id, original_public_url, thumbnail_public_url, display_order')
        .eq('ask_id', askId)
        .eq('status', 'COMPLETED')
        .order('display_order');
      return basicImages || [];
    }

    return (imagesWithLocation || []).map(img => ({
      id: img.id,
      original_public_url: img.original_public_url,
      thumbnail_public_url: img.thumbnail_public_url,
      display_order: img.display_order,
      location: (img.lng !== null && img.lat !== null) ? {
        lng: img.lng,
        lat: img.lat
      } : null
    }));
  }

  /**
   * 檢查用戶是否已點讚
   */
  async _checkUserLiked(askId, userId) {
    if (!userId) return false;

    const { data: like } = await supabase
      .from('likes')
      .select('id')
      .eq('ask_id', askId)
      .eq('user_id', userId)
      .single();

    return !!like;
  }

  /**
   * 驗證擁有權
   */
  async _verifyOwnership(askId, userId) {
    const { data: ask } = await supabase
      .from('asks')
      .select('user_id')
      .eq('id', askId)
      .single();

    if (!ask) throw Errors.notFound('找不到此詢問');
    if (ask.user_id !== userId) throw Errors.permissionDenied('您無權操作此詢問');
  }

  /**
   * 同步圖片
   */
  async _syncImages(askId, userId, sortedImages) {
    const { data: currentImages } = await supabase
      .from('image_media')
      .select('id')
      .eq('ask_id', askId);

    const currentIds = new Set((currentImages || []).map(img => img.id));
    const newIds = sortedImages
      .filter(img => img.type === 'EXISTING')
      .map(img => img.image_id);

    // 刪除不在列表中的圖片
    const toDelete = [...currentIds].filter(cid => !newIds.includes(cid));
    if (toDelete.length > 0) {
      await supabase.from('image_media').delete().in('id', toDelete);
    }

    // 處理新增和排序
    for (let i = 0; i < sortedImages.length; i++) {
      const img = sortedImages[i];

      if (img.type === 'NEW') {
        await supabase
          .from('image_media')
          .update({ ask_id: askId, status: 'COMPLETED', display_order: i })
          .eq('id', img.upload_id)
          .eq('user_id', userId);
      } else {
        await supabase
          .from('image_media')
          .update({ display_order: i })
          .eq('id', img.image_id);
      }
    }
  }
}

module.exports = new AskService();
