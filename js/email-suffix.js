/* ============================================================
   邮箱后缀选择器（登录 / 注册 / 绑定通用）
   ------------------------------------------------------------
   作用：把「一个输入框填完整邮箱」改成「用户名 + 下拉选后缀」
        · 只能选常见邮箱后缀，不能自己写
        · 前端拼出完整邮箱后，照旧交给原来的流程
   用法：
     1) 页面引入本文件
     2) 在原有输入框上不用改 HTML，脚本会自动改造
     3) 读值：NBMail.value('regEmail')
   ============================================================ */
(function () {
    var SUFFIXES = [
        'qq.com', 'foxmail.com', 'vip.qq.com',
        '163.com', '126.com', 'yeah.net', '188.com',
        '139.com', '189.cn', '21cn.com',
        'sina.com', 'sina.cn', 'sohu.com', 'tom.com', '263.net',
        'aliyun.com', 'china.com',
        'outlook.com', 'hotmail.com', 'live.com', 'msn.com',
        'gmail.com', 'icloud.com', 'me.com',
        'yahoo.com', 'yahoo.com.cn', 'proton.me'
    ];

    var IDS = ['regEmail', 'bindEmail', 'loginEmail'];

    function build(id) {
        var input = document.getElementById(id);
        if (!input || input.getAttribute('data-nbmail') === '1') return;
        input.setAttribute('data-nbmail', '1');
        input.setAttribute('placeholder', '邮箱用户名（@ 前面那部分）');
        input.setAttribute('autocomplete', 'off');
        input.style.flex = '1';

        var sel = document.createElement('select');
        sel.id = id + 'Suffix';
        sel.style.cssText = 'margin-left:8px;padding:0 10px;height:100%;min-height:44px;border-radius:10px;' +
            'border:1px solid rgba(140,160,190,.35);background:transparent;color:inherit;font-size:.92rem;font-family:inherit;';
        SUFFIXES.forEach(function (d) {
            var o = document.createElement('option');
            o.value = d;
            o.textContent = '@' + d;
            sel.appendChild(o);
        });

        // 放进原来的包裹层，保证样式一致
        var wrap = input.parentNode;
        wrap.style.display = 'flex';
        wrap.style.alignItems = 'center';
        wrap.appendChild(sel);
    }

    function value(id) {
        var input = document.getElementById(id);
        if (!input) return '';
        var u = (input.value || '').trim();
        if (!u) return '';
        // 如果用户直接粘贴了完整邮箱，拆出 @ 前部分
        if (u.indexOf('@') >= 0) u = u.split('@')[0];
        var sel = document.getElementById(id + 'Suffix');
        var suffix = sel ? sel.value : 'qq.com';
        return u + '@' + suffix;
    }

    function valid(id) {
        var input = document.getElementById(id);
        if (!input) return false;
        var u = (input.value || '').trim().split('@')[0];
        return /^[A-Za-z0-9._-]{2,32}$/.test(u);
    }

    function init() {
        IDS.forEach(build);
    }

    window.NBMail = { init: init, value: value, valid: valid, SUFFIXES: SUFFIXES };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    setTimeout(init, 400);   // 表单若是后渲染的，再补一次
})();
