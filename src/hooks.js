/* zlive-components hooks — the 'zc-dialog' reference implementation.
 *
 * Mounted on elements rendered with data-lv-hook="zc-dialog" (see
 * src/dialog.zig). Behaviors:
 *   - focus trap (Tab / Shift+Tab wrap within the panel)
 *   - Escape emits the 'zc:dialog:close' event (server removes the dialog)
 *   - body scroll-lock, refcounted across stacked dialogs
 *   - aria managed in markup by the server (role/aria-modal/aria-labelledby);
 *     the hook owns focus and tabindex
 *
 * Contract for hook-updated content: `updated()` must NOT steal focus —
 * the dialog body may hold a form the user is typing into; morphdom
 * mutates the DOM in place, so the keydown trap bound here survives
 * patches with nothing to re-arm. Copy this shape for new components.
 */
(function () {
  'use strict';

  // load order: client.js (defines window.LiveHooks) must come first
  if (!window.LiveHooks) {
    console.error('[zc] hooks.js loaded before client.js; zc-dialog not registered');
    return;
  }

  const state = new WeakMap(); // dialog el -> {prevFocus, onKeydown}
  const zcState = new WeakMap(); // zc-* floating hooks state

  let lockCount = 0;
  function lock() {
    if (++lockCount === 1) document.body.style.overflow = 'hidden';
  }
  function unlock() {
    if (lockCount > 0 && --lockCount === 0) document.body.style.overflow = '';
  }

  function focusables(root) {
    return Array.from(root.querySelectorAll(
      'a[href], button:not([disabled]), input:not([disabled]), ' +
      'select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
    )).filter((el) => el.getClientRects().length > 0);
  }

  window.LiveHooks.register('zc-dialog', {
    mounted(el) {
      const prevFocus = document.activeElement;
      const panel = el.querySelector('.zc-dialog-panel') || el;

      if (!el.hasAttribute('tabindex')) el.setAttribute('tabindex', '-1');

      const onKeydown = (ev) => {
        if (ev.key === 'Escape') {
          ev.preventDefault();
          ev.stopPropagation();
          window.Live.send('zc:dialog:close', { id: el.id });
          return;
        }
        if (ev.key !== 'Tab') return;

        const items = focusables(panel);
        if (items.length === 0) {
          ev.preventDefault();
          el.focus();
          return;
        }
        const first = items[0];
        const last = items[items.length - 1];
        const active = document.activeElement;
        if (ev.shiftKey && (active === first || !panel.contains(active))) {
          ev.preventDefault();
          last.focus();
        } else if (!ev.shiftKey && active === last) {
          ev.preventDefault();
          first.focus();
        }
      };

      el.addEventListener('keydown', onKeydown);
      state.set(el, { prevFocus, onKeydown });
      lock();

      const first = focusables(panel)[0];
      (first || el).focus();
    },

    updated(_el) {
      // Patches morph the body in place; never re-focus (the user may be
      // typing). The trap listener is bound to the dialog element itself
      // and survives morphs, so there is nothing to re-arm.
    },

    destroyed(el) {
      const s = state.get(el);
      if (!s) return;
      el.removeEventListener('keydown', s.onKeydown);
      state.delete(el);
      unlock();
      if (s.prevFocus && document.contains(s.prevFocus)) {
        s.prevFocus.focus();
      }
    },
  });

// ---------------------------------------------------------------------
// Floating primitives (Popover / Dropdown / Tooltip) — positioned with
// Floating UI (headless, loaded via CDN as window.FloatingUIDOM).
// Open state lives on the server; these hooks only position the element,
// and detect outside-click / Escape -> zc:* close events.
// ---------------------------------------------------------------------

function zcFloatingPosition(el) {
  const anchor = document.getElementById(el.getAttribute('data-zc-anchor'));
  if (!anchor || !window.FloatingUIDOM) return null;
  // shadcn's default sideOffset is 4 for dropdown/popover and 0 for tooltip;
  // the panel's template carries the number it wants.
  const offset = parseFloat(el.getAttribute('data-zc-offset') || '4');
  const position = () => window.FloatingUIDOM
    .computePosition(anchor, el, {
      // fixed strategy escapes clipping ancestors (table cells with
      // overflow, etc.) as long as no ancestor uses transform/filter
      strategy: 'fixed',
      placement: el.getAttribute('data-zc-placement') || 'bottom-start',
      middleware: [
        window.FloatingUIDOM.offset(offset),
        window.FloatingUIDOM.flip(),
        window.FloatingUIDOM.shift({ padding: 4 }),
      ],
    })
    .then(({ x, y }) => {
      el.style.position = 'fixed';
      el.style.left = x + 'px';
      el.style.top = y + 'px';
    });
  position();
  return { anchor, position };
}

// shared mounted/destroyed for popover + dropdown (dismissable floatings)
function zcDismissableMounted(el, closeEvent) {
  const f = zcFloatingPosition(el);
  if (!f) return null;

  const prevFocus = document.activeElement;
  const onDocClick = (ev) => {
    if (el.contains(ev.target) || f.anchor.contains(ev.target)) return;
    window.Live.send(closeEvent, { id: el.getAttribute('data-zc-anchor') });
  };
  const onKeydown = (ev) => {
    if (ev.key === 'Escape') {
      ev.preventDefault();
      window.Live.send(closeEvent, { id: el.getAttribute('data-zc-anchor') });
    }
  };
  // capture: run before the delegated lv-click handler toggles
  document.addEventListener('click', onDocClick, true);
  document.addEventListener('keydown', onKeydown, true);
  return { f, prevFocus, onDocClick, onKeydown };
}

function zcDismissableDestroyed(el, s) {
  document.removeEventListener('click', s.onDocClick, true);
  document.removeEventListener('keydown', s.onKeydown, true);
}

LiveHooks.register('zc-popover', {
  mounted(el) {
    const s = zcDismissableMounted(el, 'zc:popover:close');
    if (s) zcState.set(el, s);
  },
  updated(el) {
    const s = zcState.get(el);
    if (s) s.f.position(); // content size may have changed
  },
  destroyed(el) {
    const s = zcState.get(el);
    if (!s) return;
    zcDismissableDestroyed(el, s);
    zcState.delete(el);
  },
});

LiveHooks.register('zc-dropdown', {
  mounted(el) {
    const s = zcDismissableMounted(el, 'zc:dropdown:close');
    if (s) {
      zcState.set(el, s);
      // focus the first menu item
      const first = el.querySelector('[role="menuitem"]');
      if (first) first.focus();
    }
  },
  updated(el) {
    const s = zcState.get(el);
    if (s) s.f.position();
  },
  destroyed(el) {
    const s = zcState.get(el);
    if (!s) return;
    zcDismissableDestroyed(el, s);
    zcState.delete(el);
    if (s.prevFocus && document.contains(s.prevFocus)) s.prevFocus.focus();
  },
});

// Sidebar: the open state is the server's (one attribute on the provider,
// which the stylesheet hangs the whole layout off), so this hook only adds
// what CSS cannot: the Cmd/Ctrl+B shortcut, and mirroring the state into a
// cookie so a reload comes back the way it was left — what shadcn's
// SidebarProvider does with the same cookie name.
function zcSidebarCookie(el) {
  try {
    const open = el.getAttribute('data-state') === 'expanded';
    document.cookie = 'sidebar_state=' + (open ? '1' : '0') +
      '; path=/; max-age=' + 60 * 60 * 24 * 7;
  } catch { /* cookies unavailable (file://, blocked); the state still works */ }
}

LiveHooks.register('zc-sidebar', {
  mounted(el) {
    const onKeydown = (ev) => {
      if (ev.key.toLowerCase() !== 'b' || !(ev.metaKey || ev.ctrlKey)) return;
      ev.preventDefault();
      window.Live.send('zc:sidebar:toggle', { id: el.id });
    };
    document.addEventListener('keydown', onKeydown);
    zcState.set(el, { onKeydown });
    zcSidebarCookie(el);
  },
  updated(el) {
    zcSidebarCookie(el); // the wrapper's data-state is what changed
  },
  destroyed(el) {
    const s = zcState.get(el);
    if (!s) return;
    document.removeEventListener('keydown', s.onKeydown);
    zcState.delete(el);
  },
});

// Tooltip: no server state — hover toggles visibility client-side.
LiveHooks.register('zc-tooltip', {
  mounted(el) {
    const anchor = document.getElementById(el.getAttribute('data-zc-anchor'));
    if (!anchor) return;
    const show = () => { el.hidden = false; zcFloatingPosition(el); };
    const hide = () => { el.hidden = true; };
    anchor.addEventListener('mouseenter', show);
    anchor.addEventListener('mouseleave', hide);
    anchor.addEventListener('focus', show);
    anchor.addEventListener('blur', hide);
    zcState.set(el, { anchor, show, hide });
  },
  updated(_el) {},
  destroyed(el) {
    const s = zcState.get(el);
    if (!s) return;
    s.anchor.removeEventListener('mouseenter', s.show);
    s.anchor.removeEventListener('mouseleave', s.hide);
    s.anchor.removeEventListener('focus', s.show);
    s.anchor.removeEventListener('blur', s.hide);
    zcState.delete(el);
  },
});

// ---------------------------------------------------------------------
// Chart — Apache ECharts (loaded via CDN as window.echarts) hosted in a
// client-owned container.
//
// The server owns the spec; the hook owns the canvas. The element is
// rendered empty with the ECharts option JSON in data-lv-chart and
// data-lv-ignore set, so morphdom updates the attribute (firing updated)
// but never touches the DOM ECharts drew. updated() re-applies the spec;
// ECharts diffs it internally, so a data-only change animates in place.
// ---------------------------------------------------------------------
LiveHooks.register('zc-chart', {
  mounted(el) {
    if (!window.echarts) {
      console.error('[zc] zc-chart: window.echarts missing; load echarts before hooks.js runs a chart page');
      return;
    }
    let spec;
    try {
      spec = JSON.parse(el.getAttribute('data-lv-chart'));
    } catch {
      console.error('[zc] zc-chart: data-lv-chart is not valid JSON');
      return;
    }
    const chart = window.echarts.init(el);
    chart.setOption(spec);
    const onResize = () => chart.resize();
    window.addEventListener('resize', onResize);
    zcState.set(el, { chart, onResize });
  },
  updated(el) {
    const s = zcState.get(el);
    if (!s) return;
    try {
      s.chart.setOption(JSON.parse(el.getAttribute('data-lv-chart')));
    } catch { /* a transient bad spec leaves the previous chart up */ }
  },
  destroyed(el) {
    const s = zcState.get(el);
    if (!s) return;
    window.removeEventListener('resize', s.onResize);
    s.chart.dispose();
    zcState.delete(el);
  },
});
})();
