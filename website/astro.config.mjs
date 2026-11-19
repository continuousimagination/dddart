import { statSync } from 'node:fs';
import { posix, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { satteri } from '@astrojs/markdown-satteri';
import { defineConfig } from 'astro/config';
import { publishedRoutes } from './src/lib/repository-docs';
import { exampleUrl } from './src/lib/example-files';
import { githubSource, repositoryRoot } from './src/lib/repository';
import { base, doc } from './src/lib/site';

function repositoryLink(href, fileURL) {
  if (!href || /^(?:[a-z][\w+.-]*:|[/#?])/i.test(href)) return href;
  const target = new URL(href, fileURL);
  const source = relative(repositoryRoot, fileURLToPath(target)).split('\\').join('/');
  if (source === '..' || source.startsWith('../')) throw new Error(`Link outside repository: ${href} in ${fileURL}`);
  const isDirectory = statSync(target).isDirectory();
  const slug = publishedRoutes.get(isDirectory ? posix.join(source, 'README.md') : source);
  const url = slug ? doc(slug) : exampleUrl(source) ?? githubSource(source, isDirectory ? 'tree' : 'blob');
  return url + target.search + target.hash;
}

const repositoryMarkdown = {
  name: 'repository-markdown',
  element: {
    filter: ['a', 'p', 'tr'],
    visit(node, ctx) {
      if (node.tagName === 'a' && typeof node.properties.href === 'string') {
        ctx.setProperty(node, 'href', repositoryLink(node.properties.href, ctx.fileURL));
      } else if (node.tagName === 'p') {
        ctx.data.astro.frontmatter.description ??= ctx.textContent(node).replace(/\s+/g, ' ').trim();
      } else if (node.tagName === 'tr' && /\/packages\/[^/]+\/example\/README\.md$/.test(ctx.fileURL.pathname)) {
        const cells = node.children.filter(child => child.tagName === 'td');
        const link = cells[0]?.children.find(child => child.tagName === 'a');
        if (cells.length !== 3 || !link) return;
        const url = repositoryLink(link.properties.href, ctx.fileURL);
        if (!url.startsWith(base + 'examples/')) return;
        const programs = ctx.data.astro.frontmatter.programs ??= {};
        if (Object.hasOwn(programs, url)) throw new Error(`Duplicate example row: ${url}`);
        const cellText = cell => ctx.textContent(cell).replace(/\s+/g, ' ').trim();
        programs[url] = { mode: cellText(cells[1]), description: cellText(cells[2]) };
      }
    },
  },
};

export default defineConfig({
  site: 'https://continuousimagination.github.io',
  base,
  integrations: [{
    name: 'quickstart-sources',
    hooks: {
      'astro:config:setup': ({ addWatchFile, command }) => {
        if (command === 'dev') {
          for (const path of [...publishedRoutes.keys(), 'tool/documentation/validate.sh', 'tool/documentation/common.sh']) {
            addWatchFile(new URL('../' + path, import.meta.url));
          }
        }
      },
    },
  }],
  markdown: {
    processor: satteri({ hastPlugins: [repositoryMarkdown] }),
    shikiConfig: { theme: 'github-dark' },
  },
  trailingSlash: 'always',
  devToolbar: { enabled: false },
});
