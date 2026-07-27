import sitemap from "@astrojs/sitemap";
import { defineConfig } from "astro/config";

export default defineConfig({
  build: {
    format: "preserve",
  },
  integrations: [
    sitemap({
      filter: (page) => !page.endsWith("/404.html"),
      serialize(item) {
        const url = new URL(item.url);
        if (url.pathname === "/articles") {
          url.pathname = "/articles/";
        } else if (url.pathname.startsWith("/articles/")) {
          url.pathname = `${url.pathname}.html`;
        }
        return { ...item, url: url.href };
      },
    }),
  ],
  output: "static",
  site: "https://whatchord.earthmanmuons.com",
});
