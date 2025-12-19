const { request } = require('./helpers');

async function testUsers() {
  console.log('🧪 Testing Users API...');

  try {
    console.log('\n--- 1. Get My Profile ---');
    const profileRes = await request('/users/me');
    if (profileRes.status === 200) {
      console.log('✅ Got profile:', profileRes.data.display_name);
    }

    console.log('\n--- 2. Update Profile ---');
    console.log('ℹ️ PATCH /users/me is not implemented in current spec. Skipping.');
    /*
    const updateRes = await request('/users/me', {
      method: 'PATCH',
      body: JSON.stringify({
        display_name: 'Test User (Updated)',
        bio: 'I love Raibu!'
      })
    });
    if (updateRes.status === 200) {
      console.log('✅ Updated profile successfully');
    }
    */

    console.log('\n🎉 Users API Test Completed!');
  } catch (error) {
    console.error('💥 Test execution error:', error);
  }
}

testUsers();
