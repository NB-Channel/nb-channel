/**
 * NB频道 市值 API - JavaScript 示例
 * 浏览器：直接 <script src="js_example.js"> 后使用 window.NBMarket
 * Node.js：const NBMarket = require('./js_example');
 *
 * ⚠️ 需要 API Key（2026-09-25 起）
 *   /api/market、/api/comments、/api/stats 需带 X-API-Key 请求头，
 *   否则返回 401。向站长申请后这样填：
 *     NBMarket.setApiKey('你申请到的 Key');
 *   /api/bili-fans 与 /api/docs 仍然完全公开，不需要 Key。
 */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.NBMarket = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const BASE_URL = 'https://api.nb-channel.top';

  // API Key（留空则不带该请求头）。不要把这个文件连同真实 Key 提交到公开仓库。
  let API_KEY = '';

  function authHeaders() {
    return API_KEY ? { 'X-API-Key': API_KEY } : {};
  }

  async function getJSON(path, params) {
    const url = new URL(BASE_URL + path);
    if (params) {
      Object.keys(params).forEach(k => {
        if (params[k] !== undefined && params[k] !== null) url.searchParams.set(k, params[k]);
      });
    }
    const resp = await fetch(url, { headers: authHeaders() });
    if (!resp.ok) {
      let msg = 'HTTP ' + resp.status;
      try { const j = await resp.json(); msg = (j && j.message) || msg; } catch (e) { /* 忽略 */ }
      if (resp.status === 401) msg = 'API Key 缺失或错误：请先调用 NBMarket.setApiKey() 填入申请到的 Key';
      throw new Error(msg);
    }
    return resp.json();
  }

  const NBMarket = {
    /** 填入向站长申请到的 API Key（填一次即可，后续请求自动携带） */
    setApiKey: (k) => { API_KEY = k || ''; },

    /** 全市场快照；name 可选，按公司名模糊查询 */
    market: (name) => getJSON('/api/market', { name }),

    /** 单家公司市值 */
    marketById: (companyId) => getJSON('/api/market/' + companyId),

    /** 历史K线（市值走势点），days 1~30 */
    history: (companyId, days) => getJSON('/api/market/' + companyId + '/history', { days }),

    /** 最新评论（只读） */
    comments: (page, limit, pagePath) => getJSON('/api/comments', { page, limit, page_path: pagePath }),

    /** 全市场 CSV 导出，返回文本 */
    async exportCsv() {
      const resp = await fetch(BASE_URL + '/api/market/export?format=csv', { headers: authHeaders() });
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      return resp.text();
    },

    /** B站实时粉丝数（公开接口，无需 Key） */
    biliFans: () => getJSON('/api/bili-fans'),
  };

  return NBMarket;
});

/* 用法示例（浏览器控制台）：
NBMarket.setApiKey('你申请到的 Key');          // 先填 Key
const m = await NBMarket.market();
console.log('总市值', m.total_market_value, '公司数', m.count);
const one = await NBMarket.marketById(3);
const k = await NBMarket.history(3, 7);
const cs = await NBMarket.comments(1, 5);
const fans = await NBMarket.biliFans();        // 这个不需要 Key
*/
