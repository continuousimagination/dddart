import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://continuousimagination.github.io',
  base: '/dddart',
  trailingSlash: 'always',
  markdown: { shikiConfig: { theme: 'github-dark' } },
  devToolbar: { enabled: false },
});
