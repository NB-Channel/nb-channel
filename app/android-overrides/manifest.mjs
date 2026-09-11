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
const PERMS = [
  'android.permission.POST_NOTIFICATIONS',
  'android.permission.FOREGROUND_SERVICE',
  'android.permission.FOREGROUND_SERVICE_SPECIAL_USE',
];
for (const p of PERMS) {
  if (!m.includes(p)) {
    m = m.replace(/<application/, `<uses-permission android:name="${p}" />\n    <application`);
    changed++;
  }
}

// ② 兜底任务(JobScheduler,最短 15 分钟)
if (!m.includes('NotifyJobService')) {
  m = m.replace(/<\/application>/,
    '        <service android:name=".NotifyJobService"\n' +
    '            android:permission="android.permission.BIND_JOB_SERVICE"\n' +
    '            android:exported="true" />\n' +
    '    </application>');
  changed++;
}

// ③ 实时提醒前台服务(每 30 秒查一次;Android 14+ 必须声明类型)
if (!m.includes('NotifyForegroundService')) {
  m = m.replace(/<\/application>/,
    '        <service android:name=".NotifyForegroundService"\n' +
    '            android:exported="false"\n' +
    '            android:foregroundServiceType="specialUse">\n' +
    '            <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"\n' +
    '                android:value="保持消息提醒的定时检查" />\n' +
    '        </service>\n' +
    '    </application>');
  changed++;
}

if (changed) {
  fs.writeFileSync(manifestPath, m, 'utf8');
  console.log(`✅ AndroidManifest 注入 ${changed} 项(通知权限 + 兜底任务 + 实时提醒服务)`);
} else {
  console.log('ℹ️ AndroidManifest 已是最新,跳过');
}
