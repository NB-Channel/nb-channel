// 往 AndroidManifest 里补「通知权限 + 后台任务 Service」
// 必须在 `npx cap sync android` 【之后】执行,否则会被 sync 覆盖掉。
// (apply.mjs 里的权限注入跑在 sync 之前,只负责下载相关的权限)
import fs from 'node:fs';
import path from 'node:path';

const APP = path.join(process.cwd(), 'android', 'app');
const manifestPath = path.join(APP, 'src', 'main', 'AndroidManifest.xml');

if (!fs.existsSync(manifestPath)) {
  console.error('❌ 找不到 AndroidManifest.xml: ' + manifestPath);
  process.exit(1);
}

let m = fs.readFileSync(manifestPath, 'utf8');
let changed = 0;

// ① Android 13+ 发通知需要这个权限(运行时还会再申请一次)
const PERM = 'android.permission.POST_NOTIFICATIONS';
if (!m.includes(PERM)) {
  m = m.replace(/<application/, `<uses-permission android:name="${PERM}" />\n    <application`);
  changed++;
}

// ② 注册后台消息检查任务(JobScheduler 用)
if (!m.includes('NotifyJobService')) {
  m = m.replace(/<\/application>/,
    '        <service android:name=".NotifyJobService"\n' +
    '            android:permission="android.permission.BIND_JOB_SERVICE"\n' +
    '            android:exported="true" />\n' +
    '    </application>');
  changed++;
}

if (changed) {
  fs.writeFileSync(manifestPath, m, 'utf8');
  console.log(`✅ AndroidManifest 注入 ${changed} 项(通知权限 + 后台任务 Service)`);
} else {
  console.log('ℹ️ AndroidManifest 已是最新,跳过');
}
