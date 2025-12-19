const { request } = require('./helpers');

async function testReplies() {
  console.log('🧪 Testing Replies API...');

  try {
    // Similar to likes, testing the endpoint structure with dummy IDs
    console.log('\n--- 1. Get Replies for an Ask ---');
    const getRes = await request('/replies/ask/00000000-0000-0000-0000-000000000000');
    console.log('Status:', getRes.status);

    console.log('\n--- 2. Post a Reply (Expected 404 for dummy Ask) ---');
    const postRes = await request('/replies/ask/00000000-0000-0000-0000-000000000000', {
      method: 'POST',
      body: JSON.stringify({ content: 'Test reply' })
    });
    console.log('Status:', postRes.status);

    console.log('\n🎉 Replies API Test Completed!');
  } catch (error) {
    console.error('💥 Test execution error:', error);
  }
}

testReplies();
