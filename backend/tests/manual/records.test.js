const { request } = require('./helpers');

async function testRecords() {
  console.log('🧪 Testing Records API...');
  let testRecordId = null;

  try {
    // 1. Initial Request to get Upload IDs (Mocking the flow)
    console.log('\n--- 1. Setup: Get Upload IDs ---');
    const uploadReq = await request('/upload/request', {
      method: 'POST',
      body: JSON.stringify({
        image_requests: [{ client_key: 'rec_img', fileType: 'image/jpeg' }]
      }),
    });

    const uploadId = uploadReq.data.upload_credentials.rec_img.upload_id;
    const thumbUrl = uploadReq.data.upload_credentials.rec_img.thumbnail_public_url;

    // 2. Create Record
    console.log('\n--- 2. Create Record ---');
    const createRes = await request('/records', {
      method: 'POST',
      body: JSON.stringify({
        description: '這是我今天在 101 拍的照片！',
        images: [
          {
            upload_id: uploadId,
            location: { lat: 25.0330, lng: 121.5654 },
            display_order: 0,
            thumbnail_public_url: thumbUrl
          }
        ]
      }),
    });

    if (createRes.status === 201) {
      testRecordId = createRes.data.id;
      console.log('✅ Created Record ID:', testRecordId);
    }

    // 3. Get Records on Map
    console.log('\n--- 3. Get Records on Map ---');
    const mapRes = await request('/records/map?min_lat=25.0&max_lat=26.0&min_lng=121.0&max_lng=122.0');
    if (mapRes.status === 200) {
      console.log('✅ Found records on map:', mapRes.data.images.length);
    }

    // 4. Get Record Detail
    if (testRecordId) {
      console.log('\n--- 4. Get Record Detail ---');
      const detailRes = await request(`/records/${testRecordId}`);
      if (detailRes.status === 200) {
        console.log('✅ Got record detail:', detailRes.data.description);
      }

      // 5. Update Record
      console.log('\n--- 5. Update Record ---');
      const updateRes = await request(`/records/${testRecordId}`, {
        method: 'PATCH',
        body: JSON.stringify({
          description: '這是我今天在 101 拍的照片！（已更新）'
        }),
      });
      if (updateRes.status === 200) {
        console.log('✅ Updated record successfully');
      }

      // 6. Like Record
      console.log('\n--- 6. Like Record ---');
      const likeRes = await request('/likes', {
        method: 'POST',
        body: JSON.stringify({ record_id: testRecordId })
      });
      if (likeRes.status === 200) {
        console.log('✅ Liked record successfully:', likeRes.data.action);
      }

      // 7. Post Reply
      console.log('\n--- 7. Post Reply ---');
      const replyRes = await request('/replies', {
        method: 'POST',
        body: JSON.stringify({
          record_id: testRecordId,
          content: '這張照片拍得真好！'
        })
      });
      let testReplyId = null;
      if (replyRes.status === 201) {
        testReplyId = replyRes.data.id;
        console.log('✅ Posted reply successfully:', testReplyId);
      }

      // 8. Like Reply
      if (testReplyId) {
        console.log('\n--- 8. Like Reply ---');
        const likeReplyRes = await request('/likes', {
          method: 'POST',
          body: JSON.stringify({ reply_id: testReplyId })
        });
        if (likeReplyRes.status === 200) {
          console.log('✅ Liked reply successfully:', likeReplyRes.data.action);
        }
      }

      // 9. Delete Record
      // console.log('\n--- 9. Delete Record ---');
      // const deleteRes = await request(`/records/${testRecordId}`, {
      //   method: 'DELETE',
      // });
      // if (deleteRes.status === 200) {
      //   console.log('✅ Deleted record successfully');
      // }
    }

    console.log('\n🎉 Records API Test Completed!');
  } catch (error) {
    console.error('💥 Test execution error:', error);
  }
}

testRecords();
