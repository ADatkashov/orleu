// Dependency-free load test for the main read/write paths of ORLEU (Node 18+, uses global fetch).
//   BASE=http://localhost:8080 [VUS=16] [DURATION=20] [WARMUP=5] [BOOKINGS=1500] [CUSTOMERS=800] [OUT=results.md] node load-test.js
// It seeds its own business through the public API, so it can run against any freshly started stack.
// Start the backend with ORLEU_RATE_LIMIT_PER_MINUTE=1000000, otherwise the per-IP limiter (60/min) rejects the public booking scenario.
// The numbers are only meaningful for the machine, data volume and concurrency they were measured with: see docs/LOAD_TESTING.md.
const BASE = process.env.BASE || 'http://localhost:8080';
const VUS = +(process.env.VUS || 16), DURATION = +(process.env.DURATION || 20), WARMUP = +(process.env.WARMUP || 5);
const BOOKINGS = +(process.env.BOOKINGS || 1500), CUSTOMERS = +(process.env.CUSTOMERS || 800);
const J = { 'Content-Type': 'application/json' };

async function api(path, method = 'GET', body, token) {
  const r = await fetch(BASE + path, { method, headers: { ...J, ...(token ? { Authorization: 'Bearer ' + token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  const text = await r.text();
  return { status: r.status, body: text ? JSON.parse(text) : null };
}
const must = (r, what) => { if (r.status >= 300) throw new Error(`${what} -> ${r.status} ${JSON.stringify(r.body)}`); return r.body; };
const rnd = (n) => Math.floor(Math.random() * n);
const pool = async (n, conc, fn) => { let i = 0; await Promise.all(Array.from({ length: conc }, async () => { while (i < n) await fn(i++); })); };

function almatyDay(offsetDays) { // yyyy-mm-dd of "today + offset" in Asia/Almaty
  const d = new Date(Date.now() + offsetDays * 864e5 + 5 * 36e5);
  return d.toISOString().slice(0, 10);
}
const slotInstant = (day, h, m) => new Date(`${day}T${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:00+05:00`).toISOString();

async function seed() {
  const stamp = Date.now(), slug = 'load-' + stamp;
  const reg = must(await api('/api/v1/auth/register', 'POST', { email: `load${stamp}@example.com`, password: 'correct-horse-battery', fullName: 'Load Owner' }), 'register');
  const T = reg.accessToken;
  const biz = must(await api('/api/v1/businesses', 'POST', { name: 'Load Barbers', slug, businessType: 'BARBERSHOP' }, T), 'business');
  const br = must(await api(`/api/v1/businesses/${biz.id}/branches`, 'POST', { name: 'Main', address: 'Abay 1' }, T), 'branch');
  must(await api(`/api/v1/businesses/${biz.id}/branches/${br.id}/hours`, 'PUT', { hours: [1, 2, 3, 4, 5, 6, 7].map((d) => ({ dayOfWeek: d, open: '09:00', close: '21:00' })) }, T), 'hours');
  const svc = must(await api(`/api/v1/businesses/${biz.id}/services`, 'POST', { name: 'Haircut', durationMinutes: 30, price: '20000.00' }, T), 'service');
  const emps = [];
  for (let i = 0; i < 3; i++) { // the FREE plan allows 3 specialists
    const e = must(await api(`/api/v1/businesses/${biz.id}/employees`, 'POST', { displayName: 'Master ' + i }, T), 'employee');
    must(await api(`/api/v1/businesses/${biz.id}/employees/${e.id}/assignments`, 'PUT', { branchIds: [br.id], serviceIds: [svc.id] }, T), 'assign');
    emps.push(e.id);
  }
  must(await api(`/api/v1/businesses/${biz.id}/publish`, 'POST', null, T), 'publish');
  let ok = 0, tries = 0;
  const t0 = Date.now();
  await pool(BOOKINGS * 2, 8, async (i) => {
    if (ok >= BOOKINGS) return;
    tries++;
    const r = await api(`/api/v1/businesses/${biz.id}/bookings`, 'POST', {
      branchId: br.id, serviceId: svc.id, employeeId: emps[rnd(3)], startsAt: slotInstant(almatyDay(1 + rnd(60)), 9 + rnd(11), rnd(2) * 30),
      customer: { fullName: 'Customer ' + (i % CUSTOMERS), phone: '+77017' + String(100000 + (i % CUSTOMERS)).slice(-6) },
    }, T);
    if (r.status === 201) ok++;
  });
  console.log(`seeded ${ok} bookings (${tries} attempts, ${((Date.now() - t0) / 1000).toFixed(1)} s), up to ${CUSTOMERS} customers`);
  return { T, biz: biz.id, slug, br: br.id, svc: svc.id, emps };
}

const pct = (a, p) => a.length ? a[Math.min(a.length - 1, Math.floor(a.length * p))] : NaN;

async function run(name, fn) {
  const lat = [], latOk = [], codes = {};
  let stop = Date.now() + WARMUP * 1000, measuring = false, measureStart = 0;
  const vu = async () => {
    while (Date.now() < stop) {
      const t = performance.now();
      let status;
      try { status = await fn(); } catch (e) { status = 'ERR'; }
      if (measuring) { const d = performance.now() - t; lat.push(d); if (status >= 200 && status < 300) latOk.push(d); codes[status] = (codes[status] || 0) + 1; }
    }
  };
  await Promise.all(Array.from({ length: VUS }, vu)); // warm-up (JIT, connection pool, caches)
  measuring = true; measureStart = Date.now(); stop = measureStart + DURATION * 1000;
  await Promise.all(Array.from({ length: VUS }, vu));
  const secs = (Date.now() - measureStart) / 1000;
  lat.sort((a, b) => a - b);
  latOk.sort((a, b) => a - b);
  const total = lat.length;
  const good = Object.entries(codes).filter(([c]) => +c >= 200 && +c < 300).reduce((s, [, n]) => s + n, 0);
  return { name, requests: total, rps: +(total / secs).toFixed(1), p50: +pct(lat, 0.5).toFixed(1), p95: +pct(lat, 0.95).toFixed(1), p99: +pct(lat, 0.99).toFixed(1), max: +(lat[total - 1] || 0).toFixed(1), ok2xx: good, codes, successOnly: latOk.length && latOk.length !== total ? { n: latOk.length, p50: +pct(latOk, 0.5).toFixed(1), p95: +pct(latOk, 0.95).toFixed(1), p99: +pct(latOk, 0.99).toFixed(1) } : null };
}

(async () => {
  const s = await seed();
  const day = () => almatyDay(1 + rnd(60));
  const scenarios = [
    ['public availability (GET)', async () => (await api(`/api/v1/public/businesses/${s.slug}/availability?branchId=${s.br}&serviceId=${s.svc}&date=${day()}`)).status],
    ['public booking create (POST)', async () => (await api(`/api/v1/public/businesses/${s.slug}/bookings`, 'POST', {
      branchId: s.br, serviceId: s.svc, startsAt: slotInstant(almatyDay(1 + rnd(60)), 9 + rnd(11), rnd(2) * 30),
      customer: { fullName: 'Load Guest', phone: '+77018' + String(1000000 + rnd(9000000)).slice(-7) } })).status],
    ['staff calendar day (GET bookings)', async () => {
      const d = day(), from = slotInstant(d, 0, 0), to = new Date(new Date(from).getTime() + 864e5).toISOString();
      return (await api(`/api/v1/businesses/${s.biz}/bookings?from=${from}&to=${to}`, 'GET', null, s.T)).status;
    }],
    ['customer search (GET customers?q=)', async () => (await api(`/api/v1/businesses/${s.biz}/customers?q=${encodeURIComponent('Customer ' + rnd(CUSTOMERS))}&size=20`, 'GET', null, s.T)).status],
    ['dashboard summary, 90 days (GET)', async () => {
      const from = new Date(Date.now() - 30 * 864e5).toISOString(), to = new Date(Date.now() + 60 * 864e5).toISOString();
      return (await api(`/api/v1/businesses/${s.biz}/analytics/summary?from=${from}&to=${to}`, 'GET', null, s.T)).status;
    }],
    ['analytics breakdown by service (GET)', async () => {
      const from = new Date(Date.now() - 30 * 864e5).toISOString(), to = new Date(Date.now() + 60 * 864e5).toISOString();
      return (await api(`/api/v1/businesses/${s.biz}/analytics/breakdown?by=SERVICE&from=${from}&to=${to}`, 'GET', null, s.T)).status;
    }],
  ];
  const results = [];
  for (const [name, fn] of scenarios) {
    const r = await run(name, fn);
    results.push(r);
    if (r.successOnly) console.log(`${''.padEnd(40)} 2xx only: ${r.successOnly.n} requests, p50 ${r.successOnly.p50} ms  p95 ${r.successOnly.p95} ms  p99 ${r.successOnly.p99} ms`);
    console.log(`${r.name.padEnd(40)} ${String(r.rps).padStart(7)} req/s  p50 ${r.p50} ms  p95 ${r.p95} ms  p99 ${r.p99} ms  max ${r.max} ms  codes ${JSON.stringify(r.codes)}`);
  }
  if (process.env.OUT) {
    const rows = results.flatMap((r) => {
      const codes = Object.entries(r.codes).map(([c, n]) => c + '×' + n).join(', ');
      const out = [`| ${r.name} | ${r.requests} | ${r.rps} | ${r.p50} | ${r.p95} | ${r.p99} | ${r.max} | ${codes} |`];
      if (r.successOnly) out.push(`| ↳ 2xx responses only | ${r.successOnly.n} | | ${r.successOnly.p50} | ${r.successOnly.p95} | ${r.successOnly.p99} | | |`);
      return out;
    });
    require('fs').writeFileSync(process.env.OUT, `| Scenario | Requests | req/s | p50 ms | p95 ms | p99 ms | max ms | Status codes |\n|---|---|---|---|---|---|---|---|\n${rows.join('\n')}\n`);
  }
  const bad = results.filter((r) => r.name !== 'public booking create (POST)' && r.ok2xx !== r.requests);
  if (bad.length) { console.error('Non-2xx responses in: ' + bad.map((b) => b.name).join(', ')); process.exit(1); }
})().catch((e) => { console.error('LOAD TEST FAILED:', e.message); process.exit(1); });
