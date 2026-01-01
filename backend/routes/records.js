/**
 * 模組 B：紀錄模式 API
 */
const express = require("express");
const router = express.Router();
const supabase = require("../config/supabase");
const { requireAuth, optionalAuth } = require("../middleware/auth");
const { asyncHandler } = require("../middleware/errorHandler");
const { Errors } = require("../utils/errorCodes");
const { makePointSQL, isValidCoordinate } = require("../utils/geo");
const { deleteObjects } = require("../utils/r2Helpers");

/**
 * API B-1: 建立紀錄標點
 * POST /api/v1/records
 */
router.post(
  "/",
  requireAuth,
  asyncHandler(async (req, res) => {
    const { description, images } = req.body;
    const userId = req.user.id;

    // 驗證
    if (!description || typeof description !== "string") {
      throw Errors.invalidArgument("description 為必填欄位");
    }

    if (!images || !Array.isArray(images) || images.length === 0) {
      throw Errors.invalidArgument("至少需要一張圖片");
    }

    if (images.length > 10) {
      throw Errors.resourceExhausted("紀錄模式最多 10 張圖片", { limit: 10 });
    }

    // 驗證所有圖片都有 GPS 資訊
    for (const img of images) {
      if (
        !img.location ||
        !isValidCoordinate(img.location.lat, img.location.lng)
      ) {
        throw Errors.invalidArgument(
          "紀錄模式所有圖片都必須包含有效的 GPS 座標"
        );
      }
    }

    // 驗證 upload_id 歸屬（安全性檢查）
    const uploadIds = images.map((img) => img.upload_id);
    const { data: pendingImages, error: checkError } = await supabase
      .from("image_media")
      .select("id")
      .in("id", uploadIds)
      .eq("user_id", userId)
      .eq("status", "PENDING");

    if (checkError) {
      throw Errors.internal("驗證圖片失敗");
    }

    if (!pendingImages || pendingImages.length !== uploadIds.length) {
      throw Errors.permissionDenied("部分圖片不屬於當前用戶或狀態不正確");
    }

    // 建立 Record 記錄
    const firstImage =
      images.find((img) => img.display_order === 0) || images[0];

    const { data: record, error: recordError } = await supabase
      .from("records")
      .insert({
        user_id: userId,
        description,
        main_image_url: firstImage.thumbnail_public_url || null,
        media_count: images.length,
      })
      .select()
      .single();

    if (recordError) {
      console.error("Failed to create record:", recordError);
      throw Errors.internal("建立紀錄失敗");
    }

    // 更新所有圖片的狀態和關聯
    for (const img of images) {
      const { lat, lng } = img.location;

      console.log("Updating image with location:", {
        upload_id: img.upload_id,
        lat,
        lng,
        address: img.address,
      });

      // 使用 RPC 呼叫來更新 PostGIS 欄位
      const { error: updateError } = await supabase.rpc(
        "update_image_with_location",
        {
          p_image_id: img.upload_id,
          p_record_id: record.id,
          p_lng: lng,
          p_lat: lat,
          p_captured_at: img.captured_at || null,
          p_display_order: img.display_order || 0,
          p_address: img.address || null,
        }
      );

      // 如果 RPC 失敗，記錄詳細錯誤並使用基本更新
      if (updateError) {
        console.error("RPC update_image_with_location failed:", {
          error: updateError.message,
          code: updateError.code,
          details: updateError.details,
          hint: updateError.hint,
        });
        console.warn("Falling back to basic update WITHOUT location - RPC needs to be deployed in Supabase SQL Editor");
        
        // 基本更新（不含 PostGIS location）
        await supabase
          .from("image_media")
          .update({
            record_id: record.id,
            status: "COMPLETED",
            captured_at: img.captured_at || null,
            display_order: img.display_order || 0,
            address: img.address || null,
          })
          .eq("id", img.upload_id);
      } else {
        console.log("Successfully updated image with location via RPC");
      }
    }

    res.status(201).json({
      id: record.id,
      user_id: record.user_id,
      description: record.description,
      main_image_url: record.main_image_url,
      media_count: record.media_count,
      like_count: record.like_count || 0,
      view_count: record.view_count || 0,
      created_at: record.created_at,
      updated_at: record.updated_at,
    });
  })
);

/**
 * API B-2: 取得地圖範圍內的紀錄圖片
 * GET /api/v1/records/map
 */
router.get(
  "/map",
  asyncHandler(async (req, res) => {
    const { min_lat, max_lat, min_lng, max_lng } = req.query;

    // 驗證參數
    if (!min_lat || !max_lat || !min_lng || !max_lng) {
      throw Errors.invalidArgument(
        "需要提供 min_lat, max_lat, min_lng, max_lng"
      );
    }

    // 使用 RPC 進行空間查詢
    const { data, error } = await supabase.rpc("get_record_images_in_bounds", {
      p_min_lng: parseFloat(min_lng),
      p_min_lat: parseFloat(min_lat),
      p_max_lng: parseFloat(max_lng),
      p_max_lat: parseFloat(max_lat),
    });

    if (error) {
      // 如果 RPC 不存在，使用基本查詢
      console.warn("RPC not available, using basic query");
      const { data: images, error: queryError } = await supabase
        .from("image_media")
        .select("id, record_id, thumbnail_public_url, display_order, uploaded_at")
        .eq("status", "COMPLETED")
        .not("record_id", "is", null);

      if (queryError) throw Errors.internal("查詢失敗");

      res.json({ 
        images: (images || []).map(img => ({
          ...img,
          created_at: img.uploaded_at
        })) 
      });
      return;
    }

    res.json({ images: data || [] });
  })
);

/**
 * API B-3: 取得紀錄標點詳情
 * GET /api/v1/records/:id
 */
router.get(
  "/:id",
  optionalAuth,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const currentUserId = req.user?.id;

    // 取得 Record
    const { data: record, error: recordError } = await supabase
      .from("records")
      .select(
        `
      *,
      users:user_id (id, display_name, avatar_url)
    `
      )
      .eq("id", id)
      .single();

    if (recordError || !record) {
      throw Errors.notFound("找不到此紀錄");
    }

    // 取得關聯圖片（含位置座標）
    // 嘗試使用 RPC 取得座標，如果失敗則使用普通查詢
    let images = [];
    const { data: imagesWithLocation, error: rpcError } = await supabase.rpc(
      "get_record_images_with_location",
      {
        p_record_id: id,
      }
    );

    if (rpcError) {
      // RPC 不存在，使用普通查詢（不含 location）
      console.warn(
        "RPC get_record_images_with_location not available, using basic query"
      );
      const { data: basicImages } = await supabase
        .from("image_media")
        .select(
          "id, original_public_url, thumbnail_public_url, captured_at, display_order"
        )
        .eq("record_id", id)
        .eq("status", "COMPLETED")
        .order("display_order");
      images = basicImages || [];
    } else {
      // 轉換 RPC 回傳格式
      images = (imagesWithLocation || []).map((img) => ({
        id: img.id,
        original_public_url: img.original_public_url,
        thumbnail_public_url: img.thumbnail_public_url,
        captured_at: img.captured_at,
        display_order: img.display_order,
        address: img.address || null,
        location:
          img.lng !== null && img.lat !== null
            ? {
                lng: img.lng,
                lat: img.lat,
              }
            : null,
      }));
    }

    // 檢查當前用戶是否已點讚
    let userHasLiked = false;
    if (currentUserId) {
      const { data: like } = await supabase
        .from("likes")
        .select("id")
        .eq("record_id", id)
        .eq("user_id", currentUserId)
        .single();
      userHasLiked = !!like;
    }

    // 增加觀看次數
    const { error: viewError } = await supabase.rpc("increment_view_count", {
      p_table: "records",
      p_id: id,
    });
    // 忽略錯誤，觀看次數不是關鍵功能
    if (viewError) {
      console.warn("Failed to increment view count:", viewError);
    }

    res.json({
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
      images: images || [],
      user_has_liked: userHasLiked,
    });
  })
);

/**
 * API B-4: 編輯紀錄標點 (Snapshot Sync)
 * PATCH /api/v1/records/:id
 */
router.patch(
  "/:id",
  requireAuth,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { description, sorted_images } = req.body;
    const userId = req.user.id;

    // 驗證擁有權
    const { data: record, error: recordError } = await supabase
      .from("records")
      .select("user_id")
      .eq("id", id)
      .single();

    if (recordError || !record) {
      throw Errors.notFound("找不到此紀錄");
    }

    if (record.user_id !== userId) {
      throw Errors.permissionDenied("您無權編輯此紀錄");
    }

    // 更新描述（如果提供）
    if (description !== undefined) {
      await supabase
        .from("records")
        .update({ description, updated_at: new Date().toISOString() })
        .eq("id", id);
    }

    // 處理圖片同步（Snapshot Sync）
    if (sorted_images && Array.isArray(sorted_images)) {
      // 1. 取得現有圖片
      const { data: currentImages } = await supabase
        .from("image_media")
        .select("id, original_public_url, thumbnail_public_url")
        .eq("record_id", id);

      const currentImageIds = new Set(
        (currentImages || []).map((img) => img.id)
      );
      const newImageIds = new Set();
      const existingImageIds = new Set();

      // 2. 分類圖片
      for (const img of sorted_images) {
        if (img.type === "EXISTING") {
          existingImageIds.add(img.image_id);
        } else if (img.type === "NEW") {
          newImageIds.add(img.upload_id);
        }
      }

      // 3. 找出要刪除的圖片
      const toDelete = [...currentImageIds].filter(
        (id) => !existingImageIds.has(id)
      );

      if (toDelete.length > 0) {
        // 取得要刪除的圖片 URLs 用於清理 R2
        const imagesToDelete = currentImages.filter((img) =>
          toDelete.includes(img.id)
        );
        const keysToDelete = imagesToDelete.flatMap((img) =>
          [img.original_public_url, img.thumbnail_public_url].filter(Boolean)
        );

        // 刪除資料庫記錄
        await supabase.from("image_media").delete().in("id", toDelete);

        // 異步刪除 R2 檔案
        deleteObjects(keysToDelete).catch((err) => {
          console.error("Failed to delete R2 objects:", err);
        });
      }

      // 4. 處理新增圖片
      for (const img of sorted_images) {
        if (img.type === "NEW") {
          await supabase
            .from("image_media")
            .update({
              record_id: id,
              status: "COMPLETED",
            })
            .eq("id", img.upload_id)
            .eq("user_id", userId)
            .eq("status", "PENDING");
        }
      }

      // 5. 更新所有圖片順序
      for (let i = 0; i < sorted_images.length; i++) {
        const img = sorted_images[i];
        const imageId = img.type === "EXISTING" ? img.image_id : img.upload_id;

        await supabase
          .from("image_media")
          .update({ display_order: i })
          .eq("id", imageId);
      }

      // 6. 更新首圖和圖片數量
      const firstImage = sorted_images[0];
      let mainImageUrl = null;

      if (firstImage) {
        const imageId =
          firstImage.type === "EXISTING"
            ? firstImage.image_id
            : firstImage.upload_id;
        const { data: firstImg } = await supabase
          .from("image_media")
          .select("thumbnail_public_url")
          .eq("id", imageId)
          .single();
        mainImageUrl = firstImg?.thumbnail_public_url;
      }

      await supabase
        .from("records")
        .update({
          main_image_url: mainImageUrl,
          media_count: sorted_images.length,
          updated_at: new Date().toISOString(),
        })
        .eq("id", id);
    }

    res.json({ success: true });
  })
);

/**
 * API B-5: 刪除紀錄標點
 * DELETE /api/v1/records/:id
 */
router.delete(
  "/:id",
  requireAuth,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.user.id;

    // 驗證擁有權
    const { data: record, error: recordError } = await supabase
      .from("records")
      .select("user_id")
      .eq("id", id)
      .single();

    if (recordError || !record) {
      throw Errors.notFound("找不到此紀錄");
    }

    if (record.user_id !== userId) {
      throw Errors.permissionDenied("您無權刪除此紀錄");
    }

    // 取得關聯圖片用於清理 R2
    const { data: images } = await supabase
      .from("image_media")
      .select("original_public_url, thumbnail_public_url")
      .eq("record_id", id);

    const keysToDelete = (images || []).flatMap((img) =>
      [img.original_public_url, img.thumbnail_public_url].filter(Boolean)
    );

    // 刪除 Record（級聯刪除會處理 images, replies, likes）
    const { error: deleteError } = await supabase
      .from("records")
      .delete()
      .eq("id", id);

    if (deleteError) {
      throw Errors.internal("刪除失敗");
    }

    // 異步刪除 R2 檔案
    if (keysToDelete.length > 0) {
      deleteObjects(keysToDelete).catch((err) => {
        console.error("Failed to delete R2 objects:", err);
      });
    }

    res.json({ success: true });
  })
);

module.exports = router;
