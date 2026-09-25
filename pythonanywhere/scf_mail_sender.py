# -*- coding: utf-8 -*-
# NB频道 邮箱验证码发信器 · 腾讯云 SCF Web函数版(与线上部署一致)
# 部署:SCF「Web函数」+ 函数URL,入口 app.py,scf_bootstrap 启动 Flask 监听 9000
# 流程:浏览器 POST → SCF:校验+生成验证码+存Supabase(限频)+163SMTP发信
# 环境变量(函数配置里填):
#   EMAIL_ADDR = nbchannel@163.com       发件邮箱
#   EMAIL_AUTH = 163 SMTP 授权码
#   SUPA_URL   = https://pbaafgjkwdbwcmsikcmg.supabase.co
#   SUPA_KEY   = anon key(防轰炸靠 DB 限频 + 本函数内存限频)
#
# ============================================================
# v2 (2026-09-25) 新增 Origin 白名单
# ------------------------------------------------------------
# 原因:函数 URL 是公开的,任何网站都能直接调用它来消耗 163 邮箱额度。
#       已发现 utw.pages.dev 的 script.js 里带有 setInterval(...,1000)
#       持续调用本函数的代码(其注释自述为"浪费NB频道邮箱额度")。
# 规则:请求头 Origin 存在且不在白名单内 → 直接 403,不发信、不写库。
#       浏览器不允许 JS 伪造 Origin,所以对方无法绕过。
# 注意:这只挡浏览器。服务端代理调用不带 Origin,靠 DB 层的
#       每 IP 20 封/天 + 全站 200 封/天(sql/URGENT4)兜底。
# ============================================================
import json
import os
import hashlib
import random
import time
import smtplib
import ssl
import urllib.request
from flask import Flask, request, jsonify

app = Flask(__name__)

# ---------- Origin 白名单 ----------
# 只允许 NB频道 自己的域名调用本函数。
ALLOWED_ORIGINS = {
    'https://nb-channel.top',
    'https://www.nb-channel.top',
    'https://github.nb-channel.top',
    'https://cloudflare.nb-channel.top',
    'https://pythonanywhere.nb-channel.top',
    'https://api.nb-channel.top',
}
# 完全没有 Origin 头的请求(服务端脚本、curl、探活)是否放行。
# 保持 True:否则你自己的自动化脚本会挂。
ALLOW_EMPTY_ORIGIN = True
# Origin: null 是否放行。浏览器从硬盘直接打开 HTML(file://)时会发 null,
# 但沙箱 iframe / data: 页面也会发 null,存在被绕过的可能,所以默认 False。
# 若你需要在本地双击 HTML 文件调试,把它改成 True。
ALLOW_NULL_ORIGIN = False

# 被拦记录(仅用于日志观测,进程重启即清零)
_blocked = {'n': 0}


def _origin_allowed(origin):
    if not origin:
        return ALLOW_EMPTY_ORIGIN
    if origin == 'null':
        return ALLOW_NULL_ORIGIN
    return origin in ALLOWED_ORIGINS

# ---------- 内存限频(进程内;配合 Supabase store_email_code 的限频双保险) ----------
_rt = {}
_rt_ts = {}


def _rt_check(key, limit, window):
    now = time.time()
    if _rt_ts.get(key, 0) < now - window:
        _rt[key] = 0
        _rt_ts[key] = now
    _rt[key] = _rt.get(key, 0) + 1
    return _rt[key] <= limit


def supa_rpc(fn, params):
    url = os.environ.get('SUPA_URL', '').rstrip('/')
    key = os.environ.get('SUPA_KEY', '')
    if not url or not key:
        return {'ok': False, 'message': 'SUPA_URL/SUPA_KEY 未配置'}
    req = urllib.request.Request(
        url + '/rest/v1/rpc/' + fn,
        data=json.dumps(params).encode('utf-8'),
        headers={'apikey': key, 'Authorization': 'Bearer ' + key,
                 'Content-Type': 'application/json'},
        method='POST')
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            body = r.read().decode('utf-8', 'ignore')
            return {'ok': True, 'data': json.loads(body) if body.strip() else None}
    except urllib.error.HTTPError as e:
        detail = e.read().decode('utf-8', 'ignore')[:300]
        return {'ok': False, 'message': 'HTTP %s: %s' % (e.code, detail)}
    except Exception as e:
        return {'ok': False, 'message': str(e)}


def build_otp_html(code, minutes=10):
    """品牌化 HTML 邮件(内联样式,兼容 QQ/163 邮箱)"""
    return '''<div style="background:#f5f7fa;padding:28px 12px;font-family:-apple-system,'PingFang SC','Microsoft YaHei',sans-serif;">
  <div style="max-width:520px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 6px 24px rgba(16,24,40,.08);">
    <div style="background:linear-gradient(135deg,#3b82f6,#6366f1);padding:22px 28px;color:#ffffff;">
      <div style="font-size:19px;font-weight:800;letter-spacing:1px;">NB频道</div>
      <div style="font-size:12px;opacity:.88;margin-top:5px;letter-spacing:3px;">NB CHANNEL · 账号安全</div>
    </div>
    <div style="padding:30px 28px 26px;">
      <div style="font-size:16px;color:#1a1d23;font-weight:700;">你的邮箱验证码</div>
      <div style="font-size:13px;color:#5a6270;line-height:1.9;margin-top:8px;">请在登录 / 注册页面输入下面的验证码完成验证:</div>
      <div style="margin:24px 0;text-align:center;">
        <div style="display:inline-block;background:#f1f5ff;border:1px dashed #93b4ff;border-radius:14px;padding:16px 30px;">
          <span style="font-size:34px;font-weight:900;letter-spacing:9px;color:#2563eb;">''' + code + '''</span>
        </div>
      </div>
      <div style="font-size:13px;color:#5a6270;line-height:2;">
        · 验证码 <b>''' + str(minutes) + ''' 分钟内</b>有效,过期请重新获取<br>
        · 请勿把验证码告诉任何人(包括自称客服的人)<br>
        · 如果这不是你本人的操作,忽略本邮件即可
      </div>
      <div style="margin-top:22px;padding-top:18px;border-top:1px solid #e8eaee;font-size:12px;color:#8b93a3;line-height:1.9;">
        本邮件由系统自动发送,请勿直接回复。<br>
        NB频道(NoBook频道) · 虚拟公司 · <a href="https://nb-channel.top" style="color:#3b82f6;text-decoration:none;">nb-channel.top</a>
      </div>
    </div>
  </div>
  <div style="max-width:520px;margin:14px auto 0;font-size:11px;color:#98a2b3;text-align:center;">
    © 2026 NB频道 · 制作:NB搞事局
  </div>
</div>'''


def send_mail(to_addr, code, minutes=10):
    """发送 HTML + 纯文本双格式验证码邮件"""
    addr = os.environ.get('EMAIL_ADDR', '')
    auth = os.environ.get('EMAIL_AUTH', '')
    if not addr or not auth:
        return 'EMAIL_ADDR/EMAIL_AUTH 未配置'
    from email.mime.multipart import MIMEMultipart
    from email.mime.text import MIMEText
    from email.header import Header
    from email.utils import formataddr
    text = ('你的 NB频道 登录/注册验证码是: %s\n'
            '有效 %d 分钟,请勿告诉任何人。\n'
            '如果这不是你本人的操作,请忽略本邮件。\n'
            '—— NB频道(NB搞事局)') % (code, minutes)
    msg = MIMEMultipart('alternative')
    msg['Subject'] = Header('【NB频道】邮箱验证码 %s' % code, 'utf-8')
    msg['From'] = formataddr((str(Header('NB频道', 'utf-8')), addr))
    msg['To'] = to_addr
    msg.attach(MIMEText(text, 'plain', 'utf-8'))
    msg.attach(MIMEText(build_otp_html(code, minutes), 'html', 'utf-8'))
    try:
        ctx = ssl.create_default_context()
        with smtplib.SMTP_SSL('smtp.163.com', 465, timeout=20, context=ctx) as s:
            s.login(addr, auth)
            s.sendmail(addr, [to_addr], msg.as_string())
        return None
    except Exception as e:
        return str(e)


def masked_email(e):
    if '@' not in e:
        return e
    local, dom = e.split('@', 1)
    return local[0] + ('***' if len(local) > 1 else '*') + '@' + dom


@app.route('/', methods=['POST'])
def index():
    # ---------- Origin 白名单校验(第一道,也是最有效的一道) ----------
    origin = (request.headers.get('Origin') or '').strip()
    if not _origin_allowed(origin):
        ip0 = (request.headers.get('X-Forwarded-For') or '').split(',')[0].strip() or \
              request.headers.get('X-Real-IP') or 'unknown'
        _blocked['n'] += 1
        # 打在 SCF 日志里,方便回看是谁在盗用
        print('[BLOCKED-ORIGIN] origin=%r ip=%s ua=%r total_blocked=%d'
              % (origin, ip0, (request.headers.get('User-Agent') or '')[:120], _blocked['n']),
              flush=True)
        return jsonify({'ok': False, 'message': '来源不被允许'}), 403

    data = request.get_json(silent=True) or {}
    kind = str(data.get('kind') or '').strip().lower()
    email = str(data.get('email') or '').strip().lower()
    username = str(data.get('username') or '').strip()
    password = str(data.get('password') or '')
    ip = (request.headers.get('X-Forwarded-For') or '').split(',')[0].strip() or \
         request.headers.get('X-Real-IP') or 'unknown'
    if kind not in ('register', 'login', 'bind'):
        return jsonify({'ok': False, 'message': '未知类型'})
    code = str(random.randint(100000, 999999))
    to_addr = email
    if kind == 'login':
        r = supa_rpc('lookup_login_email', {'p_username': username, 'p_password': password})
        if not r.get('ok'):
            return jsonify({'ok': False, 'message': r.get('message', '校验失败')})
        d = r.get('data') or {}
        if not d.get('ok'):
            return jsonify({'ok': False, 'message': d.get('message') or '用户名或密码错误'})
        if d.get('need_bind'):
            return jsonify({'ok': True, 'need_bind': True})
        to_addr = d.get('email') or ''
    elif kind == 'bind':
        r = supa_rpc('lookup_login_email', {'p_username': username, 'p_password': password})
        if not r.get('ok'):
            return jsonify({'ok': False, 'message': r.get('message', '校验失败')})
        d = r.get('data') or {}
        if not d.get('ok'):
            return jsonify({'ok': False, 'message': d.get('message') or '用户名或密码错误'})
        if not d.get('need_bind'):
            return jsonify({'ok': False, 'message': '该账号已绑定邮箱'})
    if '@' not in to_addr:
        return jsonify({'ok': False, 'message': '邮箱格式不正确'})
    if not _rt_check('email:' + kind + ':' + to_addr, 1, 60):
        return jsonify({'ok': False, 'message': '发送太频繁,请 60 秒后再试'})

    r = supa_rpc('store_email_code', {
        'p_email': to_addr, 'p_purpose': kind,
        'p_code_hash': hashlib.md5(code.encode('utf-8')).hexdigest(),
        'p_ip': ip})
    if not r.get('ok'):
        return jsonify({'ok': False, 'message': r.get('message', '发送失败')})
    d = r.get('data') or {}
    if not d.get('ok'):
        return jsonify({'ok': False, 'message': d.get('message') or '发送失败'})

    err = send_mail(to_addr, code)
    if err:
        return jsonify({'ok': False, 'message': '邮件发送失败: ' + err})
    return jsonify({'ok': True, 'masked': masked_email(to_addr)})
