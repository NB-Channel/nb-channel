# -*- coding: utf-8 -*-
# NB频道 邮箱验证码发信器 · 腾讯云 SCF Web函数版(与线上部署一致)
# 部署:SCF「Web函数」+ 函数URL,入口 app.py,scf_bootstrap 启动 Flask 监听 9000
# 流程:浏览器 POST → SCF:校验+生成验证码+存Supabase(限频)+163SMTP发信
# 环境变量(函数配置里填):
#   EMAIL_ADDR = nbchannel@163.com       发件邮箱
#   EMAIL_AUTH = 163 SMTP 授权码
#   SUPA_URL   = https://pbaafgjkwdbwcmsikcmg.supabase.co
#   SUPA_KEY   = anon key(防轰炸靠 DB 限频 + 本函数内存限频)
import json
import os
import hashlib
import base64
import random
import time
import smtplib
import ssl
import urllib.request
from flask import Flask, request, jsonify

app = Flask(__name__)

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


def send_mail(to_addr, subject, text):
    addr = os.environ.get('EMAIL_ADDR', '')
    auth = os.environ.get('EMAIL_AUTH', '')
    if not addr or not auth:
        return 'EMAIL_ADDR/EMAIL_AUTH 未配置'
    msg = ('From: NB频道 <%s>\r\nTo: %s\r\n'
           'Subject: =?UTF-8?B?%s?=\r\n'
           'MIME-Version: 1.0\r\n'
           'Content-Type: text/plain; charset=utf-8\r\n'
           'Content-Transfer-Encoding: base64\r\n\r\n') % (
        addr, to_addr, base64.b64encode(subject.encode('utf-8')).decode('ascii'))
    msg += base64.b64encode(text.encode('utf-8')).decode('ascii')
    try:
        ctx = ssl.create_default_context()
        with smtplib.SMTP_SSL('smtp.163.com', 465, timeout=20, context=ctx) as s:
            s.login(addr, auth)
            s.sendmail(addr, [to_addr], msg.encode('utf-8'))
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
    data = request.get_json(silent=True) or {}
    kind = str(data.get('kind') or '').strip().lower()
    email = str(data.get('email') or '').strip().lower()
    username = str(data.get('username') or '').strip()
    password = str(data.get('password') or '')
    ip = (request.headers.get('X-Forwarded-For') or '').split(',')[0].strip() or \
         request.headers.get('X-Real-IP') or 'unknown'
    if kind not in ('register', 'login', 'bind'):
        return jsonify({'ok': False, 'message': '未知类型'})
    if not _rt_check('ip:' + ip, 5, 600):
        return jsonify({'ok': False, 'message': '操作过于频繁,请稍后再试'})
    if not _rt_check('email:' + kind + ':' + email, 3, 600):
        return jsonify({'ok': False, 'message': '该邮箱请求过于频繁,请稍后再试'})

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

    r = supa_rpc('store_email_code', {
        'p_email': to_addr, 'p_purpose': kind,
        'p_code_hash': hashlib.md5(code.encode('utf-8')).hexdigest(),
        'p_ip': ip})
    if not r.get('ok'):
        return jsonify({'ok': False, 'message': r.get('message', '发送失败')})
    d = r.get('data') or {}
    if not d.get('ok'):
        return jsonify({'ok': False, 'message': d.get('message') or '发送失败'})

    text = ('你的 NB频道 登录/注册验证码是: {code}\n'
            '有效 10 分钟,请勿告诉任何人。\n'
            '如果这不是你本人的操作,请忽略本邮件。\n'
            '—— NB频道(NB搞事局)').format(code=code)
    err = send_mail(to_addr, 'NB频道 邮箱验证码', text)
    if err:
        return jsonify({'ok': False, 'message': '邮件发送失败: ' + err})
    return jsonify({'ok': True, 'masked': masked_email(to_addr)})
