/**
 * Admin API 驗證腳本
 * 測試登入、取得列表、審核 API 流程
 */
const http = require('http');
const https = require('https');

const BASE = 'http://localhost:3000';
let adminCookie = '';

function request(method, path, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const opts = {
      hostname: 'localhost',
      port: 3000,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(adminCookie ? { Cookie: adminCookie } : {}),
        ...headers,
      },
    };

    const req = http.request(opts, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        // extract set-cookie for session
        const setCookie = res.headers['set-cookie'];
        if (setCookie) {
          adminCookie = setCookie.map(c => c.split(';')[0]).join('; ');
        }
        try { data = JSON.parse(data); } catch(e) {}
        resolve({ status: res.statusCode, data, headers: res.headers });
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function run() {
  const adminSecret = process.env.ADMIN_SECRET;
  if (!adminSecret) { console.error('ADMIN_SECRET not set'); process.exit(1); }

  console.log('\n--- Test 1: Login ---');
  const login = await request('POST', '/admin/api/login', { secret: adminSecret });
  console.log('Status:', login.status, '| Expected: 200');
  console.log('Body:', login.data);

  console.log('\n--- Test 2: Stats ---');
  const stats = await request('GET', '/admin/api/stats');
  console.log('Status:', stats.status, '| Expected: 200');
  console.log('Body:', stats.data);
  console.log('All status keys present:', ['PENDING','REVIEWED','RESOLVED','DISMISSED'].every(k => k in stats.data));

  console.log('\n--- Test 3: Get Reports (PENDING) ---');
  const reports = await request('GET', '/admin/api/reports?status=PENDING&limit=10');
  console.log('Status:', reports.status, '| Expected: 200');
  console.log('Data count:', reports.data?.data?.length, '| Page:', reports.data?.page);

  console.log('\n--- Test 4: Get Reports (ALL) ---');
  const allReports = await request('GET', '/admin/api/reports?status=ALL&limit=10');
  console.log('Status:', allReports.status, '| Expected: 200');
  console.log('Data count:', allReports.data?.data?.length);

  console.log('\n--- Test 5: Patch non-existent report (expect 404) ---');
  const patch404 = await request('PATCH', '/admin/api/reports/00000000-0000-0000-0000-000000000000', {
    status: 'RESOLVED', admin_notes: 'test', action: 'remove_content'
  });
  console.log('Status:', patch404.status, '| Expected: 404');
  console.log('Body:', patch404.data);

  console.log('\n--- Test 6: Patch with invalid status (expect 400) ---');
  const patch400 = await request('PATCH', '/admin/api/reports/00000000-0000-0000-0000-000000000000', {
    status: 'INVALID_STATUS'
  });
  console.log('Status:', patch400.status, '| Expected: 400');
  console.log('Body:', patch400.data);

  console.log('\n--- Test 7: Unauthenticated request (expect redirect) ---');
  const oldCookie = adminCookie;
  adminCookie = '';
  const unauth = await request('GET', '/admin/api/stats');
  adminCookie = oldCookie;
  console.log('Status:', unauth.status, '| Expected: 302');

  // Check if there's a real report to test actual patch
  if (allReports.data?.data?.length > 0) {
    const firstReport = allReports.data.data[0];
    console.log('\n--- Test 8: Patch real report (status REVIEWED, no action) ---');
    const patchReal = await request('PATCH', `/admin/api/reports/${firstReport.id}`, {
      status: 'REVIEWED', admin_notes: '自動測試備註'
    });
    console.log('Status:', patchReal.status, '| Expected: 200');
    console.log('Body:', patchReal.data);
  } else {
    console.log('\n--- Test 8: Skipped (no real reports in DB) ---');
  }

  console.log('\n✅ All tests complete');
}

run().catch(e => { console.error(e); process.exit(1); });
