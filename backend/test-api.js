const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://localhost:3000';
const TEST_USER_ID = '00000000-0000-0000-0000-000000000000'; // Dummy UUID

async function testApi() {
  console.log('🚀 Starting API Tests...');

  try {
    // 1. Create a Point
    console.log('\n1. Creating a Point...');
    const createRes = await fetch(`${BASE_URL}/points`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title: 'Test Point',
        description: 'This is a test point',
        lat: 25.0330,
        lng: 121.5654,
        user_id: TEST_USER_ID
      })
    });
    const point = await createRes.json();
    console.log('✅ Point Created:', point.id);

    if (!point.id) throw new Error('Failed to create point');

    // 2. Upload Image (Mocking a file)
    console.log('\n2. Uploading Image...');
    // Create a dummy file
    const dummyFilePath = path.join(__dirname, 'test-image.jpg');
    fs.writeFileSync(dummyFilePath, 'dummy image content');
    
    const formData = new FormData();
    const fileBlob = new Blob([fs.readFileSync(dummyFilePath)], { type: 'image/jpeg' });
    formData.append('image_file', fileBlob, 'test-image.jpg');
    formData.append('uploader_id', TEST_USER_ID);
    formData.append('latitude', '25.0330');
    formData.append('longitude', '121.5654');

    const uploadRes = await fetch(`${BASE_URL}/points/${point.id}/images`, {
      method: 'POST',
      body: formData
    });
    const image = await uploadRes.json();
    console.log('✅ Image Uploaded:', image);
    
    // Cleanup dummy file
    fs.unlinkSync(dummyFilePath);

    // 3. Like Point
    console.log('\n3. Liking Point...');
    const likeRes = await fetch(`${BASE_URL}/points/${point.id}/like`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user_id: TEST_USER_ID })
    });
    const likeResult = await likeRes.json();
    console.log('✅ Like Result:', likeResult);

    // 4. Comment on Point
    console.log('\n4. Commenting on Point...');
    const commentRes = await fetch(`${BASE_URL}/points/${point.id}/comments`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user_id: TEST_USER_ID, content: 'Nice place!' })
    });
    const comment = await commentRes.json();
    console.log('✅ Comment Added:', comment);

    // 5. Get Point Details
    console.log('\n5. Getting Point Details...');
    const detailRes = await fetch(`${BASE_URL}/points/${point.id}`);
    const detail = await detailRes.json();
    console.log('✅ Point Details:', detail);

    console.log('\n🎉 All Tests Completed!');

  } catch (error) {
    console.error('❌ Test Failed:', error);
  }
}

testApi();
