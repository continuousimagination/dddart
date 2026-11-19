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
    filter: ['a', 'p'],
    visit(node, ctx) {
      if (node.tagName === 'a' && typeof node.properties.href === 'string') {
        ctx.setProperty(node, 'href', repositoryLink(node.properties.href, ctx.fileURL));
      } else if (node.tagName === 'p') {
        ctx.data.astro.frontmatter.description ??= ctx.textContent(node).replace(/\s+/g, ' ').trim();
      }
    },
  },
};

export default defineConfig({
  site: 'https://continuousimagination.github.io',
  base,
  markdown: {
    processor: satteri({ hastPlugins: [repositoryMarkdown] }),
    shikiConfig: { theme: 'github-dark' },
  },
  trailingSlash: 'always',
  devToolbar: { enabled: false },
});
