// 把自定义的 Android 原生代码注入到 Capacitor 生成的项目里(在 GitHub Actions 里执行)
// 做三件事:
//   ① 用我们自己的 MainActivity 覆盖官方模板(加下载接管 + 自动安装)
//   ② 往 AndroidManifest 里补权限:REQUEST_INSTALL_PACKAGES
//   ③ 写入版本号(versionCode/versionName),供自更新比较
import fs from 'node:fs';
import path from 'node:path';

const APP = path.join(process.cwd(), 'android', 'app');
const pkgPath = path.join(APP, 'src', 'main', 'java', 'top', 'nbchannel', 'app');
const manifestPath = path.join(APP, 'src', 'main', 'AndroidManifest.xml');
const gradlePath = path.join(APP, 'build.gradle');
const versionCode = process.env.APP_VERSION_CODE || '1';
const versionName = process.env.APP_VERSION_NAME || '1.0.0';

function log(msg) { console.log('  ' + msg); }

// ---------- ① 注入所有自定义原生代码 ----------
// 直接扫描目录下所有 .java,以后加文件不用再改这里
const overridesDir = path.join(process.cwd(), 'android-overrides');
const overrideFiles = fs.readdirSync(overridesDir).filter(f => f.endsWith('.java'));
if (!overrideFiles.includes('MainActivity.java')) {
  console.error('❌ android-overrides 里找不到 MainActivity.java');
  process.exit(1);
}
fs.mkdirSync(pkgPath, { recursive: true });
for (const f of overrideFiles) {
  fs.copyFileSync(path.join(overridesDir, f), path.join(pkgPath, f));
}
log(`✅ 原生代码已注入 ${overrideFiles.length} 个文件(${overrideFiles.join(', ')}) → ${path.relative(process.cwd(), pkgPath)}`);

// ---------- ② 补权限 ----------
let manifest = fs.readFileSync(manifestPath, 'utf8');
const needPerms = [
  'android.permission.REQUEST_INSTALL_PACKAGES',
  'android.permission.INTERNET',
];
let added = 0;
for (const p of needPerms) {
  if (!manifest.includes(p)) {
    manifest = manifest.replace(/<application/, `<uses-permission android:name="${p}" />\n    <application`);
    added++;
  }
}
if (added) {
  fs.writeFileSync(manifestPath, manifest, 'utf8');
  log(`✅ AndroidManifest 已补 ${added} 条权限`);
} else {
  log('ℹ️ 权限已存在,跳过');
}

// ---------- ③ 写版本号 ----------
let gradle = fs.readFileSync(gradlePath, 'utf8');
gradle = gradle
  .replace(/versionCode\s+\d+/, `versionCode ${versionCode}`)
  .replace(/versionName\s+"[^"]*"/, `versionName "${versionName}"`);
fs.writeFileSync(gradlePath, gradle, 'utf8');
log(`✅ 版本号写入: versionCode=${versionCode} versionName=${versionName}`);

// ---------- ④ 产出 version.json(放到网站,供 APP 检查更新) ----------
// 注意:本脚本在 app/ 目录下执行,process.cwd() 是 app/;
// 而 APK 和 version.json 必须放到【仓库根】的 download/,所以用 GITHUB_WORKSPACE 定位
const repoRoot = process.env.GITHUB_WORKSPACE || path.join(process.cwd(), '..');
const siteDir = path.join(repoRoot, 'download');
fs.mkdirSync(siteDir, { recursive: true });

/**
 * 更新简介:直接从 Beta/changelog-Beta.html 里读当前版本(app 类型)的条目,
 * 取「总标题 · 第一个小标题」拼成一句话。
 *
 * 以前这里用的是构建脚本里写死的一句话,所以每个版本的提示都长得一模一样,
 * 用户根本看不出这版改了什么 —— 改成自动提取后,只要更新日志写好了,
 * 简介就跟着变,不用再手动改构建配置。
 */
function pickReleaseNote(ver) {
  try {
    const p = path.join(repoRoot, 'Beta', 'changelog-Beta.html');
    if (!fs.existsSync(p)) return null;
    const html = fs.readFileSync(p, 'utf8');

    const start = html.indexOf('var CHANGES = [');
    if (start < 0) return null;
    const arrStart = html.indexOf('[', start);
    let depth = 0, arrEnd = -1;
    for (let i = arrStart; i < html.length; i++) {
      if (html[i] === '[') depth++;
      else if (html[i] === ']') { depth--; if (depth === 0) { arrEnd = i; break; } }
    }
    if (arrEnd < 0) return null;

    const list = JSON.parse(html.slice(arrStart, arrEnd + 1));
    const item = list.find(x => String(x.ver) === String(ver) && (x.type === 'app' || !x.type));
    if (!item || !Array.isArray(item.lines) || !item.lines.length) return null;

    // 去掉开头的序号(一、/1.)与 emoji
    const clean = (s) => String(s || '')
      .replace(/^[一二三四五六七八九十\d]+\s*[、.．]\s*/, '')
      .replace(/^[^\p{L}\p{N}]+/u, '')
      .trim();

    const title = clean(item.lines[0]);
    let sub = '';
    for (let i = 1; i < item.lines.length; i++) {
      const t = String(item.lines[i] || '');
      if (/^[一二三四五六七八九十]\s*[、.]/.test(t)) { sub = clean(t); break; }
    }
    // 小标题和总标题意思重复时(如「APP 内下载与自动更新 · APP 内下载」)只留总标题
    const dup = sub && (title.includes(sub) || sub.includes(title) ||
      (sub.length >= 2 && title.includes(sub.slice(0, 2))));
    if (dup) sub = '';
    let note = sub ? (title + ' · ' + sub) : title;
    if (note.length > 48) note = note.slice(0, 47) + '…';
    return note || null;
  } catch (e) {
    return null;
  }
}

const autoNote = pickReleaseNote(versionName);
const note = autoNote || process.env.APP_RELEASE_NOTE || '修复与优化,详见更新日志';
if (autoNote) log(`✅ 更新简介(取自更新日志 v${versionName}): ${note}`);
else log(`⚠️ 更新日志里没找到 v${versionName} 的条目,使用兜底简介: ${note}`);

const versionFile = path.join(siteDir, 'version.json');
fs.writeFileSync(versionFile, JSON.stringify({
  version: parseInt(versionCode, 10),
  versionName: versionName,
  url: 'https://github.nb-channel.top/download/NBChannel.apk',
  apkSize: '约 3.6MB',
  note: note,
  updatedAt: new Date().toISOString().slice(0, 10),
}, null, 2), 'utf8');
log(`✅ 已生成 version.json → ${versionFile}`);

console.log('\n注入完成,可以开始构建了。');
