/* ==========================================================================
   SP GEMS — catalogue filtering, sorting and pagination
   Implements §19 (Search & Filtering) and §12.1 / §12.8 (listing behaviour).

   Every card is present in the HTML at page load, so with JavaScript disabled
   the catalogue is a complete, crawlable, readable grid — filtering is purely
   additive. In production this same filter state drives a server-rendered,
   Postgres-backed query (FR-SRCH-023); the URL contract is identical.
   ========================================================================== */
(function () {
  'use strict';

  var root = document.querySelector('[data-catalogue]');
  if (!root) return;

  var grid     = root.querySelector('[data-grid]');
  var cards    = Array.prototype.slice.call(grid.querySelectorAll('[data-stone]'));
  /* The count appears twice — in the results toolbar and in the mobile sticky
     filter bar, which sits outside the catalogue root — so both are updated. */
  var countEls = document.querySelectorAll('[data-count]');
  var appliedEl= root.querySelector('[data-applied]');
  var zeroEl   = root.querySelector('[data-zero]');
  var zeroWhy  = root.querySelector('[data-zero-why]');
  var relaxBtn = root.querySelector('[data-relax]');
  var pagerEl  = root.querySelector('[data-pager]');
  var sortEl   = root.querySelector('[data-sort]');
  var reduced  = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* Demo page size is 12 so pagination is visible with a 20-stone specimen
     catalogue. FR-CAT-007 specifies 24 in production. */
  var PAGE_SIZE = parseInt(root.getAttribute('data-page-size'), 10) || 12;

  /* Scope pre-applied by the page itself (e.g. /gemstones/ruby, /exceptional).
     Not user-removable and not shown as a chip. */
  var scope = {};
  try { scope = JSON.parse(root.getAttribute('data-scope') || '{}'); } catch (e) { scope = {}; }

  /* --- Filter definitions --------------------------------------------- */
  var LABELS = {
    type: 'Type', treatment: 'Treatment', band: 'Price', availability: 'Availability',
    origin: 'Origin', colour: 'Colour', shape: 'Shape', cert: 'Certification',
    clarity: 'Clarity', exceptional: 'Exceptional only', pairs: 'Matched pairs only',
    carat_min: 'Carat from', carat_max: 'Carat to'
  };
  var MULTI = ['type', 'band', 'origin', 'colour', 'shape', 'cert', 'clarity'];
  var SINGLE = ['treatment', 'availability'];
  var FLAGS = ['exceptional', 'pairs'];

  /* --- URL state (FR-SRCH-010) — every filtered view is shareable,
         bookmarkable and back-button correct. ---------------------------- */
  function readState() {
    var p = new URLSearchParams(window.location.search);
    var s = { page: parseInt(p.get('page'), 10) || 1, sort: p.get('sort') || 'curated' };
    MULTI.forEach(function (k) {
      var v = p.get(k);
      s[k] = v ? v.split(',').filter(Boolean) : [];
    });
    SINGLE.forEach(function (k) { s[k] = p.get(k) || ''; });
    FLAGS.forEach(function (k) { s[k] = p.get(k) === '1'; });
    s.carat_min = p.get('carat_min') || '';
    s.carat_max = p.get('carat_max') || '';
    return s;
  }

  function writeState(s, replace) {
    var p = new URLSearchParams();
    MULTI.forEach(function (k) { if (s[k] && s[k].length) p.set(k, s[k].join(',')); });
    SINGLE.forEach(function (k) { if (s[k]) p.set(k, s[k]); });
    FLAGS.forEach(function (k) { if (s[k]) p.set(k, '1'); });
    if (s.carat_min) p.set('carat_min', s.carat_min);
    if (s.carat_max) p.set('carat_max', s.carat_max);
    if (s.sort && s.sort !== 'curated') p.set('sort', s.sort);
    if (s.page > 1) p.set('page', String(s.page));
    var qs = p.toString();
    var url = window.location.pathname + (qs ? '?' + qs : '');
    if (replace) history.replaceState(null, '', url);
    else history.pushState(null, '', url);
  }

  var state = readState();

  /* --- Card accessors --------------------------------------------------- */
  function val(card, key) { return card.getAttribute('data-' + key) || ''; }
  function num(card, key) { return parseFloat(card.getAttribute('data-' + key)) || 0; }

  /* Does a card pass one dimension of the filter? Split out so that option
     counts can be computed with that dimension excluded (FR-SRCH-014). */
  function passes(card, s, skip) {
    // Page scope always applies
    for (var k in scope) {
      if (!Object.prototype.hasOwnProperty.call(scope, k)) continue;
      if (k === 'exceptional') { if (val(card, 'exceptional') !== '1') return false; continue; }
      if (k === 'availability_in') { if (scope[k].indexOf(val(card, 'availability')) < 0) return false; continue; }
      if (String(scope[k]) !== val(card, k)) return false;
    }

    // FR-CAT-006 — sold stones excluded from default results, surfaced under Archive
    if (skip !== 'availability') {
      if (s.availability === 'archive') { /* include everything */ }
      else if (s.availability === 'available') { if (val(card, 'availability') !== 'available') return false; }
      else if (!scope.availability_in && val(card, 'availability') === 'sold') return false;
    }

    if (skip !== 'type'       && s.type.length       && s.type.indexOf(val(card, 'type')) < 0) return false;
    if (skip !== 'band'       && s.band.length       && s.band.indexOf(val(card, 'band')) < 0) return false;
    if (skip !== 'origin'     && s.origin.length     && s.origin.indexOf(val(card, 'origin')) < 0) return false;
    if (skip !== 'colour'     && s.colour.length     && s.colour.indexOf(val(card, 'colour')) < 0) return false;
    if (skip !== 'shape'      && s.shape.length      && s.shape.indexOf(val(card, 'shape')) < 0) return false;
    if (skip !== 'clarity'    && s.clarity.length    && s.clarity.indexOf(val(card, 'clarity')) < 0) return false;
    if (skip !== 'cert'       && s.cert.length) {
      var lab = val(card, 'cert');
      var ok = s.cert.some(function (c) { return c === 'any' ? lab !== '' : c === lab; });
      if (!ok) return false;
    }
    // FR-SRCH-003 — treatment defaults to All, never to "unheated only"
    if (skip !== 'treatment'  && s.treatment && val(card, 'treatment') !== s.treatment) return false;
    if (skip !== 'exceptional'&& s.exceptional && val(card, 'exceptional') !== '1') return false;
    if (skip !== 'pairs'      && s.pairs && val(card, 'pairs') !== '1') return false;

    if (skip !== 'carat') {
      var c = num(card, 'carat');
      if (s.carat_min && c < parseFloat(s.carat_min)) return false;
      if (s.carat_max && c > parseFloat(s.carat_max)) return false;
    }
    return true;
  }

  /* --- Sorting (FR-CAT-008) — curated first, then newest ---------------- */
  var SORTS = {
    curated:    function (a, b) { return num(a, 'rank') - num(b, 'rank'); },
    newest:     function (a, b) { return num(b, 'added') - num(a, 'added'); },
    carat_asc:  function (a, b) { return num(a, 'carat') - num(b, 'carat'); },
    carat_desc: function (a, b) { return num(b, 'carat') - num(a, 'carat'); },
    price_asc:  function (a, b) { return num(a, 'bandrank') - num(b, 'bandrank'); },
    price_desc: function (a, b) { return num(b, 'bandrank') - num(a, 'bandrank'); }
  };

  /* --- Render ----------------------------------------------------------- */
  function render(pushUrl) {
    var matched = cards.filter(function (c) { return passes(c, state); });
    matched.sort(SORTS[state.sort] || SORTS.curated);

    var pages = Math.max(1, Math.ceil(matched.length / PAGE_SIZE));
    if (state.page > pages) state.page = pages;
    var start = (state.page - 1) * PAGE_SIZE;
    var visible = matched.slice(start, start + PAGE_SIZE);

    // Hide everything, then place the visible slice in sorted order
    cards.forEach(function (c) { c.hidden = true; });
    visible.forEach(function (c) { c.hidden = false; grid.appendChild(c); });

    // FR-SRCH-012 — count updates live and is announced via aria-live
    var countHtml = matched.length === 1 ? '<b>1</b> stone' : '<b>' + matched.length + '</b> stones';
    if (pages > 1) {
      countHtml += ' <span class="caption">· showing ' + (start + 1) + '–' +
        Math.min(start + PAGE_SIZE, matched.length) + '</span>';
    }
    countEls.forEach(function (el) { el.innerHTML = countHtml; });

    renderApplied();
    renderCounts();
    renderPager(pages);

    if (zeroEl) {
      zeroEl.hidden = matched.length !== 0;
      grid.hidden = matched.length === 0;
      if (matched.length === 0) diagnoseZero();
    }
    if (pushUrl) writeState(state, pushUrl === 'replace');
    syncControls();
  }

  /* FR-SRCH-015 — applied filters as removable chips, plus Clear all */
  function renderApplied() {
    if (!appliedEl) return;
    var chips = [];
    MULTI.forEach(function (k) {
      state[k].forEach(function (v) { chips.push({ k: k, v: v, label: LABELS[k] + ': ' + pretty(k, v) }); });
    });
    SINGLE.forEach(function (k) {
      if (state[k]) chips.push({ k: k, v: state[k], label: LABELS[k] + ': ' + pretty(k, state[k]) });
    });
    FLAGS.forEach(function (k) { if (state[k]) chips.push({ k: k, v: '1', label: LABELS[k] }); });
    if (state.carat_min) chips.push({ k: 'carat_min', v: '', label: 'From ' + state.carat_min + ' ct' });
    if (state.carat_max) chips.push({ k: 'carat_max', v: '', label: 'To ' + state.carat_max + ' ct' });

    appliedEl.hidden = chips.length === 0;
    if (!chips.length) { appliedEl.innerHTML = ''; return; }

    appliedEl.innerHTML = chips.map(function (c) {
      return '<span class="achip">' + esc(c.label) +
        '<button type="button" data-remove="' + c.k + '" data-val="' + esc(c.v) + '" ' +
        'aria-label="Remove filter ' + esc(c.label) + '">&times;</button></span>';
    }).join('') +
      '<button type="button" class="link" data-clear-all style="margin-left:8px">Clear all</button>';

    appliedEl.querySelectorAll('[data-remove]').forEach(function (b) {
      b.addEventListener('click', function () {
        var k = b.getAttribute('data-remove'), v = b.getAttribute('data-val');
        if (MULTI.indexOf(k) >= 0) state[k] = state[k].filter(function (x) { return x !== v; });
        else if (FLAGS.indexOf(k) >= 0) state[k] = false;
        else state[k] = '';
        state.page = 1;
        render(true);
      });
    });
    var ca = appliedEl.querySelector('[data-clear-all]');
    if (ca) ca.addEventListener('click', clearAll);
  }

  function clearAll() {
    MULTI.forEach(function (k) { state[k] = []; });
    SINGLE.forEach(function (k) { state[k] = ''; });
    FLAGS.forEach(function (k) { state[k] = false; });
    state.carat_min = ''; state.carat_max = ''; state.page = 1;
    render(true);
  }

  /* FR-SRCH-013/014 — every option shows its count; zero-result options are
     disabled and left visible, never hidden. */
  function renderCounts() {
    root.querySelectorAll('[data-filter]').forEach(function (input) {
      var k = input.getAttribute('data-filter');
      var v = input.value;
      var probe = Object.assign({}, state);
      if (MULTI.indexOf(k) >= 0) probe[k] = [v];
      else if (FLAGS.indexOf(k) >= 0) probe[k] = true;
      else probe[k] = v;

      var n = cards.filter(function (c) { return passes(c, probe, null); }).length;
      var host = input.closest('.fopt, .swatch, .shape, .chip');
      if (host) {
        var badge = host.querySelector('.fopt__n');
        if (badge) badge.textContent = n;
        var empty = n === 0 && !input.checked;
        host.classList.toggle('is-empty', empty);
        input.disabled = empty;
      }
    });
  }

  /* FR-SRCH-016 — a zero-result page is a lead-capture opportunity, not a
     dead end: name the most constraining filter and offer one-click relief. */
  function diagnoseZero() {
    var keys = [].concat(MULTI, SINGLE, FLAGS, ['carat']);
    var best = null, bestN = -1;
    keys.forEach(function (k) {
      var active = (MULTI.indexOf(k) >= 0) ? state[k].length
                 : (k === 'carat') ? (state.carat_min || state.carat_max ? 1 : 0)
                 : (FLAGS.indexOf(k) >= 0) ? (state[k] ? 1 : 0) : (state[k] ? 1 : 0);
      if (!active) return;
      var n = cards.filter(function (c) { return passes(c, state, k); }).length;
      if (n > bestN) { bestN = n; best = k; }
    });
    if (!best || bestN <= 0) {
      if (zeroWhy) zeroWhy.textContent = 'No stones match this combination of filters.';
      if (relaxBtn) relaxBtn.hidden = true;
      return;
    }
    var name = best === 'carat' ? 'carat range' : (LABELS[best] || best).toLowerCase();
    if (zeroWhy) {
      zeroWhy.textContent = 'The ' + name + ' filter is the most constraining. ' +
        'Relaxing it would show ' + bestN + (bestN === 1 ? ' stone.' : ' stones.');
    }
    if (relaxBtn) {
      relaxBtn.hidden = false;
      relaxBtn.textContent = 'Clear the ' + name + ' filter';
      relaxBtn.onclick = function () {
        if (best === 'carat') { state.carat_min = ''; state.carat_max = ''; }
        else if (MULTI.indexOf(best) >= 0) state[best] = [];
        else if (FLAGS.indexOf(best) >= 0) state[best] = false;
        else state[best] = '';
        state.page = 1;
        render(true);
      };
    }
  }

  /* FR-CAT-007 — real pagination with a ?page= parameter, not infinite scroll */
  function renderPager(pages) {
    if (!pagerEl) return;
    pagerEl.hidden = pages < 2;
    if (pages < 2) { pagerEl.innerHTML = ''; return; }
    var html = '<a href="#" class="' + (state.page === 1 ? 'is-off' : '') + '" rel="prev" data-page="' +
               (state.page - 1) + '" aria-label="Previous page">&larr;</a>';
    for (var i = 1; i <= pages; i++) {
      html += i === state.page
        ? '<span aria-current="page">' + i + '</span>'
        : '<a href="#" data-page="' + i + '">' + i + '</a>';
    }
    html += '<a href="#" class="' + (state.page === pages ? 'is-off' : '') + '" rel="next" data-page="' +
            (state.page + 1) + '" aria-label="Next page">&rarr;</a>';
    pagerEl.innerHTML = html;
    pagerEl.querySelectorAll('[data-page]').forEach(function (a) {
      a.addEventListener('click', function (e) {
        e.preventDefault();
        state.page = parseInt(a.getAttribute('data-page'), 10);
        render(true);
        grid.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'start' });
      });
    });
  }

  /* --- Control wiring --------------------------------------------------- */
  function syncControls() {
    root.querySelectorAll('[data-filter]').forEach(function (input) {
      var k = input.getAttribute('data-filter'), v = input.value;
      if (MULTI.indexOf(k) >= 0) input.checked = state[k].indexOf(v) >= 0;
      else if (FLAGS.indexOf(k) >= 0) input.checked = !!state[k];
      else input.checked = state[k] === v;
    });
    var mn = root.querySelector('[data-carat-min]');
    var mx = root.querySelector('[data-carat-max]');
    if (mn && document.activeElement !== mn) mn.value = state.carat_min;
    if (mx && document.activeElement !== mx) mx.value = state.carat_max;
    if (sortEl) sortEl.value = state.sort;
  }

  // FR-SRCH-011 — filters apply on selection; no Apply button on desktop
  root.querySelectorAll('[data-filter]').forEach(function (input) {
    input.addEventListener('change', function () {
      var k = input.getAttribute('data-filter'), v = input.value;
      if (MULTI.indexOf(k) >= 0) {
        if (input.checked) { if (state[k].indexOf(v) < 0) state[k].push(v); }
        else state[k] = state[k].filter(function (x) { return x !== v; });
      } else if (FLAGS.indexOf(k) >= 0) {
        state[k] = input.checked;
      } else {
        state[k] = input.checked ? v : '';
      }
      state.page = 1;
      render(true);
    });
  });

  ['[data-carat-min]', '[data-carat-max]'].forEach(function (sel, idx) {
    var el = root.querySelector(sel);
    if (!el) return;
    el.addEventListener('change', function () {
      state[idx === 0 ? 'carat_min' : 'carat_max'] = el.value;
      state.page = 1;
      render(true);
    });
  });

  if (sortEl) sortEl.addEventListener('change', function () {
    state.sort = sortEl.value; state.page = 1; render(true);
  });

  /* FR-SRCH-002 — advanced panel state persisted per visitor */
  var adv = root.querySelector('[data-advanced]');
  if (adv) {
    var advBody = adv.querySelector('.fadv__body');
    var advBtn  = adv.querySelector('.fadv__toggle');
    var open = false;
    try { open = localStorage.getItem('spgems.filters.advanced') === '1'; } catch (e) {}
    function setAdv(v) {
      open = v;
      if (advBody) advBody.hidden = !v;
      if (advBtn) {
        advBtn.setAttribute('aria-expanded', v ? 'true' : 'false');
        var t = advBtn.querySelector('span');
        if (t) t.textContent = v ? 'Fewer filters' : 'More filters';
      }
      try { localStorage.setItem('spgems.filters.advanced', v ? '1' : '0'); } catch (e) {}
    }
    setAdv(open);
    if (advBtn) advBtn.addEventListener('click', function () { setAdv(!open); });
  }

  /* Collapsible filter groups */
  root.querySelectorAll('.fgroup__h').forEach(function (h) {
    h.addEventListener('click', function () {
      var isOpen = h.getAttribute('aria-expanded') === 'true';
      h.setAttribute('aria-expanded', isOpen ? 'false' : 'true');
      var body = document.getElementById(h.getAttribute('aria-controls'));
      if (body) body.hidden = isOpen;
    });
  });

  /* FR-MOB-012 — filters open in a full-screen sheet with an explicit
     "Show N results" button and a Clear all action. */
  var sheet = root.querySelector('.filters');
  /* The sticky mobile filter bar sits outside the catalogue root, above it in
     the document, so its trigger is looked up document-wide. */
  var openSheet = document.querySelector('[data-open-filters]');
  var showBtn = root.querySelector('[data-show-results]');
  function setSheet(v) {
    if (!sheet) return;
    sheet.classList.toggle('is-open', v);
    document.body.classList.toggle('is-locked', v);
    if (openSheet) openSheet.setAttribute('aria-expanded', v ? 'true' : 'false');
  }
  if (openSheet) openSheet.addEventListener('click', function () { setSheet(true); });
  root.querySelectorAll('[data-close-filters]').forEach(function (b) {
    b.addEventListener('click', function () { setSheet(false); });
  });
  if (showBtn) {
    var updateShow = function () {
      var n = cards.filter(function (c) { return passes(c, state); }).length;
      showBtn.textContent = 'Show ' + n + (n === 1 ? ' result' : ' results');
    };
    root.addEventListener('change', updateShow);
    showBtn.addEventListener('click', function () { setSheet(false); });
    updateShow();
    var _render = render;
    render = function () { _render.apply(null, arguments); updateShow(); };
  }
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && sheet && sheet.classList.contains('is-open')) setSheet(false);
  });

  /* FR-MOB-010 — single-column toggle, persisted in localStorage */
  var colBtns = root.querySelectorAll('[data-cols]');
  if (colBtns.length) {
    var apply = function (mode) {
      grid.classList.toggle('is-single-col', mode === '1');
      colBtns.forEach(function (b) {
        b.setAttribute('aria-pressed', b.getAttribute('data-cols') === mode ? 'true' : 'false');
      });
      try { localStorage.setItem('spgems.catalogue.cols', mode); } catch (e) {}
    };
    var saved = '2';
    try { saved = localStorage.getItem('spgems.catalogue.cols') || '2'; } catch (e) {}
    apply(saved);
    colBtns.forEach(function (b) {
      b.addEventListener('click', function () { apply(b.getAttribute('data-cols')); });
    });
  }

  /* Back/forward must restore the filtered view (FR-SRCH-010) */
  window.addEventListener('popstate', function () { state = readState(); render(false); });

  /* --- Helpers ---------------------------------------------------------- */
  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function pretty(k, v) {
    var el = root.querySelector('[data-filter="' + k + '"][value="' + v + '"]');
    if (el) {
      var host = el.closest('.fopt, .swatch, .shape, .chip');
      if (host) {
        var t = host.querySelector('[data-label]');
        if (t) return t.textContent.trim();
        var clone = host.cloneNode(true);
        var n = clone.querySelector('.fopt__n');
        if (n) n.remove();
        return clone.textContent.trim();
      }
    }
    return v;
  }

  render('replace');
})();
