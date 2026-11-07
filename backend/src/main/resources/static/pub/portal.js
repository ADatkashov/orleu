/* Customer portal: phone -> SMS code -> my bookings (view, cancel). All dynamic text goes through textContent (OrleuUI.h), never innerHTML.
   The session token lives in sessionStorage only (gone when the tab closes) and is sent in the X-Portal-Token header. */
(function () {
  const { h, t, langSwitch, money, api, errText, getLang } = window.OrleuUI;
  const slug = document.body.dataset.slug;
  const root = document.getElementById('app');
  const base = `/api/v1/public/businesses/${encodeURIComponent(slug)}/portal`;
  let token = null, me = null, phone = '', codeSent = false, error = '', message = '', busy = false;
  try { token = sessionStorage.getItem('orleu.portal.' + slug); } catch (e) {}
  const fmt = (iso) => new Intl.DateTimeFormat(getLang(), { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(iso));
  const auth = () => ({ headers: { 'Content-Type': 'application/json', 'X-Portal-Token': token || '' } });

  function setToken(v) { token = v; try { v ? sessionStorage.setItem('orleu.portal.' + slug, v) : sessionStorage.removeItem('orleu.portal.' + slug); } catch (e) {} }

  async function sendCode() {
    busy = true; error = ''; message = ''; render();
    try { await api(base + '/code', { method: 'POST', body: JSON.stringify({ phone }) }); codeSent = true; message = t('pCodeSent'); }
    catch (e) { error = errText(e); }
    busy = false; render();
  }
  async function verify(code) {
    busy = true; error = ''; message = ''; render();
    try {
      const s = await api(base + '/verify', { method: 'POST', body: JSON.stringify({ phone, code }) });
      setToken(s.token); await load();
    } catch (e) { error = e.code === 'INVALID_CODE' ? t('pBadCode') : errText(e); }
    busy = false; render();
  }
  async function load() {
    try { me = await api(base + '/me', auth()); }
    catch (e) { setToken(null); me = null; if (e.status === 401) error = t('pSessionEnded'); else error = errText(e); }
  }
  async function cancel(id) {
    if (!confirm(t('mCancelConfirm'))) return;
    busy = true; error = ''; render();
    try { await api(`${base}/bookings/${encodeURIComponent(id)}/cancel`, Object.assign({ method: 'POST' }, auth())); message = t('mCancelled'); await load(); }
    catch (e) { error = e.code === 'CANCELLATION_NOT_ALLOWED' ? t('mTooLate') : e.status === 401 ? t('pSessionEnded') : errText(e); }
    busy = false; render();
  }
  async function logout() {
    try { await api(base + '/logout', Object.assign({ method: 'POST' }, auth())); } catch (e) {}
    setToken(null); me = null; codeSent = false; message = ''; error = ''; render();
  }

  function signIn() {
    const codeInput = h('input', { id: 'p-code', inputmode: 'numeric', autocomplete: 'one-time-code', maxlength: '6', 'data-testid': 'code', 'aria-label': t('pCode') });
    return h('div', { class: 'card' },
      h('label', {}, t('phone'), h('input', { id: 'p-phone', type: 'tel', autocomplete: 'tel', value: phone, 'data-testid': 'phone', oninput: (e) => { phone = e.target.value; } })),
      h('button', { class: 'btn', type: 'button', disabled: busy, 'data-testid': 'send-code', onclick: sendCode }, t('pSendCode')),
      codeSent && h('label', {}, t('pCode'), codeInput),
      codeSent && h('button', { class: 'btn', type: 'button', disabled: busy, 'data-testid': 'verify', onclick: () => verify(codeInput.value) }, t('pSignIn')));
  }

  function bookings() {
    if (!me.bookings.length) return h('p', { class: 'muted' }, t('pNone'));
    return me.bookings.map((b) => h('div', { class: 'card', 'data-testid': 'booking' },
      h('div', { class: 'row' }, h('b', {}, b.serviceName), h('span', {}, t('st_' + b.status))),
      h('div', { class: 'muted' }, fmt(b.startsAt) + ' · ' + b.employeeName),
      h('div', { class: 'muted' }, money(b.price, b.currency)),
      b.canCancel && h('button', { class: 'btn danger', type: 'button', disabled: busy, 'data-testid': 'cancel', onclick: () => cancel(b.id) }, t('mCancel'))));
  }

  function render() {
    document.documentElement.lang = getLang();
    root.replaceChildren(...[
      h('div', { class: 'brand' }, h('b', {}, 'ORLEU'), langSwitch(render)),
      h('h1', {}, t('pTitle')),
      me && h('p', { class: 'muted' }, me.businessName + ' · ' + me.fullName),
      message && h('p', { class: 'ok', 'data-testid': 'msg' }, message),
      error && h('p', { class: 'err', role: 'alert', 'data-testid': 'err' }, error),
      me ? bookings() : signIn(),
      me && h('button', { class: 'btn', type: 'button', 'data-testid': 'logout', onclick: logout }, t('pSignOut')),
      h('p', { class: 'small muted' }, h('a', { href: `/b/${encodeURIComponent(slug)}` }, t('pBook')))].flat().filter(Boolean));
  }

  (async function init() { if (token) await load(); render(); })();
})();
