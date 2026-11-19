// Compare the published source, search data, and clickable directives with the checkout.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { posix } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = new URL('../../', import.meta.url);
const dist = new URL('website/dist/', root);
const json = url => JSON.parse(readFileSync(url, 'utf8'));
const index = new Map(json(new URL('search-index.json', dist)).map(entry => [entry.url, entry]));
const projects = json(new URL('tool/validation/inventory.json', root)).examples;
const featured = Object.values(json(new URL('website/src/lib/navigation.json', root))).flat();
const libraries = new Map(projects.map(project => [project.name, project.path + '/lib']));
const tracked = execFileSync('git', ['ls-files', '-z', '--', 'packages/*/example/*.dart'], {
  cwd: root, encoding: 'utf8',
}).split('\0').filter(source => source && !source.endsWith('.g.dart'));

const pages = new Map(tracked.map(source => {
  const slug = source.replace(/^packages\/([^/]+)\/example\//, '$1/').replace(/\.dart$/, '');
  return [source, `/dddart/examples/${slug}/`];
}));

function xpath(url, expression) {
  const html = new URL(url.slice('/dddart/'.length) + 'index.html', dist);
  try {
    return execFileSync('xmllint', ['--html', '--nonet', '--nowarning', '--xpath', expression, fileURLToPath(html)], {
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (error) {
    if (/^XPath set is empty$/m.test(error.stderr)) return '';
    throw error;
  }
}

function hrefs(url, expression) {
  return [...xpath(url, expression).matchAll(/href="([^"]+)"/g)].map(match => match[1]);
}

let linkedDirectives = 0;
for (const [source, url] of pages) {
  const code = readFileSync(new URL(source, root), 'utf8');
  assert.equal(index.get(url)?.text, code, `Search must index the complete file: ${source}`);
  const rendered = xpath(url, 'string(//pre[@data-language="dart"]/code)');
  // Astro strips one final line ending; xmllint versions differ on adding one.
  const expected = code.replace(/\r\n/g, '\n').replace(/\n$/, '');
  assert.ok(rendered === expected || rendered === expected + '\n', `Changed rendered source: ${source}`);

  const links = hrefs(url, '//pre/code//a/@href');
  for (const [, uri] of code.matchAll(/^\s*(?:import|export|part(?:\s+of)?)\s+['"]([^'"]+)['"]/gm)) {
    let target = posix.join(posix.dirname(source), uri);
    if (uri.startsWith('package:')) {
      const [packageName, ...path] = uri.slice('package:'.length).split('/');
      if (!libraries.has(packageName)) continue;
      target = posix.join(libraries.get(packageName), ...path);
    }
    if (pages.has(target)) {
      assert.ok(links.includes(pages.get(target)), `Missing clickable directive in ${source}: ${uri}`);
      linkedDirectives++;
    }
  }
}

for (const project of projects) {
  const featuredGuide = featured.find(guide => guide.source === project.path + '/README.md');
  const guide = '/dddart/docs/' + (featuredGuide?.slug ?? project.path.toLowerCase()) + '/';
  const links = hrefs(guide, '//article//a/@href');
  for (const entry of project.entrypoints) {
    const source = project.path + '/' + entry.path;
    assert.ok(links.includes(pages.get(source)), `Example guide must link to the source page: ${source}`);
  }
}
console.log(`Verified ${pages.size} complete example sources, their guide links, search text and ${linkedDirectives} local directives.`);
