/* Accessible controller for the off-canvas menu.
 *
 * Deliberately vanilla. Everything else in js/main.js depends on jQuery 1.9.1
 * and removing that dependency is tracked separately, so new behaviour is
 * written without adding to it.
 *
 * This replaces the previous jQuery `toggleClass` handlers, which had no
 * concept of state. Explicit open and close is what makes the rest possible:
 * a blind toggle cannot answer "is the menu open?", so it cannot know whether
 * Escape should act, where focus should return to, or when the background
 * should become reachable again.
 *
 * Behaviour:
 *   - Escape closes the menu and returns focus to whatever opened it.
 *   - Opening moves focus into the menu, onto its close button.
 *   - Tab and Shift+Tab cycle within the menu while it is open.
 *   - Background containers are made `inert`, so they are unreachable by
 *     pointer, keyboard and assistive technology.
 *
 * The closed menu needs no special handling: `.sliding-menu-content` is
 * `visibility: hidden`, which already removes its links from the focus order.
 */
(function () {
  "use strict";

  // The backdrop and the menu are siblings of these, so nothing inside the
  // menu is affected when they are made inert.
  var BACKGROUND = "header.header, .hero-section, #page-wrapper";

  var FOCUSABLE = [
    'a[href]',
    'button:not([disabled])',
    'input:not([disabled])',
    'select:not([disabled])',
    'textarea:not([disabled])',
    '[tabindex]:not([tabindex="-1"])'
  ].join(",");

  function ready(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  }

  function toArray(nodeList) {
    return Array.prototype.slice.call(nodeList);
  }

  ready(function () {
    var menu = document.querySelector(".js-menu");
    var backdrop = document.querySelector(".js-menu-screen");
    var triggers = toArray(document.querySelectorAll(".js-menu-trigger"));

    // A layout without the menu include should not be broken by this script.
    if (!menu || triggers.length === 0) {
      return;
    }

    var background = toArray(document.querySelectorAll(BACKGROUND));
    var sliders = toArray(document.querySelectorAll(".sliding-menu-button"));
    var pageWrapper = document.querySelector("#page-wrapper");

    var isOpen = false;
    var lastFocused = null;

    function menuFocusables() {
      return toArray(menu.querySelectorAll(FOCUSABLE));
    }

    // `inert` alone is correct here. It removes a subtree from the focus order,
    // from pointer events and from the accessibility tree, so pairing it with
    // `aria-hidden` adds nothing. Worse, the browser refuses `aria-hidden` on an
    // ancestor of the focused element and logs a warning, which is exactly the
    // state that exists at the moment the menu opens from the header button.
    function setBackgroundInert(inert) {
      background.forEach(function (el) {
        if (inert) {
          el.setAttribute("inert", "");
        } else {
          el.removeAttribute("inert");
        }
      });
    }

    function setExpanded(expanded) {
      triggers.forEach(function (trigger) {
        trigger.setAttribute("aria-expanded", expanded ? "true" : "false");
      });
    }

    // Class names are the ones the existing stylesheet already reacts to.
    // `#masthead` is intentionally absent: no element carries that id, so the
    // original selector matched nothing and the header never slid. Preserved
    // as-is rather than "fixed", which would be an unrequested visual change.
    function paint(open) {
      document.body.classList.toggle("no-scroll", open);
      menu.classList.toggle("is-visible", open);
      if (backdrop) {
        backdrop.classList.toggle("is-visible", open);
      }
      sliders.forEach(function (el) {
        el.classList.toggle("slide", open);
        el.classList.toggle("close", open);
      });
      if (pageWrapper) {
        pageWrapper.classList.toggle("slide", open);
      }
    }

    function openMenu(opener) {
      if (isOpen) {
        return;
      }
      isOpen = true;
      lastFocused = opener || document.activeElement;

      paint(true);
      setExpanded(true);

      // The menu is `visibility: hidden` when closed, and an element inside a
      // hidden subtree cannot take focus. Adding the class is not enough: the
      // style has to be recalculated first, otherwise `focus()` is silently
      // ignored and focus stays on the body. Reading a layout property forces
      // that recalculation synchronously.
      void menu.offsetHeight;

      // The close button is the first focusable element in the menu, so this
      // lands somewhere predictable and leaves the links one Tab away.
      var focusables = menuFocusables();
      if (focusables.length > 0) {
        focusables[0].focus();
      }

      // Deliberately last. Focus starts on the header button that opened the
      // menu, which is inside the subtree about to become inert. Moving focus
      // out first means inertness is never applied over the focused element.
      setBackgroundInert(true);
    }

    function closeMenu() {
      if (!isOpen) {
        return;
      }
      isOpen = false;

      paint(false);
      setExpanded(false);

      // Inertness must be lifted before focus is restored, otherwise the
      // element being focused is still inside an inert subtree and the call
      // is silently ignored.
      setBackgroundInert(false);

      var restored = false;
      if (lastFocused && typeof lastFocused.focus === "function") {
        lastFocused.focus();
        restored = document.activeElement === lastFocused;
      }

      // The opener can stop being focusable while the menu is open: widen the
      // window past the desktop breakpoint and the hamburger becomes
      // `display: none`, so `focus()` on it does nothing. Without a fallback,
      // focus would sit inside the panel that is about to become
      // `visibility: hidden` and be lost entirely. Testing for a failed restore
      // rather than for body focus is what catches that case, because focus is
      // still on the menu's close button at this point, not on the body.
      if (!restored) {
        var fallback = document.querySelector(".site-title");
        if (fallback && typeof fallback.focus === "function") {
          fallback.focus();
        }
      }

      lastFocused = null;
    }

    function trapTab(event) {
      var focusables = menuFocusables();
      if (focusables.length === 0) {
        return;
      }

      var first = focusables[0];
      var last = focusables[focusables.length - 1];
      var active = document.activeElement;

      // `inert` on the background already prevents Tab from escaping in
      // browsers that support it. This keeps the cycle correct everywhere
      // else, and handles wrapping at either end regardless.
      if (event.shiftKey && (active === first || !menu.contains(active))) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && active === last) {
        event.preventDefault();
        first.focus();
      }
    }

    triggers.forEach(function (trigger) {
      // `click` alone, rather than the previous `click touchstart` pair. Binding
      // both fired twice on touch devices, and preventing default on touchstart
      // also swallowed scroll gestures that began on the button.
      trigger.addEventListener("click", function (event) {
        event.preventDefault();
        if (isOpen) {
          closeMenu();
        } else {
          openMenu(trigger);
        }
      });
    });

    if (backdrop) {
      backdrop.addEventListener("click", function (event) {
        event.preventDefault();
        closeMenu();
      });
    }

    document.addEventListener("keydown", function (event) {
      if (!isOpen) {
        return;
      }
      if (event.key === "Escape" || event.key === "Esc") {
        event.preventDefault();
        closeMenu();
      } else if (event.key === "Tab") {
        trapTab(event);
      }
    });

    // Reflect the true starting state rather than trusting the markup.
    setExpanded(false);
  });
})();
