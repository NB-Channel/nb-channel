/**
 * NB频道 导航页 · nb-channel.top
 * Cloudflare Worker 完整代码:在 Workers 面板打开本 Worker → Edit code,
 * 全选替换为下方全部内容 → Deploy 即生效。
 * 注意:页面内联 JS 刻意避开了反引号(`)与 ${},可直接整体粘贴。
 *
 * 2026-10-01 改动:镜像站点区新增 Netlify 站入口(第四个),
 *                  meta description 同步补上 Netlify。
 * 2026-10-05 改动:Netlify 站换成 EdgeOne Pages。
 *                  Netlify 免费版每月只给 20 次部署,本站有定时自动提交,
 *                  额度很快用光;用完之后它不再部署,站点一直停在
 *                  2026-09-27 的 V0.9.7,所以弃用。
 *                  新站 edgeone.nb-channel.top 走腾讯云 EdgeOne Pages
 *                  (香港节点,免备案),免费额度 500 次构建/月、流量不限量、
 *                  用量超额也不中断服务。
 *                  netlify.nb-channel.top 的 DNS 记录已删。
 */
export default {
  async fetch(request, env, ctx) {
    const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="description" content="NB频道（NoBook频道）官网入口——新版官网 Beta 界面与 GitHub / Cloudflare / EdgeOne / PythonAnywhere 镜像站导航。">
<meta name="theme-color" content="#0b1220">
<title>NB频道 · 官网入口</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
    color: #e5eaf3; line-height: 1.6; -webkit-font-smoothing: antialiased;
    background:
        radial-gradient(900px 560px at 85% -10%, rgba(59,130,246,.16), transparent 60%),
        radial-gradient(760px 520px at 8% 108%, rgba(139,92,246,.14), transparent 60%),
        linear-gradient(168deg, #0b1220 0%, #101c33 55%, #171340 100%);
    min-height: 100vh;
}
a { text-decoration: none; color: inherit; }
.wrap { max-width: 560px; margin: 0 auto; padding: 56px 20px 44px; }

/* 头 */
.head { text-align: center; margin-bottom: 40px; }
.head .logo { height: 58px; width: auto; margin-bottom: 14px; }
.head h1 { font-size: 1.9rem; font-weight: 800; letter-spacing: 2px; color: #fff; }
.head .alt { font-size: .8rem; color: rgba(255,255,255,.45); letter-spacing: 3px; margin-top: 6px; }
.fans {
    display: inline-flex; align-items: center; gap: 8px; margin-top: 16px;
    padding: 7px 16px; border-radius: 999px;
    background: rgba(255,255,255,.05); border: 1px solid rgba(255,255,255,.12);
    font-size: .85rem; color: rgba(255,255,255,.75); letter-spacing: .5px;
    font-variant-numeric: tabular-nums;
}
.fans .dot { width: 7px; height: 7px; border-radius: 50%; background: #4ade80; box-shadow: 0 0 0 0 rgba(74,222,128,.5); animation: pulse 2s ease-out infinite; }
.fans b { color: #9cc0ff; font-weight: 700; font-size: 1rem; }
@keyframes pulse { 0% { box-shadow: 0 0 0 0 rgba(74,222,128,.5); } 70% { box-shadow: 0 0 0 7px rgba(74,222,128,0); } 100% { box-shadow: 0 0 0 0 rgba(74,222,128,0); } }

/* 分区 */
.sec { margin-bottom: 26px; }
.sec-title {
    display: flex; align-items: center; gap: 10px;
    font-size: .72rem; font-weight: 700; letter-spacing: 3px;
    color: rgba(255,255,255,.42); text-transform: uppercase;
    margin-bottom: 14px;
}
.sec-title::after { content: ''; flex: 1; height: 1px; background: linear-gradient(90deg, rgba(255,255,255,.16), transparent); }

/* 主卡 */
.card {
    background: rgba(255,255,255,.045);
    border: 1px solid rgba(255,255,255,.1);
    border-radius: 20px; padding: 22px 22px 20px;
    backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px);
    transition: border-color .3s ease, transform .3s cubic-bezier(.16,1,.3,1);
}
.card:hover { border-color: rgba(96,165,250,.45); transform: translateY(-2px); }
.big {
    display: flex; align-items: center; justify-content: space-between; gap: 14px;
    background: linear-gradient(135deg, #3b82f6, #6366f1); color: #fff;
    border: none; border-radius: 16px; padding: 17px 22px;
    box-shadow: 0 18px 40px -14px rgba(59,130,246,.6);
    font-size: 1.06rem; font-weight: 700; letter-spacing: 1px;
    transition: transform .25s cubic-bezier(.16,1,.3,1), box-shadow .25s ease;
}
.big:hover { transform: translateY(-3px); box-shadow: 0 24px 50px -16px rgba(59,130,246,.7); }
.big small { display: block; font-size: .72rem; font-weight: 500; letter-spacing: 1.5px; opacity: .75; }
.big .ar { font-size: 1.2rem; font-weight: 200; }
.chips { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 10px; }
.chip {
    text-align: center; padding: 10px 8px; border-radius: 12px;
    background: rgba(255,255,255,.05); border: 1px solid rgba(255,255,255,.1);
    font-size: .86rem; color: rgba(255,255,255,.8); letter-spacing: .5px;
    transition: all .25s ease;
}
.chip:hover { border-color: rgba(96,165,250,.5); color: #fff; background: rgba(59,130,246,.14); }
.chip em { font-style: normal; color: rgba(255,255,255,.4); font-size: .7rem; display: block; letter-spacing: 1px; margin-bottom: 3px; }

/* 镜像列表 */
.mirror { display: flex; align-items: center; gap: 12px; padding: 13px 16px; border-radius: 14px; background: rgba(255,255,255,.04); border: 1px solid rgba(255,255,255,.08); margin-bottom: 8px; }
.mirror .ic { width: 34px; height: 34px; border-radius: 10px; flex-shrink: 0; display: flex; align-items: center; justify-content: center; font-size: .95rem; background: linear-gradient(135deg, rgba(59,130,246,.25), rgba(139,92,246,.25)); }
.mirror .m-name { flex: 1; min-width: 0; }
.mirror .m-name b { display: block; font-size: .92rem; color: #fff; letter-spacing: .3px; }
.mirror .m-name span { font-size: .72rem; color: rgba(255,255,255,.45); letter-spacing: .5px; }
.mirror .links { display: flex; gap: 6px; flex-shrink: 0; }
.mirror .links a { font-size: .76rem; font-weight: 700; letter-spacing: 1px; color: #9cc0ff; padding: 5px 11px; border-radius: 999px; border: 1px solid rgba(96,165,250,.3); transition: all .2s ease; white-space: nowrap; }
.mirror .links a:hover { background: rgba(59,130,246,.18); color: #fff; }

/* API + 底部 */
.api { display: flex; justify-content: center; gap: 26px; margin: 6px 0 30px; }
.api a { font-size: .8rem; letter-spacing: 1.5px; color: rgba(255,255,255,.5); transition: color .25s ease; }
.api a:hover { color: #9cc0ff; }
.foot { text-align: center; font-size: .74rem; color: rgba(255,255,255,.32); letter-spacing: 1px; line-height: 2; }
.foot a { color: rgba(255,255,255,.55); }
.foot a:hover { color: #fff; }
@media (max-width: 480px) {
    .wrap { padding: 40px 16px 30px; }
    .head h1 { font-size: 1.6rem; }
    .chips { grid-template-columns: 1fr; }
    .mirror { flex-wrap: wrap; }
    .mirror .links { margin-left: 46px; }
}
</style>
</head>
<body>
<div class="wrap">

    <header class="head">
        <img class="logo" src="https://github.nb-channel.top/images/NB%E9%A2%91%E9%81%93LOGO.png" alt="NB频道" onerror="this.style.display='none'">
        <h1>NB频道</h1>
        <div class="alt">NOBOOK CHANNEL · 官网入口</div>
        <div class="fans"><span class="dot"></span>B站粉丝 <b id="fansNum">…</b></div>
    </header>

    <section class="sec">
        <div class="sec-title">新版官网 · Beta 界面</div>
        <a class="big" href="https://github.nb-channel.top/Beta/index-Beta.html" target="_blank" rel="noopener noreferrer">
            <span>进入 Beta 官网<small>2026 全新界面 · 推荐</small></span><span class="ar">→</span>
        </a>
        <div class="chips">
            <a class="chip" href="https://github.nb-channel.top/Beta/videos-Beta.html" target="_blank" rel="noopener noreferrer"><em>VIDEO</em>视频档案</a>
            <a class="chip" href="https://github.nb-channel.top/Beta/comments-Beta.html" target="_blank" rel="noopener noreferrer"><em>COMMUNITY</em>评论区</a>
            <a class="chip" href="https://github.nb-channel.top/Beta/product-Beta.html" target="_blank" rel="noopener noreferrer"><em>LAB</em>我的产品</a>
            <a class="chip" href="https://github.nb-channel.top/Beta/changelog-Beta.html" target="_blank" rel="noopener noreferrer"><em>LOG</em>更新日志</a>
        </div>
    </section>

    <section class="sec">
        <div class="sec-title">镜像站点 · 内容同步</div>
        <div class="mirror">
            <div class="ic">G</div>
            <div class="m-name"><b>GitHub Pages 站</b><span>主站 · 代码仓库 Pages</span></div>
            <div class="links"><a href="https://github.nb-channel.top/Beta/index-Beta.html" target="_blank" rel="noopener noreferrer">新版</a><a href="https://github.nb-channel.top/" target="_blank" rel="noopener noreferrer">经典</a></div>
        </div>
        <div class="mirror">
            <div class="ic">C</div>
            <div class="m-name"><b>Cloudflare Pages 站</b><span>镜像</span></div>
            <div class="links"><a href="https://cloudflare.nb-channel.top/Beta/index-Beta.html" target="_blank" rel="noopener noreferrer">新版</a><a href="https://cloudflare.nb-channel.top/" target="_blank" rel="noopener noreferrer">经典</a></div>
        </div>
        <div class="mirror">
            <div class="ic">P</div>
            <div class="m-name"><b>PythonAnywhere 站</b><span>镜像 + 后端接口</span></div>
            <div class="links"><a href="https://pythonanywhere.nb-channel.top/Beta/index-Beta.html" target="_blank" rel="noopener noreferrer">新版</a><a href="https://pythonanywhere.nb-channel.top/" target="_blank" rel="noopener noreferrer">经典</a></div>
        </div>
        <div class="mirror">
            <div class="ic">E</div>
            <div class="m-name"><b>EdgeOne 站</b><span>镜像 · 腾讯云香港节点</span></div>
            <div class="links"><a href="https://edgeone.nb-channel.top/Beta/index-Beta.html" target="_blank" rel="noopener noreferrer">新版</a><a href="https://edgeone.nb-channel.top/" target="_blank" rel="noopener noreferrer">经典</a></div>
        </div>
    </section>

    <div class="api">
        <a href="https://api.nb-channel.top/api/docs" target="_blank" rel="noopener noreferrer">开放接口文档 ↗</a>
        <a href="https://nb-channel.top/api-sdk/" target="_blank" rel="noopener noreferrer">API SDK ↗</a>
    </div>

    <footer class="foot">
        制作：<a href="https://space.bilibili.com/3493259582114264" target="_blank" rel="noopener noreferrer">NB搞事局（原NB实验室-作死）</a><br>
        联系：<a href="mailto:nbchannel@163.com">nbchannel@163.com</a> © 2026 NB频道 · 虚拟公司
    </footer>
</div>

<script>
(function () {
    // 实时粉丝(约30秒同步,失败静默)
    var el = document.getElementById('fansNum');
    function fmt(n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
    function poll() {
        fetch('https://nbchannel.pythonanywhere.com/api/bili-fans', { cache: 'no-store' })
            .then(function (r) { return r.ok ? r.json() : null; })
            .then(function (j) {
                if (j && j.follower > 0) { el.textContent = fmt(parseInt(j.follower, 10)); }
                else { el.textContent = '--'; }
            })
            .catch(function () { el.textContent = '--'; });
    }
    poll();
    setInterval(poll, 30000);
})();
</script>
</body>
</html>`;
    return new Response(html, {
        headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'public, max-age=300' }
    });
  }
};
