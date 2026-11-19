import { render, type CollectionEntry } from 'astro:content';
import { publishedRoutes, sectionFor } from './repository-docs';

export async function readDocument(entry: CollectionEntry<'docs'>) {
  const { Content, headings, remarkPluginFrontmatter } = await render(entry);
  const title = headings.find(heading => heading.depth === 1)?.text;
  const description = remarkPluginFrontmatter.description;
  if (!title || !description) throw new Error(`Expected a title and introduction in ${entry.id}`);
  return {
    Content, headings, title, description: String(description),
    slug: publishedRoutes.get(entry.id)!, section: sectionFor(entry.id),
  };
}
