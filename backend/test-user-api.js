/**
 * 測試新增的用戶 API 端點
 * 使用方式：node test-user-api.js
 */

const API_BASE_URL = 'http://localhost:3000/api/v1';

// 從環境變數或命令行參數獲取 token
const AUTH_TOKEN = process.env.TEST_AUTH_TOKEN || process.argv[2];

if (!AUTH_TOKEN) {
  console.error('❌ 請提供認證 token');
  console.error('使用方式：');
  console.error('  node test-user-api.js <YOUR_TOKEN>');
  console.error('  或');
  console.error('  TEST_AUTH_TOKEN=<YOUR_TOKEN> node test-user-api.js');
  process.exit(1);
}

async function request(path, options = {}) {
  const url = `${API_BASE_URL}${path}`;
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  if (AUTH_TOKEN) {
    headers['Authorization'] = `Bearer ${AUTH_TOKEN}`;
  }

  try {
    const response = await fetch(url, {
      ...options,
      headers,
    });

    const data = await response.json();
    
    return {
      status: response.status,
      ok: response.ok,
      data,
    };
  } catch (error) {
    return {
      status: 0,
      ok: false,
      error: error.message,
    };
  }
}

async function testUserAPI() {
  console.log('🧪 測試新增的用戶 API...\n');

  let testUserId = null;

  try {
    // 1. 先取得自己的資料，獲取 user_id
    console.log('--- 1. 取得自己的個人資料 (GET /users/me) ---');
    const meRes = await request('/users/me');
    if (meRes.ok) {
      console.log('✅ 成功取得個人資料');
      console.log('   ID:', meRes.data.id);
      console.log('   名稱:', meRes.data.display_name);
      testUserId = meRes.data.id;
    } else {
      console.log('❌ 失敗:', meRes.data);
      return;
    }

    // 2. 測試取得其他用戶資料（使用自己的 ID 進行測試）
    console.log('\n--- 2. 取得用戶資料 (GET /users/:userId) ---');
    const userRes = await request(`/users/${testUserId}`);
    if (userRes.ok) {
      console.log('✅ 成功取得用戶資料');
      console.log('   總紀錄數:', userRes.data.total_records);
      console.log('   總詢問數:', userRes.data.total_asks);
      console.log('   總觀看數:', userRes.data.total_views);
      console.log('   總愛心數:', userRes.data.total_likes);
    } else {
      console.log('❌ 失敗:', userRes.data);
    }

    // 3. 測試取得用戶的紀錄列表
    console.log('\n--- 3. 取得用戶紀錄列表 (GET /users/:userId/records) ---');
    const recordsRes = await request(`/users/${testUserId}/records`);
    if (recordsRes.ok) {
      console.log('✅ 成功取得紀錄列表');
      console.log('   紀錄數量:', recordsRes.data.records.length);
      if (recordsRes.data.records.length > 0) {
        console.log('   第一筆:', recordsRes.data.records[0].description.substring(0, 30) + '...');
      }
    } else {
      console.log('❌ 失敗:', recordsRes.data);
    }

    // 4. 測試取得用戶的詢問列表
    console.log('\n--- 4. 取得用戶詢問列表 (GET /users/:userId/asks) ---');
    const asksRes = await request(`/users/${testUserId}/asks`);
    if (asksRes.ok) {
      console.log('✅ 成功取得詢問列表');
      console.log('   詢問數量:', asksRes.data.asks.length);
      if (asksRes.data.asks.length > 0) {
        console.log('   第一筆:', asksRes.data.asks[0].question.substring(0, 30) + '...');
      }
    } else {
      console.log('❌ 失敗:', asksRes.data);
    }

    // 5. 測試不存在的用戶
    console.log('\n--- 5. 測試不存在的用戶 (GET /users/:userId) ---');
    const fakeUserId = '00000000-0000-0000-0000-000000000000';
    const fakeUserRes = await request(`/users/${fakeUserId}`);
    if (!fakeUserRes.ok && fakeUserRes.status === 404) {
      console.log('✅ 正確回傳 404 錯誤');
    } else {
      console.log('❌ 應該回傳 404，但得到:', fakeUserRes.status);
    }

    console.log('\n🎉 用戶 API 測試完成！');

  } catch (error) {
    console.error('💥 測試執行錯誤:', error);
  }
}

// 執行測試
testUserAPI();
