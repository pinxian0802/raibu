const { request } = require('./helpers');

async function testUpload() {
  console.log('🧪 Testing Upload API...');

  try {
    console.log('\n--- 1. Request Upload URLs ---');
    const uploadRes = await request('/upload/request', {
      method: 'POST',
      body: JSON.stringify({
        image_requests: [
          { client_key: 'test_img_1', fileType: 'image/jpeg', fileSize: 1024 * 100 },
          { client_key: 'test_img_2', fileType: 'image/png', fileSize: 1024 * 200 }
        ]
      }),
    });

    if (uploadRes.status === 200) {
      console.log('✅ Received upload credentials');
      console.log('Credentials for test_img_1:', uploadRes.data.upload_credentials.test_img_1.upload_id);
    } else {
      console.log('❌ Failed to request upload URLs');
    }

    console.log('\n🎉 Upload API Test Completed!');
  } catch (error) {
    console.error('💥 Test execution error:', error);
  }
}

testUpload();
