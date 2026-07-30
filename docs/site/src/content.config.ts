import { defineCollection, reference } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro/zod";

const articleCta = z.object({
  action: z
    .object({
      external: z.boolean().optional(),
      href: z.string(),
      icon: z.enum(["github"]).optional(),
      label: z.string(),
      variant: z.enum(["ghost", "primary"]),
    })
    .optional(),
  description: z.string(),
  secondary: z
    .object({
      href: z.string(),
      label: z.string(),
      lead: z.string(),
    })
    .optional(),
  storeBadges: z.boolean().optional(),
  title: z.string(),
});

const articles = defineCollection({
  loader: glob({
    base: "./src/content/articles",
    pattern: "**/*.md",
  }),
  schema: z.object({
    cardDescription: z.string(),
    cta: articleCta,
    decks: z.array(z.string()),
    description: z.string(),
    featuredDescription: z.string().optional(),
    featuredOrder: z.number().int().nonnegative().optional(),
    group: z.enum(["musicians", "technical"]),
    indexOrder: z.number().int().nonnegative(),
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
    socialImage: z
      .object({
        alt: z.string(),
        src: z.string(),
      })
      .optional(),
    socialDescription: z.string(),
    socialTitle: z.string(),
    tag: z.string(),
    title: z.string(),
  }),
});

export const collections = { articles };
