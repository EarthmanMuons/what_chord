// Serves the static site, with one enhancement: for shared /try links that
// carry an input (?notes=...), it rewrites the social-preview metadata so an
// unfurl in Slack, Discord, iMessage, etc. shows the input notes and the top
// chord result. Crawlers do not run page JS, so the tags must be correct in
// the HTML response itself, which is what this Worker produces.
//
// The chord engine is the same compiled Dart bundle the browser uses; importing
// it for its side effects attaches globalThis.whatchordIdentify.
import "../js/chord-id.js";

const DEFAULT_MODE = "maj";
const DEFAULT_NOTATION = "textual";
const MAX_NOTES_CHARACTERS = 512;
const IOS_APP_ID = "6758409779";
const VALID_KEYS = new Set([
  "C:maj",
  "C#:maj",
  "Db:maj",
  "D:maj",
  "Eb:maj",
  "E:maj",
  "F:maj",
  "F#:maj",
  "Gb:maj",
  "G:maj",
  "Ab:maj",
  "A:maj",
  "Bb:maj",
  "B:maj",
  "Cb:maj",
  "C:min",
  "C#:min",
  "D:min",
  "D#:min",
  "Eb:min",
  "E:min",
  "F:min",
  "F#:min",
  "G:min",
  "G#:min",
  "Ab:min",
  "A:min",
  "A#:min",
  "Bb:min",
  "B:min",
]);

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/") {
      return env.ASSETS.fetch(
        new Request(new URL("/index.html", url.origin), request),
      );
    }

    if (url.pathname !== "/try") {
      return new Response("Not Found", { status: 404 });
    }

    // Always start from the real static asset so non-meta content is untouched.
    const asset = await env.ASSETS.fetch(
      new Request(new URL("/try.html", url.origin), request),
    );

    const notes = (url.searchParams.get("notes") || "").trim();
    if (!notes || notes.length > MAX_NOTES_CHARACTERS) return asset;

    const requestedKey = url.searchParams.get("key");
    const key = VALID_KEYS.has(requestedKey)
      ? requestedKey
      : "C:" + DEFAULT_MODE;
    const playingMode =
      url.searchParams.get("mode") === "ensemble" ? "ensemble" : "solo";
    let meta;
    try {
      const result = JSON.parse(
        globalThis.whatchordIdentify(notes, key, DEFAULT_NOTATION, playingMode),
      );
      meta = buildMeta(result, url, playingMode);
    } catch {
      meta = null;
    }
    if (!meta) return asset;

    const html = await asset.text();
    const rewritten = rewriteMeta(html, meta);

    // Per-URL response: let edge and crawler caches keep it for a while.
    const res = new Response(rewritten, asset);
    res.headers.delete("Content-Length");
    res.headers.set("Cache-Control", "public, max-age=3600");
    return res;
  },
};

// Builds preview copy from an engine result, or null when there is nothing
// worth previewing (bad input, or no candidates).
function buildMeta(result, url, playingMode) {
  if (
    !result ||
    !result.ok ||
    !result.candidates ||
    !result.candidates.length
  ) {
    return null;
  }
  const notes = result.input.notes.join(" ");
  const top = result.candidates[0].symbol;
  const bass = result.input.bass;
  const key = result.input.key;

  const title = notes + " → " + top;
  const description =
    "Identified by WhatChord. Bass " +
    bass +
    ", key " +
    key +
    (playingMode === "ensemble" ? ", ensemble mode" : "") +
    ".";

  return {
    title,
    titleTag: title + " | WhatChord",
    description,
    shareUrl: url.href,
  };
}

function rewriteMeta(html, meta) {
  let out = html.replace(
    /<title>.*?<\/title>/s,
    `<title>${escapeHtml(meta.titleTag)}</title>`,
  );
  out = replaceMeta(out, "name", "description", meta.description);
  out = replaceMeta(out, "property", "og:title", meta.title);
  out = replaceMeta(out, "property", "og:description", meta.description);
  out = replaceMeta(out, "property", "og:url", meta.shareUrl);
  out = replaceMeta(out, "name", "twitter:title", meta.title);
  out = replaceMeta(out, "name", "twitter:description", meta.description);
  // Point the Smart App Banner's OPEN button at this exact chord, so tapping it
  // deep-links into the app instead of cold-launching to the home screen.
  return replaceMeta(
    out,
    "name",
    "apple-itunes-app",
    "app-id=" + IOS_APP_ID + ", app-argument=" + meta.shareUrl,
  );
}

function replaceMeta(html, attribute, key, content) {
  const tag = new RegExp(
    `<meta\\s+${attribute}="${escapeRegExp(key)}"\\s+content="[^"]*"\\s*/?>`,
    "s",
  );
  return html.replace(
    tag,
    `<meta ${attribute}="${key}" content="${escapeHtml(content)}" />`,
  );
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
