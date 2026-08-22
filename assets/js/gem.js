/* ==========================================================================
   SP GEMS — gemstone / jewellery detail behaviour
   §13.8 (high-resolution viewer), §26A.4 (mobile detail page).

   In this demo the "high-resolution asset" is the specimen plate, so the
   viewer demonstrates the full interaction contract — zoom, pan, keyboard
   navigation, focus management — against placeholder media. Swapping in real
   <img srcset> assets requires no change to this file.
   ========================================================================== */
(function () {
  'use strict';

  var page = document.querySelector('[data-detail]');
  if (!page) return;

  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* --- Media set -------------------------------------------------------- */
  var slots = Array.prototype.slice.call(page.querySelectorAll('[data-media-item]'));
  var hero  = page.querySelector('[data-hero]');
  var thumbs= Array.prototype.slice.call(page.querySelectorAll('[data-thumb]'));
  var index = 0;

  function mediaHTML(i) {
    var src = slots[i];
    return src ? src.innerHTML : '';
  }
  function mediaCaption(i) {
    var src = slots[i];
    return src ? (src.getAttribute('data-caption') || '') : '';
  }

  function showIndex(i) {
    if (i < 0 || i >= slots.length) return;
    index = i;
    if (hero) hero.innerHTML = mediaHTML(i);
    thumbs.forEach(function (t, k) {
      t.setAttribute('aria-current', k === i ? 'true' : 'false');
    });
  }

  thumbs.forEach(function (t, i) {
    t.addEventListener('click', function () { showIndex(i); });
  });
  if (slots.length) showIndex(0);

  /* --- Fullscreen viewer (FR-VIEW-001…007) ----------------------------- */
  var viewer = document.getElementById('viewer');
  if (viewer) {
    var stage   = viewer.querySelector('[data-stage]');
    var holder  = viewer.querySelector('[data-holder]');
    var counter = viewer.querySelector('[data-vcount]');
    var capEl   = viewer.querySelector('[data-vcap]');
    var zoomOut = viewer.querySelector('[data-zoom-out]');
    var zoomIn  = viewer.querySelector('[data-zoom-in]');
    var zoomLbl = viewer.querySelector('[data-zoom-label]');
    var vIndex = 0, scale = 1, tx = 0, ty = 0, lastFocus = null;
    var MIN = 1, MAX = 4;

    function paint() {
      if (holder) {
        holder.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + scale + ')';
      }
      if (stage) stage.classList.toggle('is-zoomed', scale > 1);
      if (zoomLbl) zoomLbl.textContent = Math.round(scale * 100) + '%';
      if (zoomOut) zoomOut.disabled = scale <= MIN + 0.001;
      if (zoomIn)  zoomIn.disabled  = scale >= MAX - 0.001;
    }
    function setScale(next, originX, originY) {
      var prev = scale;
      scale = Math.max(MIN, Math.min(MAX, next));
      if (scale === MIN) { tx = 0; ty = 0; }
      else if (originX != null && stage) {
        // Keep the pointed-at point stationary while zooming
        var r = stage.getBoundingClientRect();
        var cx = originX - r.left - r.width / 2;
        var cy = originY - r.top - r.height / 2;
        var k = scale / prev;
        tx = cx - (cx - tx) * k;
        ty = cy - (cy - ty) * k;
      }
      clampPan();
      paint();
    }
    function clampPan() {
      if (!stage || scale <= 1) { tx = 0; ty = 0; return; }
      var r = stage.getBoundingClientRect();
      var maxX = (r.width  * (scale - 1)) / 2;
      var maxY = (r.height * (scale - 1)) / 2;
      tx = Math.max(-maxX, Math.min(maxX, tx));
      ty = Math.max(-maxY, Math.min(maxY, ty));
    }

    function load(i) {
      vIndex = (i + slots.length) % slots.length;
      /* FR-VIEW-006 — opens using the already-loaded media, never blocking on
         a high-resolution fetch. In production the full-resolution asset is
         then swapped in progressively. */
      if (holder) holder.innerHTML = mediaHTML(vIndex);
      if (counter) counter.textContent = (vIndex + 1) + ' / ' + slots.length;
      if (capEl) capEl.textContent = mediaCaption(vIndex);
      scale = 1; tx = 0; ty = 0;
      paint();
    }

    function open(i) {
      lastFocus = document.activeElement;
      viewer.classList.add('is-open');
      document.body.classList.add('is-locked');
      load(i);
      var c = viewer.querySelector('[data-vclose]');
      if (c) c.focus();
    }
    function close() {
      viewer.classList.remove('is-open');
      document.body.classList.remove('is-locked');
      showIndex(vIndex);                      // keep the page in sync
      if (lastFocus && lastFocus.focus) lastFocus.focus();  // FR-VIEW-005
    }

    // FR-VIEW-001 — open on click/tap, or via keyboard on a focused image
    page.querySelectorAll('[data-open-viewer]').forEach(function (el) {
      var i = parseInt(el.getAttribute('data-open-viewer'), 10) || 0;
      el.addEventListener('click', function () { open(i); });
      el.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(i); }
      });
    });

    viewer.querySelectorAll('[data-vclose]').forEach(function (b) { b.addEventListener('click', close); });
    var prev = viewer.querySelector('[data-vprev]');
    var next = viewer.querySelector('[data-vnext]');
    if (prev) prev.addEventListener('click', function () { load(vIndex - 1); });
    if (next) next.addEventListener('click', function () { load(vIndex + 1); });
    if (zoomIn)  zoomIn.addEventListener('click',  function () { setScale(scale + 0.5); });
    if (zoomOut) zoomOut.addEventListener('click', function () { setScale(scale - 0.5); });

    // FR-VIEW-002 — scroll wheel zoom
    if (stage) {
      stage.addEventListener('wheel', function (e) {
        if (!viewer.classList.contains('is-open')) return;
        e.preventDefault();
        setScale(scale + (e.deltaY < 0 ? 0.28 : -0.28), e.clientX, e.clientY);
      }, { passive: false });

      // FR-VIEW-002 — double-tap / double-click zoom
      stage.addEventListener('dblclick', function (e) {
        setScale(scale > 1 ? 1 : 2.2, e.clientX, e.clientY);
      });

      // FR-VIEW-003 — pan by drag
      var dragging = false, sx = 0, sy = 0, ox = 0, oy = 0;
      stage.addEventListener('pointerdown', function (e) {
        if (scale <= 1) return;
        dragging = true; sx = e.clientX; sy = e.clientY; ox = tx; oy = ty;
        stage.classList.add('is-panning');
        stage.setPointerCapture(e.pointerId);
      });
      stage.addEventListener('pointermove', function (e) {
        if (!dragging) return;
        tx = ox + (e.clientX - sx);
        ty = oy + (e.clientY - sy);
        clampPan(); paint();
      });
      var endDrag = function () { dragging = false; stage.classList.remove('is-panning'); };
      stage.addEventListener('pointerup', endDrag);
      stage.addEventListener('pointercancel', endDrag);

      // FR-VIEW-002 — pinch zoom
      var pinch = null;
      stage.addEventListener('touchstart', function (e) {
        if (e.touches.length !== 2) return;
        pinch = { d: dist(e.touches), s: scale };
      }, { passive: true });
      stage.addEventListener('touchmove', function (e) {
        if (!pinch || e.touches.length !== 2) return;
        e.preventDefault();
        setScale(pinch.s * (dist(e.touches) / pinch.d));
      }, { passive: false });
      stage.addEventListener('touchend', function () { pinch = null; });
      function dist(t) {
        var dx = t[0].clientX - t[1].clientX, dy = t[0].clientY - t[1].clientY;
        return Math.hypot(dx, dy) || 1;
      }

      // FR-VIEW-004 — swipe between images when not zoomed
      var swipe = null;
      stage.addEventListener('touchstart', function (e) {
        if (e.touches.length !== 1 || scale > 1) { swipe = null; return; }
        swipe = { x: e.touches[0].clientX, y: e.touches[0].clientY };
      }, { passive: true });
      stage.addEventListener('touchend', function (e) {
        if (!swipe || !e.changedTouches.length) return;
        var dx = e.changedTouches[0].clientX - swipe.x;
        var dy = e.changedTouches[0].clientY - swipe.y;
        if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy)) load(vIndex + (dx < 0 ? 1 : -1));
        swipe = null;
      });
    }

    // FR-VIEW-003/004/005 — keyboard: arrows navigate and pan, Escape closes
    document.addEventListener('keydown', function (e) {
      if (!viewer.classList.contains('is-open')) return;
      var step = 60;
      switch (e.key) {
        case 'Escape': e.preventDefault(); close(); break;
        case 'ArrowRight':
          e.preventDefault();
          if (scale > 1) { tx -= step; clampPan(); paint(); } else load(vIndex + 1);
          break;
        case 'ArrowLeft':
          e.preventDefault();
          if (scale > 1) { tx += step; clampPan(); paint(); } else load(vIndex - 1);
          break;
        case 'ArrowUp':   if (scale > 1) { e.preventDefault(); ty += step; clampPan(); paint(); } break;
        case 'ArrowDown': if (scale > 1) { e.preventDefault(); ty -= step; clampPan(); paint(); } break;
        case '+': case '=': e.preventDefault(); setScale(scale + 0.5); break;
        case '-': case '_': e.preventDefault(); setScale(scale - 0.5); break;
        case '0': e.preventDefault(); setScale(1); break;
      }
    });

    // FR-VIEW-005 — focus stays inside the viewer while it is open
    viewer.addEventListener('keydown', function (e) {
      if (e.key !== 'Tab') return;
      var f = viewer.querySelectorAll('button:not([disabled])');
      if (!f.length) return;
      var first = f[0], last = f[f.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    });
  }

  /* --- Mobile carousel dots and counter (FR-MOB-020) ------------------- */
  var track = page.querySelector('[data-track]');
  if (track) {
    var dots = page.querySelectorAll('[data-dots] i');
    var mcount = page.querySelector('[data-mcount]');
    var onScroll = function () {
      // clientWidth is 0 while the carousel is display:none on desktop
      var w = track.clientWidth;
      var i = w > 0 ? Math.round(track.scrollLeft / w) : 0;
      dots.forEach(function (d, k) { d.classList.toggle('is-on', k === i); });
      if (mcount) mcount.textContent = (i + 1) + ' / ' + dots.length;
    };
    track.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  /* --- Sticky mobile action bar (FR-MOB-021) ---------------------------
         Appears once the visitor has scrolled past the initial media block.
         The single highest-impact mobile conversion element.               */
  var abar = document.querySelector('.abar');
  var anchor = page.querySelector('[data-abar-after]');
  if (abar && anchor) {
    /* Scroll position rather than IntersectionObserver: this is the highest
       -impact mobile conversion element, and it must not depend on an observer
       that can fail to fire in a background tab or an embedded view. */
    var syncBar = function () {
      var bottom = anchor.getBoundingClientRect().bottom;
      abar.classList.toggle('is-visible', bottom < 0);
    };
    window.addEventListener('scroll', syncBar, { passive: true });
    window.addEventListener('resize', syncBar, { passive: true });
    syncBar();
  }
})();
