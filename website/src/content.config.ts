import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';
import { sections } from './lib/site';

const docs = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/docs' }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    section: z.enum(sections),
    order: z.number(),
  }),
});

export const collections = { docs };
