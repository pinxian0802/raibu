const { request } = require('./helpers');

async function testAsks() {
  console.log('🧪 Testing Asks API...');
  let testAskId = null;

  try {
    // 1. Create Ask
    console.log('\n--- 1. Create Ask ---');
    const createRes = await request('/asks', {
      method: 'POST',
      body: JSON.stringify({
        center: { lat: 25.0330, lng: 121.5654 },
        radius_meters: 500,
        question: '這裡有什麼好吃的？ (Test Ask)',
      }),
    });
    
    if (createRes.status === 201) {
      testAskId = createRes.data.id;
      console.log('✅ Created Ask ID:', testAskId);
    } else {
      console.log('❌ Failed to create ask');
    }

    // 2. Get Asks on Map
    console.log('\n--- 2. Get Asks on Map ---');
    const mapRes = await request('/asks/map?min_lat=25.0&max_lat=26.0&min_lng=121.0&max_lng=122.0');
    if (mapRes.status === 200) {
      console.log('✅ Found asks on map:', mapRes.data.asks.length);
    }

    // 3. Get Ask Detail
    if (testAskId) {
      console.log('\n--- 3. Get Ask Detail ---');
      const detailRes = await request(`/asks/${testAskId}`);
      if (detailRes.status === 200) {
        console.log('✅ Got ask detail:', detailRes.data.question);
      }

      // 4. Update Ask
      console.log('\n--- 4. Update Ask ---');
      const updateRes = await request(`/asks/${testAskId}`, {
        method: 'PATCH',
        body: JSON.stringify({
          question: '這裡有什麼好吃的？（已編輯）',
          status: 'RESOLVED'
        }),
      });
      if (updateRes.status === 200) {
        console.log('✅ Updated ask successfully');
      }

      // 5. Like Ask
      console.log('\n--- 5. Like Ask ---');
      const likeRes = await request('/likes', {
        method: 'POST',
        body: JSON.stringify({ ask_id: testAskId })
      });
      if (likeRes.status === 200) {
        console.log('✅ Liked ask successfully:', likeRes.data.action);
      }

      // 6. Post Reply
      console.log('\n--- 6. Post Reply ---');
      const replyRes = await request('/replies', {
        method: 'POST',
        body: JSON.stringify({
          ask_id: testAskId,
          content: '我知道這附近有一家很好吃的牛肉麵！'
        })
      });
      let testReplyId = null;
      if (replyRes.status === 201) {
        testReplyId = replyRes.data.id;
        console.log('✅ Posted reply successfully:', testReplyId);
      }

      // 7. Like Reply
      if (testReplyId) {
        console.log('\n--- 7. Like Reply ---');
        const likeReplyRes = await request('/likes', {
          method: 'POST',
          body: JSON.stringify({ reply_id: testReplyId })
        });
        if (likeReplyRes.status === 200) {
          console.log('✅ Liked reply successfully:', likeReplyRes.data.action);
        }
      }

      // 8. Delete Ask
      // console.log('\n--- 8. Delete Ask ---');
      // const deleteRes = await request(`/asks/${testAskId}`, {
      //   method: 'DELETE',
      // });
      // if (deleteRes.status === 200) {
      //   console.log('✅ Deleted ask successfully');
      // }
    }

    console.log('\n🎉 Asks API Test Completed!');
  } catch (error) {
    console.error('💥 Test execution error:', error);
  }
}

testAsks();
