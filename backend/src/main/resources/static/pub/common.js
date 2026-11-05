/* Tiny DOM helpers. All dynamic text goes through textContent - never innerHTML - so business/customer data cannot inject markup. */
(function () {
  const I = window.ORLEU_I18N;
  const supported = ['kk', 'ru', 'en'];
  let lang = (new URLSearchParams(location.search).get('lang') || localStorage.getItem('orleu.lang') || navigator.language || 'en').slice(0, 2).toLowerCase();
  if (!supported.includes(lang)) lang = 'en';

  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v === false || v == null) continue;
      if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
      else if (k === 'class') el.className = v;
      else el.setAttribute(k, v === true ? '' : v);
    }
    for (const kid of kids.flat()) if (kid != null && kid !== false) el.append(kid.nodeType ? kid : document.createTextNode(String(kid)));
    return el;
  }
  const t = (k) => (I[lang] && I[lang][k]) || I.en[k] || k;
  function setLang(l, rerender) { lang = l; try { localStorage.setItem('orleu.lang', l); } catch (e) {} document.documentElement.lang = l; rerender(); }
  function langSwitch(rerender) {
    return h('div', { class: 'lang', role: 'group', 'aria-label': 'Language' },
      supported.map((l) => h('button', { type: 'button', 'aria-pressed': String(l === lang), onclick: () => setLang(l, rerender) }, l.toUpperCase())));
  }
  function money(v, cur) {
    const n = Number(v);
    return new Intl.NumberFormat(lang, { style: 'currency', currency: cur, maximumFractionDigits: Number.isInteger(n) ? 0 : 2 }).format(n);
  }
  async function api(path, opts) {
    let res;
    try { res = await fetch(path, Object.assign({ headers: { 'Content-Type': 'application/json' } }, opts)); }
    catch (e) { throw { code: 'NETWORK', status: 0 }; }
    let body = null;
    try { body = await res.json(); } catch (e) {}
    if (!res.ok) throw { code: (body && body.code) || 'HTTP_' + res.status, status: res.status, body };
    return body;
  }
  function errText(e) {
    if (e.code === 'SLOT_UNAVAILABLE') return t('errSlot');
    if (e.status === 404) return t('errNotFound');
    if (e.status === 429) return t('errRate');
    if (e.status === 403) return t('errBlocked');
    return t('errGeneric');
  }
  window.OrleuUI = { h, t, langSwitch, money, api, errText, getLang: () => lang };
})();
