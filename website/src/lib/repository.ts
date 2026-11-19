import { execFileSync } from 'node:child_process';
import { repo } from './site';

// Works for both Astro's config loader and the server modules used during prerendering.
export const repositoryRoot = execFileSync('git', ['rev-parse', '--show-toplevel'], {
  cwd: new URL('.', import.meta.url), encoding: 'utf8',
}).trimEnd();

export function git(...args: string[]) {
  return execFileSync('git', args, { cwd: repositoryRoot, encoding: 'utf8' });
}

const revision = process.env.DDDART_SOURCE_REVISION || git('rev-parse', 'HEAD').trimEnd();

export function githubSource(source: string, kind: 'blob' | 'tree' = 'blob') {
  return `${repo}/${kind}/${revision}/${source.split('/').map(encodeURIComponent).join('/')}`;
}
