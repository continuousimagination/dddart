import { getCollection } from 'astro:content';
import { readDocument } from '../lib/documents';
import { guides } from '../lib/repository-docs';
import { doc } from '../lib/site';

export async function GET() {
  const entries = await getCollection('docs');
  const index = await Promise.all(entries.map(async entry => {
    const { title, description, section, slug } = await readDocument(entry);
    const label = guides.find(guide => guide.slug === slug)?.label ?? title;
    return { title: label, description, section, url: doc(slug), text: entry.body };
  }));
  return Response.json(index);
}
