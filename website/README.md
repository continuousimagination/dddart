# Develop the DDDart website

The [public documentation](https://continuousimagination.github.io/dddart/) is
built with Astro and served by GitHub Pages. The Node constraint and site
dependencies are in [package.json](package.json).

## Preview and test

From this directory:

```sh
npm ci
ASTRO_TELEMETRY_DISABLED=1 npm run dev
ASTRO_TELEMETRY_DISABLED=1 npm run check
```

Follow the printed local URL under `/dddart/`. Use `npm run preview` for the
built site. The check builds the site, verifies links, anchors, metadata,
assets and search data, and runs the site checker regression tests. It uses
Bash, jq and `xmllint` (on Ubuntu, install `libxml2-utils`).
[Documentation validation](../tool/documentation/README.md) checks that Dart
examples still work.

## Edit a guide

Open [the repository documentation index](../docs/README.md) to review a
guide, or use **Improve this page** on the published site. Both lead to the
same Markdown file. Its first heading supplies the title and its first
paragraph supplies the search description. Write ordinary relative links to
other guides, sections, examples, and source files. Astro resolves them from
the Markdown file's directory when building the site.

Register a new document in the [documentation inventory](../tool/documentation/surfaces.json).
Current Markdown documents get a page and a full-text search entry. The
[navigation map](src/lib/navigation.json) assigns the twelve featured guides
their public URLs, sidebar labels, and reading order. Other documents get
URLs derived from their repository paths. The
[documentation contributor guide](../tool/documentation/README.md) explains
how to include and check runnable examples.

## Publish

The [Website workflow](../.github/workflows/pages.yml) builds and checks the
site when its inputs change. It deploys from `main` to GitHub Pages. The
[Documentation workflow](../.github/workflows/documentation.yml) checks guides
throughout the repository. See [Actions](https://github.com/continuousimagination/dddart/actions)
for current runs.
