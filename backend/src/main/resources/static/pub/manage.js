(function () {
  const { h, t, langSwitch, money, api, errText, getLang } = window.OrleuUI;
  const token = document.body.dataset.token;
  const root = document.getElementById('app');
  let view = null, message = '', error = '', busy = false, stars = 0, comment = '';
  const fmt = (iso) => new Intl.DateTimeFormat(getLang(), { dateStyle: 'full', timeStyle: 'short' }).format(new Date(iso));

  async function cancel() {
    if (!confirm(t('mCancelConfirm'))) return;
    busy = true; error = ''; render();
    try { view = await api(`/api/v1/public/manage/${encodeURIComponent(token)}/cancel`, { method: 'POST' }); message = t('mCancelled'); }
    catch (e) { error = e.code === 'CANCELLATION_NOT_ALLOWED' ? t('mTooLate') : errText(e); }
    busy = false; render();
  }
  async function sendReview() {
    if (!stars) return;
    busy = true; error = ''; render();
    try {
      await api(`/api/v1/public/manage/${encodeURIComponent(token)}/review`, { method: 'POST', body: JSON.stringify({ rating: stars, comment: comment.trim() || null }) });
      view = await api(`/api/v1/public/manage/${encodeURIComponent(token)}`); message = t('rateThanks');
    } catch (e) { error = e.code === 'ALREADY_REVIEWED' ? t('errAlreadyReviewed') : e.code === 'REVIEW_NOT_ALLOWED' ? t('errReviewNotAllowed') : errText(e); }
    busy = false; render();
  }
  function reviewBox() {
    if (view.reviewRating) return h('p', { 'data-testid': 'your-rating' }, t('rateYours') + ': ' + '★'.repeat(view.reviewRating) + '☆'.repeat(5 - view.reviewRating));
    if (!view.canReview) return null;
    return h('div', { class: 'card', 'data-testid': 'review-box' },
      h('h2', {}, t('rateTitle')),
      h('div', { class: 'stars', role: 'group', 'aria-label': t('rateTitle') },
        [1, 2, 3, 4, 5].map((n) => h('button', { type: 'button', class: 'btn', 'aria-pressed': String(stars === n), 'aria-label': n + ' ' + t('rateStar'), 'data-testid': 'star-' + n,
          onclick: () => { stars = n; render(); } }, n <= stars ? '★' : '☆'))),
      h('label', {}, t('rateComment'), h('textarea', { rows: 3, maxlength: 1000, 'data-testid': 'comment', oninput: (e) => { comment = e.target.value; } }, comment)),
      h('button', { class: 'btn', type: 'button', disabled: busy || !stars, 'data-testid': 'send-review', onclick: sendReview }, t('rateSend')));
  }
  function render() {
    document.documentElement.lang = getLang();
    if (!view) return;
    const row = (k, v) => h('div', { class: 'row' }, h('span', { class: 'muted' }, k), h('span', {}, v));
    // replaceChildren stringifies `false`/null, so falsy entries are dropped explicitly
    root.replaceChildren(...[
      h('div', { class: 'brand' }, h('b', {}, 'ORLEU'), langSwitch(render)),
      h('h1', {}, t('mTitle')), h('p', { class: 'muted' }, view.businessName),
      h('div', { class: 'card' },
        row(t('service'), view.serviceName), row(t('when'), fmt(view.startsAt)),
        row(t('status'), t('st_' + view.status)), row(t('price'), money(view.price, view.currency)),
        Number(view.depositAmount) > 0 && row(t('deposit'), money(view.depositAmount, view.currency)),
        row(t('remaining'), money(view.remainingBalance, view.currency))),
      message && h('p', { class: 'ok', 'data-testid': 'msg' }, message),
      error && h('p', { class: 'err', role: 'alert', 'data-testid': 'err' }, error),
      reviewBox(),
      view.canCancel && h('button', { class: 'btn danger', type: 'button', disabled: busy, 'data-testid': 'cancel', onclick: cancel }, t('mCancel')),
      !view.canCancel && view.status !== 'CANCELLED' && ['PENDING', 'CONFIRMED', 'AWAITING_PAYMENT'].includes(view.status) &&
        h('p', { class: 'small muted' }, t('mTooLate'))].filter(Boolean));
  }
  (async function init() {
    try { view = await api(`/api/v1/public/manage/${encodeURIComponent(token)}`); render(); }
    catch (e) { root.replaceChildren(h('p', { class: 'err', role: 'alert' }, errText(e))); }
  })();
})();
