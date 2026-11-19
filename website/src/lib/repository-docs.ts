import inventory from '../../../tool/documentation/surfaces.json';
import navigation from './navigation.json';
import overrides from './route-overrides.json';

export { navigation };
export const guides = Object.entries(navigation).flatMap(([section, entries]) =>
  entries.map(entry => ({ ...entry, section }))
);

function referenceSlug(source: string) {
  return source.replace(/^docs\//, 'reference/').replace(/\/README\.md$|\.md$/i, '').toLowerCase();
}

const routes = new Map<string, string>();
for (const [source, status] of Object.entries(inventory.documents)) {
  if (status === 'current' && source.endsWith('.md')) routes.set(source, referenceSlug(source));
}
for (const [source, slug] of Object.entries(overrides)) {
  if (!routes.has(source)) throw new Error(`Missing source for documentation URL ${slug}: ${source}`);
  routes.set(source, slug);
}
const publishedSlugs = new Set(routes.values());
if (publishedSlugs.size !== routes.size) throw new Error('Duplicate documentation URL');
for (const guide of guides) {
  if (!publishedSlugs.has(guide.slug)) throw new Error(`Unpublished sidebar link: ${guide.slug}`);
}
export const publishedRoutes = routes;

export function sectionFor(source: string) {
  const slug = routes.get(source);
  return guides.find(guide => guide.slug === slug)?.section
    ?? (source.startsWith('packages/') ? 'Package reference' : 'Reference');
}
