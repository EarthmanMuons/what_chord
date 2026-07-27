import { defineCollection, reference } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro/zod";

const articles = defineCollection({
  loader: glob({
    base: "./src/content/articles",
    pattern: "**/*.md",
  }),
  schema: z.object({
    cardDescription: z.string(),
    cardTitle: z.string(),
    decks: z.array(z.string()),
    description: z.string(),
    featuredDescription: z.string().optional(),
    featuredOrder: z.number().int().nonnegative().optional(),
    group: z.enum(["musicians", "technical"]),
    image: z.string(),
    imageAlt: z.string(),
    indexOrder: z.number().int().nonnegative(),
    pageTitle: z.string(),
    related: z.array(reference("articles")),
    relatedExternal: z
      .array(
        z.object({
          description: z.string(),
          href: z.url(),
          readMore: z.string(),
          tag: z.string(),
          title: z.string(),
        }),
      )
      .optional(),
    socialDescription: z.string(),
    socialTitle: z.string(),
    tag: z.string(),
    title: z.string(),
  }),
});

export const collections = { articles };
