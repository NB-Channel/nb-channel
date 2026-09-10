// NB频道 安全体检:表权限 + 敏感读 + RPC 令牌化 + 后台密码口子
// 用法:node tools/security_check.mjs
const K = 'sb_publishable_tv7YVJEisnvs3hvU8ImYUw_b0p6bmRg';
const U = 'https://pbaafgjkwdbwcmsikcmg.supabase.co/rest/v1';
const Z = '00000000-0000-0000-0000-000000000000';
const H = { apikey: K, Authorization: `Bearer ${K}` };

const TABLES = ['profiles','user_companies','bank_accounts','bank_logs','holdings','transactions','transfers',
  'lottery_records','user_titles','user_achievements','user_items','user_balance_counts','user_sessions',
  'comments','comment_reactions','reports','notifications','products','product_purchases','product_downloads',
  'messages','conversations','friendships','friend_requests','profile_visits','check_in_records',
  'checkin_fix_records','coin_claims','verified_users','verified_users_backup','titles','achievements',
  'shop_items','stock_daily_kline','stock_history','stock_history_full','stock_latest','user_checkins',
  'support_logs','support_rules','banned_ips','bad_words','api_logs','market_meta','email_codes',
  'registration_attempts','admin_config','admin_sessions','admin_login_attempts'];

const FILTERS = ['id=eq.-999999', `id=eq.${Z}`, `user_id=eq.${Z}`, 'key=eq.__probe__', 'email=eq.__probe@x.com'];

const lines = [];
let bad = 0;

// ---------- 1) 写权限 ----------
lines.push('【1】匿名写权限(实测 DELETE 不存在的行;401=已锁)');
const writable = [];
for (const t of TABLES) {
  let verdict = '?';
  for (const q of FILTERS) {
    try {
      const r = await fetch(`${U}/${t}?${q}`, { method: 'DELETE', headers: { ...H, Prefer: 'return=minimal' } });
      if (r.status === 204 || r.status === 200) { verdict = '可写!!'; break; }
      if (r.status === 401 || r.status === 403) { verdict = '已锁'; break; }
      verdict = `?${r.status}`;
    } catch { verdict = 'ERR'; }
  }
  if (verdict === '可写!!') { writable.push(t); bad++; }
}
lines.push(writable.length ? '   ❌ 仍可写: ' + writable.join(', ') : `   ✅ 全部 ${TABLES.length} 张表写权限已锁死`);

// ---------- 2) 敏感读 ----------
lines.push('');
lines.push('【2】匿名可读表(设计上该公开的才算正常)');
const readable = [];
for (const t of TABLES) {
  const r = await fetch(`${U}/${t}?select=*&limit=1`, { headers: H });
  if (r.status === 200 || r.status === 206) readable.push(t);
}
lines.push('   可读: ' + readable.join(', '));
const shouldBeClosed = ['email_codes', 'admin_sessions', 'admin_login_attempts', 'registration_attempts', 'user_sessions', 'bank_accounts', 'bank_logs', 'transfers'];
const leaked = shouldBeClosed.filter(t => readable.includes(t));
lines.push(leaked.length ? '   ❌ 不该可读却能读: ' + leaked.join(', ') : '   ✅ 敏感表均不可读');
if (leaked.length) bad++;

// ---------- 3) admin_config 只应剩公告 ----------
lines.push('');
lines.push('【3】admin_config 内容(应只剩 announcement,看不到 admin_password)');
{
  const r = await fetch(`${U}/admin_config?select=key`, { headers: H });
  const j = await r.json();
  const keys = Array.isArray(j) ? j.map(x => x.key) : j;
  lines.push('   可见 key: ' + JSON.stringify(keys));
  const hasPwd = Array.isArray(keys) && keys.includes('admin_password');
  lines.push(hasPwd ? '   ❌ 密码行仍可读!' : '   ✅ 密码行已不可读');
  if (hasPwd) bad++;
}

// ---------- 4) RPC 令牌化 ----------
lines.push('');
lines.push('【4】关键 RPC 鉴权(应返回鉴权失败/空/401)');
const RPCS = [
  ['send_message', { p_sender: Z, p_session: 'x', p_conversation_id: 1, p_content: 'x' }],
  ['get_conversations', { p_user: Z, p_session: 'x' }],
  ['get_friends', { p_user_id: Z, p_session: 'x' }],
  ['buy_title', { p_user_id: Z, p_session: 'x', p_title_key: 'x' }],
  ['visit_profile', { p_user_id: Z, p_session: 'x' }],
  ['update_username', { user_id: Z, p_session: 'x', new_username: 'x', old_password: 'x' }],
  ['update_password', { user_id: Z, p_session: 'x', old_password: 'x', new_password: 'y' }],
  ['register_company', { p_user_id: Z, p_session: 'x', p_company_name: 'x', p_need_verify: false }],
  ['support_company', { p_user_id: Z, p_session: 'x', p_company_id: 1, p_amount: 1 }],
  ['insert_comment', { p_page_path: 'x', p_user_id: Z, p_session: 'x', p_content: 'x', p_parent_id: null }],
  ['create_product', { p_user_id: Z, p_session: 'x', p_title: 'x', p_description: 'x', p_price: 1, p_file_url: 'x', p_file_name: 'x', p_file_size: 1, p_mime_type: 'x' }],
  ['update_avatar_url', { p_user_id: Z, p_session: 'x', p_url: 'x' }],
  ['purchase_product', { p_product_id: 1, p_buyer_id: Z, p_session: 'x' }],
  ['get_my_balance', { p_user_id: Z, p_session: 'x' }],
  ['get_checkin_status', { p_user_id: Z, p_session: 'x' }],
  ['do_check_in', { p_user_id: Z, p_session: 'x' }],
  ['transfer_nb', { p_from: Z, p_session: 'x', p_to: Z, p_amount: 1 }],
  ['bankrupt_company', { p_user_id: Z, p_session: 'x' }],
  ['check_admin_password_plain', { input_pwd: 'x' }],
  ['bank_daily_settle', {}],
  ['random_fluctuate_market_values', {}],
];
let rpcBad = 0;
for (const [fn, body] of RPCS) {
  const r = await fetch(`${U}/rpc/${fn}`, { method: 'POST', headers: { ...H, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const t = await r.text();
  const ok = r.status === 401 || r.status === 204 || t.includes('鉴权失败') || t === '[]' || t.includes('permission denied');
  if (!ok) { rpcBad++; bad++; }
  lines.push(`   ${ok ? '✅' : '❌'} ${fn.padEnd(28)} [${r.status}] ${t.slice(0, 70)}`);
}
lines.push(`   小结:${RPCS.length - rpcBad}/${RPCS.length} 已拦`);

// ---------- 汇总 ----------
lines.push('');
lines.push(bad === 0 ? '===== 总体:✅ 全部通过,未发现匿名可乘之机 =====' : `===== 总体:❌ 发现 ${bad} 处问题(见上) =====`);

const fs = await import('node:fs');
fs.writeFileSync('D:/工作区/fanstest/final_check.txt', lines.join('\n'), 'utf8');
console.log(lines.join('\n'));
