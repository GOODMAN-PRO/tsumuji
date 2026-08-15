/* manga reader — vanilla, no deps. All paths relative (GitHub Pages project site). */
(function () {
  'use strict';

  var K = { theme: 'tsumuji:theme', mode: 'tsumuji:mode', pos: 'tsumuji:pos' };
  var get = function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } };
  var set = function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} };
  var $ = function (id) { return document.getElementById(id); };
  var pad = function (n) { return n < 10 ? '0' + n : '' + n; };

  /* ---------- theme ---------- */
  function applyTheme(t) {
    var root = document.documentElement;
    if (t) root.dataset.theme = t; else delete root.dataset.theme;
    var dark = t ? t === 'dark' : !matchMedia('(prefers-color-scheme: light)').matches;
    var tc = $('tc');
    if (tc) tc.content = dark ? '#121110' : '#faf8f5';
  }
  applyTheme(get(K.theme));
  Array.prototype.forEach.call(document.querySelectorAll('[data-theme-toggle]'), function (b) {
    b.addEventListener('click', function () {
      var dark = document.documentElement.dataset.theme
        ? document.documentElement.dataset.theme === 'dark'
        : matchMedia('(prefers-color-scheme: dark)').matches;
      var next = dark ? 'light' : 'dark';
      set(K.theme, next);
      applyTheme(next);
    });
  });

  /* ---------- shared bits ---------- */
  function say(msg) { var n = $('note'); if (n) { n.textContent = msg; n.hidden = false; } }

  // image box with a graceful "page N" placeholder when the file 404s
  function box(src, label, lazy) {
    var d = document.createElement('div');
    d.className = 'box';
    var ph = document.createElement('span');
    ph.className = 'ph';
    ph.textContent = label;
    d.appendChild(ph);
    var img = new Image();
    img.alt = label;
    img.decoding = 'async';
    if (lazy) img.loading = 'lazy';
    img.onload = function () { d.style.setProperty('--ar', img.naturalWidth + '/' + img.naturalHeight); };
    img.onerror = function () { d.classList.add('err'); };
    img.src = src;
    d.appendChild(img);
    return d;
  }

  function manifest() {
    return fetch('chapters.json', { cache: 'no-cache' }).then(function (r) {
      if (!r.ok) throw new Error(r.status);
      return r.json();
    });
  }

  function savedPos() {
    try { return JSON.parse(get(K.pos) || 'null'); } catch (e) { return null; }
  }

  function fmtDate(s) {
    var d = new Date(s);
    return isNaN(d) ? (s || '') : d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
  }

  /* ---------- index ---------- */
  function initIndex() {
    manifest().then(function (m) {
      var s = m.series || {};
      document.title = s.title || 'Manga';
      $('s-title').textContent = s.title || '';
      $('s-sub').textContent = s.subtitle || '';
      $('s-tag').textContent = s.tagline || '';

      var chapters = (m.chapters || []).slice().sort(function (a, b) { return b.n - a.n; });
      var pos = savedPos();
      if (pos && chapters.some(function (c) { return c.n === pos.chapter; })) {
        var r = $('resume');
        r.href = 'read.html?ch=' + pos.chapter + '#p' + pad(pos.page);
        r.textContent = 'Continue Ch.' + pos.chapter + ' — page ' + pos.page;
        r.hidden = false;
      }

      var grid = $('grid');
      chapters.forEach(function (c) {
        var li = document.createElement('li');
        var a = document.createElement('a');
        a.className = 'card';
        a.href = 'read.html?ch=' + c.n;
        a.appendChild(box(c.cover || ('chapters/' + c.slug + '/cover.jpg'), 'Ch.' + c.n, true));
        a.insertAdjacentHTML('beforeend',
          '<span class="cnum"></span><span class="ctitle"></span><span class="cmeta"></span>');
        a.querySelector('.cnum').textContent = 'Chapter ' + c.n;
        a.querySelector('.ctitle').textContent = c.title || '';
        a.querySelector('.cmeta').textContent = c.pages + ' pages · ' + fmtDate(c.published);
        li.appendChild(a);
        grid.appendChild(li);
      });
      if (!chapters.length) say('No chapters yet.');
    }).catch(function () { say('Could not load chapters.json.'); });
  }

  /* ---------- reader ---------- */
  function initReader() {
    if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
    var n = parseInt(new URLSearchParams(location.search).get('ch'), 10);
    manifest().then(function (m) {
      var list = (m.chapters || []).slice().sort(function (a, b) { return a.n - b.n; });
      var ch = list.filter(function (c) { return c.n === n; })[0];
      if (!ch) { say('Chapter not found.'); document.body.classList.add('bar'); return; }
      build(ch, list);
    }).catch(function () { say('Could not load chapters.json.'); });
  }

  function build(ch, list) {
    var total = ch.pages;
    var cur = 1;
    var mode = get(K.mode) === 'page' ? 'page' : 'scroll';
    var meta = $('meta');
    var barTimer;

    document.title = 'Ch.' + ch.n + ' — ' + ch.title;

    var src = function (p) { return 'chapters/' + ch.slug + '/p' + pad(p) + '.jpg'; };
    var frag = document.createDocumentFragment();
    var els = [];
    for (var p = 1; p <= total; p++) {
      var d = document.createElement('div');
      d.className = 'page';
      d.dataset.p = p;
      d.appendChild(box(src(p), 'page ' + p, p > 2));
      els.push(d);
      frag.appendChild(d);
    }
    $('pages').appendChild(frag);

    // chapter nav from the manifest
    var idx = list.indexOf(ch);
    var nav = $('chnav');
    nav.innerHTML = '';
    [[list[idx - 1], '← Ch.'], [list[idx + 1], 'Ch.']].forEach(function (pair, j) {
      var c = pair[0], el;
      if (c) {
        el = document.createElement('a');
        el.href = 'read.html?ch=' + c.n;
        el.textContent = j ? 'Ch.' + c.n + ' →' : '← Ch.' + c.n;
      } else {
        el = document.createElement('span');
        el.textContent = j ? 'Latest chapter' : 'First chapter';
      }
      nav.appendChild(el);
    });
    nav.hidden = false;

    /* --- position --- */
    function mark(p, scroll) {
      if (p < 1) p = 1; if (p > total) p = total;
      cur = p;
      meta.textContent = 'Ch.' + ch.n + ' · p ' + p + '/' + total;
      history.replaceState(null, '', '#p' + pad(p));
      set(K.pos, JSON.stringify({ chapter: ch.n, page: p }));
      if (mode === 'page') {
        els.forEach(function (e, i) { e.classList.toggle('cur', i === p - 1); });
        document.body.classList.toggle('at-end', p === total);
        for (var j = p + 1; j <= Math.min(total, p + 2); j++) new Image().src = src(j);
      } else if (scroll) {
        els[p - 1].scrollIntoView({ block: 'start' });
      }
    }

    /* --- modes --- */
    function setMode(m, jump) {
      mode = m;
      set(K.mode, m);
      document.body.classList.toggle('mode-page', m === 'page');
      document.body.classList.toggle('mode-scroll', m === 'scroll');
      $('modeBtn').textContent = m === 'page' ? '☷' : '‖';
      $('modeBtn').title = m === 'page' ? 'Switch to vertical scroll' : 'Switch to page-by-page';
      document.body.classList.remove('at-end');
      if (m === 'scroll') { els.forEach(function (e) { e.classList.remove('cur'); }); }
      mark(jump || cur, m === 'scroll');
    }

    $('modeBtn').addEventListener('click', function () {
      setMode(mode === 'page' ? 'scroll' : 'page');
      showBar();
    });

    /* --- chrome --- */
    function showBar(sticky) {
      document.body.classList.add('bar');
      clearTimeout(barTimer);
      if (!sticky) barTimer = setTimeout(function () { document.body.classList.remove('bar'); }, 2600);
    }
    var lastY = 0;
    addEventListener('scroll', function () {
      var y = scrollY;
      if (y < lastY - 4 || y < 40) showBar(); else if (y > lastY + 4) { document.body.classList.remove('bar'); clearTimeout(barTimer); }
      lastY = y;
    }, { passive: true });

    /* --- taps / swipes / keys --- */
    var reader = $('reader');
    reader.addEventListener('click', function (e) {
      if (e.target.closest('a,button')) return;
      var z = e.clientX / innerWidth;
      if (mode === 'page' && z < 0.33) mark(cur - 1);
      else if (mode === 'page' && z > 0.67) mark(cur + 1);
      else showBar();
    });
    var x0 = 0, y0 = 0;
    reader.addEventListener('touchstart', function (e) {
      x0 = e.changedTouches[0].clientX; y0 = e.changedTouches[0].clientY;
    }, { passive: true });
    reader.addEventListener('touchend', function (e) {
      if (mode !== 'page') return;
      var dx = e.changedTouches[0].clientX - x0, dy = e.changedTouches[0].clientY - y0;
      if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy)) mark(cur + (dx < 0 ? 1 : -1));
    }, { passive: true });
    addEventListener('keydown', function (e) {
      if (mode !== 'page') return;
      if (e.key === 'ArrowRight' || e.key === 'PageDown' || e.key === ' ') mark(cur + 1);
      else if (e.key === 'ArrowLeft' || e.key === 'PageUp') mark(cur - 1);
      else return;
      e.preventDefault();
      showBar();
    });

    /* --- current page while scrolling --- */
    if ('IntersectionObserver' in window) {
      var io = new IntersectionObserver(function (entries) {
        if (mode !== 'scroll') return;
        entries.forEach(function (en) {
          if (en.isIntersecting) mark(+en.target.dataset.p);
        });
      }, { rootMargin: '-45% 0px -45% 0px' });
      els.forEach(function (e) { io.observe(e); });
    }

    /* --- restore: #pNN wins, else the saved position for this chapter --- */
    var hash = parseInt((location.hash.match(/^#p(\d+)$/) || [])[1], 10);
    var pos = savedPos();
    var start = hash || (pos && pos.chapter === ch.n ? pos.page : 1);
    setMode(mode, start);
    if (mode === 'scroll' && start > 1) {
      // wait for layout, then land silently on the page
      requestAnimationFrame(function () { els[start - 1].scrollIntoView({ block: 'start' }); });
    }
    showBar();

    addEventListener('hashchange', function () {
      var h = parseInt((location.hash.match(/^#p(\d+)$/) || [])[1], 10);
      if (h && h !== cur) mark(h, true);
    });
  }

  if (document.body.dataset.page === 'read') initReader(); else initIndex();
})();
