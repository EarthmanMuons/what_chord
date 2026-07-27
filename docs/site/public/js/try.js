// Drives the browser chord-identification demo (try.html). Reads input, calls
// the compiled Dart engine (window.whatchordIdentify), and renders results.
// Seeds musical state from and writes it to the URL query string so links are
// shareable. Presentation preferences remain local to the viewer.
(function () {
  "use strict";

  // All 15 conventional key signatures per mode, chromatic ascending with
  // enharmonic spellings listed together (e.g. C# and Db major, D# and Eb
  // minor).
  var ROOTS = {
    maj: [
      "C",
      "C#",
      "Db",
      "D",
      "Eb",
      "E",
      "F",
      "F#",
      "Gb",
      "G",
      "Ab",
      "A",
      "Bb",
      "B",
      "Cb",
    ],
    min: [
      "C",
      "C#",
      "D",
      "D#",
      "Eb",
      "E",
      "F",
      "F#",
      "G",
      "G#",
      "Ab",
      "A",
      "A#",
      "Bb",
      "B",
    ],
  };
  var PC = {
    C: 0,
    "C#": 1,
    Db: 1,
    D: 2,
    "D#": 3,
    Eb: 3,
    E: 4,
    F: 5,
    "F#": 6,
    Gb: 6,
    G: 7,
    "G#": 8,
    Ab: 8,
    A: 9,
    "A#": 10,
    Bb: 10,
    B: 11,
    Cb: 11,
  };
  var DEFAULT_MODE = "maj";
  var DEFAULT_NOTATION = "textual";
  var NOTATION_STORAGE_KEY = "whatchord.notation";
  var MAX_NOTES_CHARACTERS = 512;
  var SITE_HOST = "whatchord.earthmanmuons.com";
  var ANDROID_PACKAGE = "com.earthmanmuons.whatchord";
  var IS_ANDROID = /android/i.test(navigator.userAgent);
  // iPadOS reports as "MacIntel"; the touch-point check catches iPad Safari.
  var IS_IOS =
    /iphone|ipad|ipod/i.test(navigator.userAgent) ||
    (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  // On iOS the native Smart App Banner already offers the app, so trim the
  // header to a breadcrumb plus Source (see try.css) to avoid a clashing
  // second app prompt.
  if (IS_IOS) document.documentElement.classList.add("is-ios");
  // Matches the static <title> in try.html; restored when there is no result
  // to show. The Worker overrides the served title for seeded links, so we
  // cannot read this back from document.title at boot.
  var DEFAULT_TITLE = "Try It - Identify a Chord | WhatChord";

  var els = {
    notes: document.getElementById("notes-input"),
    clear: document.getElementById("clear-notes"),
    keyRoot: document.getElementById("key-root"),
    keyMode: document.getElementById("key-mode"),
    notation: document.getElementById("notation"),
    playing: document.getElementById("playing-mode"),
    status: document.getElementById("status"),
    resultsHead: document.getElementById("results-head"),
    echo: document.getElementById("echo"),
    candidates: document.getElementById("candidates"),
    rankingFeedback: document.getElementById("ranking-feedback"),
    symbolLegend: document.getElementById("symbol-legend"),
    copyLink: document.getElementById("copy-link"),
    copyLabel: document.querySelector("#copy-link .copy-label"),
    openApp: document.getElementById("open-app"),
  };

  var state = {
    mode: DEFAULT_MODE,
    notation: loadNotation(),
    // Playing context; deliberately not persisted so a fresh visit is solo.
    ensemble: false,
    canonicalNotes: null,
  };

  function loadNotation() {
    try {
      var notation = localStorage.getItem(NOTATION_STORAGE_KEY);
      return notation === "symbolic" || notation === "textual"
        ? notation
        : DEFAULT_NOTATION;
    } catch {
      return DEFAULT_NOTATION;
    }
  }

  function saveNotation(notation) {
    try {
      localStorage.setItem(NOTATION_STORAGE_KEY, notation);
    } catch {
      // Storage can be unavailable in private browsing or restricted contexts.
    }
  }

  // ─── Key dropdown (mode-aware) ─────────────────────────────────

  function glyph(label) {
    return label.replace("#", "♯").replace("b", "♭");
  }

  // Rebuilds the root options for the current mode, keeping the same pitch
  // class selected (so switching major<->minor respells, e.g. Db <-> C#).
  function rebuildKeyRoot(pc) {
    var list = ROOTS[state.mode];
    var selected = list[0];
    els.keyRoot.innerHTML = "";
    list.forEach(function (label) {
      var opt = document.createElement("option");
      opt.value = label;
      opt.textContent = glyph(label);
      els.keyRoot.appendChild(opt);
      if (PC[label] === pc) selected = label;
    });
    els.keyRoot.value = selected;
  }

  // ─── Controls ──────────────────────────────────────────────────

  function setSegmented(group, attr, value) {
    Array.prototype.forEach.call(
      group.querySelectorAll("button"),
      function (b) {
        b.setAttribute("aria-pressed", String(b.getAttribute(attr) === value));
      },
    );
  }

  els.keyMode.addEventListener("click", function (e) {
    var btn = e.target.closest("button");
    if (!btn) return;
    state.mode = btn.getAttribute("data-mode");
    setSegmented(els.keyMode, "data-mode", state.mode);
    rebuildKeyRoot(PC[els.keyRoot.value]);
    scheduleRun();
  });

  els.notation.addEventListener("click", function (e) {
    var btn = e.target.closest("button");
    if (!btn) return;
    state.notation = btn.getAttribute("data-notation");
    saveNotation(state.notation);
    setSegmented(els.notation, "data-notation", state.notation);
    scheduleRun();
  });

  els.playing.addEventListener("click", function (e) {
    var btn = e.target.closest("button");
    if (!btn) return;
    state.ensemble = btn.getAttribute("data-playing") === "ensemble";
    setSegmented(
      els.playing,
      "data-playing",
      state.ensemble ? "ensemble" : "solo",
    );
    scheduleRun();
  });

  els.keyRoot.addEventListener("change", scheduleRun);
  els.notes.addEventListener("input", function () {
    state.canonicalNotes = null;
    syncClear();
    scheduleRun();
  });
  els.notes.addEventListener("keydown", function (e) {
    if (e.key !== "Enter") return;
    e.preventDefault();
    els.notes.blur();
  });

  els.clear.addEventListener("click", function () {
    els.notes.value = "";
    syncClear();
    els.notes.focus();
    scheduleRun();
  });

  // Shows the clear button only when the input has text.
  function syncClear() {
    els.clear.hidden = els.notes.value.length === 0;
  }

  els.copyLink.addEventListener("click", function () {
    var url = location.origin + "/try" + buildQuery();
    var done = function () {
      els.copyLabel.textContent = "Copied!";
      setTimeout(function () {
        els.copyLabel.textContent = "Copy link";
      }, 1500);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(url).then(done, done);
    } else {
      done();
    }
  });

  // ─── State <-> URL ─────────────────────────────────────────────

  function currentKey() {
    return els.keyRoot.value + ":" + state.mode;
  }

  function buildQuery() {
    var params = new URLSearchParams();
    if (state.canonicalNotes) params.set("notes", state.canonicalNotes);
    if (currentKey() !== "C:" + DEFAULT_MODE) params.set("key", currentKey());
    if (state.ensemble) params.set("mode", "ensemble");
    var q = params.toString();
    return q ? "?" + q : "";
  }

  function syncUrl() {
    var path = location.protocol === "file:" ? location.pathname : "/try";
    history.replaceState(null, "", path + buildQuery());
  }

  // Android has no native smart banner, so offer an explicit deep link. The
  // intent URL opens the app when installed and falls back to this page when
  // not. Shown only on Android, and only when there is a chord to open.
  function updateOpenAppLink() {
    if (!IS_ANDROID || !state.canonicalNotes) {
      els.openApp.hidden = true;
      return;
    }
    var query = buildQuery();
    var httpsUrl = "https://" + SITE_HOST + "/try" + query;
    els.openApp.href =
      "intent://" +
      SITE_HOST +
      "/try" +
      query +
      "#Intent;scheme=https;package=" +
      ANDROID_PACKAGE +
      ";S.browser_fallback_url=" +
      encodeURIComponent(httpsUrl) +
      ";end";
    els.openApp.hidden = false;
  }

  // Keeps the tab title in step with the current result, same format the
  // Worker uses for shared links, so it no longer reflects a stale seeded
  // chord once the user starts typing their own notes.
  function syncTitle(result) {
    if (result && result.ok && result.candidates.length) {
      document.title =
        result.input.notes.join(" ") +
        " → " +
        result.candidates[0].symbol +
        " | WhatChord";
    } else {
      document.title = DEFAULT_TITLE;
    }
  }

  // Applies URL params and returns the pitch class to preselect in the key
  // dropdown (defaults to C).
  function seedFromUrl() {
    var params = new URLSearchParams(location.search);
    var rootPc = 0;

    var key = params.get("key");
    if (key) {
      var parts = key.split(":");
      var mode = (parts[1] || "").toLowerCase().slice(0, 3);
      if (mode === "min" || mode === "maj") state.mode = mode;
      if (parts[0] in PC) rootPc = PC[parts[0]];
    }
    setSegmented(els.keyMode, "data-mode", state.mode);

    setSegmented(els.notation, "data-notation", state.notation);

    state.ensemble = params.get("mode") === "ensemble";
    setSegmented(
      els.playing,
      "data-playing",
      state.ensemble ? "ensemble" : "solo",
    );

    var notes = params.get("notes");
    if (notes !== null) {
      els.notes.value =
        notes.length <= MAX_NOTES_CHARACTERS
          ? notes
          : notes.slice(0, MAX_NOTES_CHARACTERS + 1);
    }

    return rootPc;
  }

  // ─── Rendering ─────────────────────────────────────────────────

  function setStatus(text, kind) {
    els.status.textContent = text || "";
    els.status.className = "try-status" + (kind ? " is-" + kind : "");
  }

  function render(result) {
    els.candidates.innerHTML = "";
    els.rankingFeedback.hidden = true;
    els.symbolLegend.hidden = true;

    if (!result.ok) {
      setStatus(result.errors.join(" "), "error");
      els.resultsHead.hidden = true;
      return;
    }

    if (result.warnings && result.warnings.length) {
      setStatus(result.warnings.join(" "), "warning");
    } else {
      setStatus("");
    }

    els.resultsHead.hidden = false;
    els.echo.innerHTML = "";
    addEcho("Notes", result.input.notes.join(" "));
    addEcho("Bass", result.input.bass);
    addEcho("Key", result.input.key);
    addEcho("Mode", state.ensemble ? "Ensemble" : "");

    if (!result.candidates.length) {
      var none = document.createElement("div");
      none.className = "try-notes";
      none.textContent = "No chord candidates for these notes.";
      els.candidates.appendChild(none);
      return;
    }

    result.candidates.forEach(function (c) {
      els.candidates.appendChild(renderCandidate(c));
    });
    els.rankingFeedback.hidden = false;
    els.symbolLegend.hidden = false;
  }

  function addEcho(label, value) {
    if (!value) return;
    // Real space between items (not a flex gap) so copy/paste keeps them apart.
    if (els.echo.childNodes.length) {
      els.echo.appendChild(document.createTextNode(" "));
    }
    var span = document.createElement("span");
    span.className = "try-echo-item";
    span.appendChild(document.createTextNode(label + ": "));
    var b = document.createElement("b");
    b.textContent = value;
    span.appendChild(b);
    els.echo.appendChild(span);
  }

  var TAG_LABEL = {
    chosen: "Chosen",
    possible: "Possible",
    unlikely: "Unlikely",
  };

  function renderCandidate(c) {
    var row = document.createElement("div");
    row.className =
      "try-candidate" + (c.class === "chosen" ? " is-chosen" : "");

    var rank = document.createElement("div");
    rank.className = "try-rank";
    rank.textContent = c.rank;

    var main = document.createElement("div");
    main.className = "try-cand-main";
    var symbol = document.createElement("div");
    symbol.className = "try-symbol";
    appendSymbol(symbol, c.symbol);
    var academicName = document.createElement("div");
    academicName.className = "try-academic-name";
    academicName.textContent = c.academicName;
    var notes = document.createElement("div");
    notes.className = "try-notes";
    appendNoteGroup(notes, "Chord tones", formatNoteList(c.chordTones));
    if (c.alsoPlayedNotes) {
      var separator = document.createElement("span");
      separator.className = "try-notes-also-played-marker";
      separator.textContent = " + ";
      notes.appendChild(separator);
      appendNoteGroup(notes, "also", formatNoteList(c.alsoPlayedNotes));
    }
    main.appendChild(symbol);
    main.appendChild(academicName);
    main.appendChild(notes);

    var tag = document.createElement("span");
    tag.className = "try-tag tag-" + c.class;
    tag.textContent = TAG_LABEL[c.class] || c.class;

    var cost = document.createElement("div");
    cost.className = "try-cost";
    cost.textContent = c.cost.toFixed(2);

    row.appendChild(rank);
    row.appendChild(main);
    row.appendChild(tag);
    row.appendChild(cost);
    return row;
  }

  // Matches the app's identity card: the root note is emphasized (bold, larger)
  // while the quality/extensions and any slash bass stay lighter and smaller.
  // The bass slash is wrapped only for visual spacing; its text stays "/" so
  // selection and copy/paste preserve the compact canonical chord symbol.
  // The root is always a letter A-G plus glyph accidentals; no quality token
  // begins with one of those accidentals right after the root, so this split is
  // unambiguous for the international note names the engine emits here.
  var ROOT_RE = /^[A-G][♯♭\u{1D12A}\u{1D12B}]*/u;
  var SLASH_BASS_RE = /\/([A-G][♯♭\u{1D12A}\u{1D12B}]*)$/u;
  function appendSymbol(container, text) {
    var m = ROOT_RE.exec(text);
    if (!m || !m[0]) {
      container.textContent = text;
      return;
    }
    var root = document.createElement("span");
    root.className = "try-symbol-root";
    root.textContent = m[0];
    container.appendChild(root);
    var rest = text.slice(m[0].length);
    appendSymbolRest(container, rest);
  }

  function appendSymbolRest(container, text) {
    if (!text) return;
    var slash = SLASH_BASS_RE.exec(text);
    if (!slash || !slash[1]) {
      container.appendChild(document.createTextNode(text));
      return;
    }
    var before = text.slice(0, slash.index);
    if (before) container.appendChild(document.createTextNode(before));
    var slashSpan = document.createElement("span");
    slashSpan.className = "try-symbol-bass-slash";
    slashSpan.textContent = "/";
    container.appendChild(slashSpan);
    container.appendChild(document.createTextNode(slash[1]));
  }

  function appendNoteGroup(container, label, value) {
    var group = document.createElement("span");
    var labelSpan = document.createElement("span");
    labelSpan.className = "try-notes-label";
    labelSpan.textContent = label + ": ";
    group.appendChild(labelSpan);
    group.appendChild(document.createTextNode(value));
    container.appendChild(group);
  }

  function formatNoteList(value) {
    return value.trim().split(/\s+/).join("-");
  }

  // ─── Run loop ──────────────────────────────────────────────────

  var timer = null;
  function scheduleRun() {
    clearTimeout(timer);
    timer = setTimeout(run, 120);
  }

  function run() {
    var notes = els.notes.value;
    if (!notes.trim()) {
      state.canonicalNotes = null;
      syncUrl();
      syncTitle(null);
      els.candidates.innerHTML = "";
      els.resultsHead.hidden = true;
      els.rankingFeedback.hidden = true;
      els.symbolLegend.hidden = true;
      updateOpenAppLink();
      setStatus("");
      return;
    }
    var json = window.whatchordIdentify(
      notes,
      currentKey(),
      state.notation,
      state.ensemble ? "ensemble" : "solo",
    );
    var result = JSON.parse(json);
    state.canonicalNotes = result.ok
      ? result.input.notes.map(toAsciiNote).join(" ")
      : null;
    syncUrl();
    syncTitle(result);
    render(result);
    updateOpenAppLink();
  }

  function toAsciiNote(note) {
    return note
      .replaceAll("𝄪", "x")
      .replaceAll("𝄫", "bb")
      .replaceAll("♯", "#")
      .replaceAll("♭", "b");
  }

  // ─── Boot ──────────────────────────────────────────────────────

  function start() {
    var rootPc = seedFromUrl();
    rebuildKeyRoot(rootPc);
    syncClear();
    run();
    els.notes.focus();
  }

  if (window.whatchordReady) {
    start();
  } else {
    window.addEventListener("whatchord-ready", start, { once: true });
  }
})();
