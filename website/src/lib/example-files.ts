import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join, posix } from 'node:path';
import quickstarts from '../../../docs/quickstarts/workflows.json';
import inventory from '../../../tool/validation/inventory.json';
import { git, githubSource, repositoryRoot } from './repository';
import { base } from './site';

export const packageExamples = inventory.examples;
const projects = new Map(packageExamples.map(project => [project.path, project]));
const packageLibraries = new Map(inventory.examples.map(project => [project.name, project.path + '/lib']));
const snippets: Record<string, { document: string; line: number; text: string }> = JSON.parse(
  execFileSync('bash', ['tool/documentation/validate.sh', 'snippets'], { cwd: repositoryRoot, encoding: 'utf8' })
);

export function readQuickstart(source: string) {
  if (!Object.hasOwn(snippets, source)) throw new Error(`Missing quickstart snippet: ${source}`);
  return snippets[source].text;
}

export function sourceLink(file: ExampleFile) {
  const snippet = snippets[file.source];
  return snippet ? githubSource(snippet.document) + '?plain=1#L' + snippet.line : githubSource(file.source);
}

type SourceListing = {
  source: string;
  name: string;
  projectPath: string;
  projectLabel: string;
  route: string;
  description: string;
};

function exampleFile({ route, ...file }: SourceListing) {
  const { name } = file;
  const slug = route + '/' + name.replace(/\.dart$/, '');
  const language = name.endsWith('.dart') ? 'dart' : name.endsWith('.yaml') ? 'yaml' : 'text';
  return { ...file, slug, language, url: `${base}examples/${slug}/` } as const;
}

function packageFile(source: string) {
  const projectPath = source.split('/').slice(0, 3).join('/');
  const project = projects.get(projectPath);
  if (!project) throw new Error(`Example project missing from the validation inventory: ${projectPath}`);
  const name = source.slice(projectPath.length + 1);
  const packageName = projectPath.split('/')[1];
  const projectLabel = packageName + ' examples';
  const description = name === 'pubspec.yaml' ? `Package configuration for the ${projectLabel}.`
    : `Supporting source for the ${projectLabel}.`;
  return exampleFile({ source, name, projectPath, projectLabel, route: packageName, description });
}

export type ExampleFile = ReturnType<typeof exampleFile>;

// The checkout can also contain generated or ignored Dart files from running examples.
const packageFiles = git('ls-files', '-z', '--', 'packages/*/example/*.dart', 'packages/*/example/pubspec.yaml')
  .split('\0').filter(source => source && !source.endsWith('.g.dart')).map(packageFile);
const quickstartFiles = quickstarts.workflows.flatMap(workflow => {
  const route = 'quickstarts/' + workflow.name;
  const projectPath = 'docs/' + route;
  const projectLabel = workflow.name.replaceAll('_', ' ') + ' quickstart';
  return workflow.files.map(({ source, destination }) => exampleFile({
    source: projectPath + '/' + source, name: destination, projectPath, projectLabel, route,
    description: `Save this file as ${destination} when following the ${projectLabel}.`,
  }));
});
export const exampleFiles = [...packageFiles, ...quickstartFiles];
if (new Set(exampleFiles.map(file => file.slug)).size !== exampleFiles.length) throw new Error('Duplicate example URL');
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
  return snippets[file.source]?.text ?? readFileSync(join(repositoryRoot, file.source), 'utf8');
}

export function importedExample(source: string, uri: string) {
  if (uri.startsWith('package:')) {
    const [name, ...path] = uri.slice('package:'.length).split('/');
    const library = packageLibraries.get(name);
    return library && exampleUrl(posix.join(library, ...path));
  }
  return exampleUrl(posix.join(posix.dirname(source), uri));
}
