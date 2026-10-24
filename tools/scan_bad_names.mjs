// 扫描用户名 + 个人简介(bio)里的脏话/辱骂/谐音绕过
const K = 'sb_publishable_tv7YVJEisnvs3hvU8ImYUw_b0p6bmRg';
const U = 'https://pbaafgjkwdbwcmsikcmg.supabase.co/rest/v1';

const BAD = [
  ['死妈', '骂人'], ['死全家', '骂人'], ['妈死', '骂人'], ['你妈', '骂人'], ['尼玛', '骂人'],
  ['妈的', '骂人'], ['他妈', '骂人'], ['干你', '骂人'], ['日你', '骂人'], ['操你', '骂人'], ['草你', '骂人'],
  ['傻逼', '骂人'], ['傻B', '骂人'], ['煞笔', '骂人'], ['沙比', '骂人'], ['傻叉', '骂人'], ['傻狗', '骂人'],
  ['智障', '骂人'], ['脑残', '骂人'], ['弱智', '骂人'], ['废物', '骂人'], ['垃圾', '骂人'],
  ['狗东西', '骂人'], ['狗杂', '骂人'], ['杂种', '骂人'], ['野种', '骂人'], ['畜生', '骂人'],
  ['婊', '骂人'], ['贱人', '骂人'], ['贱', '骂人'], ['骚货', '骂人'], ['肏', '骂人'], ['屌', '骂人'], ['屄', '骂人'],
  ['鸡巴', '骂人'], ['去死', '骂人'], ['全家死', '骂人'], ['孤儿', '骂人'], ['没妈', '骂人'], ['眉目', '谐音没妈'],
  ['私募', '谐音死妈'], ['勾石', '谐音狗屎'], ['狗屎', '骂人'], ['蛆', '骂人'], ['汉奸', '骂人'], ['支那', '辱华'],
  ['gay', '辱骂同性恋'], ['homo', '辱骂同性恋'], ['sbsb', '傻逼连写'], ['sb', '傻逼缩写'],
  ['nmsl', '骂人缩写'], ['cnm', '骂人缩写'], ['tmd', '骂人缩写'], ['mmp', '骂人缩写'], ['wdnmd', '骂人缩写'],
  ['rnm', '骂人缩写'], ['zz', '智障缩写'], ['nc', '脑残缩写'], ['fw', '废物缩写'], ['lj', '垃圾缩写'],
  ['fuck', '脏话'], ['shit', '脏话'], ['bitch', '脏话'], ['asshole', '脏话'], ['cunt', '脏话'],
  ['bastard', '脏话'], ['retard', '脏话'], ['nigger', '种族歧视'], ['rape', '严重'], ['porn', '严重'],
  ['死🐎', '骂人'], ['死🐴', '骂人'], ['亖', '骂人'], ['死m', '骂人'], ['4妈', '骂人'],
  ['Adolf', '纳粹'], ['希特勒', '纳粹'], ['114514', '淫梦梗'], ['夺舍', '挑衅'], ['炸了', '挑衅']
];

(async () => {
  const r = await fetch(`${U}/profiles?select=id,username,created_at,is_banned,banned_reason,bio&order=created_at.asc&limit=2000`, {
    headers: { apikey: K, Authorization: `Bearer ${K}` }
  });
  const rows = await r.json();
  const bj = t => new Date(new Date(t).getTime() + 8 * 3600 * 1000).toISOString().slice(0, 16).replace('T', ' ');

  const nameHits = [], bioHits = [];
  for (const p of rows) {
    const name = String(p.username || '');
    const bio = String(p.bio || '');
    const scan = txt => {
      const low = txt.toLowerCase(); const hit = [];
      for (const [w, tag] of BAD) if (low.includes(w.toLowerCase())) hit.push(`${w}(${tag})`);
      return [...new Set(hit)];
    };
    const hn = scan(name);
    const hb = scan(bio);
    if (hn.length) nameHits.push({ ...p, hit: hn, t: bj(p.created_at) });
    if (hb.length) bioHits.push({ ...p, hit: hb, t: bj(p.created_at), bio });
  }

  const out = [];
  out.push(`账号总数 ${rows.length}`);
  out.push('');
  out.push(`===== 用户名含脏话/辱骂 (${nameHits.length}) =====`);
  for (const h of nameHits) out.push(`${h.t}  「${h.username}」  [${h.hit.join(', ')}]${h.is_banned ? ' 已封:' + (h.banned_reason || '') : ''}  ${h.id}`);
  out.push('');
  out.push(`===== 个人简介含脏话/辱骂 (${bioHits.length}) =====`);
  for (const h of bioHits) out.push(`${h.t}  「${h.username}」 [${h.hit.join(', ')}]${h.is_banned ? ' 已封' : ''}\n      bio: ${h.bio.replace(/\s+/g, ' ').slice(0, 160)}`);

  const fs = await import('node:fs');
  fs.writeFileSync('D:/工作区/fanstest/name_scan.txt', out.join('\n'), 'utf8');
  console.log('name hits', nameHits.length, '| bio hits', bioHits.length);
})();
