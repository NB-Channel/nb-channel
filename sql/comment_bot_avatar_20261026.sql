-- ============================================================
-- 给机器人账号设头像
--
-- 头像文件：img/bot-avatar.svg（刚加进仓库）
-- 用绝对地址，这样在根目录页和 Beta 页都能显示（相对路径在 Beta 下会 404）。
--
-- ⚠️ 如果你的头像渲染要求 http(s) 开头（前端可能有过滤），下面这个是合格的。
--    如果显示不出来，改成 data URI 版本（文件末尾那段注释里）。
--
-- 在 Supabase SQL Editor 里跑一次。
-- ============================================================

update public.profiles
   set avatar_url = 'https://github.nb-channel.top/img/bot-avatar.svg'
 where id = '11111111-2222-3333-4444-555555555555'::uuid;

-- 确认（应该输出一行，avatar_url 是上面那个网址）
select id, username, avatar_url from public.profiles
 where id = '11111111-2222-3333-4444-555555555555'::uuid;

-- ------------------------------------------------------------
-- 备用：如果上面的网址显示不出来（比如前端只认 data: 或 storage 路径），
-- 把 SVG 转成 data URI 塞进去。生成方法（本地跑一次即可）：
--   python -c "import base64,io;print('data:image/svg+xml;base64,'+base64.b64encode(io.open('img/bot-avatar.svg','rb').read()).decode())"
-- 然后把 update 的 avatar_url 换成那串。
-- ------------------------------------------------------------
