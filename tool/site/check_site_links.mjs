import { readdir, readFile } from "node:fs/promises";
import { extname, join, relative, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";

const siteOrigin = "https://site.invalid";

function decodeHtmlAttribute(value) {
  return value.replace(
    /&(?:#(\d+)|#x([\da-f]+)|amp|apos|gt|lt|quot);/gi,
    (entity, decimal, hexadecimal) => {
      if (decimal) {
        return String.fromCodePoint(Number.parseInt(decimal, 10));
      }
      if (hexadecimal) {
        return String.fromCodePoint(Number.parseInt(hexadecimal, 16));
      }

      return {
        "&amp;": "&",
        "&apos;": "'",
        "&gt;": ">",
        "&lt;": "<",
        "&quot;": '"',
      }[entity.toLowerCase()];
    },
  );
}

async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await walk(path)));
    } else if (entry.isFile()) {
      files.push(path);
    }
  }

  return files;
}

function toPublicPath(root, file) {
  return `/${relative(root, file).split(sep).join("/")}`;
}

function routeForHtmlPath(path) {
  if (path === "/index.html") {
    return "/";
  }
  if (path.endsWith("/index.html")) {
    return `${path.slice(0, -"index.html".length)}`;
  }
  return path;
}

function htmlPathForRoute(route, files) {
  const candidates = [route];

  if (route.endsWith("/")) {
    candidates.push(`${route}index.html`);
  } else {
    candidates.push(`${route}.html`, `${route}/index.html`);
  }

  return candidates.find((candidate) => files.has(candidate));
}

function findAttributes(html, name) {
  const pattern = new RegExp(`(?:^|\\s)${name}=(["'])(.*?)\\1`, "gis");
  return [...html.matchAll(pattern)].map((match) =>
    decodeHtmlAttribute(match[2]),
  );
}

export async function checkSiteLinks(rootArgument) {
  const root = resolve(rootArgument);
  const diskFiles = await walk(root);
  const publicFiles = new Set(
    diskFiles.map((file) => toPublicPath(root, file)),
  );
  const htmlFiles = diskFiles.filter((file) => extname(file) === ".html");
  const pages = new Map();
  const failures = [];
  let checkedReferences = 0;
  let checkedFragments = 0;

  for (const file of htmlFiles) {
    const path = toPublicPath(root, file);
    const route = routeForHtmlPath(path);
    const html = await readFile(file, "utf8");
    const ids = findAttributes(html, "id");
    const duplicateIds = ids.filter((id, index) => ids.indexOf(id) !== index);

    for (const id of new Set(duplicateIds)) {
      failures.push(`${route}: duplicate id "${id}"`);
    }

    pages.set(path, { html, ids: new Set(ids), route });
  }

  for (const page of pages.values()) {
    const references = [
      ...findAttributes(page.html, "href"),
      ...findAttributes(page.html, "src"),
    ];

    for (const reference of references) {
      let url;
      try {
        url = new URL(reference, `${siteOrigin}${page.route}`);
      } catch {
        failures.push(`${page.route}: invalid URL "${reference}"`);
        continue;
      }

      if (url.origin !== siteOrigin) {
        continue;
      }

      checkedReferences += 1;
      let pathname;
      try {
        pathname = decodeURIComponent(url.pathname);
      } catch {
        failures.push(`${page.route}: invalid URL encoding in "${reference}"`);
        continue;
      }

      const targetPath = htmlPathForRoute(pathname, publicFiles);
      if (!targetPath) {
        failures.push(`${page.route}: missing target "${reference}"`);
        continue;
      }

      if (!url.hash || extname(targetPath) !== ".html") {
        continue;
      }

      checkedFragments += 1;
      let fragment;
      try {
        fragment = decodeURIComponent(url.hash.slice(1));
      } catch {
        failures.push(
          `${page.route}: invalid fragment encoding in "${reference}"`,
        );
        continue;
      }

      if (!pages.get(targetPath)?.ids.has(fragment)) {
        failures.push(`${page.route}: missing fragment target "${reference}"`);
      }
    }
  }

  if (failures.length > 0) {
    throw new Error(
      `Generated site link check failed:\n${failures
        .map((failure) => `- ${failure}`)
        .join("\n")}`,
    );
  }

  console.log(
    `Checked ${checkedReferences} local references and ${checkedFragments} fragments across ${pages.size} HTML pages.`,
  );
}

const invokedPath =
  process.argv[1] && pathToFileURL(resolve(process.argv[1])).href;
if (invokedPath === import.meta.url) {
  const rootArgument = process.argv[2];
  if (!rootArgument) {
    throw new Error("Usage: check_site_links.mjs <generated-site-directory>");
  }
  await checkSiteLinks(rootArgument);
}
