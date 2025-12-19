const { execSync } = require('child_process');
const path = require('path');

const tests = [
  'upload.test.js',
  'asks.test.js',
  'records.test.js',
  'likes.test.js',
  'replies.test.js',
  'users.test.js'
];

console.log('🚀 Running all API tests...');

for (const test of tests) {
  console.log(`\n========================================`);
  console.log(`🏃 Running ${test}...`);
  try {
    execSync(`node ${path.join(__dirname, 'manual', test)}`, { stdio: 'inherit' });
  } catch (error) {
    console.error(`❌ ${test} failed`);
  }
}

console.log(`\n========================================`);
console.log('🏁 All tests finished!');
