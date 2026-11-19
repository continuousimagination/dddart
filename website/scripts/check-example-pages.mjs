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
const workflows = json(new URL('docs/quickstarts/workflows.json', root)).workflows;
const snippets = JSON.parse(execFileSync('bash', ['tool/documentation/validate.sh', 'snippets'], { cwd: root, encoding: 'utf8' }));
const featured = Object.values(json(new URL('website/src/lib/navigation.json', root))).flat();
const libraries = new Map(projects.map(project => [project.name, project.path + '/lib']));
const tracked = execFileSync('git', ['ls-files', '-z', '--', 'packages/*/example/*.dart', 'packages/*/example/pubspec.yaml'], {
  cwd: root, encoding: 'utf8',
}).split('\0').filter(source => source && !source.endsWith('.g.dart'));

const pages = new Map(tracked.map(source => {
  const slug = source.replace(/^packages\/([^/]+)\/example\//, '$1/').replace(/\.dart$/, '');
  return [source, `/dddart/examples/${slug}/`];
}));
for (const workflow of workflows) {
  for (const { source, destination } of workflow.files) {
    const path = `quickstarts/${workflow.name}/`;
    pages.set('docs/' + path + source, '/dddart/examples/' + path + destination.replace(/\.dart$/, '') + '/');
  }
}

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
  const snippet = snippets[source];
  let code;
  if (snippet) {
    const lines = readFileSync(new URL(snippet.document, root), 'utf8').replaceAll('\r\n', '\n').split('\n');
    const start = snippet.line - 1;
    assert.equal(lines[start - 2], `<!-- dddart-source: ${source} -->`);
    const end = lines.indexOf('```', start);
    assert.equal(lines[end + 1], '<!-- /dddart-source -->');
    code = lines.slice(start, end).join('\n') + '\n';
    assert.ok(xpath(url, 'string(//div[@class="doc-edit"]/a/@href)').trim().endsWith('/' + snippet.document + '?plain=1#L' + snippet.line));
  } else {
    code = readFileSync(new URL(source, root), 'utf8');
  }
  assert.equal(index.get(url)?.text, code, `Search must index the complete file: ${source}`);
  const extension = posix.extname(source.replace(/\.txt$/, ''));
  const language = { '.dart': 'dart', '.yaml': 'yaml' }[extension] ?? 'text';
  const rendered = xpath(url, `string(//pre[@data-language="${language}"]/code)`);
  // Astro strips one final line ending; xmllint versions differ on adding one.
  const expected = code.replace(/\r\n/g, '\n').replace(/\n$/, '');
  assert.ok(rendered === expected || rendered === expected + '\n', `Changed rendered source: ${source}`);

  if (language !== 'dart') continue;
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

for (const [panel, file] of Object.entries({ order: 'main', repository: 'repository', service: 'contracts' })) {
  const code = xpath('/dddart/', `string(//*[@id="panel-${panel}"]//pre/code)`);
  assert.equal(code.trimEnd(), snippets[`docs/quickstarts/core/bin/${file}.dart`].text.trimEnd(), `Homepage ${panel} tab`);
}

function guideUrl(projectPath) {
  const featuredGuide = featured.find(guide => guide.source === projectPath + '/README.md');
  return '/dddart/docs/' + (featuredGuide?.slug ?? projectPath.toLowerCase().replace(/^docs\//, 'reference/')) + '/';
}

function checkPubspecLink(links, guide, source) {
  assert.ok(links.includes(pages.get(source)), `The guide must link to the on-site pubspec: ${guide}`);
}

for (const workflow of workflows) {
  const projectPath = 'docs/quickstarts/' + workflow.name;
  const pubspec = workflow.files.find(file => file.destination === 'pubspec.yaml');
  const guide = guideUrl(projectPath);
  checkPubspecLink(hrefs(guide, '//article//a/@href'), guide, projectPath + '/' + pubspec.source);
}
for (const project of projects) {
  const guide = guideUrl(project.path);
  const links = hrefs(guide, '//article//a/@href');
  checkPubspecLink(links, guide, project.path + '/pubspec.yaml');
  for (const entry of project.entrypoints) {
    const source = project.path + '/' + entry.path;
    assert.ok(links.includes(pages.get(source)), `Example guide must link to the source page: ${source}`);
  }
}
console.log(`Verified ${pages.size} complete example sources, ${workflows.length + projects.length} guide pubspec links, search text and ${linkedDirectives} local directives.`);
