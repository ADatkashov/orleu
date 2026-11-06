(function () {
  const { h, t, langSwitch, money, api, errText, getLang } = window.OrleuUI;
  const slug = document.body.dataset.slug;
  const root = document.getElementById('app');
  const S = { profile: null, step: 1, service: null, branch: null, employee: null /* null = any */, date: null, slots: null, slot: null,
    name: '', phone: '', email: '', marketing: false, promoInput: '', promo: null, error: '', busy: false, result: null };

  const PHONE = /^\+[1-9]\d{7,14}$/;
  function normPhone(raw) {
    let d = raw.replace(/[\s\-()]/g, '');
    if (/^8\d{10}$/.test(d)) d = '+7' + d.slice(1);
    else if (/^7\d{10}$/.test(d)) d = '+' + d;
    return d;
  }
  const tz = () => (S.branch && S.branch.timezone) || S.profile.timezone;
  const fmtTime = (iso) => new Intl.DateTimeFormat(getLang(), { hour: '2-digit', minute: '2-digit', timeZone: tz() }).format(new Date(iso));
  const fmtDateTime = (iso) => new Intl.DateTimeFormat(getLang(), { dateStyle: 'full', timeStyle: 'short', timeZone: tz() }).format(new Date(iso));

  function eligibleEmployees(branchId) {
    return S.profile.employees.filter((e) => e.serviceIds.includes(S.service.id) && (!branchId || e.branchIds.includes(branchId)));
  }
  function eligibleBranches() {
    const ids = new Set(eligibleEmployees().flatMap((e) => e.branchIds));
    return S.profile.branches.filter((b) => ids.has(b.id));
  }
  function dateOptions() {
    const today = new Intl.DateTimeFormat('en-CA', { timeZone: tz() }).format(new Date()); // YYYY-MM-DD in branch tz
    const [y, m, d] = today.split('-').map(Number);
    return Array.from({ length: 14 }, (_, i) => {
      const dt = new Date(Date.UTC(y, m - 1, d + i, 12));
      return { value: dt.toISOString().slice(0, 10), label: new Intl.DateTimeFormat(getLang(), { weekday: 'short', day: 'numeric', month: 'short', timeZone: 'UTC' }).format(dt) };
    });
  }
  async function loadSlots() {
    S.slots = null; S.slot = null; render();
    const q = new URLSearchParams({ branchId: S.branch.id, serviceId: S.service.id, date: S.date });
    if (S.employee) q.set('employeeId', S.employee.id);
    try { S.slots = await api(`/api/v1/public/businesses/${encodeURIComponent(slug)}/availability?${q}`); S.error = ''; }
    catch (e) { S.slots = []; S.error = errText(e); }
    render();
  }
  const go = (n) => {
    S.step = n; S.error = ''; window.scrollTo(0, 0);
    if (n === 3 && !S.date) { S.date = dateOptions()[0].value; return loadSlots(); }
    render();
  };

  function header() {
    const total = 5;
    return [
      h('div', { class: 'brand' }, h('b', {}, 'ORLEU'), langSwitch(render)),
      h('h1', {}, S.profile.name),
      S.profile.reviewCount > 0 && h('p', { class: 'muted small', 'data-testid': 'rating' }, '★ ' + Number(S.profile.averageRating).toFixed(1) + ' (' + S.profile.reviewCount + ' ' + t('reviewsCount') + ')'),
      S.profile.description && h('p', { class: 'muted' }, S.profile.description),
      [S.profile.city, S.profile.address].filter(Boolean).length > 0 && h('p', { class: 'muted small' }, [S.profile.city, S.profile.address].filter(Boolean).join(', ')),
      S.step <= total && !S.result && h('div', { class: 'steps', role: 'progressbar', 'aria-valuemin': 1, 'aria-valuemax': total, 'aria-valuenow': S.step, 'aria-label': t('step') },
        Array.from({ length: total }, (_, i) => h('i', { class: i < S.step ? 'on' : '' }))),
    ];
  }
  const backBtn = (n) => h('button', { class: 'btn ghost', type: 'button', onclick: () => go(n) }, t('back'));
  const err = () => S.error && h('p', { class: 'err', role: 'alert' }, S.error);

  function stepService() {
    return [h('h2', {}, t('chooseService')), S.profile.services.map((s) =>
      h('button', { class: 'opt', type: 'button', 'data-testid': 'service', onclick: () => {
        S.service = s; S.employee = null; S.date = null; S.slot = null; S.slots = null;
        const bs = eligibleBranches();
        S.branch = bs.length === 1 ? bs[0] : null;
        // skip the "who" step only when there is nothing to choose (one branch, at most one specialist)
        go(S.branch && eligibleEmployees(S.branch.id).length <= 1 ? 3 : 2);
      } },
      h('div', { class: 'row' }, h('strong', {}, s.name), h('span', { class: 'price' }, money(s.price, S.profile.currency))),
      h('div', { class: 'muted small' }, `${s.durationMinutes} min` + (s.category ? ' · ' + s.category : ''))))];
  }
  function stepWho() {
    const bs = eligibleBranches();
    const emps = S.branch ? eligibleEmployees(S.branch.id) : [];
    return [
      bs.length > 1 && h('h2', {}, t('chooseBranch')),
      bs.length > 1 && bs.map((b) => h('button', { class: 'opt', type: 'button', 'aria-pressed': String(S.branch && S.branch.id === b.id), onclick: () => { S.branch = b; S.employee = null; render(); } },
        h('strong', {}, b.name), b.address && h('div', { class: 'muted small' }, b.address))),
      S.branch && h('h2', {}, t('chooseMaster')),
      S.branch && h('button', { class: 'opt', type: 'button', 'data-testid': 'any-master', onclick: () => { S.employee = null; go(3); } }, t('anyMaster')),
      S.branch && emps.map((e) => h('button', { class: 'opt', type: 'button', onclick: () => { S.employee = e; go(3); } }, e.displayName)),
      backBtn(1),
    ];
  }
  function stepWhen() {
    return [
      h('h2', {}, t('chooseDate')),
      h('div', { class: 'chips', role: 'group' }, dateOptions().map((d) =>
        h('button', { class: 'chip', type: 'button', 'aria-pressed': String(S.date === d.value), onclick: () => { S.date = d.value; loadSlots(); } }, d.label))),
      h('h2', {}, t('chooseTime')),
      S.slots === null ? h('p', { class: 'muted' }, '…') :
        S.slots.length === 0 ? h('p', { class: 'muted', 'data-testid': 'no-slots' }, t('noSlots')) :
        h('div', { class: 'slots' }, S.slots.map((sl) => h('button', { class: 'chip', type: 'button', 'data-testid': 'slot', 'aria-pressed': String(S.slot && S.slot.start === sl.start),
          onclick: () => { S.slot = sl; render(); } }, fmtTime(sl.start)))),
      err(),
      h('button', { class: 'btn', type: 'button', disabled: !S.slot, 'data-testid': 'to-details', onclick: () => go(4) }, t('next')),
      backBtn(eligibleBranches().length > 1 || eligibleEmployees(S.branch.id).length > 1 ? 2 : 1),
    ];
  }
  function stepDetails() {
    const val = () => {
      S.name = document.getElementById('f-name').value.trim();
      S.phone = normPhone(document.getElementById('f-phone').value);
      S.email = document.getElementById('f-email').value.trim();
      S.marketing = document.getElementById('f-mk').checked;
    };
    return [
      h('h2', {}, t('yourDetails')),
      h('label', { for: 'f-name' }, t('name')), h('input', { id: 'f-name', type: 'text', autocomplete: 'name', value: S.name, maxlength: 200 }),
      h('label', { for: 'f-phone' }, t('phone')), h('input', { id: 'f-phone', type: 'tel', autocomplete: 'tel', inputmode: 'tel', value: S.phone }),
      h('label', { for: 'f-email' }, t('email')), h('input', { id: 'f-email', type: 'email', autocomplete: 'email', value: S.email, maxlength: 254 }),
      h('label', { class: 'check' }, h('input', { id: 'f-mk', type: 'checkbox', checked: S.marketing }), t('marketing')),
      err(),
      h('button', { class: 'btn', type: 'button', 'data-testid': 'to-review', onclick: () => {
        val();
        if (!S.name) S.error = t('errName');
        else if (!PHONE.test(S.phone)) S.error = t('errPhone');
        else if (S.email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(S.email)) S.error = t('errEmail');
        else return go(5);
        render();
      } }, t('next')),
      h('button', { class: 'btn ghost', type: 'button', onclick: () => { val(); go(3); } }, t('back')),
    ];
  }
  function depositFor() {
    // effective percent = service override, else business default. The server recomputes and returns the authoritative amount.
    return Number(S.service.depositPercent != null ? S.service.depositPercent : (S.profile.depositPercent || 0));
  }
  function stepReview() {
    const pct = depositFor();
    const price = S.promo ? Number(S.promo.price) : Number(S.service.price);
    const dep = S.promo ? Number(S.promo.depositAmount) : (pct ? Math.round(price * pct) / 100 : null);
    const row = (k, v) => h('div', { class: 'row' }, h('span', { class: 'muted' }, k), h('span', {}, v));
    return [
      h('h2', {}, t('review')),
      h('div', { class: 'card' },
        row(t('service'), S.service.name), row(t('where'), S.branch.name),
        row(t('who'), S.employee ? S.employee.displayName : t('anyMaster')),
        row(t('when'), fmtDateTime(S.slot.start)),
        S.promo ? row(t('discount'), '−' + money(S.promo.discount, S.profile.currency)) : null,
        row(t('price'), money(price, S.profile.currency)),
        dep ? row(t('deposit'), money(dep, S.profile.currency)) : null),
      h('div', { class: 'row' },
        h('input', { type: 'text', 'data-testid': 'promo', maxlength: 32, placeholder: t('promo'), value: S.promoInput, 'aria-label': t('promo'),
          oninput: (ev) => { S.promoInput = ev.target.value; } }),
        h('button', { class: 'btn ghost', type: 'button', 'data-testid': 'applyPromo', onclick: applyPromo }, t('applyPromo'))),
      err(),
      h('button', { class: 'btn', type: 'button', disabled: S.busy, 'data-testid': 'confirm', onclick: confirm }, t('confirm')),
      backBtn(4),
    ];
  }
  async function applyPromo() {
    S.error = ''; S.promo = null;
    const code = S.promoInput.trim();
    if (code) {
      try { S.promo = Object.assign({ code }, await api(`/api/v1/public/businesses/${encodeURIComponent(slug)}/promo-check?serviceId=${S.service.id}&code=${encodeURIComponent(code)}`)); }
      catch (e) { S.error = errText(e); }
    }
    render();
  }
  async function confirm() {
    S.busy = true; S.error = ''; render();
    const body = { branchId: S.branch.id, serviceId: S.service.id, startsAt: S.slot.start,
      customer: { fullName: S.name, phone: S.phone, email: S.email || null, marketingOptIn: S.marketing } };
    if (S.employee) body.employeeId = S.employee.id;
    if (S.promo) body.promoCode = S.promo.code;
    try {
      S.result = await api(`/api/v1/public/businesses/${encodeURIComponent(slug)}/bookings`, { method: 'POST', body: JSON.stringify(body) });
    } catch (e) {
      S.error = errText(e);
      if (e.code === 'PROMO_INVALID') S.promo = null;
      if (e.code === 'SLOT_UNAVAILABLE') { S.busy = false; S.step = 3; return loadSlots(); }
    }
    S.busy = false; render();
  }
  function stepDone() {
    const r = S.result;
    const link = `${location.origin}/m/${r.manageToken}`;
    const deposit = Number(r.depositAmount);
    return [
      h('h2', { class: 'ok', 'data-testid': 'done' }, t('booked')),
      h('p', {}, t('status_' + r.status)),
      h('div', { class: 'card' }, h('div', {}, S.service.name), h('div', { class: 'muted' }, fmtDateTime(r.startsAt)),
        h('div', { class: 'price' }, money(r.price, r.currency))),
      deposit > 0 && h('div', { class: 'box' }, h('strong', {}, `${t('deposit')}: ${money(deposit, r.currency)}`),
        h('p', { class: 'small' }, `${t('depositNote')} ${r.holdExpiresAt ? fmtTime(r.holdExpiresAt) : ''}`)),
      h('p', { class: 'small muted' }, t('manageLink')),
      h('p', { class: 'link small' }, h('a', { href: link, 'data-testid': 'manage-link' }, link)),
      h('button', { class: 'btn ghost', type: 'button', onclick: async (ev) => { try { await navigator.clipboard.writeText(link); ev.target.textContent = t('copied'); } catch (e) {} } }, t('copy')),
    ];
  }

  function render() {
    if (!S.profile) return;
    document.documentElement.lang = getLang();
    const body = S.result ? stepDone() : [stepService, stepWho, stepWhen, stepDetails, stepReview][S.step - 1]();
    root.replaceChildren(...header().filter(Boolean), ...body.flat().filter(Boolean));
  }

  (async function init() {
    try { S.profile = await api(`/api/v1/public/businesses/${encodeURIComponent(slug)}`); render(); }
    catch (e) { root.replaceChildren(h('p', { class: 'err', role: 'alert' }, errText(e))); }
  })();
})();
