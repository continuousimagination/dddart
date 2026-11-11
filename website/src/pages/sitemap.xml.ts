import { getCollection } from 'astro:content';
import { base, doc } from '../lib/site';
export async function GET() {
  const entries = await getCollection('docs');
  const urls = [base, ...entries.map(entry => doc(entry.id))];
  return new Response(`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls.map(url => `<url><loc>https://continuousimagination.github.io${url}</loc></url>`).join('')}</urlset>`, { headers: { 'Content-Type': 'application/xml' } });
}
