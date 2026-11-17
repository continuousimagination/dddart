export const base = '/dddart/';
export const repo = 'https://github.com/continuousimagination/dddart';
export const revision = '56607ac8d3913b8e896ac03f8ecff58473d62ce2';
export const doc = (slug: string) => `${base}docs/${slug}/`;
export const sections = ['Start here', 'Build your domain', 'Connect the pieces', 'Reference'];
export const navTitles: Record<string, string> = {
  philosophy: 'Philosophy', 'getting-started': 'Getting started',
  modeling: 'Modeling', serialization: 'JSON serialization', contracts: 'Shared contracts',
  repositories: 'Repositories', http: 'HTTP & authentication', events: 'Events & watches',
  configuration: 'Configuration', integrations: 'Integrations', packages: 'Package map', examples: 'Examples',
};
