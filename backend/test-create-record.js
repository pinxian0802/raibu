/**
 * 測試 API B-1: 建立紀錄標點
 * 流程：登入 -> 請求上傳授權 -> 建立紀錄
 */
const fetch = require('node-fetch');
require('dotenv').config();

const BASE_URL = 'http://localhost:3000/api/v1';

// 請填寫您的測試帳號資訊 (需先在 Supabase Auth 建立)
const TEST_EMAIL = 'your-email@example.com';
const TEST_PASSWORD = 'your-password';

async function runTest() {
  console.log('🚀 開始測試建立紀錄標點流程...');

  try {
    // 1. 取得 Token
    // 在測試模式下，後端會直接使用 .env 中的 TEST_USER_ID，因此這裡不需要真實 Token
    const token = process.env.TEST_ACCESS_TOKEN || 'test-token'; 

    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    };

    // 2. 第一階段：請求上傳授權 (API A-1)
    console.log('\nStep 1: 請求上傳授權 (API A-1)...');
    const uploadReqRes = await fetch(`${BASE_URL}/upload/request`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        image_requests: [
          {
            client_key: 'test_img_001',
            fileType: 'image/jpeg',
            fileSize: 1024 * 100 // 100KB
          }
        ]
      })
    });

    const uploadReqData = await uploadReqRes.json();
    if (uploadReqData.error) {
      console.error('❌ 上傳授權失敗:', uploadReqData.error);
      return;
    }

    const credential = uploadReqData.upload_credentials.test_img_001;
    const uploadId = credential.upload_id;
    console.log('✅ 取得 Upload ID:', uploadId);

    // 3. 第二階段：建立紀錄標點 (API B-1)
    console.log('\nStep 2: 建立紀錄標點 (API B-1)...');
    const createRecordRes = await fetch(`${BASE_URL}/records`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        description: '這是一則透過測試腳本建立的紀錄',
        images: [
          {
            upload_id: uploadId,
            location: { lat: 25.0330, lng: 121.5654 }, // 紀錄模式必須有 GPS
            captured_at: new Date().toISOString(),
            display_order: 0,
            thumbnail_public_url: credential.thumbnail_public_url
          }
        ]
      })
    });

    const recordData = await createRecordRes.json();
    if (recordData.error) {
      console.error('❌ 建立紀錄失敗:', recordData.error);
      console.log('詳情:', JSON.stringify(recordData.error, null, 2));
    } else {
      console.log('🎉 紀錄建立成功！');
      console.log('紀錄 ID:', recordData.id);
      console.log('回應資料:', recordData);
    }

  } catch (err) {
    console.error('💥 測試過程發生錯誤:', err);
  }
}

runTest();
