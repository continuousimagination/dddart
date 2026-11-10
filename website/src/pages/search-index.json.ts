import { getCollection } from 'astro:content';
import { doc } from '../lib/site';
export async function GET() {
  const entries = await getCollection('docs');
  return new Response(JSON.stringify(entries.map(entry => ({
    title: entry.data.title, description: entry.data.description,
    section: entry.data.section, url: doc(entry.id), text: entry.body,
  }))), { headers: { 'Content-Type': 'application/json; charset=utf-8' } });
}
