// Shared behavior for the static site.
(function () {
  "use strict";

  if (/android/i.test(navigator.userAgent)) {
    document.querySelectorAll(".btn-get-app").forEach(function (element) {
      element.href =
        "https://play.google.com/store/apps/details?id=com.earthmanmuons.whatchord";
    });
  }

  // Give section headings GitHub-style anchor links, generating ids from the
  // heading text so no page has to hand-author them. Covers long-form articles
  // and the articles index.
  document
    .querySelectorAll(".article-body, .articles-index")
    .forEach(function (scope) {
      var usedIds = {};
      scope.querySelectorAll("h2").forEach(function (heading) {
        // Leave the call-to-action and related-articles headings alone.
        if (heading.closest(".article-cta, .article-related")) return;

        var slug = heading.textContent
          .trim()
          .toLowerCase()
          .replace(/[^\w\s-]/g, "")
          .replace(/\s+/g, "-")
          .replace(/-+/g, "-");
        if (!slug) return;

        usedIds[slug] = (usedIds[slug] || 0) + 1;
        if (usedIds[slug] > 1) slug = slug + "-" + usedIds[slug];
        if (!heading.id) heading.id = slug;

        var anchor = document.createElement("a");
        anchor.className = "heading-anchor";
        anchor.href = "#" + heading.id;
        anchor.setAttribute("aria-label", "Link to this section");
        anchor.innerHTML =
          '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">' +
          '<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.1" d="M10.6 13.4a4 4 0 0 1 0-5.7l2.8-2.8a4 4 0 0 1 5.7 5.7l-1.5 1.5"/>' +
          '<path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.1" d="M13.4 10.6a4 4 0 0 1 0 5.7l-2.8 2.8a4 4 0 0 1-5.7-5.7l1.5-1.5"/>' +
          "</svg>";
        heading.appendChild(anchor);
      });
    });

  // CSS can print an href attribute, but it cannot resolve relative links to
  // their deployed absolute URLs. Populate print-only URL attributes so local
  // previews and production prints match.
  if (
    document.body.classList.contains("article-page") ||
    document.body.classList.contains("articles-index-page") ||
    document.body.classList.contains("try-page")
  ) {
    var siteOrigin = "https://whatchord.earthmanmuons.com";
    var canonicalLink = document.querySelector('link[rel="canonical"]');
    var ogUrl = document.querySelector('meta[property="og:url"]');

    function resolvedPageUrl() {
      var pageUrl =
        (canonicalLink && canonicalLink.href) || (ogUrl && ogUrl.content) || "";

      if (/^https?:$/.test(window.location.protocol)) {
        return window.location.href;
      }

      var sitePath = window.location.pathname;
      var siteMarker = "/docs/site/";
      var siteIndex = sitePath.indexOf(siteMarker);
      if (siteIndex !== -1) {
        sitePath = "/" + sitePath.slice(siteIndex + siteMarker.length);
      }
      var localUrl = siteOrigin + sitePath + window.location.search;
      return pageUrl && !window.location.search ? pageUrl : localUrl;
    }

    function syncPrintPageUrl() {
      var pageUrl = resolvedPageUrl();
      document.body.dataset.printPageUrl = pageUrl;
      var footerCopy = document.querySelector(".footer-copy");
      if (footerCopy) {
        footerCopy.dataset.printPageUrl = pageUrl;
      }
    }

    function syncPrintLinkUrls() {
      var pageUrl = resolvedPageUrl();
      document
        .querySelectorAll(
          ".article-body a[href], .articles-index a[href], .try-feedback a[href]",
        )
        .forEach(function (link) {
          var href = link.getAttribute("href");
          if (!href || href.charAt(0) === "#") return;

          try {
            link.dataset.printUrl = new URL(href, pageUrl).href;
          } catch (_) {
            link.dataset.printUrl = href;
          }
        });
    }

    function syncPrintUrls() {
      syncPrintPageUrl();
      syncPrintLinkUrls();
    }

    syncPrintUrls();
    window.addEventListener("beforeprint", syncPrintUrls);
  }

  // The mobile nav menu is a disclosure: the hamburger button toggles the
  // menu and reports its state via aria-expanded. Also close on an outside
  // click, on Escape, or after choosing an item.
  var navBurger = document.querySelector(".nav-burger");
  var navMenu = document.querySelector(".nav-menu");
  if (navBurger && navMenu) {
    function navOpen() {
      return navBurger.getAttribute("aria-expanded") === "true";
    }

    function setNavOpen(open) {
      navBurger.setAttribute("aria-expanded", String(open));
      navMenu.classList.toggle("is-open", open);
    }

    navBurger.addEventListener("click", function () {
      setNavOpen(!navOpen());
    });

    document.addEventListener("click", function (event) {
      if (!navOpen() || navBurger.contains(event.target)) return;
      // A chosen menu link closes the menu (then navigates); any other outside
      // click just closes it.
      if (navMenu.contains(event.target)) {
        if (event.target.closest("a")) setNavOpen(false);
        return;
      }
      setNavOpen(false);
    });

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && navOpen()) {
        setNavOpen(false);
        navBurger.focus();
      }
    });
  }

  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return;
  }

  document.querySelectorAll("[data-motion-media]").forEach(function (element) {
    var video = element.querySelector("[data-motion-video]");
    var toggle = element.querySelector("[data-motion-toggle]");
    if (!video) return;

    var userPaused = false;

    function setPaused(isPaused) {
      element.classList.toggle("is-video-paused", isPaused);
      if (toggle) {
        toggle.setAttribute(
          "aria-label",
          isPaused ? "Play animation" : "Pause animation",
        );
      }
    }

    function activateVideoControl() {
      element.classList.add("is-video-active");
      setPaused(video.paused);
      if (toggle) {
        toggle.hidden = false;
      }
    }

    function activateVideo() {
      var play = video.play();
      if (play && typeof play.then === "function") {
        play.then(activateVideoControl).catch(function () {});
        return;
      }

      activateVideoControl();
    }

    if (toggle) {
      toggle.addEventListener("click", function () {
        if (video.paused) {
          userPaused = false;
          activateVideo();
          return;
        }

        userPaused = true;
        video.pause();
        setPaused(true);
      });
    }

    // Only run the video while it is on screen, and respect a manual pause
    // when scrolling back into view.
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            if (entry.isIntersecting) {
              if (!userPaused) activateVideo();
            } else {
              video.pause();
            }
          });
        },
        { threshold: 0.25 },
      ).observe(element);
    } else if (video.readyState >= 3) {
      activateVideo();
    } else {
      video.addEventListener("canplay", activateVideo, { once: true });
    }
  });
})();
