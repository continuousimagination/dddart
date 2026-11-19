import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { publishedRoutes } from './lib/repository-docs';

const docs = defineCollection({
  loader: glob({
    base: '../',
    // Links also depend on the routes of other documents. Render against the current map.
    deferRender: true,
    pattern: [...publishedRoutes.keys()],
    generateId: ({ entry }) => entry,
  }),
});

export const collections = { docs };
