import inventory from '../../../tool/documentation/surfaces.json';
import navigation from './navigation.json';

export { navigation };
export const guides = Object.entries(navigation).flatMap(([section, entries]) =>
  entries.map(entry => ({ ...entry, section }))
);

function referenceSlug(source: string) {
  if (source === 'README.md') return 'project';
  if (source === 'docs/README.md') return 'overview';
  return source.replace(/^docs\//, 'reference/').replace(/\/README\.md$|\.md$/i, '').toLowerCase();
}

const routes = new Map<string, string>();
for (const [source, status] of Object.entries(inventory.documents)) {
  if (status === 'current' && source.endsWith('.md')) routes.set(source, referenceSlug(source));
}
for (const guide of guides) {
  if (!routes.has(guide.source)) throw new Error(`Missing guide source: ${guide.source}`);
  routes.set(guide.source, guide.slug);
}
if (new Set(routes.values()).size !== routes.size) throw new Error('Duplicate documentation URL');
export const publishedRoutes = routes;

export function sectionFor(source: string) {
  return guides.find(guide => guide.source === source)?.section
    ?? (source.startsWith('packages/') ? 'Package reference' : 'Reference');
}
