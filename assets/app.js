/* ===== Fox partner · Reaction Archive ===== */
(function () {
  'use strict';

  // ---------- SETTINGS (edit these) ----------
  const CONFIG = {
    youtubeUrl: 'https://www.youtube.com/@thefoxpartner',
    patreonUrl: 'https://www.patreon.com/c/Foxpartner',
    // Google Form that receives the recommendations (see README / setup steps).
    // id = the long code in the form link: docs.google.com/forms/d/e/<id>/viewform
    googleForm: {
      id: '1FAIpQLSeW-Nruh1vB72G2ZohnrtDhQVp8fBQkdBjwyke7OEYHYIzEag',
      fields: { what: 'entry.832068007', link: 'entry.1800166251' },
    },
    pageSize: 24,
  };

  // ---------- helpers ----------
  const $ = (s, el = document) => el.querySelector(s);
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const norm = (s) => String(s ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  const reEsc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

  function rng(seed) { // mulberry32
    let a = seed >>> 0;
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  function hash(str) { let h = 2166136261; for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }

  // torn-paper edge for each card, stable per item
  function tornPolygon(seed) {
    const r = rng(seed);
    const j = (max) => (r() * max).toFixed(1) + 'px';
    const pts = [];
    for (let x = 0; x <= 100; x += 5) pts.push(`${x}% ${j(6)}`);
    for (let y = 8; y <= 92; y += 12) pts.push(`calc(100% - ${j(3)}) ${y}%`);
    for (let x = 100; x >= 0; x -= 5) pts.push(`${x}% calc(100% - ${j(6)})`);
    for (let y = 92; y >= 8; y -= 12) pts.push(`${j(3)} ${y}%`);
    return `polygon(${pts.join(',')})`;
  }

  const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  function fmtDate(d, exact) {
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(d || '');
    if (!m) return '';
    const mon = MONTHS[+m[2] - 1];
    return exact ? `${mon} ${+m[3]}, ${m[1]}` : `${mon} ${m[1]}`;
  }

  // remove the artist name from the start of the "reacted" text (the artist is shown above it)
  function stripArtist(text, names) {
    let t = text;
    for (const n of names) {
      if (!n) continue;
      const re = new RegExp('^\\s*' + reEsc(n) + '\\s*(\\([^)]*\\))?\\s*([-–|:/]\\s*)?', 'i');
      if (re.test(t)) { const rest = t.replace(re, ''); if (rest.trim().length > 2) { t = rest; break; } }
    }
    return t.trim();
  }

  // ---------- data ----------
  const RAW = Array.isArray(window.FOX_CATALOG) ? window.FOX_CATALOG : [];
  const DATA = RAW.map((x, i) => {
    const yt = /[?&]v=([\w-]{11})/.exec(x.u || '');
    const what = stripArtist(x.r || x.o || '', [x.a, x.g]);
    const group = x.g || x.a || 'Various';
    const feats = String(x.f || '').split(';').map((s) => s.trim()).filter((s) => s && s !== group);
    return {
      i,
      artist: x.a || 'Various',
      group,
      feats,
      groups: [group, ...feats],
      what,
      type: x.t || 'Music Video',
      platform: x.p,
      date: x.d || '',
      url: x.u,
      original: x.o || '',
      ytId: yt ? yt[1] : null,
      img: x.i || '',
      hay: norm([x.a, x.g, x.f, x.r, x.o, x.t, x.p].join(' | ')),
    };
  });

  function matches(item, tokens) {
    for (const t of tokens) if (!item.hay.includes(t)) return false;
    return true;
  }
  const tokenize = (q) => norm(q).split(/\s+/).filter(Boolean);

  // ---------- links / stats ----------
  document.querySelectorAll('[data-link]').forEach((a) => {
    a.href = a.dataset.link === 'youtube' ? CONFIG.youtubeUrl : CONFIG.patreonUrl;
  });
  const groups = new Map();
  DATA.forEach((d) => d.groups.forEach((g) => groups.set(g, (groups.get(g) || 0) + 1)));

  // ---------- spiral ----------
  (function drawSpiral() {
    const p = $('#spiral-path'); if (!p) return;
    let d = '';
    for (let t = 0; t <= Math.PI * 6.2; t += 0.12) {
      const r = 4 + 4.9 * t;
      const x = 100 + r * Math.cos(t), y = 100 + r * Math.sin(t);
      d += (d ? 'L' : 'M') + x.toFixed(1) + ' ' + y.toFixed(1);
    }
    p.setAttribute('d', d);
  })();

  // ---------- filters ----------
  const state = { q: '', platform: 'all', group: 'all', sort: 'new', shown: CONFIG.pageSize };

  const selGroup = $('#f-group'), selSort = $('#f-sort'), q = $('#q');
  selGroup.innerHTML = `<option value="all">All artists (${groups.size})</option>` +
    [...groups.entries()].sort((a, b) => a[0].localeCompare(b[0], 'en', { sensitivity: 'base' }))
      .map(([g, n]) => `<option value="${esc(g)}">${esc(g)} (${n})</option>`).join('');

  // read state from URL (?q=ateez&platform=Patreon ...) so filtered views can be shared
  const params = new URLSearchParams(location.search);
  if (params.get('q')) state.q = params.get('q');
  if (['YouTube', 'Patreon'].includes(params.get('platform'))) state.platform = params.get('platform');
  if (params.get('artist') && groups.has(params.get('artist'))) state.group = params.get('artist');
  if (['new', 'old', 'az'].includes(params.get('sort'))) state.sort = params.get('sort');
  q.value = state.q; selGroup.value = state.group; selSort.value = state.sort;

  function syncUrl() {
    const p = new URLSearchParams();
    if (state.q) p.set('q', state.q);
    if (state.platform !== 'all') p.set('platform', state.platform);
    if (state.group !== 'all') p.set('artist', state.group);
    if (state.sort !== 'new') p.set('sort', state.sort);
    const s = p.toString();
    history.replaceState(null, '', location.pathname + (s ? '?' + s : '') + location.hash);
  }

  function filtered() {
    const tokens = tokenize(state.q);
    let list = DATA.filter((d) =>
      (state.platform === 'all' || d.platform === state.platform) &&
      (state.group === 'all' || d.groups.includes(state.group)) &&
      matches(d, tokens));
    if (state.sort === 'new') list.sort((a, b) => (b.date || '').localeCompare(a.date || '') || a.i - b.i);
    else if (state.sort === 'old') list.sort((a, b) => (a.date || '').localeCompare(b.date || '') || b.i - a.i);
    else list.sort((a, b) => a.artist.localeCompare(b.artist, 'en', { sensitivity: 'base' }) || a.what.localeCompare(b.what));
    return list;
  }

  function card(d) {
    const seed = hash(d.url || String(d.i));
    const r = rng(seed);
    const rot = ((r() - 0.5) * 3.2).toFixed(2);
    const tape = ((r() - 0.5) * 10).toFixed(1);
    const isYT = d.platform === 'YouTube';
    const src = isYT && d.ytId ? `https://i.ytimg.com/vi/${d.ytId}/mqdefault.jpg` : d.img;
    const thumb = src
      ? `<div class="thumb"><img loading="lazy" decoding="async" src="${esc(src)}" alt="" onerror="this.remove()"></div>`
      : `<div class="thumb pt"><span class="stamp">Patreon<small>members only</small></span></div>`;
    const sub = d.artist !== d.group ? `<small>${esc(d.group)}</small>` : '';
    return `<article class="clip" style="--rot:${rot}deg;--tape:${tape}deg">
      <a class="card" href="${esc(d.url)}" target="_blank" rel="noopener" style="--torn:${tornPolygon(seed)}" title="${esc(d.original)}">
        ${thumb}
        <div class="card-body">
          <span class="tag">${esc(d.type)}</span>
          <h3 class="artist">${esc(d.artist)}${sub}</h3>
          ${d.feats.length ? `<p class="feat">with ${d.feats.map(esc).join(' &amp; ')}</p>` : ''}
          <p class="what">${esc(d.what)}</p>
          <div class="meta">
            <span class="plat ${isYT ? 'yt' : 'pt'}">${isYT ? '▶ YouTube' : (d.img ? '★ Patreon · free' : '★ Patreon')}</span>
            <time datetime="${esc(d.date)}"${isYT ? ' title="approximate date"' : ''}>${fmtDate(d.date, !isYT)}</time>
          </div>
        </div>
      </a>
    </article>`;
  }

  const grid = $('#grid'), count = $('#count'), more = $('#more'), empty = $('#empty');

  function render() {
    const list = filtered();
    const shown = list.slice(0, state.shown);
    grid.innerHTML = shown.map(card).join('');
    empty.hidden = list.length > 0;
    more.hidden = list.length <= state.shown;
    more.textContent = `Load more (${list.length - shown.length} left)`;
    count.innerHTML = list.length
      ? `Showing <b>${shown.length}</b> of <b>${list.length}</b> reaction${list.length === 1 ? '' : 's'}`
      : '';
    document.querySelectorAll('.chip-btn').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.platform === state.platform)));
    syncUrl();
  }

  let qTimer;
  q.addEventListener('input', () => {
    clearTimeout(qTimer);
    qTimer = setTimeout(() => { state.q = q.value.trim(); state.shown = CONFIG.pageSize; render(); }, 120);
  });
  document.querySelectorAll('.chip-btn').forEach((b) => b.addEventListener('click', () => {
    state.platform = b.dataset.platform; state.shown = CONFIG.pageSize; render();
  }));
  selGroup.addEventListener('change', () => { state.group = selGroup.value; state.shown = CONFIG.pageSize; render(); });
  selSort.addEventListener('change', () => { state.sort = selSort.value; render(); });
  more.addEventListener('click', () => { state.shown += CONFIG.pageSize; render(); });

  // "Recommend it" from the empty state carries the search over to the checker
  $('#empty-recommend').addEventListener('click', () => {
    const c = $('#check'); c.value = state.q; runCheck();
    setTimeout(() => c.focus({ preventScroll: true }), 400);
  });

  // ---------- recommendation checker ----------
  const check = $('#check'), checkOut = $('#check-results');
  function runCheck() {
    const tokens = tokenize(check.value);
    if (!tokens.length || check.value.trim().length < 2) { checkOut.innerHTML = ''; return; }
    const hits = DATA.filter((d) => matches(d, tokens)).sort((a, b) => (b.date || '').localeCompare(a.date || ''));
    if (!hits.length) {
      checkOut.innerHTML = `<p class="verdict">Not in the archive yet. Send it! →</p>`;
      return;
    }
    const top = hits.slice(0, 6);
    checkOut.innerHTML = `<p class="verdict yes">Good news! I found ${hits.length} reaction${hits.length === 1 ? '' : 's'}:</p>
      <ul>${top.map((d) => `<li><a href="${esc(d.url)}" target="_blank" rel="noopener">
        <span class="ttl"><b>${esc(d.artist)}</b>: ${esc(d.what)}</span>
        <span class="plat ${d.platform === 'YouTube' ? 'yt' : 'pt'}">${d.platform === 'YouTube' ? '▶ YT' : '★ Patreon'}</span>
      </a></li>`).join('')}</ul>
      ${hits.length > top.length ? `<p class="verdict" style="font-size:16px;margin-top:10px"><a href="?q=${encodeURIComponent(check.value.trim())}#archive">See all ${hits.length} in the archive</a></p>` : ''}`;
  }
  let cTimer;
  check.addEventListener('input', () => { clearTimeout(cTimer); cTimer = setTimeout(runCheck, 150); });

  // ---------- recommendation form (sends to Google Forms) ----------
  const form = $('#rec-form'), status = $('#rec-status'), dup = $('#dup-warning'), submitBtn = $('#rec-submit');
  const gf = CONFIG.googleForm;
  const formReady = !!(gf.id && gf.fields.what);
  let dupConfirmedFor = null;

  function setStatus(msg, kind) { status.className = 'rec-status' + (kind ? ' ' + kind : ''); status.innerHTML = msg; }

  form.elements.what.addEventListener('input', () => { dup.hidden = true; dupConfirmedFor = null; });

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const what = form.elements.what.value.trim();
    const link = form.elements.link.value.trim();
    if (what.length < 2) { setStatus('Tell me what to react to first!', 'err'); form.elements.what.focus(); return; }
    if (link && !/^https?:\/\/\S+\.\S+/.test(link)) { setStatus('That link doesn\'t look right. It should start with https://', 'err'); form.elements.link.focus(); return; }

    // already in the archive? warn once, second click sends anyway
    const hits = DATA.filter((d) => matches(d, tokenize(what)));
    if (hits.length && dupConfirmedFor !== what) {
      dupConfirmedFor = what;
      const top = hits.slice(0, 3);
      dup.innerHTML = `<b>Heads up! I might have reacted to this already:</b><ul>${top.map((d) =>
        `<li><a href="${esc(d.url)}" target="_blank" rel="noopener">${esc(d.artist)}: ${esc(d.what)}</a> <span class="plat ${d.platform === 'YouTube' ? 'yt' : 'pt'}">${d.platform === 'YouTube' ? '▶ YT' : '★ Patreon'}</span></li>`).join('')}</ul>
        <p>Something different? Click send again.</p>`;
      dup.hidden = false;
      setStatus('');
      return;
    }

    if (!formReady) { setStatus('The form isn\'t connected yet. Please try again soon!', 'err'); return; }

    const body = new FormData();
    body.append(gf.fields.what, what);
    if (gf.fields.link && link) body.append(gf.fields.link, link);

    submitBtn.disabled = true; setStatus('Sending…');
    try {
      await fetch(`https://docs.google.com/forms/d/e/${encodeURIComponent(gf.id)}/formResponse`, { method: 'POST', mode: 'no-cors', body });
      form.reset(); dup.hidden = true; dupConfirmedFor = null;
      setStatus('<b>Got it, thank you!</b> Your recommendation is on my list. 🦊', 'ok');
    } catch (e) {
      setStatus('Something went wrong. Check your connection and try again.', 'err');
    } finally {
      submitBtn.disabled = false;
    }
  });

  render();
})();
