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

// ---------- ① 覆盖 MainActivity ----------
const overrides = path.join(process.cwd(), 'android-overrides', 'MainActivity.java');
if (!fs.existsSync(overrides)) {
  console.error('❌ 找不到 android-overrides/MainActivity.java');
  process.exit(1);
}
fs.mkdirSync(pkgPath, { recursive: true });
fs.copyFileSync(overrides, path.join(pkgPath, 'MainActivity.java'));
log(`✅ MainActivity 已替换(下载接管 + 自动安装) → ${path.relative(process.cwd(), pkgPath)}`);

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
const siteDir = path.join(process.cwd(), 'download');
fs.mkdirSync(siteDir, { recursive: true });
fs.writeFileSync(path.join(siteDir, 'version.json'), JSON.stringify({
  version: parseInt(versionCode, 10),
  versionName: versionName,
  url: 'https://github.nb-channel.top/download/NBChannel.apk',
  apkSize: '约 5MB',
  note: process.env.APP_RELEASE_NOTE || '修复与优化',
  updatedAt: new Date().toISOString().slice(0, 10),
}, null, 2), 'utf8');
log('✅ 已生成 download/version.json(APP 启动时用它比对版本)');

console.log('\n注入完成,可以开始构建了。');
