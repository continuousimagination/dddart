import { readFileSync } from 'node:fs';
import { join, posix } from 'node:path';
import inventory from '../../../tool/validation/inventory.json';
import { git, repositoryRoot } from './repository';
import { base } from './site';

const projects = new Map(inventory.examples.map(project => [project.path, project]));
const packageLibraries = new Map(inventory.examples.map(project => [project.name, project.path + '/lib']));

function describeFile(source: string) {
  const projectPath = source.split('/').slice(0, 3).join('/');
  const project = projects.get(projectPath);
  if (!project) throw new Error(`Example project missing from the validation inventory: ${projectPath}`);
  const name = source.slice(projectPath.length + 1);
  const packageName = projectPath.split('/')[1];
  const slug = packageName + '/' + name.slice(0, -'.dart'.length);
  const entry = project.entrypoints.find(entry => entry.path === name);
  const description = entry?.reason ?? `Supporting source for the ${packageName} examples.`;
  return { source, name, projectPath, packageName, slug, description, url: `${base}examples/${slug}/` };
}

export type ExampleFile = ReturnType<typeof describeFile>;

// The checkout can also contain generated or ignored Dart files from running examples.
export const exampleFiles = git('ls-files', '-z', '--', 'packages/*/example/*.dart')
  .split('\0').filter(source => source && !source.endsWith('.g.dart')).map(describeFile);
const bySource = new Map(exampleFiles.map(file => [file.source, file]));
for (const project of projects.values()) {
  for (const entry of project.entrypoints) {
    const source = `${project.path}/${entry.path}`;
    if (!bySource.has(source)) throw new Error(`Missing package example: ${source}`);
  }
}

export function exampleUrl(source: string) {
  return bySource.get(source)?.url;
}

export function readExample(file: ExampleFile) {
  return readFileSync(join(repositoryRoot, file.source), 'utf8');
}

export function importedExample(source: string, uri: string) {
  if (uri.startsWith('package:')) {
    const [name, ...path] = uri.slice('package:'.length).split('/');
    const library = packageLibraries.get(name);
    return library && exampleUrl(posix.join(library, ...path));
  }
  return exampleUrl(posix.join(posix.dirname(source), uri));
}
