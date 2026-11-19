import { getEntry, render, type CollectionEntry } from 'astro:content';
import { exampleFiles, exampleUrl, packageExamples } from './example-files';
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

export async function readExampleListings() {
  const descriptions = new Map<string, string>();
  const modes: Record<string, string> = { run: 'Local run', compile: 'Configured integration', service: 'Local database' };
  for (const project of packageExamples) {
    const source = project.path + '/README.md';
    const guide = await getEntry('docs', source);
    if (!guide) throw new Error(`Missing example guide: ${source}`);
    const { remarkPluginFrontmatter } = await render(guide);
    const programs = remarkPluginFrontmatter.programs ?? {};
    for (const entry of project.entrypoints) {
      const url = exampleUrl(project.path + '/' + entry.path)!;
      const row = programs[url];
      if (!row?.description || row.mode !== modes[entry.action]) {
        throw new Error(`${source}: expected a description and "${modes[entry.action]}" for ${entry.path}`);
      }
      descriptions.set(url, row.description);
    }
  }
  return exampleFiles.map(file => ({ ...file, description: descriptions.get(file.url) ?? file.description }));
}
