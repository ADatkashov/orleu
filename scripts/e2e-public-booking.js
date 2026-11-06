// Real-browser E2E of the public booking flow against a running backend.
// Usage: BASE=http://localhost:18082 node scripts/e2e-public-booking.js [screenshotDir]
const { chromium } = require('playwright');
const BASE = process.env.BASE || 'http://localhost:8080';
const SHOTS = process.argv[2];
const J = { 'Content-Type': 'application/json' };

async function api(path, method, body, token) {
  const r = await fetch(BASE + path, { method, headers: { ...J, ...(token ? { Authorization: 'Bearer ' + token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  const text = await r.text();
  if (!r.ok) throw new Error(`${method} ${path} -> ${r.status} ${text}`);
  return text ? JSON.parse(text) : null;
}
const assert = (c, m) => { if (!c) throw new Error('ASSERT: ' + m); };

(async () => {
  const stamp = Date.now();
  const slug = 'e2e-' + stamp;
  const { accessToken: T } = await api('/api/v1/auth/register', 'POST', { email: `e2e${stamp}@example.com`, password: 'correct-horse-battery', fullName: 'E2E Owner' });
  const biz = await api('/api/v1/businesses', 'POST', { name: 'E2E Barbers', slug, businessType: 'BARBERSHOP', description: 'Fades & beards' }, T);
  const br = await api(`/api/v1/businesses/${biz.id}/branches`, 'POST', { name: 'Main', address: 'Abay 1' }, T);
  await api(`/api/v1/businesses/${biz.id}/branches/${br.id}/hours`, 'PUT', { hours: [1, 2, 3, 4, 5, 6, 7].map((d) => ({ dayOfWeek: d, open: '00:00', close: '23:59' })) }, T);
  const svc = await api(`/api/v1/businesses/${biz.id}/services`, 'POST', { name: 'Haircut', durationMinutes: 60, price: '20000.00', category: 'Hair' }, T);
  const emp = await api(`/api/v1/businesses/${biz.id}/employees`, 'POST', { displayName: 'Master Dana' }, T);
  await api(`/api/v1/businesses/${biz.id}/employees/${emp.id}/assignments`, 'PUT', { branchIds: [br.id], serviceIds: [svc.id] }, T);
  await api(`/api/v1/businesses/${biz.id}/publish`, 'POST', null, T);

  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'en-US' });
  const page = await ctx.newPage();
  const problems = [];
  page.on('console', (m) => { if (m.type() === 'error') problems.push('console: ' + m.text()); });
  page.on('pageerror', (e) => problems.push('pageerror: ' + e.message));
  const shot = async (n) => { if (SHOTS) await page.screenshot({ path: `${SHOTS}/${n}.png` }); };

  await page.goto(`${BASE}/b/${slug}`);
  await page.getByRole('heading', { name: 'E2E Barbers' }).waitFor();
  assert((await page.title()).includes('E2E Barbers'), 'title');
  await shot('1-service');
  await page.getByTestId('service').first().click();
  // one branch and one specialist -> straight to date/time
  await page.getByTestId('slot').first().waitFor();
  await shot('2-time');
  // pick a date 4 days out (outside the 24h free-cancellation window), then a time
  await page.locator('.chips .chip').nth(4).click();
  await page.getByTestId('slot').first().waitFor();
  await page.getByTestId('slot').nth(8).click();
  await page.getByTestId('to-details').click();

  await page.locator('#f-name').fill('Aigerim');
  await page.locator('#f-phone').fill('8 701 123 45 67'); // local format must be normalised to +7...
  await shot('3-details');
  await page.getByTestId('to-review').click();
  await page.getByTestId('confirm').waitFor();
  await shot('4-review');
  await page.getByTestId('confirm').click();
  await page.getByTestId('done').waitFor();
  await shot('5-done');

  const link = await page.getByTestId('manage-link').getAttribute('href');
  assert(/\/m\/[A-Za-z0-9_-]{40,}$/.test(link), 'manage link ' + link);

  // owner sees the guest booking with normalised phone
  const from = new Date(Date.now() - 864e5).toISOString(), to = new Date(Date.now() + 10 * 864e5).toISOString();
  const list = await api(`/api/v1/businesses/${biz.id}/bookings?from=${from}&to=${to}`, 'GET', null, T);
  assert(list.length === 1 && list[0].customerPhone === '+77011234567' && list[0].status === 'CONFIRMED', 'owner view ' + JSON.stringify(list));

  // manage page: view, then cancel
  const m = await ctx.newPage();
  m.on('pageerror', (e) => problems.push('pageerror: ' + e.message));
  m.on('dialog', (d) => d.accept());
  await m.goto(link);
  await m.getByTestId('cancel').waitFor();
  if (SHOTS) await m.screenshot({ path: `${SHOTS}/6-manage.png` });
  await m.getByTestId('cancel').click();
  await m.getByTestId('msg').waitFor();
  assert(!(await m.getByTestId('cancel').count()), 'cancel button gone');
  assert(!/\b(false|null|undefined)\b/.test(await m.locator('body').innerText()), 'no stray false/null text on the manage page');
  const after = await api(`/api/v1/businesses/${biz.id}/bookings?from=${from}&to=${to}`, 'GET', null, T);
  assert(after[0].status === 'CANCELLED', 'cancelled in backend');

  // review: a second guest booking, completed by staff, is reviewed in the browser via its manage link
  const when = new Date(Date.now() + 6 * 864e5); when.setUTCHours(12, 0, 0, 0);
  const second = await api(`/api/v1/public/businesses/${slug}/bookings`, 'POST', { branchId: br.id, serviceId: svc.id, startsAt: when.toISOString(), customer: { fullName: 'Dana Guest', phone: '+77011234568' } });
  const rv = await ctx.newPage();
  rv.on('pageerror', (e) => problems.push('pageerror: ' + e.message));
  await rv.goto(`${BASE}/m/${second.manageToken}`);
  await rv.getByTestId('cancel').waitFor();
  assert(!(await rv.getByTestId('review-box').count()), 'no review box before the visit happened');
  for (const st of ['CHECKED_IN', 'IN_PROGRESS', 'COMPLETED']) await api(`/api/v1/businesses/${biz.id}/bookings/${second.bookingId}/transition`, 'POST', { status: st }, T);
  await rv.reload();
  await rv.getByTestId('review-box').waitFor();
  assert(!/\b(false|null|undefined)\b/.test(await rv.locator('body').innerText()), 'no stray false/null text on the review page');
  if (SHOTS) await rv.screenshot({ path: `${SHOTS}/7-review.png` });
  assert(await rv.getByTestId('send-review').isDisabled(), 'send disabled until a star is chosen');
  await rv.getByTestId('star-5').click();
  await rv.getByTestId('comment').fill('Great <b>cut</b>');
  await rv.getByTestId('send-review').click();
  await rv.getByTestId('your-rating').waitFor();
  assert(!(await rv.getByTestId('review-box').count()), 'review box gone after sending');
  const reviews = await api(`/api/v1/businesses/${biz.id}/reviews`, 'GET', null, T);
  assert(reviews.length === 1 && reviews[0].rating === 5 && reviews[0].comment === 'Great <b>cut</b>', 'review stored ' + JSON.stringify(reviews));
  await page.goto(`${BASE}/b/${slug}`);
  await page.getByTestId('rating').waitFor();
  assert((await page.getByTestId('rating').textContent()).includes('5.0'), 'average shown on the booking page');

  // language switch re-renders in Russian
  await m.getByRole('button', { name: 'RU' }).click();
  await m.getByText('Ваша запись').waitFor();

  // XSS probe: a hostile business name must render as text
  await api(`/api/v1/businesses/${biz.id}/settings`, 'PATCH', { name: '<img src=x onerror=window.__xss=1>' }, T);
  await page.goto(`${BASE}/b/${slug}`);
  await page.getByRole('heading').first().waitFor();
  assert(!(await page.evaluate(() => window.__xss)), 'XSS executed');

  assert(problems.length === 0, 'browser problems: ' + problems.join(' | '));
  await browser.close();
  console.log('E2E PASSED: guest booked, owner saw it, guest cancelled via link, completed visit reviewed (average shown on the page), RU switch, XSS probe inert');
})().catch((e) => { console.error('E2E FAILED:', e.message); process.exit(1); });
