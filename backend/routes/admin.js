/**
 * Admin Routes
 * 提供管理後台的 API 端點與 HTML 頁面
 */
const express = require('express');
const router = express.Router();
const supabaseAdmin = require('../config/supabaseAdmin');
const { requireAdminSession, requireAdminToken } = require('../middleware/adminAuth');

const ADMIN_SECRET = () => process.env.ADMIN_SECRET;

// ============================================================
// 登入頁面
// ============================================================
router.get('/login', (req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Raibu 管理後台 — 登入</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'PingFang TC', sans-serif;
           background: #f5f5f7; display: flex; align-items: center; justify-content: center;
           min-height: 100vh; }
    .card { background: white; border-radius: 16px; padding: 40px; width: 360px;
            box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
    h1 { font-size: 22px; font-weight: 700; margin-bottom: 8px; color: #1d1d1f; }
    p  { font-size: 14px; color: #86868b; margin-bottom: 28px; }
    input { width: 100%; padding: 12px 16px; border: 1.5px solid #d1d1d6;
            border-radius: 10px; font-size: 15px; outline: none; transition: border .2s; }
    input:focus { border-color: #0071e3; }
    button { width: 100%; padding: 12px; background: #0071e3; color: white;
             border: none; border-radius: 10px; font-size: 15px; font-weight: 600;
             cursor: pointer; margin-top: 16px; transition: background .2s; }
    button:hover { background: #0077ed; }
    .error { color: #ff3b30; font-size: 13px; margin-top: 10px; display: none; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🌈 Raibu 管理後台</h1>
    <p>請輸入管理員密碼</p>
    <input type="password" id="pw" placeholder="Admin Secret" autocomplete="current-password">
    <button onclick="login()">登入</button>
    <div class="error" id="err">密碼錯誤，請再試一次</div>
  </div>
  <script>
    document.getElementById('pw').addEventListener('keydown', e => {
      if (e.key === 'Enter') login();
    });
    async function login() {
      const pw = document.getElementById('pw').value;
      const res = await fetch('/admin/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ secret: pw }),
      });
      if (res.ok) {
        window.location.href = '/admin';
      } else {
        document.getElementById('err').style.display = 'block';
      }
    }
  </script>
</body>
</html>`);
});

// ============================================================
// 登入 API（設定 cookie）
// ============================================================
router.post('/api/login', (req, res) => {
  const { secret } = req.body;
  if (!ADMIN_SECRET() || secret !== ADMIN_SECRET()) {
    return res.status(401).json({ error: '密碼錯誤' });
  }
  // 設定 HttpOnly cookie，7 天有效
  res.setHeader(
    'Set-Cookie',
    `admin_token=${ADMIN_SECRET()}; HttpOnly; Path=/admin; Max-Age=${7 * 24 * 3600}; SameSite=Strict`
  );
  res.json({ ok: true });
});

// ============================================================
// 登出
// ============================================================
router.get('/logout', (req, res) => {
  res.setHeader('Set-Cookie', 'admin_token=; HttpOnly; Path=/admin; Max-Age=0');
  res.redirect('/admin/login');
});

// ============================================================
// 主頁面（需登入）
// ============================================================
router.get('/', requireAdminSession, (req, res) => {
  res.send(getAdminHTML());
});

// ============================================================
// API: 取得檢舉列表
// ============================================================
router.get('/api/reports', requireAdminSession, async (req, res) => {
  const { status = 'PENDING', page = 1, limit = 20 } = req.query;
  const offset = (parseInt(page) - 1) * parseInt(limit);

  const validStatuses = ['PENDING', 'REVIEWED', 'RESOLVED', 'DISMISSED', 'ALL'];
  const filterStatus = validStatuses.includes(status) ? status : 'PENDING';

  let query = supabaseAdmin
    .from('reports')
    .select(`
      id,
      reason_category,
      reason,
      status,
      admin_notes,
      created_at,
      reviewed_at,
      record_id,
      ask_id,
      reply_id,
      reporter:reporter_id (
        id,
        display_name,
        avatar_url
      )
    `)
    .order('created_at', { ascending: false })
    .range(offset, offset + parseInt(limit) - 1);

  if (filterStatus !== 'ALL') {
    query = query.eq('status', filterStatus);
  }

  const { data, error, count } = await query;

  if (error) {
    console.error('Admin get reports error:', error);
    return res.status(500).json({ error: '取得檢舉列表失敗' });
  }

  // 針對每筆檢舉，非同步撈取目標內容的摘要
  const enriched = await Promise.all((data || []).map(async (report) => {
    let targetInfo = null;
    try {
      if (report.record_id) {
        const { data: rec } = await supabaseAdmin
          .from('records')
          .select('id, title, user_id, users:user_id(display_name)')
          .eq('id', report.record_id)
          .single();
        targetInfo = { type: 'record', ...rec };
      } else if (report.ask_id) {
        const { data: ask } = await supabaseAdmin
          .from('asks')
          .select('id, question, user_id, users:user_id(display_name)')
          .eq('id', report.ask_id)
          .single();
        targetInfo = { type: 'ask', ...ask };
      } else if (report.reply_id) {
        const { data: reply } = await supabaseAdmin
          .from('replies')
          .select('id, content, user_id, users:user_id(display_name)')
          .eq('id', report.reply_id)
          .single();
        targetInfo = { type: 'reply', ...reply };
      }
    } catch (e) {
      // 被檢舉內容可能已刪除
    }
    return { ...report, target: targetInfo };
  }));

  res.json({ data: enriched, page: parseInt(page), limit: parseInt(limit) });
});

// ============================================================
// API: 審核單筆檢舉
// ============================================================
router.patch('/api/reports/:id', requireAdminSession, async (req, res) => {
  const { id } = req.params;
  const { status, admin_notes, action } = req.body;
  // action 可選值：
  //   'remove_content' — 刪除被檢舉的內容（reply/record/ask）
  //   'ban_user'       — 封鎖被檢舉內容的作者
  //   'remove_and_ban' — 刪除內容 + 封鎖用戶
  //   undefined / ''   — 只更新狀態，不動內容

  const validStatuses = ['REVIEWED', 'RESOLVED', 'DISMISSED'];
  if (!validStatuses.includes(status)) {
    return res.status(400).json({ error: `status 必須是 ${validStatuses.join(' / ')}` });
  }

  // 1. 先取得這筆 report，並預先 join 目標內容的 user_id（供後續封鎖使用）
  const { data: report, error: fetchErr } = await supabaseAdmin
    .from('reports')
    .select('id, record_id, ask_id, reply_id, status')
    .eq('id', id)
    .single();

  if (fetchErr || !report) {
    console.error('Admin fetch report error:', fetchErr);
    return res.status(404).json({ error: '找不到此檢舉記錄' });
  }

  const actionLog = [];

  // 2. 若需要封鎖用戶，先取得目標內容的 user_id（必須在刪除內容前查詢）
  let targetUserId = null;
  if (action === 'ban_user' || action === 'remove_and_ban') {
    try {
      if (report.reply_id) {
        const { data: r } = await supabaseAdmin.from('replies').select('user_id').eq('id', report.reply_id).single();
        targetUserId = r?.user_id;
      } else if (report.record_id) {
        const { data: r } = await supabaseAdmin.from('records').select('user_id').eq('id', report.record_id).single();
        targetUserId = r?.user_id;
      } else if (report.ask_id) {
        const { data: r } = await supabaseAdmin.from('asks').select('user_id').eq('id', report.ask_id).single();
        targetUserId = r?.user_id;
      }
    } catch (e) {
      console.warn('Admin: could not fetch target user_id', e);
    }
  }

  // 3. 先更新 report 狀態（必須在刪除內容前更新，避免 ON DELETE CASCADE 使 report 消失）
  const updatePayload = {
    status,
    admin_notes: admin_notes || null,
    reviewed_at: new Date().toISOString(),
  };

  const { data: updatedReport, error: updateErr } = await supabaseAdmin
    .from('reports')
    .update(updatePayload)
    .eq('id', id)
    .select('id, status, admin_notes, reviewed_at')
    .single();

  if (updateErr) {
    console.error('Admin update report error:', updateErr);
    return res.status(500).json({ error: '更新審核狀態失敗', detail: updateErr.message });
  }

  // 4. 刪除內容（若 reports 有 ON DELETE CASCADE，此時 report 已先更新完畢）
  if (action === 'remove_content' || action === 'remove_and_ban') {
    try {
      if (report.reply_id) {
        const { error: e } = await supabaseAdmin.from('replies').delete().eq('id', report.reply_id);
        if (e) throw e;
        actionLog.push('reply 已下架');
      } else if (report.record_id) {
        const { error: e } = await supabaseAdmin.from('records').delete().eq('id', report.record_id);
        if (e) throw e;
        actionLog.push('record 已下架');
      } else if (report.ask_id) {
        const { error: e } = await supabaseAdmin.from('asks').delete().eq('id', report.ask_id);
        if (e) throw e;
        actionLog.push('ask 已下架');
      }
    } catch (deleteErr) {
      console.error('Admin delete content error:', deleteErr);
      // 已更新 report 狀態，但刪除失敗 — 回傳部分成功
      return res.status(207).json({
        ok: false,
        warn: '審核狀態已更新，但刪除內容失敗',
        detail: deleteErr.message,
        data: updatedReport,
        actions: actionLog,
      });
    }
  }

  // 5. 封鎖用戶
  if ((action === 'ban_user' || action === 'remove_and_ban') && targetUserId) {
    try {
      const { error: banErr } = await supabaseAdmin
        .from('users')
        .update({ is_banned: true, banned_at: new Date().toISOString(), ban_reason: admin_notes || '違反社群規範' })
        .eq('id', targetUserId);
      if (banErr) throw banErr;
      actionLog.push(`用戶 ${targetUserId.slice(0, 8)}… 已封鎖`);
    } catch (banErr) {
      console.error('Admin ban user error:', banErr);
      actionLog.push('⚠️ 封鎖用戶失敗：' + banErr.message);
    }
  }

  // 6. 若有執行動作，補充更新 admin_notes 加入動作日誌
  if (actionLog.length > 0) {
    const combinedNotes = [admin_notes, '（動作：' + actionLog.join('、') + '）']
      .filter(Boolean).join(' ');
    await supabaseAdmin.from('reports').update({ admin_notes: combinedNotes }).eq('id', id);
    updatedReport.admin_notes = combinedNotes;
  }

  res.json({ ok: true, data: updatedReport, actions: actionLog });
});

// ============================================================
// API: 封鎖/解封用戶（獨立端點）
// ============================================================
router.patch('/api/users/:userId/ban', requireAdminSession, async (req, res) => {
  const { userId } = req.params;
  const { ban, reason } = req.body; // ban: true/false

  const { error } = await supabaseAdmin
    .from('users')
    .update({
      is_banned: !!ban,
      banned_at: ban ? new Date().toISOString() : null,
      ban_reason: ban ? (reason || '違反社群規範') : null,
    })
    .eq('id', userId);

  if (error) {
    return res.status(500).json({ error: ban ? '封鎖失敗' : '解封失敗', detail: error.message });
  }

  res.json({ ok: true, is_banned: !!ban });
});

// ============================================================
// API: 取得統計數字（dashboard 用）
// ============================================================
router.get('/api/stats', requireAdminSession, async (req, res) => {
  const statuses = ['PENDING', 'REVIEWED', 'RESOLVED', 'DISMISSED'];
  const results = {};

  await Promise.all(statuses.map(async (s) => {
    const { count } = await supabaseAdmin
      .from('reports')
      .select('*', { count: 'exact', head: true })
      .eq('status', s);
    results[s] = count || 0;
  }));

  res.json(results);
});

// ============================================================
// HTML 頁面內容
// ============================================================
function getAdminHTML() {
  return `<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Raibu 管理後台</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'PingFang TC', sans-serif;
           background: #f5f5f7; color: #1d1d1f; min-height: 100vh; }

    /* ---- 頂部導覽列 ---- */
    nav { background: white; border-bottom: 1px solid #e5e5ea; padding: 0 24px;
          height: 52px; display: flex; align-items: center; justify-content: space-between;
          position: sticky; top: 0; z-index: 100; }
    nav .logo { font-size: 17px; font-weight: 700; }
    nav a { color: #86868b; font-size: 14px; text-decoration: none; }
    nav a:hover { color: #0071e3; }

    /* ---- 主內容 ---- */
    main { max-width: 1100px; margin: 0 auto; padding: 28px 20px; }

    /* ---- 統計卡片 ---- */
    .stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin-bottom: 28px; }
    .stat-card { background: white; border-radius: 12px; padding: 18px 22px;
                 box-shadow: 0 1px 6px rgba(0,0,0,0.06); }
    .stat-card .label { font-size: 12px; color: #86868b; margin-bottom: 6px; }
    .stat-card .value { font-size: 28px; font-weight: 700; }
    .stat-card.pending .value  { color: #ff9f0a; }
    .stat-card.reviewed .value { color: #0071e3; }
    .stat-card.resolved .value { color: #34c759; }
    .stat-card.dismissed .value{ color: #86868b; }

    /* ---- 篩選列 ---- */
    .toolbar { display: flex; align-items: center; gap: 10px; margin-bottom: 18px; flex-wrap: wrap; }
    .tab { padding: 6px 16px; border-radius: 20px; border: 1.5px solid #d1d1d6; background: white;
           font-size: 13px; cursor: pointer; transition: all .15s; }
    .tab.active { background: #0071e3; color: white; border-color: #0071e3; }
    .tab:hover:not(.active) { border-color: #0071e3; color: #0071e3; }

    /* ---- 表格 ---- */
    .table-wrap { background: white; border-radius: 14px; overflow: hidden;
                  box-shadow: 0 1px 6px rgba(0,0,0,0.06); }
    table { width: 100%; border-collapse: collapse; }
    th { background: #f5f5f7; font-size: 12px; color: #86868b; font-weight: 600;
         padding: 10px 16px; text-align: left; }
    td { padding: 14px 16px; border-top: 1px solid #f2f2f7; font-size: 13px; vertical-align: top; }
    tr:hover td { background: #fafafa; }

    /* ---- badge ---- */
    .badge { display: inline-block; padding: 2px 10px; border-radius: 20px;
             font-size: 11px; font-weight: 600; }
    .badge.PENDING   { background: #fff3e0; color: #f57c00; }
    .badge.REVIEWED  { background: #e3f2fd; color: #1565c0; }
    .badge.RESOLVED  { background: #e8f5e9; color: #2e7d32; }
    .badge.DISMISSED { background: #f5f5f5; color: #757575; }

    .cat-badge { display: inline-block; padding: 2px 8px; border-radius: 6px;
                 font-size: 11px; background: #f0f0f5; color: #3c3c43; }

    /* ---- 操作按鈕 ---- */
    .btn { padding: 5px 12px; border-radius: 8px; border: none; font-size: 12px;
           cursor: pointer; font-weight: 600; transition: opacity .15s; }
    .btn:hover { opacity: .8; }
    .btn.review      { background: #0071e3; color: white; }
    .btn.resolve     { background: #34c759; color: white; }
    .btn.dismiss     { background: #e5e5ea; color: #3c3c43; }
    .btn.danger      { background: #ff3b30; color: white; }
    .btn.danger-soft { background: #fff0ee; color: #ff3b30; border: 1.5px solid #ff3b30; }

    /* ---- Modal ---- */
    .overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,.4);
               z-index: 200; align-items: center; justify-content: center; }
    .overlay.open { display: flex; }
    .modal { background: white; border-radius: 16px; padding: 28px; width: 480px;
             max-width: calc(100vw - 32px); max-height: 90vh; overflow-y: auto; }
    .modal h2 { font-size: 17px; font-weight: 700; margin-bottom: 18px; }
    .modal label { display: block; font-size: 13px; color: #86868b; margin-bottom: 6px; }
    .modal textarea { width: 100%; padding: 10px 12px; border: 1.5px solid #d1d1d6;
                      border-radius: 10px; font-size: 14px; resize: vertical;
                      min-height: 80px; outline: none; font-family: inherit; }
    .modal textarea:focus { border-color: #0071e3; }
    .modal-actions { display: flex; gap: 8px; margin-top: 20px; flex-wrap: wrap; }
    .modal-actions button { flex: 1; min-width: 120px; padding: 8px 10px; font-size: 12px; }
    .modal-divider { border: none; border-top: 1px solid #f2f2f7; margin: 16px 0; }
    .modal-section-title { font-size: 11px; color: #86868b; font-weight: 600;
                           text-transform: uppercase; letter-spacing: .5px; margin-bottom: 8px; }

    .info-row { display: flex; gap: 6px; margin-bottom: 8px; align-items: flex-start; }
    .info-row .key { font-size: 12px; color: #86868b; min-width: 64px; padding-top: 1px; }
    .info-row .val { font-size: 13px; word-break: break-all; }

    .empty { text-align: center; padding: 60px 20px; color: #86868b; }

  /* ---- toast & confirm ---- */
  .toast { position: fixed; right: 20px; bottom: 20px; background: rgba(0,0,0,0.85); color: white; padding: 10px 14px; border-radius: 10px; box-shadow: 0 6px 18px rgba(0,0,0,0.12); display: none; z-index: 400; }
  .toast.show { display: block; }
  .toast.success { background: rgba(20,120,80,0.95); }
  .confirm-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 350; align-items: center; justify-content: center; }
  .confirm-overlay.open { display: flex; }
  .confirm-box { background: white; border-radius: 12px; padding: 18px; width: 420px; max-width: calc(100vw - 32px); }

    @media (max-width: 700px) {
      .stats { grid-template-columns: repeat(2, 1fr); }
      table thead { display: none; }
      td { display: block; }
      td::before { content: attr(data-label); font-weight: 600; font-size: 11px;
                   color: #86868b; display: block; margin-bottom: 3px; }
    }
  </style>
</head>
<body>

<nav>
  <span class="logo">🌈 Raibu 管理後台</span>
  <a href="/admin/logout">登出</a>
</nav>

<main>
  <!-- 統計 -->
  <div class="stats" id="stats">
    <div class="stat-card pending"><div class="label">待審核</div><div class="value" id="cnt-pending">—</div></div>
    <div class="stat-card reviewed"><div class="label">審核中</div><div class="value" id="cnt-reviewed">—</div></div>
    <div class="stat-card resolved"><div class="label">已處理</div><div class="value" id="cnt-resolved">—</div></div>
    <div class="stat-card dismissed"><div class="label">已駁回</div><div class="value" id="cnt-dismissed">—</div></div>
  </div>

  <!-- 篩選 tabs -->
  <div class="toolbar">
    <button class="tab active" data-status="PENDING"  onclick="switchTab(this)">待審核</button>
    <button class="tab"        data-status="REVIEWED" onclick="switchTab(this)">審核中</button>
    <button class="tab"        data-status="RESOLVED" onclick="switchTab(this)">已處理</button>
    <button class="tab"        data-status="DISMISSED" onclick="switchTab(this)">已駁回</button>
    <button class="tab"        data-status="ALL"      onclick="switchTab(this)">全部</button>
  </div>

  <!-- 表格 -->
  <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th>時間</th>
          <th>類型</th>
          <th>原因</th>
          <th>檢舉者</th>
          <th>被檢舉內容</th>
          <th>狀態</th>
          <th>操作</th>
        </tr>
      </thead>
      <tbody id="tbody">
        <tr><td colspan="7" class="empty">載入中…</td></tr>
      </tbody>
    </table>
  </div>
</main>

<!-- 審核 Modal -->
<div class="overlay" id="modal-overlay" onclick="closeModal(event)">
  <div class="modal">
    <h2>審核檢舉</h2>
    <div id="modal-info"></div>

    <label>管理員備註（選填）</label>
    <textarea id="modal-notes" placeholder="例：內容違反社群規範、已通知用戶…"></textarea>

    <hr class="modal-divider">
    <div class="modal-section-title">✅ 違規成立</div>
    <div class="modal-actions">
      <button class="btn resolve" onclick="confirmAction('remove_content')">下架留言</button>
      <button class="btn danger-soft" onclick="confirmAction('ban_user')">封鎖用戶（留言保留）</button>
      <button class="btn danger" onclick="confirmAction('remove_and_ban')">下架 + 封鎖</button>
    </div>

    <hr class="modal-divider">
    <div class="modal-section-title">� 其他處理</div>
    <div class="modal-actions">
      <button class="btn review"  onclick="submitReview('REVIEWED', '')">標記審核中（稍後處理）</button>
      <button class="btn dismiss" onclick="submitReview('DISMISSED', '')">駁回（不違規）</button>
    </div>
  </div>
</div>

<script>
  let currentStatus = 'PENDING';
  let currentReportId = null;

  // 所有 fetch 統一加 credentials: 'same-origin'，讓瀏覽器自動帶 HttpOnly cookie
  function apiFetch(url, options = {}) {
    return fetch(url, { credentials: 'same-origin', ...options });
  }

  function getCookie(name) {
    return document.cookie.split('; ').find(r => r.startsWith(name + '='))?.split('=')[1] || '';
  }

  const CATEGORY_MAP = {
    SPAM: '垃圾訊息', INAPPROPRIATE: '不當內容',
    HARASSMENT: '騷擾', FALSE_INFO: '錯誤資訊', OTHER: '其他'
  };
  const TYPE_MAP = { record: '記錄', ask: '發問', reply: '回覆' };

  function fmtDate(iso) {
    const d = new Date(iso);
    return d.toLocaleDateString('zh-TW') + ' ' + d.toLocaleTimeString('zh-TW', { hour: '2-digit', minute: '2-digit' });
  }

  function truncate(str, n = 40) {
    if (!str) return '（已刪除）';
    return str.length > n ? str.slice(0, n) + '…' : str;
  }

  // ---- 載入統計 ----
  async function loadStats() {
    const r = await apiFetch('/admin/api/stats');
    if (!r.ok) return;
    const d = await r.json();
    document.getElementById('cnt-pending').textContent   = d.PENDING;
    document.getElementById('cnt-reviewed').textContent  = d.REVIEWED;
    document.getElementById('cnt-resolved').textContent  = d.RESOLVED;
    document.getElementById('cnt-dismissed').textContent = d.DISMISSED;
  }

  // ---- 載入列表 ----
  async function loadReports(status = 'PENDING') {
    const tbody = document.getElementById('tbody');
    tbody.innerHTML = '<tr><td colspan="7" class="empty">載入中…</td></tr>';

    const r = await apiFetch('/admin/api/reports?status=' + status + '&limit=50');

    if (!r.ok) {
      tbody.innerHTML = '<tr><td colspan="7" class="empty">載入失敗，請重新整理</td></tr>';
      return;
    }

    const { data } = await r.json();

    if (!data || data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" class="empty">目前沒有檢舉記錄 ✅</td></tr>';
      return;
    }

    tbody.innerHTML = data.map(r => {
      const target = r.target;
      const targetText = target
        ? (target.question || target.title || target.content || '—')
        : '（內容已刪除）';
      const targetType = target ? TYPE_MAP[target.type] || target.type : '—';
      const reporter = r.reporter?.display_name || r.reporter_id?.slice(0,8);
      const targetUser = target?.users?.display_name || '—';

      const cells = [];
      cells.push('<td data-label="時間">' + fmtDate(r.created_at) + '</td>');
      cells.push('<td data-label="類型"><span class="cat-badge">' + targetType + '</span></td>');
      cells.push('<td data-label="原因"><span class="cat-badge">' + (CATEGORY_MAP[r.reason_category] || r.reason_category) + '</span><div style="margin-top:5px;color:#3c3c43">' + truncate(r.reason) + '</div></td>');
      cells.push('<td data-label="檢舉者">' + reporter + '</td>');
      cells.push('<td data-label="被檢舉內容"><div>' + truncate(targetText) + '</div><div style="color:#86868b;font-size:11px;margin-top:3px">by ' + targetUser + '</div></td>');
      cells.push('<td data-label="狀態"><span class="badge ' + r.status + '">' + r.status + '</span></td>');
      const actionHtml = (r.status === 'PENDING' || r.status === 'REVIEWED')
        ? \`<button class="btn review" onclick='openModal(\${JSON.stringify(r.id)}, \${JSON.stringify(r).replace(/"/g,'&quot;')})'>審核</button>\`
        : '<span style="color:#86868b;font-size:12px">已完成</span>';
      cells.push('<td data-label="操作" id="action-' + r.id + '">' + actionHtml + '</td>');

      return '<tr id="row-' + r.id + '">' + cells.join('') + '</tr>';
    }).join('');
  }

  // ---- Tab 切換 ----
  function switchTab(el) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    el.classList.add('active');
    currentStatus = el.dataset.status;
    loadReports(currentStatus);
  }

  // ---- Modal ----
  function openModal(reportId, report) {
    currentReportId = reportId;
    document.getElementById('modal-notes').value = report.admin_notes || '';

    const target = report.target;
    const targetText = target
      ? (target.question || target.title || target.content || '—')
      : '（內容已刪除）';

    document.getElementById('modal-info').innerHTML = \`
      <div class="info-row"><span class="key">ID</span><span class="val" style="font-size:11px;color:#86868b">\${reportId}</span></div>
      <div class="info-row"><span class="key">原因分類</span><span class="val">\${CATEGORY_MAP[report.reason_category] || report.reason_category}</span></div>
      <div class="info-row"><span class="key">說明</span><span class="val">\${report.reason}</span></div>
      <div class="info-row"><span class="key">被檢舉內容</span><span class="val">\${truncate(targetText, 80)}</span></div>
      <div class="info-row" style="margin-bottom:16px"><span class="key">目前狀態</span><span class="val"><span class="badge \${report.status}">\${report.status}</span></span></div>
    \`;

    document.getElementById('modal-overlay').classList.add('open');
  }

  function closeModal(e) {
    if (e.target === document.getElementById('modal-overlay')) {
      document.getElementById('modal-overlay').classList.remove('open');
    }
  }

  async function submitReview(newStatus, action = '') {
    const notes = document.getElementById('modal-notes').value.trim();

    // 顯示 loading 狀態
    const modalBtns = document.querySelectorAll('#modal-overlay button');
    modalBtns.forEach(b => { b.disabled = true; b.style.opacity = '0.6'; });

    const r = await apiFetch('/admin/api/reports/' + currentReportId, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: newStatus, admin_notes: notes, action }),
    });

    // 恢復按鈕狀態
    modalBtns.forEach(b => { b.disabled = false; b.style.opacity = ''; });

    const result = await r.json().catch(() => ({}));

    if (!r.ok && r.status !== 207) {
      showToast('操作失敗：' + (result.error || '請再試一次'), 'error');
      return;
    }

    // 207 = 部分成功（狀態已更新，但刪除失敗）
    if (r.status === 207) {
      showToast('⚠️ 審核狀態已更新，但刪除內容時發生錯誤', 'error', 5000);
    } else {
      const actionSummary = (result.actions && result.actions.length)
        ? ' — ' + result.actions.join('、')
        : '';
      showToast('✅ 操作成功' + actionSummary);
    }

    document.getElementById('modal-overlay').classList.remove('open');
    // optimistic UI update for immediate feedback
    try { applyOptimisticUpdate(currentReportId, result.data?.status || newStatus); } catch(e){}
    await loadStats();
    await loadReports(currentStatus);
  }

  const ACTION_CONFIRM = {
    remove_content: '確定要【下架這則內容】嗎？此操作不可復原。',
    ban_user: '確定要【封鎖這位用戶】嗎？封鎖後他將無法使用 App。',
    remove_and_ban: '確定要【下架內容並封鎖用戶】嗎？此操作不可復原。',
  };
  const ACTION_LABEL = {
    remove_content: '下架違規內容',
    ban_user: '封鎖該用戶',
    remove_and_ban: '下架 + 封鎖',
  };

  async function confirmAction(action) {
    const ok = await showConfirm(ACTION_CONFIRM[action], ACTION_LABEL[action]);
    if (!ok) return;
    await submitReview('RESOLVED', action);
  }

  // ---- toast & confirm helpers ----
  function showToast(message, type = 'success', ms = 3500) {
    let t = document.getElementById('global-toast');
    if (!t) {
      t = document.createElement('div');
      t.id = 'global-toast';
      t.className = 'toast';
      document.body.appendChild(t);
    }
    t.style.display = '';
    t.textContent = message;
    t.className = 'toast' + (type === 'success' ? ' show success' : ' show');
    clearTimeout(t._timeout);
    t._timeout = setTimeout(() => {
      t.className = 'toast';
      t.style.display = '';
    }, ms);
  }

  function showConfirm(message, title = '確認') {
    return new Promise((resolve) => {
      let overlay = document.getElementById('confirm-overlay');
      if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'confirm-overlay';
        overlay.className = 'confirm-overlay';
        document.body.appendChild(overlay);
      }
      overlay.style.display = '';
      if (!overlay.querySelector('#confirm-msg')) {
        overlay.innerHTML = '<div class="confirm-box">'
          + '<div id="confirm-title" style="font-weight:700;margin-bottom:8px">確認</div>'
          + '<div id="confirm-msg" style="margin-bottom:14px;color:#3c3c43"></div>'
          + '<div style="display:flex;gap:8px;justify-content:flex-end">'
            + '<button id="confirm-cancel" class="btn dismiss">取消</button>'
            + '<button id="confirm-ok" class="btn danger">確認</button>'
          + '</div>'
        + '</div>';
      }
      overlay.querySelector('#confirm-title').textContent = title;
      overlay.querySelector('#confirm-msg').textContent = message;
      overlay.classList.add('open');
      const cleanup = (val) => { overlay.classList.remove('open'); resolve(val); };
      overlay.querySelector('#confirm-cancel').onclick = () => cleanup(false);
      overlay.querySelector('#confirm-ok').onclick = () => cleanup(true);
    });
  }

  function applyOptimisticUpdate(reportId, newStatus) {
    try {
      const row = document.getElementById('row-' + reportId);
      if (!row) return;
      const badge = row.querySelector('.badge');
      if (badge) { badge.textContent = newStatus; badge.className = 'badge ' + newStatus; }
      const actionCell = row.querySelector('[data-label="操作"]');
      if (actionCell) { actionCell.innerHTML = '<span style="color:#86868b;font-size:12px">已完成</span>'; }
    } catch (e) { console.warn('optimistic update failed', e); }
  }

  // ---- 初始化 ----
  loadStats();
  loadReports('PENDING');
</script>
<!-- placeholders for toast & confirm (created dynamically if missing) -->
<div id="global-toast" class="toast"></div>
<div id="confirm-overlay" class="confirm-overlay">
  <div class="confirm-box">
    <div id="confirm-title" style="font-weight:700;margin-bottom:8px">確認</div>
    <div id="confirm-msg" style="margin-bottom:14px;color:#3c3c43"></div>
    <div style="display:flex;gap:8px;justify-content:flex-end">
      <button id="confirm-cancel" class="btn dismiss">取消</button>
      <button id="confirm-ok" class="btn danger">確認</button>
    </div>
  </div>
</div>
</body>
</html>`;
}

module.exports = router;
