/* ==========================================================================
   SP GEMS — shared site behaviour
   Progressive enhancement only. FR-HOME-013: the site renders usefully with
   JavaScript disabled; nothing here is required to read a page or follow a
   link. Every form also carries a working non-JS submission path.
   ========================================================================== */
(function () {
  'use strict';

  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* --- Footer copyright — §29 s.12: rendered dynamically so it can never
         go stale the way "All right reserved 2015" did. ------------------- */
  document.querySelectorAll('[data-year]').forEach(function (el) {
    el.textContent = new Date().getFullYear();
  });

  /* --- Header: condense on scroll (FR-MOB-001) ------------------------- */
  var hdr = document.querySelector('.hdr');
  if (hdr) {
    var onScroll = function () {
      hdr.classList.toggle('is-scrolled', window.scrollY > 8);
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
  }

  /* --- Mega-menu (§9.3) -----------------------------------------------
         Opens on hover for pointers and on click/Enter for keyboard and
         touch. FR-MOB-003 forbids hover-only behaviour, so the trigger is a
         real <a> that still navigates if scripting is off.                 */
  var openItem = null;
  function closeMega() {
    if (!openItem) return;
    openItem.classList.remove('is-open');
    var t = openItem.querySelector('.nav__link');
    if (t) t.setAttribute('aria-expanded', 'false');
    openItem = null;
  }
  function openMega(item) {
    if (openItem === item) return;
    closeMega();
    openItem = item;
    item.classList.add('is-open');
    var t = item.querySelector('.nav__link');
    if (t) t.setAttribute('aria-expanded', 'true');
  }

  document.querySelectorAll('.nav__item').forEach(function (item) {
    if (!item.querySelector('.mega')) return;
    var trigger = item.querySelector('.nav__link');
    if (trigger) trigger.setAttribute('aria-expanded', 'false');

    var hoverTimer;
    item.addEventListener('mouseenter', function () {
      if (!window.matchMedia('(hover: hover)').matches) return;
      clearTimeout(hoverTimer);
      openMega(item);
    });
    item.addEventListener('mouseleave', function () {
      if (!window.matchMedia('(hover: hover)').matches) return;
      hoverTimer = setTimeout(closeMega, 140);
    });
    // Keyboard / touch: the trigger toggles rather than navigating straight away
    if (trigger) {
      trigger.addEventListener('click', function (e) {
        if (openItem !== item) { e.preventDefault(); openMega(item); }
      });
    }
    item.addEventListener('focusout', function (e) {
      if (!item.contains(e.relatedTarget)) closeMega();
    });
  });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeMega(); });
  document.addEventListener('click', function (e) {
    if (openItem && !openItem.contains(e.target)) closeMega();
  });

  /* --- Mobile overlay nav (FR-MOB-002) -------------------------------- */
  var mnav = document.getElementById('mnav');
  var burger = document.querySelector('.hdr__burger');
  function setMnav(open) {
    if (!mnav) return;
    mnav.classList.toggle('is-open', open);
    document.body.classList.toggle('is-locked', open);
    if (burger) burger.setAttribute('aria-expanded', open ? 'true' : 'false');
    if (open) {
      var f = mnav.querySelector('a, button');
      if (f) f.focus();
    } else if (burger) { burger.focus(); }
  }
  if (burger) burger.addEventListener('click', function () { setMnav(!mnav.classList.contains('is-open')); });
  var mclose = document.querySelector('.mnav__close');
  if (mclose) mclose.addEventListener('click', function () { setMnav(false); });
  if (mnav) {
    mnav.querySelectorAll('.mnav__row[aria-expanded]').forEach(function (row) {
      row.addEventListener('click', function () {
        var open = row.getAttribute('aria-expanded') === 'true';
        row.setAttribute('aria-expanded', open ? 'false' : 'true');
        var sub = document.getElementById(row.getAttribute('aria-controls'));
        if (sub) sub.classList.toggle('is-open', !open);
      });
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && mnav.classList.contains('is-open')) setMnav(false);
    });
  }

  /* --- Reveal on scroll (§28.6: fade + 24px translate, 80ms stagger,
         maximum six items) ------------------------------------------------ */
  var reveals = document.querySelectorAll('[data-reveal]');
  if (reveals.length) {
    if (reduced || !('IntersectionObserver' in window)) {
      reveals.forEach(function (el) { el.classList.add('is-in'); });
    } else {
      var io = new IntersectionObserver(function (entries) {
        var n = 0;
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var delay = Math.min(n, 5) * 80;
          n++;
          setTimeout(function () { entry.target.classList.add('is-in'); }, delay);
          io.unobserve(entry.target);
        });
      }, { rootMargin: '0px 0px -8% 0px', threshold: 0.06 });
      reveals.forEach(function (el) { io.observe(el); });

      /* Failsafe. If the observer never fires — a hidden tab, an embedded
         preview, a browser quirk — the content must not stay invisible. */
      setTimeout(function () {
        reveals.forEach(function (el) { el.classList.add('is-in'); });
      }, 2500);
    }
  }

  /* --- Glossary disclosures (FR-GEM-056) ------------------------------
         Button + popover. Keyboard operable, dismissible on Escape.
         Never hover-only: that fails on touch and for keyboard users.      */
  var openPop = null;
  function closePop() {
    if (!openPop) return;
    openPop.pop.hidden = true;
    openPop.btn.setAttribute('aria-expanded', 'false');
    openPop = null;
  }
  document.querySelectorAll('.gloss').forEach(function (g) {
    var btn = g.querySelector('.gloss__btn');
    var pop = g.querySelector('.gloss__pop');
    if (!btn || !pop) return;
    btn.setAttribute('aria-expanded', 'false');
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      var isOpen = !pop.hidden;
      closePop();
      if (!isOpen) {
        pop.hidden = false;
        btn.setAttribute('aria-expanded', 'true');
        openPop = { pop: pop, btn: btn };
      }
    });
  });
  document.addEventListener('click', function (e) {
    if (openPop && !openPop.pop.parentNode.contains(e.target)) closePop();
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && openPop) { var b = openPop.btn; closePop(); b.focus(); }
  });

  /* --- Enquiry modal (FR-GEM-051) -------------------------------------
         The primary CTA opens a modal pre-populated with the item's ID,
         title and URL rather than navigating away to a generic contact
         page — navigating away loses context and reduces completion.       */
  var modal = document.getElementById('enquiry-modal');
  var lastFocus = null;

  function fillContext(trigger) {
    if (!modal) return;
    var id = trigger.getAttribute('data-item-id') || '';
    var title = trigger.getAttribute('data-item-title') || '';
    var meta = trigger.getAttribute('data-item-meta') || '';
    var kind = trigger.getAttribute('data-item-kind') || 'general';

    var ctx = modal.querySelector('[data-ctx]');
    if (ctx) {
      ctx.hidden = !id;
      var t = ctx.querySelector('[data-ctx-title]');
      var m = ctx.querySelector('[data-ctx-meta]');
      var i = ctx.querySelector('[data-ctx-id]');
      if (t) t.textContent = title;
      if (m) m.textContent = meta;
      if (i) i.textContent = id;
    }
    var set = function (name, value) {
      var f = modal.querySelector('[name="' + name + '"]');
      if (f) f.value = value;
    };
    set('item_id', id);
    set('item_title', title);
    set('item_url', id ? window.location.href : '');
    set('enquiry_type', kind);

    var heading = modal.querySelector('[data-modal-title]');
    if (heading) {
      heading.textContent = id ? 'Enquire about this ' + (kind === 'jewellery' ? 'piece' : 'stone')
                               : 'Make an enquiry';
    }
    var msg = modal.querySelector('[name="message"]');
    if (msg && id && !msg.value) {
      msg.value = 'I would like more information about ' + title + ' (' + id + ').';
    }
  }

  function openModal(trigger) {
    if (!modal) return;
    lastFocus = trigger || document.activeElement;
    fillContext(trigger || document.createElement('button'));
    modal.classList.add('is-open');
    document.body.classList.add('is-locked');
    var first = modal.querySelector('.modal__close');
    if (first) first.focus();
  }
  function closeModal() {
    if (!modal) return;
    modal.classList.remove('is-open');
    document.body.classList.remove('is-locked');
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }

  document.querySelectorAll('[data-enquire]').forEach(function (btn) {
    btn.addEventListener('click', function (e) {
      if (!modal) return;             // no modal on this page: let the href work
      e.preventDefault();
      openModal(btn);
    });
  });
  if (modal) {
    modal.querySelectorAll('.modal__close, .modal__scrim').forEach(function (el) {
      el.addEventListener('click', closeModal);
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && modal.classList.contains('is-open')) closeModal();
    });
    // Focus trap
    modal.addEventListener('keydown', function (e) {
      if (e.key !== 'Tab') return;
      var f = modal.querySelectorAll('a[href], button:not([disabled]), input:not([type="hidden"]), select, textarea');
      if (!f.length) return;
      var first = f[0], last = f[f.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    });
  }

  /* --- Forms ----------------------------------------------------------
         Demo behaviour: no backend exists, so submission renders the
         confirmation state described in §15.2 / §16.3 with a reference
         number, and logs the payload. In production these post to the
         inquiry API (§34) and the reference is server-issued.              */
  function refNumber(prefix) {
    var y = new Date().getFullYear();
    var n = String(Math.floor(1000 + Math.random() * 8999)).slice(0, 4);
    return prefix + '-' + y + '-' + n;
  }

  document.querySelectorAll('form[data-demo-form]').forEach(function (form) {
    // FR-UI: inline validation on blur, never on keystroke (§28.5 Forms)
    form.querySelectorAll('.input[required]').forEach(function (input) {
      input.addEventListener('blur', function () {
        var field = input.closest('.field');
        if (!field) return;
        field.classList.toggle('is-invalid', !input.checkValidity());
      });
    });

    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var bad = null;
      form.querySelectorAll('.input[required], input[required]').forEach(function (input) {
        var ok = input.checkValidity();
        var field = input.closest('.field') || input.closest('.consent');
        if (field) field.classList.toggle('is-invalid', !ok);
        if (!ok && !bad) bad = input;
      });
      if (bad) { bad.focus(); return; }

      var prefix = form.getAttribute('data-ref-prefix') || 'ENQ';
      var ref = refNumber(prefix);
      var payload = {};
      new FormData(form).forEach(function (v, k) { payload[k] = v; });
      /* eslint-disable no-console */
      console.log('[SP Gems demo] ' + prefix + ' submission — no data is sent anywhere.', ref, payload);

      var done = form.parentNode.querySelector('[data-form-done]');
      if (done) {
        var refEl = done.querySelector('[data-ref]');
        if (refEl) refEl.textContent = ref;
        form.hidden = true;
        var steps = form.parentNode.querySelector('.steps');
        if (steps) steps.hidden = true;
        done.hidden = false;
        done.setAttribute('tabindex', '-1');
        done.focus();
        done.scrollIntoView({ block: 'center', behavior: reduced ? 'auto' : 'smooth' });
      }
    });
  });

  /* --- Multi-step forms (§15.2 bespoke, §16.3 consultation) ------------
         FR-BSP-001: every step before contact details is skippable.
         FR-BSP-002: state persists so a back-navigation does not lose work.
         FR-BSP-003: without JS all steps render at once and still submit.   */
  document.querySelectorAll('[data-steps]').forEach(function (host) {
    var steps = Array.prototype.slice.call(host.querySelectorAll('.fstep'));
    var pips  = Array.prototype.slice.call(host.querySelectorAll('.steps__i'));
    if (steps.length < 2) return;
    var key = 'spgems.form.' + (host.getAttribute('data-steps') || 'x');
    var i = 0;

    function show(n) {
      i = Math.max(0, Math.min(steps.length - 1, n));
      steps.forEach(function (s, k) { s.hidden = k !== i; });
      pips.forEach(function (p, k) {
        p.classList.toggle('is-active', k === i);
        p.classList.toggle('is-done', k < i);
      });
      var h = steps[i].querySelector('h2, h3, legend');
      if (h) { h.setAttribute('tabindex', '-1'); h.focus({ preventScroll: true }); }
      host.scrollIntoView({ block: 'nearest', behavior: reduced ? 'auto' : 'smooth' });
    }
    host.querySelectorAll('[data-step-next]').forEach(function (b) {
      b.addEventListener('click', function () { save(); show(i + 1); });
    });
    host.querySelectorAll('[data-step-prev]').forEach(function (b) {
      b.addEventListener('click', function () { show(i - 1); });
    });
    host.querySelectorAll('[data-step-go]').forEach(function (b) {
      b.addEventListener('click', function () { save(); show(parseInt(b.getAttribute('data-step-go'), 10)); });
    });

    function save() {
      try {
        var form = host.querySelector('form');
        if (!form) return;
        var d = {};
        new FormData(form).forEach(function (v, k) { d[k] = v; });
        sessionStorage.setItem(key, JSON.stringify(d));
      } catch (err) { /* private mode */ }
    }
    function restore() {
      try {
        var raw = sessionStorage.getItem(key);
        if (!raw) return;
        var d = JSON.parse(raw);
        var form = host.querySelector('form');
        if (!form) return;
        Object.keys(d).forEach(function (k) {
          var f = form.elements[k];
          if (!f) return;
          if (f.type === 'checkbox' || f.type === 'radio') { return; }
          if (f.value === '') f.value = d[k];
        });
      } catch (err) { /* ignore */ }
    }
    restore();
    host.addEventListener('change', save);
    show(0);
  });

  /* --- Consultation: show the visitor's own time zone alongside Yangon
         (FR-CON-010/011). Myanmar Standard Time is UTC+06:30 — a half-hour
         offset and a well-known source of off-by-thirty-minute bugs.       */
  document.querySelectorAll('[data-tz-local]').forEach(function (el) {
    try {
      var tz = Intl.DateTimeFormat().resolvedOptions().timeZone || 'your local time';
      var mins = -new Date().getTimezoneOffset();
      var sign = mins < 0 ? '−' : '+';
      var a = Math.abs(mins);
      var off = 'UTC' + sign + String(Math.floor(a / 60)).padStart(2, '0') + ':' + String(a % 60).padStart(2, '0');
      el.textContent = tz + ' (' + off + ')';
    } catch (err) { el.textContent = 'your local time zone'; }
  });
  document.querySelectorAll('[data-yangon-now]').forEach(function (el) {
    try {
      el.textContent = new Intl.DateTimeFormat('en-GB', {
        timeZone: 'Asia/Yangon', hour: '2-digit', minute: '2-digit', hour12: false
      }).format(new Date()) + ' in Yangon';
    } catch (err) { /* ignore */ }
  });

  /* --- Demo notice ------------------------------------------------------ */
  var demobar = document.querySelector('.demobar');
  if (demobar) {
    var x = demobar.querySelector('.demobar__x');
    try {
      if (sessionStorage.getItem('spgems.demobar') === 'off') demobar.hidden = true;
    } catch (err) { /* ignore */ }
    if (x) x.addEventListener('click', function () {
      demobar.hidden = true;
      try { sessionStorage.setItem('spgems.demobar', 'off'); } catch (err) { /* ignore */ }
    });
  }

  /* --- Newsletter (single inline field, never a modal — §28.7) --------- */
  document.querySelectorAll('[data-newsletter]').forEach(function (form) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var input = form.querySelector('input');
      if (!input || !input.checkValidity()) { if (input) input.focus(); return; }
      form.innerHTML = '<p style="font-size:13px;padding:10px 0;color:#B8B1A8">' +
        'Thank you — this is a demo, so nothing was sent.</p>';
    });
  });
})();
